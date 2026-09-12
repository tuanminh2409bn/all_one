import 'package:all_one/core/app_data.dart';
import 'package:all_one/core/auth_service.dart';
import 'package:all_one/ui/certificate_login_screen.dart';
import 'package:all_one/ui/home_screen.dart';
import 'package:all_one/ui/pin_screen.dart';
import 'package:all_one/ui/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    await tester.pumpWidget(_host(CertificateLoginScreen(auth: auth)));
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
