import 'package:flutter/material.dart';

/// 8-Point Spacing Scale Tokens
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

/// Geometry Radius Tokens
class AppRadius {
  static const double small = 8.0;
  static const double card = 12.0;
  static const double control = 12.0;
  static const double modal = 24.0;
  static const double pill = 100.0;
}

/// Touch Target Tokens
class AppTouchTarget {
  static const double minHeight = 48.0;
}

/// Semantic Money & Theme Color System
class AppColors {
  // Money Tokens
  static const Color creditGreen = Color(0xFF10B981); // Income / In
  static const Color creditGreenBg = Color(0x1A10B981);
  
  static const Color debitRed = Color(0xFFF43F5E);   // Expense / Out
  static const Color debitRedBg = Color(0x1AF43F5E);

  // Accent Presets
  static const Map<String, Color> accentSwatches = {
    'Indigo Slate': Color(0xFF4F46E5),
    'Sky Platinum': Color(0xFF0284C7),
    'Emerald Mint': Color(0xFF10B981),
    'Electric Cyan': Color(0xFF06B6D4),
    'Gold Amber': Color(0xFFD97706),
    'Royal Violet': Color(0xFF7C3AED),
  };

  // Light Scheme
  static const Color lightScaffold = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Dark Scheme
  static const Color darkScaffold = Color(0xFF0F1117);
  static const Color darkSurface = Color(0xFF181A22);
  static const Color darkBorder = Color(0xFF262A36);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  static Color scaffoldBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkScaffold
        : lightScaffold;
  }

  static Color surfaceCard(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSurface
        : lightSurface;
  }

  static Color cardBorder(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBorder
        : lightBorder;
  }

  static Color textPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextPrimary
        : lightTextPrimary;
  }

  static Color textSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextSecondary
        : lightTextSecondary;
  }
}

/// Accessible Theme Builder
class AppTheme {
  static ThemeData buildTheme({
    required Brightness brightness,
    required Color primaryAccent,
  }) {
    final bool isDark = brightness == Brightness.dark;
    
    // Determine high-contrast onPrimary text color
    final double luminance = primaryAccent.computeLuminance();
    final Color onPrimary = luminance > 0.4 ? Colors.black : Colors.white;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primaryAccent,
      onPrimary: onPrimary,
      secondary: primaryAccent,
      onSecondary: onPrimary,
      error: AppColors.debitRed,
      onError: Colors.white,
      surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      onSurface: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? AppColors.darkScaffold : AppColors.lightScaffold,
      fontFamily: 'Roboto',
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: isDark ? AppColors.darkScaffold : AppColors.lightScaffold,
        foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: primaryAccent, width: 2),
        ),
      ),
    );
  }
}
