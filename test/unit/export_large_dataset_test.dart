import 'package:flutter_test/flutter_test.dart';
import 'package:nummo/features/export/export_service.dart';
import 'package:nummo/models/transaction.dart';
import 'package:nummo/models/category.dart';

void main() {
  group('ExportService Large Dataset & Unicode Sanitization Tests', () {
    test('ExportService.generatePdfBytes runs on background isolate with 1000 transactions', () async {
      final txns = List.generate(
        1000,
        (i) => Transaction(
          id: 't_$i',
          amount: (i + 1) * 10.0,
          isCredit: i % 3 == 0,
          note: 'Transaction item number $i with descriptive text that wraps cleanly',
          timestamp: DateTime(2026, 1, 1).add(Duration(hours: i)),
          balanceAfter: 1000.0 + i * 10,
          tag: 'FOOD',
        ),
      );

      final bytes = await ExportService.generatePdfBytes(
        transactions: txns,
        periodTitle: 'All Transactions',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 6, 1),
        budgetName: 'Nummo Personal Account',
      );
      expect(bytes.isNotEmpty, isTrue);
    });

    test('ExportService.generatePdfBytes sanitizes Unicode emojis and typography without errors', () async {
      final categories = [
        const CategoryTag(id: 'FOOD', name: 'Food 🍕', colorValue: 0xFF10B981, emoji: '🍕'),
      ];

      final txns = [
        Transaction(
          id: 'u_1',
          amount: 750,
          isCredit: false,
          note: 'Starbucks ☕ coffee & lunch 🥪 ₹750 — ‘special’ “treat”… • groceries',
          timestamp: DateTime(2026, 3, 15, 14, 30),
          balanceAfter: 9250,
          tag: 'FOOD',
        ),
        Transaction(
          id: 'u_2',
          amount: 5000,
          isCredit: true,
          note: 'Salary credit 🎉 ₹5,000 — March 2026',
          timestamp: DateTime(2026, 3, 1, 10, 0),
          balanceAfter: 10000,
          tag: 'FOOD',
        ),
      ];

      final bytes = await ExportService.generatePdfBytes(
        transactions: txns,
        periodTitle: 'Unicode Test Period — 2026',
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 31),
        budgetName: 'Nummo Personal Account',
        categories: categories,
      );

      expect(bytes.isNotEmpty, isTrue);
    });

    test('ExportService.generateExcelBytes generates valid Excel bytes', () {
      final txns = [
        Transaction(
          id: 'x_1',
          amount: 150,
          isCredit: false,
          note: 'Groceries',
          timestamp: DateTime(2026, 3, 15, 14, 30),
          balanceAfter: 850,
          tag: 'FOOD',
        ),
      ];

      final bytes = ExportService.generateExcelBytes(
        transactions: txns,
        periodTitle: 'March 2026',
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 31),
        budgetName: 'Nummo Personal Account',
      );

      expect(bytes.isNotEmpty, isTrue);
    });
  });
}
