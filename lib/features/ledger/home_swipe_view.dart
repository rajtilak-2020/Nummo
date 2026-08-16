import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../models/budget.dart';
import '../../core/utils/money_formatter.dart';
import '../../design_system/tokens.dart';
import '../../design_system/components/nummo_card.dart';
import '../../design_system/components/nummo_dialog.dart';
import 'transaction_tile.dart';
import 'add_transaction_sheet.dart';

/// Two-Page Home View featuring Dashboard and Logs controlled via NavigationBar.
class HomeSwipeView extends StatefulWidget {
  final int subTabIndex;
  final List<Transaction> transactions;
  final List<CategoryTag> categories;
  final List<Budget> budgets;
  final bool isPinEnabled;
  final VoidCallback? onLockApp;
  final Future<void> Function(Transaction txn) onAddTransaction;
  final Future<void> Function(Transaction txn) onUpdateTransaction;
  final Future<void> Function(String id) onDeleteTransaction;
  final Future<void> Function(List<Budget> budgets)? onUpdateBudgets;
  final Future<void> Function(List<CategoryTag> categories)? onUpdateCategories;
  final Future<void> Function(CategoryTag category)? onCreateCategory;

  const HomeSwipeView({
    super.key,
    this.subTabIndex = 0,
    required this.transactions,
    required this.categories,
    required this.budgets,
    this.isPinEnabled = false,
    this.onLockApp,
    required this.onAddTransaction,
    required this.onUpdateTransaction,
    required this.onDeleteTransaction,
    this.onUpdateBudgets,
    this.onUpdateCategories,
    this.onCreateCategory,
  });

  @override
  State<HomeSwipeView> createState() => _HomeSwipeViewState();
}

