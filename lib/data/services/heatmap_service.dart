import 'dart:ui';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/incident_model.dart';

class HeatmapPoint {
  final LatLng center;
  final int count;
  final double intensity;

  HeatmapPoint({
    required this.center,
    required this.count,
    required this.intensity,
  });
}

class HeatmapService {
  /// Grid size in degrees (approximately 500 meters at equator)
  static const double gridSize = 0.005;

  /// Calculate heatmap data from incidents
  static List<HeatmapPoint> calculateHeatmap(List<IncidentModel> incidents) {
    if (incidents.isEmpty) return [];

    // Group incidents by grid cells
    final Map<String, List<IncidentModel>> grid = {};

    for (final incident in incidents) {
      final gridKey = _getGridKey(incident.latitude, incident.longitude);
      grid.putIfAbsent(gridKey, () => []).add(incident);
    }

    // Calculate max count for normalization
    int maxCount = 0;
    for (final cell in grid.values) {
      if (cell.length > maxCount) maxCount = cell.length;
    }

    if (maxCount == 0) return [];

    // Convert to heatmap points
    final List<HeatmapPoint> points = [];
    for (final entry in grid.entries) {
      final coords = _parseGridKey(entry.key);
      final count = entry.value.length;
      final intensity = count / maxCount;

      // Calculate center of the cell
      final centerLat = coords[0] + gridSize / 2;
      final centerLng = coords[1] + gridSize / 2;

      points.add(HeatmapPoint(
        center: LatLng(centerLat, centerLng),
        count: count,
        intensity: intensity,
      ));
    }

    return points;
  }

  static String _getGridKey(double lat, double lng) {
    final gridLat = (lat / gridSize).floor() * gridSize;
    final gridLng = (lng / gridSize).floor() * gridSize;
    return '$gridLat,$gridLng';
  }

  static List<double> _parseGridKey(String key) {
    final parts = key.split(',');
    return [double.parse(parts[0]), double.parse(parts[1])];
  }

  /// Generate circles for the heatmap overlay
  static Set<Circle> generateHeatmapCircles(
    List<HeatmapPoint> points, {
    double baseRadius = 150,
    double maxRadius = 400,
  }) {
    return points.map((point) {
      // Scale radius based on intensity
      final radius = baseRadius + (maxRadius - baseRadius) * point.intensity;

      // Interpolate color from yellow -> orange -> red based on intensity
      final color = _getHeatmapColor(point.intensity);

      return Circle(
        circleId: CircleId('heatmap_${point.center.latitude}_${point.center.longitude}'),
        center: point.center,
        radius: radius,
        fillColor: color.withValues(alpha: 0.35),
        strokeColor: color.withValues(alpha: 0.6),
        strokeWidth: 1,
      );
    }).toSet();
  }

  static Color _getHeatmapColor(double intensity) {
    // Low intensity: green/yellow
    // Medium intensity: orange
    // High intensity: red

    if (intensity < 0.33) {
      // Green to Yellow
      final t = intensity / 0.33;
      return Color.lerp(
        const Color(0xFF38A169), // Green
        const Color(0xFFF6E05E), // Yellow
        t,
      )!;
    } else if (intensity < 0.66) {
      // Yellow to Orange
      final t = (intensity - 0.33) / 0.33;
      return Color.lerp(
        const Color(0xFFF6E05E), // Yellow
        const Color(0xFFDD6B20), // Orange
        t,
      )!;
    } else {
      // Orange to Red
      final t = (intensity - 0.66) / 0.34;
      return Color.lerp(
        const Color(0xFFDD6B20), // Orange
        const Color(0xFFE53E3E), // Red
        t,
      )!;
    }
  }
}

