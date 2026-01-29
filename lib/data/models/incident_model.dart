enum IncidentCategory {
  crime,
  infrastructure,
  suspicious,
  traffic,
  environmental,
  emergency,
}

enum SeverityLevel { low, moderate, high }

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

  String get timeAgo {
    final diff = DateTime.now().difference(reportedAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category.index,
      'severity': severity.index,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'reportedAt': reportedAt.millisecondsSinceEpoch,
      'reporterId': reporterId,
      'isAnonymous': isAnonymous,
      'mediaUrls': mediaUrls,
      'confirmations': confirmations,
    };
  }

  factory IncidentModel.fromMap(String id, Map<String, dynamic> map) {
    return IncidentModel(
      id: id,
      title: map['title'] ?? '',
      category: IncidentCategory.values[map['category'] ?? 0],
      severity: SeverityLevel.values[map['severity'] ?? 0],
      description: map['description'] ?? '',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      address: map['address'] ?? '',
      reportedAt: DateTime.fromMillisecondsSinceEpoch(map['reportedAt'] ?? 0),
      reporterId: map['reporterId'] ?? '',
      isAnonymous: map['isAnonymous'] ?? false,
      mediaUrls: List<String>.from(map['mediaUrls'] ?? []),
      confirmations: map['confirmations'] ?? 0,
    );
  }
}
