import 'package:flutter_test/flutter_test.dart';
import 'package:nummo/core/security/app_lock_guard.dart';

void main() {
  group('AppLockGuard Unit Tests', () {
    setUp(() {
      AppLockGuard.reset();
    });

    test('Initial state of isPickerActive is false', () {
      expect(AppLockGuard.isPickerActive, isFalse);
    });

    test('setPickerActive explicitly modifies active status', () {
      AppLockGuard.setPickerActive(true);
      expect(AppLockGuard.isPickerActive, isTrue);
      AppLockGuard.setPickerActive(false);
      expect(AppLockGuard.isPickerActive, isFalse);
    });

    test('runWithPickerGuard sets active to true during execution and resets to false afterwards', () async {
      expect(AppLockGuard.isPickerActive, isFalse);

      bool insideActionChecked = false;
      final result = await AppLockGuard.runWithPickerGuard(() async {
        expect(AppLockGuard.isPickerActive, isTrue);
        insideActionChecked = true;
        return 'success';
      });

      expect(insideActionChecked, isTrue);
      expect(result, equals('success'));
      expect(AppLockGuard.isPickerActive, isFalse);
    });

    test('runWithPickerGuard resets active to false even if action throws an error', () async {
      expect(AppLockGuard.isPickerActive, isFalse);

      try {
        await AppLockGuard.runWithPickerGuard(() async {
          expect(AppLockGuard.isPickerActive, isTrue);
          throw Exception('Picker error');
        });
      } catch (_) {}

      expect(AppLockGuard.isPickerActive, isFalse);
    });

    test('shouldSuppressResumeLock remains true for grace window after picker finishes', () async {
      expect(AppLockGuard.shouldSuppressResumeLock, isFalse);

      await AppLockGuard.runWithPickerGuard(() async {
        expect(AppLockGuard.shouldSuppressResumeLock, isTrue);
        return true;
      });

      // After picker finishes, shouldSuppressResumeLock remains true for grace window
      expect(AppLockGuard.isPickerActive, isFalse);
      expect(AppLockGuard.shouldSuppressResumeLock, isTrue);

      AppLockGuard.reset();
      expect(AppLockGuard.shouldSuppressResumeLock, isFalse);
    });

    test('Nested runWithPickerGuard maintains active state properly', () async {
      AppLockGuard.reset();
      expect(AppLockGuard.isPickerActive, isFalse);

      await AppLockGuard.runWithPickerGuard(() async {
        expect(AppLockGuard.isPickerActive, isTrue);

        await AppLockGuard.runWithPickerGuard(() async {
          expect(AppLockGuard.isPickerActive, isTrue);
        });

        // Still active after inner finishes
        expect(AppLockGuard.isPickerActive, isTrue);
      });

      // Both finished
      expect(AppLockGuard.isPickerActive, isFalse);
      expect(AppLockGuard.shouldSuppressResumeLock, isTrue);

      AppLockGuard.reset();
    });
  });
}
