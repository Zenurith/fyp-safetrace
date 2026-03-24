import 'package:cloud_firestore/cloud_firestore.dart';

class SystemConfigModel {
  final bool announcementEnabled;
  final String announcementMessage;

  final int pointsForReport;
  final int pointsForUpvoteReceived;
  final int pointsForDownvoteReceived;
  final int trustedThreshold;

  final double defaultAlertRadiusKm;
  final int maxAlertsPerHour;

  final DateTime? updatedAt;
  final String? updatedBy;

  const SystemConfigModel({
    required this.announcementEnabled,
    required this.announcementMessage,
    required this.pointsForReport,
    required this.pointsForUpvoteReceived,
    required this.pointsForDownvoteReceived,
    required this.trustedThreshold,
    required this.defaultAlertRadiusKm,
    required this.maxAlertsPerHour,
    this.updatedAt,
    this.updatedBy,
  });

  static const SystemConfigModel defaults = SystemConfigModel(
    announcementEnabled: false,
    announcementMessage: '',
    pointsForReport: 10,
    pointsForUpvoteReceived: 5,
    pointsForDownvoteReceived: -3,
    trustedThreshold: 500,
    defaultAlertRadiusKm: 5.0,
    maxAlertsPerHour: 10,
  );

  factory SystemConfigModel.fromMap(Map<String, dynamic> map) {
    return SystemConfigModel(
      announcementEnabled: map['announcementEnabled'] ?? false,
      announcementMessage: map['announcementMessage'] ?? '',
      pointsForReport: map['pointsForReport'] ?? 10,
      pointsForUpvoteReceived: map['pointsForUpvoteReceived'] ?? 5,
      pointsForDownvoteReceived: map['pointsForDownvoteReceived'] ?? -3,
      trustedThreshold: map['trustedThreshold'] ?? 500,
      defaultAlertRadiusKm: (map['defaultAlertRadiusKm'] ?? 5.0).toDouble(),
      maxAlertsPerHour: map['maxAlertsPerHour'] ?? 10,
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      updatedBy: map['updatedBy'],
    );
  }

  Map<String, dynamic> toMap() => {
        'announcementEnabled': announcementEnabled,
        'announcementMessage': announcementMessage,
        'pointsForReport': pointsForReport,
        'pointsForUpvoteReceived': pointsForUpvoteReceived,
        'pointsForDownvoteReceived': pointsForDownvoteReceived,
        'trustedThreshold': trustedThreshold,
        'defaultAlertRadiusKm': defaultAlertRadiusKm,
        'maxAlertsPerHour': maxAlertsPerHour,
        'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
        'updatedBy': updatedBy,
      };

  SystemConfigModel copyWith({
    bool? announcementEnabled,
    String? announcementMessage,
    int? pointsForReport,
    int? pointsForUpvoteReceived,
    int? pointsForDownvoteReceived,
    int? trustedThreshold,
    double? defaultAlertRadiusKm,
    int? maxAlertsPerHour,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return SystemConfigModel(
      announcementEnabled: announcementEnabled ?? this.announcementEnabled,
      announcementMessage: announcementMessage ?? this.announcementMessage,
      pointsForReport: pointsForReport ?? this.pointsForReport,
      pointsForUpvoteReceived:
          pointsForUpvoteReceived ?? this.pointsForUpvoteReceived,
      pointsForDownvoteReceived:
          pointsForDownvoteReceived ?? this.pointsForDownvoteReceived,
      trustedThreshold: trustedThreshold ?? this.trustedThreshold,
      defaultAlertRadiusKm: defaultAlertRadiusKm ?? this.defaultAlertRadiusKm,
      maxAlertsPerHour: maxAlertsPerHour ?? this.maxAlertsPerHour,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
