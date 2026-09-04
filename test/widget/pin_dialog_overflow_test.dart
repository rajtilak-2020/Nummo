import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nummo/design_system/components/pin_setup_dialog.dart';
import 'package:nummo/design_system/components/pin_verify_dialog.dart';

void main() {
  group('PIN Dialogs Narrow Screen Overflow Tests', () {
    testWidgets('PinSetupDialog renders cleanly without RenderFlex overflow on 320dp width', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PinSetupDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(PinSetupDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PinVerifyDialog renders cleanly without RenderFlex overflow on 320dp width', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PinVerifyDialog(
                onVerifyPin: (pin) async => true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(PinVerifyDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
