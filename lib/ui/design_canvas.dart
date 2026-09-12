import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const double mockupWidth = 588;
const double mockupHeight = 1280;
Future<void> showDeviceStatusBar({
  required bool darkIcons,
  required Color backgroundColor,
}) async {
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );
  final style = darkIcons
      ? SystemUiOverlayStyle.dark
      : SystemUiOverlayStyle.light;
  SystemChrome.setSystemUIOverlayStyle(
    style.copyWith(
      statusBarColor: backgroundColor,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarColor: backgroundColor,
      systemNavigationBarIconBrightness: darkIcons
          ? Brightness.dark
          : Brightness.light,
      systemNavigationBarContrastEnforced: false,
      systemNavigationBarDividerColor: backgroundColor,
    ),
  );
}

class DesignCanvas extends StatelessWidget {
  const DesignCanvas({
    super.key,
    required this.child,
    this.backgroundColor = Colors.white,
    this.fullWidthBottomColor,
    this.fullWidthBottomTop,
    this.fullWidthBottomKey,
  }) : assert((fullWidthBottomColor == null) == (fullWidthBottomTop == null));

  final Widget child;
  final Color backgroundColor;
  final Color? fullWidthBottomColor;
  final double? fullWidthBottomTop;
  final Key? fullWidthBottomKey;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = math.min(
            constraints.maxWidth / mockupWidth,
            constraints.maxHeight / mockupHeight,
          );
          final canvasHeight = mockupHeight * scale;
          final canvasTop = (constraints.maxHeight - canvasHeight) / 2;
          final canvas = Center(
            child: SizedBox(
              width: mockupWidth * scale,
              height: canvasHeight,
              child: FittedBox(
                // The canvas keeps the mockup aspect ratio. `contain` avoids
                // stretching glyphs and icon edges when a device's dimensions
                // do not divide cleanly into the design canvas.
                fit: BoxFit.contain,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: mockupWidth,
                  height: mockupHeight,
                  // Every screen is positioned against the fixed design
                  // canvas. Respecting Android's system font scale here would
                  // enlarge only glyphs (not their positioned containers),
                  // which causes controls such as the recipient edit chip to
                  // overlap their labels. Keep the canvas typography at its
                  // mockup size on every device.
                  child: MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.noScaling),
                    child: DefaultTextStyle(
                      style: const TextStyle(
                        fontFamily: 'NotoSansKR',
                        color: Color(0xFF151820),
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          );
          final bottomColor = fullWidthBottomColor;
          final bottomTop = fullWidthBottomTop;
          if (bottomColor == null || bottomTop == null) return canvas;
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: canvasTop + (bottomTop * scale),
                bottom: 0,
                child: ColoredBox(key: fullWidthBottomKey, color: bottomColor),
              ),
              canvas,
            ],
          );
        },
      ),
    );
  }
}
