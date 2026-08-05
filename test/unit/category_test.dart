import 'package:flutter_test/flutter_test.dart';
import 'package:nummo/models/category.dart';

void main() {
  group('CategoryTag Tests', () {
    test('CategoryTag preserves emoji separately from name', () {
      const cat = CategoryTag(id: 'CUSTOM', name: 'Coffee & Tea', emoji: '☕', colorValue: 0xFFF59E0B);
      expect(cat.name, 'Coffee & Tea');
      expect(cat.emoji, '☕');

      final json = cat.toJson();
      final restored = CategoryTag.fromJson(json);
      expect(restored.name, 'Coffee & Tea');
      expect(restored.emoji, '☕');
    });

    test('CategoryTag.fromString migrates legacy tags safely', () {
      final foodCat = CategoryTag.fromString('FOOD');
      expect(foodCat.emoji, '🍔');

      final customCat = CategoryTag.fromString('MY_SPECIAL_TAG');
      expect(customCat.emoji, '🏷️');
      expect(customCat.name, 'MY_SPECIAL_TAG');
    });
  });
}
