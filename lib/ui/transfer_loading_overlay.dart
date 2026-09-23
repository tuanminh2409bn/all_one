import 'dart:async';

import 'package:flutter/material.dart';

import 'design_canvas.dart';

const homeToAccountDetailsLoadingDuration = Duration(milliseconds: 1500);
const homeToAccountDetailsScreenSwitchDelay = Duration(milliseconds: 1300);
const transferHomeToRecipientLoadingDuration = Duration(milliseconds: 400);
const transferHomeToRecipientScreenSwitchDelay = Duration(milliseconds: 233);
const transferPinAcceptedLoadingDuration = Duration(milliseconds: 1000);
const transferPinAcceptedScrimDelay = Duration(milliseconds: 66);
const transferWarningToConfirmationLoadingDuration = Duration(
  milliseconds: 600,
);
const transferWarningScrimDelay = Duration(milliseconds: 33);
const transferWarningScreenSwitchDelay = Duration(milliseconds: 67);
const transferSubmissionLoadingDuration = Duration(milliseconds: 1400);

/// The transfer loader measured from the original 588×1280 reference video.
///
/// The animation is the existing Loading 2 APNG, but transfer transitions use
/// a 120 px box and a darker scrim than the authenticated PIN-to-Home loader.
class TransferLoadingOverlay extends StatefulWidget {
  const TransferLoadingOverlay({
    super.key,
    required this.playbackKey,
    required this.duration,
    required this.onComplete,
    this.scrimDelay = Duration.zero,
    this.onScrimShown,
    this.backdropSwitchDelay,
    this.onBackdropSwitch,
  });

  final Object playbackKey;
  final Duration duration;
  final VoidCallback onComplete;
  final Duration scrimDelay;
  final VoidCallback? onScrimShown;
  final Duration? backdropSwitchDelay;
  final VoidCallback? onBackdropSwitch;

  @override
  State<TransferLoadingOverlay> createState() => _TransferLoadingOverlayState();
}

class _TransferLoadingOverlayState extends State<TransferLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;
  Timer? _scrimTimer;
  Timer? _backdropSwitchTimer;
  late bool _scrimVisible;

  @override
  void initState() {
    super.initState();
    _scrimVisible = widget.scrimDelay == Duration.zero;
    if (!_scrimVisible) {
      _scrimTimer = Timer(widget.scrimDelay, () {
        if (!mounted) return;
        setState(() => _scrimVisible = true);
        widget.onScrimShown?.call();
      });
    }
    if (widget.backdropSwitchDelay case final delay?) {
      _backdropSwitchTimer = Timer(delay, () {
        if (mounted) widget.onBackdropSwitch?.call();
      });
    }
    _clock = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          widget.onComplete();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _scrimTimer?.cancel();
    _backdropSwitchTimer?.cancel();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ModalBarrier(
        key: const Key('transfer-loading-scrim'),
        color: _scrimVisible ? const Color(0x7E000000) : Colors.transparent,
        dismissible: false,
        semanticsLabel: '처리 중',
      ),
      IgnorePointer(
        child: DesignCanvas(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              Positioned(
                key: const Key('transfer-loading-logo'),
                left: 234,
                top: 581,
                width: 120,
                height: 120,
                child: RepaintBoundary(
                  child: Image.asset(
                    'assets/images/loading_original.png',
                    key: ValueKey<Object>(widget.playbackKey),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    gaplessPlayback: true,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
