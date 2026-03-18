import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/incident_model.dart';
import '../../../data/services/analytics_service.dart';
import '../../../utils/app_theme.dart';
import '../../providers/incident_provider.dart';
import '../../providers/category_provider.dart';
import '../analytics/stats_card.dart';
import '../analytics/incident_trend_chart.dart';
import '../analytics/category_pie_chart.dart';
import '../analytics/severity_bar_chart.dart';

class AdminAnalyticsTab extends StatefulWidget {
  const AdminAnalyticsTab({super.key});

  @override
  State<AdminAnalyticsTab> createState() => _AdminAnalyticsTabState();
}

class _AdminAnalyticsTabState extends State<AdminAnalyticsTab> {
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

  void _showFilterSheet(BuildContext context, List<String> categoryNames) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void update(VoidCallback fn) {
            fn();
            setSheetState(() {});
            setState(() {});
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Filter Analytics', style: AppTheme.headingSmall),
                    if (_hasActiveFilters)
                      TextButton(
                        onPressed: () => update(() {
                          _dateFilter = 'all';
                          _categoryFilter = null;
                          _severityFilter = null;
                        }),
                        child: const Text('Clear All'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Date range
                Text('Date Range', style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryDark,
                )),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final entry in const {
                      'all': 'All Time',
                      '7days': 'Last 7 Days',
                      '30days': 'Last 30 Days',
                      '90days': 'Last 90 Days',
                    }.entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: _dateFilter == entry.key,
                        onSelected: (_) => update(() => _dateFilter = entry.key),
                        selectedColor: AppTheme.primaryRed,
                        labelStyle: TextStyle(
                          color: _dateFilter == entry.key ? Colors.white : AppTheme.primaryDark,
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Category
                Text('Category', style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryDark,
                )),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _categoryFilter == null,
                      onSelected: (_) => update(() => _categoryFilter = null),
                      selectedColor: AppTheme.primaryRed,
                      labelStyle: TextStyle(
                        color: _categoryFilter == null ? Colors.white : AppTheme.primaryDark,
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                      ),
                    ),
                    for (final cat in categoryNames)
                      ChoiceChip(
                        label: Text(cat),
                        selected: _categoryFilter == cat,
                        onSelected: (_) => update(() =>
                            _categoryFilter = _categoryFilter == cat ? null : cat),
                        selectedColor: AppTheme.primaryRed,
                        labelStyle: TextStyle(
                          color: _categoryFilter == cat ? Colors.white : AppTheme.primaryDark,
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Severity
                Text('Severity', style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryDark,
                )),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _severityFilter == null,
                      onSelected: (_) => update(() => _severityFilter = null),
                      selectedColor: AppTheme.primaryRed,
                      labelStyle: TextStyle(
                        color: _severityFilter == null ? Colors.white : AppTheme.primaryDark,
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                      ),
                    ),
                    for (final entry in const {
                      SeverityLevel.low: 'Low',
                      SeverityLevel.moderate: 'Moderate',
                      SeverityLevel.high: 'High',
                    }.entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: _severityFilter == entry.key,
                        onSelected: (_) => update(() =>
                            _severityFilter = _severityFilter == entry.key ? null : entry.key),
                        selectedColor: AppTheme.primaryRed,
                        labelStyle: TextStyle(
                          color: _severityFilter == entry.key ? Colors.white : AppTheme.primaryDark,
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
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
      children: [
        // Filter header row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
          ),
          child: Row(
            children: [
              Text(
                '${filtered.length} incidents',
                style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
              ),
              const Spacer(),
              if (_hasActiveFilters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: () => _showFilterSheet(context, categoryNames),
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Filter'),
                style: TextButton.styleFrom(
                  foregroundColor: _hasActiveFilters ? AppTheme.primaryRed : AppTheme.primaryDark,
                  textStyle: AppTheme.bodyMedium,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: SingleChildScrollView(
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
                        color: AppTheme.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatsCard(
                        title: 'Avg Resolution',
                        value: '${analytics.averageResolutionDays.toStringAsFixed(1)}d',
                        icon: Icons.timer_outlined,
                        color: AppTheme.warningOrange,
                        subtitle: 'days',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  trendTitle,
                  style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryDark),
                ),
                const SizedBox(height: 8),
                IncidentTrendChart(data: analytics.trendData),
                const SizedBox(height: 16),
                CategoryPieChart(data: analytics.categoryDistribution),
                const SizedBox(height: 16),
                SeverityBarChart(data: analytics.severityDistribution),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
