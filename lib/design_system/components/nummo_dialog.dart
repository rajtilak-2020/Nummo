import 'package:flutter/material.dart';
import '../tokens.dart';
import 'nummo_button.dart';

/// Modal dialog and confirmation sheets.
class NummoDialog {
  /// Shows a clean 2-step irreversible confirmation dialog.
  static Future<bool> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmText,
    bool isDestructive = false,
    String? requireTypedText,
  }) async {
    final TextEditingController textController = TextEditingController();
    bool canConfirm = requireTypedText == null;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceCard(ctx),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              title: Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary(ctx),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      color: AppColors.textSecondary(ctx),
                      fontSize: 14,
                    ),
                  ),
                  if (requireTypedText != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Type "$requireTypedText" to confirm:',
                      style: TextStyle(
                        color: AppColors.textPrimary(ctx),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: textController,
                      autofocus: true,
                      onChanged: (val) {
                        setState(() {
                          canConfirm = val.trim().toUpperCase() == requireTypedText.toUpperCase();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: requireTypedText,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textSecondary(ctx)),
                  ),
                ),
                NummoButton(
                  text: confirmText,
                  fullWidth: false,
                  variant: isDestructive
                      ? NummoButtonVariant.destructive
                      : NummoButtonVariant.primary,
                  onPressed: canConfirm ? () => Navigator.of(ctx).pop(true) : null,
                ),
              ],
            );
          },
        );
      },
    );

    return result ?? false;
  }
}
