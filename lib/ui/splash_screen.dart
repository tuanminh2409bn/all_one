import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/auth_service.dart';
import 'certificate_login_screen.dart';
import 'design_canvas.dart';
import 'entry_reference_canvas.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.auth, this.autoContinue = true});

  final AuthService auth;
  final bool autoContinue;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    showDeviceStatusBar(darkIcons: true, backgroundColor: Colors.white);
    if (widget.autoContinue) {
      _timer = Timer(const Duration(milliseconds: 1600), _continue);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _continue() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 230),
        pageBuilder: (_, animation, secondaryAnimation) =>
            CertificateLoginScreen(auth: widget.auth),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.white,
        systemNavigationBarColor: const Color(0xFFF1FCFD),
        systemNavigationBarIconBrightness: Brightness.dark,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
      ),
      child: GestureDetector(
        key: const Key('entry-screen-6'),
        behavior: HitTestBehavior.opaque,
        onTap: _continue,
        child: const EntryReferenceCanvas(
          asset: 'assets/images/entry_6_splash.png',
          backgroundColor: Color(0xFFF1FCFD),
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}
