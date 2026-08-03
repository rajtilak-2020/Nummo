import 'package:flutter/material.dart';

class Transaction {
  final String id;
  final double amount;
  final bool isCredit;
  final String note;
  final DateTime timestamp;
  double balanceAfter;
  final String? tag;

  Transaction({
    required this.id,
    required this.amount,
    required this.isCredit,
    required this.note,
    required this.timestamp,
    this.balanceAfter = 0.0,
    this.tag,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'isCredit': isCredit,
        'note': note,
        'timestamp': timestamp.toIso8601String(),
        'balanceAfter': balanceAfter,
        'tag': tag,
      };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as String,
        amount: (json['amount'] as num).toDouble(),
        isCredit: json['isCredit'] as bool,
        note: json['note'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        balanceAfter: (json['balanceAfter'] as num?)?.toDouble() ?? 0.0,
        tag: json['tag'] as String?,
      );
}

enum BudgetPeriod {
  daily,
  weekly,
  monthly,
  custom,
}

class Budget {
  final String id;
  final String title;
  final double amount;
  final BudgetPeriod period;
  final bool isRepetitive; // true = auto-repeats each period, false = one-time
  final String? tag; // null or empty = All Categories
  final DateTime startDate;
  final DateTime? endDate; // required for custom

  Budget({
    required this.id,
    required this.title,
    required this.amount,
    required this.period,
    required this.isRepetitive,
    this.tag,
    required this.startDate,
    this.endDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'period': period.name,
        'isRepetitive': isRepetitive,
        'tag': tag,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
      };

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Budget',
        amount: (json['amount'] as num).toDouble(),
        period: BudgetPeriod.values.firstWhere(
          (e) => e.name == json['period'],
          orElse: () => BudgetPeriod.monthly,
        ),
        isRepetitive: json['isRepetitive'] as bool? ?? true,
        tag: json['tag'] as String?,
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: json['endDate'] != null
            ? DateTime.parse(json['endDate'] as String)
            : null,
      );

