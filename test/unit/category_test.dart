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

    test('CategoryTag created in transaction modal updates category list', () {
      final categories = List<CategoryTag>.from(CategoryTag.defaults);
      const newCat = CategoryTag(id: 'MOVIES', name: 'Movies', emoji: '🍿', colorValue: 0xFF8B5CF6);

      if (!categories.any((c) => c.name.toLowerCase() == newCat.name.toLowerCase())) {
        categories.add(newCat);
      }

      expect(categories.length, 4);
      expect(categories.any((c) => c.name == 'Movies' && c.emoji == '🍿'), isTrue);
    });
  });
}
