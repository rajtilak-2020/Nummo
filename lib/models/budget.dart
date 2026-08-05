import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'transaction.dart';

enum BudgetPeriod { weekly, monthly, custom }

/// Multi-Budget model supporting category scope, custom cycles, and spending calculations.
class Budget {
  final String id;
  final String title;
  final double amount;
  final String scope; // 'overall' or category ID/name
  final BudgetPeriod period;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isRecurring;

  Budget({
    String? id,
    required this.title,
    required this.amount,
    this.scope = 'overall',
    this.period = BudgetPeriod.monthly,
    DateTime? startDate,
    this.endDate,
    this.isRecurring = true,
  })  : id = id ?? const Uuid().v4(),
        startDate = startDate ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'scope': scope,
      'period': period.name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isRecurring': isRecurring,
    };
  }

  factory Budget.fromJson(Map<String, dynamic> json) {
    final rawAmount = (json['amount'] as num?)?.toDouble() ?? 0.0;
    final rawTitle = json['title']?.toString() ?? 'Budget';
    final rawScope = json['scope']?.toString() ?? 'overall';

    BudgetPeriod period = BudgetPeriod.monthly;
    if (json['period'] == 'weekly') period = BudgetPeriod.weekly;
    if (json['period'] == 'custom') period = BudgetPeriod.custom;

    DateTime start = DateTime.now();
    if (json['startDate'] != null) {
      start = DateTime.tryParse(json['startDate'].toString()) ?? DateTime.now();
    }

    DateTime? end;
    if (json['endDate'] != null) {
      end = DateTime.tryParse(json['endDate'].toString());
    }

    return Budget(
      id: json['id']?.toString() ?? const Uuid().v4(),
      title: rawTitle,
      amount: rawAmount > 0 ? rawAmount : 0.0,
      scope: rawScope,
      period: period,
      startDate: start,
      endDate: end,
      isRecurring: json['isRecurring'] as bool? ?? true,
    );
  }

  /// Label helper for period & recurrence display
  String get periodLabel {
    switch (period) {
      case BudgetPeriod.weekly:
        return isRecurring ? 'Weekly (Recurring)' : 'Weekly (One-time)';
      case BudgetPeriod.monthly:
        return isRecurring ? 'Monthly (Recurring)' : 'Monthly (One-time)';
      case BudgetPeriod.custom:
        if (endDate != null) {
          final s = DateFormat('dd MMM').format(startDate);
          final e = DateFormat('dd MMM').format(endDate!);
          return '$s - $e';
        }
        return 'Custom Date Range';
    }
  }

  /// Calculates current active date range for spending calculation.
  ({DateTime start, DateTime end}) getCurrentCycleRange([DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    if (period == BudgetPeriod.custom) {
      final start = startDate;
      final end = endDate ?? DateTime(now.year + 10);
      return (start: start, end: end);
    } else if (period == BudgetPeriod.weekly) {
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      final end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      return (start: start, end: end);
    } else {
      // Monthly
      final start = DateTime(now.year, now.month, 1);
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      final end = nextMonth.subtract(const Duration(seconds: 1));
      return (start: start, end: end);
    }
  }

  /// Calculates total debit spending within current budget cycle.
  double calculateSpent(List<Transaction> transactions, [DateTime? referenceDate]) {
    final range = getCurrentCycleRange(referenceDate);
    double total = 0.0;

    for (final t in transactions) {
      if (t.isCredit) continue; // Debits only

      final tDate = t.timestamp;
      final isAfterOrAtStart = tDate.isAfter(range.start) || tDate.isAtSameMomentAs(range.start);
      final isBeforeOrAtEnd = tDate.isBefore(range.end) || tDate.isAtSameMomentAs(range.end);

      if (isAfterOrAtStart && isBeforeOrAtEnd) {
        if (scope == 'overall' ||
            (t.tag != null && (t.tag!.toLowerCase() == scope.toLowerCase()))) {
          total += t.amount;
        }
      }
    }

    return total;
  }
}
