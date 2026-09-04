import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 8-Point Spacing Scale Tokens
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double bottomNavClearance = 76.0;
  static const double bottomNavClearanceCompact = 24.0;
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
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
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
      textTheme: TextTheme(
        bodyLarge: TextStyle(
          fontSize: 16,
          color: primaryTxt,
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
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isAmoled
            ? const Color(0xFF151720)
            : (isDark ? const Color(0xFF1E212D) : const Color(0xFF0F172A)),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: BorderSide(
            color: isAmoled
                ? const Color(0xFF262A36)
                : (isDark ? const Color(0xFF2E3344) : const Color(0xFF334155)),
            width: 1.0,
          ),
        ),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        insetPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.lg,
        ),
      ),
    );
  }
}

/// Semantic toast notification types.
enum ToastType {
  success,
  error,
  warning,
  info,
}

/// Ultra-modern Apple-style floating pill toast notification component for Nummo.
class NummoToast {
  static OverlayEntry? _activeEntry;
  static Timer? _activeTimer;

  /// Displays an Apple-style spring-animated floating pill toast notification.
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    OverlayState? overlay;
    try {
      overlay = Overlay.maybeOf(context, rootOverlay: true) ??
          Overlay.maybeOf(context) ??
          Navigator.maybeOf(context, rootNavigator: true)?.overlay ??
          Navigator.maybeOf(context)?.overlay;
    } catch (_) {}

    if (overlay != null) {
      showWithOverlay(
        overlay,
        context,
        message: message,
        type: type,
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
      );
      return;
    }

