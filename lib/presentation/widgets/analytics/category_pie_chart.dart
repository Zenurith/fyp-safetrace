import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../data/services/analytics_service.dart';
import '../../../utils/app_theme.dart';

class CategoryPieChart extends StatefulWidget {
  final List<CategoryCount> data;

  const CategoryPieChart({super.key, required this.data});

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart> {
  int touchedIndex = -1;

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'crime':
        return AppTheme.primaryRed;
      case 'traffic':
        return AppTheme.warningOrange;
      case 'emergency':
        return const Color(0xFFE53E3E);
      case 'infrastructure':
        return AppTheme.accentBlue;
      case 'environmental':
        return AppTheme.successGreen;
      case 'suspicious':
        return AppTheme.profilePurple;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.data.isEmpty) {
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecorationFor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category Distribution',
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
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              touchedIndex = -1;
                              return;
                            }
                            touchedIndex =
                                pieTouchResponse.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: _buildSections(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.data.take(5).map((cat) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getCategoryColor(cat.category),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${cat.category} (${cat.count})',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 11,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildSections() {
    return widget.data.asMap().entries.map((entry) {
      final index = entry.key;
      final cat = entry.value;
      final isTouched = index == touchedIndex;
      final fontSize = isTouched ? 16.0 : 12.0;
      final radius = isTouched ? 60.0 : 50.0;

      return PieChartSectionData(
        color: _getCategoryColor(cat.category),
        value: cat.count.toDouble(),
        title: '${cat.percentage.toStringAsFixed(0)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }
}
