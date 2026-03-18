import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/app_theme.dart';
import '../../../data/services/analytics_service.dart';
import '../../providers/incident_provider.dart';
import '../../widgets/analytics/stats_card.dart';
import '../../widgets/analytics/incident_trend_chart.dart';
import '../../widgets/analytics/category_pie_chart.dart';
import '../../widgets/analytics/severity_bar_chart.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final incidents = context.watch<IncidentProvider>().allIncidents;
    final analytics = AnalyticsService.calculateAnalytics(incidents);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats grid — 3 columns on wide, 2 on narrow
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth > 900 ? 3 : 2;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: cols,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.2,
                children: [
                  StatsCard(
                    title: 'Total Incidents',
                    value: '${analytics.totalIncidents}',
                    icon: Icons.warning_amber_rounded,
                    color: AppTheme.primaryDark,
                  ),
                  StatsCard(
                    title: 'Active',
                    value: '${analytics.activeIncidents}',
                    icon: Icons.pending_actions,
                    color: AppTheme.warningOrange,
                  ),
                  StatsCard(
                    title: 'Resolved',
                    value: '${analytics.resolvedIncidents}',
                    icon: Icons.check_circle_outline,
                    color: AppTheme.successGreen,
                  ),
                  StatsCard(
                    title: 'Last 24h',
                    value: '${analytics.incidentsLast24h}',
                    icon: Icons.schedule,
                    color: AppTheme.primaryRed,
                  ),
                  StatsCard(
                    title: 'Last 7 Days',
                    value: '${analytics.incidentsLast7d}',
                    icon: Icons.date_range,
                    color: AppTheme.primaryDark,
                  ),
                  StatsCard(
                    title: 'Avg Resolution',
                    value: '${analytics.averageResolutionDays.toStringAsFixed(1)}d',
                    icon: Icons.timer_outlined,
                    color: AppTheme.warningOrange,
                    subtitle: 'days',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Incident Trend Chart (full width)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.cardDecorationFor(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Incident Trend (Last 7 Days)',
                  style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryDark),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 260,
                  child: IncidentTrendChart(data: analytics.trendData),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Category Distribution
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.cardDecorationFor(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Category Distribution',
                  style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryDark),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 280,
                  child: CategoryPieChart(data: analytics.categoryDistribution),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Severity Distribution
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.cardDecorationFor(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Severity Distribution',
                  style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryDark),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 260,
                  child: SeverityBarChart(data: analytics.severityDistribution),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
