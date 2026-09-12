import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:all_one/core/app_data.dart';

void main() {
  group('AppDataStore balance invariants', () {
    late AppDataStore store;
    late String accountId;

    setUp(() {
      store = AppDataStore.inMemory();
      accountId = store.accounts.first.id;
    });

    test('seed data reproduces the mockup balance exactly', () {
      expect(store.balanceFor(accountId), 388489);
      final transactions = store.transactionsFor(accountId);
      expect(transactions, hasLength(7));
      expect(store.runningBalanceFor(transactions.first), 388489);
      expect(store.runningBalanceFor(transactions.last), 360289);
    });

    test('create, edit and delete apply the exact signed delta', () async {
      final before = store.balanceFor(accountId);
      final created = await store.createTransaction(
        accountId: accountId,
        title: '테스트 입금',
        signedAmount: 12345,
        occurredAt: DateTime(2026, 7, 23, 1, 2, 3),
        channel: '모바일',
      );
      expect(store.balanceFor(accountId), before + 12345);

      await store.saveTransaction(created.copyWith(signedAmount: -2000));
      expect(store.balanceFor(accountId), before - 2000);

      await store.deleteTransaction(created.id);
      expect(store.balanceFor(accountId), before);
    });

    test(
      'duplicate changes balance once and reorder never changes it',
      () async {
        final source = store.transactionsFor(accountId).first;
        final before = store.balanceFor(accountId);
        final duplicate = await store.duplicateTransaction(source.id);
        expect(duplicate, isNotNull);
        expect(store.balanceFor(accountId), before + source.signedAmount);

        final afterDuplicate = store.balanceFor(accountId);
        await store.reorderTransactions(accountId, 0, 2);
        expect(store.balanceFor(accountId), afterDuplicate);
      },
    );

    test('changing date to the second recalculates running balances', () async {
      final transactions = store.transactionsFor(accountId);
      final latest = transactions.first;
      final changed = latest.copyWith(
        occurredAt: DateTime(2026, 7, 20, 0, 0, 1),
      );
      await store.saveTransaction(changed);

      expect(store.balanceFor(accountId), 388489);
      expect(store.runningBalanceFor(changed), 559289);
    });

    test('editing displayed balance sets the exact requested total', () async {
      final account = store.accountById(accountId)!;
      await store.saveAccountWithCurrentBalance(account, 500000);
      expect(store.balanceFor(accountId), 500000);
      expect(store.transactionsFor(accountId), hasLength(7));
    });

    test(
      'editing displayed balance remains exact after income history',
      () async {
        final account = store.accountById(accountId)!;
        await store.createTransaction(
          accountId: accountId,
          title: '추가 입금',
          signedAmount: 100000,
          occurredAt: DateTime(2026, 7, 30, 1, 2, 3),
          channel: '모바일',
        );
        await store.saveAccountWithCurrentBalance(account, 50000);
        expect(store.balanceFor(accountId), 50000);
      },
    );
  });

  group('AppDataStore CRUD', () {
    test('accounts and recipients can be added, edited and removed', () async {
      final store = AppDataStore.inMemory();
      final account = await store.createAccount(
        bankCode: '우리',
        bankDisplayName: '우리 커스텀',
        ownerName: 'TEST OWNER',
        accountNumber: '100-200-300',
        accountType: '입출금',
        openingBalance: 500000,
      );
      expect(store.balanceFor(account.id), 500000);

      await store.saveAccount(
        account.copyWith(bankDisplayName: '새 표시 이름', openingBalance: 700000),
      );
      expect(store.accountById(account.id)?.bankDisplayName, '새 표시 이름');
      expect(store.balanceFor(account.id), 700000);

      final recipient = await store.createRecipient(
        displayName: '받는 사람',
        bankCode: '하나',
        accountNumber: '123456789',
      );
      await store.saveRecipient(recipient.copyWith(displayName: '수정된 이름'));
      expect(
        store.recipients
            .singleWhere((item) => item.id == recipient.id)
            .displayName,
        '수정된 이름',
      );
      await store.deleteRecipient(recipient.id);
      expect(
        store.recipients.where((item) => item.id == recipient.id),
        isEmpty,
      );

      await store.archiveAccount(account.id);
      expect(store.accounts.where((item) => item.id == account.id), isEmpty);
    });

    test(
      'account and recipient numbers are validated and cannot duplicate',
      () async {
        final store = AppDataStore.inMemory(withMockData: false);
        await expectLater(
          store.createAccount(
            bankCode: '신한',
            bankDisplayName: '신한',
            ownerName: 'OWNER',
            accountNumber: '12',
            accountType: '입출금',
            openingBalance: 0,
          ),
          throwsArgumentError,
        );
        await expectLater(
          store.createAccount(
            bankCode: '신한',
            bankDisplayName: '신한',
            ownerName: 'OWNER',
            accountNumber: '110-123-456',
            accountType: '입출금',
            openingBalance: -1,
          ),
          throwsArgumentError,
        );

        await store.createRecipient(
          displayName: 'FIRST',
          bankCode: '우리',
          accountNumber: '100-200-300',
        );
        await expectLater(
          store.createRecipient(
            displayName: 'DUPLICATE',
            bankCode: '우리',
            accountNumber: '100200300',
          ),
          throwsStateError,
        );
      },
    );

    test('manual expense cannot reduce an account below zero', () async {
      final store = AppDataStore.inMemory(withMockData: false);
      final account = await store.createAccount(
        bankCode: '신한',
        bankDisplayName: '신한',
        ownerName: 'OWNER',
        accountNumber: '110-123-456',
        accountType: '입출금',
        openingBalance: 100,
      );
      await expectLater(
        store.createTransaction(
          accountId: account.id,
          title: 'TOO LARGE',
          signedAmount: -101,
          occurredAt: DateTime(2026, 8, 1),
          channel: '모바일',
        ),
        throwsStateError,
      );
      expect(store.balanceFor(account.id), 100);
      expect(store.transactionsFor(account.id), isEmpty);
    });
  });

  test('recent recipients can save up to fifty entries', () async {
    final store = AppDataStore.inMemory(withMockData: false);
    for (var index = 0; index < AppDataStore.maxSavedRecipients; index++) {
      await store.createRecipient(
        displayName: 'Recipient $index',
        bankCode: '신한',
        accountNumber: '110000000$index',
      );
    }

    expect(store.recipients, hasLength(AppDataStore.maxSavedRecipients));
    await expectLater(
      store.createRecipient(
        displayName: 'One too many',
        bankCode: '신한',
        accountNumber: '1100000050',
      ),
      throwsStateError,
    );
  });

  test(
    'a new user scope starts with no mockup data and persists additions',
    () async {
      SharedPreferences.setMockInitialValues({});
      final first = AppDataStore();
      await first.initialize('user-a');
      expect(first.accounts, isEmpty);
      expect(first.recipients, isEmpty);

      final account = await first.createAccount(
        bankCode: '신한',
        bankDisplayName: '나의 신한 계좌',
        ownerName: 'NEW USER',
        accountNumber: '110-000-000000',
        accountType: '입출금',
        openingBalance: 100000,
      );
      await first.createTransaction(
        accountId: account.id,
        title: '영구 저장',
        signedAmount: 777,
        occurredAt: DateTime(2026, 7, 29, 12, 34, 56),
        channel: '모바일',
      );
      final expectedBalance = first.balanceFor(account.id);

      final reloaded = AppDataStore();
      await reloaded.initialize('user-a');
      expect(reloaded.balanceFor(account.id), expectedBalance);
      expect(
        reloaded
            .transactionsFor(account.id)
            .where((item) => item.title == '영구 저장'),
        hasLength(1),
      );

      final otherUser = AppDataStore();
      await otherUser.initialize('user-b');
      expect(otherUser.accounts, isEmpty);
      expect(otherUser.transactionsFor(account.id), isEmpty);
      expect(otherUser.recipients, isEmpty);
    },
  );

  test(
    'home card values and spending month persist for the signed-in user',
    () async {
      SharedPreferences.setMockInitialValues({});
      final first = AppDataStore();
      await first.initialize('home-card-user');

      expect(first.homeCardMonth, 8);
      expect(first.homeCardAmount, 6500);
      expect(first.homeSpendingMonth, DateTime.now().month);
      await first.updateHomeCardUsage(month: 9, amount: 123456);
      await first.updateHomeSpendingMonth(6);

      final reloaded = AppDataStore();
      await reloaded.initialize('home-card-user');
      expect(reloaded.homeCardMonth, 9);
      expect(reloaded.homeCardAmount, 123456);
      expect(reloaded.homeSpendingMonth, 6);
    },
  );

  test('home card rejects invalid month and negative amount', () async {
    final store = AppDataStore.inMemory(withMockData: false);

    await expectLater(
      store.updateHomeCardUsage(month: 0, amount: 1000),
      throwsArgumentError,
    );
    await expectLater(
      store.updateHomeCardUsage(month: 8, amount: -1),
      throwsArgumentError,
    );
    await expectLater(store.updateHomeSpendingMonth(13), throwsArgumentError);
    expect(store.homeCardMonth, 8);
    expect(store.homeCardAmount, 6500);
    expect(store.homeSpendingMonth, DateTime.now().month);
  });

  test('corrupted local data recovers to an empty valid state', () async {
    SharedPreferences.setMockInitialValues({
      'nh_allone_app_data_v2-Z3Vlc3Q=': '{not-valid-json',
    });
    final store = AppDataStore();

    await store.initialize('guest');

    expect(store.accounts, isEmpty);
    expect(store.recipients, isEmpty);
  });

  test(
    'legacy mockup data is removed without deleting user-created rows',
    () async {
      const scope = 'existing-user';
      final key =
          'nh_allone_app_data_v1-${base64Url.encode(utf8.encode(scope))}';
      SharedPreferences.setMockInitialValues({
        key: jsonEncode({
          'schemaVersion': 1,
          'updatedAtMicros': 1,
          'idSequence': 3,
          'accounts': [
            {
              'id': 'default-account',
              'bankCode': '신한',
              'bankDisplayName': '신한',
              'ownerName': 'MOCK',
              'accountNumber': '110-628-103680',
              'accountType': '저축예금',
              'openingBalance': 560289,
              'createdAt': '2026-07-20T00:00:00.000Z',
              'archived': false,
            },
            {
              'id': 'user-account',
              'bankCode': '우리',
              'bankDisplayName': '내 우리 계좌',
              'ownerName': 'REAL USER',
              'accountNumber': '100-200-300',
              'accountType': '입출금',
              'openingBalance': 250000,
              'createdAt': '2026-07-25T00:00:00.000Z',
              'archived': false,
            },
          ],
          'transactions': [
            {
              'id': 'seed-transaction-0',
              'accountId': 'default-account',
              'title': 'MOCK',
              'signedAmount': -1000,
              'occurredAt': '2026-07-22T00:00:00.000Z',
              'channel': '모바일',
              'displayOrder': 0,
            },
          ],
          'recipients': [
            {
              'id': 'seed-recipient-0',
              'displayName': 'MOCK',
              'bankCode': '신한',
              'accountNumber': '1',
              'favorite': false,
            },
            {
              'id': 'user-recipient',
              'displayName': 'NGƯỜI NHẬN THẬT',
              'bankCode': '우리',
              'accountNumber': '200300400',
              'favorite': false,
            },
          ],
        }),
      });

      final store = AppDataStore();
      await store.initialize(scope);

      expect(store.accounts.map((item) => item.id), ['user-account']);
      expect(store.transactionsFor('user-account'), isEmpty);
      expect(store.recipients.map((item) => item.id), ['user-recipient']);
    },
  );
}
