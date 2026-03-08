import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/incident_model.dart';
import '../../../utils/app_theme.dart';
import '../../providers/incident_provider.dart';
import '../../providers/category_provider.dart';

class IncidentsManagementPage extends StatefulWidget {
  const IncidentsManagementPage({super.key});

  @override
  State<IncidentsManagementPage> createState() => _IncidentsManagementPageState();
}

class _IncidentsManagementPageState extends State<IncidentsManagementPage> {
  String _searchQuery = '';
  IncidentStatus? _statusFilter;
  String? _categoryFilter;
  SeverityLevel? _severityFilter;
  String _dateFilter = 'all'; // 'all', '7days', '30days', '90days'

  List<IncidentModel> _filterIncidents(List<IncidentModel> incidents) {
    return incidents.where((incident) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!incident.title.toLowerCase().contains(query) &&
            !incident.address.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Date filter
      if (_dateFilter != 'all') {
        final now = DateTime.now();
        DateTime cutoff;
        switch (_dateFilter) {
          case '7days':
            cutoff = now.subtract(const Duration(days: 7));
            break;
          case '30days':
            cutoff = now.subtract(const Duration(days: 30));
            break;
          case '90days':
            cutoff = now.subtract(const Duration(days: 90));
            break;
          default:
            cutoff = DateTime(2000);
        }
        if (incident.reportedAt.isBefore(cutoff)) {
          return false;
        }
      }

      // Status filter
      if (_statusFilter != null && incident.status != _statusFilter) {
        return false;
      }

      // Category filter
      if (_categoryFilter != null && incident.categoryLabel != _categoryFilter) {
        return false;
      }

      // Severity filter
      if (_severityFilter != null && incident.severity != _severityFilter) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final incidentProvider = context.watch<IncidentProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final allIncidents = incidentProvider.allIncidents;
    final incidents = _filterIncidents(allIncidents);
    final categoryNames = categoryProvider.categories.map((c) => c.name).toList();

    return Column(
      children: [
        // Filters bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: AppTheme.cardBorder,
              ),
            ),
          ),
          child: Row(
            children: [
              // Search
              Expanded(
                flex: 2,
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.primaryDark,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by title or location...',
                    hintStyle: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    prefixIcon: Icon(Icons.search, size: 20, color: AppTheme.textSecondary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppTheme.cardBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppTheme.cardBorder,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Status filter
              _buildDropdown<IncidentStatus?>(
                value: _statusFilter,
                hint: 'All Status',
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Status')),
                  ...IncidentStatus.values.map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(_getStatusLabel(s)),
                      )),
                ],
                onChanged: (value) => setState(() => _statusFilter = value),
              ),
              const SizedBox(width: 12),

              // Category filter
              _buildDropdown<String?>(
                value: _categoryFilter,
                hint: 'All Categories',
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Categories')),
                  ...categoryNames.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                ],
                onChanged: (value) => setState(() => _categoryFilter = value),
              ),
              const SizedBox(width: 12),

              // Severity filter
              _buildDropdown<SeverityLevel?>(
                value: _severityFilter,
                hint: 'All Severity',
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Severity')),
                  ...SeverityLevel.values.map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(_getSeverityLabel(s)),
                      )),
                ],
                onChanged: (value) => setState(() => _severityFilter = value),
              ),
              const SizedBox(width: 12),

              // Date filter
              _buildDropdown<String>(
                value: _dateFilter,
                hint: 'All Time',
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Time')),
                  DropdownMenuItem(value: '7days', child: Text('Last 7 Days')),
                  DropdownMenuItem(value: '30days', child: Text('Last 30 Days')),
                  DropdownMenuItem(value: '90days', child: Text('Last 90 Days')),
                ],
                onChanged: (value) => setState(() => _dateFilter = value ?? 'all'),
              ),
              const SizedBox(width: 12),

              // Clear filters
              if (_statusFilter != null ||
                  _categoryFilter != null ||
                  _severityFilter != null ||
                  _dateFilter != 'all' ||
                  _searchQuery.isNotEmpty)
                TextButton.icon(
                  onPressed: () => setState(() {
                    _searchQuery = '';
                    _statusFilter = null;
                    _categoryFilter = null;
                    _severityFilter = null;
                    _dateFilter = 'all';
                  }),
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('Clear'),
                ),
            ],
          ),
        ),

        // Results count
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          alignment: Alignment.centerLeft,
          child: Text(
            '${incidents.length} incidents',
            style: AppTheme.caption.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ),

        // Incidents list
        Expanded(
          child: incidents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_outlined,
                        size: 64,
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No incidents match your filters',
                        style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: incidents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final incident = incidents[index];
                    return _IncidentCard(incident: incident);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.cardBorder,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.textSecondary,
          )),
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.primaryDark,
          ),
          dropdownColor: Colors.white,
          iconEnabledColor: AppTheme.textSecondary,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  String _getStatusLabel(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.pending:
        return 'Pending';
      case IncidentStatus.underReview:
        return 'Under Review';
      case IncidentStatus.verified:
        return 'Verified';
      case IncidentStatus.resolved:
        return 'Resolved';
      case IncidentStatus.dismissed:
        return 'Dismissed';
    }
  }

  String _getSeverityLabel(SeverityLevel severity) {
    switch (severity) {
      case SeverityLevel.low:
        return 'Low';
      case SeverityLevel.moderate:
        return 'Moderate';
      case SeverityLevel.high:
        return 'High';
    }
  }
}

