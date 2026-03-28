import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AuditLogModel {
  final String id;
  final String adminId;
  final String adminName;
  final String action;

  /// Broad category: 'user', 'flag', 'config', 'community', 'incident'
  final String targetType;
  final String targetId;
  final String detail;
  final DateTime timestamp;

  AuditLogModel({
    required this.id,
    required this.adminId,
    required this.adminName,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.detail,
    required this.timestamp,
  });

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return DateFormat('MMM d, y').format(timestamp);
  }

  String get formattedTime => DateFormat('MMM d, y · HH:mm').format(timestamp);

  Map<String, dynamic> toMap() {
    return {
      'adminId': adminId,
      'adminName': adminName,
      'action': action,
      'targetType': targetType,
      'targetId': targetId,
      'detail': detail,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory AuditLogModel.fromMap(Map<String, dynamic> map, String id) {
    return AuditLogModel(
      id: id,
      adminId: map['adminId'] ?? '',
      adminName: map['adminName'] ?? '',
      action: map['action'] ?? '',
      targetType: map['targetType'] ?? '',
      targetId: map['targetId'] ?? '',
      detail: map['detail'] ?? '',
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
