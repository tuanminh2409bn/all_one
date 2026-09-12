import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/auth_service.dart';
import 'design_canvas.dart';
import 'entry_reference_canvas.dart';
import 'home_screen.dart';

/// Recreates the app's authenticated loading transition shown in mockup 9.
///
/// The loader first sits over the certificate screen, keeps playing while the
/// home screen appears underneath, then fades away with the loading route.
class AppLoadingTransition extends StatefulWidget {
  const AppLoadingTransition({super.key, required this.auth});

  final AuthService auth;

  @override
  State<AppLoadingTransition> createState() => _AppLoadingTransitionState();
}

class _AppLoadingTransitionState extends State<AppLoadingTransition> {
  static const _certificateHold = Duration(milliseconds: 1450);
  static const _homeHold = Duration(milliseconds: 520);
  static const _revealDuration = Duration(milliseconds: 220);

  bool _showHome = false;

  @override
  void initState() {
    super.initState();
    showDeviceStatusBar(darkIcons: true, backgroundColor: Colors.white);
    unawaited(_runTransition());
  }

  Future<void> _runTransition() async {
    await Future<void>.delayed(_certificateHold);
    if (!mounted) return;
    setState(() => _showHome = true);

    await Future<void>.delayed(_homeHold);
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil<void>(
      PageRouteBuilder<void>(
        transitionDuration: _revealDuration,
        pageBuilder: (_, animation, secondaryAnimation) =>
            HomeScreen(auth: widget.auth),
        transitionsBuilder: (_, animation, secondaryAnimation, child) =>
            FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.white,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        key: const Key('app-loading-transition'),
        backgroundColor: Colors.white,
        body: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 170),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  fit: StackFit.expand,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                ),
                child: _showHome
                    ? HomeScreen(
                        key: const ValueKey('loading-home-backdrop'),
                        auth: widget.auth,
                      )
                    : const _CertificateBackdrop(
                        key: ValueKey('loading-certificate-backdrop'),
                      ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: padding.top,
              bottom: padding.bottom,
              child: const ColoredBox(
                key: Key('app-loading-scrim'),
                color: Color(0x73000000),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: padding.top,
              bottom: padding.bottom,
              child: IgnorePointer(
                child: Align(
                  alignment: const Alignment(0, -0.03),
                  child: const _OriginalLoadingLogo(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CertificateBackdrop extends StatelessWidget {
  const _CertificateBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF9F8FF),
      child: EntryReferenceCanvas(
        asset: 'assets/images/entry_7_certificate.png',
        backgroundColor: Color(0xFFF9F8FF),
        child: SizedBox.expand(),
      ),
    );
  }
}

class _OriginalLoadingLogo extends StatelessWidget {
  const _OriginalLoadingLogo();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: const Key('app-loading-logo'),
      child: SizedBox.square(
        dimension: 84,
        child: Image.asset(
          'assets/images/loading_original.png',
          key: const Key('app-loading-logo-animation'),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
