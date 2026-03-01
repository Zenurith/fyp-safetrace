import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../data/services/analytics_service.dart';
import '../../../utils/app_theme.dart';

class SeverityBarChart extends StatelessWidget {
  final List<SeverityCount> data;

  const SeverityBarChart({super.key, required this.data});

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'low':
        return AppTheme.successGreen;
      case 'moderate':
        return AppTheme.warningOrange;
      case 'high':
        return AppTheme.primaryRed;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecorationFor(context),
        height: 200,
        child: Center(
          child: Text(
            'No data available',
            style: TextStyle(
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            ),
          ),
        ),
      );
    }

    // Sort by severity order: Low, Moderate, High
    final sortedData = List<SeverityCount>.from(data);
    sortedData.sort((a, b) {
      const order = ['Low', 'Moderate', 'High'];
      return order.indexOf(a.severity).compareTo(order.indexOf(b.severity));
    });

    final maxCount = sortedData.map((e) => e.count).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecorationFor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Severity Distribution',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxCount.toDouble() * 1.2,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${sortedData[groupIndex].severity}\n${sortedData[groupIndex].count}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= sortedData.length) {
                          return const Text('');
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            sortedData[index].severity,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _getSeverityColor(sortedData[index].severity),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: maxCount > 5 ? (maxCount / 5).ceilToDouble() : 1,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 10,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxCount > 5 ? (maxCount / 5).ceilToDouble() : 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                      strokeWidth: 1,
                    );
                  },
                ),
                barGroups: sortedData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final sev = entry.value;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: sev.count.toDouble(),
                        color: _getSeverityColor(sev.severity),
                        width: 32,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
