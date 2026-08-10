import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens.dart';

enum NummoButtonVariant { primary, secondary, destructive, success, outline }

/// Accessible button component with minimum 48px height and WCAG contrast compliant colors.
class NummoButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final NummoButtonVariant variant;
  final bool isLoading;
  final bool fullWidth;

  const NummoButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.variant = NummoButtonVariant.primary,
    this.isLoading = false,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color bg;
    Color fg;
    BorderSide border = BorderSide.none;

    switch (variant) {
      case NummoButtonVariant.primary:
        bg = colorScheme.primary;
        fg = colorScheme.onPrimary;
        break;
      case NummoButtonVariant.secondary:
        bg = colorScheme.brightness == Brightness.dark
            ? const Color(0xFF262A36)
            : const Color(0xFFE2E8F0);
        fg = AppColors.textPrimary(context);
        break;
      case NummoButtonVariant.destructive:
        bg = AppColors.debitRed;
        fg = Colors.white;
        break;
      case NummoButtonVariant.success:
        bg = AppColors.creditGreen;
        fg = Colors.white;
        break;
      case NummoButtonVariant.outline:
        bg = Colors.transparent;
        fg = colorScheme.primary;
        border = BorderSide(color: colorScheme.primary, width: 1.5);
        break;
    }

    Widget content;
    if (isLoading) {
      content = SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(fg),
        ),
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: variant == NummoButtonVariant.primary ? 2 : 0,
      shadowColor: variant == NummoButtonVariant.primary ? bg.withValues(alpha: 0.4) : Colors.transparent,
      minimumSize: const Size(0, AppTouchTarget.minHeight),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: border,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
    );

    final button = ElevatedButton(
      onPressed: (onPressed == null || isLoading)
          ? null
          : () {
              HapticFeedback.selectionClick();
              onPressed!();
            },
      style: buttonStyle,
      child: content,
    );

    if (fullWidth) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }
    return button;
  }
}
