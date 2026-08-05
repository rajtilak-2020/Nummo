import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Category model containing stable ID, name, emoji, and color.
class CategoryTag {
  final String id;
  final String name;
  final String emoji;
  final int colorValue;

  const CategoryTag({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorValue,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'colorValue': colorValue,
    };
  }

  factory CategoryTag.fromJson(Map<String, dynamic> json) {
    final rawName = json['name']?.toString() ?? 'OTHER';
    final rawEmoji = json['emoji']?.toString() ?? '🏷️';
    final rawColor = (json['colorValue'] as num?)?.toInt() ?? 0xFF64748B;
    final rawId = json['id']?.toString() ?? const Uuid().v4();

    return CategoryTag(
      id: rawId,
      name: rawName,
      emoji: rawEmoji,
      colorValue: rawColor,
    );
  }

  /// Migrates legacy string tags (e.g. "FOOD", "SHOPPING") into CategoryTag instances.
  factory CategoryTag.fromString(String rawTag) {
    final trimmed = rawTag.trim().toUpperCase();
    final match = defaults.firstWhere(
      (c) => c.id.toUpperCase() == trimmed || c.name.toUpperCase() == trimmed,
      orElse: () => CategoryTag(
        id: const Uuid().v4(),
        name: rawTag.trim(),
        emoji: '🏷️',
        colorValue: 0xFF64748B,
      ),
    );
    return match;
  }

  static const List<CategoryTag> defaults = [
    CategoryTag(id: 'FOOD', name: 'Food', emoji: '🍔', colorValue: 0xFFF59E0B),
    CategoryTag(id: 'SHOPPING', name: 'Shopping', emoji: '🛍️', colorValue: 0xFFEC4899),
    CategoryTag(id: 'FUEL', name: 'Fuel', emoji: '⛽', colorValue: 0xFF3B82F6),
  ];

  static CategoryTag fromIdOrName(String? input) {
    if (input == null || input.trim().isEmpty) return defaults.first;
    final clean = input.trim();
    for (final cat in defaults) {
      if (cat.id.equalsIgnoreCase(clean) || cat.name.equalsIgnoreCase(clean)) {
        return cat;
      }
    }
    return CategoryTag.fromString(clean);
  }
}

extension _StringExt on String {
  bool equalsIgnoreCase(String other) => toLowerCase() == other.toLowerCase();
}
