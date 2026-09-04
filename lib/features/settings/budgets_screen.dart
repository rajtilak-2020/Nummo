import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/utils/money_formatter.dart';
import '../../design_system/components/animations.dart';
import '../../design_system/components/budget_dialog.dart';
import '../../design_system/components/nummo_card.dart';
import '../../design_system/components/nummo_dialog.dart';
import '../../design_system/tokens.dart';
import '../../models/budget.dart';
import '../../models/category.dart';
import '../../models/transaction.dart';

/// Dedicated screen for managing budget targets and viewing detailed spending health.
class BudgetsScreen extends StatefulWidget {
  final List<Budget> budgets;
  final List<CategoryTag> categories;
  final List<Transaction> transactions;
  final Future<void> Function(List<Budget> budgets) onUpdateBudgets;

  const BudgetsScreen({
    super.key,
    required this.budgets,
    required this.categories,
    required this.transactions,
    required this.onUpdateBudgets,
  });

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  late List<Budget> _budgets;

  @override
  void initState() {
    super.initState();
    _budgets = List<Budget>.from(widget.budgets);
  }

  @override
  void didUpdateWidget(covariant BudgetsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.budgets != widget.budgets) {
      _budgets = List<Budget>.from(widget.budgets);
    }
  }

  void _openBudgetDialog([Budget? existing]) {
    BudgetDialog.show(
      context,
      existingBudget: existing,
      categories: widget.categories,
      onSave: (b) async {
        final updated = List<Budget>.from(_budgets);
        if (existing != null) {
          final idx = updated.indexWhere((item) => item.id == existing.id);
          if (idx != -1) updated[idx] = b;
        } else {
          updated.add(b);
        }
        setState(() => _budgets = updated);
        await widget.onUpdateBudgets(updated);
      },
      onDelete: existing == null ? null : () => _confirmDeleteBudget(existing),
    );
  }

  Future<void> _confirmDeleteBudget(Budget b) async {
    final confirmed = await NummoDialog.showConfirmDialog(
      context: context,
      title: 'Delete Budget',
      message:
          'Are you sure you want to delete budget "${b.title}" of ${MoneyFormatter.format(b.amount)}?',
      confirmText: 'Delete',
      isDestructive: true,
    );
    if (confirmed) {
      final updated = _budgets.where((item) => item.id != b.id).toList();
      setState(() => _budgets = updated);
      await widget.onUpdateBudgets(updated);
      if (mounted) {
        NummoToast.success(context, message: 'Deleted budget "${b.title}"');
      }
    }
  }

  String _getBudgetPeriodChipText(Budget b) {
    switch (b.period) {
      case BudgetPeriod.weekly:
        return b.isRecurring ? 'Weekly' : 'Weekly (1x)';
      case BudgetPeriod.monthly:
        return b.isRecurring ? 'Monthly' : 'Monthly (1x)';
      case BudgetPeriod.custom:
        if (b.endDate != null) {
          final s = DateFormat('dd MMM').format(b.startDate);
          final e = DateFormat('dd MMM').format(b.endDate!);
          return '$s – $e';
        }
        return 'Custom';
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs, left: 4),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.textSecondary(context),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildOverviewHeroCard({
    required double totalSpent,
    required double totalLimit,
    required double ratio,
    required bool isExceeded,
    required double excess,
    required double remaining,
    required int percentage,
    required Color statusColor,
    required bool isDark,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard(context),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: isExceeded
              ? AppColors.debitRed.withValues(alpha: 0.35)
              : AppColors.cardBorder(context),
          width: isExceeded ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.22)
                : const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.insights_rounded,
                        size: 16,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Overall Budget',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  isExceeded
                      ? 'Exceeded ($percentage%)'
                      : '$percentage% utilized',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL SPENT',
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      MoneyFormatter.format(totalSpent),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isExceeded
                            ? AppColors.debitRed
                            : AppColors.textPrimary(context),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'TOTAL CEILING',
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      MoneyFormatter.format(totalLimit),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              backgroundColor: isDark
                  ? const Color(0xFF262A36)
                  : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_budgets.length} Active Target${_budgets.length == 1 ? '' : 's'}',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Flexible(
                child: Text(
                  isExceeded
                      ? '+${MoneyFormatter.format(excess)} exceeded'
                      : '${MoneyFormatter.format(remaining)} remaining',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: isExceeded
                        ? AppColors.debitRed
                        : (ratio >= 0.85
                              ? const Color(0xFFF59E0B)
                              : AppColors.creditGreen),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard(Budget b) {
    final isOverall = b.scope == 'overall';
    final cat = isOverall
        ? null
        : CategoryTag.fromIdOrName(b.scope, widget.categories);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final cardAccent = isOverall ? primaryColor : (cat?.color ?? primaryColor);
    final cardEmoji = isOverall
        ? '🎯'
        : (cat?.emoji.trim().isNotEmpty == true ? cat!.emoji : '🎯');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final spent = b.calculateSpent(widget.transactions);
    final limit = b.amount;
    final ratio = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final isExceeded = spent > limit;
    final remaining = !isExceeded ? (limit - spent) : 0.0;
    final excess = isExceeded ? (spent - limit) : 0.0;
    final percentage = limit > 0 ? ((spent / limit) * 100).round() : 0;

    final Color statusColor = isExceeded
        ? AppColors.debitRed
        : (ratio >= 0.85 ? const Color(0xFFF59E0B) : AppColors.creditGreen);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: NummoBouncy(
        scaleFactor: 0.98,
        onTap: () {
          HapticFeedback.selectionClick();
          _openBudgetDialog(b);
        },
        onLongPress: () {
          HapticFeedback.heavyImpact();
          _confirmDeleteBudget(b);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard(context),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: isExceeded
                  ? AppColors.debitRed.withValues(alpha: 0.35)
                  : AppColors.cardBorder(context),
              width: isExceeded ? 1.2 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.22)
                    : const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Row: Avatar, Title & Badges, Quick Edit Icon
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cardAccent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: cardAccent.withValues(alpha: 0.25),
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      cardEmoji,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            // Scope Pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: cardAccent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                              child: Text(
                                isOverall
                                    ? '🌐 Overall'
                                    : (cat?.name ?? 'Category'),
                                style: TextStyle(
                                  color: cardAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Period Pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF202330)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (b.isRecurring) ...[
                                    Icon(
                                      Icons.repeat_rounded,
                                      size: 10,
                                      color: AppColors.textSecondary(context),
                                    ),
                                    const SizedBox(width: 3),
                                  ],
                                  Text(
                                    _getBudgetPeriodChipText(b),
                                    style: TextStyle(
                                      color: AppColors.textSecondary(context),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.04),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 2. Spending vs Limit Metric Numbers
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SPENT',
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          MoneyFormatter.format(spent),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isExceeded
                                ? AppColors.debitRed
                                : AppColors.textPrimary(context),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'BUDGET LIMIT',
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          MoneyFormatter.format(limit),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 3. Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor: isDark
                      ? const Color(0xFF262A36)
                      : const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
              const SizedBox(height: 8),

              // 4. Footer: Status Badge & Remaining / Over
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      isExceeded
                          ? 'Exceeded ($percentage%)'
                          : '$percentage% of limit',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      isExceeded
                          ? '+${MoneyFormatter.format(excess)} over'
                          : '${MoneyFormatter.format(remaining)} left',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: isExceeded
                            ? AppColors.debitRed
                            : (ratio >= 0.85
                                  ? const Color(0xFFF59E0B)
                                  : AppColors.creditGreen),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
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

  Widget _buildEmptyState() {
    return NummoCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Center(
          child: Column(
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.track_changes_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'No Budget Targets Configured',
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Set spending ceilings for categories or overall expenses to track and control outflow.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text(
                  'Create Budget Target',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                onPressed: () => _openBudgetDialog(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    double totalSpent = 0;
    double totalLimit = 0;
    for (final b in _budgets) {
      totalSpent += b.calculateSpent(widget.transactions);
      totalLimit += b.amount;
    }
    final double ratio = totalLimit > 0
        ? (totalSpent / totalLimit).clamp(0.0, 1.0)
        : 0.0;
    final bool isExceeded = totalSpent > totalLimit;
    final double excess = isExceeded ? (totalSpent - totalLimit) : 0.0;
    final double remaining = !isExceeded ? (totalLimit - totalSpent) : 0.0;
    final int percentage = totalLimit > 0
        ? ((totalSpent / totalLimit) * 100).round()
        : 0;
    final Color statusColor = isExceeded
        ? AppColors.debitRed
        : (ratio >= 0.85 ? const Color(0xFFF59E0B) : AppColors.creditGreen);

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.track_changes_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.sm),
            const Flexible(
              child: Text(
                'Budget Targets',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 22),
            tooltip: 'Add Budget Target',
            onPressed: () => _openBudgetDialog(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          MediaQuery.of(context).padding.bottom + 80,
        ),
        children: [
          if (_budgets.isEmpty)
            _buildEmptyState()
          else ...[
            _buildOverviewHeroCard(
              totalSpent: totalSpent,
              totalLimit: totalLimit,
              ratio: ratio,
              isExceeded: isExceeded,
              excess: excess,
              remaining: remaining,
              percentage: percentage,
              statusColor: statusColor,
              isDark: isDark,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('ACTIVE CEILINGS'),
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${_budgets.length}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ..._budgets.map((b) => _buildBudgetCard(b)),
          ],
        ],
      ),
      floatingActionButton: _budgets.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _openBudgetDialog(),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                'Add Target',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            )
          : null,
    );
  }
}
