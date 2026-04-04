part of '../community_manager_screen.dart';

// ── All Incidents Tab (community manager view) ───────────────────────────────

class _AllIncidentsTab extends StatefulWidget {
  final String communityId;

  const _AllIncidentsTab({required this.communityId});

  @override
  State<_AllIncidentsTab> createState() => _AllIncidentsTabState();
}

class _AllIncidentsTabState extends State<_AllIncidentsTab> {
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

  void _showStatusDialog(IncidentModel incident) {
    final noteController = TextEditingController();
    IncidentStatus selectedStatus = incident.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Text('Update Status', style: AppTheme.headingMedium),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(incident.title,
                      style: AppTheme.headingSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 16),
                  ...IncidentStatus.values.map((status) {
                    final isSelected = selectedStatus == status;
                    final color = _statusColor(status);
                    return GestureDetector(
                      onTap: () =>
                          setDialogState(() => selectedStatus = status),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withValues(alpha: 0.1)
                              : Colors.transparent,
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
                                  color:
                                      isSelected ? color : AppTheme.cardBorder,
                                  width: 2,
                                ),
                                color:
                                    isSelected ? color : Colors.transparent,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      size: 14, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_statusLabel(status),
                                      style: AppTheme.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w700)),
                                  Text(_statusDescription(status),
                                      style: AppTheme.caption),
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
                        borderSide:
                            const BorderSide(color: AppTheme.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppTheme.cardBorder),
                      ),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: AppTheme.bodyMedium
                      .copyWith(color: AppTheme.textSecondary)),
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
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        'Status updated to ${_statusLabel(selectedStatus)}'),
                    backgroundColor: AppTheme.successGreen,
                  ));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final all = context.watch<IncidentProvider>().communityIncidents;
    final pending =
        all.where((i) => i.status == IncidentStatus.pending).toList();
    final active = all
        .where((i) => i.status != IncidentStatus.pending)
        .toList()
      ..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));

    if (all.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_outlined,
                size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text('No incident reports',
                style: TextStyle(fontSize: 18, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Text('No incidents have been shared with this community',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (pending.isNotEmpty) ...[
          _SectionHeader(label: 'Pending Review (${pending.length})'),
          const SizedBox(height: 8),
          ...pending.map((incident) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PendingIncidentCard(
                  incident: incident,
                  onApprove: () => _approve(incident),
                  onReject: () => _reject(incident),
                ),
              )),
        ],
        if (active.isNotEmpty) ...[
          if (pending.isNotEmpty) const SizedBox(height: 4),
          _SectionHeader(label: 'All Incidents (${active.length})'),
          const SizedBox(height: 8),
          ...active.map((incident) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ActiveIncidentCard(
                  incident: incident,
                  statusColor: _statusColor(incident.status),
                  statusLabel: _statusLabel(incident.status),
                  onUpdateStatus: () => _showStatusDialog(incident),
                ),
              )),
        ],
      ],
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: AppTheme.caption.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ));
  }
}

// ── Pending incident card (approve / dismiss) ─────────────────────────────────

class _PendingIncidentCard extends StatelessWidget {
  final IncidentModel incident;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingIncidentCard({
    required this.incident,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isHigh = incident.severity == SeverityLevel.high;
    final severityColor =
        isHigh ? AppTheme.primaryRed : AppTheme.warningOrange;

    return Container(
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => IncidentBottomSheet(incidentId: incident.id),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
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
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Approve'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.successGreen,
                      side: BorderSide(
                          color: AppTheme.successGreen.withValues(alpha: 0.6)),
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
  }
}

// ── Active incident card (status chip + update status button) ─────────────────

class _ActiveIncidentCard extends StatelessWidget {
  final IncidentModel incident;
  final Color statusColor;
  final String statusLabel;
  final VoidCallback onUpdateStatus;

  const _ActiveIncidentCard({
    required this.incident,
    required this.statusColor,
    required this.statusLabel,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isHigh = incident.severity == SeverityLevel.high;
    final severityColor =
        isHigh ? AppTheme.primaryRed : AppTheme.warningOrange;

    return Container(
      decoration: AppTheme.cardDecoration,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => IncidentBottomSheet(incidentId: incident.id),
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${incident.categoryLabel}  •  ${incident.timeAgo}',
                            style: AppTheme.caption,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusLabel,
                            style: AppTheme.caption.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined,
                    size: 18, color: AppTheme.textSecondary),
                tooltip: 'Update Status',
                onPressed: onUpdateStatus,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
