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

  // Queue of pending notifications
  final List<IncidentNotification> _notificationQueue = [];

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

    // Quiet hours check
    if (settings.quietHoursEnabled && _isInQuietHours(settings.quietFrom, settings.quietTo)) {
      return;
    }

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
        _notificationQueue.add(IncidentNotification(
          incident: incident,
          distance: distance,
        ));
      }
    }

    // Emit the first queued notification if the queue was just populated
    if (_notificationQueue.isNotEmpty) {
      final next = _notificationQueue.removeAt(0);
      _notificationController.add(next);
    }
  }

  /// Removes and returns the next notification from the queue, or null if empty.
  IncidentNotification? dequeueNext() {
    if (_notificationQueue.isEmpty) return null;
    return _notificationQueue.removeAt(0);
  }

  bool _isInQuietHours(String quietFrom, String quietTo) {
    final now = DateTime.now();
    final fromTime = _parseTime(quietFrom);
    final toTime = _parseTime(quietTo);
    if (fromTime == null || toTime == null) return false;

    final nowMinutes = now.hour * 60 + now.minute;
    final fromMinutes = fromTime.hour * 60 + fromTime.minute;
    final toMinutes = toTime.hour * 60 + toTime.minute;

    // Handle overnight ranges (e.g. 10 PM to 7 AM)
    if (fromMinutes > toMinutes) {
      return nowMinutes >= fromMinutes || nowMinutes < toMinutes;
    } else {
      return nowMinutes >= fromMinutes && nowMinutes < toMinutes;
    }
  }

  DateTime? _parseTime(String timeStr) {
    try {
      // Expected format: "10:00 PM" or "07:00 AM"
      final parts = timeStr.trim().split(' ');
      if (parts.length != 2) return null;
      final timeParts = parts[0].split(':');
      if (timeParts.length != 2) return null;
      int hour = int.parse(timeParts[0]);
      final int minute = int.parse(timeParts[1]);
      final String period = parts[1].toUpperCase();
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return DateTime(0, 1, 1, hour, minute);
    } catch (_) {
      return null;
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