class _HomeSwipeViewState extends State<HomeSwipeView> {
  late FocusNode _searchFocusNode;
  String _searchQuery = '';
  double _dragDx = 0.0;
  bool _isSwitchingPage = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _unfocusSearch() {
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }
  }

  void _openAddSheet(Transaction existing) {
    _unfocusSearch();
    AddTransactionSheet.show(
      context,
      existingTransaction: existing,
      initialIsCredit: existing.isCredit,
      availableCategories: widget.categories,
      onCreateCategory: widget.onCreateCategory,
      onUpdateCategories: widget.onUpdateCategories,
      onSave: (txn) async {
        await widget.onUpdateTransaction(txn);
      },
    );
  }

  Future<void> _confirmDelete(Transaction txn) async {
    _unfocusSearch();
    final confirmed = await NummoDialog.showConfirmDialog(
      context: context,
      title: 'Delete Transaction',
      message: 'Are you sure you want to delete "${txn.note}" of ${MoneyFormatter.format(txn.amount)}?',
      confirmText: 'Delete',
      isDestructive: true,
    );
    if (confirmed) {
      await widget.onDeleteTransaction(txn.id);
    }
  }

  Widget _buildTopSegmentSwitcher(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      child: Container(
        height: 38,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard(context),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.cardBorder(context)),
        ),
        child: TabBar(
          onTap: (_) => _unfocusSearch(),
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            color: primaryColor,
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textSecondary(context),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Logs'),
          ],
        ),
      ),
    );
  }

  void _onParentDragUpdate(DragUpdateDetails details, TabController tabController) {
    _unfocusSearch();
    if (_isSwitchingPage) return;
    _dragDx += details.delta.dx;
    const threshold = 90.0; // 90px threshold to prevent accidental swipes
    if (_dragDx > threshold && tabController.index == 1) {
      _isSwitchingPage = true;
      tabController.animateTo(0);
      HapticFeedback.selectionClick();
    }
  }

  void _onParentDragEnd() {
    _dragDx = 0.0;
    _isSwitchingPage = false;
  }

  @override
  Widget build(BuildContext context) {
    // Totals calculation
    double totalIncome = 0.0;
    double totalExpense = 0.0;
    final Map<String, double> categorySpendMap = {};

    for (final t in widget.transactions) {
      if (t.isCredit) {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
        final catId = t.tag ?? 'OTHER';
        categorySpendMap[catId] = (categorySpendMap[catId] ?? 0.0) + t.amount;
      }
    }
    final netBalance = totalIncome - totalExpense;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          scrolledUnderElevation: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6.0),
                child: Image.asset(
                  'logo/nummo.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Text('Nummo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          actions: [
            IconButton(
              key: const Key('lock_app_button'),
              tooltip: widget.isPinEnabled ? 'Lock Nummo' : 'PIN Lock Disabled',
              icon: Icon(
                widget.isPinEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
                color: widget.isPinEnabled
                    ? Theme.of(context).colorScheme.primary
                    : AppColors.textSecondary(context).withValues(alpha: 0.5),
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                if (widget.isPinEnabled && widget.onLockApp != null) {
                  widget.onLockApp!();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Security PIN is disabled. Turn on PIN lock in Settings to lock Nummo.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ),
        body: Builder(
          builder: (builderContext) {
            final tabController = DefaultTabController.of(builderContext);
            return GestureDetector(
              onTap: _unfocusSearch,
              behavior: HitTestBehavior.translucent,
              child: Column(
                children: [
                  // Top Segment Switcher (Dashboard | Logs) below header
                  _buildTopSegmentSwitcher(builderContext),

                  // Swipeable PageView with 90px threshold guard
                  Expanded(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onHorizontalDragStart: (_) {
                            _unfocusSearch();
                            _dragDx = 0.0;
                            _isSwitchingPage = false;
                          },
                          onHorizontalDragUpdate: (details) {
                            _unfocusSearch();
                            if (_isSwitchingPage) return;
                            _dragDx += details.delta.dx;
                            const threshold = 90.0; // 90px threshold to prevent accidental swipes
                            if (_dragDx < -threshold && tabController.index == 0) {
                              _isSwitchingPage = true;
                              tabController.animateTo(1);
                              HapticFeedback.selectionClick();
                            } else if (_dragDx > threshold && tabController.index == 1) {
                              _isSwitchingPage = true;
                              tabController.animateTo(0);
                              HapticFeedback.selectionClick();
                            }
                          },
                          onHorizontalDragEnd: (_) {
                            _dragDx = 0.0;
                            _isSwitchingPage = false;
                          },
                          child: TabBarView(
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _buildDashboardPage(netBalance, totalIncome, totalExpense, categorySpendMap),
                              _buildLogsPage(tabController),
                            ],
                          ),
                        ),
                        // Top Gradient Blur Fade Overlay below segment switcher
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Container(
                              height: 18,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppColors.scaffoldBackground(context),
                                    AppColors.scaffoldBackground(context).withValues(alpha: 0.7),
                                    AppColors.scaffoldBackground(context).withValues(alpha: 0.0),
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // --- PAGE 1: DASHBOARD ---
  Widget _buildDashboardPage(double balance, double income, double expense, Map<String, double> categorySpendMap) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.bottomNavClearance),
      children: [
        // Total Balance Card
        RepaintBoundary(
          child: NummoCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Balance',
                  style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  MoneyFormatter.format(balance),
                  style: TextStyle(
                    color: balance >= 0 ? AppColors.creditGreen : AppColors.debitRed,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
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
                          Text(
                            MoneyFormatter.format(income),
                            style: const TextStyle(color: AppColors.creditGreen, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 32, color: AppColors.cardBorder(context)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Expenses (Out)', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              MoneyFormatter.format(expense),
                              style: const TextStyle(color: AppColors.debitRed, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
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
        const SizedBox(height: AppSpacing.lg),

        // Category Spend Breakdown (Single Card with Left Donut Chart & Right Legend List)
        RepaintBoundary(
          child: HomeCategoryBreakdownCard(
            categorySpendMap: categorySpendMap,
            totalExpense: expense,
            categories: widget.categories,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Multi-Budget Progress Section (Consolidated Single Card)
        RepaintBoundary(
          child: HomeActiveBudgetsCard(
            budgets: widget.budgets,
            transactions: widget.transactions,
            categories: widget.categories,
          ),
        ),
      ],
    );
  }

  // --- PAGE 2: LOGS ---
  Widget _buildLogsPage(TabController tabController) {
    // Sort transactions latest first
    final sortedTxns = List<Transaction>.from(widget.transactions)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Filter by search query
    final filtered = sortedTxns.where((t) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final matchesNote = t.note.toLowerCase().contains(q);
      final matchesAmount = t.amount.toString().contains(q);
      final matchesTag = (t.tag ?? '').toLowerCase().contains(q);
      return matchesNote || matchesAmount || matchesTag;
    }).toList();

    // Group by Date String
    final Map<String, List<Transaction>> grouped = {};
    for (final txn in filtered) {
      final dateStr = DateFormat('EEE, dd MMM yyyy').format(txn.timestamp);
      grouped.putIfAbsent(dateStr, () => []).add(txn);
    }

    return Column(
      children: [
        // Action Header Bar: Search input
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
          child: TextField(
            focusNode: _searchFocusNode,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'Search logs...',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
        ),

        // Grouped Logs List
        Expanded(
          child: Stack(
            children: [
              filtered.isEmpty
                  ? Center(
                      child: Text('No transaction logs found', style: TextStyle(color: AppColors.textSecondary(context))),
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (scrollInfo) {
                        if (scrollInfo is ScrollStartNotification || scrollInfo is UserScrollNotification) {
                          _unfocusSearch();
                        }
                        return false;
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.bottomNavClearance),
                        itemCount: grouped.keys.length,
                        itemBuilder: (context, index) {
                          final dateKey = grouped.keys.elementAt(index);
                          final items = grouped[dateKey]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(0, AppSpacing.sm, 0, AppSpacing.xs),
                                child: Text(
                                  dateKey,
                                  style: TextStyle(
                                    color: AppColors.textSecondary(context),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              ...items.map((txn) => RepaintBoundary(
                                    key: ValueKey(txn.id),
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                      child: TransactionTile(
                                        transaction: txn,
                                        categories: widget.categories,
                                        onEdit: () => _openAddSheet(txn),
                                        onDelete: () => _confirmDelete(txn),
                                        onParentDragUpdate: (details) => _onParentDragUpdate(details, tabController),
                                        onParentDragEnd: _onParentDragEnd,
                                      ),
                                    ),
                                  )),
                            ],
                          );
                        },
                      ),
                    ),
              // Top Gradient Blur Fade Overlay below search field
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 12,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.scaffoldBackground(context),
                        AppColors.scaffoldBackground(context).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Bottom Gradient Blur Fade Overlay above navbar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 24,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        AppColors.scaffoldBackground(context),
                        AppColors.scaffoldBackground(context).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Unified, interactive Category Breakdown Card featuring a Donut Chart on the Left
/// and a Category Legend List on the Right with bi-directional highlight/fade effects.
class HomeCategoryBreakdownCard extends StatefulWidget {
  final Map<String, double> categorySpendMap;
  final double totalExpense;
  final List<CategoryTag>? categories;

  const HomeCategoryBreakdownCard({
    super.key,
    required this.categorySpendMap,
    required this.totalExpense,
    this.categories,
  });

  @override
  State<HomeCategoryBreakdownCard> createState() => _HomeCategoryBreakdownCardState();
}

class _HomeCategoryBreakdownCardState extends State<HomeCategoryBreakdownCard> {
  String? _selectedCategoryKey;

  void _toggleCategoryHold(String key) {
    HapticFeedback.heavyImpact();
    setState(() {
      if (_selectedCategoryKey == key) {
        _selectedCategoryKey = null;
      } else {
        _selectedCategoryKey = key;
      }
    });
  }

  void _resetSelection() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCategoryKey = null;
    });
  }

  Widget _buildLegendItem(
    MapEntry<String, double> entry,
    List<MapEntry<String, double>> entries,
  ) {
    final catTag = CategoryTag.fromIdOrName(entry.key, widget.categories);
    final isSelected = _selectedCategoryKey == entry.key;
    final isAnySelected = _selectedCategoryKey != null;
    final ratio = widget.totalExpense > 0 ? (entry.value / widget.totalExpense) : 0.0;
    final opacity = (isAnySelected && !isSelected) ? 0.35 : 1.0;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onLongPress: () => _toggleCategoryHold(entry.key),
            onTap: () {
              if (_selectedCategoryKey != null) {
                _resetSelection();
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? catTag.color.withValues(alpha: 0.15)
                    : AppColors.scaffoldBackground(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? catTag.color.withValues(alpha: 0.5)
                      : AppColors.cardBorder(context),
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: catTag.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(catTag.emoji, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      catTag.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${(ratio * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: isSelected ? catTag.color : AppColors.textSecondary(context),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categorySpendMap.isEmpty) {
      return NummoCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            'No expense transactions recorded yet',
            style: TextStyle(color: AppColors.textSecondary(context)),
          ),
        ),
      );
    }

    final entries = widget.categorySpendMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    MapEntry<String, double>? selectedEntry;
    if (_selectedCategoryKey != null) {
      final idx = entries.indexWhere((e) => e.key == _selectedCategoryKey);
      if (idx != -1) selectedEntry = entries[idx];
    }

    final selectedTag = selectedEntry != null ? CategoryTag.fromIdOrName(selectedEntry.key, widget.categories) : null;
    final selectedAmount = selectedEntry?.value ?? widget.totalExpense;

    return NummoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Category Breakdown',
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_selectedCategoryKey != null)
                InkWell(
                  onTap: _resetSelection,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Main Row Layout: Left Donut Chart, Right Details List
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left Part: Interactive Donut Chart with Bottom Summary Text
              Expanded(
                flex: 5,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 110,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          RepaintBoundary(
                            child: PieChart(
                              PieChartData(
                                pieTouchData: PieTouchData(
                                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                    if (pieTouchResponse != null && pieTouchResponse.touchedSection != null) {
                                      final idx = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                      if (idx >= 0 && idx < entries.length) {
                                        final touchedKey = entries[idx].key;
                                        if (event is FlLongPressStart || event is FlLongPressMoveUpdate) {
                                          _toggleCategoryHold(touchedKey);
                                        }
                                      }
                                    }
                                  },
                                ),
                                borderData: FlBorderData(show: false),
                                sectionsSpace: entries.length <= 1
                                    ? 0.0
                                    : (entries.length > 6 ? 1.5 : 2.0),
                                centerSpaceRadius: 30,
                                sections: List.generate(entries.length, (i) {
                                  final entry = entries[i];
                                  final catTag = CategoryTag.fromIdOrName(entry.key, widget.categories);
                                  final isSelected = _selectedCategoryKey == entry.key;
                                  final isAnySelected = _selectedCategoryKey != null;

                                  final color = (isAnySelected && !isSelected)
                                      ? catTag.color.withValues(alpha: 0.22)
                                      : catTag.color;

                                  // Enforce 2.5% minimum visual floor so small amounts (e.g. ₹1) always render cleanly
                                  final double visualValue = widget.totalExpense > 0
                                      ? math.max(entry.value, widget.totalExpense * 0.025)
                                      : entry.value;

                                  return PieChartSectionData(
                                    color: color,
                                    value: visualValue,
                                    radius: isSelected ? 20.0 : 15.0,
                                    showTitle: false,
                                    borderSide: BorderSide(
                                      color: AppColors.surfaceCard(context),
                                      width: entries.length <= 1 ? 0.0 : 2.0,
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                          // Donut Center Hole Elevated Pod Container
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surfaceCard(context),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.08,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                              border: Border.all(
                                color: (selectedTag != null ? selectedTag.color : Theme.of(context).colorScheme.primary)
                                    .withValues(alpha: 0.25),
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: selectedTag != null
                                ? Text(selectedTag.emoji, style: const TextStyle(fontSize: 20))
                                : Icon(
                                    Icons.donut_large_rounded,
                                    size: 18,
                                    color: AppColors.textSecondary(context).withValues(alpha: 0.4),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Summary Text & Amount outside the Donut Chart (Bottom Side)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selectedTag != null ? selectedTag.name : 'Total Expense',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selectedTag != null ? selectedTag.color : AppColors.textSecondary(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 1),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            MoneyFormatter.format(selectedAmount),
                            style: TextStyle(
                              color: selectedTag != null ? selectedTag.color : AppColors.debitRed,
                              fontSize: 13,
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

              const SizedBox(width: AppSpacing.sm),

              // Right Part: Category Legend & Details List
              Expanded(
                flex: 6,
                child: entries.length <= 5
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: entries.map((entry) => _buildLegendItem(entry, entries)).toList(),
                      )
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 165),
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: entries.map((entry) => _buildLegendItem(entry, entries)).toList(),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Consolidated, premium single-card representation for active budgets on Home Dashboard.
class HomeActiveBudgetsCard extends StatelessWidget {
  final List<Budget> budgets;
  final List<Transaction> transactions;
  final List<CategoryTag> categories;

  const HomeActiveBudgetsCard({
    super.key,
    required this.budgets,
    required this.transactions,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    return NummoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header inside card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Active Budgets',
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (budgets.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${budgets.length} active',
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
          const SizedBox(height: AppSpacing.md),

          if (budgets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.track_changes_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No active budgets configured',
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Set spending limits in Settings to track your financial goals.',
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            // Budget Items List
            ...List.generate(budgets.length, (index) {
            final budget = budgets[index];
            final spent = budget.calculateSpent(transactions);
            final double limit = budget.amount;
            final double ratio = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
            final bool isExceeded = spent > limit;
            final double excess = isExceeded ? (spent - limit) : 0.0;
            final double remaining = !isExceeded ? (limit - spent) : 0.0;
            final int percentage = limit > 0 ? ((spent / limit) * 100).round() : 0;

            final isOverall = budget.scope == 'overall';
            final catTag = isOverall
                ? null
                : CategoryTag.fromIdOrName(budget.scope, categories);

            final primaryColor = Theme.of(context).colorScheme.primary;
            final accentColor = isOverall ? primaryColor : (catTag?.color ?? primaryColor);
            final emoji = isOverall ? '🎯' : (catTag?.emoji ?? '🎯');

            final range = budget.getCurrentCycleRange();
            final cycleStartStr = DateFormat('dd MMM').format(range.start);
            final cycleEndStr = DateFormat('dd MMM').format(range.end);

            final Color statusColor = isExceeded
                ? AppColors.debitRed
                : (ratio >= 0.85 ? const Color(0xFFF59E0B) : accentColor);

            return Column(
              children: [
                if (index > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(
                      height: 1,
                      thickness: 0.8,
                      color: AppColors.cardBorder(context).withValues(alpha: 0.5),
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 15)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  budget.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textPrimary(context),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                ),
                                child: Text(
                                  isOverall ? 'Overall' : (catTag?.name ?? 'Category'),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${budget.periodLabel.split(' ')[0]} • $cycleStartStr – $cycleEndStr',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textSecondary(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 3),
                      decoration: BoxDecoration(
                        color: isExceeded
                            ? AppColors.debitRed.withValues(alpha: 0.1)
                            : (ratio >= 0.85
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                                : AppColors.creditGreen.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: isExceeded
                              ? AppColors.debitRed.withValues(alpha: 0.25)
                              : (ratio >= 0.85
                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.25)
                                  : AppColors.creditGreen.withValues(alpha: 0.25)),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        isExceeded
                            ? '+${MoneyFormatter.format(excess)}'
                            : '${MoneyFormatter.format(remaining)} left',
                        style: TextStyle(
                          color: isExceeded
                              ? AppColors.debitRed
                              : (ratio >= 0.85 ? const Color(0xFFF59E0B) : AppColors.creditGreen),
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 5,
                    backgroundColor: AppColors.scaffoldBackground(context),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Spent ',
                          style: TextStyle(color: AppColors.textSecondary(context), fontSize: 10.5),
                        ),
                        Text(
                          MoneyFormatter.format(spent),
                          style: TextStyle(
                            color: isExceeded ? AppColors.debitRed : AppColors.textPrimary(context),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          ' of ',
                          style: TextStyle(color: AppColors.textSecondary(context), fontSize: 10.5),
                        ),
                        Text(
                          MoneyFormatter.format(limit),
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: isExceeded
                            ? AppColors.debitRed
                            : (ratio >= 0.85 ? const Color(0xFFF59E0B) : AppColors.textSecondary(context)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
