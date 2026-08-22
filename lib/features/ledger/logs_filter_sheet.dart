import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../core/utils/money_formatter.dart';
import '../../design_system/tokens.dart';
import '../../design_system/components/nummo_button.dart';

/// Transaction flow type filter (All, In / Income, Out / Expense).
enum TransactionTypeFilter {
  all('All'),
  inOnly('Income'),
  outOnly('Expense');

  final String label;
  const TransactionTypeFilter(this.label);
}

/// Predefined date period filters for transaction logs.
enum LogsDateFilter {
  allTime('All Time'),
  today('Today'),
  thisWeek('This Week'),
  thisMonth('This Month'),
  thisYear('This Year'),
  customRange('Custom');

  final String label;
  const LogsDateFilter(this.label);
}

/// Sort orders for transaction logs.
enum LogsSortOrder {
  newestFirst('Newest First (Latest)'),
  oldestFirst('Oldest First'),
  highestAmount('Highest Amount'),
  lowestAmount('Lowest Amount');

  final String label;
  const LogsSortOrder(this.label);
}

/// Immutable state encapsulating all active filter and sort options for transaction logs.
class LogsFilterOptions {
  final TransactionTypeFilter typeFilter;
  final Set<String> selectedCategoryIds; // Empty = All categories
  final LogsDateFilter dateFilter;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final LogsSortOrder sortOrder;
  final double? minAmount;
  final double? maxAmount;

  const LogsFilterOptions({
    this.typeFilter = TransactionTypeFilter.all,
    this.selectedCategoryIds = const {},
    this.dateFilter = LogsDateFilter.allTime,
    this.customStartDate,
    this.customEndDate,
    this.sortOrder = LogsSortOrder.newestFirst,
    this.minAmount,
    this.maxAmount,
  });

  /// Returns true if all settings are at their default states.
  bool get isDefault =>
      typeFilter == TransactionTypeFilter.all &&
      selectedCategoryIds.isEmpty &&
      dateFilter == LogsDateFilter.allTime &&
      sortOrder == LogsSortOrder.newestFirst &&
      minAmount == null &&
      maxAmount == null;

  /// Number of active non-default filter criteria.
  int get activeFilterCount {
    int count = 0;
    if (typeFilter != TransactionTypeFilter.all) count++;
    if (selectedCategoryIds.isNotEmpty) count++;
    if (dateFilter != LogsDateFilter.allTime) count++;
    if (sortOrder != LogsSortOrder.newestFirst) count++;
    if (minAmount != null || maxAmount != null) count++;
    return count;
  }

  LogsFilterOptions copyWith({
    TransactionTypeFilter? typeFilter,
    Set<String>? selectedCategoryIds,
    LogsDateFilter? dateFilter,
    DateTime? customStartDate,
    DateTime? customEndDate,
    LogsSortOrder? sortOrder,
    double? minAmount,
    double? maxAmount,
    bool clearCustomDates = false,
    bool clearAmounts = false,
  }) {
    return LogsFilterOptions(
      typeFilter: typeFilter ?? this.typeFilter,
      selectedCategoryIds: selectedCategoryIds ?? this.selectedCategoryIds,
      dateFilter: dateFilter ?? this.dateFilter,
      customStartDate: clearCustomDates ? null : (customStartDate ?? this.customStartDate),
      customEndDate: clearCustomDates ? null : (customEndDate ?? this.customEndDate),
      sortOrder: sortOrder ?? this.sortOrder,
      minAmount: clearAmounts ? null : (minAmount ?? this.minAmount),
      maxAmount: clearAmounts ? null : (maxAmount ?? this.maxAmount),
    );
  }

