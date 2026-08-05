import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/transaction.dart';
import '../../core/utils/money_formatter.dart';
import '../../design_system/tokens.dart';
import '../../design_system/components/nummo_card.dart';
import '../../design_system/components/nummo_button.dart';
import 'export_service.dart';

enum ExportPeriodFrequency {
  today('Today'),
  thisWeek('This Week'),
  thisMonth('This Month'),
  thisYear('This Year'),
  allTime('All Time'),
  custom('Custom Range');

  final String label;
  const ExportPeriodFrequency(this.label);
}

/// Dialog / Bottom Sheet allowing users to select frequency range, validate financial log existence, and export PDF or Excel statement.
class ExportDialog extends StatefulWidget {
  final List<Transaction> transactions;
  final String budgetName;

  const ExportDialog({
    super.key,
    required this.transactions,
    required this.budgetName,
  });

  static Future<void> show(BuildContext context, {
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
  ExportPeriodFrequency _selectedFrequency = ExportPeriodFrequency.thisMonth;
  DateTime _customStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _customEndDate = DateTime.now();

  bool _isExportingPdf = false;
  bool _isExportingExcel = false;

  ({DateTime start, DateTime end, String title}) _getPeriodRange() {
    final now = DateTime.now();
    switch (_selectedFrequency) {
      case ExportPeriodFrequency.today:
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return (start: start, end: end, title: 'Today (${DateFormat('dd MMM yyyy').format(now)})');

      case ExportPeriodFrequency.thisWeek:
        final start = now.subtract(Duration(days: now.weekday - 1));
        final weekStart = DateTime(start.year, start.month, start.day);
        final weekEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return (start: weekStart, end: weekEnd, title: 'This Week (${DateFormat('dd MMM').format(weekStart)} – ${DateFormat('dd MMM').format(weekEnd)})');

      case ExportPeriodFrequency.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
        return (start: start, end: end, title: DateFormat('MMMM yyyy').format(now));

      case ExportPeriodFrequency.thisYear:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        return (start: start, end: end, title: 'Year ${now.year}');

      case ExportPeriodFrequency.allTime:
        final start = DateTime(2000, 1, 1);
        final end = DateTime(2099, 12, 31, 23, 59, 59, 999);
        return (start: start, end: end, title: 'All Time Records');

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
      if (isPdf) {
        await ExportService.exportPdf(
          transactions: txns,
          periodTitle: range.title,
          startDate: range.start,
          endDate: range.end,
          budgetName: widget.budgetName,
        );
      } else {
        await ExportService.exportExcel(
          transactions: txns,
          periodTitle: range.title,
          startDate: range.start,
          endDate: range.end,
          budgetName: widget.budgetName,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${isPdf ? "PDF Document" : "Excel Spreadsheet"} exported successfully!'),
            backgroundColor: AppColors.creditGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export: $e'),
            backgroundColor: AppColors.debitRed,
          ),
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

    double totalIncome = 0.0;
    double totalExpense = 0.0;
    for (final t in filteredTxns) {
      if (t.isCredit) {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar & Header
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

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Icon(
                    Icons.output_rounded,
                    color: Theme.of(context).colorScheme.primary,
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
                        'Export PDF or Excel report of your financial logs',
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

            // Period Frequency Selection Title
            Text(
              'Select Frequency / Range',
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // Chips List for Frequency Range
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ExportPeriodFrequency.values.map((freq) {
                final isSelected = _selectedFrequency == freq;
                return ChoiceChip(
                  label: Text(freq.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedFrequency = freq);
                    }
                  },
                  selectedColor: Theme.of(context).colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary(context),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  backgroundColor: AppColors.scaffoldBackground(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),

            // Custom Range Date Pickers
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

            // Export Buttons (PDF & Excel)
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
            const SizedBox(height: AppSpacing.md),
            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () async {
                  final uri = Uri.parse('https://github.com/rajtilak-2020');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Developed by ',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 11,
                        ),
                      ),
                      TextSpan(
                        text: 'K Rajtilak',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 11,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ),
      ),
    );
  }
}
