part of '../community_detail_screen.dart';

// ── Reports Tab (community incidents) ────────────────────────────────────────

class _CommunityIncidentsTab extends StatefulWidget {
  final String communityId;

  const _CommunityIncidentsTab({required this.communityId});

  @override
  State<_CommunityIncidentsTab> createState() => _CommunityIncidentsTabState();
}

class _CommunityIncidentsTabState extends State<_CommunityIncidentsTab> {
  late final IncidentProvider _incidentProvider;

  @override
  void initState() {
    super.initState();
    _incidentProvider = context.read<IncidentProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _incidentProvider.watchCommunityIncidents(widget.communityId);
    });
  }

  @override
  void dispose() {
    _incidentProvider.stopWatchingCommunityIncidents();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<IncidentProvider>().communityIncidents;
    // Show only non-pending, non-dismissed incidents
    final incidents = all
        .where((i) =>
            i.status != IncidentStatus.pending &&
            i.status != IncidentStatus.dismissed)
        .toList();

    return Stack(
      children: [
        incidents.isEmpty
            ? Center(
                child: _EmptyState(
                  icon: Icons.warning_amber_outlined,
                  message: 'No incident reports yet.\nBe the first to report!',
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: incidents.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final incident = incidents[i];
                  final isHigh = incident.severity == SeverityLevel.high;
                  final severityColor =
                      isHigh ? AppTheme.primaryRed : AppTheme.warningOrange;
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
                              crossAxisAlignment: CrossAxisAlignment.start,
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
}
