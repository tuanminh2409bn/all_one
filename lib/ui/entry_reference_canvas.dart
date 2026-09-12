import 'dart:math' as math;

import 'package:flutter/material.dart';

const double entryReferenceWidth = 1206;
const double entryReferenceHeight = 2375;

/// Keeps the entry screens aligned to the safe-area crop of the iPhone
/// references while preserving their aspect ratio on Android devices.
class EntryReferenceCanvas extends StatelessWidget {
  const EntryReferenceCanvas({
    super.key,
    required this.asset,
    required this.child,
    required this.backgroundColor,
  });

  final String asset;
  final Widget child;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = math.min(
              constraints.maxWidth / entryReferenceWidth,
              constraints.maxHeight / entryReferenceHeight,
            );
            return Center(
              child: SizedBox(
                width: entryReferenceWidth * scale,
                height: entryReferenceHeight * scale,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: entryReferenceWidth,
                    height: entryReferenceHeight,
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
              ),
            );
          },
        ),
      ),
    );
  }
}
