import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:all_one/core/app_data.dart';
import 'package:all_one/core/auth_service.dart';
import 'package:all_one/ui/account_details_screen.dart';
import 'package:all_one/ui/app_loading_transition.dart';
import 'package:all_one/ui/certificate_login_screen.dart';
import 'package:all_one/ui/home_screen.dart';
import 'package:all_one/ui/limit_release_screen.dart';
import 'package:all_one/ui/pin_screen.dart';
import 'package:all_one/ui/splash_screen.dart';
import 'package:all_one/ui/transfer_recipient_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
    expect(find.byKey(const Key('home-daily-point-hand')), findsOneWidget);
    final accountLogo = find.byKey(const Key('home-account-logo'));
    expect(tester.getSize(accountLogo), const Size.square(48));
    expect(
      tester.widget<ClipRRect>(accountLogo).borderRadius,
      BorderRadius.circular(14),
    );
    expect(find.text('매일 포인트 용돈 받기'), findsOneWidget);
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
    expect(find.text('매일 포인트 용돈 받기'), findsOneWidget);
    expect(find.text('쓸수록 혜택받기'), findsNothing);
    expect(find.byKey(const Key('home-bottom-navigation')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('home-bottom-navigation'))),
      navigationTop,
    );
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
    expect(find.text('뚜레쥬르'), findsOneWidget);
    expect(find.text('1개월 · 전체 · 최신순'), findsOneWidget);
    expect(find.text('거래내역이 없습니다.'), findsOneWidget);

    final title = find.byKey(const Key('account-details-title'));
    final accountType = find.byKey(const Key('account-type-text'));
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

  testWidgets('transfer flow uses green and respects Android navigation', (
    tester,
  ) async {
    const appGreen = Color(0xFF159757);
    _configureMockupViewport(tester);
    tester.view.padding = const FakeViewPadding(bottom: 68);
    tester.view.viewPadding = const FakeViewPadding(bottom: 68);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    final store = AppDataStore.inMemory(withMockData: false);
    addTearDown(store.dispose);
    await store.createAccount(
      bankCode: '신한',
      bankDisplayName: '저축예금',
      ownerName: 'BUI PHUONG',
      accountNumber: '3022180437191',
      accountType: '저축예금',
      openingBalance: 20000,
    );

    await tester.pumpWidget(
      _TestHost(
        home: TransferRecipientScreen(
          dataStore: store,
          initialPinKeys: const [
            '2',
            '3',
            '6',
            '8',
            '0',
            '9',
            '4',
            '7',
            '1',
            '5',
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('transfer-account-input')),
      '100237698805',
    );
    await tester.tap(find.byKey(const Key('transfer-bank-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bank-농협')));
    await tester.pumpAndSettle();

    FilledButton nextButton() =>
        tester.widget<FilledButton>(find.byKey(const Key('transfer-next')));
    expect(
      nextButton().style?.backgroundColor?.resolve(<WidgetState>{}),
      appGreen,
    );

    await tester.tap(find.byKey(const Key('transfer-next')));
    await tester.pumpAndSettle();

    const safeBottom = 1280 - 68;
    expect(find.text('얼마를 보낼까요?'), findsOneWidget);
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
    expect(oneLabel.style?.fontWeight, FontWeight.w500);

    await tester.tap(find.byKey(const Key('amount-key-2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('transfer-next')));
    await tester.pumpAndSettle();

    expect(find.textContaining('보낼까요?'), findsOneWidget);
    expect(
      tester.getBottomRight(find.byKey(const Key('transfer-next'))).dy,
      lessThanOrEqualTo(safeBottom),
    );
    expect(
      nextButton().style?.backgroundColor?.resolve(<WidgetState>{}),
      appGreen,
    );

    await tester.tap(find.byKey(const Key('transfer-next')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const Key('transfer-pin-keypad-background')),
          )
          .color,
      appGreen,
    );
    final pinTwoLabel = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('transfer-pin-key-2')),
        matching: find.text('2'),
      ),
    );
    expect(pinTwoLabel.style?.fontWeight, FontWeight.w700);

    await tester.tap(find.byKey(const Key('transfer-pin-key-2')));
    await tester.pump();
    final firstIndicator = tester.widget<Container>(
      find.byKey(const Key('transfer-pin-indicator-0')),
    );
    expect((firstIndicator.decoration as BoxDecoration).color, appGreen);

    for (final digit in ['3', '6', '8']) {
      await tester.tap(find.byKey(Key('transfer-pin-key-$digit')));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    final failureButton = tester.widget<FilledButton>(
      find.byKey(const Key('transfer-failure-home-confirm')),
    );
    expect(
      failureButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      appGreen,
    );
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
      closeTo(11.3, 0.001),
    );

    await tester.tap(find.byKey(const Key('home-native-large-text')));
    await tester.pump();

    expect(
      MediaQuery.textScalerOf(tester.element(header)).scale(10),
      closeTo(12.769, 0.001),
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
      theme: ThemeData(useMaterial3: true, fontFamily: 'NotoSansKR'),
      home: home,
    );
  }
}
