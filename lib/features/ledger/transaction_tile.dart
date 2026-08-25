import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../core/utils/money_formatter.dart';
import '../../design_system/tokens.dart';
import '../../design_system/components/animations.dart';
import '../../design_system/components/nummo_dialog.dart';
import '../../design_system/components/nummo_button.dart';

/// Grouped Date Card that wraps all transactions for a specific date inside
/// a single unified Apple-grade surface card with sleek dividers and daily net totals.
class TransactionDateGroupCard extends StatelessWidget {
  final String dateTitle;
  final List<Transaction> transactions;
  final List<CategoryTag>? categories;
  final void Function(Transaction txn) onEdit;
  final void Function(Transaction txn) onDelete;
  final bool isMasked;
  final void Function(DragUpdateDetails details)? onParentDragUpdate;
  final VoidCallback? onParentDragEnd;

  const TransactionDateGroupCard({
    super.key,
    required this.dateTitle,
    required this.transactions,
    this.categories,
    required this.onEdit,
    required this.onDelete,
    this.isMasked = false,
    this.onParentDragUpdate,
    this.onParentDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) return const SizedBox.shrink();

    // Calculate daily net cash flow
    double dayCredit = 0;
    double dayDebit = 0;
    for (final t in transactions) {
      if (t.isCredit) {
        dayCredit += t.amount;
      } else {
        dayDebit += t.amount;
      }
    }
    final netDay = dayCredit - dayDebit;
    final showNetPill = transactions.length >= 2 && (dayCredit > 0 || dayDebit > 0);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard(context),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.cardBorder(context)),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black.withValues(alpha: 0.22)
                  : const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Top Header: Date Title + Daily NET Total Pill
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateTitle,
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (showNetPill)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: netDay >= 0
                            ? AppColors.creditGreenBg
                            : AppColors.debitRedBg,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        'NET: ${netDay >= 0 ? '+' : ''}${MoneyFormatter.format(netDay, isMasked: isMasked)}',
                        style: TextStyle(
                          color: netDay >= 0
                              ? AppColors.creditGreen
                              : AppColors.debitRed,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Top Header Separator Divider
            Divider(
              height: 1,
              thickness: 0.8,
              color: AppColors.cardBorder(context).withValues(alpha: 0.8),
            ),

            // Date Transactions List Rows
            for (int i = 0; i < transactions.length; i++) ...[
              TransactionTile(
                transaction: transactions[i],
                categories: categories,
                isGrouped: true,
                isMasked: isMasked,
                isFirst: i == 0,
                isLast: i == transactions.length - 1,
                onEdit: () => onEdit(transactions[i]),
                onDelete: () => onDelete(transactions[i]),
                onParentDragUpdate: onParentDragUpdate,
                onParentDragEnd: onParentDragEnd,
              ),
              if (i < transactions.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 62, right: 14),
                  child: Divider(
                    height: 1,
                    thickness: 0.8,
                    color: AppColors.cardBorder(context).withValues(alpha: 0.7),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Interactive transaction tile that opens a details and actions modal on click/tap.
/// Supports both standalone card display and unified grouped date rows with seamless dividers.
class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final List<CategoryTag>? categories;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isGrouped;
  final bool isMasked;
  final bool isFirst;
  final bool isLast;
  final void Function(DragUpdateDetails details)? onParentDragUpdate;
  final VoidCallback? onParentDragEnd;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.categories,
    required this.onEdit,
    required this.onDelete,
    this.isGrouped = false,
    this.isMasked = false,
    this.isFirst = false,
    this.isLast = false,
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
                        Text(
                          'Date & Time',
                          style: TextStyle(color: AppColors.textSecondary(ctx), fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('dd MMM yyyy, hh:mm a').format(t.timestamp),
                          style: TextStyle(
                            color: AppColors.textPrimary(ctx),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
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
                        Text(
                          'Balance After',
                          style: TextStyle(color: AppColors.textSecondary(ctx), fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          MoneyFormatter.format(t.balanceAfter),
                          style: TextStyle(
                            color: AppColors.textPrimary(ctx),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Actions: Edit and Delete Buttons
            Row(
              children: [
                Expanded(
                  child: NummoButton(
                    text: 'Edit',
                    icon: Icons.edit_rounded,
                    variant: NummoButtonVariant.outline,
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _handleConfirmEdit(context);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
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
    final catTag = CategoryTag.fromIdOrName(transaction.tag, categories);
    final isCredit = transaction.isCredit;

    final tileContent = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isGrouped ? AppSpacing.md : AppSpacing.md,
        vertical: isGrouped ? 12 : AppSpacing.sm + 4,
      ),
      child: Row(
        children: [
          // Category Emoji / Credit Badge
          Container(
            width: isGrouped ? 40 : 42,
            height: isGrouped ? 40 : 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isCredit
                  ? (transaction.tag != null ? catTag.color.withValues(alpha: 0.12) : AppColors.creditGreenBg)
                  : catTag.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              isCredit ? (transaction.tag != null ? catTag.emoji : '📥') : catTag.emoji,
              style: TextStyle(fontSize: isGrouped ? 19 : 20),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Note & Time / Category Badge
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
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
                MoneyFormatter.format(transaction.amount, showSign: true, isCredit: isCredit, isMasked: isMasked),
                style: TextStyle(
                  color: isCredit ? AppColors.creditGreen : AppColors.debitRed,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Bal: ${MoneyFormatter.format(transaction.balanceAfter, isMasked: isMasked)}',
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
    );

    if (isGrouped) {
      // Grouped row inside a unified Date Card
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            _showDetailsModal(context, catTag);
          },
          child: tileContent,
        ),
      );
    }

    // Standalone Card Mode
    return NummoBouncy(
      scaleFactor: 0.98,
      onTap: () {
        HapticFeedback.selectionClick();
        _showDetailsModal(context, catTag);
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: AppTouchTarget.minHeight),
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
        child: tileContent,
      ),
    );
  }
}
