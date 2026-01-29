import 'package:cloud_firestore/cloud_firestore.dart';

enum IncidentCategory {
  crime,
  infrastructure,
  suspicious,
  traffic,
  environmental,
  emergency,
}

enum SeverityLevel { low, moderate, high }

enum IncidentStatus {
  pending,
  underReview,
  verified,
  resolved,
  dismissed,
}

class IncidentModel {
  final String id;
  final String title;
  final IncidentCategory category;
  final SeverityLevel severity;
  final String description;
  final double latitude;
  final double longitude;
  final String address;
  final DateTime reportedAt;
  final String reporterId;
  final bool isAnonymous;
  final List<String> mediaUrls;
  final int confirmations;
  final IncidentStatus status;
  final DateTime? statusUpdatedAt;
  final String? statusNote;

  IncidentModel({
    required this.id,
    required this.title,
    required this.category,
    required this.severity,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.reportedAt,
    required this.reporterId,
    this.isAnonymous = false,
    this.mediaUrls = const [],
    this.confirmations = 0,
    this.status = IncidentStatus.pending,
    this.statusUpdatedAt,
    this.statusNote,
  });

  String get categoryLabel {
    switch (category) {
      case IncidentCategory.crime:
        return 'Crime';
      case IncidentCategory.infrastructure:
        return 'Infrastructure';
      case IncidentCategory.suspicious:
        return 'Suspicious';
      case IncidentCategory.traffic:
        return 'Traffic';
      case IncidentCategory.environmental:
        return 'Environmental';
      case IncidentCategory.emergency:
        return 'Emergency';
    }
  }

  String get severityLabel {
    switch (severity) {
      case SeverityLevel.low:
        return 'Low';
      case SeverityLevel.moderate:
        return 'Moderate';
      case SeverityLevel.high:
        return 'High';
    }
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
    final diff = DateTime.now().difference(reportedAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  bool get isActive =>
      status != IncidentStatus.resolved && status != IncidentStatus.dismissed;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category.index,
      'severity': severity.index,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'reportedAt': Timestamp.fromDate(reportedAt),
      'reporterId': reporterId,
      'isAnonymous': isAnonymous,
      'mediaUrls': mediaUrls,
      'confirmations': confirmations,
      'status': status.index,
      'statusUpdatedAt':
          statusUpdatedAt != null ? Timestamp.fromDate(statusUpdatedAt!) : null,
      'statusNote': statusNote,
    };
  }

  factory IncidentModel.fromMap(Map<String, dynamic> map, String id) {
    return IncidentModel(
      id: id,
      title: map['title'] ?? '',
      category: IncidentCategory.values[map['category'] ?? 0],
      severity: SeverityLevel.values[map['severity'] ?? 0],
      description: map['description'] ?? '',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      address: map['address'] ?? '',
      reportedAt: map['reportedAt'] is Timestamp
          ? (map['reportedAt'] as Timestamp).toDate()
          : DateTime.now(),
      reporterId: map['reporterId'] ?? '',
      isAnonymous: map['isAnonymous'] ?? false,
      mediaUrls: List<String>.from(map['mediaUrls'] ?? []),
      confirmations: map['confirmations'] ?? 0,
      status: IncidentStatus.values[map['status'] ?? 0],
      statusUpdatedAt: map['statusUpdatedAt'] is Timestamp
          ? (map['statusUpdatedAt'] as Timestamp).toDate()
          : null,
      statusNote: map['statusNote'],
    );
  }

  IncidentModel copyWith({
    String? id,
    String? title,
    IncidentCategory? category,
    SeverityLevel? severity,
    String? description,
    double? latitude,
    double? longitude,
    String? address,
    DateTime? reportedAt,
    String? reporterId,
    bool? isAnonymous,
    List<String>? mediaUrls,
    int? confirmations,
    IncidentStatus? status,
    DateTime? statusUpdatedAt,
    String? statusNote,
  }) {
    return IncidentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      reportedAt: reportedAt ?? this.reportedAt,
      reporterId: reporterId ?? this.reporterId,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      confirmations: confirmations ?? this.confirmations,
      status: status ?? this.status,
      statusUpdatedAt: statusUpdatedAt ?? this.statusUpdatedAt,
      statusNote: statusNote ?? this.statusNote,
    );
  }
}