    // Fallback for headless environments or widgets without an active Overlay
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      if (type == ToastType.error || type == ToastType.warning) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        createSnackBar(
          context: context,
          message: message,
          type: type,
          icon: icon,
          actionLabel: actionLabel,
          onAction: onAction,
          duration: duration,
        ),
      );
    }
  }

  /// Displays the Apple-style toast directly in a provided [OverlayState].
  static void showWithOverlay(
    OverlayState overlay,
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (type == ToastType.error || type == ToastType.warning) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    _dismissActiveToast();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _AppleToastWidget(
        message: message,
        type: type,
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
        onDismissed: () {
          if (_activeEntry == entry) {
            _activeEntry?.remove();
            _activeEntry = null;
          }
        },
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);
  }

  static void _dismissActiveToast() {
    _activeTimer?.cancel();
    _activeTimer = null;
    _activeEntry?.remove();
    _activeEntry = null;
  }

  /// Convenience helper for success notifications.
  static void success(
    BuildContext context, {
    required String message,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      type: ToastType.success,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Convenience helper for error notifications.
  static void error(
    BuildContext context, {
    required String message,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      type: ToastType.error,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Convenience helper for warning notifications.
  static void warning(
    BuildContext context, {
    required String message,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      type: ToastType.warning,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Convenience helper for informational notifications.
  static void info(
    BuildContext context, {
    required String message,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      type: ToastType.info,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Displays a floating toast notification using a [ScaffoldMessengerState].
  static void showWithMessenger(
    ScaffoldMessengerState messenger, {
    required String message,
    ToastType type = ToastType.info,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
    BuildContext? context,
  }) {
    final effectiveContext = context ?? messenger.context;
    show(
      effectiveContext,
      message: message,
      type: type,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Constructs a styled floating [SnackBar] conforming to Nummo's Uber-grade design system.
  static SnackBar createSnackBar({
    BuildContext? context,
    required String message,
    ToastType type = ToastType.info,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final bool isDark = context != null
        ? Theme.of(context).brightness == Brightness.dark
        : true;
    final bool isAmoled = context != null ? AppColors.isAmoled(context) : false;
    final primaryColor = context != null
        ? Theme.of(context).colorScheme.primary
        : const Color(0xFF4F46E5);

    Color accentColor;
    IconData defaultIcon;

    switch (type) {
      case ToastType.success:
        accentColor = AppColors.creditGreen;
        defaultIcon = Icons.check_circle_rounded;
        break;
      case ToastType.error:
        accentColor = AppColors.debitRed;
        defaultIcon = Icons.error_outline_rounded;
        break;
      case ToastType.warning:
        accentColor = const Color(0xFFF59E0B);
        defaultIcon = Icons.warning_amber_rounded;
        break;
      case ToastType.info:
        accentColor = primaryColor;
        defaultIcon = Icons.info_outline_rounded;
        break;
    }

    final effectiveIcon = icon ?? defaultIcon;

    final Color bgColor = isAmoled
        ? const Color(0xFF151720)
        : (isDark ? const Color(0xFF1E212D) : const Color(0xFF0F172A));
    final Color borderColor = isAmoled
        ? const Color(0xFF262A36)
        : (isDark ? const Color(0xFF2E3344) : const Color(0xFF334155));

    return SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: bgColor,
      elevation: 8,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: BorderSide(color: borderColor, width: 1.0),
      ),
      duration: duration,
      content: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              effectiveIcon,
              size: 16,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(AppRadius.small),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  actionLabel,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Minimal Apple-style floating pill toast with blur-fade animation and zero backdrop overhead.
class _AppleToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final VoidCallback onDismissed;

  const _AppleToastWidget({
    required this.message,
    required this.type,
    this.icon,
    this.actionLabel,
    this.onAction,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_AppleToastWidget> createState() => _AppleToastWidgetState();
}

class _AppleToastWidgetState extends State<_AppleToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _opacityAnimation;
  late final Animation<double> _blurAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
    );

    // Apple-style scale pop
    _scaleAnimation = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    // Subtle slide upward into resting position
    _slideAnimation = Tween<double>(begin: 14.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    // Soft opacity fade
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutQuad,
        reverseCurve: Curves.easeInQuad,
      ),
    );

    // Blur dissolve effect (starts blurred, sharpens in; exits by dissolving into blur)
    _blurAnimation = Tween<double>(begin: 8.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _controller.forward();

    _dismissTimer = Timer(widget.duration, () {
      _dismiss();
    });
  }

  void _dismiss() {
    if (!mounted) return;
    _dismissTimer?.cancel();
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismissed();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isAmoled = AppColors.isAmoled(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color accentColor;
    IconData defaultIcon;

    switch (widget.type) {
      case ToastType.success:
        accentColor = AppColors.creditGreen;
        defaultIcon = Icons.check_circle_rounded;
        break;
      case ToastType.error:
        accentColor = AppColors.debitRed;
        defaultIcon = Icons.error_outline_rounded;
        break;
      case ToastType.warning:
        accentColor = const Color(0xFFF59E0B);
        defaultIcon = Icons.warning_amber_rounded;
        break;
      case ToastType.info:
        accentColor = primaryColor;
        defaultIcon = Icons.info_outline_rounded;
        break;
    }

    final effectiveIcon = widget.icon ?? defaultIcon;

    final Color bgColor = isAmoled
        ? const Color(0xFF14151B)
        : (isDark ? const Color(0xFF1A1D27) : const Color(0xFF0F172A));
    final Color borderColor = isAmoled
        ? const Color(0xFF262A36)
        : (isDark ? const Color(0xFF2E3344) : const Color(0xFF334155));

    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final bottomSafe = mediaQuery.padding.bottom;
    final double bottomPadding = bottomInset > 0
        ? bottomInset + 16.0
        : bottomSafe + 84.0;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, bottomPadding),
        child: GestureDetector(
          onTap: _dismiss,
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
              _dismiss();
            }
          },
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final opacity = _opacityAnimation.value.clamp(0.0, 1.0);
              final scale = _scaleAnimation.value;
              final slideY = _slideAnimation.value;
              final blur = _blurAnimation.value.clamp(0.0, 10.0);

              Widget content = child!;
              if (blur > 0.05) {
                content = ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: content,
                );
              }

              return Opacity(
                opacity: opacity,
                child: Transform.translate(
                  offset: Offset(0, slideY),
                  child: Transform.scale(
                    scale: scale,
                    child: content,
                  ),
                ),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: borderColor, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.2),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        effectiveIcon,
                        size: 15,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        widget.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (widget.actionLabel != null && widget.onAction != null) ...[
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          _dismiss();
                          widget.onAction!();
                        },
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            widget.actionLabel!,
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

