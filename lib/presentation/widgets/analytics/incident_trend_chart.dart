import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../data/services/analytics_service.dart';
import '../../../utils/app_theme.dart';

class IncidentTrendChart extends StatelessWidget {
  final List<IncidentTrendData> data;

  const IncidentTrendChart({super.key, required this.data});

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

    // Use last 7 days for cleaner visualization
    final recentData = data.length > 7 ? data.sublist(data.length - 7) : data;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecorationFor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Incident Trend (Last 7 Days)',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= recentData.length) {
                          return const Text('');
                        }
                        final date = recentData[index].date;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat('E').format(date),
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 10,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
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
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value == value.roundToDouble()) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 10,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(recentData.length, (index) {
                      return FlSpot(index.toDouble(), recentData[index].count.toDouble());
                    }),
                    isCurved: true,
                    color: AppTheme.primaryRed,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: AppTheme.primaryRed,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primaryRed.withValues(alpha: 0.1),
                    ),
                  ),
                ],
                minY: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