class _IncidentCard extends StatelessWidget {
  final IncidentModel incident;

  const _IncidentCard({required this.incident});

  void _showDetailDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _IncidentDetailDialog(incident: incident),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showDetailDialog(context),
        child: Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecorationFor(context),
      child: Row(
        children: [
          // Category icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.categoryColor(incident.categoryLabel).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.categoryColor(incident.categoryLabel),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Incident info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  incident.title,
                  style: AppTheme.headingSmall.copyWith(
                    color: AppTheme.primaryDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        incident.address,
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Category badge
          _Badge(
            label: incident.categoryLabel,
            color: AppTheme.categoryColor(incident.categoryLabel),
          ),
          const SizedBox(width: 12),

          // Severity badge
          _Badge(
            label: incident.severityLabel,
            color: AppTheme.severityColor(incident.severityLabel),
          ),
          const SizedBox(width: 12),

          // Image verification badge
          if (incident.verificationScore != null) ...[
            Tooltip(
              message: incident.verificationNote ?? 'No details',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (incident.imageVerified == true
                          ? AppTheme.successGreen
                          : AppTheme.warningOrange)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (incident.imageVerified == true
                            ? AppTheme.successGreen
                            : AppTheme.warningOrange)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      incident.imageVerified == true
                          ? Icons.verified
                          : Icons.image_not_supported_outlined,
                      size: 12,
                      color: incident.imageVerified == true
                          ? AppTheme.successGreen
                          : AppTheme.warningOrange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(incident.verificationScore! * 100).toInt()}%',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: incident.imageVerified == true
                            ? AppTheme.successGreen
                            : AppTheme.warningOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Votes
          Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.thumb_up_outlined, size: 14, color: AppTheme.successGreen),
                  const SizedBox(width: 4),
                  Text(
                    '${incident.upvotes}',
                    style: AppTheme.caption.copyWith(color: AppTheme.successGreen),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.thumb_down_outlined, size: 14, color: AppTheme.primaryRed),
                  const SizedBox(width: 4),
                  Text(
                    '${incident.downvotes}',
                    style: AppTheme.caption.copyWith(color: AppTheme.primaryRed),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 16),

          // Status chip
          _StatusChip(status: incident.status),
          const SizedBox(width: 16),

          // Actions
          _ActionButton(
            icon: Icons.edit_outlined,
            onTap: () => _showStatusDialog(context),
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.delete_outline,
            color: AppTheme.primaryRed,
            onTap: () => _showDeleteDialog(context),
          ),
        ],
      ),
        ),
      ),
    );
  }

  void _showStatusDialog(BuildContext context) {
    final noteController = TextEditingController();
    IncidentStatus selectedStatus = incident.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Update Status', style: AppTheme.headingMedium),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(incident.title, style: AppTheme.headingSmall),
                const SizedBox(height: 4),
                Text(incident.address, style: AppTheme.caption),
                const SizedBox(height: 16),
                ...IncidentStatus.values.map((status) {
                  final isSelected = selectedStatus == status;
                  return GestureDetector(
                    onTap: () => setState(() => selectedStatus = status),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _getStatusColor(status).withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? _getStatusColor(status) : AppTheme.cardBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? _getStatusColor(status) : AppTheme.cardBorder,
                                width: 2,
                              ),
                              color: isSelected ? _getStatusColor(status) : Colors.transparent,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getStatusLabel(status),
                                  style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  _getStatusDescription(status),
                                  style: AppTheme.caption,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  style: AppTheme.bodyMedium,
                  decoration: InputDecoration(
                    labelText: 'Note (Optional)',
                    labelStyle: AppTheme.caption,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.cardBorder),
                    ),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                await context.read<IncidentProvider>().updateIncidentStatus(
                      incident.id,
                      selectedStatus,
                      note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                    );
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Status updated to ${_getStatusLabel(selectedStatus)}'),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete Incident', style: AppTheme.headingMedium),
        content: Text(
          'Are you sure you want to delete "${incident.title}"?',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              context.read<IncidentProvider>().deleteIncident(incident.id);
              Navigator.pop(ctx);
            },
            child: Text('Delete', style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryRed)),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.pending:
        return 'Pending';
      case IncidentStatus.underReview:
        return 'Under Review';
      case IncidentStatus.verified:
        return 'Verified';
      case IncidentStatus.resolved:
        return 'Resolved';
      case IncidentStatus.dismissed:
        return 'Dismissed';
    }
  }

  String _getStatusDescription(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.pending:
        return 'Awaiting initial review';
      case IncidentStatus.underReview:
        return 'Being investigated';
      case IncidentStatus.verified:
        return 'Confirmed by sources';
      case IncidentStatus.resolved:
        return 'Issue addressed';
      case IncidentStatus.dismissed:
        return 'Invalid report';
    }
  }

  Color _getStatusColor(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.pending:
        return AppTheme.warningOrange;
      case IncidentStatus.underReview:
        return AppTheme.primaryDark;
      case IncidentStatus.verified:
        return AppTheme.successGreen;
      case IncidentStatus.resolved:
        return AppTheme.successGreen;
      case IncidentStatus.dismissed:
        return AppTheme.textSecondary;
    }
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IncidentStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _getStatusColor().withValues(alpha: 0.3)),
      ),
      child: Text(
        _getStatusLabel(),
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _getStatusColor(),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (status) {
      case IncidentStatus.pending:
        return AppTheme.warningOrange;
      case IncidentStatus.underReview:
        return AppTheme.primaryDark;
      case IncidentStatus.verified:
        return AppTheme.successGreen;
      case IncidentStatus.resolved:
        return AppTheme.successGreen;
      case IncidentStatus.dismissed:
        return AppTheme.textSecondary;
    }
  }

  String _getStatusLabel() {
    switch (status) {
      case IncidentStatus.pending:
        return 'Pending';
      case IncidentStatus.underReview:
        return 'Review';
      case IncidentStatus.verified:
        return 'Verified';
      case IncidentStatus.resolved:
        return 'Resolved';
      case IncidentStatus.dismissed:
        return 'Dismissed';
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.cardBorder,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: color ?? (AppTheme.primaryDark),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Incident Detail Dialog
// ─────────────────────────────────────────────

class _IncidentDetailDialog extends StatelessWidget {
  final IncidentModel incident;

  const _IncidentDetailDialog({required this.incident});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DetailHeader(incident: incident),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailInfoGrid(incident: incident),
                    const SizedBox(height: 20),
                    _DetailDescription(incident: incident),
                    if (incident.mediaUrls.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _DetailPhotos(incident: incident),
                    ],
                    if (incident.verificationScore != null) ...[
                      const SizedBox(height: 20),
                      _DetailVerification(incident: incident),
                    ],
                    if (incident.statusHistory.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _DetailStatusHistory(incident: incident),
                    ],
                  ],
                ),
              ),
            ),
            _DetailFooter(incident: incident),
          ],
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  final IncidentModel incident;

  const _DetailHeader({required this.incident});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.categoryColor(incident.categoryLabel).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.categoryColor(incident.categoryLabel),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  incident.title,
                  style: AppTheme.headingSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _DetailBadge(
                      label: incident.categoryLabel,
                      color: AppTheme.categoryColor(incident.categoryLabel),
                    ),
                    _DetailBadge(
                      label: incident.severityLabel,
                      color: AppTheme.severityColor(incident.severityLabel),
                    ),
                    _DetailStatusChip(status: incident.status),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 20),
            color: AppTheme.textSecondary,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

