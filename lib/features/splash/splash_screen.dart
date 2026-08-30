import 'package:flutter/material.dart';
import '../../design_system/tokens.dart';

/// Minimal, clean splash screen without logo.
/// Renders instantly during early frame hydration without adding any artificial delay.
class NummoSplashScreen extends StatelessWidget {
  final Color primaryColor;
  final bool isDark;

  const NummoSplashScreen({
    super.key,
    required this.primaryColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppColors.darkScaffold : AppColors.lightScaffold;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subtextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'NUMMO',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 6.0,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'TRACK EVERY RUPEE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.5,
                color: subtextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
