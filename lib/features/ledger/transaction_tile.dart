import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../core/utils/money_formatter.dart';
import '../../design_system/tokens.dart';
import '../../design_system/components/nummo_dialog.dart';
import '../../design_system/components/nummo_button.dart';

/// Interactive transaction tile supporting:
/// 1. Tap -> Opens read-only details modal.
/// 2. Swipe Left -> Reveals Edit and Delete action buttons.
/// 3. Edit -> Shows explicit confirmation before editing.
class TransactionTile extends StatefulWidget {
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

  @override
  State<TransactionTile> createState() => _TransactionTileState();
}

class _TransactionTileState extends State<TransactionTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _dragAnimation;
  double _dragOffset = 0.0;
  static const double _maxDrag = 80.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _dragAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(_controller)
      ..addListener(() {
        setState(() {
          _dragOffset = _dragAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_dragOffset == 0.0 && details.delta.dx > 0) {
      widget.onParentDragUpdate?.call(details);
      return;
    }
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(-_maxDrag, 0.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragOffset == 0.0) {
      widget.onParentDragEnd?.call();
      return;
    }
    if (_dragOffset < -_maxDrag / 2) {
      _animateTo(-_maxDrag);
    } else {
      _animateTo(0.0);
    }
  }

  void _animateTo(double target) {
    _dragAnimation = Tween<double>(begin: _dragOffset, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward(from: 0.0);
  }

  void _closeSwipe() {
    _animateTo(0.0);
  }

  Future<void> _handleConfirmEdit(BuildContext context) async {
    _closeSwipe();
    final confirmed = await NummoDialog.showConfirmDialog(
      context: context,
      title: 'Edit Transaction',
      message: 'Are you sure you want to edit "${widget.transaction.note}"?',
      confirmText: 'Proceed to Edit',
      isDestructive: false,
    );
    if (confirmed) {
      widget.onEdit();
    }
  }

  void _showDetailsModal(BuildContext context, CategoryTag catTag) {
    final t = widget.transaction;
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
                    color: isCredit ? AppColors.creditGreenBg : catTag.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Text(isCredit ? '📥' : catTag.emoji, style: const TextStyle(fontSize: 24)),
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
                          color: isCredit ? AppColors.creditGreenBg : catTag.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          isCredit ? '📥 Credit' : '${catTag.emoji} ${catTag.name}',
                          style: TextStyle(
                            color: isCredit ? AppColors.creditGreen : catTag.color,
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

            Row(
              children: [
                Expanded(
                  child: NummoButton(
                    text: 'Close',
                    variant: NummoButtonVariant.secondary,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: NummoButton(
                    text: 'Edit Entry',
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
    final catTag = CategoryTag.fromIdOrName(widget.transaction.tag);
    final isCredit = widget.transaction.isCredit;

    return Stack(
      children: [
        // Action Buttons Underneath (Right Aligned: Delete Only)
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () {
                _closeSwipe();
                widget.onDelete();
              },
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Container(
                width: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.debitRed,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
                    SizedBox(height: 2),
                    Text('Delete', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Foreground Card Row (Draggable horizontally)
        GestureDetector(
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          child: Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (_dragOffset != 0) {
                    _closeSwipe();
                  } else {
                    HapticFeedback.selectionClick();
                    _showDetailsModal(context, catTag);
                  }
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
                  ),
                  child: Row(
                    children: [
                      // Category Emoji / Credit Badge
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isCredit ? AppColors.creditGreenBg : catTag.color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          isCredit ? '📥' : catTag.emoji,
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
                              widget.transaction.note,
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
                                  DateFormat('hh:mm a').format(widget.transaction.timestamp),
                                  style: TextStyle(
                                    color: AppColors.textSecondary(context),
                                    fontSize: 12,
                                  ),
                                ),
                                if (!isCredit) ...[
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
                            MoneyFormatter.format(widget.transaction.amount, showSign: true, isCredit: isCredit),
                            style: TextStyle(
                              color: isCredit ? AppColors.creditGreen : AppColors.debitRed,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Bal: ${MoneyFormatter.format(widget.transaction.balanceAfter)}',
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
            ),
          ),
        ),
      ],
    );
  }
}
