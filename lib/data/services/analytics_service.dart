import '../models/incident_model.dart';

class IncidentTrendData {
  final DateTime date;
  final int count;

  IncidentTrendData({required this.date, required this.count});
}

class CategoryCount {
  final String category;
  final int count;
  final double percentage;

  CategoryCount({
    required this.category,
    required this.count,
    required this.percentage,
  });
}

class SeverityCount {
  final String severity;
  final int count;

  SeverityCount({required this.severity, required this.count});
}

class StatusCount {
  final String status;
  final int count;

  StatusCount({required this.status, required this.count});
}

class AnalyticsData {
  final int totalIncidents;
  final int activeIncidents;
  final int resolvedIncidents;
  final int pendingIncidents;
  final List<IncidentTrendData> trendData;
  final List<CategoryCount> categoryDistribution;
  final List<SeverityCount> severityDistribution;
  final List<StatusCount> statusDistribution;
  final double averageResolutionDays;
  final int incidentsLast24h;
  final int incidentsLast7d;

  AnalyticsData({
    required this.totalIncidents,
    required this.activeIncidents,
    required this.resolvedIncidents,
    required this.pendingIncidents,
    required this.trendData,
    required this.categoryDistribution,
    required this.severityDistribution,
    required this.statusDistribution,
    required this.averageResolutionDays,
    required this.incidentsLast24h,
    required this.incidentsLast7d,
  });
}

class AnalyticsService {
  static AnalyticsData calculateAnalytics(List<IncidentModel> incidents) {
    if (incidents.isEmpty) {
      return AnalyticsData(
        totalIncidents: 0,
        activeIncidents: 0,
        resolvedIncidents: 0,
        pendingIncidents: 0,
        trendData: [],
        categoryDistribution: [],
        severityDistribution: [],
        statusDistribution: [],
        averageResolutionDays: 0,
        incidentsLast24h: 0,
        incidentsLast7d: 0,
      );
    }

    final now = DateTime.now();
    final last24h = now.subtract(const Duration(hours: 24));
    final last7d = now.subtract(const Duration(days: 7));

    // Count by status
    int activeCount = 0;
    int resolvedCount = 0;
    int pendingCount = 0;
    int incidentsLast24h = 0;
    int incidentsLast7d = 0;

    final Map<String, int> categoryMap = {};
    final Map<String, int> severityMap = {};
    final Map<String, int> statusMap = {};

    for (final incident in incidents) {
      // Status counts
      if (incident.status == IncidentStatus.resolved) {
        resolvedCount++;
      } else if (incident.status == IncidentStatus.pending) {
        pendingCount++;
      }

      if (incident.isActive) {
        activeCount++;
      }

      // Time-based counts
      if (incident.reportedAt.isAfter(last24h)) {
        incidentsLast24h++;
      }
      if (incident.reportedAt.isAfter(last7d)) {
        incidentsLast7d++;
      }

      // Category distribution
      final catLabel = incident.categoryLabel;
      categoryMap[catLabel] = (categoryMap[catLabel] ?? 0) + 1;

      // Severity distribution
      final sevLabel = incident.severityLabel;
      severityMap[sevLabel] = (severityMap[sevLabel] ?? 0) + 1;

      // Status distribution
      final statusLabel = incident.statusLabel;
      statusMap[statusLabel] = (statusMap[statusLabel] ?? 0) + 1;
    }

    // Calculate category distribution with percentages
    final categoryDistribution = categoryMap.entries.map((e) {
      return CategoryCount(
        category: e.key,
        count: e.value,
        percentage: e.value / incidents.length * 100,
      );
    }).toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    // Severity distribution
    final severityDistribution = severityMap.entries.map((e) {
      return SeverityCount(severity: e.key, count: e.value);
    }).toList();

    // Status distribution
    final statusDistribution = statusMap.entries.map((e) {
      return StatusCount(status: e.key, count: e.value);
    }).toList();

    // Calculate trend data (last 30 days)
    final trendData = _calculateTrendData(incidents, 30);

    // Calculate average resolution time
    final resolvedIncidents = incidents
        .where((i) => i.status == IncidentStatus.resolved && i.statusUpdatedAt != null)
        .toList();

    double avgResolutionDays = 0;
    if (resolvedIncidents.isNotEmpty) {
      double totalDays = 0;
      for (final incident in resolvedIncidents) {
        final days = incident.statusUpdatedAt!.difference(incident.reportedAt).inHours / 24;
        totalDays += days;
      }
      avgResolutionDays = totalDays / resolvedIncidents.length;
    }

    return AnalyticsData(
      totalIncidents: incidents.length,
      activeIncidents: activeCount,
      resolvedIncidents: resolvedCount,
      pendingIncidents: pendingCount,
      trendData: trendData,
      categoryDistribution: categoryDistribution,
      severityDistribution: severityDistribution,
      statusDistribution: statusDistribution,
      averageResolutionDays: avgResolutionDays,
      incidentsLast24h: incidentsLast24h,
      incidentsLast7d: incidentsLast7d,
    );
  }

  static List<IncidentTrendData> _calculateTrendData(
    List<IncidentModel> incidents,
    int days,
  ) {
    final now = DateTime.now();
    final Map<String, int> dailyCounts = {};

    // Initialize all days with 0
    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final key = '${date.year}-${date.month}-${date.day}';
      dailyCounts[key] = 0;
    }

    // Count incidents per day
    for (final incident in incidents) {
      final date = incident.reportedAt;
      if (date.isAfter(now.subtract(Duration(days: days)))) {
        final key = '${date.year}-${date.month}-${date.day}';
        dailyCounts[key] = (dailyCounts[key] ?? 0) + 1;
      }
    }

    // Convert to list and sort by date
    final List<IncidentTrendData> result = [];
    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = '${date.year}-${date.month}-${date.day}';
      result.add(IncidentTrendData(
        date: DateTime(date.year, date.month, date.day),
        count: dailyCounts[key] ?? 0,
      ));
    }

    return result;
  }
}
