import 'incident_model.dart';

class AlertSettingsModel {
  final double radiusKm;
  final Set<SeverityLevel> severityFilters;
  final Set<IncidentCategory> categoryFilters;
  final bool activeHoursEnabled;
  final String activeFrom;
  final String activeTo;

  AlertSettingsModel({
    this.radiusKm = 2.0,
    Set<SeverityLevel>? severityFilters,
    Set<IncidentCategory>? categoryFilters,
    this.activeHoursEnabled = true,
    this.activeFrom = '07:00 AM',
    this.activeTo = '11:00 PM',
  })  : severityFilters = severityFilters ??
            {SeverityLevel.high, SeverityLevel.moderate},
        categoryFilters = categoryFilters ??
            {
              IncidentCategory.crime,
              IncidentCategory.traffic,
              IncidentCategory.emergency,
            };

  Map<String, dynamic> toMap() {
    return {
      'radiusKm': radiusKm,
      'severityFilters': severityFilters.map((e) => e.index).toList(),
      'categoryFilters': categoryFilters.map((e) => e.index).toList(),
      'activeHoursEnabled': activeHoursEnabled,
      'activeFrom': activeFrom,
      'activeTo': activeTo,
    };
  }

  factory AlertSettingsModel.fromMap(Map<String, dynamic> map) {
    return AlertSettingsModel(
      radiusKm: (map['radiusKm'] ?? 2.0).toDouble(),
      severityFilters: (map['severityFilters'] as List?)
          ?.map((i) => SeverityLevel.values[i as int])
          .toSet(),
      categoryFilters: (map['categoryFilters'] as List?)
          ?.map((i) => IncidentCategory.values[i as int])
          .toSet(),
      activeHoursEnabled: map['activeHoursEnabled'] ?? true,
      activeFrom: map['activeFrom'] ?? '07:00 AM',
      activeTo: map['activeTo'] ?? '11:00 PM',
    );
  }

  AlertSettingsModel copyWith({
    double? radiusKm,
    Set<SeverityLevel>? severityFilters,
    Set<IncidentCategory>? categoryFilters,
    bool? activeHoursEnabled,
    String? activeFrom,
    String? activeTo,
  }) {
    return AlertSettingsModel(
      radiusKm: radiusKm ?? this.radiusKm,
      severityFilters: severityFilters ?? this.severityFilters,
      categoryFilters: categoryFilters ?? this.categoryFilters,
      activeHoursEnabled: activeHoursEnabled ?? this.activeHoursEnabled,
      activeFrom: activeFrom ?? this.activeFrom,
      activeTo: activeTo ?? this.activeTo,
    );
  }
}
