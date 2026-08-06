import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../core/utils/money_formatter.dart';
import 'file_saver.dart';

/// Handles generation and download/export of PDF and native Excel financial statements.
class ExportService {
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _fileDateFormat = DateFormat('yyyyMMdd_HHmmss');

  /// Generates clean PDF document bytes with no emojis or Unicode icons.
  static Future<List<int>> generatePdfBytes({
    required List<Transaction> transactions,
    required String periodTitle,
    required DateTime startDate,
    required DateTime endDate,
    required String budgetName,
  }) async {
    final pdf = pw.Document();

    final sortedTxns = List<Transaction>.from(transactions)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    double totalIncome = 0.0;
    double totalExpense = 0.0;
    final Map<String, double> categorySpendMap = {};
    final Map<String, int> categoryCountMap = {};

    for (final t in sortedTxns) {
      if (t.isCredit) {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
        final catKey = t.tag ?? 'OTHER';
        categorySpendMap[catKey] = (categorySpendMap[catKey] ?? 0.0) + t.amount;
        categoryCountMap[catKey] = (categoryCountMap[catKey] ?? 0) + 1;
      }
    }

    final netSavings = totalIncome - totalExpense;
    final ratio = totalIncome > 0 ? (totalExpense / totalIncome * 100).clamp(0.0, 999.0) : 0.0;

    final catEntries = categorySpendMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final accountName = _resolveAccountName(budgetName);
    final dateRangeText = '${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}';
    final String formattedScope;
    if (periodTitle.contains(DateFormat('dd MMM yyyy').format(startDate)) || periodTitle.contains(DateFormat('dd MMM').format(startDate))) {
      formattedScope = periodTitle;
    } else {
      formattedScope = '$periodTitle ($dateRangeText)';
    }

    String formatPdfMoney(double amount) {
      return MoneyFormatter.format(amount).replaceAll('₹', 'Rs. ');
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'NUMMO FINANCIAL STATEMENT',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Account: $accountName | Scope: $formattedScope',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Date & Time Generated',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
                      style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 1)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    pw.Text(
                      'Finance Tracker - Developed by ',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                    pw.UrlLink(
                      destination: 'https://github.com/rajtilak-2020',
                      child: pw.Text(
                        'K Rajtilak',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.blue700,
                          decoration: pw.TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 16),

            // Executive Summary Metric Box
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _pdfMetricItem('Total Income', formatPdfMoney(totalIncome), PdfColors.green700),
                  _pdfMetricItem('Total Expense', formatPdfMoney(totalExpense), PdfColors.red700),
                  _pdfMetricItem('Net Savings', formatPdfMoney(netSavings), netSavings >= 0 ? PdfColors.blue700 : PdfColors.red700),
                  _pdfMetricItem('Spend Ratio', '${ratio.toStringAsFixed(1)}%', PdfColors.orange700),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Category Breakdown Section (Clean plain text names - no emojis)
            if (catEntries.isNotEmpty) ...[
              pw.Text(
                'Category Breakdown',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(2.5),
                  3: const pw.FlexColumnWidth(2),
                },
                headers: ['Category Name', 'Transactions', 'Total Amount', '% Share'],
                data: catEntries.map((e) {
                  final catTag = CategoryTag.fromIdOrName(e.key);
                  final pct = totalExpense > 0 ? (e.value / totalExpense * 100).toStringAsFixed(1) : '0.0';
                  final count = categoryCountMap[e.key] ?? 0;
                  return [
                    catTag.name,
                    '$count txns',
                    formatPdfMoney(e.value),
                    '$pct%',
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 20),
            ],

            // Transaction Detail Log Table (Clean plain text names - no emojis)
            pw.Text(
              'Detailed Financial Transaction Log (${sortedTxns.length} records)',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
            ),
            pw.SizedBox(height: 8),

            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FlexColumnWidth(2.2),
                1: const pw.FlexColumnWidth(2.5),
                2: const pw.FlexColumnWidth(1.8),
                3: const pw.FlexColumnWidth(1.4),
                4: const pw.FlexColumnWidth(2.0),
                5: const pw.FlexColumnWidth(2.0),
              },
              headers: ['Date & Time', 'Note / Particulars', 'Category', 'Type', 'Amount', 'Balance After'],
              data: sortedTxns.map((t) {
                final catTag = CategoryTag.fromIdOrName(t.tag ?? 'OTHER');
                return [
                  _dateFormat.format(t.timestamp),
                  t.note,
                  catTag.name,
                  t.isCredit ? 'CREDIT' : 'DEBIT',
                  formatPdfMoney(t.amount),
                  formatPdfMoney(t.balanceAfter),
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  /// Exports selected transactions as a formatted PDF statement document.
  static Future<bool> exportPdf({
    required List<Transaction> transactions,
    required String periodTitle,
    required DateTime startDate,
    required DateTime endDate,
    required String budgetName,
  }) async {
    final bytes = await generatePdfBytes(
      transactions: transactions,
      periodTitle: periodTitle,
      startDate: startDate,
      endDate: endDate,
      budgetName: budgetName,
    );

    final filename = 'Nummo_Report_${_fileDateFormat.format(DateTime.now())}.pdf';
    return await downloadExportFile(
      bytes: bytes,
      filename: filename,
      mimeType: 'application/pdf',
    );
  }

  static pw.Widget _pdfMetricItem(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.SizedBox(height: 3),
        pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color)),
      ],
    );
  }

  /// Generates native Microsoft Excel workbook bytes with clean text and no emojis.
  static List<int> generateExcelBytes({
    required List<Transaction> transactions,
    required String periodTitle,
    required DateTime startDate,
    required DateTime endDate,
    required String budgetName,
  }) {
    final sortedTxns = List<Transaction>.from(transactions)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    double totalIncome = 0.0;
    double totalExpense = 0.0;
    final Map<String, double> categorySpendMap = {};
    final Map<String, int> categoryCountMap = {};

    for (final t in sortedTxns) {
      if (t.isCredit) {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
        final catKey = t.tag ?? 'OTHER';
        categorySpendMap[catKey] = (categorySpendMap[catKey] ?? 0.0) + t.amount;
        categoryCountMap[catKey] = (categoryCountMap[catKey] ?? 0) + 1;
      }
    }

    final netSavings = totalIncome - totalExpense;

    final excel = Excel.createExcel();
    final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    final Sheet sheet = excel[defaultSheet];

    void appendRow(List<dynamic> values) {
      sheet.appendRow(values.map((v) {
        if (v == null) return TextCellValue('');
        if (v is double) return DoubleCellValue(v);
        if (v is int) return IntCellValue(v);
        return TextCellValue(v.toString());
      }).toList());
    }

    final accountName = _resolveAccountName(budgetName);
    final dateRangeText = '${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}';
    final String formattedScope;
    if (periodTitle.contains(DateFormat('dd MMM yyyy').format(startDate)) || periodTitle.contains(DateFormat('dd MMM').format(startDate))) {
      formattedScope = periodTitle;
    } else {
      formattedScope = '$periodTitle ($dateRangeText)';
    }

    // Title Block
    appendRow(['NUMMO PERSONAL FINANCE STATEMENT']);
    appendRow(['Account', accountName]);
    appendRow(['Period Scope', formattedScope]);
    appendRow(['Date Range', '${DateFormat('yyyy-MM-dd').format(startDate)} to ${DateFormat('yyyy-MM-dd').format(endDate)}']);
    appendRow(['Date & Time Generated', DateFormat('yyyy-MM-dd HH:mm:ss (hh:mm a)').format(DateTime.now())]);
    appendRow([]);

    // Executive Summary Block
    appendRow(['EXECUTIVE FINANCIAL SUMMARY']);
    appendRow(['Total Income (Credit)', totalIncome]);
    appendRow(['Total Expense (Debit)', totalExpense]);
    appendRow(['Net Savings / Balance', netSavings]);
    appendRow(['Total Transactions', sortedTxns.length]);
    appendRow([]);

    // Category Breakdown Table (Clean category names - no emojis)
    appendRow(['CATEGORY BREAKDOWN METRICS']);
    appendRow(['Category Name', 'Transaction Count', 'Total Spent (Rupees)', 'Percentage Share']);
    for (final entry in categorySpendMap.entries) {
      final catTag = CategoryTag.fromIdOrName(entry.key);
      final pct = totalExpense > 0 ? (entry.value / totalExpense * 100).toStringAsFixed(2) : '0.00';
      final count = categoryCountMap[entry.key] ?? 0;
      appendRow([catTag.name, count, entry.value, '$pct%']);
    }
    appendRow([]);

    // Detailed Log Table (Clean category names - no emojis)
    appendRow(['TRANSACTION LOG DETAILS']);
    appendRow(['Transaction ID', 'Timestamp', 'Date', 'Time', 'Particulars / Note', 'Category', 'Type', 'Amount (Rupees)', 'Balance After (Rupees)']);

    final timeFormat = DateFormat('hh:mm:ss a');
    final dateOnlyFormat = DateFormat('yyyy-MM-dd');

    for (final t in sortedTxns) {
      final catTag = CategoryTag.fromIdOrName(t.tag ?? 'OTHER');
      appendRow([
        t.id,
        t.timestamp.toIso8601String(),
        dateOnlyFormat.format(t.timestamp),
        timeFormat.format(t.timestamp),
        t.note,
        catTag.name, // Plain text category name with no emoji
        t.isCredit ? 'CREDIT' : 'DEBIT',
        t.amount,
        t.balanceAfter,
      ]);
    }

    appendRow([]);
    appendRow(['100% Offline Personal Finance Tracker • Developed by K Rajtilak (https://github.com/rajtilak-2020)']);

    final bytes = excel.save();
    return bytes ?? [];
  }

  static String _resolveAccountName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Nummo Personal Account';
    final clean = raw.trim();
    final lower = clean.toLowerCase();
    if (lower == 'overall' ||
        lower == 'primary account' ||
        lower == 'primary ledger' ||
        lower == 'monthly' ||
        lower == 'budget' ||
        lower == 'overall account') {
      return 'Nummo Personal Account';
    }
    if (lower.contains('nummo') || lower.contains('account')) {
      return clean;
    }
    return 'Nummo Personal Account ($clean)';
  }

  /// Exports selected transactions as a native Microsoft Excel workbook file.
  static Future<bool> exportExcel({
    required List<Transaction> transactions,
    required String periodTitle,
    required DateTime startDate,
    required DateTime endDate,
    required String budgetName,
  }) async {
    final bytes = generateExcelBytes(
      transactions: transactions,
      periodTitle: periodTitle,
      startDate: startDate,
      endDate: endDate,
      budgetName: budgetName,
    );

    final filename = 'Nummo_Transactions_${_fileDateFormat.format(DateTime.now())}.xlsx';
    return await downloadExportFile(
      bytes: bytes,
      filename: filename,
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }
}
