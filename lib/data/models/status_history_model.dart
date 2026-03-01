import 'package:cloud_firestore/cloud_firestore.dart';
import 'incident_model.dart';

class StatusHistoryEntry {
  final IncidentStatus status;
  final DateTime timestamp;
  final String? updatedBy;
  final String? note;

  StatusHistoryEntry({
    required this.status,
    required this.timestamp,
    this.updatedBy,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'status': status.index,
      'timestamp': Timestamp.fromDate(timestamp),
      'updatedBy': updatedBy,
      'note': note,
    };
  }

  factory StatusHistoryEntry.fromMap(Map<String, dynamic> map) {
    return StatusHistoryEntry(
      status: IncidentStatus.values[map['status'] ?? 0],
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      updatedBy: map['updatedBy'],
      note: map['note'],
    );
  }

  String get statusLabel {
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

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}
