import 'package:cloud_firestore/cloud_firestore.dart';

enum FlagTargetType { incident, comment, user }
enum FlagStatus { pending, reviewed, resolved, dismissed }

class FlagModel {
  final String id;
  final FlagTargetType targetType;
  final String targetId;
  final String reporterId;
  final String reporterName;
  final String reason;
  final String? details;
  final FlagStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? resolutionNote;

  FlagModel({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reporterId,
    required this.reporterName,
    required this.reason,
    this.details,
    this.status = FlagStatus.pending,
    required this.createdAt,
    this.resolvedAt,
    this.resolvedBy,
    this.resolutionNote,
  });

  String get targetTypeLabel {
    switch (targetType) {
      case FlagTargetType.incident:
        return 'Incident';
      case FlagTargetType.comment:
        return 'Comment';
      case FlagTargetType.user:
        return 'User';
    }
  }

  String get statusLabel {
    switch (status) {
      case FlagStatus.pending:
        return 'Pending';
      case FlagStatus.reviewed:
        return 'Reviewed';
      case FlagStatus.resolved:
        return 'Resolved';
      case FlagStatus.dismissed:
        return 'Dismissed';
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  Map<String, dynamic> toMap() {
    return {
      'targetType': targetType.index,
      'targetId': targetId,
      'reporterId': reporterId,
      'reporterName': reporterName,
      'reason': reason,
      'details': details,
      'status': status.index,
      'createdAt': Timestamp.fromDate(createdAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'resolvedBy': resolvedBy,
      'resolutionNote': resolutionNote,
    };
  }

  factory FlagModel.fromMap(Map<String, dynamic> map, String id) {
    return FlagModel(
      id: id,
      targetType: FlagTargetType.values[map['targetType'] ?? 0],
      targetId: map['targetId'] ?? '',
      reporterId: map['reporterId'] ?? '',
      reporterName: map['reporterName'] ?? 'Anonymous',
      reason: map['reason'] ?? '',
      details: map['details'],
      status: FlagStatus.values[map['status'] ?? 0],
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      resolvedAt: map['resolvedAt'] is Timestamp
          ? (map['resolvedAt'] as Timestamp).toDate()
          : null,
      resolvedBy: map['resolvedBy'],
      resolutionNote: map['resolutionNote'],
    );
  }

  FlagModel copyWith({
    String? id,
    FlagTargetType? targetType,
    String? targetId,
    String? reporterId,
    String? reporterName,
    String? reason,
    String? details,
    FlagStatus? status,
    DateTime? createdAt,
    DateTime? resolvedAt,
    String? resolvedBy,
    String? resolutionNote,
  }) {
    return FlagModel(
      id: id ?? this.id,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      reporterId: reporterId ?? this.reporterId,
      reporterName: reporterName ?? this.reporterName,
      reason: reason ?? this.reason,
      details: details ?? this.details,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolutionNote: resolutionNote ?? this.resolutionNote,
    );
  }
}
