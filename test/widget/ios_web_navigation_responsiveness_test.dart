import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nummo/design_system/tokens.dart';
import 'package:nummo/design_system/components/animations.dart';

void main() {
  group('iOS Web Navigation Responsiveness & Safe Area Tests', () {
    testWidgets('AppSpacing.safeBottomInset returns system padding when system padding > 0', (tester) async {
      double? resolvedInset;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34.0)),
            child: Builder(
              builder: (context) {
                resolvedInset = AppSpacing.safeBottomInset(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(resolvedInset, 34.0);
    });

    testWidgets('AppSpacing.safeBottomInset returns 0.0 on non-iOS platform when system padding is 0', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      double? resolvedInset;

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(padding: EdgeInsets.zero),
              child: Builder(
                builder: (context) {
                  resolvedInset = AppSpacing.safeBottomInset(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        // When not kIsWeb, it returns 0.0 when system padding is 0.0
        expect(resolvedInset, 0.0);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('NummoBouncy triggers onTap and reverses animation', (tester) async {
      int tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NummoBouncy(
                onTap: () {
                  tapCount++;
                },
                child: const Text('Tap Me'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Tap Me'), findsOneWidget);
      expect(tapCount, 0);

      await tester.tap(find.text('Tap Me'));
      await tester.pumpAndSettle();

      expect(tapCount, 1);
    });

    testWidgets('NummoBouncy handles tap down and release cleanly', (tester) async {
      int tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NummoBouncy(
                onTap: () {
                  tapCount++;
                },
                child: const SizedBox(
                  width: 100,
                  height: 50,
                  child: Center(child: Text('Button')),
                ),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.text('Button')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tapCount, 0);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(tapCount, 1);
    });

    testWidgets('NummoBouncy does not fire onTap when gesture is dragged away and cancelled', (tester) async {
      int tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NummoBouncy(
                onTap: () {
                  tapCount++;
                },
                child: const SizedBox(
                  width: 100,
                  height: 50,
                  child: Center(child: Text('Cancel Button')),
                ),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.text('Cancel Button')));
      await tester.pump(const Duration(milliseconds: 50));
      // Drag far away to trigger tapCancel
      await gesture.moveBy(const Offset(0, 300));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tapCount, 0);
    });
  });
}
