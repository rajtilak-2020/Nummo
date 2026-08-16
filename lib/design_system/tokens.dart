import 'package:flutter/material.dart';

/// 8-Point Spacing Scale Tokens
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double bottomNavClearance = 140.0;
}

/// Geometry Radius Tokens (Strictly adhering to section 4 Uber-grade design system rules)
class AppRadius {
  static const double small = 8.0;
  static const double card = 20.0;
  static const double control = 14.0;
  static const double modal = 24.0;
  static const double modalTop = 28.0;
  static const double pill = 100.0;
}

/// Touch Target Tokens
class AppTouchTarget {
  static const double minHeight = 48.0;
}

/// Semantic Money & Theme Color System
class AppColors {
  // Money Tokens (10-12% alpha fill for cards/pills)
  static const Color creditGreen = Color(0xFF10B981); // Income / In (Emerald Mint)
  static const Color creditGreenBg = Color(0x1F10B981);
  
  static const Color debitRed = Color(0xFFF43F5E);   // Expense / Out (Vivid Coral Crimson)
  static const Color debitRedBg = Color(0x1FF43F5E);

  // Accent Presets
  static const Map<String, Color> accentSwatches = {
    'Indigo Slate': Color(0xFF4F46E5),
    'Sky Platinum': Color(0xFF0284C7),
    'Emerald Mint': Color(0xFF10B981),
    'Electric Cyan': Color(0xFF06B6D4),
    'Gold Amber': Color(0xFFD97706),
    'Royal Violet': Color(0xFF7C3AED),
    'Crimson Rose': Color(0xFFE11D48),
    'Teal Lagoon': Color(0xFF0D9488),
    'Sunset Orange': Color(0xFFEA580C),
    'Amethyst Glow': Color(0xFF9333EA),
    'Magenta Pink': Color(0xFFDB2777),
    'Forest Moss': Color(0xFF16A34A),
    'Cobalt Sapphire': Color(0xFF2563EB),
    'Obsidian Slate': Color(0xFF475569),
  };

  /// Resolves an accent name or hex string to a valid [Color].
  static Color resolveAccentColor(String swatchOrHex) {
    if (accentSwatches.containsKey(swatchOrHex)) {
      return accentSwatches[swatchOrHex]!;
    }
    try {
      String hex = swatchOrHex.replaceAll('#', '').trim();
      if (hex.startsWith('0x') || hex.startsWith('0X')) hex = hex.substring(2);
      if (hex.length == 6) hex = 'FF$hex';
      if (hex.length == 8) return Color(int.parse(hex, radix: 16));
    } catch (_) {}
    return const Color(0xFF4F46E5);
  }

  // Light Scheme (Warm Slate #F8F9FA, Surface #FFFFFF, Soft Border #E2E8F0)
  static const Color lightScaffold = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Dark Scheme (Rich Charcoal Obsidian #0F1117, Surface #181A22, Border #262A36)
  static const Color darkScaffold = Color(0xFF0F1117);
  static const Color darkSurface = Color(0xFF181A22);
  static const Color darkBorder = Color(0xFF262A36);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // Super AMOLED Scheme (Pure Pitch Black #000000 canvas with ultra-deep obsidian #07080A surfaces and subtle #151720 borders)
  static const Color amoledScaffold = Color(0xFF000000);
  static const Color amoledSurface = Color(0xFF07080A);
  static const Color amoledBorder = Color(0xFF151720);
  static const Color amoledTextPrimary = Color(0xFFF8FAFC);
  static const Color amoledTextSecondary = Color(0xFF94A3B8);

  static Color scaffoldBackground(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>();
    if (ext != null) return ext.scaffoldBackground;
    return Theme.of(context).brightness == Brightness.dark
        ? darkScaffold
        : lightScaffold;
  }

  static Color surfaceCard(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>();
    if (ext != null) return ext.surfaceCard;
    return Theme.of(context).brightness == Brightness.dark
        ? darkSurface
        : lightSurface;
  }

  static Color cardBorder(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>();
    if (ext != null) return ext.cardBorder;
    return Theme.of(context).brightness == Brightness.dark
        ? darkBorder
        : lightBorder;
  }

  static Color textPrimary(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>();
    if (ext != null) return ext.textPrimary;
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextPrimary
        : lightTextPrimary;
  }

  static Color textSecondary(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>();
    if (ext != null) return ext.textSecondary;
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextSecondary
        : lightTextSecondary;
  }

  static bool isAmoled(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>();
    return ext?.isAmoled ?? false;
  }
}

/// Theme Extension to cleanly propagate AMOLED & dynamic theme tokens across the app
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final bool isAmoled;
  final Color scaffoldBackground;
  final Color surfaceCard;
  final Color cardBorder;
  final Color textPrimary;
  final Color textSecondary;