class _DetailInfoGrid extends StatelessWidget {
  final IncidentModel incident;

  const _DetailInfoGrid({required this.incident});

  static String _fmt(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _InfoTile(
          icon: Icons.location_on_outlined,
          label: 'Location',
          value: incident.address,
        ),
        _InfoTile(
          icon: Icons.access_time_outlined,
          label: 'Reported',
          value: _fmt(incident.reportedAt),
        ),
        _InfoTile(
          icon: incident.isAnonymous ? Icons.person_off_outlined : Icons.person_outline,
          label: 'Reporter',
          value: incident.isAnonymous ? 'Anonymous' : 'Registered User',
        ),
        _InfoTile(
          icon: Icons.thumbs_up_down_outlined,
          label: 'Votes',
          value: '${incident.upvotes} up · ${incident.downvotes} down',
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 310,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundGrey,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTheme.caption),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.primaryDark,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailDescription extends StatelessWidget {
  final IncidentModel incident;

  const _DetailDescription({required this.incident});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Description', style: AppTheme.headingSmall),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.backgroundGrey,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Text(
            incident.description.isEmpty ? 'No description provided.' : incident.description,
            style: AppTheme.bodyMedium.copyWith(
              color: incident.description.isEmpty
                  ? AppTheme.textSecondary
                  : AppTheme.primaryDark,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailPhotos extends StatelessWidget {
  final IncidentModel incident;

  const _DetailPhotos({required this.incident});

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photos (${incident.mediaUrls.length})',
          style: AppTheme.headingSmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: incident.mediaUrls.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final url = incident.mediaUrls[index];
              return GestureDetector(
                onTap: () => _showFullImage(context, url),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    url,
                    width: 240,
                    height: 180,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : Container(
                            width: 240,
                            height: 180,
                            color: AppTheme.backgroundGrey,
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                    errorBuilder: (_, __, ___) => Container(
                      width: 240,
                      height: 180,
                      color: AppTheme.backgroundGrey,
                      child: const Icon(Icons.broken_image_outlined, color: AppTheme.textSecondary),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DetailVerification extends StatelessWidget {
  final IncidentModel incident;

  const _DetailVerification({required this.incident});

  @override
  Widget build(BuildContext context) {
    final isVerified = incident.imageVerified == true;
    final color = isVerified ? AppTheme.successGreen : AppTheme.warningOrange;
    final score = ((incident.verificationScore ?? 0) * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Image Verification', style: AppTheme.headingSmall),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isVerified ? Icons.verified_outlined : Icons.warning_amber_outlined,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isVerified ? 'Image Verified' : 'Needs Manual Review',
                          style: AppTheme.headingSmall.copyWith(color: color, fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$score% confidence',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (incident.verificationNote != null &&
                        incident.verificationNote!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        incident.verificationNote!,
                        style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailStatusHistory extends StatelessWidget {
  final IncidentModel incident;

  const _DetailStatusHistory({required this.incident});

  Color _statusColor(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.pending:
        return AppTheme.warningOrange;
      case IncidentStatus.underReview:
        return AppTheme.primaryDark;
      case IncidentStatus.verified:
        return AppTheme.successGreen;
      case IncidentStatus.resolved:
        return AppTheme.successGreen;
      case IncidentStatus.dismissed:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = incident.statusHistory.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Status History', style: AppTheme.headingSmall),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.backgroundGrey,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(
            children: history.asMap().entries.map((entry) {
              final isLast = entry.key == history.length - 1;
              final item = entry.value;
              final color = _statusColor(item.status);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(top: 3),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 36,
                          color: AppTheme.cardBorder,
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                item.statusLabel,
                                style: AppTheme.bodyMedium.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(item.timeAgo, style: AppTheme.caption),
                            ],
                          ),
                          if (item.note != null && item.note!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              item.note!,
                              style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _DetailFooter extends StatelessWidget {
  final IncidentModel incident;

  const _DetailFooter({required this.incident});

  void _showStatusDialog(BuildContext context) {
    final noteController = TextEditingController();
    IncidentStatus selectedStatus = incident.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Update Status', style: AppTheme.headingMedium),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(incident.title, style: AppTheme.headingSmall),
                const SizedBox(height: 4),
                Text(incident.address, style: AppTheme.caption),
                const SizedBox(height: 16),
                ...IncidentStatus.values.map((status) {
                  final isSelected = selectedStatus == status;
                  final color = _statusColor(status);
                  return GestureDetector(
                    onTap: () => setState(() => selectedStatus = status),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? color : AppTheme.cardBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? color : AppTheme.cardBorder,
                                width: 2,
                              ),
                              color: isSelected ? color : Colors.transparent,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _statusLabel(status),
                                  style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(_statusDescription(status), style: AppTheme.caption),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  style: AppTheme.bodyMedium,
                  decoration: InputDecoration(
                    labelText: 'Note (Optional)',
                    labelStyle: AppTheme.caption,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.cardBorder),
                    ),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                await context.read<IncidentProvider>().updateIncidentStatus(
                      incident.id,
                      selectedStatus,
                      note: noteController.text.trim().isEmpty
                          ? null
                          : noteController.text.trim(),
                    );
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Status updated to ${_statusLabel(selectedStatus)}'),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete Incident', style: AppTheme.headingMedium),
        content: Text(
          'Are you sure you want to delete "${incident.title}"? This cannot be undone.',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              context.read<IncidentProvider>().deleteIncident(incident.id);
              Navigator.pop(ctx);
              Navigator.pop(context); // also close detail dialog
            },
            child: Text('Delete',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryRed)),
          ),
        ],
      ),
    );
  }

  String _statusLabel(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.pending:
        return 'Pending';
      case IncidentStatus.underReview:
        return 'Under Review';
      case IncidentStatus.verified:
        return 'Verified';
      case IncidentStatus.resolved:
        return 'Resolved';
      case IncidentStatus.dismissed:
        return 'Dismissed';
    }
  }

  String _statusDescription(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.pending:
        return 'Awaiting initial review';
      case IncidentStatus.underReview:
        return 'Being investigated';
      case IncidentStatus.verified:
        return 'Confirmed by sources';
      case IncidentStatus.resolved:
        return 'Issue addressed';
      case IncidentStatus.dismissed:
        return 'Invalid report';
    }
  }

  Color _statusColor(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.pending:
        return AppTheme.warningOrange;
      case IncidentStatus.underReview:
        return AppTheme.primaryDark;
      case IncidentStatus.verified:
        return AppTheme.successGreen;
      case IncidentStatus.resolved:
        return AppTheme.successGreen;
      case IncidentStatus.dismissed:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () => _showDeleteDialog(context),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryRed,
              side: const BorderSide(color: AppTheme.primaryRed),
              textStyle: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _showStatusDialog(context),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Update Status'),
            style: ElevatedButton.styleFrom(
              textStyle: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _DetailBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _DetailStatusChip extends StatelessWidget {
  final IncidentStatus status;

  const _DetailStatusChip({required this.status});

  Color _color() {
    switch (status) {
      case IncidentStatus.pending:
        return AppTheme.warningOrange;
      case IncidentStatus.underReview:
        return AppTheme.primaryDark;
      case IncidentStatus.verified:
        return AppTheme.successGreen;
      case IncidentStatus.resolved:
        return AppTheme.successGreen;
      case IncidentStatus.dismissed:
        return AppTheme.textSecondary;
    }
  }

  String _label() {
    switch (status) {
      case IncidentStatus.pending:
        return 'Pending';
      case IncidentStatus.underReview:
        return 'Under Review';
      case IncidentStatus.verified:
        return 'Verified';
      case IncidentStatus.resolved:
        return 'Resolved';
      case IncidentStatus.dismissed:
        return 'Dismissed';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        _label(),
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
