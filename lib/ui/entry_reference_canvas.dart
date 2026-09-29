import 'dart:math' as math;

import 'package:flutter/material.dart';

const double entryReferenceWidth = 1206;
const double entryReferenceHeight = 2375;

/// Keeps entry artwork aligned to its iPhone reference dimensions while
/// preserving the aspect ratio on Android devices.
class EntryReferenceCanvas extends StatelessWidget {
  const EntryReferenceCanvas({
    super.key,
    required this.asset,
    required this.child,
    required this.backgroundColor,
    this.referenceSize = const Size(entryReferenceWidth, entryReferenceHeight),
    this.extendBehindBottomSafeArea = false,
    this.alignment = Alignment.center,
  });

  final String asset;
  final Widget child;
  final Color backgroundColor;
  final Size referenceSize;
  final bool extendBehindBottomSafeArea;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final layout = LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.min(
          constraints.maxWidth / referenceSize.width,
          constraints.maxHeight / referenceSize.height,
        );
        final canvas = SizedBox(
          width: referenceSize.width * scale,
          height: referenceSize.height * scale,
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: referenceSize.width,
              height: referenceSize.height,
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.noScaling),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image(
                      key: ValueKey('entry-reference-$asset'),
                      image: AssetImage(asset),
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                      excludeFromSemantics: true,
                    ),
                    child,
                  ],
                ),
              ),
            ),
          ),
        );
        return alignment == Alignment.center
            ? Center(child: canvas)
            : Align(alignment: alignment, child: canvas);
      },
    );
    return ColoredBox(
      color: backgroundColor,
      child: extendBehindBottomSafeArea
          ? SafeArea(bottom: false, child: layout)
          : SafeArea(child: layout),
    );
  }
}
