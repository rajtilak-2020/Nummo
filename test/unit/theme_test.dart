import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nummo/design_system/tokens.dart';

void main() {
  group('Theme & Accent Swatches System Tests', () {
    test('AppColors.accentSwatches contains expanded set of 14 theme presets', () {
      expect(AppColors.accentSwatches.length, equals(14));
      expect(AppColors.accentSwatches.containsKey('Indigo Slate'), isTrue);
      expect(AppColors.accentSwatches.containsKey('Sky Platinum'), isTrue);
      expect(AppColors.accentSwatches.containsKey('Emerald Mint'), isTrue);
      expect(AppColors.accentSwatches.containsKey('Electric Cyan'), isTrue);
      expect(AppColors.accentSwatches.containsKey('Gold Amber'), isTrue);
      expect(AppColors.accentSwatches.containsKey('Royal Violet'), isTrue);
      expect(AppColors.accentSwatches.containsKey('Crimson Rose'), isTrue);
      expect(AppColors.accentSwatches.containsKey('Teal Lagoon'), isTrue);
      expect(AppColors.accentSwatches.containsKey('Sunset Orange'), isTrue);
      expect(AppColors.accentSwatches.containsKey('Amethyst Glow'), isTrue);
      expect(AppColors.accentSwatches.containsKey('Magenta Pink'), isTrue);
      expect(AppColors.accentSwatches.containsKey('Forest Moss'), isTrue);
      expect(AppColors.accentSwatches.containsKey('Cobalt Sapphire'), isTrue);
      expect(AppColors.accentSwatches.containsKey('Obsidian Slate'), isTrue);
    });

    test('resolveAccentColor returns preset color for known swatch names', () {
      final indigo = AppColors.resolveAccentColor('Indigo Slate');
      expect(indigo, equals(const Color(0xFF4F46E5)));

      final crimson = AppColors.resolveAccentColor('Crimson Rose');
      expect(crimson, equals(const Color(0xFFE11D48)));
    });

    test('resolveAccentColor parses custom hex codes correctly', () {
      final customColor = AppColors.resolveAccentColor('#EC4899');
      expect(customColor.toARGB32(), equals(const Color(0xFFEC4899).toARGB32()));

      final rawHex = AppColors.resolveAccentColor('FF5722');
      expect(rawHex.toARGB32(), equals(const Color(0xFFFF5722).toARGB32()));
    });

    test('resolveAccentColor falls back to Indigo Slate on invalid inputs', () {
      final fallback = AppColors.resolveAccentColor('InvalidColorName');
      expect(fallback, equals(const Color(0xFF4F46E5)));
    });

    test('NummoToast.createSnackBar constructs styled floating SnackBar with appropriate icons and colors', () {
      final successBar = NummoToast.createSnackBar(
        message: 'Data saved successfully',
        type: ToastType.success,
      );
      expect(successBar.behavior, SnackBarBehavior.floating);
      expect(successBar.backgroundColor, const Color(0xFF1E212D));

      final errorBar = NummoToast.createSnackBar(
        message: 'Something went wrong',
        type: ToastType.error,
      );
      expect(errorBar.behavior, SnackBarBehavior.floating);

      final warningBar = NummoToast.createSnackBar(
        message: 'Warning note',
        type: ToastType.warning,
      );
      expect(warningBar.behavior, SnackBarBehavior.floating);
    });

    testWidgets('NummoToast renders Apple-style animated toast with scale and fade', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => NummoToast.show(ctx, message: 'Settings saved', type: ToastType.success),
                  child: const Text('Show Toast'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to show toast
      await tester.tap(find.text('Show Toast'));
      await tester.pump(const Duration(milliseconds: 50));

      // Toast is entering with animation
      expect(find.text('Settings saved'), findsOneWidget);

      // Settle entry animation
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Settings saved'), findsOneWidget);

      // Wait for auto dismiss
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Toast dismissed
      expect(find.text('Settings saved'), findsNothing);
    });
  });
}
