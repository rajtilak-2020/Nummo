import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nummo/features/security/lock_screen.dart';
import 'package:nummo/core/security/biometric_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LockScreen renders full-screen Telegram-style reactive TurbulentDisplaceBackground and responds to key taps', (WidgetTester tester) async {
    bool unlocked = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF10B981), primary: const Color(0xFF10B981)),
        ),
        home: LockScreen(
          isBioEnabled: false,
          onVerifyPin: (pin) async => pin == '1234',
          onSuccess: () {
            unlocked = true;
          },
          biometricService: BiometricService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(TurbulentDisplaceBackground), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('Nummo'), findsOneWidget);
    expect(find.text('Enter Passcode'), findsOneWidget);

    // Tap digits 1, 2, 3, 4 to trigger reactive impulse animations and verify unlock
    await tester.tap(find.text('1'));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('2'));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('3'));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();

    expect(unlocked, isTrue);
  });
}
