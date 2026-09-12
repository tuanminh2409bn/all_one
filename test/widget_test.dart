import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:all_one/core/app_data.dart';
import 'package:all_one/core/auth_service.dart';
import 'package:all_one/ui/app_loading_transition.dart';
import 'package:all_one/ui/certificate_login_screen.dart';
import 'package:all_one/ui/home_screen.dart';
import 'package:all_one/ui/pin_screen.dart';
import 'package:all_one/ui/splash_screen.dart';

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
      _TestHost(home: CertificateLoginScreen(auth: AuthService())),
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

  testWidgets('screens 7 and 8 lead to home after six PIN digits', (
    tester,
  ) async {
    _configureMockupViewport(tester);
    await tester.pumpWidget(
      _TestHost(home: CertificateLoginScreen(auth: AuthService())),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('certificate-login-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('certificate-login-button')));
    await tester.pumpAndSettle();
    expect(find.byType(PinScreen), findsOneWidget);

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

  testWidgets('PIN close returns to certificate login', (tester) async {
    _configureMockupViewport(tester);
    await tester.pumpWidget(
      _TestHost(home: CertificateLoginScreen(auth: AuthService())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('certificate-login-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pin-close')));
    await tester.pumpAndSettle();

    expect(find.byType(CertificateLoginScreen), findsOneWidget);
    expect(find.byType(PinScreen), findsNothing);
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
