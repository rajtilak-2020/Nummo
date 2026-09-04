import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../models/budget.dart';
import '../../models/category.dart';
import '../../core/utils/money_formatter.dart';
import '../../design_system/tokens.dart';
import '../../design_system/components/animations.dart';
import '../../design_system/components/nummo_card.dart';
import '../export/export_dialog.dart';

enum AnalyticsPeriodFilter {
  today,
  particularDay,
  thisWeek,
  thisMonth,
  thisYear,
  allTime,
  customRange,
}

/// Dynamic, interactive analytics dashboard featuring auto-adapting Spend Trend charts,
/// comprehensive date filters, KPI summary cards, Credit to Spend Ratio statistics,
/// and category breakdowns with slice highlighting.
class AnalyticsScreen extends StatefulWidget {
  final List<Transaction> transactions;
  final Budget budget;
  final List<CategoryTag>? categories;
  final AnalyticsPeriodFilter selectedFilter;
  final DateTime particularDay;
  final DateTime customStartDate;
  final DateTime customEndDate;

  AnalyticsScreen({
    super.key,
    required this.transactions,
    required this.budget,
    this.categories,
    this.selectedFilter = AnalyticsPeriodFilter.thisMonth,
    DateTime? particularDay,
    DateTime? customStartDate,
    DateTime? customEndDate,
  })  : particularDay = particularDay ?? DateTime.now(),
        customStartDate = customStartDate ?? DateTime.now().subtract(const Duration(days: 30)),
        customEndDate = customEndDate ?? DateTime.now();

  static String getFilterLabel({
    required AnalyticsPeriodFilter filter,
    required DateTime particularDay,
    required DateTime customStartDate,
    required DateTime customEndDate,
  }) {
    switch (filter) {
      case AnalyticsPeriodFilter.today:
        return 'Today (${DateFormat('dd MMM').format(DateTime.now())})';
      case AnalyticsPeriodFilter.particularDay:
        return DateFormat('EEE, dd MMM yyyy').format(particularDay);
      case AnalyticsPeriodFilter.thisWeek:
        return 'This Week';
      case AnalyticsPeriodFilter.thisMonth:
        return 'This Month (${DateFormat('MMM yyyy').format(DateTime.now())})';
      case AnalyticsPeriodFilter.thisYear:
        return 'This Year (${DateTime.now().year})';
      case AnalyticsPeriodFilter.allTime:
        return 'All Time';
      case AnalyticsPeriodFilter.customRange:
        return '${DateFormat('dd MMM').format(customStartDate)} - ${DateFormat('dd MMM').format(customEndDate)}';
    }
  }

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String? _selectedCategoryKey;

  void _toggleCategoryHold(String categoryKey) {
    HapticFeedback.heavyImpact();
    setState(() {
      if (_selectedCategoryKey == categoryKey) {
        _selectedCategoryKey = null;
      } else {
        _selectedCategoryKey = categoryKey;
      }
    });
  }

