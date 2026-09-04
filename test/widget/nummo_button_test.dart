import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nummo/design_system/components/nummo_button.dart';

void main() {
  group('NummoButton Responsive Layout Tests', () {
    testWidgets('renders cleanly without overflow in very narrow constraints (84px and below)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 84.0,
                child: NummoButton(
                  text: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  variant: NummoButtonVariant.destructive,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders side-by-side buttons in compact dialog/modal width without overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 260.0,
                child: Row(
                  children: [
                    Expanded(
                      child: NummoButton(
                        text: 'Edit',
                        icon: Icons.edit_rounded,
                        variant: NummoButtonVariant.outline,
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: NummoButton(
                        text: 'Delete',
                        icon: Icons.delete_outline_rounded,
                        variant: NummoButtonVariant.destructive,
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
