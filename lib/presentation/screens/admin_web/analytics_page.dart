import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/app_theme.dart';
import '../../../data/services/analytics_service.dart';
import '../../providers/incident_provider.dart';
import '../../widgets/analytics/stats_card.dart';
import '../../widgets/analytics/incident_trend_chart.dart';
import '../../widgets/analytics/category_pie_chart.dart';
import '../../widgets/analytics/severity_bar_chart.dart';
import '../../widgets/admin_web/responsive_layout.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final incidentProvider = context.watch<IncidentProvider>();
    final incidents = incidentProvider.allIncidents;
    final analytics = AnalyticsService.calculateAnalytics(incidents);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final columns = ResponsiveLayout.getGridColumns(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats grid
          Text(
            'Key Metrics',
            style: AppTheme.headingMedium.copyWith(
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 16),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: columns == 1 ? 2 : columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: columns == 1 ? 1.5 : 2,
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
                color: AppTheme.accentBlue,
              ),
              StatsCard(
                title: 'Avg Resolution',
                value: '${analytics.averageResolutionDays.toStringAsFixed(1)}d',
                icon: Icons.timer_outlined,
                color: AppTheme.profilePurple,
                subtitle: 'days',
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Charts section
          Text(
            'Trends & Distribution',
            style: AppTheme.headingMedium.copyWith(
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 16),

          // Trend chart (full width)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.cardDecorationFor(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Incident Trend (Last 7 Days)',
                  style: AppTheme.headingSmall.copyWith(
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  child: IncidentTrendChart(data: analytics.trendData),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Category and severity charts side by side on desktop
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppTheme.cardDecorationFor(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'By Category',
                          style: AppTheme.headingSmall.copyWith(
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 300,
                          child: CategoryPieChart(data: analytics.categoryDistribution),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppTheme.cardDecorationFor(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'By Severity',
                          style: AppTheme.headingSmall.copyWith(
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 300,
                          child: SeverityBarChart(data: analytics.severityDistribution),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else ...[
            // Stack on mobile/tablet
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.cardDecorationFor(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'By Category',
                    style: AppTheme.headingSmall.copyWith(
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: CategoryPieChart(data: analytics.categoryDistribution),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.cardDecorationFor(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'By Severity',
                    style: AppTheme.headingSmall.copyWith(
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: SeverityBarChart(data: analytics.severityDistribution),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),

          // Summary stats
          Text(
            'Summary',
            style: AppTheme.headingMedium.copyWith(
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.cardDecorationFor(context),
            child: Column(
              children: [
                _SummaryRow(
                  label: 'Total incidents reported',
                  value: '${analytics.totalIncidents}',
                  icon: Icons.warning_amber_rounded,
                  isDark: isDark,
                ),
                const Divider(height: 24),
                _SummaryRow(
                  label: 'Resolution rate',
                  value: analytics.totalIncidents > 0
                      ? '${((analytics.resolvedIncidents / analytics.totalIncidents) * 100).toStringAsFixed(1)}%'
                      : 'N/A',
                  icon: Icons.check_circle_outline,
                  isDark: isDark,
                ),
                const Divider(height: 24),
                _SummaryRow(
                  label: 'Average time to resolution',
                  value: '${analytics.averageResolutionDays.toStringAsFixed(1)} days',
                  icon: Icons.timer_outlined,
                  isDark: isDark,
                ),
                const Divider(height: 24),
                _SummaryRow(
                  label: 'Most active period',
                  value: 'Last 7 days: ${analytics.incidentsLast7d} incidents',
                  icon: Icons.trending_up,
                  isDark: isDark,
                ),
                const Divider(height: 24),
                _SummaryRow(
                  label: 'Current active incidents',
                  value: '${analytics.activeIncidents}',
                  icon: Icons.pending_actions,
                  isDark: isDark,
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

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isDark;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppTheme.bodyMedium.copyWith(
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: AppTheme.headingSmall.copyWith(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryDark,
          ),
        ),
      ],
    );
  }
}
