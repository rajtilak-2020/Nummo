import 'package:flutter/material.dart';
import '../tokens.dart';

/// Reusable neutral surface card component with 20px border radius and elevated micro-shadows.
class NummoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;

  const NummoCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.boxShadow,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = backgroundColor ?? AppColors.surfaceCard(context);
    final borderClr = borderColor ?? AppColors.cardBorder(context);

    final defaultShadows = isDark
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ]
        : [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: gradient == null ? bg : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: borderClr, width: 1),
        boxShadow: boxShadow ?? defaultShadows,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: Padding(
                  padding: padding ?? const EdgeInsets.all(AppSpacing.md),
                  child: child,
                ),
              )
            : Padding(
                padding: padding ?? const EdgeInsets.all(AppSpacing.md),
                child: child,
              ),
      ),
    );
  }
}

