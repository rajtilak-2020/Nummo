import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../core/utils/money_formatter.dart';
import '../../design_system/tokens.dart';
import '../../design_system/components/nummo_card.dart';
import '../../design_system/components/nummo_button.dart';
import 'export_service.dart';

enum ExportPeriodFrequency {
  byMonth('By Month'),
  byYear('By Year'),
  custom('Custom Range');

  final String label;
  const ExportPeriodFrequency(this.label);
}

/// Dialog / Bottom Sheet allowing users to select frequency range (By Month, By Year, Custom Range),
/// inspect available financial logs with elegant grayed-out empty periods, and export PDF or Excel statements.
class ExportDialog extends StatefulWidget {
  final List<Transaction> transactions;
  final String budgetName;

  const ExportDialog({
    super.key,
    required this.transactions,
    required this.budgetName,
  });

  static Future<void> show(
    BuildContext context, {
    required List<Transaction> transactions,
    required String budgetName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExportDialog(
        transactions: transactions,
        budgetName: budgetName,
      ),
    );
  }

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  ExportPeriodFrequency _selectedFrequency = ExportPeriodFrequency.byMonth;
  late int _selectedYear;
  late int _selectedMonth;
  DateTime _customStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _customEndDate = DateTime.now();

  bool _isExportingPdf = false;
  bool _isExportingExcel = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;

