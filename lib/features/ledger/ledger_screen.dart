import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../core/utils/money_formatter.dart';
import '../../design_system/tokens.dart';
import '../../design_system/components/nummo_card.dart';
import '../../design_system/components/nummo_dialog.dart';
import 'transaction_tile.dart';
import 'add_transaction_sheet.dart';
import 'logs_filter_sheet.dart';

/// Main Ledger Screen showing balance summary and grouped transactions.
class LedgerScreen extends StatefulWidget {
  final List<Transaction> transactions;
  final List<CategoryTag> categories;
  final Future<void> Function(Transaction txn) onAddTransaction;
  final Future<void> Function(Transaction txn) onUpdateTransaction;
  final Future<void> Function(String id) onDeleteTransaction;

  final Future<void> Function(List<CategoryTag> categories)? onUpdateCategories;
  final Future<void> Function(CategoryTag category)? onCreateCategory;

  const LedgerScreen({
    super.key,
    required this.transactions,
    required this.categories,
    required this.onAddTransaction,
    required this.onUpdateTransaction,
    required this.onDeleteTransaction,
    this.onUpdateCategories,
    this.onCreateCategory,
  });

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  LogsFilterOptions _filterOptions = const LogsFilterOptions();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddSheet([Transaction? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddTransactionSheet(
        existingTransaction: existing,
        availableCategories: widget.categories,
        onCreateCategory: widget.onCreateCategory,
        onUpdateCategories: widget.onUpdateCategories,
        onSave: (txn) async {
          if (existing != null) {
            await widget.onUpdateTransaction(txn);
          } else {
            await widget.onAddTransaction(txn);
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(Transaction txn) async {
    final confirmed = await NummoDialog.showConfirmDialog(
      context: context,
      title: 'Delete Transaction',
      message: 'Are you sure you want to delete "${txn.note}" of ${MoneyFormatter.format(txn.amount)}?',
      confirmText: 'Delete',
      isDestructive: true,
    );
    if (confirmed) {
      await widget.onDeleteTransaction(txn.id);
      if (mounted) {
        NummoToast.show(
          context,
          message: 'Deleted "${txn.note}"',
          type: ToastType.error,
          icon: Icons.delete_outline_rounded,
          actionLabel: 'UNDO',
          duration: const Duration(seconds: 4),
          onAction: () async {
            HapticFeedback.mediumImpact();
            await widget.onAddTransaction(txn);
            if (mounted) {
              NummoToast.success(
                context,
                message: 'Restored "${txn.note}"',
                icon: Icons.restore_rounded,
              );
            }
          },
        );
      }
    }
  }

  void _openFilterSheet() {
    LogsFilterSheet.show(
      context,
      initialOptions: _filterOptions,
      categories: widget.categories,
      allTransactions: widget.transactions,
      currentSearchQuery: _searchQuery,
      onApply: (newOptions) {
        setState(() {
          _filterOptions = newOptions;
        });
      },
    );
  }

  void _resetAllFilters() {
    HapticFeedback.selectionClick();
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _filterOptions = const LogsFilterOptions();
    });
  }

  String _getDateFilterLabel(LogsDateFilter filter, DateTime? customStart, DateTime? customEnd) {
    switch (filter) {
      case LogsDateFilter.allTime:
        return 'All Time';
      case LogsDateFilter.today:
        return 'Today';
      case LogsDateFilter.thisWeek:
        return 'This Week';
      case LogsDateFilter.thisMonth:
        return 'This Month';
      case LogsDateFilter.thisYear:
        return 'This Year';
      case LogsDateFilter.customRange:
        if (customStart != null && customEnd != null) {
          return '${DateFormat('dd MMM').format(customStart)} - ${DateFormat('dd MMM').format(customEnd)}';
        }
        return 'Custom';
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final hasActiveFilters = _filterOptions.activeFilterCount > 0;

    double totalIn = 0.0;
    double totalOut = 0.0;
    for (final t in widget.transactions) {
      if (t.isCredit) {
        totalIn += t.amount;
      } else {
        totalOut += t.amount;
      }
    }
    final netBalance = totalIn - totalOut;

    final filtered = _filterOptions.apply(
      transactions: widget.transactions,
      searchQuery: _searchQuery,
    );

    final Map<String, List<Transaction>> grouped = {};
    if (_filterOptions.sortOrder == LogsSortOrder.highestAmount ||
        _filterOptions.sortOrder == LogsSortOrder.lowestAmount) {
      final key = '${_filterOptions.sortOrder.label} (${filtered.length})';
      grouped[key] = filtered;
    } else {
      for (final t in filtered) {
        final key = DateFormat('EEE, dd MMM yyyy').format(t.timestamp);
        grouped.putIfAbsent(key, () => []).add(t);
      }
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: NummoCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Balance', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppSpacing.xs),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        MoneyFormatter.format(netBalance),
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: netBalance >= 0 ? AppColors.creditGreen : AppColors.debitRed,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Income (In)', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  MoneyFormatter.format(totalIn),
                                  maxLines: 1,
                                  softWrap: false,
                                  style: const TextStyle(color: AppColors.creditGreen, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 36, color: AppColors.cardBorder(context)),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Expenses (Out)', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    MoneyFormatter.format(totalOut),
                                    maxLines: 1,
                                    softWrap: false,
                                    style: const TextStyle(color: AppColors.debitRed, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard(context),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  border: Border.all(
                    color: hasActiveFilters
                        ? primaryColor.withValues(alpha: 0.6)
                        : AppColors.cardBorder(context),
                    width: hasActiveFilters ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.04,
                      ),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: 12),
                    Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppColors.textSecondary(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search transactions...',
                          hintStyle: TextStyle(
                            color: AppColors.textSecondary(context).withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          isDense: true,
                          fillColor: Colors.transparent,
                          filled: false,
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: AppColors.textSecondary(context),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        tooltip: 'Clear search',
                        splashRadius: 18,
                        visualDensity: VisualDensity.compact,
                      ),
                    Container(
                      width: 1,
                      height: 24,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: AppColors.cardBorder(context),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _openFilterSheet,
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(AppRadius.control - 1),
                        ),
                        child: Container(
                          height: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.center,
                          decoration: hasActiveFilters
                              ? BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.12),
                                  borderRadius: const BorderRadius.horizontal(
                                    right: Radius.circular(AppRadius.control - 1),
                                  ),
                                )
                              : null,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                size: 19,
                                color: hasActiveFilters
                                    ? primaryColor
                                    : AppColors.textPrimary(context),
                              ),
                              if (hasActiveFilters) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                  ),
                                  child: Text(
                                    '${_filterOptions.activeFilterCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (hasActiveFilters)
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
                child: Row(
                  children: [
                    if (_filterOptions.typeFilter != TransactionTypeFilter.all)
                      _buildActiveFilterChip(
                        label: _filterOptions.typeFilter == TransactionTypeFilter.inOnly ? '📥 Income' : '📤 Expense',
                        color: _filterOptions.typeFilter == TransactionTypeFilter.inOnly
                            ? AppColors.creditGreen
                            : AppColors.debitRed,
                        onRemove: () {
                          HapticFeedback.selectionClick();
                          setState(() => _filterOptions = _filterOptions.copyWith(typeFilter: TransactionTypeFilter.all));
                        },
                      ),
                    ..._filterOptions.selectedCategoryIds.map((catId) {
                      final tag = CategoryTag.fromIdOrName(catId, widget.categories);
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _buildActiveFilterChip(
                          label: '${tag.emoji} ${tag.name}',
                          color: tag.color,
                          onRemove: () {
                            HapticFeedback.selectionClick();
                            final updated = Set<String>.from(_filterOptions.selectedCategoryIds)..remove(catId);
                            setState(() => _filterOptions = _filterOptions.copyWith(selectedCategoryIds: updated));
                          },
                        ),
                      );
                    }),
                    if (_filterOptions.dateFilter != LogsDateFilter.allTime)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _buildActiveFilterChip(
                          label: '📅 ${_getDateFilterLabel(_filterOptions.dateFilter, _filterOptions.customStartDate, _filterOptions.customEndDate)}',
                          color: primaryColor,
                          onRemove: () {
                            HapticFeedback.selectionClick();
                            setState(() => _filterOptions = _filterOptions.copyWith(
                                  dateFilter: LogsDateFilter.allTime,
                                  clearCustomDates: true,
                                ));
                          },
                        ),
                      ),
                    if (_filterOptions.sortOrder != LogsSortOrder.newestFirst)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _buildActiveFilterChip(
                          label: '↕️ ${_filterOptions.sortOrder.label}',
                          color: primaryColor,
                          onRemove: () {
                            HapticFeedback.selectionClick();
                            setState(() => _filterOptions = _filterOptions.copyWith(sortOrder: LogsSortOrder.newestFirst));
                          },
                        ),
                      ),
                    if (_filterOptions.minAmount != null || _filterOptions.maxAmount != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _buildActiveFilterChip(
                          label: '₹ ${_filterOptions.minAmount != null ? _filterOptions.minAmount!.toStringAsFixed(0) : '0'} - ${_filterOptions.maxAmount != null ? _filterOptions.maxAmount!.toStringAsFixed(0) : '∞'}',
                          color: primaryColor,
                          onRemove: () {
                            HapticFeedback.selectionClick();
                            setState(() => _filterOptions = _filterOptions.copyWith(clearAmounts: true));
                          },
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: InkWell(
                        onTap: _resetAllFilters,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.debitRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(color: AppColors.debitRed.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh_rounded, size: 13, color: AppColors.debitRed),
                              SizedBox(width: 4),
                              Text(
                                'Clear all',
                                style: TextStyle(
                                  color: AppColors.debitRed,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.filter_alt_off_rounded,
                        size: 44,
                        color: AppColors.textSecondary(context).withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        widget.transactions.isEmpty ? 'No transactions yet' : 'No matching transactions',
                        style: TextStyle(color: AppColors.textPrimary(context), fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      if (hasActiveFilters || _searchQuery.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        TextButton.icon(
                          onPressed: _resetAllFilters,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Clear Search & Filters'),
                          style: TextButton.styleFrom(foregroundColor: primaryColor),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final dateKey = grouped.keys.elementAt(index);
                  final items = grouped[dateKey]!;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: TransactionDateGroupCard(
                      dateTitle: dateKey,
                      transactions: items,
                      categories: widget.categories,
                      onEdit: (txn) => _openAddSheet(txn),
                      onDelete: (txn) => _confirmDelete(txn),
                    ),
                  );
                },
                childCount: grouped.keys.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChip({
    required String label,
    required Color color,
    required VoidCallback onRemove,
  }) {
    return InkWell(
      onTap: _openFilterSheet,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.close_rounded,
                  size: 13,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
