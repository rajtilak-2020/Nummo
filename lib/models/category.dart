import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum TagScope {
  debit,
  credit,
  both;

  String get label {
    switch (this) {
      case TagScope.debit:
        return 'Debit Only';
      case TagScope.credit:
        return 'Credit Only';
      case TagScope.both:
        return 'Both (Credit & Debit)';
    }
  }

  String get shortLabel {
    switch (this) {
      case TagScope.debit:
        return 'Debit';
      case TagScope.credit:
        return 'Credit';
      case TagScope.both:
        return 'Both';
    }
  }

  bool get isApplicableToDebit => this == TagScope.debit || this == TagScope.both;
  bool get isApplicableToCredit => this == TagScope.credit || this == TagScope.both;

  static TagScope fromString(String? val, [TagScope defaultScope = TagScope.debit]) {
    if (val == null || val.trim().isEmpty) return defaultScope;
    final lower = val.trim().toLowerCase();
    if (lower == 'credit' || lower == 'income') return TagScope.credit;
    if (lower == 'both' || lower == 'all') return TagScope.both;
    if (lower == 'debit' || lower == 'expense') return TagScope.debit;
    return defaultScope;
  }
}

/// Category model containing stable ID, name, emoji, color, and section usability scope.
class CategoryTag {
  final String id;
  final String name;
  final String emoji;
  final int colorValue;
  final TagScope? _scope;

  const CategoryTag({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorValue,
    TagScope? scope = TagScope.debit,
  }) : _scope = scope ?? TagScope.debit;

  TagScope get scope => _scope ?? TagScope.debit;

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'colorValue': colorValue,
      'scope': scope.name,
    };
  }

  factory CategoryTag.fromJson(Map<String, dynamic> json) {
    final rawName = json['name']?.toString() ?? 'OTHER';
    final rawEmoji = json['emoji']?.toString() ?? '🏷️';
    final rawColor = (json['colorValue'] as num?)?.toInt() ?? 0xFF64748B;
    final rawId = json['id']?.toString() ?? const Uuid().v4();
    final rawScope = json['scope']?.toString();

    final TagScope scope;
    if (rawScope != null && rawScope.trim().isNotEmpty) {
      scope = TagScope.fromString(rawScope, TagScope.debit);
    } else {
      // Legacy data migration: match against known defaults if applicable,
      // otherwise default custom tags to debit since legacy versions only supported debit expenses.
      final matchDefault = defaults.where(
        (d) => d.id.equalsIgnoreCase(rawId) || d.name.equalsIgnoreCase(rawName),
      ).firstOrNull;
      scope = matchDefault?.scope ?? TagScope.debit;
    }

    return CategoryTag(
      id: rawId,
      name: rawName,
      emoji: rawEmoji,
      colorValue: rawColor,
      scope: scope,
    );
  }

  /// Migrates legacy string tags (e.g. "FOOD", "SHOPPING") into CategoryTag instances.
  factory CategoryTag.fromString(String rawTag) {
    final trimmed = rawTag.trim().toUpperCase();
    final match = defaults.where(
      (c) => c.id.toUpperCase() == trimmed || c.name.toUpperCase() == trimmed,
    ).firstOrNull;
    if (match != null) return match;

    return CategoryTag(
      id: const Uuid().v4(),
      name: rawTag.trim(),
      emoji: '🏷️',
      colorValue: 0xFF64748B,
      scope: TagScope.debit,
    );
  }

  static const List<CategoryTag> defaults = [
    CategoryTag(id: 'FOOD', name: 'Food', emoji: '🍔', colorValue: 0xFFF59E0B, scope: TagScope.debit),
    CategoryTag(id: 'SHOPPING', name: 'Shopping', emoji: '🛍️', colorValue: 0xFFEC4899, scope: TagScope.debit),
    CategoryTag(id: 'FUEL', name: 'Fuel', emoji: '⛽', colorValue: 0xFF3B82F6, scope: TagScope.debit),
    CategoryTag(id: 'SALARY', name: 'Salary', emoji: '💰', colorValue: 0xFF10B981, scope: TagScope.credit),
    CategoryTag(id: 'POCKETMONEY', name: 'Pocket Money', emoji: '💵', colorValue: 0xFF06B6D4, scope: TagScope.credit),
    CategoryTag(id: 'FREELANCE', name: 'Freelance', emoji: '💼', colorValue: 0xFF8B5CF6, scope: TagScope.credit),
    CategoryTag(id: 'INVESTMENT', name: 'Investment', emoji: '📈', colorValue: 0xFFF59E0B, scope: TagScope.both),
  ];

  static CategoryTag fromIdOrName(String? input, [List<CategoryTag>? customCategories]) {
    if (input == null || input.trim().isEmpty) return defaults.first;
    final clean = input.trim();

    if (customCategories != null && customCategories.isNotEmpty) {
      for (final cat in customCategories) {
        if (cat.id.equalsIgnoreCase(clean) ||
            cat.name.equalsIgnoreCase(clean) ||
            cat.id.replaceAll('_', '').equalsIgnoreCase(clean.replaceAll('_', '').replaceAll(' ', '')) ||
            cat.name.replaceAll(' ', '').equalsIgnoreCase(clean.replaceAll(' ', '').replaceAll('_', ''))) {
          return cat;
        }
      }
    }

    for (final cat in defaults) {
      if (cat.id.equalsIgnoreCase(clean) ||
          cat.name.equalsIgnoreCase(clean) ||
          cat.id.replaceAll('_', '').equalsIgnoreCase(clean.replaceAll('_', '').replaceAll(' ', '')) ||
          cat.name.replaceAll(' ', '').equalsIgnoreCase(clean.replaceAll(' ', '').replaceAll('_', ''))) {
        return cat;
      }
    }
    return CategoryTag.fromString(clean);
  }

  CategoryTag copyWith({
    String? id,
    String? name,
    String? emoji,
    int? colorValue,
    TagScope? scope,
  }) {
    return CategoryTag(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      colorValue: colorValue ?? this.colorValue,
      scope: scope ?? this.scope,
    );
  }
}

extension _StringExt on String {
  bool equalsIgnoreCase(String other) => toLowerCase() == other.toLowerCase();
}
