import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/services/analytics_service.dart';
import '../../../utils/app_theme.dart';
import '../../providers/incident_provider.dart';
import '../analytics/stats_card.dart';
import '../analytics/incident_trend_chart.dart';
import '../analytics/category_pie_chart.dart';
import '../analytics/severity_bar_chart.dart';

class AdminAnalyticsTab extends StatelessWidget {
  const AdminAnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final incidents = context.watch<IncidentProvider>().allIncidents;
    final analytics = AnalyticsService.calculateAnalytics(incidents);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: StatsCard(
                  title: 'Total Incidents',
                  value: '${analytics.totalIncidents}',
                  icon: Icons.warning_amber_rounded,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatsCard(
                  title: 'Active',
                  value: '${analytics.activeIncidents}',
                  icon: Icons.pending_actions,
                  color: AppTheme.warningOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatsCard(
                  title: 'Resolved',
                  value: '${analytics.resolvedIncidents}',
                  icon: Icons.check_circle_outline,
                  color: AppTheme.successGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatsCard(
                  title: 'Last 24h',
                  value: '${analytics.incidentsLast24h}',
                  icon: Icons.schedule,
                  color: AppTheme.primaryRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatsCard(
                  title: 'Last 7 Days',
                  value: '${analytics.incidentsLast7d}',
                  icon: Icons.date_range,
                  color: AppTheme.accentBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatsCard(
                  title: 'Avg Resolution',
                  value: '${analytics.averageResolutionDays.toStringAsFixed(1)}d',
                  icon: Icons.timer_outlined,
                  color: AppTheme.profilePurple,
                  subtitle: 'days',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          IncidentTrendChart(data: analytics.trendData),
          const SizedBox(height: 16),
          CategoryPieChart(data: analytics.categoryDistribution),
          const SizedBox(height: 16),
          SeverityBarChart(data: analytics.severityDistribution),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
