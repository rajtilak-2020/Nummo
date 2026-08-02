import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemePreset {
  uber,    // Signature Monochrome Platinum / Pure White
  matrix,  // Vibrant Emerald Mint (#10B981)
  cyber,   // Electric Neon Cyan (#06B6D4)
  amber,   // Warm Gold Amber (#F59E0B)
  crimson, // Vivid Coral Crimson (#F43F5E)
  violet,  // Royal Indigo Violet (#8B5CF6)
  custom,  // User Custom Accent Color
}

class AppColors {
  // Light Mode Colors (Warm Slate & Crisp Surface)
  static const Color lightScaffold = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCardBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightCredit = Color(0xFF10B981);
  static const Color lightCreditFill = Color(0x1F10B981);
  static const Color lightDebit = Color(0xFFF43F5E);
  static const Color lightDebitFill = Color(0x1FF43F5E);

  // Dark Mode Colors (Rich Charcoal Obsidian - No Harsh Pitch Black)
  static const Color darkScaffold = Color(0xFF0F1117);
  static const Color darkSurface = Color(0xFF181A22);
  static const Color darkCardBorder = Color(0xFF262A36);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkCredit = Color(0xFF10B981);
  static const Color darkCreditFill = Color(0x2910B981);
  static const Color darkDebit = Color(0xFFF43F5E);
  static const Color darkDebitFill = Color(0x29F43F5E);

  // Dynamic Accent Color
  static Color get accent => themeController.primaryAccent;

  static Color scaffold(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkScaffold
        : lightScaffold;
  }

  static Color surface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSurface
        : lightSurface;
  }

  static Color credit(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkCredit
        : lightCredit;
  }

  static Color creditFill(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkCreditFill
        : lightCreditFill;
  }

  static Color debit(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkDebit
        : lightDebit;
  }

  static Color debitFill(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkDebitFill
        : lightDebitFill;
  }

  static Color cardBorder(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkCardBorder
        : lightCardBorder;
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

class ThemeController extends ValueNotifier<ThemeMode> {
  static const String _prefKey = 'theme_mode_v1';
  static const String _presetKey = 'theme_preset_v2';
  static const String _customColorKey = 'custom_accent_color_v2';

  ThemePreset _preset = ThemePreset.uber;
  Color _customColor = const Color(0xFF38BDF8);

  ThemeController() : super(ThemeMode.system) {
    _loadThemeSettings();
  }

  ThemePreset get preset => _preset;
  Color get customColor => _customColor;

  Color get primaryAccent {
    switch (_preset) {
      case ThemePreset.uber:
        return const Color(0xFF38BDF8);
      case ThemePreset.matrix:
        return const Color(0xFF10B981);
      case ThemePreset.cyber:
        return const Color(0xFF06B6D4);
      case ThemePreset.amber:
        return const Color(0xFFF59E0B);
      case ThemePreset.crimson:
        return const Color(0xFFF43F5E);
      case ThemePreset.violet:
        return const Color(0xFF8B5CF6);
      case ThemePreset.custom:
        return _customColor;
    }
  }

  Future<void> _loadThemeSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedModeStr = prefs.getString(_prefKey);
      if (savedModeStr != null) {
        if (savedModeStr == 'light') {
          value = ThemeMode.light;
        } else if (savedModeStr == 'dark') {
          value = ThemeMode.dark;
        } else {
          value = ThemeMode.system;
        }
      }
      final savedColorInt = prefs.getInt(_customColorKey);
      if (savedColorInt != null) {
        _customColor = Color(savedColorInt);
      }
      final savedPresetStr = prefs.getString(_presetKey);
      if (savedPresetStr != null) {
        _preset = ThemePreset.values.firstWhere(
          (e) => e.name == savedPresetStr,
          orElse: () => ThemePreset.uber,
        );
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    value = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      String strVal = 'system';
      if (mode == ThemeMode.light) strVal = 'light';
      if (mode == ThemeMode.dark) strVal = 'dark';
      await prefs.setString(_prefKey, strVal);
    } catch (_) {}
  }

  Future<void> setPreset(ThemePreset preset) async {
    _preset = preset;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_presetKey, preset.name);
    } catch (_) {}
  }

  Future<void> setCustomColor(Color color) async {
    _customColor = color;
    _preset = ThemePreset.custom;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_presetKey, ThemePreset.custom.name);
      await prefs.setInt(_customColorKey, color.toARGB32());
    } catch (_) {}
  }
}

final themeController = ThemeController();

class AppTheme {
  static ThemeData get lightTheme {
    final accent = themeController.primaryAccent;
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.lightScaffold,
      colorScheme: ColorScheme.light(
        primary: accent,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        error: AppColors.lightDebit,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          letterSpacing: -0.5,
          color: AppColors.lightTextPrimary,
        ),
        iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.lightCardBorder, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightCardBorder,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightScaffold,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lightCardBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lightCardBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lightDebit, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lightDebit, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.lightTextSecondary),
        hintStyle: const TextStyle(color: AppColors.lightTextSecondary),
        errorStyle: const TextStyle(
          color: AppColors.lightDebit,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final accent = themeController.primaryAccent;
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.darkScaffold,
      colorScheme: ColorScheme.dark(
        primary: accent,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
        error: AppColors.darkDebit,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          letterSpacing: -0.5,
          color: AppColors.darkTextPrimary,
        ),
        iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.darkCardBorder, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkCardBorder,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkScaffold,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkCardBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkCardBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkDebit, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkDebit, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.darkTextSecondary),
        hintStyle: const TextStyle(color: AppColors.darkTextSecondary),
        errorStyle: const TextStyle(
          color: AppColors.darkDebit,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
