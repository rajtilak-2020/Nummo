import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  final Future<void> Function(Transaction txn) onAddTransaction;
  final Future<void> Function(Transaction txn) onUpdateTransaction;
  final Future<void> Function(String id) onDeleteTransaction;
  final Future<void> Function(List<Budget> budgets)? onUpdateBudgets;

  const HomeSwipeView({
    super.key,
    this.subTabIndex = 0,
    required this.transactions,
    required this.categories,
    required this.budgets,
    required this.onAddTransaction,
    required this.onUpdateTransaction,
    required this.onDeleteTransaction,
    this.onUpdateBudgets,
  });

  @override
  State<HomeSwipeView> createState() => _HomeSwipeViewState();
}

class _HomeSwipeViewState extends State<HomeSwipeView> {
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  double _dragDx = 0.0;
  bool _isSwitchingPage = false;

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
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
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
            children: [
              SvgPicture.asset(
                'logo/nummo.svg',
                width: 28,
                height: 28,
                semanticsLabel: 'Nummo Logo',
                placeholderBuilder: (ctx) => Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text('N', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Text('Nummo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
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
                    child: GestureDetector(
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
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
      children: [
        // Total Balance Card
        NummoCard(
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
        const SizedBox(height: AppSpacing.md),

        // Multi-Budget Progress Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Active Budgets', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (widget.budgets.isEmpty)
          NummoCard(
            child: Text('No active budgets configured', style: TextStyle(color: AppColors.textSecondary(context))),
          )
        else
          ...widget.budgets.map((budget) {
            final spent = budget.calculateSpent(widget.transactions);
            final double limit = budget.amount;
            final double ratio = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
            final bool isExceeded = spent > limit;
            final double excess = isExceeded ? (spent - limit) : 0.0;
            final double remaining = !isExceeded ? (limit - spent) : 0.0;
            final int percentage = limit > 0 ? ((spent / limit) * 100).round() : 0;

            final catTag = budget.scope == 'overall'
                ? null
                : CategoryTag.fromIdOrName(budget.scope);

            final range = budget.getCurrentCycleRange();
            final cycleStartStr = DateFormat('dd MMM').format(range.start);
            final cycleEndStr = DateFormat('dd MMM').format(range.end);

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: NummoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row: Title & Status Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                budget.title,
                                style: TextStyle(
                                  color: AppColors.textPrimary(context),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              // Clean Sub-line Metadata (Scope & Date Range)
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: catTag != null
                                          ? catTag.color.withValues(alpha: 0.12)
                                          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      catTag != null ? catTag.name : 'Overall',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: catTag != null ? catTag.color : Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '•',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary(context).withValues(alpha: 0.5),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$cycleStartStr – $cycleEndStr',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Sleek Professional Status Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isExceeded
                                ? AppColors.debitRed.withValues(alpha: 0.1)
                                : AppColors.creditGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isExceeded
                                  ? AppColors.debitRed.withValues(alpha: 0.25)
                                  : AppColors.creditGreen.withValues(alpha: 0.25),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            isExceeded
                                ? '+${MoneyFormatter.format(excess)} over'
                                : '${MoneyFormatter.format(remaining)} left',
                            style: TextStyle(
                              color: isExceeded ? AppColors.debitRed : AppColors.creditGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        backgroundColor: AppColors.cardBorder(context),
                        color: isExceeded ? AppColors.debitRed : Theme.of(context).colorScheme.primary,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Financial Metrics Breakdown Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: AppColors.textSecondary(context),
                            ),
                            children: [
                              TextSpan(
                                text: MoneyFormatter.format(spent),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isExceeded ? AppColors.debitRed : AppColors.textPrimary(context),
                                ),
                              ),
                              TextSpan(
                                text: ' of ',
                                style: TextStyle(color: AppColors.textSecondary(context)),
                              ),
                              TextSpan(
                                text: MoneyFormatter.format(limit),
                                style: TextStyle(
                                  color: AppColors.textSecondary(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          isExceeded ? '$percentage% (Exceeded)' : '$percentage%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: isExceeded ? AppColors.debitRed : AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: AppSpacing.md),

        // Category Spend Breakdown (Single Card with Left Donut Chart & Right Legend List)
        HomeCategoryBreakdownCard(
          categorySpendMap: categorySpendMap,
          totalExpense: expense,
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
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
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
          child: filtered.isEmpty
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
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.lg),
                    itemCount: grouped.keys.length,
                    itemBuilder: (context, index) {
                      final dateKey = grouped.keys.elementAt(index);
                      final items = grouped[dateKey]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                            child: Text(
                              dateKey,
                              style: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ...items.map((txn) => Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: TransactionTile(
                                  transaction: txn,
                                  onEdit: () => _openAddSheet(txn),
                                  onDelete: () => _confirmDelete(txn),
                                  onParentDragUpdate: (details) => _onParentDragUpdate(details, tabController),
                                  onParentDragEnd: _onParentDragEnd,
                                ),
                              )),
                        ],
                      );
                    },
                  ),
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

  const HomeCategoryBreakdownCard({
    super.key,
    required this.categorySpendMap,
    required this.totalExpense,
  });

  @override
  State<HomeCategoryBreakdownCard> createState() => _HomeCategoryBreakdownCardState();
}

class _HomeCategoryBreakdownCardState extends State<HomeCategoryBreakdownCard> {
  String? _selectedCategoryKey;
  String? _pinnedCategoryKey;
  bool _isPinned = false;
  Timer? _holdTimer;
  String? _holdingCategoryKey;
  DateTime? _touchStartTime;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _startHold(String categoryKey) {
    if (_holdingCategoryKey == categoryKey && _holdTimer != null && _holdTimer!.isActive) {
      return;
    }
    _holdTimer?.cancel();
    _holdingCategoryKey = categoryKey;
    _touchStartTime = DateTime.now();
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCategoryKey = categoryKey;
    });

    _holdTimer = Timer(const Duration(milliseconds: 1000), () {
      if (_holdingCategoryKey == categoryKey && mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _isPinned = true;
          _pinnedCategoryKey = categoryKey;
          _selectedCategoryKey = categoryKey;
        });
      }
    });
  }

  void _endHold([String? categoryKey]) {
    _holdTimer?.cancel();
    _holdTimer = null;
    final targetKey = categoryKey ?? _holdingCategoryKey;
    final touchStart = _touchStartTime;
    _holdingCategoryKey = null;
    _touchStartTime = null;

    if (mounted) {
      bool heldLongEnough = false;
      if (touchStart != null) {
        final elapsed = DateTime.now().difference(touchStart).inMilliseconds;
        if (elapsed >= 1000 && targetKey != null) {
          heldLongEnough = true;
          _isPinned = true;
          _pinnedCategoryKey = targetKey;
        }
      }

      setState(() {
        if (_isPinned && _pinnedCategoryKey != null) {
          _selectedCategoryKey = _pinnedCategoryKey;
        } else if (!heldLongEnough) {
          _selectedCategoryKey = null;
        }
      });
    }
  }

  void _resetSelection() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdingCategoryKey = null;
    _pinnedCategoryKey = null;
    _touchStartTime = null;
    HapticFeedback.selectionClick();
    setState(() {
      _isPinned = false;
      _selectedCategoryKey = null;
    });
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

    final selectedTag = selectedEntry != null ? CategoryTag.fromIdOrName(selectedEntry.key) : null;
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
                child: Listener(
                  onPointerUp: (_) => _endHold(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 110,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(
                              PieChartData(
                                pieTouchData: PieTouchData(
                                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                    if (pieTouchResponse != null && pieTouchResponse.touchedSection != null) {
                                      final idx = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                      if (idx >= 0 && idx < entries.length) {
                                        final touchedKey = entries[idx].key;
                                        if (event is FlTapDownEvent || event is FlPanDownEvent || event is FlPanStartEvent || event is FlLongPressStart || event is FlPointerEnterEvent) {
                                          _startHold(touchedKey);
                                        } else if (event is FlPanUpdateEvent || event is FlLongPressMoveUpdate) {
                                          if (_holdingCategoryKey != null && _holdingCategoryKey != touchedKey) {
                                            _startHold(touchedKey);
                                          }
                                        }
                                      }
                                    }
                                    if (event is FlTapUpEvent || event is FlPointerExitEvent) {
                                      _endHold();
                                    }
                                  },
                                ),
                                borderData: FlBorderData(show: false),
                                sectionsSpace: 3,
                                centerSpaceRadius: 28,
                                sections: List.generate(entries.length, (i) {
                                  final entry = entries[i];
                                  final catTag = CategoryTag.fromIdOrName(entry.key);
                                  final isSelected = _selectedCategoryKey == entry.key;
                                  final isAnySelected = _selectedCategoryKey != null;

                                  final color = (isAnySelected && !isSelected)
                                      ? catTag.color.withValues(alpha: 0.2)
                                      : catTag.color;

                                  return PieChartSectionData(
                                    color: color,
                                    value: entry.value,
                                    radius: isSelected ? 24.0 : 18.0,
                                    showTitle: false,
                                  );
                                }),
                              ),
                            ),
                            // Donut Center Emoji / Icon
                            if (selectedTag != null)
                              Text(selectedTag.emoji, style: const TextStyle(fontSize: 22))
                            else
                              Icon(
                                Icons.pie_chart_outline_rounded,
                                size: 22,
                                color: AppColors.textSecondary(context).withValues(alpha: 0.35),
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
              ),

              const SizedBox(width: AppSpacing.sm),

              // Right Part: Category Legend & Details List
              Expanded(
                flex: 6,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final catTag = CategoryTag.fromIdOrName(entry.key);
                      final isSelected = _selectedCategoryKey == entry.key;
                      final isAnySelected = _selectedCategoryKey != null;
                      final ratio = widget.totalExpense > 0 ? (entry.value / widget.totalExpense) : 0.0;

                      final opacity = (isAnySelected && !isSelected) ? 0.35 : 1.0;

                      return AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: opacity,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Listener(
                            onPointerDown: (_) => _startHold(entry.key),
                            onPointerUp: (_) => _endHold(entry.key),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
                                      color: AppColors.textSecondary(context),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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
