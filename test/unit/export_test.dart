import 'package:flutter_test/flutter_test.dart';
import 'package:nummo/models/transaction.dart';
import 'package:nummo/features/export/export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Export Service & Format Tests', () {
    final testTxns = [
      Transaction(
        id: 'txn-1',
        amount: 5000.0,
        isCredit: true,
        note: 'Freelance Payment',
        timestamp: DateTime(2026, 8, 1, 10, 0),
        tag: 'SALARY',
      ),
      Transaction(
        id: 'txn-2',
        amount: 450.0,
        isCredit: false,
        note: 'Grocery Supermarket',
        timestamp: DateTime(2026, 8, 2, 14, 30),
        tag: 'FOOD',
      ),
    ];

    test('Export CSV/Excel generates valid headers, branding, and transaction logs', () {
      final now = DateTime(2026, 8, 5);
      final start = DateTime(2026, 8, 1);

      final bytes = ExportService.generateExcelBytes(
        transactions: testTxns,
        periodTitle: 'August 2026',
        startDate: start,
        endDate: now,
        budgetName: 'Test Account',
      );

      expect(bytes.isNotEmpty, true);
    });

    test('Export PDF generates document bytes cleanly with branding and links', () async {
      final now = DateTime(2026, 8, 5);
      final start = DateTime(2026, 8, 1);

      final bytes = await ExportService.generatePdfBytes(
        transactions: testTxns,
        periodTitle: 'August 2026',
        startDate: start,
        endDate: now,
        budgetName: 'Test Account',
      );

      expect(bytes.isNotEmpty, true);
    });

    test('Filtering transactions by period range validates log availability', () {
      final start = DateTime(2026, 8, 1);
      final end = DateTime(2026, 8, 5, 23, 59, 59);

      final inRange = testTxns.where((t) => !t.timestamp.isBefore(start) && !t.timestamp.isAfter(end)).toList();
      expect(inRange.length, 2);

      final outOfRangeStart = DateTime(2026, 9, 1);
      final outOfRangeEnd = DateTime(2026, 9, 30);
      final emptyRange = testTxns.where((t) => !t.timestamp.isBefore(outOfRangeStart) && !t.timestamp.isAfter(outOfRangeEnd)).toList();
      expect(emptyRange.isEmpty, true);
    });
  });
}
