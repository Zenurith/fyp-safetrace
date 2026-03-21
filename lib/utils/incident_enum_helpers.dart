import 'package:flutter/material.dart';
import '../data/models/incident_model.dart';
import 'app_theme.dart';

String categoryLabel(IncidentCategory cat) {
  switch (cat) {
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
    case IncidentCategory.other:
      return 'Other';
  }
}

IconData categoryIcon(IncidentCategory cat) {
  switch (cat) {
    case IncidentCategory.crime:
      return Icons.shield;
    case IncidentCategory.infrastructure:
      return Icons.construction;
    case IncidentCategory.suspicious:
      return Icons.visibility;
    case IncidentCategory.traffic:
      return Icons.directions_car;
    case IncidentCategory.environmental:
      return Icons.eco;
    case IncidentCategory.emergency:
      return Icons.local_hospital;
    case IncidentCategory.other:
      return Icons.category;
  }
}

Color categoryColor(IncidentCategory cat) {
  return AppTheme.categoryColor(categoryLabel(cat));
}

IncidentCategory incidentCategoryFromName(String name) {
  switch (name.toLowerCase()) {
    case 'crime':
      return IncidentCategory.crime;
    case 'infrastructure':
      return IncidentCategory.infrastructure;
    case 'suspicious':
      return IncidentCategory.suspicious;
    case 'traffic':
      return IncidentCategory.traffic;
    case 'environmental':
      return IncidentCategory.environmental;
    case 'emergency':
      return IncidentCategory.emergency;
    default:
      return IncidentCategory.other;
  }
}

String severityLabel(SeverityLevel level) {
  switch (level) {
    case SeverityLevel.low:
      return 'Low';
    case SeverityLevel.moderate:
      return 'Moderate';
    case SeverityLevel.high:
      return 'High';
  }
}

Color severityColor(SeverityLevel level) {
  switch (level) {
    case SeverityLevel.low:
      return AppTheme.severityLow;
    case SeverityLevel.moderate:
      return AppTheme.severityModerate;
    case SeverityLevel.high:
      return AppTheme.severityHigh;
  }
}
