import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:all_one/core/app_data.dart';
import 'package:all_one/core/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'native auth restoration stays pending until Firebase reports state',
    () async {
      final states = StreamController<String?>();
      var completed = false;
      final restoration = waitForInitialFirebaseAuthState(states.stream);
      unawaited(restoration.then((_) => completed = true));

      await Future<void>.delayed(Duration.zero);
      expect(states.hasListener, isTrue);
      expect(completed, isFalse);

      states.add('restored-user');
      expect(await restoration, 'restored-user');
      expect(completed, isTrue);
      await states.close();
    },
  );

  test('login and ledger survive a full service restart', () async {
    SharedPreferences.setMockInitialValues({});

    final firstAuth = AuthService();
    await firstAuth.initialize();
    final registration = await firstAuth.authenticate(
      mode: AuthMode.register,
      email: 'persistent@example.com',
      password: 'secret123',
      displayName: 'PERSISTENT USER',
    );
    expect(registration.ok, isTrue);
    expect(firstAuth.isSignedIn, isTrue);

    final wrongAccount = await firstAuth.reauthenticate(
      email: 'other@example.com',
      password: 'secret123',
    );
    expect(wrongAccount.ok, isFalse);
    final correctAccount = await firstAuth.reauthenticate(
      email: 'persistent@example.com',
      password: 'secret123',
    );
    expect(correctAccount.ok, isTrue);

    final firstStore = AppDataStore();
    await firstStore.initialize(firstAuth.dataScope);
    final account = await firstStore.createAccount(
      bankCode: '신한',
      bankDisplayName: '신한',
      ownerName: 'PERSISTENT USER',
      accountNumber: '110-123-456789',
      accountType: '저축예금',
      openingBalance: 500000,
    );
    await firstStore.createTransaction(
      accountId: account.id,
      title: '재실행 후 유지',
      signedAmount: -12500,
      occurredAt: DateTime(2026, 8, 6, 12, 34, 56),
      channel: '모바일',
    );

    // New service/store instances emulate killing and relaunching the app.
    final restoredAuth = AuthService();
    await restoredAuth.initialize();
    expect(restoredAuth.isSignedIn, isTrue);
    expect(restoredAuth.currentEmail, 'persistent@example.com');
    expect(restoredAuth.displayName, 'PERSISTENT USER');
    expect(restoredAuth.dataScope, firstAuth.dataScope);

    final restoredStore = AppDataStore();
    await restoredStore.initialize(restoredAuth.dataScope);
    expect(restoredStore.accounts, hasLength(1));
    expect(restoredStore.balanceFor(account.id), 487500);
    expect(restoredStore.transactionsFor(account.id).single.title, '재실행 후 유지');

    await restoredAuth.signOut();
    final signedOutAuth = AuthService();
    await signedOutAuth.initialize();
    expect(signedOutAuth.isSignedIn, isFalse);
    expect(signedOutAuth.dataScope, 'guest');
  });
}
