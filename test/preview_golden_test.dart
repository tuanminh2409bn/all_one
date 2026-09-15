import 'package:all_one/core/app_data.dart';
import 'package:all_one/core/auth_service.dart';
import 'package:all_one/core/bank_catalog.dart';
import 'package:all_one/ui/certificate_login_screen.dart';
import 'package:all_one/ui/home_screen.dart';
import 'package:all_one/ui/limit_release_screen.dart';
import 'package:all_one/ui/account_details_screen.dart';
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
    DateTime referenceNow() => DateTime(2026, 9, 13, 11, 40);

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
    await _precache(
      tester,
      BankCatalog.entries
          .map((entry) => 'assets/images/${entry.assetName}')
          .toSet()
          .toList(),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile('goldens/preview_11_transfer_recipient.png'),
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
    createdAt: DateTime(2026, 8, 13),
  );
  await store.saveAccount(account);
  await store.saveTransaction(
    LedgerTransaction(
      id: 'history-deposit',
      accountId: account.id,
      title: 'BUIPHƯƠNG',
      signedAmount: 21000,
      occurredAt: DateTime(2026, 9, 9, 9, 42, 6),
      channel: '모바일',
      displayOrder: 2,
    ),
  );
  await store.saveTransaction(
    LedgerTransaction(
      id: 'history-savings',
      accountId: account.id,
      title: '예적금신규',
      signedAmount: -20000,
      occurredAt: DateTime(2026, 9, 9, 9, 43, 23),
      channel: '모바일',
      displayOrder: 1,
    ),
  );
  await store.saveTransaction(
    LedgerTransaction(
      id: 'history-card',
      accountId: account.id,
      title: '현금카드발급',
      signedAmount: -1000,
      occurredAt: DateTime(2026, 9, 9, 9, 48, 46),
      channel: '모바일',
      displayOrder: 0,
    ),
  );
  return store;
}

const _homeAssets = <String>[
  'assets/images/home_event_gift.png',
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
      await precacheImage(AssetImage(asset), context);
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

Widget _host(Widget home) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansKR',
      fontFamilyFallback: const [
        'Apple SD Gothic Neo',
        'Noto Sans KR',
        'Noto Sans',
        'Roboto',
      ],
    ),
    home: home,
  );
}

Widget _homeHost(Widget home) {
  return MaterialApp(
    key: ValueKey(home.key),
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansKR',
      fontFamilyFallback: const [
        'Apple SD Gothic Neo',
        'Noto Sans KR',
        'Noto Sans',
        'Roboto',
      ],
    ),
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
