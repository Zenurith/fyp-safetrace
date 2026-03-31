import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../data/services/analytics_service.dart';
import '../../../utils/app_theme.dart';

class PeakHoursChart extends StatelessWidget {
  final List<PeakHourData> data;

  const PeakHoursChart({super.key, required this.data});

  String _hourLabel(int hour) {
    if (hour == 0) return '12am';
    if (hour == 12) return '12pm';
    if (hour < 12) return '${hour}am';
    return '${hour - 12}pm';
  }

  @override
  Widget build(BuildContext context) {
    final allZero = data.every((d) => d.count == 0);
    if (data.isEmpty || allZero) {
      return const Center(
        child: Text(
          'No data available',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.textSecondary,
          ),
        ),
      );
    }

    final maxCount = data.map((d) => d.count).reduce((a, b) => a > b ? a : b);
    final maxY = (maxCount * 1.25).ceilToDouble();
    final interval = maxY > 5 ? (maxY / 5).ceilToDouble() : 1.0;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceEvenly,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final d = data[groupIndex];
              return BarTooltipItem(
                '${_hourLabel(d.hour)}\n${d.count} report${d.count == 1 ? '' : 's'}',
                const TextStyle(
                  color: Colors.white,
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
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
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final hour = value.toInt();
                // Label every 3 hours to avoid crowding
                if (hour % 3 != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _hourLabel(hour),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 9,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value != value.roundToDouble()) return const SizedBox.shrink();
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10,
                    color: AppTheme.textSecondary,
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
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppTheme.cardBorder,
            strokeWidth: 1,
          ),
        ),
        barGroups: data.map((d) {
          final isEmpty = d.count == 0;
          return BarChartGroupData(
            x: d.hour,
            barRods: [
              BarChartRodData(
                toY: isEmpty ? 0 : d.count.toDouble(),
                color: AppTheme.primaryRed.withValues(alpha: isEmpty ? 0.12 : 0.8),
                width: 9,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
