import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../tokens.dart';

/// Luxury obsidian dialog prompting web users on first visit to download the native Android APK.
class AndroidAppPromptDialog {
  static const String githubReleasesUrl = 'https://github.com/rajtilak-2020/Nummo/releases';

  static Future<void> show(BuildContext context) async {
    HapticFeedback.lightImpact();
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceCard(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          contentPadding: const EdgeInsets.all(AppSpacing.lg),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.creditGreenBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.creditGreen.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.android_rounded,
                  color: AppColors.creditGreen,
                  size: 36,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Nummo Android App',
                style: TextStyle(
                  color: AppColors.textPrimary(ctx),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '100% Offline Personal Finance Ledger',
                style: TextStyle(
                  color: AppColors.creditGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Enjoy faster speed, touch haptic feedback, and biometric vault security with our native Android app.',
                style: TextStyle(
                  color: AppColors.textSecondary(ctx),
                  fontSize: 13,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  border: Border.all(
                    color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  children: [
                    _buildFeatureRow(ctx, Icons.wifi_off_rounded, '100% Local Storage & Offline'),
                    const SizedBox(height: 6),
                    _buildFeatureRow(ctx, Icons.fingerprint_rounded, 'Hardware Biometric Security'),
                    const SizedBox(height: 6),
                    _buildFeatureRow(ctx, Icons.offline_bolt_rounded, 'Instant Launch & Smoother UI'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final uri = Uri.parse(githubReleasesUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text(
                    'Get Android App (GitHub Releases)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.creditGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Continue using Web App',
                    style: TextStyle(
                      color: AppColors.textSecondary(ctx),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildFeatureRow(BuildContext context, IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
