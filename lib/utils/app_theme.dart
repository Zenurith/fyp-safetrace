import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryDark = Color(0xFF2D3748);
  static const Color primaryRed = Color(0xFFE53E3E);
  static const Color accentBlue = Color(0xFF3182CE);
  static const Color profilePurple = Color(0xFF5A67D8);
  static const Color successGreen = Color(0xFF38A169);
  static const Color warningOrange = Color(0xFFDD6B20);
  static const Color severityLow = Color(0xFFF6E05E);
  static const Color severityModerate = Color(0xFFF6AD55);
  static const Color severityHigh = Color(0xFFE53E3E);
  static const Color backgroundGrey = Color(0xFFF7FAFC);
  static const Color cardBorder = Color(0xFFE2E8F0);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryDark,
        primary: primaryDark,
        error: primaryRed,
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  static Color severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
        return severityHigh;
      case 'moderate':
        return severityModerate;
      case 'low':
        return severityLow;
      default:
        return Colors.grey;
    }
  }

  static Color categoryColor(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('crime')) return primaryRed;
    if (cat.contains('traffic') || cat.contains('hazard')) return warningOrange;
    if (cat.contains('emergency')) return primaryRed;
    if (cat.contains('infrastructure')) return accentBlue;
    if (cat.contains('environmental')) return successGreen;
    if (cat.contains('suspicious')) return Colors.purple;
    return Colors.grey;
  }
}
