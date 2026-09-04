import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nummo/design_system/components/animations.dart';

void main() {
  group('NummoMarqueeText Widget Tests', () {
    setUp(() {
      NummoMarqueeText.enableInTests = true;
    });

    tearDown(() {
      NummoMarqueeText.enableInTests = false;
    });

    testWidgets('Short text fits within constraints and renders statically without scroll view', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: NummoMarqueeText(
                text: 'Short Note',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify text is present
      expect(find.text('Short Note'), findsOneWidget);
      // SingleChildScrollView should not be rendered when text fits
      expect(find.byType(SingleChildScrollView), findsNothing);
    });

    testWidgets('Long text that overflows scrolls sideways without ellipsis', (tester) async {
      const longText = 'Super Long Detailed Note For An Extremely Big Transaction Description';
      
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              child: NummoMarqueeText(
                text: longText,
                style: TextStyle(fontSize: 14),
                pauseDuration: Duration(milliseconds: 200),
                scrollSpeed: 100.0,
                returnSpeed: 100.0,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Text widget rendered with complete text (no ellipsis)
      expect(find.text(longText), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text(longText));
      expect(textWidget.overflow, isNot(TextOverflow.ellipsis));

      // SingleChildScrollView is rendered for scrolling
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      final scrollableFinder = find.byType(Scrollable);
      final initialScrollPosition = tester.state<ScrollableState>(scrollableFinder).position.pixels;
      expect(initialScrollPosition, 0.0);

      // Advance time past initial pause and into scroll animation
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 300));

      final scrolledPosition = tester.state<ScrollableState>(scrollableFinder).position.pixels;
      expect(scrolledPosition, greaterThan(0.0));
    });

    testWidgets('Empty text renders without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: NummoMarqueeText(
                text: '',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Text), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing);
    });
  });
}
