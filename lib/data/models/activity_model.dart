import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

enum ActivityType { memberJoined, roleChanged, incidentAdded, incidentResolved }

class ActivityModel {
  final String id;
  final ActivityType type;
  final String actorId;
  final String? targetId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  ActivityModel({
    required this.id,
    required this.type,
    required this.actorId,
    this.targetId,
    required this.metadata,
    required this.createdAt,
  });

  String get description {
    switch (type) {
      case ActivityType.memberJoined:
        return metadata['invited'] == true
            ? 'A member was invited to join'
            : 'A new member joined';
      case ActivityType.roleChanged:
        final role = metadata['role'] as String? ?? 'member';
        return 'Member role changed to $role';
      case ActivityType.incidentAdded:
        final title = metadata['title'] as String?;
        return title != null ? 'New report: $title' : 'New incident reported';
      case ActivityType.incidentResolved:
        final title = metadata['title'] as String?;
        return title != null ? 'Report resolved: $title' : 'Incident resolved';
    }
  }

  IconData get icon {
    switch (type) {
      case ActivityType.memberJoined:
        return Icons.person_add_outlined;
      case ActivityType.roleChanged:
        return Icons.shield_outlined;
      case ActivityType.incidentAdded:
        return Icons.warning_amber_outlined;
      case ActivityType.incidentResolved:
        return Icons.check_circle_outline;
    }
  }

  Color get iconColor {
    switch (type) {
      case ActivityType.memberJoined:
        return AppTheme.successGreen;
      case ActivityType.roleChanged:
        return AppTheme.warningOrange;
      case ActivityType.incidentAdded:
        return AppTheme.primaryRed;
      case ActivityType.incidentResolved:
        return AppTheme.successGreen;
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt.day.toString().padLeft(2, '0')}-'
        '${createdAt.month.toString().padLeft(2, '0')}-'
        '${createdAt.year}';
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.index,
      'actorId': actorId,
      'targetId': targetId,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ActivityModel.fromMap(Map<String, dynamic> map, String id) {
    return ActivityModel(
      id: id,
      type: ActivityType.values[map['type'] as int? ?? 0],
      actorId: map['actorId'] as String? ?? '',
      targetId: map['targetId'] as String?,
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
