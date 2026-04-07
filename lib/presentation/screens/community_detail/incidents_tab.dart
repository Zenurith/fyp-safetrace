part of '../community_detail_screen.dart';

// ── Reports Tab (community incidents) ────────────────────────────────────────

class _CommunityIncidentsTab extends StatefulWidget {
  final String communityId;

  const _CommunityIncidentsTab({required this.communityId});

  @override
  State<_CommunityIncidentsTab> createState() => _CommunityIncidentsTabState();
}

class _CommunityIncidentsTabState extends State<_CommunityIncidentsTab>
    with AutomaticKeepAliveClientMixin {
  late final IncidentProvider _incidentProvider;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SeverityLevel? _selectedSeverity;
  IncidentCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _incidentProvider = context.read<IncidentProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _incidentProvider.watchCommunityIncidents(widget.communityId);
    });
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _incidentProvider.stopWatchingCommunityIncidents();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  bool get _hasActiveFilters =>
      _selectedSeverity != null || _selectedCategory != null;

  List<IncidentModel> _applyFilters(List<IncidentModel> source) {
    return source.where((i) {
      if (_selectedSeverity != null && i.severity != _selectedSeverity) {
        return false;
      }
      if (_selectedCategory != null && i.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final titleMatch = i.title.toLowerCase().contains(_searchQuery);
        final categoryMatch =
            i.categoryLabel.toLowerCase().contains(_searchQuery);
        if (!titleMatch && !categoryMatch) return false;
      }
      return true;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _selectedSeverity = null;
      _selectedCategory = null;
      _searchController.clear();
    });
  }

  Color _severityColor(SeverityLevel s) {
    switch (s) {
      case SeverityLevel.high:
        return AppTheme.primaryRed;
      case SeverityLevel.moderate:
        return AppTheme.warningOrange;
      case SeverityLevel.low:
        return AppTheme.successGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final all = context.watch<IncidentProvider>().communityIncidents;
    final visible = all
        .where((i) =>
            i.status != IncidentStatus.pending &&
            i.status != IncidentStatus.dismissed)
        .toList();
    final filtered = _applyFilters(visible);

    return Stack(
      children: [
        Column(
          children: [
            // ── Search + Filter bar ────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search field
                  TextField(
                    controller: _searchController,
                    style: AppTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Search incidents…',
                      hintStyle: AppTheme.caption,
                      prefixIcon: const Icon(Icons.search,
                          size: 20, color: AppTheme.textSecondary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close,
                                  size: 18, color: AppTheme.textSecondary),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      filled: true,
                      fillColor: AppTheme.backgroundGrey,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Filter chips row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Severity filter
                        _FilterDropdown<SeverityLevel>(
                          label: _selectedSeverity == null
                              ? 'Severity'
                              : _selectedSeverity!.name[0].toUpperCase() +
                                  _selectedSeverity!.name.substring(1),
                          isActive: _selectedSeverity != null,
                          items: SeverityLevel.values,
                          itemLabel: (s) =>
                              s.name[0].toUpperCase() + s.name.substring(1),
                          selected: _selectedSeverity,
                          onSelected: (v) =>
                              setState(() => _selectedSeverity = v),
                        ),
                        const SizedBox(width: 8),
                        // Category filter
                        _FilterDropdown<IncidentCategory>(
                          label: _selectedCategory == null
                              ? 'Category'
                              : _categoryLabel(_selectedCategory!),
                          isActive: _selectedCategory != null,
                          items: IncidentCategory.values,
                          itemLabel: _categoryLabel,
                          selected: _selectedCategory,
                          onSelected: (v) =>
                              setState(() => _selectedCategory = v),
                        ),
                        if (_hasActiveFilters) ...[
                          const SizedBox(width: 8),
                          ActionChip(
                            label: const Text('Clear'),
                            labelStyle: AppTheme.caption
                                .copyWith(color: AppTheme.primaryRed),
                            avatar: const Icon(Icons.close,
                                size: 14, color: AppTheme.primaryRed),
                            backgroundColor: AppTheme.primaryRed
                                .withValues(alpha: 0.08),
                            side: BorderSide(
                                color: AppTheme.primaryRed
                                    .withValues(alpha: 0.3)),
                            onPressed: _clearFilters,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            // Results count if filtered
            if (_searchQuery.isNotEmpty || _hasActiveFilters)
              Container(
                width: double.infinity,
                color: AppTheme.backgroundGrey,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(
                  '${filtered.length} result${filtered.length == 1 ? '' : 's'}',
                  style: AppTheme.caption,
                ),
              ),
            // ── Incident list ──────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: _EmptyState(
                        icon: (_searchQuery.isNotEmpty || _hasActiveFilters)
                            ? Icons.search_off_rounded
                            : Icons.warning_amber_outlined,
                        message: (_searchQuery.isNotEmpty || _hasActiveFilters)
                            ? 'No incidents match your filters.'
                            : 'No incident reports yet.\nBe the first to report!',
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final incident = filtered[i];
                        final severityColor =
                            _severityColor(incident.severity);
                        return InkWell(
                          onTap: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) =>
                                IncidentBottomSheet(incidentId: incident.id),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: AppTheme.cardDecoration,
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: severityColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.warning_amber_rounded,
                                      size: 20, color: severityColor),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(incident.title,
                                          style: AppTheme.headingSmall,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${incident.categoryLabel}  •  ${incident.severityLabel}  •  ${incident.timeAgo}',
                                        style: AppTheme.caption,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right,
                                    size: 18, color: AppTheme.textSecondary),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'report_incident_fab',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreatePostScreen()),
            ),
            backgroundColor: AppTheme.primaryRed,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_alert_outlined),
            label: const Text('Create a Post'),
          ),
        ),
      ],
    );
  }

  String _categoryLabel(IncidentCategory c) {
    switch (c) {
      case IncidentCategory.crime:
        return 'Crime';
      case IncidentCategory.infrastructure:
        return 'Infrastructure';
      case IncidentCategory.suspicious:
        return 'Suspicious';
      case IncidentCategory.traffic:
        return 'Traffic';
      case IncidentCategory.environmental:
        return 'Environmental';
      case IncidentCategory.emergency:
        return 'Emergency';
      case IncidentCategory.other:
        return 'Other';
    }
  }
}