  DateTimeRange getCurrentPeriodRange([DateTime? now]) {
    final ref = now ?? DateTime.now();

    if (period == BudgetPeriod.custom) {
      final start = startDate;
      final end = endDate ?? startDate.add(const Duration(days: 30));
      return DateTimeRange(start: start, end: end);
    }

    if (!isRepetitive) {
      DateTime end;
      switch (period) {
        case BudgetPeriod.daily:
          end = DateTime(
              startDate.year, startDate.month, startDate.day, 23, 59, 59, 999);
          break;
        case BudgetPeriod.weekly:
          end = startDate.add(
              const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
          break;
        case BudgetPeriod.monthly:
          final nextMonth = DateTime(startDate.year, startDate.month + 1, 1);
          end = nextMonth.subtract(const Duration(milliseconds: 1));
          break;
        case BudgetPeriod.custom:
          end = endDate ?? startDate.add(const Duration(days: 30));
          break;
      }
      return DateTimeRange(start: startDate, end: end);
    }

    // Repetitive
    switch (period) {
      case BudgetPeriod.daily:
        final start = DateTime(ref.year, ref.month, ref.day);
        final end = DateTime(ref.year, ref.month, ref.day, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);

      case BudgetPeriod.weekly:
        final dayOffset = ref.weekday - 1;
        final start = DateTime(ref.year, ref.month, ref.day - dayOffset);
        final end = start.add(
            const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        return DateTimeRange(start: start, end: end);

      case BudgetPeriod.monthly:
        final start = DateTime(ref.year, ref.month, 1);
        final nextMonth = DateTime(ref.year, ref.month + 1, 1);
        final end = nextMonth.subtract(const Duration(milliseconds: 1));
        return DateTimeRange(start: start, end: end);

      case BudgetPeriod.custom:
        final start = startDate;
        final end = endDate ?? startDate.add(const Duration(days: 30));
        return DateTimeRange(start: start, end: end);
    }
  }

  double calculateSpent(List<Transaction> transactions, [DateTime? now]) {
    final range = getCurrentPeriodRange(now);
    double total = 0.0;

    for (final tx in transactions) {
      if (tx.isCredit) continue;
      if (tx.timestamp.isBefore(range.start) ||
          tx.timestamp.isAfter(range.end)) {
        continue;
      }

      if (tag != null && tag!.isNotEmpty) {
        final txClean = TagHelper.getCleanName(tx.tag ?? '').toUpperCase();
        final budgetClean = TagHelper.getCleanName(tag!).toUpperCase();
        if (txClean != budgetClean) continue;
      }

      total += tx.amount;
    }
    return total;
  }

  bool isActive([DateTime? now]) {
    final ref = now ?? DateTime.now();
    final range = getCurrentPeriodRange(ref);
    return !ref.isBefore(range.start) && !ref.isAfter(range.end);
  }
}

class TagHelper {
  static const Map<String, List<String>> emojiCategories = {
    'Food & Drink': ['🍔', '🍕', '☕', '🍺', '🍜', '🍣', '🍦', '🍩', '🥑', '🍷'],
    'Shopping': ['🛍️', '🛒', '👕', '👟', '💄', '💍', '🎁', '📱', '💻', '🎧'],
    'Travel & Transport': ['✈️', '🚗', '⛽', '🚖', '🚆', '🚲', '🏖️', '🏨', '🎟️', '🗺️'],
    'Bills & Utilities': ['📄', '💡', '💧', '⚡', '📶', '🏠', '🔑', '🛠️', '📺', '🧾'],
    'Finance & Growth': ['💰', '📈', '💳', '🏦', '💎', '💵', '🪙', '📊', '💼', '🎯'],
    'Health & Lifestyle': ['🏥', '💊', '🏋️', '🧘', '⚽', '🎮', '🎓', '🐾', '🍿', '🎨'],
  };

  static const List<String> availableEmojis = [
    '🍔', '🍕', '☕', '🍺', '🛍️', '✈️', '🚗', '⛽',
    '📦', '📄', '🎬', '🏥', '🛒', '💰', '📈', '🎮',
    '💡', '📱', '🏋️', '🎓', '🐾', '🏠', '🎁', '⚡',
  ];

  static const Map<String, String> defaultTagEmojis = {
    'FOOD': '🍔',
    'SHOPPING': '🛍️',
    'TRAVEL': '✈️',
    'OTHERS': '📦',
  };

  static const List<String> defaultTags = [
    '🍔 FOOD',
    '🛍️ SHOPPING',
    '✈️ TRAVEL',
    '📦 OTHERS',
  ];

  static String getCleanName(String fullTag) {
    final trimmed = fullTag.trim();
    // Remove leading emoji if present
    final regex = RegExp(
        r'^[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{1F1E6}-\u{1F1FF}\s]+',
        unicode: true);
    final clean = trimmed.replaceFirst(regex, '').trim();
    return clean.isEmpty ? trimmed : clean;
  }

  static String getEmoji(String fullTag) {
    final trimmed = fullTag.trim();
    if (trimmed.isEmpty) return '';
    final firstChar = trimmed.split(' ').first;
    final regex = RegExp(
        r'^[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{1F1E6}-\u{1F1FF}]',
        unicode: true);
    if (regex.hasMatch(firstChar)) {
      return firstChar;
    }
    final clean = getCleanName(trimmed).toUpperCase();
    if (defaultTagEmojis.containsKey(clean)) {
      return defaultTagEmojis[clean]!;
    }
    return '';
  }

  static String formatTag(String name, String emoji) {
    final clean = getCleanName(name).toUpperCase();
    final trimmedEmoji = emoji.trim();
    if (trimmedEmoji.isEmpty) {
      return clean;
    }
    return '$trimmedEmoji $clean';
  }
}