  const AppThemeExtension({
    required this.isAmoled,
    required this.scaffoldBackground,
    required this.surfaceCard,
    required this.cardBorder,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  ThemeExtension<AppThemeExtension> copyWith({
    bool? isAmoled,
    Color? scaffoldBackground,
    Color? surfaceCard,
    Color? cardBorder,
    Color? textPrimary,
    Color? textSecondary,
  }) {
    return AppThemeExtension(
      isAmoled: isAmoled ?? this.isAmoled,
      scaffoldBackground: scaffoldBackground ?? this.scaffoldBackground,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      cardBorder: cardBorder ?? this.cardBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
    );
  }

  @override
  ThemeExtension<AppThemeExtension> lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      isAmoled: other.isAmoled,
      scaffoldBackground: Color.lerp(scaffoldBackground, other.scaffoldBackground, t) ?? scaffoldBackground,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t) ?? surfaceCard,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t) ?? cardBorder,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
    );
  }
}

/// Accessible Theme Builder
class AppTheme {
  static ThemeData buildTheme({
    required Brightness brightness,
    required Color primaryAccent,
    bool isAmoled = false,
  }) {
    final bool isDark = brightness == Brightness.dark || isAmoled;
    final Color scaffoldBg = isAmoled
        ? AppColors.amoledScaffold
        : (isDark ? AppColors.darkScaffold : AppColors.lightScaffold);
    final Color surfaceColor = isAmoled
        ? AppColors.amoledSurface
        : (isDark ? AppColors.darkSurface : AppColors.lightSurface);
    final Color borderColor = isAmoled
        ? AppColors.amoledBorder
        : (isDark ? AppColors.darkBorder : AppColors.lightBorder);
    final Color primaryTxt = isAmoled
        ? AppColors.amoledTextPrimary
        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
    final Color secondaryTxt = isAmoled
        ? AppColors.amoledTextSecondary
        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);

    // Determine high-contrast onPrimary text color
    final double luminance = primaryAccent.computeLuminance();
    final Color onPrimary = luminance > 0.4 ? Colors.black : Colors.white;

    final colorScheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: primaryAccent,
      onPrimary: onPrimary,
      secondary: primaryAccent,
      onSecondary: onPrimary,
      error: AppColors.debitRed,
      onError: Colors.white,
      surface: surfaceColor,
      onSurface: primaryTxt,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,
      fontFamily: 'Roboto',
      extensions: [
        AppThemeExtension(
          isAmoled: isAmoled,
          scaffoldBackground: scaffoldBg,
          surfaceCard: surfaceColor,
          cardBorder: borderColor,
          textPrimary: primaryTxt,
          textSecondary: secondaryTxt,
        ),
      ],
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: scaffoldBg,
        foregroundColor: primaryTxt,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(
            color: borderColor,
            width: 1,
          ),
        ),
        color: surfaceColor,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        elevation: isAmoled ? 0 : 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.modal),
          side: isAmoled ? BorderSide(color: borderColor, width: 1.2) : BorderSide.none,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceColor,
        elevation: isAmoled ? 0 : 16,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.modalTop)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: primaryAccent, width: 2),
        ),
      ),
    );
  }
}