    // If current month has no transactions, auto-select latest month with transactions
    if (_getTransactionCountForMonth(_selectedYear, _selectedMonth) == 0) {
      final availableMonths = _getAvailableMonthsWithData();
      if (availableMonths.isNotEmpty) {
        _selectedYear = availableMonths.first.year;
        _selectedMonth = availableMonths.first.month;
      }
    }
  }

  /// Returns unique years present in transactions (or current year if empty), sorted descending.
  List<int> _getAvailableYears() {
    final Set<int> years = {DateTime.now().year};
    for (final t in widget.transactions) {
      if (t.timestamp.year >= 2000 && t.timestamp.year <= 2100) {
        years.add(t.timestamp.year);
      }
    }
    final sorted = years.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  /// Returns number of transactions in a specific year.
  int _getTransactionCountForYear(int year) {
    return widget.transactions.where((t) => t.timestamp.year == year).length;
  }

  /// Returns number of transactions in a specific year and month.
  int _getTransactionCountForMonth(int year, int month) {
    return widget.transactions.where((t) {
      return t.timestamp.year == year && t.timestamp.month == month;
    }).length;
  }

  /// Helper returning all ({year, month}) pairs that have > 0 transactions, sorted descending.
  List<({int year, int month})> _getAvailableMonthsWithData() {
    final Set<String> keySet = {};
    final List<({int year, int month})> result = [];

    for (final t in widget.transactions) {
      final key = '${t.timestamp.year}-${t.timestamp.month}';
      if (!keySet.contains(key)) {
        keySet.add(key);
        result.add((year: t.timestamp.year, month: t.timestamp.month));
      }
    }

    result.sort((a, b) {
      if (a.year != b.year) return b.year.compareTo(a.year);
      return b.month.compareTo(a.month);
    });

    return result;
  }

  ({DateTime start, DateTime end, String title}) _getPeriodRange() {
    switch (_selectedFrequency) {
      case ExportPeriodFrequency.byMonth:
        final start = DateTime(_selectedYear, _selectedMonth, 1);
        final end = DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59, 999);
        return (start: start, end: end, title: DateFormat('MMMM yyyy').format(start));

      case ExportPeriodFrequency.byYear:
        final start = DateTime(_selectedYear, 1, 1);
        final end = DateTime(_selectedYear, 12, 31, 23, 59, 59, 999);
        return (start: start, end: end, title: 'Year $_selectedYear');

      case ExportPeriodFrequency.custom:
        final start = DateTime(_customStartDate.year, _customStartDate.month, _customStartDate.day);
        final end = DateTime(_customEndDate.year, _customEndDate.month, _customEndDate.day, 23, 59, 59, 999);
        return (
          start: start,
          end: end,
          title: '${DateFormat('dd MMM yyyy').format(start)} to ${DateFormat('dd MMM yyyy').format(end)}'
        );
    }
  }

  List<Transaction> _getFilteredTransactions(({DateTime start, DateTime end, String title}) range) {
    return widget.transactions.where((t) {
      return !t.timestamp.isBefore(range.start) && !t.timestamp.isAfter(range.end);
    }).toList();
  }

  Future<void> _pickCustomDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _customStartDate : _customEndDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _customStartDate = picked;
          if (_customStartDate.isAfter(_customEndDate)) {
            _customEndDate = _customStartDate;
          }
        } else {
          _customEndDate = picked;
          if (_customEndDate.isBefore(_customStartDate)) {
            _customStartDate = _customEndDate;
          }
        }
      });
    }
  }

  Future<void> _handleExport(bool isPdf, List<Transaction> txns, ({DateTime start, DateTime end, String title}) range) async {
    if (txns.isEmpty) return;

    setState(() {
      if (isPdf) {
        _isExportingPdf = true;
      } else {
        _isExportingExcel = true;
      }
    });

    try {
      final bool success;
      if (isPdf) {
        success = await ExportService.exportPdf(
          transactions: txns,
          periodTitle: range.title,
          startDate: range.start,
          endDate: range.end,
          budgetName: widget.budgetName,
        );
      } else {
        success = await ExportService.exportExcel(
          transactions: txns,
          periodTitle: range.title,
          startDate: range.start,
          endDate: range.end,
          budgetName: widget.budgetName,
        );
      }

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          NummoToast.show(
            context,
            message: '${isPdf ? "PDF Document" : "Excel Spreadsheet"} exported successfully!',
            type: ToastType.success,
          );
        } else {
          NummoToast.show(
            context,
            message: 'Export cancelled',
            type: ToastType.info,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        NummoToast.show(
          context,
          message: 'Failed to export: $e',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExportingPdf = false;
          _isExportingExcel = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = _getPeriodRange();
    final filteredTxns = _getFilteredTransactions(range);
    final bool hasData = filteredTxns.isNotEmpty;
    const warningAmber = Color(0xFFF59E0B);
    final primaryColor = Theme.of(context).colorScheme.primary;

    double totalIncome = 0.0;
    double totalExpense = 0.0;
    for (final t in filteredTxns) {
      if (t.isCredit) {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }
    }

    final availableYears = _getAvailableYears();
    final yearIdx = availableYears.indexOf(_selectedYear);
    final bool canGoBackInYears = yearIdx < availableYears.length - 1;
    final bool canGoForwardInYears = yearIdx > 0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        MediaQuery.of(context).padding.bottom + AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder(context),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Dialog Title Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Icon(
                    Icons.output_rounded,
                    color: primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Export Financial Statement',
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Export formatted PDF reports & Excel CSV logs',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: AppColors.textSecondary(context)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Segmented Tab Switcher (By Month, By Year, Custom Range)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.scaffoldBackground(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder(context), width: 1),
              ),
              child: Row(
                children: ExportPeriodFrequency.values.map((freq) {
                  final isSelected = _selectedFrequency == freq;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedFrequency = freq);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.28),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ]
                              : null,
                        ),
                        child: Text(
                          freq.label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textSecondary(context),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // --- 1. BY MONTH SECTION ---
            if (_selectedFrequency == ExportPeriodFrequency.byMonth) ...[
              // Year Navigation Header Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.scaffoldBackground(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder(context).withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, size: 18, color: primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Select Month',
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: canGoBackInYears
                                ? () {
                                    HapticFeedback.lightImpact();
                                    setState(() => _selectedYear = availableYears[yearIdx + 1]);
                                  }
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.chevron_left_rounded,
                                size: 22,
                                color: canGoBackInYears
                                    ? AppColors.textPrimary(context)
                                    : AppColors.textSecondary(context).withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$_selectedYear',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: canGoForwardInYears
                                ? () {
                                    HapticFeedback.lightImpact();
                                    setState(() => _selectedYear = availableYears[yearIdx - 1]);
                                  }
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                size: 22,
                                color: canGoForwardInYears
                                    ? AppColors.textPrimary(context)
                                    : AppColors.textSecondary(context).withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 12 Month Cards Grid (3 Columns x 4 Rows)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 12,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (ctx, index) {
                  final monthNum = index + 1; // 1..12
                  final monthDate = DateTime(_selectedYear, monthNum, 1);
                  final monthAbbr = DateFormat('MMM').format(monthDate).toUpperCase();
                  final logCount = _getTransactionCountForMonth(_selectedYear, monthNum);
                  final bool hasLogs = logCount > 0;
                  final bool isSelected = _selectedMonth == monthNum;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: hasLogs
                          ? () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedMonth = monthNum);
                            }
                          : null,
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryColor
                              : hasLogs
                                  ? AppColors.surfaceCard(context)
                                  : AppColors.scaffoldBackground(context).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? primaryColor
                                : hasLogs
                                    ? AppColors.cardBorder(context)
                                    : AppColors.cardBorder(context).withValues(alpha: 0.15),
                            width: isSelected ? 1.8 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              monthAbbr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: isSelected
                                    ? Colors.white
                                    : hasLogs
                                        ? AppColors.textPrimary(context)
                                        : AppColors.textSecondary(context).withValues(alpha: 0.35),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.22)
                                    : hasLogs
                                        ? AppColors.creditGreenBg
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                hasLogs ? '$logCount logs' : 'No logs',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? Colors.white
                                      : hasLogs
                                          ? AppColors.creditGreen
                                          : AppColors.textSecondary(context).withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // --- 2. BY YEAR SECTION ---
            if (_selectedFrequency == ExportPeriodFrequency.byYear) ...[
              Text(
                'Financial Record Years',
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),

              // Years Grid (2 Columns)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: availableYears.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (ctx, index) {
                  final yr = availableYears[index];
                  final logCount = _getTransactionCountForYear(yr);
                  final bool hasLogs = logCount > 0;
                  final bool isSelected = _selectedYear == yr;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: hasLogs
                          ? () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedYear = yr);
                            }
                          : null,
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryColor
                              : hasLogs
                                  ? AppColors.surfaceCard(context)
                                  : AppColors.scaffoldBackground(context).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? primaryColor
                                : hasLogs
                                    ? AppColors.cardBorder(context)
                                    : AppColors.cardBorder(context).withValues(alpha: 0.15),
                            width: isSelected ? 1.8 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ]
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$yr',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'monospace',
                                    color: isSelected
                                        ? Colors.white
                                        : hasLogs
                                            ? AppColors.textPrimary(context)
                                            : AppColors.textSecondary(context).withValues(alpha: 0.35),
                                  ),
                                ),
                                Icon(
                                  hasLogs
                                      ? (isSelected ? Icons.check_circle_rounded : Icons.date_range_rounded)
                                      : Icons.block_rounded,
                                  size: 16,
                                  color: isSelected
                                      ? Colors.white
                                      : hasLogs
                                          ? primaryColor
                                          : AppColors.textSecondary(context).withValues(alpha: 0.3),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.22)
                                    : hasLogs
                                        ? AppColors.creditGreenBg
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                hasLogs ? '$logCount logs recorded' : 'No financial logs',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : hasLogs
                                          ? AppColors.creditGreen
                                          : AppColors.textSecondary(context).withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // --- 3. CUSTOM DATE RANGE SECTION ---
            if (_selectedFrequency == ExportPeriodFrequency.custom) ...[
              Row(
                children: [
                  Expanded(
                    child: NummoCard(
                      child: InkWell(
                        onTap: () => _pickCustomDate(true),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('From Date', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('dd MMM yyyy').format(_customStartDate),
                                style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: NummoCard(
                      child: InkWell(
                        onTap: () => _pickCustomDate(false),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('To Date', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('dd MMM yyyy').format(_customEndDate),
                                style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Financial Log Existence Validation Banner
            NummoCard(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: hasData
                      ? AppColors.creditGreen.withValues(alpha: 0.08)
                      : warningAmber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: hasData
                        ? AppColors.creditGreen.withValues(alpha: 0.3)
                        : warningAmber.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasData ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                      color: hasData ? AppColors.creditGreen : warningAmber,
                      size: 24,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasData ? '${filteredTxns.length} Financial Logs Found' : 'No Financial Logs Available',
                            style: TextStyle(
                              color: AppColors.textPrimary(context),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasData
                                ? 'Expense: ${MoneyFormatter.format(totalExpense)} • Income: ${MoneyFormatter.format(totalIncome)}'
                                : 'No transactions exist in the selected range (${range.title}). Choose a different period to export.',
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
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Export Action Buttons (PDF & Excel)
            Row(
              children: [
                Expanded(
                  child: NummoButton(
                    text: _isExportingPdf ? 'Exporting...' : 'Export PDF',
                    icon: Icons.picture_as_pdf_rounded,
                    onPressed: (hasData && !_isExportingPdf && !_isExportingExcel)
                        ? () => _handleExport(true, filteredTxns, range)
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: NummoButton(
                    text: _isExportingExcel ? 'Exporting...' : 'Export Excel',
                    icon: Icons.table_chart_rounded,
                    onPressed: (hasData && !_isExportingPdf && !_isExportingExcel)
                        ? () => _handleExport(false, filteredTxns, range)
                        : null,
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
}
