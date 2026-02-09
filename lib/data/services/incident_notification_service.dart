import 'dart:async';
import 'dart:math';
import '../models/incident_model.dart';
import '../models/alert_settings_model.dart';

class IncidentNotification {
  final IncidentModel incident;
  final double distance;

  IncidentNotification({required this.incident, required this.distance});
}

class IncidentNotificationService {
  final _notificationController = StreamController<IncidentNotification>.broadcast();
  Stream<IncidentNotification> get notificationStream => _notificationController.stream;

  double? _userLatitude;
  double? _userLongitude;

  // Track already notified incidents to avoid duplicates
  final Set<String> _notifiedIncidentIds = {};

  void updateUserLocation(double latitude, double longitude) {
    _userLatitude = latitude;
    _userLongitude = longitude;
  }

  void checkNewIncidents({
    required List<IncidentModel> incidents,
    required AlertSettingsModel settings,
    String? currentUserId,
  }) {
    if (_userLatitude == null || _userLongitude == null) return;

    for (final incident in incidents) {
      // Skip if already notified
      if (_notifiedIncidentIds.contains(incident.id)) continue;

      // Skip own reports
      if (currentUserId != null && incident.reporterId == currentUserId) continue;

      // Skip inactive incidents
      if (!incident.isActive) continue;

      // Check severity filter
      if (!settings.severityFilters.contains(incident.severity)) continue;

      // Check category filter
      if (!settings.categoryFilters.contains(incident.category)) continue;

      // Calculate distance
      final distance = _calculateDistance(
        _userLatitude!,
        _userLongitude!,
        incident.latitude,
        incident.longitude,
      );

      // Check if within radius
      if (distance <= settings.radiusKm) {
        _notifiedIncidentIds.add(incident.id);
        _notificationController.add(IncidentNotification(
          incident: incident,
          distance: distance,
        ));
        // Only show one notification at a time
        break;
      }
    }
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371.0; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  void dispose() {
    _notificationController.close();
  }
}