  void _resetSelection() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCategoryKey = null;
    });
  }

  ({DateTime start, DateTime end}) _calculateFilterRange() {
    final now = DateTime.now();
    switch (widget.selectedFilter) {
      case AnalyticsPeriodFilter.today:
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return (start: start, end: end);

      case AnalyticsPeriodFilter.particularDay:
        final pDay = widget.particularDay;
        final start = DateTime(pDay.year, pDay.month, pDay.day);
        final end = DateTime(pDay.year, pDay.month, pDay.day, 23, 59, 59);
        return (start: start, end: end);

      case AnalyticsPeriodFilter.thisWeek:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return (start: start, end: end);

      case AnalyticsPeriodFilter.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return (start: start, end: end);

      case AnalyticsPeriodFilter.thisYear:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, 12, 31, 23, 59, 59);
        return (start: start, end: end);

      case AnalyticsPeriodFilter.allTime:
        final start = DateTime(2000, 1, 1);
        final end = DateTime(2100, 1, 1);
        return (start: start, end: end);

      case AnalyticsPeriodFilter.customRange:
        final cStart = widget.customStartDate;
        final cEnd = widget.customEndDate;
        final start = DateTime(cStart.year, cStart.month, cStart.day);
        final end = DateTime(cEnd.year, cEnd.month, cEnd.day, 23, 59, 59);
        return (start: start, end: end);
    }
  }

  /// Detailed Credit to Spend Ratio Statistics Card
  Widget _buildCreditToSpendRatioCard(BuildContext context, double income, double expense, double netSavings) {
    final ratio = expense > 0 ? (income / expense) : (income > 0 ? 99.0 : 0.0);
    final expenseRatioPct = income > 0 ? ((expense / income) * 100).clamp(0.0, 999.0) : (expense > 0 ? 100.0 : 0.0);
    final retentionRatePct = income > 0 ? ((netSavings / income) * 100).clamp(-999.0, 100.0) : 0.0;

    final isHealthy = netSavings > 0 && retentionRatePct >= 20.0;
    final isModerate = netSavings >= 0 && retentionRatePct < 20.0;

    final statusColor = isHealthy ? AppColors.creditGreen : (isModerate ? const Color(0xFFF59E0B) : AppColors.debitRed);
    final statusLabel = isHealthy ? 'Healthy Cashflow' : (isModerate ? 'Moderate Flow' : 'Deficit Warning');

    final totalFlow = income + expense;
    final incomeRatio = totalFlow > 0 ? (income / totalFlow).clamp(0.0, 1.0) : 0.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Credit to Spend Ratio',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                statusLabel,
                maxLines: 1,
                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        NummoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Credit Coverage Multiplier',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            expense > 0 ? '${ratio.toStringAsFixed(2)}x' : (income > 0 ? '∞ (No Spend)' : '0.00x'),
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Expense Ratio',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${expenseRatioPct.toStringAsFixed(1)}%',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: expenseRatioPct <= 80 ? AppColors.creditGreen : AppColors.debitRed,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Segmented Income vs Expense Proportional Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: [
                      Expanded(
                        flex: (incomeRatio * 100).toInt().clamp(1, 99),
                        child: Container(color: AppColors.creditGreen),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        flex: ((1 - incomeRatio) * 100).toInt().clamp(1, 99),
                        child: Container(color: AppColors.debitRed),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.creditGreen, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text('Credit In: ${MoneyFormatter.format(income)}', maxLines: 1, softWrap: false, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.debitRed, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text('Debit Out: ${MoneyFormatter.format(expense)}', maxLines: 1, softWrap: false, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Divider(height: 1, color: AppColors.cardBorder(context)),
              const SizedBox(height: AppSpacing.sm),

              // Sub-metrics Row: Retention Rate & Retained Capital Pool
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Retention Rate', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          '${retentionRatePct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: retentionRatePct >= 0 ? AppColors.creditGreen : AppColors.debitRed,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 28, color: AppColors.cardBorder(context)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Retained Net Pool', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11)),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              MoneyFormatter.format(netSavings, showSign: true, isCredit: netSavings >= 0),
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                color: netSavings >= 0 ? AppColors.creditGreen : AppColors.debitRed,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
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
      ],
    );
  }

  /// Dynamic Spend Trend Graph that automatically adjusts resolution and data range
  /// to match the active filter and data availability.
  Widget _buildSpendTrendGraph(BuildContext context, List<Transaction> periodTxns, DateTime start, DateTime end) {
    final filter = widget.selectedFilter;

    // 1. ALL-TIME FILTER: Detect years for which actual transaction data is available
    if (filter == AnalyticsPeriodFilter.allTime) {
      final expenseTxns = widget.transactions.where((t) => !t.isCredit).toList();
      final Map<int, double> yearlyExpenses = {};

      for (final t in expenseTxns) {
        final yr = t.timestamp.year;
        yearlyExpenses[yr] = (yearlyExpenses[yr] ?? 0.0) + t.amount;
      }

      final years = yearlyExpenses.keys.toList()..sort();

      // If no data or single year with data -> Show monthly breakdown for that active year
      if (years.isEmpty || years.length == 1) {
        final targetYear = years.isNotEmpty ? years.first : DateTime.now().year;
        return _buildMonthlyTrendGraph(
          context,
          expenseTxns.where((t) => t.timestamp.year == targetYear).toList(),
          yearLabel: '$targetYear',
        );
      }

      // Multi-year data available -> Show year bars for available years only
      double peakYearSpend = 0.0;
      int? peakYear;
      for (final e in yearlyExpenses.entries) {
        if (e.value > peakYearSpend) {
          peakYearSpend = e.value;
          peakYear = e.key;
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Spend Trend',
                style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (peakYear != null && peakYearSpend > 0) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.debitRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.debitRed.withValues(alpha: 0.3)),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Peak: ${MoneyFormatter.format(peakYearSpend)} in $peakYear',
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(color: AppColors.debitRed, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          NummoCard(
            child: SizedBox(
              height: 200,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final chartWidth = math.max(constraints.maxWidth, years.length * 60.0);
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: SizedBox(
                      width: chartWidth,
                      height: 200,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                final yr = years[group.x.toInt()];
                                return BarTooltipItem(
                                  'Year $yr\n${MoneyFormatter.format(rod.toY)}',
                                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                );
                              },
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: const FlGridData(show: false),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 26,
                                getTitlesWidget: (val, meta) {
                                  final idx = val.toInt();
                                  if (idx >= 0 && idx < years.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        years[idx].toString(),
                                        style: TextStyle(
                                          color: AppColors.textSecondary(context),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox();
                                },
                              ),
                            ),
                          ),
                          barGroups: List.generate(years.length, (i) {
                            final yr = years[i];
                            final amount = yearlyExpenses[yr] ?? 0.0;
                            final isPeak = yr == peakYear;
                            return BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: amount,
                                  color: isPeak ? AppColors.debitRed : Theme.of(context).colorScheme.primary,
                                  width: 24,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      );
    }

    // 2. THIS YEAR FILTER
    if (filter == AnalyticsPeriodFilter.thisYear) {
      return _buildMonthlyTrendGraph(
        context,
        periodTxns.where((t) => !t.isCredit).toList(),
        yearLabel: '${DateTime.now().year}',
      );
    }

    // 3. TODAY / PARTICULAR DAY FILTER
    if (filter == AnalyticsPeriodFilter.today || filter == AnalyticsPeriodFilter.particularDay) {
      return _buildHourlyTrendGraph(context, periodTxns.where((t) => !t.isCredit).toList());
    }

    // 4. DAILY / WEEKLY / CUSTOM RANGE FILTER
    return _buildDailyTrendGraph(context, periodTxns.where((t) => !t.isCredit).toList(), start, end);
  }

  Widget _buildMonthlyTrendGraph(BuildContext context, List<Transaction> expenseTxns, {required String yearLabel}) {
    final Map<int, double> monthlyExpenses = {};
    double peakMonthSpend = 0.0;
    int? peakMonthIdx;

    for (final t in expenseTxns) {
      final mIdx = t.timestamp.month - 1;
      final sum = (monthlyExpenses[mIdx] ?? 0.0) + t.amount;
      monthlyExpenses[mIdx] = sum;
      if (sum > peakMonthSpend) {
        peakMonthSpend = sum;
        peakMonthIdx = mIdx;
      }
    }

    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Spend Trend',
              style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (peakMonthIdx != null && peakMonthSpend > 0) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.debitRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppColors.debitRed.withValues(alpha: 0.3)),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Peak: ${MoneyFormatter.format(peakMonthSpend)} in ${monthNames[peakMonthIdx]}',
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(color: AppColors.debitRed, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        NummoCard(
          child: SizedBox(
            height: 200,
            child: monthlyExpenses.isEmpty
                ? Center(child: Text('No timeline expense data available', style: TextStyle(color: AppColors.textSecondary(context))))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final chartWidth = math.max(constraints.maxWidth, 12 * 46.0);
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: SizedBox(
                          width: chartWidth,
                          height: 200,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              barTouchData: BarTouchData(
                                touchTooltipData: BarTouchTooltipData(
                                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                    return BarTooltipItem(
                                      '${monthNames[group.x.toInt()]}\n${MoneyFormatter.format(rod.toY)}',
                                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                    );
                                  },
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              gridData: const FlGridData(show: false),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 26,
                                    getTitlesWidget: (val, meta) {
                                      final idx = val.toInt();
                                      if (idx >= 0 && idx < 12) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Text(
                                            monthNames[idx],
                                            style: TextStyle(
                                              color: AppColors.textSecondary(context),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox();
                                    },
                                  ),
                                ),
                              ),
                              barGroups: List.generate(12, (i) {
                                final amount = monthlyExpenses[i] ?? 0.0;
                                final isPeak = amount > 0 && i == peakMonthIdx;
                                return BarChartGroupData(
                                  x: i,
                                  barRods: [
                                    BarChartRodData(
                                      toY: amount,
                                      color: isPeak ? AppColors.debitRed : Theme.of(context).colorScheme.primary,
                                      width: 14,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildHourlyTrendGraph(BuildContext context, List<Transaction> expenseTxns) {
    final Map<int, double> hourlyExpenses = {};
    for (final t in expenseTxns) {
      final slot = (t.timestamp.hour / 4).floor().clamp(0, 5);
      hourlyExpenses[slot] = (hourlyExpenses[slot] ?? 0.0) + t.amount;
    }

    const slotNames = ['00-04h', '04-08h', '08-12h', '12-16h', '16-20h', '20-24h'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Spend Trend',
              style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        NummoCard(
          child: SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final idx = group.x.toInt();
                      return BarTooltipItem(
                        'Time Slot: ${slotNames[idx]}\n${MoneyFormatter.format(rod.toY)}',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      );
                    },
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < slotNames.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              slotNames[idx],
                              style: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(6, (i) {
                  final amount = hourlyExpenses[i] ?? 0.0;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: amount,
                        color: Theme.of(context).colorScheme.primary,
                        width: 20,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyTrendGraph(BuildContext context, List<Transaction> expenseTxns, DateTime start, DateTime end) {
    int daysCount = end.difference(start).inDays + 1;
    if (daysCount <= 0) daysCount = 1;

    // Show all dates in current month or active filter range
    int displayDays;
    if (widget.selectedFilter == AnalyticsPeriodFilter.thisWeek) {
      displayDays = 7;
    } else if (widget.selectedFilter == AnalyticsPeriodFilter.thisMonth) {
      final daysInMonth = DateTime(start.year, start.month + 1, 0).day;
      displayDays = daysInMonth;
    } else {
      displayDays = daysCount.clamp(1, 31);
    }

    final Map<int, double> dailyExpenses = {};
    double peakDaySpend = 0.0;
    DateTime? peakDayDate;

    for (final t in expenseTxns) {
      final diff = t.timestamp.difference(start).inDays;
      if (diff >= 0 && diff < displayDays) {
        final curDayTotal = (dailyExpenses[diff] ?? 0.0) + t.amount;
        dailyExpenses[diff] = curDayTotal;
        if (curDayTotal > peakDaySpend) {
          peakDaySpend = curDayTotal;
          peakDayDate = t.timestamp;
        }
      }
    }

    final isWeekly = widget.selectedFilter == AnalyticsPeriodFilter.thisWeek;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Spend Trend',
              style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (peakDayDate != null && peakDaySpend > 0) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.debitRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppColors.debitRed.withValues(alpha: 0.3)),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Peak: ${MoneyFormatter.format(peakDaySpend)} on ${DateFormat('dd MMM').format(peakDayDate)}',
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(color: AppColors.debitRed, fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        NummoCard(
          child: SizedBox(
            height: 200,
            child: dailyExpenses.isEmpty
                ? Center(child: Text('No timeline expense data available', style: TextStyle(color: AppColors.textSecondary(context))))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final chartWidth = math.max(constraints.maxWidth, displayDays * 44.0);
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: SizedBox(
                          width: chartWidth,
                          height: 200,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              barTouchData: BarTouchData(
                                touchTooltipData: BarTouchTooltipData(
                                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                    final dayDate = start.add(Duration(days: group.x.toInt()));
                                    final label = DateFormat('EEE, dd MMM').format(dayDate);
                                    return BarTooltipItem(
                                      '$label\n${MoneyFormatter.format(rod.toY)}',
                                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                    );
                                  },
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              gridData: const FlGridData(show: false),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 26,
                                    getTitlesWidget: (val, meta) {
                                      final idx = val.toInt();
                                      if (idx >= 0 && idx < displayDays) {
                                        final date = start.add(Duration(days: idx));
                                        final label = isWeekly
                                            ? DateFormat('EEE').format(date)
                                            : DateFormat('dd MMM').format(date);
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Text(
                                            label,
                                            style: TextStyle(
                                              color: AppColors.textSecondary(context),
                                              fontSize: isWeekly ? 10 : 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox();
                                    },
                                  ),
                                ),
                              ),
                              barGroups: List.generate(
                                displayDays,
                                (i) {
                                  final amount = dailyExpenses[i] ?? 0.0;
                                  final isPeak = amount > 0 && amount == peakDaySpend;
                                  return BarChartGroupData(
                                    x: i,
                                    barRods: [
                                      BarChartRodData(
                                        toY: amount,
                                        color: isPeak ? AppColors.debitRed : Theme.of(context).colorScheme.primary,
                                        width: (160 / displayDays).clamp(6.0, 16.0),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ],
                                  );
                                },
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = _calculateFilterRange();

    // Filter transactions in selected period
    final periodTxns = widget.transactions.where((t) {
      final isAfter = t.timestamp.isAfter(range.start) || t.timestamp.isAtSameMomentAs(range.start);
      final isBefore = t.timestamp.isBefore(range.end) || t.timestamp.isAtSameMomentAs(range.end);
      return isAfter && isBefore;
    }).toList();

    double periodIncome = 0.0;
    double periodExpense = 0.0;
    int creditCount = 0;
    int debitCount = 0;
    final Map<String, double> categoryTotals = {};
    final Map<String, int> categoryCounts = {};

    int daysCount = range.end.difference(range.start).inDays + 1;
    if (daysCount <= 0) daysCount = 1;

    for (final t in periodTxns) {
      if (t.isCredit) {
        periodIncome += t.amount;
        creditCount++;
      } else {
        periodExpense += t.amount;
        debitCount++;
        final cat = t.tag ?? 'OTHER';
        categoryTotals[cat] = (categoryTotals[cat] ?? 0.0) + t.amount;
        categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
      }
    }

    final netSavings = periodIncome - periodExpense;
    final savingsRate = periodIncome > 0 ? ((netSavings / periodIncome) * 100).clamp(-999.0, 100.0) : 0.0;
    final dailyAvgExpense = daysCount > 0 ? (periodExpense / daysCount) : 0.0;

    final sortedCatEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Find selected category tag if active
    CategoryTag? selectedTag;
    double selectedTagAmount = periodExpense;
    if (_selectedCategoryKey != null) {
      selectedTag = CategoryTag.fromIdOrName(_selectedCategoryKey, widget.categories);
      selectedTagAmount = categoryTotals[_selectedCategoryKey] ?? 0.0;
    }

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: const Text(
                  'Analytics Dashboard',
                  maxLines: 1,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: NummoBouncy(
              scaleFactor: 0.94,
              onTap: () {
                HapticFeedback.mediumImpact();
                ExportDialog.show(
                  context,
                  transactions: widget.transactions,
                  budgetName: widget.budget.scope == 'overall'
                      ? widget.budget.title
                      : 'Nummo Personal Account',
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.output_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Export',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          MediaQuery.of(context).padding.bottom + AppSpacing.bottomNavClearance,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Date Badge Row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 13,
                  color: AppColors.textSecondary(context),
                ),
                const SizedBox(width: 6),
                Text(
                  AnalyticsScreen.getFilterLabel(
                    filter: widget.selectedFilter,
                    particularDay: widget.particularDay,
                    customStartDate: widget.customStartDate,
                    customEndDate: widget.customEndDate,
                  ),
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

                  // KPI Cards Row 1: Income vs Expense
                  Row(
                    children: [
                      Expanded(
                        child: NummoCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Total Income',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.creditGreenBg,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text('$creditCount in', maxLines: 1, style: const TextStyle(color: AppColors.creditGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: NummoCountUp(
                                  value: periodIncome,
                                  isCredit: true,
                                  style: const TextStyle(color: AppColors.creditGreen, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: NummoCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Total Expenses',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.debitRedBg,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text('$debitCount out', maxLines: 1, style: const TextStyle(color: AppColors.debitRed, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: NummoCountUp(
                                  value: periodExpense,
                                  isCredit: false,
                                  style: const TextStyle(color: AppColors.debitRed, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // KPI Cards Row 2: Net Cashflow & Daily Average
                  Row(
                    children: [
                      Expanded(
                        child: NummoCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Net Cashflow',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '${savingsRate >= 0 ? '+' : ''}${savingsRate.toStringAsFixed(0)}% saved',
                                        maxLines: 1,
                                        style: TextStyle(
                                          color: netSavings >= 0 ? AppColors.creditGreen : AppColors.debitRed,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: NummoCountUp(
                                  value: netSavings,
                                  showSign: true,
                                  isCredit: netSavings >= 0,
                                  style: TextStyle(
                                    color: netSavings >= 0 ? AppColors.creditGreen : AppColors.debitRed,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: NummoCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Daily Avg Expense',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${MoneyFormatter.format(dailyAvgExpense)} / day',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                    color: AppColors.textPrimary(context),
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // CREDIT TO SPEND RATIO CARD (BEFORE CATEGORY BREAKDOWN)
                  _buildCreditToSpendRatioCard(context, periodIncome, periodExpense, netSavings),
                  const SizedBox(height: AppSpacing.xl),
                  NummoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                'Category Breakdown & Metrics',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textPrimary(context),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
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

                        if (sortedCatEntries.isEmpty)
                          Container(
                            height: 140,
                            alignment: Alignment.center,
                            child: Text('No expenses recorded in this period', style: TextStyle(color: AppColors.textSecondary(context))),
                          )
                        else ...[
                          // Donut Chart Area (Visual Representation)
                          SizedBox(
                            height: 160,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                PieChart(
                                  PieChartData(
                                    pieTouchData: PieTouchData(
                                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                        if (pieTouchResponse != null && pieTouchResponse.touchedSection != null) {
                                          final idx = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                          if (idx >= 0 && idx < sortedCatEntries.length) {
                                            final touchedKey = sortedCatEntries[idx].key;
                                            if (event is FlLongPressStart || event is FlLongPressMoveUpdate) {
                                              _toggleCategoryHold(touchedKey);
                                            }
                                          }
                                        }
                                      },
                                    ),
                                    borderData: FlBorderData(show: false),
                                    sectionsSpace: sortedCatEntries.length <= 1
                                        ? 0.0
                                        : (sortedCatEntries.length > 6 ? 1.5 : 2.0),
                                    centerSpaceRadius: 44,
                                    sections: List.generate(sortedCatEntries.length, (i) {
                                      final entry = sortedCatEntries[i];
                                      final catTag = CategoryTag.fromIdOrName(entry.key, widget.categories);
                                      final isSelected = _selectedCategoryKey == entry.key;
                                      final isAnySelected = _selectedCategoryKey != null;

                                      final color = (isAnySelected && !isSelected)
                                          ? catTag.color.withValues(alpha: 0.22)
                                          : catTag.color;

                                      // Enforce 2.5% minimum visual floor so small amounts (e.g. ₹1) always render cleanly
                                      final double visualValue = periodExpense > 0
                                          ? math.max(entry.value, periodExpense * 0.025)
                                          : entry.value;

                                      return PieChartSectionData(
                                        color: color,
                                        value: visualValue,
                                        radius: isSelected ? 24.0 : 18.0,
                                        showTitle: false,
                                        borderSide: BorderSide(
                                          color: AppColors.surfaceCard(context),
                                          width: sortedCatEntries.length <= 1 ? 0.0 : 2.0,
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                                // Donut Center Hole Elevated Pod Container
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.surfaceCard(context),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.08,
                                        ),
                                        blurRadius: 10,
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
                                      ? Text(selectedTag.emoji, style: const TextStyle(fontSize: 26))
                                      : Icon(
                                          Icons.donut_large_rounded,
                                          size: 24,
                                          color: AppColors.textSecondary(context).withValues(alpha: 0.4),
                                        ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),

                          // Donut Amount & Category Details Display BELOW the Donut Chart
                          SizedBox(
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (selectedTag != null) ...[
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: selectedTag.color.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(AppRadius.pill),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(selectedTag.emoji, style: const TextStyle(fontSize: 13)),
                                            const SizedBox(width: 5),
                                            Text(
                                              selectedTag.name,
                                              style: TextStyle(
                                                color: selectedTag.color,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  Text(
                                    'TOTAL PERIOD EXPENSE',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.textSecondary(context),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: double.infinity,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.center,
                                    child: Text(
                                      MoneyFormatter.format(selectedTagAmount),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      softWrap: false,
                                      style: TextStyle(
                                        color: selectedTag != null ? selectedTag.color : AppColors.debitRed,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (selectedTag != null && periodExpense > 0)
                                  Text(
                                    '${((selectedTagAmount / periodExpense) * 100).toStringAsFixed(1)}% of total period spend',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.textSecondary(context),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
                                else
                                  Text(
                                    '${sortedCatEntries.length} category ${sortedCatEntries.length == 1 ? "breakdown" : "breakdowns"}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.textSecondary(context),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                            child: Divider(height: 1),
                          ),

                          // Detailed Category Metrics Rows Inside Single Card
                          ...sortedCatEntries.map((entry) {
                            final catTag = CategoryTag.fromIdOrName(entry.key, widget.categories);
                            final double percent = periodExpense > 0 ? (entry.value / periodExpense) : 0.0;
                            final int count = categoryCounts[entry.key] ?? 0;
                            final double avgPerTxn = count > 0 ? (entry.value / count) : 0.0;

                            final isSelected = _selectedCategoryKey == entry.key;
                            final isAnySelected = _selectedCategoryKey != null;
                            final opacity = (isAnySelected && !isSelected) ? 0.35 : 1.0;

                            return AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: opacity,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onLongPress: () => _toggleCategoryHold(entry.key),
                                    onTap: () {
                                      if (_selectedCategoryKey != null) {
                                        _resetSelection();
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(AppRadius.small),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? catTag.color.withValues(alpha: 0.12)
                                            : AppColors.scaffoldBackground(context).withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(AppRadius.small),
                                        border: Border.all(
                                          color: isSelected
                                              ? catTag.color.withValues(alpha: 0.6)
                                              : AppColors.cardBorder(context),
                                          width: isSelected ? 1.5 : 1.0,
                                        ),
                                      ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 32,
                                              height: 32,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: catTag.color.withValues(alpha: 0.15),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(catTag.emoji, style: const TextStyle(fontSize: 16)),
                                            ),
                                            const SizedBox(width: AppSpacing.sm),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                   Text(
                                                     catTag.name,
                                                     maxLines: 1,
                                                     overflow: TextOverflow.ellipsis,
                                                     style: TextStyle(
                                                       color: AppColors.textPrimary(context),
                                                       fontWeight: FontWeight.bold,
                                                       fontSize: 13,
                                                     ),
                                                   ),
                                                   Text(
                                                     '$count txns • Avg ${MoneyFormatter.format(avgPerTxn)}',
                                                     maxLines: 1,
                                                     overflow: TextOverflow.ellipsis,
                                                     style: TextStyle(color: AppColors.textSecondary(context), fontSize: 10),
                                                   ),
                                                 ],
                                               ),
                                             ),
                                              const SizedBox(width: AppSpacing.xs),
                                              ConstrainedBox(
                                                constraints: const BoxConstraints(maxWidth: 90),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      alignment: Alignment.centerRight,
                                                      child: Text(
                                                        MoneyFormatter.format(entry.value),
                                                        maxLines: 1,
                                                        softWrap: false,
                                                        style: const TextStyle(
                                                          color: AppColors.debitRed,
                                                          fontWeight: FontWeight.bold,
                                                          fontFamily: 'monospace',
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      '${(percent * 100).toStringAsFixed(1)}%',
                                                      maxLines: 1,
                                                      style: TextStyle(color: AppColors.textSecondary(context), fontSize: 10, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(AppRadius.pill),
                                          child: LinearProgressIndicator(
                                            value: percent,
                                            minHeight: 5,
                                            backgroundColor: AppColors.scaffoldBackground(context),
                                            valueColor: AlwaysStoppedAnimation<Color>(catTag.color),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
                  const SizedBox(height: AppSpacing.xl),

                  // SPEND TREND GRAPH PLACED AT VERY END
                  _buildSpendTrendGraph(context, periodTxns, range.start, range.end),
                ],
              ),
            ),
    );
  }
}
