import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../core/utils/money_formatter.dart';
import '../../design_system/tokens.dart';
import '../../design_system/components/nummo_dialog.dart';
import '../../design_system/components/nummo_button.dart';

/// Interactive transaction tile that opens a details and actions modal on click/tap.
/// The modal contains the transaction details along with Delete and Edit action buttons.
class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(DragUpdateDetails details)? onParentDragUpdate;
  final VoidCallback? onParentDragEnd;

  const TransactionTile({
    super.key,
    required this.transaction,
    required this.onEdit,
    required this.onDelete,
    this.onParentDragUpdate,
    this.onParentDragEnd,
  });

  Future<void> _handleConfirmEdit(BuildContext context) async {
    final confirmed = await NummoDialog.showConfirmDialog(
      context: context,
      title: 'Edit Transaction',
      message: 'Are you sure you want to edit "${transaction.note}"?',
      confirmText: 'Proceed to Edit',
      isDestructive: false,
    );
    if (confirmed) {
      onEdit();
    }
  }

  void _showDetailsModal(BuildContext context, CategoryTag catTag) {
    final t = transaction;
    final isCredit = t.isCredit;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard(ctx),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder(ctx),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isCredit
                        ? (t.tag != null ? catTag.color.withValues(alpha: 0.15) : AppColors.creditGreenBg)
                        : catTag.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    isCredit ? (t.tag != null ? catTag.emoji : '📥') : catTag.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.note,
                        style: TextStyle(
                          color: AppColors.textPrimary(ctx),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isCredit
                              ? (t.tag != null ? catTag.color.withValues(alpha: 0.1) : AppColors.creditGreenBg)
                              : catTag.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          isCredit
                              ? (t.tag != null ? '📥 ${catTag.emoji} ${catTag.name}' : '📥 Credit')
                              : '${catTag.emoji} ${catTag.name}',
                          style: TextStyle(
                            color: isCredit
                                ? (t.tag != null ? catTag.color : AppColors.creditGreen)
                                : catTag.color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Amount Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isCredit ? AppColors.creditGreenBg : AppColors.debitRedBg,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCredit ? 'Credit Entry (Income)' : 'Debit Entry (Expense)',
                    style: TextStyle(
                      color: isCredit ? AppColors.creditGreen : AppColors.debitRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    MoneyFormatter.format(t.amount, showSign: true, isCredit: isCredit),
                    style: TextStyle(
                      color: isCredit ? AppColors.creditGreen : AppColors.debitRed,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Details Grid
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm + 4),
                    decoration: BoxDecoration(
                      color: AppColors.scaffoldBackground(ctx),
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      border: Border.all(color: AppColors.cardBorder(ctx)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date & Time', style: TextStyle(color: AppColors.textSecondary(ctx), fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('dd MMM yyyy, hh:mm a').format(t.timestamp),
                          style: TextStyle(color: AppColors.textPrimary(ctx), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm + 4),
                    decoration: BoxDecoration(
                      color: AppColors.scaffoldBackground(ctx),
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      border: Border.all(color: AppColors.cardBorder(ctx)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Balance After', style: TextStyle(color: AppColors.textSecondary(ctx), fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          MoneyFormatter.format(t.balanceAfter),
                          style: TextStyle(color: AppColors.textPrimary(ctx), fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Modal Actions: Delete & Edit
            Row(
              children: [
                Expanded(
                  child: NummoButton(
                    text: 'Delete',
                    icon: Icons.delete_outline_rounded,
                    variant: NummoButtonVariant.destructive,
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onDelete();
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: NummoButton(
                    text: 'Edit',
                    icon: Icons.edit_rounded,
                    variant: NummoButtonVariant.primary,
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _handleConfirmEdit(context);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catTag = CategoryTag.fromIdOrName(transaction.tag);
    final isCredit = transaction.isCredit;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          _showDetailsModal(context, catTag);
        },
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppTouchTarget.minHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 4,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard(context),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.cardBorder(context)),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: 0.25)
                    : const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Category Emoji / Credit Badge
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isCredit
                      ? (transaction.tag != null ? catTag.color.withValues(alpha: 0.12) : AppColors.creditGreenBg)
                      : catTag.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  isCredit ? (transaction.tag != null ? catTag.emoji : '📥') : catTag.emoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Note & Time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      transaction.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          DateFormat('hh:mm a').format(transaction.timestamp),
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 12,
                          ),
                        ),
                        if (transaction.tag != null) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: catTag.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              '${catTag.emoji} ${catTag.name}',
                              style: TextStyle(
                                color: catTag.color,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Amount & Running Balance
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    MoneyFormatter.format(transaction.amount, showSign: true, isCredit: isCredit),
                    style: TextStyle(
                      color: isCredit ? AppColors.creditGreen : AppColors.debitRed,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Bal: ${MoneyFormatter.format(transaction.balanceAfter)}',
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