  /// Evaluates and applies all search query, flow type, category, date range, and sort rules.
  List<Transaction> apply({
    required List<Transaction> transactions,
    required String searchQuery,
  }) {
    final q = searchQuery.trim().toLowerCase();

    final filtered = transactions.where((t) {
      // 1. Search Query (note, amount, tag)
      if (q.isNotEmpty) {
        final matchesNote = t.note.toLowerCase().contains(q);
        final matchesAmount = t.amount.toString().contains(q) ||
            MoneyFormatter.format(t.amount).toLowerCase().contains(q);
        final matchesTag = (t.tag ?? '').toLowerCase().contains(q);
        if (!matchesNote && !matchesAmount && !matchesTag) {
          return false;
        }
      }

      // 2. Type Filter (Credit / Debit)
      if (typeFilter == TransactionTypeFilter.inOnly && !t.isCredit) return false;
      if (typeFilter == TransactionTypeFilter.outOnly && t.isCredit) return false;

      // 3. Category Filter
      if (selectedCategoryIds.isNotEmpty) {
        final tagId = t.tag ?? 'OTHER';
        final hasMatch = selectedCategoryIds.contains(tagId) ||
            (t.tag != null && selectedCategoryIds.contains(t.tag!.toUpperCase())) ||
            (t.tag == null && selectedCategoryIds.contains('OTHER'));
        if (!hasMatch) return false;
      }

      // 4. Date Range Filter
      final now = DateTime.now();
      switch (dateFilter) {
        case LogsDateFilter.allTime:
          break;
        case LogsDateFilter.today:
          final start = DateTime(now.year, now.month, now.day);
          final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
          if (t.timestamp.isBefore(start) || t.timestamp.isAfter(end)) return false;
          break;
        case LogsDateFilter.thisWeek:
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
          final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
          if (t.timestamp.isBefore(start) || t.timestamp.isAfter(end)) return false;
          break;
        case LogsDateFilter.thisMonth:
          final start = DateTime(now.year, now.month, 1);
          final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
          if (t.timestamp.isBefore(start) || t.timestamp.isAfter(end)) return false;
          break;
        case LogsDateFilter.thisYear:
          final start = DateTime(now.year, 1, 1);
          final end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
          if (t.timestamp.isBefore(start) || t.timestamp.isAfter(end)) return false;
          break;
        case LogsDateFilter.customRange:
          if (customStartDate != null && customEndDate != null) {
            final start = DateTime(customStartDate!.year, customStartDate!.month, customStartDate!.day);
            final end = DateTime(customEndDate!.year, customEndDate!.month, customEndDate!.day, 23, 59, 59, 999);
            if (t.timestamp.isBefore(start) || t.timestamp.isAfter(end)) return false;
          }
          break;
      }

      // 5. Amount Range
      if (minAmount != null && t.amount < minAmount!) return false;
      if (maxAmount != null && t.amount > maxAmount!) return false;

      return true;
    }).toList();

    // 6. Sorting Order
    switch (sortOrder) {
      case LogsSortOrder.newestFirst:
        filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case LogsSortOrder.oldestFirst:
        filtered.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        break;
      case LogsSortOrder.highestAmount:
        filtered.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case LogsSortOrder.lowestAmount:
        filtered.sort((a, b) => a.amount.compareTo(b.amount));
        break;
    }

    return filtered;
  }
}

/// Uber-grade bottom sheet allowing full customization of transaction logs filters & sorting.
class LogsFilterSheet extends StatefulWidget {
  final LogsFilterOptions initialOptions;
  final List<CategoryTag> categories;
  final List<Transaction> allTransactions;
  final String currentSearchQuery;
  final ValueChanged<LogsFilterOptions> onApply;

  const LogsFilterSheet({
    super.key,
    required this.initialOptions,
    required this.categories,
    required this.allTransactions,
    required this.currentSearchQuery,
    required this.onApply,
  });

  /// Presents the bottom sheet with standard Uber-grade elevation and rounded geometry.
  static Future<void> show(
    BuildContext context, {
    required LogsFilterOptions initialOptions,
    required List<CategoryTag> categories,
    required List<Transaction> allTransactions,
    required String currentSearchQuery,
    required ValueChanged<LogsFilterOptions> onApply,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LogsFilterSheet(
        initialOptions: initialOptions,
        categories: categories,
        allTransactions: allTransactions,
        currentSearchQuery: currentSearchQuery,
        onApply: onApply,
      ),
    );
  }

  @override
  State<LogsFilterSheet> createState() => _LogsFilterSheetState();
}

class _LogsFilterSheetState extends State<LogsFilterSheet> {
  late TransactionTypeFilter _typeFilter;
  late Set<String> _selectedCategoryIds;
  late LogsDateFilter _dateFilter;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  late LogsSortOrder _sortOrder;
  late TextEditingController _minAmountController;
  late TextEditingController _maxAmountController;

