import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/incident_model.dart';
import '../../data/models/status_history_model.dart';
import '../../utils/app_theme.dart';

class StatusTimelineWidget extends StatelessWidget {
  final IncidentModel incident;

  const StatusTimelineWidget({super.key, required this.incident});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Build timeline entries from status history
    final entries = _buildTimelineEntries();

    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.timeline,
              size: 18,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              'Status Timeline',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryDark,
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

          return _TimelineEntry(
            status: item.status,
            timestamp: item.timestamp,
            note: item.note,
            updatedBy: item.updatedBy,
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
    if (incident.statusHistory.isEmpty) {
      // Add initial "reported" entry
      entries.add(StatusHistoryEntry(
        status: IncidentStatus.pending,
        timestamp: incident.reportedAt,
        note: 'Incident reported',
      ));

      // Add current status if different from pending
      if (incident.status != IncidentStatus.pending) {
        entries.add(StatusHistoryEntry(
          status: incident.status,
          timestamp: incident.statusUpdatedAt ?? DateTime.now(),
          note: incident.statusNote,
        ));
      }
    } else {
      // Use actual history, sorted by timestamp descending (most recent first)
      entries.addAll(incident.statusHistory.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp)));

      // Add initial "reported" entry if not in history
      final hasInitialEntry =
          entries.any((e) => e.timestamp == incident.reportedAt);
      if (!hasInitialEntry) {
        entries.add(StatusHistoryEntry(
          status: IncidentStatus.pending,
          timestamp: incident.reportedAt,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                      : (isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder),
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
                        : (isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder),
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
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textSecondary,
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
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.primaryDark,
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
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary,
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
        return AppTheme.accentBlue;
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
