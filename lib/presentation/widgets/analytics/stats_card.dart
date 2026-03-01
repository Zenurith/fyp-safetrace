import 'package:flutter/material.dart';
import '../../../utils/app_theme.dart';

class StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const StatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecorationFor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
