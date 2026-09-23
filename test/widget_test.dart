import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:all_one/core/app_data.dart';
import 'package:all_one/core/auth_service.dart';
import 'package:all_one/core/bank_catalog.dart';
import 'package:all_one/core/pin_security.dart';
import 'package:all_one/ui/account_details_screen.dart';
import 'package:all_one/ui/app_loading_transition.dart';
import 'package:all_one/ui/app_theme.dart';
import 'package:all_one/ui/bank_logo.dart';
import 'package:all_one/ui/certificate_login_screen.dart';
import 'package:all_one/ui/home_screen.dart';
import 'package:all_one/ui/limit_release_screen.dart';
import 'package:all_one/ui/pin_screen.dart';
import 'package:all_one/ui/splash_screen.dart';
import 'package:all_one/ui/transfer_loading_overlay.dart';
import 'package:all_one/ui/transfer_recipient_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('bank logos use the new rounded-square image assets', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BankLogo(bankCode: '신한', size: 50)),
      ),
    );

    final frame = tester.widget<ClipRRect>(
      find.byKey(const Key('bank-logo-frame-신한')),
    );
    final image = tester.widget<Image>(find.byType(Image));
    final radius = frame.borderRadius as BorderRadius;
    expect(radius.topLeft.x, closeTo(14, .001));
    expect(radius.topLeft.y, closeTo(14, .001));
    expect(image.image, isA<ResizeImage>());
    expect(BankCatalog.logoAsset('신한'), endsWith('logo_shinhan.png'));
    expect(tester.getSize(find.byType(BankLogo)), const Size.square(50));
  });

  test('default Korean font is a static face on every platform', () async {
    final data = await rootBundle.load('assets/fonts/NotoSansKR-Medium.otf');
    final tableCount = data.getUint16(4);
    final tableTags = <String>{};
    for (var index = 0; index < tableCount; index++) {
      final recordOffset = 12 + (index * 16);
      final tag = String.fromCharCodes([
        for (var byte = 0; byte < 4; byte++) data.getUint8(recordOffset + byte),
      ]);
      tableTags.add(tag);
    }
    expect(tableTags, contains('CFF '));
    expect(tableTags, isNot(contains('fvar')));
  });

  test('app theme renders normal copy at w500 or above in black', () {
    final theme = buildAllOneTheme();
    final styles = <TextStyle?>[
      theme.textTheme.bodyLarge,
      theme.textTheme.bodyMedium,
      theme.textTheme.bodySmall,
      theme.textTheme.titleLarge,
      theme.textTheme.titleMedium,
      theme.textTheme.titleSmall,
      theme.textTheme.labelLarge,
      theme.textTheme.labelMedium,
      theme.textTheme.labelSmall,
    ];
    for (final style in styles) {
      expect(style?.fontWeight?.value, greaterThanOrEqualTo(500));
      expect(style?.color, Colors.black);
    }
    expect(theme.colorScheme.onSurface, Colors.black);
    expect(theme.colorScheme.onSurfaceVariant, Colors.black);
    expect(theme.disabledColor, Colors.black);
    expect(theme.inputDecorationTheme.labelStyle?.color, Colors.black);
    expect(theme.inputDecorationTheme.hintStyle?.color, Colors.black);
  });

  test(
    'original loading asset preserves the extracted video animation',
    () async {
      final data = await rootBundle.load('assets/images/loading_original.png');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final codec = await ui.instantiateImageCodec(bytes);

      expect(codec.frameCount, 20);
      final firstFrame = await codec.getNextFrame();
      expect(firstFrame.duration, const Duration(milliseconds: 50));
      expect(firstFrame.image.width, 288);
      expect(firstFrame.image.height, 288);

      firstFrame.image.dispose();
      codec.dispose();
    },
  );

  test('Home benefit strip loops the video frames', () async {
    final data = await rootBundle.load(
      'assets/images/home_daily_benefit_loop.png',
    );
    expect(
      String.fromCharCodes([
        for (var offset = 37; offset < 41; offset++) data.getUint8(offset),
      ]),
      'acTL',
    );
    expect(data.getUint32(41), 175);
    expect(data.getUint32(45), 0); // APNG repeats indefinitely.
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final codec = await ui.instantiateImageCodec(bytes);

    expect(codec.frameCount, 175);
    final firstFrame = await codec.getNextFrame();
    expect(firstFrame.duration, const Duration(milliseconds: 50));
    expect(firstFrame.image.width, 410);
    expect(firstFrame.image.height, 70);

    firstFrame.image.dispose();
    codec.dispose();
  });

  test(
    'certificate loading asset preserves the source-video cadence',
    () async {
      final data = await rootBundle.load(
        'assets/images/loading_certificate_to_pin.png',
      );
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final codec = await ui.instantiateImageCodec(bytes);

      expect(codec.frameCount, 36);
      const blankFrameIndices = {
        0,
        1,
        2,
        11,
        14,
        24,
        25,
        26,
        27,
        28,
        29,
        30,
        31,
        32,
        33,
        34,
        35,
      };
      var totalDuration = Duration.zero;
      for (var index = 0; index < codec.frameCount; index++) {
        final frame = await codec.getNextFrame();
        final expectedDuration = Duration(
          milliseconds: index % 3 == 2 ? 16 : 17,
        );
        expect(frame.duration, expectedDuration);
        totalDuration += frame.duration;
        expect(frame.image.width, 288);
        expect(frame.image.height, 288);
        final pixels = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        expect(pixels, isNotNull);
        final centerAlpha = pixels!.getUint8(((144 * 288) + 144) * 4 + 3);
        expect(
          centerAlpha == 0,
          blankFrameIndices.contains(index),
          reason: 'frame $index must match the source-video blink cadence',
        );
        frame.image.dispose();
      }
      expect(totalDuration, const Duration(milliseconds: 600));
      codec.dispose();
    },
  );

  testWidgets('entry flow starts at reference screen 6', (tester) async {
    _configureMockupViewport(tester);
    await tester.pumpWidget(
      MaterialApp(home: SplashScreen(auth: AuthService(), autoContinue: false)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('entry-screen-6')), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('entry-reference-assets/images/entry_6_splash.png'),
      ),
      findsOneWidget,
    );
    expect(find.byType(PinScreen), findsNothing);
  });

  testWidgets('certificate screen paints white behind the status bar', (
    tester,
  ) async {
    _configureMockupViewport(tester);
    tester.view.padding = const FakeViewPadding(top: 54);
    tester.view.viewPadding = const FakeViewPadding(top: 54);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    await tester.pumpWidget(
      _TestHost(
        home: CertificateLoginScreen(auth: AuthService(), autoContinue: false),
      ),
    );
    await tester.pumpAndSettle();

    final background = find.byKey(
      const Key('certificate-status-bar-background'),
    );
    expect(background, findsOneWidget);
    expect(tester.getTopLeft(background), Offset.zero);
    expect(tester.getSize(background).height, 54);
    expect(tester.widget<ColoredBox>(background).color, Colors.white);
  });

  testWidgets('screen 7 automatically loads screen 8, then PIN leads home', (
    tester,
  ) async {
    _configureMockupViewport(tester);
    await tester.pumpWidget(
      _TestHost(home: CertificateLoginScreen(auth: AuthService())),
    );
    await tester.pump();

    expect(find.byKey(const Key('certificate-login-button')), findsNothing);
    expect(find.byType(PinScreen), findsNothing);

    await tester.pump(const Duration(milliseconds: 750));
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.byType(PinScreen), findsOneWidget);
    expect(find.byKey(const Key('pin-entry-loading')), findsOneWidget);
    expect(find.byKey(const Key('pin-entry-loading-logo')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('pin-entry-loading-logo'))),
      const Size.square(72),
    );
    expect(
      find.byKey(const Key('pin-entry-loading-animation')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('pin-close')), findsNothing);

    await tester.pump(const Duration(milliseconds: 390));
    expect(find.byKey(const Key('pin-entry-loading')), findsNothing);

    for (final digit in [4, 7, 2, 6, 8, 5]) {
      await tester.tap(find.byKey(Key('app-pin-key-$digit')));
      await tester.pump(const Duration(milliseconds: 25));
    }
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(AppLoadingTransition), findsOneWidget);
    expect(find.byKey(const Key('app-loading-logo')), findsOneWidget);
    expect(find.byKey(const Key('app-loading-logo-animation')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('loading-certificate-backdrop')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 260));
    expect(find.byKey(const Key('app-loading-logo-animation')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1190));
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.byKey(const ValueKey('loading-home-backdrop')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(AppLoadingTransition), findsNothing);
  });

  testWidgets('PIN screen has no certificate back control', (tester) async {
    _configureMockupViewport(tester);
    await tester.pumpWidget(_TestHost(home: PinScreen(auth: AuthService())));
    await tester.pumpAndSettle();

    expect(find.byType(PinScreen), findsOneWidget);
    expect(find.byKey(const Key('pin-close')), findsNothing);
    expect(find.byKey(const Key('pin-close-cover')), findsOneWidget);
  });

  testWidgets('PIN shuffle preserves key artwork and aligns entered dots', (
    tester,
  ) async {
    _configureMockupViewport(tester);
    await tester.pumpWidget(_TestHost(home: PinScreen(auth: AuthService())));
    await tester.pumpAndSettle();

    List<Image> keypadLabels() => List.generate(
      10,
      (index) =>
          tester.widget<Image>(find.byKey(Key('app-pin-key-label-$index'))),
    );

    List<String> assetsOf(List<Image> labels) =>
        labels.map((label) => (label.image as AssetImage).assetName).toList();

    expect(find.byKey(const Key('app-pin-key-label-0')), findsNothing);
    final initialOrder = List.generate(
      10,
      (index) =>
          'assets/images/pin_digit_${[4, 7, 2, 6, 8, 5, 3, 9, 0, 1][index]}.png',
    );

    await tester.tap(find.byKey(const Key('app-pin-rearrange')));
    await tester.pump();

    final shuffledLabels = keypadLabels();
    final shuffledOrder = assetsOf(shuffledLabels);
    expect(shuffledOrder, isNot(initialOrder));
    expect(shuffledOrder.toSet(), initialOrder.toSet());

    await tester.tap(find.byKey(const Key('app-pin-key-4')));
    await tester.pump();
    final firstDot = find.byKey(const Key('app-pin-indicator-0'));
    expect(tester.getSize(firstDot).width, 52);
    expect(tester.getCenter(firstDot).dx, closeTo(191.58, 0.1));
  });

  testWidgets('unsigned home shows Korean login and mockup sections', (
    tester,
  ) async {
    _configureMockupViewport(tester);
    final auth = AuthService();
    await tester.pumpWidget(
      _TestHost(
        home: HomeScreen(
          auth: auth,
          dataStore: AppDataStore.inMemory(withMockData: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-account-name')), findsOneWidget);
    expect(find.text('로그인'), findsWidgets);
    expect(find.text('NH올원모임통장'), findsOneWidget);
    expect(find.text('거래내역'), findsOneWidget);
    expect(find.text('이체'), findsOneWidget);
    expect(find.text('오늘의 혜택'), findsOneWidget);
    expect(find.text('내 모임'), findsOneWidget);
    expect(find.text('내 소비'), findsOneWidget);
    expect(find.text('내 자산'), findsWidgets);
    expect(find.text('750,998원'), findsNWidgets(2));
    expect(find.text('NH금융그룹'), findsOneWidget);
    expect(find.text('홈 화면 설정'), findsOneWidget);
    expect(find.text('포인트쌓기'), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byKey(const Key('home-top-reference')), findsNothing);
    expect(find.byKey(const Key('home-bottom-navigation')), findsOneWidget);
    final benefitAnimation = tester.widget<Image>(
      find.byKey(const Key('home-daily-benefit-animation')),
    );
    expect(
      (benefitAnimation.image as AssetImage).assetName,
      'assets/images/home_daily_benefit_loop.png',
    );
    final accountLogo = find.byKey(const Key('home-account-logo'));
    expect(tester.getSize(accountLogo), const Size.square(48));
    expect(
      tester.widget<ClipRRect>(accountLogo).borderRadius,
      BorderRadius.circular(14),
    );
    expect(find.text('매일 포인트 용돈 받기'), findsNothing);
    expect(find.text('쓸수록 혜택받기'), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('home-fortune-chip'))),
      const Size(124, 55),
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('home-nav-home'))).dx,
      closeTo(75.6, 0.1),
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('home-nav-gift'))).dx,
      closeTo(512.4, 0.1),
    );
    final spendingTitleCenter = tester
        .getCenter(find.byKey(const ValueKey('home-data-title-내 소비')))
        .dy;
    expect(
      tester.getCenter(find.byKey(const ValueKey('home-data-date-내 소비'))).dy,
      closeTo(spendingTitleCenter, 2),
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('home-data-hide-내 소비'))).dy,
      closeTo(spendingTitleCenter, 2),
    );

    final navigationTop = tester.getTopLeft(
      find.byKey(const Key('home-bottom-navigation')),
    );
    await tester.drag(
      find.byKey(const Key('home-scroll')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('home-daily-benefit-animation')),
      findsOneWidget,
    );
    expect(find.text('쓸수록 혜택받기'), findsNothing);
    expect(find.byKey(const Key('home-bottom-navigation')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('home-bottom-navigation'))),
      navigationTop,
    );
  });

  testWidgets('home visibility action follows the final balance digit', (
    tester,
  ) async {
    _configureMockupViewport(tester);
    final store = AppDataStore.inMemory();
    addTearDown(store.dispose);
    await store.saveAccountWithCurrentBalance(store.accounts.first, 0);
    await tester.pumpWidget(
      _TestHost(
        home: HomeScreen(auth: AuthService(), dataStore: store),
      ),
    );
    await tester.pumpAndSettle();

    final balanceRect = tester.getRect(
      find.byKey(const Key('home-account-balance')),
    );
    final actionRect = tester.getRect(
      find.byKey(const Key('home-balance-visibility')),
    );
    expect(actionRect.left - balanceRect.right, closeTo(10, 0.01));

    await store.saveAccountWithCurrentBalance(store.accounts.first, 123456789);
    await tester.pumpAndSettle();

    final longBalanceRect = tester.getRect(
      find.byKey(const Key('home-account-balance')),
    );
    final movedActionRect = tester.getRect(
      find.byKey(const Key('home-balance-visibility')),
    );
    expect(longBalanceRect.left, balanceRect.left);
    expect(movedActionRect.left, greaterThan(actionRect.left));
    expect(movedActionRect.left - longBalanceRect.right, closeTo(10, 0.01));
  });

  testWidgets('limit release action opens a fixed-header scrollable guide', (
    tester,
  ) async {
    _configureMockupViewport(tester);
    await tester.pumpWidget(
      _TestHost(
        home: HomeScreen(
          auth: AuthService(),
          dataStore: AppDataStore.inMemory(withMockData: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, '한도해제'));
    await tester.pumpAndSettle();

    expect(find.byType(LimitReleaseScreen), findsOneWidget);
    expect(find.text('한도제한 해제(NH농협은행)'), findsOneWidget);
    expect(find.text('계좌 선택'), findsOneWidget);
    expect(find.text('NH올원모임통장'), findsOneWidget);
    expect(find.text('NH농협은행 302-2180-4371-91'), findsOneWidget);
    expect(find.text('알아두세요'), findsOneWidget);
    expect(find.byKey(const ValueKey('limit-release-info-0')), findsOneWidget);

    final title = find.byKey(const Key('limit-release-title'));
    final titleTop = tester.getTopLeft(title);
    await tester.drag(
      find.byKey(const Key('limit-release-scroll')),
      const Offset(0, -520),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const Key('limit-release-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(scrollable.position.pixels, greaterThan(100));
    expect(tester.getTopLeft(title), titleTop);
    expect(find.byKey(const ValueKey('limit-release-info-6')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('limit-release-info-6'))).dy,
      lessThan(1280),
    );

    await tester.tap(find.byKey(const Key('limit-release-back')));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('middle Home action shows Loading 2 before transaction history', (
    tester,
  ) async {
    _configureMockupViewport(tester);
    final store = AppDataStore.inMemory(withMockData: false);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      _TestHost(
        home: HomeScreen(auth: AuthService(), dataStore: store),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, '거래내역'));
    await tester.pump();

    const loadingKey = Key('home-loading-to-account-details');
    expect(find.byKey(loadingKey), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(AccountDetailsScreen), findsNothing);
    expect(
      tester
          .widget<ModalBarrier>(find.byKey(const Key('transfer-loading-scrim')))
          .color,
      const Color(0x7E000000),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('transfer-loading-logo'))),
      const Offset(234, 581),
    );
    expect(
      tester.getSize(find.byKey(const Key('transfer-loading-logo'))),
      const Size.square(120),
    );
    final image = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('transfer-loading-logo')),
        matching: find.byType(Image),
      ),
    );
    expect(
      (image.image as AssetImage).assetName,
      'assets/images/loading_original.png',
    );

    await tester.pump(const Duration(milliseconds: 1299));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(AccountDetailsScreen), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.byType(AccountDetailsScreen), findsOneWidget);
    expect(find.byKey(loadingKey), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 199));
    expect(find.byKey(loadingKey), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 17));
    await tester.pump();
    expect(find.byKey(loadingKey), findsNothing);
    expect(find.text('거래내역조회'), findsOneWidget);
  });

  testWidgets('middle account action opens sticky transaction history', (
    tester,
  ) async {
    _configureMockupViewport(tester);
    await tester.pumpWidget(
      _TestHost(
        home: HomeScreen(
          auth: AuthService(),
          dataStore: AppDataStore.inMemory(withMockData: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, '거래내역'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountDetailsScreen), findsOneWidget);
    expect(find.text('거래내역조회'), findsOneWidget);
    expect(find.text('NH올원모임통장'), findsOneWidget);
    expect(find.text('계좌관리'), findsOneWidget);
    expect(find.text('이체'), findsOneWidget);
    expect(
      find.byKey(const Key('account-transaction-promotion')),
      findsOneWidget,
    );
    expect(find.text('1개월 · 전체 · 최신순'), findsOneWidget);
    expect(find.text('거래내역이 없습니다.'), findsOneWidget);

    final title = find.byKey(const Key('account-details-title'));
    final accountType = find.byKey(const Key('account-type-text'));
    final accountNumber = find.byKey(const Key('account-number-text'));
    expect(tester.widget<Text>(title).style?.color, Colors.black);
    expect(tester.widget<Text>(accountType).style?.color, Colors.black);
    expect(tester.widget<Text>(accountNumber).style?.color, Colors.black);
    expect(
      tester.widget<Text>(find.text('1개월 · 전체 · 최신순')).style?.color,
      Colors.black,
    );
    expect(tester.widget<Text>(find.text('잔액 숨기기')).style?.color, Colors.black);
    expect(
      tester.widget<Text>(find.text('거래내역이 없습니다.')).style?.color,
      Colors.black,
    );
    final titleTop = tester.getTopLeft(title);
    final accountTypeTop = tester.getTopLeft(accountType);
    await tester.drag(
      find.byKey(const Key('account-details-scroll')),
      const Offset(0, -430),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const Key('account-details-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(scrollable.position.pixels, greaterThan(360));
    expect(tester.getTopLeft(title), titleTop);
    expect(tester.getTopLeft(accountType), accountTypeTop);
    expect(
      find.byKey(const Key('account-history-filter-collapsed')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('account-back')));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets(
    'transfer failure from transaction history is shown after returning home',
    (tester) async {
      _configureMockupViewport(tester);
      final store = AppDataStore.inMemory();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        _TestHost(
          home: HomeScreen(auth: AuthService(), dataStore: store),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, '거래내역'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account-transfer')));
      await tester.pumpAndSettle();
      expect(find.byType(TransferRecipientScreen), findsOneWidget);

      Navigator.of(
        tester.element(find.byType(TransferRecipientScreen)),
      ).pop(TransferFlowResult.failed);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byKey(const Key('transfer-failure-popup')), findsOneWidget);
    },
  );

  testWidgets('transaction timestamps keep native glyph proportions', (
    tester,
  ) async {
    _configureMockupViewport(tester);
    final store = AppDataStore.inMemory();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      _TestHost(
        home: AccountDetailsScreen(
          auth: AuthService(),
          dataStore: store,
          accountId: 'default-account',
          nowProvider: () => DateTime(2026, 8, 21),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final timestamp = find.byKey(
      const Key('account-transaction-time-seed-transaction-0'),
    );
    expect(timestamp, findsOneWidget);
    final text = tester.widget<Text>(timestamp);
    expect(text.style?.fontSize, 17);
    expect(text.style?.fontWeight, FontWeight.w500);
    expect(text.style?.color, Colors.black);
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const Key('account-transaction-balance-seed-transaction-0'),
            ),
          )
          .style
          ?.color,
      Colors.black,
    );
    expect(
      tester.widget<Text>(find.text('TRINHTRUNGMINH')).style?.color,
      Colors.black,
    );
  });

  testWidgets('transaction history filter matches the reference flow', (
    tester,
  ) async {
    _configureMockupViewport(tester);
    await tester.pumpWidget(
      _TestHost(
        home: AccountDetailsScreen(
          auth: AuthService(),
          dataStore: AppDataStore.inMemory(withMockData: false),
          nowProvider: () => DateTime(2026, 9, 18, 11, 40),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('account-history-filter')));
    await tester.pumpAndSettle();

    expect(find.text('조회 조건을 선택해 주세요'), findsOneWidget);
    expect(find.text('조회 기간'), findsOneWidget);
    expect(find.text('1주일'), findsOneWidget);
    expect(find.text('1개월'), findsOneWidget);
    expect(find.text('3개월'), findsOneWidget);
    expect(find.text('6개월'), findsOneWidget);
    expect(find.text('월별'), findsOneWidget);
    expect(find.text('기간선택'), findsOneWidget);
    expect(find.text('정렬 순서'), findsOneWidget);
    expect(find.text('조회 구분'), findsOneWidget);
    expect(find.text('신한 ATM'), findsNothing);
    expect(find.byKey(const Key('history-filter-apply')), findsOneWidget);

    await tester.tap(find.byKey(const Key('history-range-week')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history-start-date')), findsOneWidget);
    expect(find.byKey(const Key('history-end-date')), findsOneWidget);

    await tester.tap(find.byKey(const Key('history-period-monthly')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history-month-field')));
    await tester.pumpAndSettle();
    expect(find.text('연/월을 선택해 주세요'), findsOneWidget);
    expect(find.byKey(const Key('history-year-wheel')), findsOneWidget);
    expect(find.byKey(const Key('history-month-wheel')), findsOneWidget);
    expect(find.byKey(const Key('history-month-picker-apply')), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('history-month-wheel')),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history-month-picker-apply')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history-filter-apply')));
    await tester.pumpAndSettle();
    expect(find.text('조회시작날짜는 오늘날짜이거나 과거날짜이어야합니다.'), findsOneWidget);
    expect(
      find.byKey(const Key('history-filter-validation-confirm')),
      findsOneWidget,
    );
  });

  testWidgets('third account action opens recipient and institution picker', (
    tester,
  ) async {
    _configureMockupViewport(tester);
    await tester.pumpWidget(
      _TestHost(
        home: HomeScreen(
          auth: AuthService(),
          dataStore: AppDataStore.inMemory(withMockData: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, '이체'));
    await tester.pumpAndSettle();

    expect(find.byType(TransferRecipientScreen), findsOneWidget);
    expect(find.text('누구에게 보낼까요?'), findsOneWidget);
    expect(find.text('계좌번호를 입력해 주세요'), findsOneWidget);
    expect(find.text('은행을 선택해 주세요'), findsOneWidget);
    expect(find.text('최근 이체 내역이 없습니다.'), findsOneWidget);
    expect(find.byKey(const Key('transfer-cancel')), findsOneWidget);

    final accountInput = tester.widget<TextField>(
      find.byKey(const Key('transfer-account-input')),
    );
    expect(
      tester.getSize(find.byKey(const Key('transfer-account-input'))).height,
      79,
    );
    expect(
      accountInput.decoration?.contentPadding,
      const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
    );
    expect(accountInput.decoration?.constraints?.minHeight, 79);
    expect(accountInput.decoration?.constraints?.maxHeight, 79);
    final bankPlaceholder = tester.widget<Text>(find.text('은행을 선택해 주세요'));
    expect(bankPlaceholder.style?.fontWeight, FontWeight.w500);

    await tester.tap(find.byKey(const Key('transfer-recipient-tab-자주')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('transfer-favorite-category')), findsOneWidget);
    expect(find.byKey(const Key('transfer-favorite-search')), findsOneWidget);
    expect(
      find.byKey(const Key('transfer-favorite-search-icon')),
      findsOneWidget,
    );
    expect(find.text('자주쓰는 계좌/연락처 등록'), findsOneWidget);
    expect(find.text('NH스마트뱅킹에서 정보를 가져올 수 있어요.'), findsOneWidget);
    expect(find.text('등록된 계좌가 없습니다.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('transfer-favorite-hint-close')));
    await tester.pumpAndSettle();
    expect(find.text('NH스마트뱅킹에서 정보를 가져올 수 있어요.'), findsNothing);

    await tester.tap(find.byKey(const Key('transfer-bank-selector')));
    await tester.pumpAndSettle();

    expect(find.text('은행/증권사 선택'), findsOneWidget);
    expect(find.text('NH농협'), findsOneWidget);
    expect(find.text('국민은행'), findsOneWidget);
    expect(find.byKey(const Key('bank-selector-list-banks')), findsOneWidget);
    expect(
      tester.getCenter(find.text('NH농협')).dy,
      closeTo(tester.getCenter(find.text('국민은행')).dy, 1),
    );

    final pickerTitle = find.text('은행/증권사 선택');
    final pickerTitleTop = tester.getTopLeft(pickerTitle);
    await tester.drag(
      find.byKey(const Key('bank-selector-list-banks')),
      const Offset(0, -470),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(pickerTitle), pickerTitleTop);
    expect(find.text('지방세입'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bank-selector-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('transfer-bank-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bank-tab-증권사')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('bank-selector-list-securities')),
      findsOneWidget,
    );
    expect(find.text('NH투자증권'), findsOneWidget);
    expect(find.text('교보증권'), findsOneWidget);
    expect(find.text('BNK증권'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bank-selector-close')));
    await tester.pumpAndSettle();
    expect(find.text('누구에게 보낼까요?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('transfer-back')));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets(
    'recipient entry matches selected-bank validation and favorite states',
    (tester) async {
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
        _TestHost(home: TransferRecipientScreen(dataStore: store)),
      );
      await tester.pumpAndSettle();

      FilledButton nextButton() =>
          tester.widget<FilledButton>(find.byKey(const Key('transfer-next')));

      expect(nextButton().onPressed, isNull);
      expect(find.byKey(const Key('favorite-star-selected')), findsOneWidget);
      expect(find.text('신한은행 110628103680'), findsOneWidget);
      final recipientBankAccount = tester.widget<Text>(
        find.byKey(const Key('recipient-bank-account')),
      );
      expect(recipientBankAccount.style?.fontSize, 20);
      expect(recipientBankAccount.style?.fontWeight, FontWeight.w500);
      expect(recipientBankAccount.style?.color, Colors.black);
      expect(
        tester
            .widget<BankLogo>(find.byKey(const Key('recipient-bank-logo')))
            .size,
        62,
      );
      expect(
        find.byKey(const Key('transfer-recipient-manage-link')),
        findsOneWidget,
      );
      final recentTab = find.byKey(const Key('transfer-recipient-tab-연락처'));
      final manageLink = find.byKey(
        const Key('transfer-recipient-manage-link'),
      );
      final recentRow = find.byKey(const Key('recipient-TRINHTRUNG'));
      expect(tester.getBottomLeft(recentTab).dy, 749);
      expect(tester.getTopLeft(manageLink).dy, 787);
      expect(tester.getTopLeft(recentRow).dy, 826);
      await tester.tap(find.byKey(Key('recipient-favorite-${recipient.id}')));
      await tester.pumpAndSettle();
      expect(store.recipients.single.favorite, isFalse);
      expect(manageLink, findsNothing);
      expect(tester.getTopLeft(recentRow).dy, 766);

      await tester.tap(find.byKey(Key('recipient-favorite-${recipient.id}')));
      await tester.pumpAndSettle();
      expect(store.recipients.single.favorite, isTrue);
      expect(manageLink, findsOneWidget);
      expect(tester.getTopLeft(recentRow).dy, 826);

      await tester.tap(find.byKey(const Key('transfer-bank-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('NH농협'));
      await tester.pumpAndSettle();
      expect(tester.getBottomLeft(recentTab).dy, 689);
      expect(tester.getTopLeft(manageLink).dy, 727);
      expect(tester.getTopLeft(recentRow).dy, 766);

      expect(
        find.byKey(const Key('transfer-selected-bank-logo')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<BankLogo>(
              find.byKey(const Key('transfer-selected-bank-logo')),
            )
            .size,
        46,
      );
      final selectedBankLabel = tester.widget<Text>(
        find.byKey(const Key('transfer-selected-bank-label')),
      );
      expect(selectedBankLabel.style?.fontWeight, FontWeight.w500);
      expect(find.text('계좌번호를 입력하면 은행을 조회해 드릴게요'), findsNothing);
      expect(find.text('NH농협'), findsOneWidget);
      expect(nextButton().onPressed, isNull);
      expect(tester.getTopLeft(find.byKey(const Key('transfer-next'))).dy, 497);

      await tester.enterText(
        find.byKey(const Key('transfer-account-input')),
        '12345',
      );
      await tester.pump();
      expect(nextButton().onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('transfer-account-input')),
        '123456',
      );
      await tester.pump();
      expect(nextButton().onPressed, isNotNull);
      expect(
        nextButton().style?.backgroundColor?.resolve(<WidgetState>{}),
        const Color(0xFF1F9A3F),
      );
      final nextLabel = tester.widget<Text>(find.text('다음'));
      expect(nextLabel.style?.color, Colors.white);

      await tester.enterText(
        find.byKey(const Key('transfer-account-input')),
        '123456789012345678901',
      );
      await tester.pump();
      final accountInput = tester.widget<TextField>(
        find.byKey(const Key('transfer-account-input')),
      );
      expect(accountInput.controller?.text, '12345678901234567890');
      expect(nextButton().onPressed, isNotNull);

      await tester.tap(find.byKey(Key('recipient-favorite-${recipient.id}')));
      await tester.pumpAndSettle();
      expect(store.recipients.single.favorite, isFalse);
      expect(find.byKey(const Key('favorite-star-idle')), findsOneWidget);
      expect(manageLink, findsNothing);
      expect(tester.getTopLeft(recentRow).dy, 706);
    },
  );

  testWidgets('amount source card shows the selected account live balance', (
    tester,
  ) async {
    _configureMockupViewport(tester);
    final store = AppDataStore.inMemory(withMockData: false);
    addTearDown(store.dispose);
    final firstAccount = await store.createAccount(
      bankCode: '농협',
      bankDisplayName: 'NH농협은행',
      ownerName: 'BUI PHUONG',
      accountNumber: '3022180437191',
      accountType: 'NH올원모임통장',
      openingBalance: 20000,
    );
    await store.createTransaction(
      accountId: firstAccount.id,
      title: '추가 입금',
      signedAmount: 5000,
      occurredAt: DateTime(2026, 9, 23),
      channel: '모바일',
    );
    final secondAccount = await store.createAccount(
      bankCode: '신한',
      bankDisplayName: '신한은행',
      ownerName: 'BUI PHUONG',
      accountNumber: '110123456789',
      accountType: '입출금통장',
      openingBalance: 40000,
    );
    await store.createRecipient(
      displayName: 'TRINHTRUNG',
      bankCode: '신한',
      accountNumber: '110628103680',
    );

    await tester.pumpWidget(
      _TestHost(home: TransferRecipientScreen(dataStore: store)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recipient-TRINHTRUNG')));
    await tester.pumpAndSettle();

    String displayedBalance() => tester
        .widget<Text>(find.byKey(const Key('amount-source-card-value')))
        .data!;
    expect(displayedBalance(), '25,000원');

    for (final digit in ['5', '0', '0', '0']) {
      await tester.tap(find.byKey(Key('amount-key-$digit')));
      await tester.pump();
    }
    expect(
      tester.widget<Text>(find.byKey(const Key('amount-display'))).data,
      '5,000원',
    );
    expect(displayedBalance(), '25,000원');

    await tester.tap(find.byKey(const Key('source-account-selector')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('source-account-option-신한은행-110123456789')),
    );
    await tester.pumpAndSettle();
    expect(displayedBalance(), '40,000원');

    await store.saveAccountWithCurrentBalance(secondAccount, 32000);
    await tester.pumpAndSettle();
    expect(displayedBalance(), '32,000원');
  });

  testWidgets('signed-in wrong PIN attempts match the reference flow', (
    tester,
  ) async {
    const recipientGreen = Color(0xFF1F9A3F);
    _configureMockupViewport(tester);
    tester.view.padding = const FakeViewPadding(bottom: 68);
    tester.view.viewPadding = const FakeViewPadding(bottom: 68);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    final store = AppDataStore.inMemory(withMockData: false);
    final auth = _CountingTransferAuth();
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
      _TestHost(
        home: TransferRecipientScreen(
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
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('recipient-TRINHTRUNG')));
    await tester.pumpAndSettle();

    FilledButton nextButton() =>
        tester.widget<FilledButton>(find.byKey(const Key('transfer-next')));

    const safeBottom = 1280 - 68;
    expect(find.text('TRINHTRUNG'), findsOneWidget);
    expect(find.text('신한은행 110628103680'), findsOneWidget);
    final recipientAccount = tester.widget<Text>(
      find.byKey(const Key('amount-recipient-account')),
    );
    expect(recipientAccount.style?.color, const Color(0xFF707070));
    expect(recipientAccount.style?.decorationColor, const Color(0xFF707070));
    expect(find.text('얼마를 보낼까요?'), findsOneWidget);
    expect(find.text('NH농협은행(7191)'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('amount-source-card-value')))
          .data,
      '20,000원',
    );
    expect(nextButton().onPressed, isNull);
    expect(
      nextButton().style?.backgroundColor?.resolve(<WidgetState>{
        WidgetState.disabled,
      }),
      const Color(0xFFE9E9E9),
    );
    expect(
      tester.getBottomRight(find.byKey(const Key('transfer-next'))).dy,
      lessThanOrEqualTo(safeBottom),
    );
    expect(
      tester.getBottomRight(find.byKey(const Key('amount-key-00'))).dy,
      lessThanOrEqualTo(safeBottom),
    );

    final oneLabel = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('amount-key-1')),
        matching: find.text('1'),
      ),
    );
    expect(oneLabel.style?.fontWeight, FontWeight.w700);

    for (final digit in ['5', '0', '0', '0']) {
      await tester.tap(find.byKey(Key('amount-key-$digit')));
      await tester.pump();
    }
    expect(
      tester.widget<Text>(find.byKey(const Key('amount-display'))).data,
      '5,000원',
    );
    expect(nextButton().onPressed, isNotNull);
    expect(
      nextButton().style?.backgroundColor?.resolve(<WidgetState>{}),
      recipientGreen,
    );

    await tester.tap(find.byKey(const Key('transfer-next')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('transfer-pin-sheet')), findsOneWidget);
    expect(find.byKey(const Key('transfer-pin-dim-layer')), findsOneWidget);
    expect(find.text('계좌 비밀번호 입력'), findsOneWidget);
    expect(find.text('NH농협은행 302-2180-4371-91'), findsOneWidget);
    expect(find.byKey(const Key('transfer-pin-symbol-left')), findsOneWidget);
    expect(find.byKey(const Key('transfer-pin-symbol-right')), findsOneWidget);
    expect(find.byKey(const Key('transfer-pin-indicator-0')), findsNothing);
    final pinTwoLabel = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('transfer-pin-key-2')),
        matching: find.text('2'),
      ),
    );
    expect(pinTwoLabel.style?.fontWeight, FontWeight.w500);

    final rearrangeCenter = tester.getCenter(
      find.byKey(const Key('transfer-pin-rearrange')),
    );
    final deleteCenter = tester.getCenter(
      find.byKey(const Key('transfer-pin-delete')),
    );
    final okCenter = tester.getCenter(find.byKey(const Key('transfer-pin-ok')));
    expect(rearrangeCenter.dx, closeTo(116, 0.1));
    expect(deleteCenter.dx, closeTo(294, 0.1));
    expect(okCenter.dx, closeTo(472, 0.1));
    expect(deleteCenter.dx - rearrangeCenter.dx, closeTo(178, 0.1));
    expect(okCenter.dx - deleteCenter.dx, closeTo(178, 0.1));
    expect(rearrangeCenter.dy, closeTo(deleteCenter.dy, 0.1));
    expect(deleteCenter.dy, closeTo(okCenter.dy, 0.1));
    expect(rearrangeCenter.dy, closeTo(1174, 0.1));
    expect(
      (tester
                  .widget<Image>(
                    find.byKey(const Key('transfer-pin-rearrange-artwork')),
                  )
                  .image
              as AssetImage)
          .assetName,
      'assets/images/ref_transfer_pin_rearrange.png',
    );
    expect(
      (tester
                  .widget<Image>(
                    find.byKey(const Key('transfer-pin-delete-artwork')),
                  )
                  .image
              as AssetImage)
          .assetName,
      'assets/images/ref_transfer_pin_delete.png',
    );

    final randomizableKeys = <Key>[
      for (final digit in List<String>.generate(10, (index) => '$index'))
        Key('transfer-pin-key-$digit'),
      const Key('transfer-pin-symbol-left'),
      const Key('transfer-pin-symbol-right'),
    ];
    final beforeRearrange = <Key, Offset>{
      for (final key in randomizableKeys)
        key: tester.getCenter(find.byKey(key)),
    };
    await tester.tap(find.byKey(const Key('transfer-pin-rearrange')));
    await tester.pump();
    final afterRearrange = <Key, Offset>{
      for (final key in randomizableKeys)
        key: tester.getCenter(find.byKey(key)),
    };
    expect(
      beforeRearrange.entries.every(
        (entry) => afterRearrange[entry.key] != entry.value,
      ),
      isTrue,
    );

    for (var index = 0; index < 4; index++) {
      await tester.tap(find.byKey(const Key('transfer-pin-key-9')));
      await tester.pump();
      for (var indicator = 0; indicator <= index; indicator++) {
        expect(
          find.byKey(Key('transfer-pin-indicator-$indicator')),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(Key('transfer-pin-indicator-${index + 1}')),
        findsNothing,
      );
      if (index == 1) {
        final firstIndicator = find.byKey(
          const Key('transfer-pin-indicator-0'),
        );
        final secondIndicator = find.byKey(
          const Key('transfer-pin-indicator-1'),
        );
        expect(tester.getSize(firstIndicator), const Size.square(28));
        expect(
          tester.getCenter(secondIndicator).dx -
              tester.getCenter(firstIndicator).dx,
          33,
        );
        final indicator = tester.widget<DecoratedBox>(firstIndicator);
        expect(
          (indicator.decoration as BoxDecoration).color,
          const Color(0xFF159757),
        );
      }
    }
    await tester.pumpAndSettle();

    String mismatchMessage() => tester
        .widget<RichText>(
          find.byKey(const Key('transfer-pin-mismatch-message')),
        )
        .text
        .toPlainText();

    expect(
      find.byKey(const Key('transfer-pin-mismatch-popup')),
      findsOneWidget,
    );
    expect(mismatchMessage(), contains('1회'));
    expect(mismatchMessage(), contains('연속\n5회 오류'));

    await tester.tap(find.byKey(const Key('transfer-pin-mismatch-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('transfer-pin-sheet')), findsOneWidget);
    expect(find.byKey(const Key('transfer-pin-reset')), findsNothing);
    expect(find.text('비밀번호 재설정'), findsNothing);

    for (final digit in ['8', '8', '8', '8']) {
      await tester.tap(find.byKey(Key('transfer-pin-key-$digit')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(mismatchMessage(), contains('2회'));
  });

  testWidgets('guest transfer accepts a complete local demonstration PIN', (
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
      showTransferWarning: true,
    );

    await tester.pumpWidget(
      _TestHost(
        home: TransferRecipientScreen(
          dataStore: store,
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
    await tester.pump(const Duration(milliseconds: 180));

    expect(
      find.byKey(const Key('transfer-loading-pinToWarning')),
      findsOneWidget,
    );
    for (
      var frame = 0;
      frame < 120 &&
          find.byKey(const Key('transfer-warning-popup')).evaluate().isEmpty;
      frame++
    ) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byKey(const Key('transfer-warning-popup')), findsOneWidget);
  });

  testWidgets('transfer loading uses responsive reference coordinates', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 780);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _TestHost(
        home: TransferLoadingOverlay(
          playbackKey: 1,
          duration: const Duration(seconds: 2),
          onComplete: () {},
        ),
      ),
    );
    await tester.pump();

    const scale = 780 / 1280;
    const canvasLeft = (360 - (588 * scale)) / 2;
    expect(
      tester.getTopLeft(find.byKey(const Key('transfer-loading-logo'))),
      const Offset(canvasLeft + (234 * scale), 581 * scale),
    );
    final logo = find.byKey(const Key('transfer-loading-logo'));
    final paintedLogoSize =
        tester.getBottomRight(logo) - tester.getTopLeft(logo);
    expect(paintedLogoSize, const Offset(120 * scale, 120 * scale));
    expect(
      tester.getSize(find.byKey(const Key('transfer-loading-scrim'))),
      const Size(360, 780),
    );
  });

  testWidgets(
    'saved recipient warning setting controls the correct-PIN destination',
    (tester) async {
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
      final recipient = await store.createRecipient(
        displayName: 'TRINHTRUNG',
        bankCode: '신한',
        accountNumber: '110628103680',
        showTransferWarning: true,
      );

      Future<void> reachCorrectPin({required Key screenKey}) async {
        await tester.pumpWidget(
          _TestHost(
            home: TransferRecipientScreen(
              key: screenKey,
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
        await tester.pumpAndSettle();
        await tester.pump();
        await tester.pumpAndSettle();
      }

      await reachCorrectPin(screenKey: const ValueKey('warning-on'));
      expect(find.byKey(const Key('transfer-warning-popup')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('transfer-warning-cancel'))),
        const Size(217, 69),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('transfer-warning-cancel'))).dy,
        closeTo(713.5, 0.1),
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('amount-source-card-value')))
            .style
            ?.fontWeight,
        FontWeight.w500,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('transfer-warning-message')))
            .data,
        contains('TRINHTRUNG님에게 이체하시겠어요?'),
      );
      await tester.tap(find.byKey(const Key('transfer-warning-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('이체확인'), findsOneWidget);
      expect(find.byKey(const Key('transfer-review-confirm')), findsOneWidget);
      expect(find.byKey(const Key('transfer-review-close')), findsOneWidget);
      expect(find.byKey(const Key('transfer-home')), findsNothing);
      expect(
        find.byKey(const Key('transfer-review-edit-icon')),
        findsNWidgets(3),
      );
      for (final editIcon in tester.widgetList<Image>(
        find.byKey(const Key('transfer-review-edit-icon')),
      )) {
        expect(
          (editIcon.image as AssetImage).assetName,
          'assets/images/ref_transfer_review_edit.png',
        );
      }
      expect(
        tester.widget<Text>(find.text('메모')).style?.color,
        const Color(0xFF686868),
      );
      expect(
        tester.widget<Text>(find.text('메모입력')).style?.color,
        const Color(0xFFB6B6B6),
      );
      expect(
        tester.widget<Text>(find.textContaining('료 면제!')).style?.height,
        1.55,
      );
      expect(
        tester.getSize(find.byKey(const Key('transfer-review-add'))),
        const Size(172, 81),
      );
      expect(
        tester.getSize(find.byKey(const Key('transfer-review-confirm'))),
        const Size(332, 81),
      );
      expect(
        tester
            .widget<RichText>(find.byKey(const Key('transfer-review-title')))
            .text
            .toPlainText(),
        'TRINHTRUNG...님께 5,000원을\n이체할까요?',
      );
      expect(find.text('BUIPHUONGT'), findsOneWidget);

      await store.saveRecipient(recipient.copyWith(showTransferWarning: false));
      await reachCorrectPin(screenKey: const ValueKey('warning-off'));
      expect(find.byKey(const Key('transfer-warning-popup')), findsNothing);
      expect(find.text('이체확인'), findsOneWidget);
      expect(find.byKey(const Key('transfer-review-confirm')), findsOneWidget);
    },
  );

  testWidgets('four transfer Loading 2 transitions match the source video', (
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
      _TestHost(
        home: HomeScreen(auth: auth, dataStore: store),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> pumpUntilLoading(Key key) async {
      for (var attempt = 0; attempt < 30; attempt++) {
        if (find.byKey(key).evaluate().isNotEmpty) return;
        await tester.pump(const Duration(milliseconds: 16));
      }
      fail('Loading overlay $key did not appear.');
    }

    void expectReferenceGeometry(Key phaseKey, Color scrimColor) {
      expect(find.byKey(phaseKey), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('transfer-loading-logo'))),
        const Offset(234, 581),
      );
      expect(
        tester.getSize(find.byKey(const Key('transfer-loading-logo'))),
        const Size.square(120),
      );
      final barrier = tester.widget<ModalBarrier>(
        find.byKey(const Key('transfer-loading-scrim')),
      );
      expect(barrier.color, scrimColor);
      final image = tester.widget<Image>(
        find.descendant(
          of: find.byKey(const Key('transfer-loading-logo')),
          matching: find.byType(Image),
        ),
      );
      expect(
        (image.image as AssetImage).assetName,
        'assets/images/loading_original.png',
      );
    }

    Future<void> expectExactDuration(Key key, Duration duration) async {
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(duration - const Duration(milliseconds: 1));
      expect(find.byKey(key), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(find.byKey(key), findsNothing);
    }

    const homeToRecipient = Key('transfer-loading-homeToRecipient');
    await tester.tap(find.widgetWithText(OutlinedButton, '이체'));
    await pumpUntilLoading(homeToRecipient);
    expectReferenceGeometry(homeToRecipient, Colors.transparent);
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.pump(
      transferHomeToRecipientScreenSwitchDelay -
          const Duration(milliseconds: 1),
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text('누구에게 보낼까요?'), findsOneWidget);
    expectReferenceGeometry(homeToRecipient, const Color(0x7E000000));
    await tester.pump(
      transferHomeToRecipientLoadingDuration -
          transferHomeToRecipientScreenSwitchDelay -
          const Duration(milliseconds: 1),
    );
    expect(find.byKey(homeToRecipient), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.byKey(homeToRecipient), findsNothing);

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

    const pinToWarning = Key('transfer-loading-pinToWarning');
    await pumpUntilLoading(pinToWarning);
    expectReferenceGeometry(pinToWarning, Colors.transparent);
    expect(find.byKey(const Key('amount-key-1')), findsNothing);
    expect(find.text('5,000원'), findsWidgets);
    await tester.pump(
      transferPinAcceptedScrimDelay - const Duration(milliseconds: 1),
    );
    expectReferenceGeometry(pinToWarning, Colors.transparent);
    await tester.pump(const Duration(milliseconds: 1));
    expectReferenceGeometry(pinToWarning, const Color(0x7E000000));
    await tester.pump(
      transferPinAcceptedLoadingDuration -
          transferPinAcceptedScrimDelay -
          const Duration(milliseconds: 1),
    );
    expect(find.byKey(pinToWarning), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.byKey(pinToWarning), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('transfer-warning-popup')), findsOneWidget);

    await tester.tap(find.byKey(const Key('transfer-warning-confirm')));
    const warningToConfirmation = Key('transfer-loading-warningToConfirmation');
    await pumpUntilLoading(warningToConfirmation);
    expectReferenceGeometry(warningToConfirmation, Colors.transparent);
    expect(find.byKey(const Key('amount-key-1')), findsNothing);
    await tester.pump(
      transferWarningScrimDelay - const Duration(milliseconds: 1),
    );
    expectReferenceGeometry(warningToConfirmation, Colors.transparent);
    await tester.pump(const Duration(milliseconds: 1));
    expectReferenceGeometry(warningToConfirmation, const Color(0x7E000000));
    await tester.pump(
      transferWarningScreenSwitchDelay - transferWarningScrimDelay,
    );
    expect(find.text('이체확인'), findsOneWidget);
    await tester.pump(
      transferWarningToConfirmationLoadingDuration -
          transferWarningScreenSwitchDelay -
          const Duration(milliseconds: 1),
    );
    expect(find.byKey(warningToConfirmation), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.byKey(warningToConfirmation), findsNothing);
    expect(find.byKey(const Key('transfer-review-confirm')), findsOneWidget);

    await tester.tap(find.byKey(const Key('transfer-review-confirm')));
    const confirmationToResult = Key('transfer-loading-confirmationToResult');
    await pumpUntilLoading(confirmationToResult);
    expectReferenceGeometry(confirmationToResult, const Color(0x7E000000));
    expect(find.text('이체확인'), findsOneWidget);
    await expectExactDuration(
      confirmationToResult,
      transferSubmissionLoadingDuration,
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byKey(const Key('transfer-failure-popup')), findsOneWidget);
  });

  testWidgets('transfer failure popup matches the NH6901 reference', (
    tester,
  ) async {
    _configureMockupViewport(tester);
    final store = AppDataStore.inMemory();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      _TestHost(
        home: HomeScreen(auth: _VerifiedTransferAuth(), dataStore: store),
      ),
    );
    await tester.pumpAndSettle();

    final popupFuture = showTransferFailurePopup(
      tester.element(find.byType(HomeScreen)),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('transfer-failure-popup'))),
      const Size(435, 429),
    );
    expect(
      tester.getSize(find.byKey(const Key('transfer-failure-home-confirm'))),
      const Size(385, 57),
    );
    expect(find.text('거래가 제한되었습니다.'), findsOneWidget);
    expect(find.text('(NH6901)'), findsOneWidget);
    expect(find.textContaining('자금세탁 의심거래'), findsOneWidget);
    expect(find.textContaining('1661-3000'), findsOneWidget);
    expect(
      (tester
                  .widget<Image>(
                    find.byKey(const Key('transfer-failure-brand')),
                  )
                  .image
              as AssetImage)
          .assetName,
      'assets/images/ref_transfer_failure_brand_sharp.png',
    );

    await tester.tap(find.byKey(const Key('transfer-failure-home-confirm')));
    await tester.pumpAndSettle();
    await popupFuture;
    expect(find.byKey(const Key('transfer-failure-popup')), findsNothing);
  });

  testWidgets('header menu jumps to benefits and keeps chrome fixed', (
    tester,
  ) async {
    _configureMockupViewport(tester);
    await tester.pumpWidget(
      _TestHost(
        home: HomeScreen(
          auth: AuthService(),
          dataStore: AppDataStore.inMemory(withMockData: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final headerTop = tester.getTopLeft(
      find.byKey(const Key('home-native-header')),
    );
    final navigationTop = tester.getTopLeft(
      find.byKey(const Key('home-bottom-navigation')),
    );
    await tester.tap(find.byKey(const Key('home-menu-search')));
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const Key('home-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(scrollable.position.pixels, greaterThan(500));
    expect(
      tester.getTopLeft(find.byKey(const Key('home-native-header'))),
      headerTop,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('home-bottom-navigation'))),
      navigationTop,
    );
  });

  testWidgets('home uses the mockup text scale before large-text boost', (
    tester,
  ) async {
    _configureMockupViewport(tester);
    await tester.pumpWidget(
      _TestHost(
        home: HomeScreen(
          auth: AuthService(),
          dataStore: AppDataStore.inMemory(withMockData: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final header = find.byKey(const Key('home-native-header'));
    expect(
      MediaQuery.textScalerOf(tester.element(header)).scale(10),
      closeTo(10.0, 0.001),
    );

    await tester.tap(find.byKey(const Key('home-native-large-text')));
    await tester.pump();

    expect(
      MediaQuery.textScalerOf(tester.element(header)).scale(10),
      closeTo(11.3, 0.001),
    );
    final accountCard = find.byKey(const Key('home-account-card'));
    final accountActions = find.byKey(const Key('home-account-actions'));
    expect(
      tester.getBottomLeft(accountActions).dy,
      lessThanOrEqualTo(tester.getBottomLeft(accountCard).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('login name opens Korean auth sheet', (tester) async {
    _configureMockupViewport(tester);
    await tester.pumpWidget(
      _TestHost(
        home: HomeScreen(
          auth: AuthService(),
          dataStore: AppDataStore.inMemory(withMockData: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-account-name')));
    await tester.pumpAndSettle();
    expect(find.text('계정'), findsOneWidget);
    await tester.tap(find.byKey(const Key('account-auth-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth-sheet-brand')), findsOneWidget);
    expect(find.text('NH올원뱅크'), findsOneWidget);
    expect(find.text('로그인'), findsWidgets);
    expect(find.text('이메일'), findsOneWidget);
    expect(find.text('비밀번호'), findsOneWidget);
    expect(find.byKey(const Key('auth-password-visibility')), findsOneWidget);
    expect(find.textContaining('로컬 개발 모드'), findsNothing);
    expect(find.text('계정이 없으신가요? 회원가입'), findsOneWidget);
  });

  testWidgets('register sheet uses Korean labels', (tester) async {
    _configureMockupViewport(tester);
    await tester.pumpWidget(
      _TestHost(
        home: HomeScreen(
          auth: AuthService(),
          dataStore: AppDataStore.inMemory(withMockData: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-account-name')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-auth-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('계정이 없으신가요? 회원가입'));
    await tester.pumpAndSettle();
    expect(find.text('회원가입'), findsWidgets);
    expect(find.text('표시 이름'), findsOneWidget);
    expect(find.byKey(const Key('register-display-name')), findsOneWidget);
  });
}

void _configureMockupViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(588, 1280);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

class _TestHost extends StatelessWidget {
  const _TestHost({required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAllOneTheme(),
      home: home,
    );
  }
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

class _CountingTransferAuth extends AuthService {
  int _failedAttempts = 0;

  @override
  bool get isSignedIn => true;

  @override
  Future<PinStatus> pinStatus(PinPurpose purpose) async =>
      PinStatus(configured: true, failedAttempts: _failedAttempts);

  @override
  Future<PinVerificationResult> verifyPin(
    PinPurpose purpose,
    String pin,
  ) async {
    _failedAttempts++;
    return PinVerificationResult(
      configured: true,
      failedAttempts: _failedAttempts,
      matched: false,
    );
  }
}
