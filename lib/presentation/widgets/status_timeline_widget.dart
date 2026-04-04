import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/incident_model.dart';
import '../../data/models/status_history_model.dart';
import '../../data/repositories/user_repository.dart';
import '../../utils/app_theme.dart';

class StatusTimelineWidget extends StatefulWidget {
  final IncidentModel incident;

  const StatusTimelineWidget({super.key, required this.incident});

  @override
  State<StatusTimelineWidget> createState() => _StatusTimelineWidgetState();
}

class _StatusTimelineWidgetState extends State<StatusTimelineWidget> {
  final _userRepository = UserRepository();
  Map<String, String> _userNames = {};

  @override
  void initState() {
    super.initState();
    _resolveUserNames();
  }

  @override
  void didUpdateWidget(StatusTimelineWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.incident.id != widget.incident.id ||
        oldWidget.incident.statusHistory.length !=
            widget.incident.statusHistory.length) {
      _resolveUserNames();
    }
  }

  Future<void> _resolveUserNames() async {
    final ids = widget.incident.statusHistory
        .map((e) => e.updatedBy)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (ids.isEmpty) return;

    final users = await _userRepository.getUsersByIds(ids);
    if (!mounted) return;
    setState(() {
      _userNames = {for (final u in users) u.id: u.name};
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = _buildTimelineEntries();

    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.timeline,
              size: 18,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            const Text(
              'Status Timeline',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...entries.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == entries.length - 1;
          final isFirst = index == 0;

          final resolvedName = item.updatedBy != null
              ? (_userNames[item.updatedBy] ?? item.updatedBy)
              : null;

          return _TimelineEntry(
            status: item.status,
            timestamp: item.timestamp,
            note: item.note,
            updatedBy: resolvedName,
            isFirst: isFirst,
            isLast: isLast,
            isCurrent: isFirst,
          );
        }),
      ],
    );
  }

  List<StatusHistoryEntry> _buildTimelineEntries() {
    final List<StatusHistoryEntry> entries = [];

    // Add current status if no history exists
    if (widget.incident.statusHistory.isEmpty) {
      // Add current status first (newest) if different from pending
      if (widget.incident.status != IncidentStatus.pending) {
        entries.add(StatusHistoryEntry(
          status: widget.incident.status,
          timestamp: widget.incident.statusUpdatedAt ?? DateTime.now(),
          note: widget.incident.statusNote,
        ));
      }

      // Add initial "reported" entry last (oldest)
      entries.add(StatusHistoryEntry(
        status: IncidentStatus.pending,
        timestamp: widget.incident.reportedAt,
        note: 'Incident reported',
      ));
    } else {
      // Use actual history, sorted by timestamp descending (most recent first)
      entries.addAll(widget.incident.statusHistory.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp)));

      // Add initial "reported" entry if not in history
      final hasInitialEntry =
          entries.any((e) => e.timestamp == widget.incident.reportedAt);
      if (!hasInitialEntry) {
        entries.add(StatusHistoryEntry(
          status: IncidentStatus.pending,
          timestamp: widget.incident.reportedAt,
          note: 'Incident reported',
        ));
      }
    }

    return entries;
  }
}

class _TimelineEntry extends StatelessWidget {
  final IncidentStatus status;
  final DateTime timestamp;
  final String? note;
  final String? updatedBy;
  final bool isFirst;
  final bool isLast;
  final bool isCurrent;

  const _TimelineEntry({
    required this.status,
    required this.timestamp,
    this.note,
    this.updatedBy,
    required this.isFirst,
    required this.isLast,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line and dot
          SizedBox(
            width: 24,
            child: Column(
              children: [
                // Top line
                Container(
                  width: 2,
                  height: 8,
                  color: isFirst
                      ? Colors.transparent
                      : (AppTheme.cardBorder),
                ),
                // Dot
                Container(
                  width: isCurrent ? 16 : 12,
                  height: isCurrent ? 16 : 12,
                  decoration: BoxDecoration(
                    color: isCurrent ? color : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color,
                      width: 2,
                    ),
                  ),
                ),
                // Bottom line
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : (AppTheme.cardBorder),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _getStatusLabel(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatTimestamp(),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (note != null && note!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      note!,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                  ],
                  if (updatedBy != null && updatedBy!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'by $updatedBy',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel() {
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

  String _formatTimestamp() {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return DateFormat('MMM d, y').format(timestamp);
  }
}
