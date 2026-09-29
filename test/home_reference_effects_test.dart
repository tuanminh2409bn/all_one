import 'dart:io';
import 'dart:ui' as ui;

import 'package:all_one/core/app_data.dart';
import 'package:all_one/core/auth_service.dart';
import 'package:all_one/ui/app_theme.dart';
import 'package:all_one/ui/home_reference_effects.dart';
import 'package:all_one/ui/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await (FontLoader('NotoSansKRMedium')
          ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Medium.otf'))
          ..addFont(rootBundle.load('assets/fonts/NotoSansCJKkr-Bold.otf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets('benefits reveal native copy in the source three-message order', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const HomeBenefitStrip(scale: 1)));
    expect(find.text(homeBenefitLabels[0]), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 900));
    final first = tester.widget<Text>(
      find.byKey(const Key('home-benefit-label')),
    );
    expect(first.style!.fontSize, 24);
    expect(find.byType(ShaderMask), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.text(homeBenefitLabels[1]), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.text(homeBenefitLabels[2]), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.text(homeBenefitLabels[0]), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'reduced motion uses still artwork and stops the repeating ticker',
    (tester) async {
      await tester.pumpWidget(
        _host(const HomeBenefitStrip(scale: 1), reducedMotion: true),
      );
      await tester.pumpAndSettle();
      final icon = tester.widget<Image>(find.byType(Image));
      expect((icon.image as AssetImage).assetName, contains('_still.png'));
      await tester.pump(const Duration(seconds: 8));
      expect(find.text(homeBenefitLabels[0]), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('vector chevrons animate and return to their source loop phase', (
    tester,
  ) async {
    const key = Key('chevron-capture');
    await tester.pumpWidget(
      _host(
        const RepaintBoundary(key: key, child: HomeAssetChevrons(scale: 1)),
      ),
    );
    Future<List<int>> pixels() async => (await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData();
      image.dispose();
      return data!.buffer.asUint8List();
    }))!;

    final first = await pixels();
    await tester.pump(const Duration(milliseconds: 750));
    expect(await pixels(), isNot(orderedEquals(first)));
    await tester.pump(const Duration(milliseconds: 750));
    expect(await pixels(), orderedEquals(first));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  if (const bool.fromEnvironment('EXPORT_HOME_EFFECTS')) {
    testWidgets('export the running Home effects at native 2x resolution', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(588, 1280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final store = AppDataStore.inMemory(withMockData: false);
      addTearDown(store.dispose);
      const key = Key('home-effect-export');
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAllOneTheme(),
          home: RepaintBoundary(
            key: key,
            child: HomeScreen(auth: AuthService(), dataStore: store),
          ),
        ),
      );
      for (var warmup = 0; warmup < 3; warmup++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      final directory = Directory('build/comparisons/home_effects_frames')
        ..createSync(recursive: true);
      for (var frame = 0; frame < 225; frame++) {
        await tester.pump(const Duration(microseconds: 33333));
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(key),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '${directory.path}/${frame.toString().padLeft(4, '0')}.png',
          ).writeAsBytesSync(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }
}

Widget _host(Widget child, {bool reducedMotion = false}) => MaterialApp(
  theme: buildAllOneTheme(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reducedMotion),
    child: Scaffold(
      body: Center(child: SizedBox(width: 476, child: child)),
    ),
  ),
);
