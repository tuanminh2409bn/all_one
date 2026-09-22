import 'package:all_one/core/app_data.dart';
import 'package:all_one/core/auth_service.dart';
import 'package:all_one/core/bank_catalog.dart';
import 'package:all_one/core/pin_security.dart';
import 'package:all_one/ui/certificate_login_screen.dart';
import 'package:all_one/ui/home_screen.dart';
import 'package:all_one/ui/limit_release_screen.dart';
import 'package:all_one/ui/native_home_view.dart';
import 'package:all_one/ui/account_details_screen.dart';
import 'package:all_one/ui/app_theme.dart';
import 'package:all_one/ui/pin_screen.dart';
import 'package:all_one/ui/splash_screen.dart';
import 'package:all_one/ui/transfer_recipient_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  setUpAll(() async {
    final loader = FontLoader('NotoSansKR')
      ..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'))
      ..addFont(rootBundle.load('assets/fonts/NotoSansCJKkr-Bold.otf'));
    await loader.load();
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await materialIcons.load();
  });

  testWidgets('export splash', (tester) async {
    _configureMockupViewport(tester);
    final auth = AuthService();

    await tester.pumpWidget(
      _host(SplashScreen(auth: auth, autoContinue: false)),
    );
    await _precache(tester, const ['assets/images/entry_6_splash.png']);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/preview_0_splash.png'),
    );
  });

  testWidgets('export entry, home checkpoints, and login sheet', (
    tester,
  ) async {
    _configureMockupViewport(tester);
    final auth = AuthService();
    final store = AppDataStore.inMemory(withMockData: false);

    await tester.pumpWidget(
      _host(CertificateLoginScreen(auth: auth, autoContinue: false)),
    );
    await _precache(tester, const ['assets/images/entry_7_certificate.png']);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/preview_0a_certificate.png'),
    );

    await tester.pumpWidget(_host(PinScreen(auth: auth)));
    await _precache(tester, const ['assets/images/entry_8_pin.png']);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/preview_0b_pin.png'),
    );

    await tester.pumpWidget(
      _homeHost(
        HomeScreen(
          key: const ValueKey('home-top'),
          auth: auth,
          dataStore: store,
        ),
      ),
    );
    await _precache(tester, _homeAssets);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/preview_1_home_top.png'),
    );

    await tester.pumpWidget(
      _homeHost(
        HomeScreen(
          key: const ValueKey('home-benefits'),
          auth: auth,
          dataStore: store,
          initialScrollOffset: 633,
        ),
      ),
    );
    await _precache(tester, _homeAssets);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/preview_2_benefits.png'),
    );

    await tester.pumpWidget(
      _homeHost(
        HomeScreen(
          key: const ValueKey('home-spending'),
          auth: auth,
          dataStore: store,
          initialScrollOffset: 1580,
        ),
      ),
    );
    await _precache(tester, _homeAssets);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/preview_3_spending.png'),
    );

    await tester.pumpWidget(
      _homeHost(
        HomeScreen(
          key: const ValueKey('home-lifestyle'),
          auth: auth,
          dataStore: store,
          initialScrollOffset: 2535,
        ),
      ),
    );
    await _precache(tester, _homeAssets);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/preview_4_lifestyle.png'),
    );

    await tester.pumpWidget(
      _homeHost(
        HomeScreen(
          key: const ValueKey('home-group-footer'),
          auth: auth,
          dataStore: store,
          initialScrollOffset: 2942,
        ),
      ),
    );
    await _precache(tester, _homeAssets);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/preview_5_group_footer.png'),
    );

    await tester.pumpWidget(
      _homeHost(
        HomeScreen(
          key: const ValueKey('home-login'),
          auth: auth,
          dataStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-account-name')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-auth-action')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/preview_6_login_sheet.png'),
    );
  });

  testWidgets('export corrected signed-in home comparison', (tester) async {
    _configureMockupViewport(tester);
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    final account = BankAccount(
      id: 'home-comparison-account',
      bankCode: '농협',
      bankDisplayName: 'NH농협은행',
      ownerName: 'BUI PHUONG',
      accountNumber: '302-2180-4371-91',
      accountType: 'NH올원모임통장',
      openingBalance: 0,
      createdAt: DateTime(2026, 9, 18),
    );

    await tester.pumpWidget(
      _homeHost(
        NativeHomeView(
          scrollController: scrollController,
          benefitsKey: GlobalKey(),
          assetsKey: GlobalKey(),
          accountName: 'BUI PHUONG',
          account: account,
          balanceLabel: '0원',
          netAssetsLabel: '0원',
          spendingLabel: '0원',
          scheduledLabel: '0원',
          hideAmounts: false,
          largeText: false,
          nhSelected: true,
          onAccountTap: () {},
          onToggleLargeText: () {},
          onMenuTap: () {},
          onSelectNh: () {},
          onSelectOther: () {},
          onLimitRelease: () {},
          onOpenDetails: () {},
          onTransfer: () {},
          onCopyAccount: () {},
          onToggleHide: () {},
          onAccounts: () {},
          onAllAccounts: () {},
          onScrollToAssets: () {},
        ),
      ),
    );
    await _precache(tester, _homeAssets);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/preview_15_home_comparison.png'),
    );
  });

  testWidgets('export limit release top and scrolled checkpoints', (
    tester,
  ) async {
    _configureMockupViewport(tester);

    await tester.pumpWidget(
      _homeHost(const LimitReleaseScreen(key: ValueKey('limit-release-top'))),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/preview_7_limit_release_top.png'),
    );

    await tester.pumpWidget(
      _homeHost(
        const LimitReleaseScreen(
          key: ValueKey('limit-release-scrolled'),
          initialScrollOffset: 175,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/preview_8_limit_release_scrolled.png'),
    );
  });

  testWidgets('export transaction history top and scrolled checkpoints', (
    tester,
  ) async {
    _configureMockupViewport(tester);
    final store = await _transactionHistoryStore();
    final auth = AuthService();
    DateTime referenceNow() => DateTime(2026, 9, 18, 11, 40);

    await tester.pumpWidget(
      _homeHost(
        AccountDetailsScreen(
          key: const ValueKey('transaction-history-top'),
          auth: auth,
          dataStore: store,
          nowProvider: referenceNow,
        ),
      ),
    );
    await _precache(tester, const ['assets/images/transaction_tlj_cakes.jpg']);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/preview_9_transaction_history_top.png'),
    );

    await tester.pumpWidget(
      _homeHost(
        AccountDetailsScreen(
          key: const ValueKey('transaction-history-scrolled'),
          auth: auth,
          dataStore: store,
          initialScrollOffset: 380,
          nowProvider: referenceNow,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/preview_10_transaction_history_scrolled.png'),
    );

    await tester.pumpWidget(
      _homeHost(
        AccountDetailsScreen(
          key: const ValueKey('transaction-history-filter'),
          auth: auth,
          dataStore: store,
          nowProvider: referenceNow,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-history-filter')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/preview_9a_transaction_history_filter.png'),
    );

    await tester.tap(find.byKey(const Key('history-month-field')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/preview_9b_transaction_history_month_picker.png',
      ),
    );
  });

  testWidgets('export transfer recipient and institution picker checkpoints', (
    tester,
  ) async {
    _configureMockupViewport(tester);
    final store = AppDataStore.inMemory(withMockData: false);

    await tester.pumpWidget(
      _homeHost(
        TransferRecipientScreen(
          key: const ValueKey('transfer-recipient'),
          dataStore: store,
        ),
      ),
    );
    await _precache(tester, BankCatalog.logoAssets);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile('goldens/preview_11_transfer_recipient.png'),
    );

    await tester.tap(find.byKey(const Key('transfer-recipient-tab-자주')));
    await tester.pumpAndSettle();
    await _settleAssetImages(tester);
    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile('goldens/preview_11a_transfer_recipient_frequent.png'),
    );

    await tester.pumpWidget(
      _homeHost(
        TransferRecipientScreen(
          key: const ValueKey('transfer-bank-picker-top'),
          dataStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('transfer-bank-selector')));
    await tester.pumpAndSettle();
    await _settleAssetImages(tester);
    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile('goldens/preview_12_bank_picker_top.png'),
    );

    await tester.pumpWidget(
      _homeHost(
        TransferRecipientScreen(
          key: const ValueKey('transfer-bank-picker-scrolled'),
          dataStore: store,
          initialBankPickerScrollOffset: 470,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('transfer-bank-selector')));
    await tester.pumpAndSettle();
    await _settleAssetImages(tester);
    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile('goldens/preview_13_bank_picker_scrolled.png'),
    );

    await tester.pumpWidget(
      _homeHost(
        TransferRecipientScreen(
          key: const ValueKey('transfer-securities-picker'),
          dataStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('transfer-bank-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bank-tab-증권사')));
    await tester.pumpAndSettle();
    await _settleAssetImages(tester);
    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile('goldens/preview_14_securities_picker.png'),
    );
  });

  testWidgets('export selected-bank recipient entry checkpoints', (
    tester,
  ) async {
    _configureMockupViewport(tester);
    final store = AppDataStore.inMemory(withMockData: false);
    addTearDown(store.dispose);
    await store.createAccount(
      bankCode: '농협',
      bankDisplayName: 'NH농협은행',
      ownerName: 'BUI PHUONG',
      accountNumber: '3022180437191',
      accountType: 'NH올원모임통장',
      openingBalance: 20000,
    );
    final recipient = await store.createRecipient(
      displayName: 'TRINHTRUNG',
      bankCode: '신한',
      accountNumber: '110628103680',
    );
    await store.saveRecipient(recipient.copyWith(favorite: true));

    await tester.pumpWidget(
      _homeHost(
        TransferRecipientScreen(
          key: const ValueKey('transfer-selected-bank'),
          dataStore: store,
        ),
      ),
    );
    await _precache(tester, BankCatalog.logoAssets);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('transfer-bank-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NH농협'));
    await tester.pumpAndSettle();
    await _settleAssetImages(tester);

    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile(
        'goldens/preview_11b_transfer_recipient_selected_bank.png',
      ),
    );

    await tester.enterText(
      find.byKey(const Key('transfer-account-input')),
      '122222',
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile(
        'goldens/preview_11c_transfer_recipient_valid_account.png',
      ),
    );
  });

  testWidgets('export saved-recipient amount and PIN checkpoints', (
    tester,
  ) async {
    _configureMockupViewport(tester);
    final store = AppDataStore.inMemory(withMockData: false);
    addTearDown(store.dispose);
    await store.createAccount(
      bankCode: '농협',
      bankDisplayName: 'NH농협은행',
      ownerName: 'BUI PHUONG',
      accountNumber: '3022180437191',
      accountType: 'NH올원모임통장',
      openingBalance: 20000,
    );
    await store.createRecipient(
      displayName: 'TRINHTRUNG',
      bankCode: '신한',
      accountNumber: '110628103680',
    );

    await tester.pumpWidget(
      _host(
        TransferRecipientScreen(
          key: const ValueKey('transfer-saved-recipient-flow'),
          dataStore: store,
          auth: _VerifiedTransferAuth(),
          initialPinKeys: const [
            '1',
            '2',
            '3',
            '4',
            '5',
            '6',
            '7',
            '8',
            '9',
            '0',
          ],
        ),
      ),
    );
    await _precache(tester, const [
      'assets/images/ref_transfer_pin_symbol_left.jpg',
      'assets/images/ref_transfer_pin_symbol_right.jpg',
      'assets/images/ref_transfer_pin_rearrange.png',
      'assets/images/ref_transfer_pin_delete.png',
      'assets/images/ref_transfer_pin_phone.png',
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recipient-TRINHTRUNG')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile('goldens/preview_11d_transfer_amount_empty.png'),
    );

    for (final digit in ['5', '0', '0', '0']) {
      await tester.tap(find.byKey(Key('amount-key-$digit')));
      await tester.pump();
    }
    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile('goldens/preview_11e_transfer_amount_5000.png'),
    );

    await tester.tap(find.byKey(const Key('transfer-next')));
    await tester.pumpAndSettle();
    await _settleAssetImages(tester);
    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile('goldens/preview_11f_transfer_pin.png'),
    );

    for (final digit in ['1', '2']) {
      await tester.tap(find.byKey(Key('transfer-pin-key-$digit')));
      await tester.pump();
    }
    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile('goldens/preview_11f1_transfer_pin_2_digits.png'),
    );
    await tester.tap(find.byKey(const Key('transfer-pin-delete')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('transfer-pin-delete')));
    await tester.pump();

    for (final digit in ['9', '9', '9', '9']) {
      await tester.tap(find.byKey(Key('transfer-pin-key-$digit')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pumpAndSettle();
    await _settleAssetImages(tester);
    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile('goldens/preview_11g_transfer_pin_failure.png'),
    );
  });

  testWidgets('export transfer warning and confirmation checkpoints', (
    tester,
  ) async {
    _configureMockupViewport(tester);
    final auth = _VerifiedTransferAuth();

    final store = AppDataStore.inMemory(withMockData: false);
    addTearDown(store.dispose);
    await store.createAccount(
      bankCode: '농협',
      bankDisplayName: 'NH농협은행',
      ownerName: 'BUI PHUONG THANH',
      accountNumber: '3022180437191',
      accountType: 'NH올원모임통장',
      openingBalance: 20000,
    );
    await store.createRecipient(
      displayName: 'TRINHTRUNG',
      bankCode: '신한',
      accountNumber: '110628103680',
      showTransferWarning: true,
    );

    await tester.pumpWidget(
      _host(
        TransferRecipientScreen(
          key: const ValueKey('transfer-warning-flow'),
          dataStore: store,
          auth: auth,
          initialPinKeys: const [
            '1',
            '2',
            '3',
            '4',
            '5',
            '6',
            '7',
            '8',
            '9',
            '0',
          ],
        ),
      ),
    );
    await _precache(tester, <String>[
      ...BankCatalog.logoAssets,
      'assets/images/ref_transfer_pin_symbol_left.jpg',
      'assets/images/ref_transfer_pin_symbol_right.jpg',
      'assets/images/ref_transfer_pin_rearrange.png',
      'assets/images/ref_transfer_pin_delete.png',
      'assets/images/ref_transfer_pin_phone.png',
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recipient-TRINHTRUNG')));
    await tester.pumpAndSettle();
    for (final digit in ['5', '0', '0', '0']) {
      await tester.tap(find.byKey(Key('amount-key-$digit')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('transfer-next')));
    await tester.pumpAndSettle();
    for (final digit in ['1', '2', '3', '4']) {
      await tester.tap(find.byKey(Key('transfer-pin-key-$digit')));
      await tester.pump();
    }
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('transfer-warning-popup')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await _settleAssetImages(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/preview_11h_transfer_warning.png'),
    );

    await tester.tap(find.byKey(const Key('transfer-warning-confirm')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('transfer-review-confirm')),
    );
    await _pumpUntilGone(
      tester,
      find.byKey(const Key('transfer-loading-warningToConfirmation')),
    );
    await _settleAssetImages(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/preview_11i_transfer_confirmation.png'),
    );
  });

  testWidgets('export four transfer Loading 2 checkpoints', (tester) async {
    _configureMockupViewport(tester);
    final auth = _VerifiedTransferAuth();
    final store = AppDataStore.inMemory(withMockData: false);
    addTearDown(store.dispose);
    await store.createAccount(
      bankCode: '농협',
      bankDisplayName: 'NH농협은행',
      ownerName: 'BUI PHUONG THANH',
      accountNumber: '3022180437191',
      accountType: 'NH올원모임통장',
      openingBalance: 20000,
    );
    await store.createRecipient(
      displayName: 'TRINHTRUNG',
      bankCode: '신한',
      accountNumber: '110628103680',
      showTransferWarning: true,
    );

    await tester.pumpWidget(
      _homeHost(HomeScreen(auth: auth, dataStore: store)),
    );
    await _precache(tester, <String>[
      ..._homeAssets,
      ...BankCatalog.logoAssets,
      'assets/images/ref_transfer_pin_symbol_left.jpg',
      'assets/images/ref_transfer_pin_symbol_right.jpg',
      'assets/images/ref_transfer_pin_rearrange.png',
      'assets/images/ref_transfer_pin_delete.png',
      'assets/images/ref_transfer_failure_brand.jpg',
    ]);
    await tester.pumpAndSettle();

    Future<void> pumpUntil(Key key) async {
      for (var attempt = 0; attempt < 30; attempt++) {
        if (find.byKey(key).evaluate().isNotEmpty) return;
        await tester.pump(const Duration(milliseconds: 16));
      }
      fail('Expected $key to appear.');
    }

    Future<void> captureLoading(
      Key key,
      String golden, {
      Duration advance = Duration.zero,
    }) async {
      await pumpUntil(key);
      if (advance > Duration.zero) await tester.pump(advance);
      await _settleAssetImages(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile(golden));
      await tester.pumpAndSettle();
      await tester.pump();
    }

    await tester.tap(find.widgetWithText(OutlinedButton, '이체'));
    await captureLoading(
      const Key('transfer-loading-homeToRecipient'),
      'goldens/preview_11k_loading_home_to_recipient.png',
    );

    await tester.tap(find.byKey(const Key('recipient-TRINHTRUNG')));
    await tester.pumpAndSettle();
    for (final digit in ['5', '0', '0', '0']) {
      await tester.tap(find.byKey(Key('amount-key-$digit')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('transfer-next')));
    await tester.pumpAndSettle();
    for (final digit in ['1', '2', '3']) {
      await tester.tap(find.byKey(Key('transfer-pin-key-$digit')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('transfer-pin-key-4')));
    await tester.pump(const Duration(milliseconds: 180));
    await captureLoading(
      const Key('transfer-loading-pinToWarning'),
      'goldens/preview_11l_loading_pin_to_warning.png',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('transfer-warning-confirm')));
    await captureLoading(
      const Key('transfer-loading-warningToConfirmation'),
      'goldens/preview_11m_loading_warning_to_confirmation.png',
      advance: const Duration(milliseconds: 100),
    );

    await tester.tap(find.byKey(const Key('transfer-review-confirm')));
    await captureLoading(
      const Key('transfer-loading-confirmationToResult'),
      'goldens/preview_11n_loading_confirmation_to_result.png',
    );
  });

  testWidgets('export transfer failure popup on home', (tester) async {
    _configureMockupViewport(tester);
    final store = AppDataStore.inMemory();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      _homeHost(HomeScreen(auth: _VerifiedTransferAuth(), dataStore: store)),
    );
    await _precache(tester, <String>[
      ..._homeAssets,
      'assets/images/ref_transfer_failure_brand.jpg',
    ]);
    await tester.pumpAndSettle();

    final popupFuture = showTransferFailurePopup(
      tester.element(find.byType(HomeScreen)),
    );
    await tester.pumpAndSettle();
    await _settleAssetImages(tester);
    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile('goldens/preview_11j_transfer_failure_home.png'),
    );

    await tester.tap(find.byKey(const Key('transfer-failure-home-confirm')));
    await tester.pumpAndSettle();
    await popupFuture;
  });
}

Future<AppDataStore> _transactionHistoryStore() async {
  final store = AppDataStore.inMemory(withMockData: false);
  final account = BankAccount(
    id: 'history-account',
    bankCode: '농협',
    bankDisplayName: 'NH농협은행',
    ownerName: 'BUI PHUONG',
    accountNumber: '302-2180-4371-91',
    accountType: 'NH올원모임통장',
    openingBalance: 0,
    createdAt: DateTime(2026, 8, 18),
  );
  await store.saveAccount(account);
  await store.saveTransaction(
    LedgerTransaction(
      id: 'history-deposit',
      accountId: account.id,
      title: 'TRINHTRUNG',
      signedAmount: 5000,
      occurredAt: DateTime(2026, 9, 17, 14, 57, 14),
      channel: '',
      displayOrder: 1,
    ),
  );
  await store.saveTransaction(
    LedgerTransaction(
      id: 'history-withdrawal',
      accountId: account.id,
      title: 'TRINHTRUNG',
      signedAmount: -5000,
      occurredAt: DateTime(2026, 9, 17, 15, 0, 9),
      channel: '올원이체',
      displayOrder: 0,
    ),
  );
  return store;
}

const _homeAssets = <String>[
  'assets/images/home_event_gift.png',
  'assets/images/ref_header_actions.png',
  'assets/images/ref_daily_point.png',
  'assets/images/ref_moim_people_alpha.png',
  'assets/images/ref_lifestyle_0.png',
  'assets/images/ref_lifestyle_1.png',
  'assets/images/ref_shortcut_0.png',
  'assets/images/ref_shortcut_1.png',
  'assets/images/ref_shortcut_2.png',
  'assets/images/ref_shortcut_3.png',
  'assets/images/ref_shortcut_4.png',
  'assets/images/ref_shortcut_5.png',
  'assets/images/ref_shortcut_6.png',
  'assets/images/ref_shortcut_7.png',
  'assets/images/ref_spending_0.png',
  'assets/images/ref_spending_1.png',
  'assets/images/ref_asset_0.png',
  'assets/images/ref_asset_1.png',
  'assets/images/ref_asset_2.png',
  'assets/images/ref_asset_3.png',
  'assets/images/ref_group_0.png',
  'assets/images/ref_group_1.png',
  'assets/images/ref_group_2.png',
  'assets/images/ref_group_3.png',
  'assets/images/ref_group_4.png',
  'assets/images/ref_group_5.png',
  'assets/images/ref_nav_home.png',
  'assets/images/ref_nav_products.png',
  'assets/images/ref_nav_my.png',
  'assets/images/ref_nav_point.png',
  'assets/images/ref_nav_gift.png',
];

Future<void> _precache(WidgetTester tester, List<String> assets) async {
  final context = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    for (final asset in assets) {
      final ImageProvider provider = asset.contains('/logo_')
          ? ResizeImage(AssetImage(asset), width: 256, height: 256)
          : AssetImage(asset);
      await precacheImage(provider, context);
    }
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> _settleAssetImages(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump();
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 180,
}) async {
  for (var frame = 0; frame < maxFrames && finder.evaluate().isEmpty; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(finder, findsOneWidget);
}

Future<void> _pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 180,
}) async {
  for (
    var frame = 0;
    frame < maxFrames && finder.evaluate().isNotEmpty;
    frame++
  ) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(finder, findsNothing);
}

Widget _host(Widget home) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildAllOneTheme(),
    home: home,
  );
}

class _VerifiedTransferAuth extends AuthService {
  @override
  bool get isSignedIn => true;

  @override
  Future<PinStatus> pinStatus(PinPurpose purpose) async =>
      const PinStatus(configured: true, failedAttempts: 0);

  @override
  Future<PinVerificationResult> verifyPin(
    PinPurpose purpose,
    String pin,
  ) async => PinVerificationResult(
    configured: true,
    failedAttempts: pin == '1234' ? 0 : 1,
    matched: pin == '1234',
  );
}

Widget _homeHost(Widget home) {
  return MaterialApp(
    key: ValueKey(home.key),
    debugShowCheckedModeBanner: false,
    theme: buildAllOneTheme(),
    home: Builder(
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        const systemInsets = EdgeInsets.only(top: 54, bottom: 68);
        return MediaQuery(
          data: mediaQuery.copyWith(
            padding: systemInsets,
            viewPadding: systemInsets,
          ),
          child: home,
        );
      },
    ),
  );
}

void _configureMockupViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(588, 1280);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}
