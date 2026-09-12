import 'package:flutter_test/flutter_test.dart';
import 'package:all_one/core/pin_security.dart';

void main() {
  test(
    'PINs and failed attempts stay isolated by account and purpose',
    () async {
      final security = PinSecurityService(store: MemoryPinValueStore());

      await security.setPin(
        accountScope: 'firebase-user-a',
        purpose: PinPurpose.appAccess,
        pin: '123456',
      );
      await security.setPin(
        accountScope: 'firebase-user-a',
        purpose: PinPurpose.transfer,
        pin: '9876',
      );

      final firstFailure = await security.verify(
        accountScope: 'firebase-user-a',
        purpose: PinPurpose.appAccess,
        pin: '000000',
      );
      expect(firstFailure.matched, isFalse);
      expect(firstFailure.failedAttempts, 1);
      expect(firstFailure.locked, isFalse);

      final transferResult = await security.verify(
        accountScope: 'firebase-user-a',
        purpose: PinPurpose.transfer,
        pin: '9876',
      );
      expect(transferResult.matched, isTrue);
      expect(transferResult.failedAttempts, 0);

      final otherAccount = await security.status(
        accountScope: 'firebase-user-b',
        purpose: PinPurpose.appAccess,
      );
      expect(otherAccount.configured, isFalse);
      expect(otherAccount.failedAttempts, 0);
    },
  );

  test('the fifth wrong PIN locks verification until it is cleared', () async {
    final security = PinSecurityService(store: MemoryPinValueStore());
    await security.setPin(
      accountScope: 'firebase-user',
      purpose: PinPurpose.appAccess,
      pin: '123456',
    );

    for (
      var attempt = 1;
      attempt <= PinSecurityService.maxAttempts;
      attempt++
    ) {
      final result = await security.verify(
        accountScope: 'firebase-user',
        purpose: PinPurpose.appAccess,
        pin: '000000',
      );
      expect(result.failedAttempts, attempt);
      expect(result.locked, attempt == PinSecurityService.maxAttempts);
    }

    final correctWhileLocked = await security.verify(
      accountScope: 'firebase-user',
      purpose: PinPurpose.appAccess,
      pin: '123456',
    );
    expect(correctWhileLocked.matched, isFalse);
    expect(correctWhileLocked.failedAttempts, 5);

    await security.clear(
      accountScope: 'firebase-user',
      purpose: PinPurpose.appAccess,
    );
    final cleared = await security.status(
      accountScope: 'firebase-user',
      purpose: PinPurpose.appAccess,
    );
    expect(cleared.configured, isFalse);
    expect(cleared.failedAttempts, 0);
  });
}