// ── Generic filter dropdown chip ─────────────────────────────────────────────

class _FilterDropdown<T> extends StatelessWidget {
  final String label;
  final bool isActive;
  final List<T> items;
  final String Function(T) itemLabel;
  final T? selected;
  final ValueChanged<T?> onSelected;

  const _FilterDropdown({
    required this.label,
    required this.isActive,
    required this.items,
    required this.itemLabel,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: AppTheme.caption.copyWith(
                color: isActive ? AppTheme.primaryRed : AppTheme.primaryDark,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.normal,
              )),
          const SizedBox(width: 2),
          Icon(Icons.arrow_drop_down,
              size: 16,
              color: isActive ? AppTheme.primaryRed : AppTheme.textSecondary),
        ],
      ),
      selected: isActive,
      selectedColor: AppTheme.primaryRed.withValues(alpha: 0.08),
      backgroundColor: AppTheme.backgroundGrey,
      side: BorderSide(
        color: isActive
            ? AppTheme.primaryRed.withValues(alpha: 0.4)
            : AppTheme.cardBorder,
      ),
      showCheckmark: false,
      onSelected: (_) => _showMenu(context),
    );
  }

  void _showMenu(BuildContext context) {
    final RenderBox chip = context.findRenderObject() as RenderBox;
    final Offset offset = chip.localToGlobal(Offset.zero);
    final Size size = chip.size;

    showMenu<T?>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height + 4,
        offset.dx + size.width,
        0,
      ),
      items: [
        if (selected != null)
          PopupMenuItem<T?>(
            value: null,
            child: Text('All',
                style: AppTheme.bodyMedium
                    .copyWith(color: AppTheme.textSecondary)),
          ),
        ...items.map(
          (item) => PopupMenuItem<T?>(
            value: item,
            child: Row(
              children: [
                if (selected == item)
                  const Icon(Icons.check,
                      size: 16, color: AppTheme.primaryRed)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(itemLabel(item), style: AppTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ],
    ).then((value) {
      if (value == null && selected != null) {
        onSelected(null); // "All" clears filter
      } else if (value != null) {
        onSelected(value);
      }
    });
  }
}