  @override
  void initState() {
    super.initState();
    _typeFilter = widget.initialOptions.typeFilter;
    _selectedCategoryIds = Set<String>.from(widget.initialOptions.selectedCategoryIds);
    _dateFilter = widget.initialOptions.dateFilter;
    _customStartDate = widget.initialOptions.customStartDate ?? DateTime.now().subtract(const Duration(days: 30));
    _customEndDate = widget.initialOptions.customEndDate ?? DateTime.now();
    _sortOrder = widget.initialOptions.sortOrder;

    _minAmountController = TextEditingController(
      text: widget.initialOptions.minAmount != null ? widget.initialOptions.minAmount!.toStringAsFixed(0) : '',
    );
    _maxAmountController = TextEditingController(
      text: widget.initialOptions.maxAmount != null ? widget.initialOptions.maxAmount!.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  LogsFilterOptions _buildCurrentOptions() {
    final minVal = double.tryParse(_minAmountController.text.trim());
    final maxVal = double.tryParse(_maxAmountController.text.trim());

    return LogsFilterOptions(
      typeFilter: _typeFilter,
      selectedCategoryIds: _selectedCategoryIds,
      dateFilter: _dateFilter,
      customStartDate: _dateFilter == LogsDateFilter.customRange ? _customStartDate : null,
      customEndDate: _dateFilter == LogsDateFilter.customRange ? _customEndDate : null,
      sortOrder: _sortOrder,
      minAmount: (minVal != null && minVal > 0) ? minVal : null,
      maxAmount: (maxVal != null && maxVal > 0) ? maxVal : null,
    );
  }

  void _resetAll() {
    HapticFeedback.mediumImpact();
    setState(() {
      _typeFilter = TransactionTypeFilter.all;
      _selectedCategoryIds.clear();
      _dateFilter = LogsDateFilter.allTime;
      _customStartDate = DateTime.now().subtract(const Duration(days: 30));
      _customEndDate = DateTime.now();
      _sortOrder = LogsSortOrder.newestFirst;
      _minAmountController.clear();
      _maxAmountController.clear();
    });
  }

  Future<void> _pickDateRange() async {
    HapticFeedback.selectionClick();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: _customStartDate ?? DateTime.now().subtract(const Duration(days: 30)),
        end: _customEndDate ?? DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  surface: AppColors.surfaceCard(context),
                ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateFilter = LogsDateFilter.customRange;
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final cardColor = AppColors.surfaceCard(context);
    final borderColor = AppColors.cardBorder(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    final currentOptions = _buildCurrentOptions();
    final previewResults = currentOptions.apply(
      transactions: widget.allTransactions,
      searchQuery: widget.currentSearchQuery,
    );

    final isDefault = currentOptions.isDefault;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.modalTop)),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.tune_rounded, color: primaryColor, size: 20),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Filter Logs',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (!isDefault)
                  TextButton.icon(
                    onPressed: _resetAll,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reset All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.debitRed,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: textSecondary, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Divider(color: borderColor, height: 16),

          // Scrollable Filter Sections
          Flexible(
            child: ListView(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              children: [
                // SECTION 1: Transaction Flow (Type)
                _buildSectionHeader(title: 'Transaction Type', icon: Icons.swap_horiz_rounded),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: _buildTypeSegment(
                        label: 'All',
                        icon: Icons.layers_rounded,
                        isSelected: _typeFilter == TransactionTypeFilter.all,
                        selectedColor: primaryColor,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _typeFilter = TransactionTypeFilter.all);
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _buildTypeSegment(
                        label: 'Income',
                        icon: Icons.arrow_downward_rounded,
                        isSelected: _typeFilter == TransactionTypeFilter.inOnly,
                        selectedColor: AppColors.creditGreen,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _typeFilter = TransactionTypeFilter.inOnly);
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _buildTypeSegment(
                        label: 'Expense',
                        icon: Icons.arrow_upward_rounded,
                        isSelected: _typeFilter == TransactionTypeFilter.outOnly,
                        selectedColor: AppColors.debitRed,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _typeFilter = TransactionTypeFilter.outOnly);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // SECTION 2: Date Period
                _buildSectionHeader(title: 'Time Period', icon: Icons.calendar_today_rounded),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: LogsDateFilter.values.map((filter) {
                    final isSelected = _dateFilter == filter;
                    return InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (filter == LogsDateFilter.customRange) {
                          _pickDateRange();
                        } else {
                          setState(() => _dateFilter = filter);
                        }
                      },
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? primaryColor.withValues(alpha: 0.15) : AppColors.scaffoldBackground(context),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: isSelected ? primaryColor : borderColor,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              Icon(Icons.check_rounded, size: 14, color: primaryColor),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              filter.label,
                              style: TextStyle(
                                color: isSelected ? primaryColor : textPrimary,
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.lg),

                // SECTION 3: Category Filter
                _buildSectionHeader(
                  title: 'Categories',
                  icon: Icons.category_rounded,
                  trailing: _selectedCategoryIds.isNotEmpty
                      ? InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedCategoryIds.clear());
                          },
                          child: Text(
                            'Clear (${_selectedCategoryIds.length})',
                            style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // "All Categories" chip
                    _buildCategoryChip(
                      label: 'All Categories',
                      emoji: '✨',
                      color: primaryColor,
                      isSelected: _selectedCategoryIds.isEmpty,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedCategoryIds.clear());
                      },
                    ),
                    // Specific Categories
                    ...widget.categories.map((cat) {
                      final isSelected = _selectedCategoryIds.contains(cat.id) || _selectedCategoryIds.contains(cat.name);
                      return _buildCategoryChip(
                        label: cat.name,
                        emoji: cat.emoji,
                        color: cat.color,
                        isSelected: isSelected,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (isSelected) {
                              _selectedCategoryIds.remove(cat.id);
                              _selectedCategoryIds.remove(cat.name);
                            } else {
                              _selectedCategoryIds.add(cat.id);
                            }
                          });
                        },
                      );
                    }),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // SECTION 4: Sorting Order
                _buildSectionHeader(title: 'Sort Order', icon: Icons.sort_rounded),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: LogsSortOrder.values.map((sort) {
                    final isSelected = _sortOrder == sort;
                    return InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _sortOrder = sort);
                      },
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? primaryColor.withValues(alpha: 0.15) : AppColors.scaffoldBackground(context),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: isSelected ? primaryColor : borderColor,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              Icon(Icons.check_rounded, size: 14, color: primaryColor),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              sort.label,
                              style: TextStyle(
                                color: isSelected ? primaryColor : textPrimary,
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.lg),

                // SECTION 5: Amount Range Filter
                _buildSectionHeader(title: 'Amount Range (₹)', icon: Icons.currency_rupee_rounded),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minAmountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                        decoration: const InputDecoration(
                          hintText: 'Min (e.g. 100)',
                          prefixText: '₹ ',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text('to', style: TextStyle(color: textSecondary, fontSize: 13)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextField(
                        controller: _maxAmountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                        decoration: const InputDecoration(
                          hintText: 'Max (e.g. 5000)',
                          prefixText: '₹ ',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),

          // Bottom Action Apply Button
          Container(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              MediaQuery.of(context).padding.bottom + AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: cardColor,
              border: Border(top: BorderSide(color: borderColor, width: 1.0)),
            ),
            child: NummoButton(
              text: 'Apply Filters (${previewResults.length} ${previewResults.length == 1 ? 'log' : 'logs'})',
              icon: Icons.check_circle_outline_rounded,
              onPressed: () {
                HapticFeedback.mediumImpact();
                widget.onApply(currentOptions);
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required IconData icon, Widget? trailing}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          trailing,
        ],
      ],
    );
  }

  Widget _buildTypeSegment({
    required String label,
    IconData? icon,
    required bool isSelected,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor.withValues(alpha: 0.15) : AppColors.scaffoldBackground(context),
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(
            color: isSelected ? selectedColor : AppColors.cardBorder(context),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: isSelected ? selectedColor : AppColors.textSecondary(context),
              ),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? selectedColor : AppColors.textPrimary(context),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required String emoji,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppColors.scaffoldBackground(context),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSelected ? color : AppColors.cardBorder(context),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : AppColors.textPrimary(context),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
