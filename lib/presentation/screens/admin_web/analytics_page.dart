import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/incident_model.dart';
import '../../../utils/app_theme.dart';
import '../../../data/services/analytics_service.dart';
import '../../providers/incident_provider.dart';
import '../../providers/category_provider.dart';
import '../../widgets/analytics/stats_card.dart';
import '../../widgets/analytics/incident_trend_chart.dart';
import '../../widgets/analytics/category_pie_chart.dart';
import '../../widgets/analytics/peak_hours_chart.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  String _dateFilter = 'all';
  String? _categoryFilter;
  SeverityLevel? _severityFilter;

  List<IncidentModel> _applyFilters(List<IncidentModel> incidents) {
    return incidents.where((incident) {
      if (_dateFilter != 'all') {
        final now = DateTime.now();
        DateTime cutoff;
        switch (_dateFilter) {
          case '7days':
            cutoff = now.subtract(const Duration(days: 7));
            break;
          case '30days':
            cutoff = now.subtract(const Duration(days: 30));
            break;
          case '90days':
            cutoff = now.subtract(const Duration(days: 90));
            break;
          default:
            cutoff = DateTime(2000);
        }
        if (incident.reportedAt.isBefore(cutoff)) return false;
      }

      if (_categoryFilter != null && incident.categoryLabel != _categoryFilter) {
        return false;
      }

      if (_severityFilter != null && incident.severity != _severityFilter) {
        return false;
      }

      return true;
    }).toList();
  }

  bool get _hasActiveFilters =>
      _dateFilter != 'all' || _categoryFilter != null || _severityFilter != null;

  Widget _buildDropdown<T>({
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryDark),
          dropdownColor: Colors.white,
          iconEnabledColor: AppTheme.textSecondary,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allIncidents = context.watch<IncidentProvider>().allIncidents;
    final categoryNames =
        context.watch<CategoryProvider>().categories.map((c) => c.name).toList();
    final filtered = _applyFilters(allIncidents);

    final trendDays = _dateFilter == '7days' ? 7 : 30;
    final trendTitle = _dateFilter == '7days'
        ? 'Incident Trend (Last 7 Days)'
        : 'Incident Trend (Last 30 Days)';

    final analytics = AnalyticsService.calculateAnalytics(filtered, trendDays: trendDays);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: AppTheme.cardBorder),
            ),
          ),
          child: Row(
            children: [
              // Date filter
              _buildDropdown<String>(
                value: _dateFilter,
                hint: 'All Time',
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Time')),
                  DropdownMenuItem(value: '7days', child: Text('Last 7 Days')),
                  DropdownMenuItem(value: '30days', child: Text('Last 30 Days')),
                  DropdownMenuItem(value: '90days', child: Text('Last 90 Days')),
                ],
                onChanged: (v) => setState(() => _dateFilter = v ?? 'all'),
              ),
              const SizedBox(width: 12),

              // Category filter
              _buildDropdown<String?>(
                value: _categoryFilter,
                hint: 'All Categories',
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Categories')),
                  ...categoryNames.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                ],
                onChanged: (v) => setState(() => _categoryFilter = v),
              ),
              const SizedBox(width: 12),

              // Severity filter
              _buildDropdown<SeverityLevel?>(
                value: _severityFilter,
                hint: 'All Severity',
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Severity')),
                  const DropdownMenuItem(value: SeverityLevel.low, child: Text('Low')),
                  const DropdownMenuItem(value: SeverityLevel.moderate, child: Text('Moderate')),
                  const DropdownMenuItem(value: SeverityLevel.high, child: Text('High')),
                ],
                onChanged: (v) => setState(() => _severityFilter = v),
              ),
              const SizedBox(width: 12),

              if (_hasActiveFilters)
                TextButton.icon(
                  onPressed: () => setState(() {
                    _dateFilter = 'all';
                    _categoryFilter = null;
                    _severityFilter = null;
                  }),
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('Clear Filters'),
                ),

              const Spacer(),

              Text(
                '${filtered.length} incidents',
                style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),

        // Analytics content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats grid
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

                // Incident Trend Chart
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.cardDecorationFor(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trendTitle,
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

                // Peak Reporting Hours
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.cardDecorationFor(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Peak Reporting Hours',
                        style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryDark),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Number of incidents reported by hour of day',
                        style: AppTheme.caption,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 260,
                        child: PeakHoursChart(data: analytics.peakHoursData),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
