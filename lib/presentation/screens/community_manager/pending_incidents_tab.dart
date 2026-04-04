part of '../community_manager_screen.dart';

// ── Pending Incidents Tab ────────────────────────────────────────────────────

class _PendingIncidentsTab extends StatefulWidget {
  final String communityId;

  const _PendingIncidentsTab({required this.communityId});

  @override
  State<_PendingIncidentsTab> createState() => _PendingIncidentsTabState();
}

class _PendingIncidentsTabState extends State<_PendingIncidentsTab> {
  Future<void> _approve(IncidentModel incident) async {
    final provider = context.read<IncidentProvider>();
    final staffId = context.read<UserProvider>().currentUser?.id ?? '';
    final ok = await provider.approveCommunityIncident(incident.id, staffId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Incident approved — now visible on map'
            : (provider.error ?? 'Failed to approve')),
        backgroundColor: ok ? AppTheme.successGreen : AppTheme.primaryRed,
      ));
    }
  }

  Future<void> _reject(IncidentModel incident) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Report'),
        content: Text('Dismiss "${incident.title}"? It will not appear on the map.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Dismiss',
                style: TextStyle(color: AppTheme.primaryRed)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<IncidentProvider>();
    final staffId = context.read<UserProvider>().currentUser?.id ?? '';
    final ok = await provider.rejectCommunityIncident(incident.id, staffId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Report dismissed' : (provider.error ?? 'Failed')),
        backgroundColor: ok ? AppTheme.warningOrange : AppTheme.primaryRed,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final incidents = context.watch<IncidentProvider>().pendingCommunityIncidents;

    if (incidents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text('No pending reports',
                style: TextStyle(fontSize: 18, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Text('All incident reports have been reviewed',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: incidents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final incident = incidents[i];
        final isHigh = incident.severity == SeverityLevel.high;
        final severityColor = isHigh ? AppTheme.primaryRed : AppTheme.warningOrange;

        return Container(
          decoration: AppTheme.cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tap to preview in bottom sheet
              InkWell(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) =>
                      IncidentBottomSheet(incidentId: incident.id),
                ),
                child: Padding(
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
              ),
              // Approve / Dismiss action row
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _reject(incident),
                        icon: const Icon(Icons.cancel_outlined, size: 16),
                        label: const Text('Dismiss'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryRed,
                          side: BorderSide(
                              color: AppTheme.primaryRed.withValues(alpha: 0.6)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          textStyle: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _approve(incident),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Approve'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.successGreen,
                          side: BorderSide(
                              color: AppTheme.successGreen
                                  .withValues(alpha: 0.6)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          textStyle: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
