import 'package:flutter/material.dart';

class AppTheme {
  // Primary colors
  static const Color primaryDark = Color(0xFF2D3748);
  static const Color primaryRed = Color(0xFFE53E3E);

  // Semantic colors (use only for states, not decoration)
  static const Color successGreen = Color(0xFF38A169);
  static const Color warningOrange = Color(0xFFDD6B20);

  // Legacy colors (avoid for new UI work)
  static const Color accentBlue = Color(0xFF3182CE);
  static const Color profilePurple = Color(0xFF5A67D8);

  // Severity colors
  static const Color severityLow = Color(0xFFF6E05E);
  static const Color severityModerate = Color(0xFFF6AD55);
  static const Color severityHigh = Color(0xFFE53E3E);

  // Neutral colors
  static const Color backgroundGrey = Color(0xFFF7FAFC);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color textSecondary = Color(0xFF718096);

  // Font family
  static const String fontFamily = 'Avenir';

  // Text styles
  static const TextStyle headingLarge = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 24,
    color: primaryDark,
  );

  static const TextStyle headingMedium = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 20,
    color: primaryDark,
  );

  static const TextStyle headingSmall = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 16,
    color: primaryDark,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    color: primaryDark,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    color: primaryDark,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w300,
    fontSize: 12,
    color: textSecondary,
  );

  // Card decoration (border-only, no shadow)
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: cardBorder),
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
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
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 20,
          color: Colors.white,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: headingLarge,
        headlineMedium: headingMedium,
        headlineSmall: headingSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: caption,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: cardBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: cardBorder),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    if (cat.contains('infrastructure')) return primaryDark;
    if (cat.contains('environmental')) return successGreen;
    if (cat.contains('suspicious')) return primaryDark;
    return textSecondary;
  }
}
