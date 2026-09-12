import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/auth_service.dart';
import '../core/data_bootstrap.dart';
import 'auth_sheet.dart';
import 'design_canvas.dart';
import 'entry_reference_canvas.dart';
import 'pin_screen.dart';

class CertificateLoginScreen extends StatefulWidget {
  const CertificateLoginScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<CertificateLoginScreen> createState() => _CertificateLoginScreenState();
}

class _CertificateLoginScreenState extends State<CertificateLoginScreen> {
  bool _openingPin = false;

  @override
  void initState() {
    super.initState();
    showDeviceStatusBar(darkIcons: true, backgroundColor: Colors.white);
  }

  Future<void> _openPin() async {
    if (_openingPin) return;
    setState(() => _openingPin = true);
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (routeContext, animation, secondaryAnimation) => PinScreen(
          auth: widget.auth,
          onClose: () => Navigator.of(routeContext).pop(),
        ),
        transitionsBuilder: (_, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    if (mounted) {
      setState(() => _openingPin = false);
      showDeviceStatusBar(darkIcons: true, backgroundColor: Colors.white);
    }
  }

  Future<void> _changeLoginMethod() async {
    final authenticated = await showAuthSheet(context, auth: widget.auth);
    if (!authenticated || !mounted) return;
    await initializeUserData(widget.auth);
    if (mounted) await _openPin();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.white,
        systemNavigationBarColor: const Color(0xFFF9F8FF),
        systemNavigationBarIconBrightness: Brightness.dark,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F8FF),
        body: Stack(
          fit: StackFit.expand,
          children: [
            EntryReferenceCanvas(
              asset: 'assets/images/entry_7_certificate.png',
              backgroundColor: const Color(0xFFF9F8FF),
              child: Stack(
                children: [
                  Positioned(
                    key: const Key('certificate-login-button'),
                    left: 135,
                    top: 795,
                    width: 936,
                    height: 185,
                    child: _InvisibleReferenceButton(
                      semanticsLabel: 'NH인증서 로그인',
                      onTap: _openPin,
                    ),
                  ),
                  Positioned(
                    key: const Key('certificate-change-method'),
                    left: 85,
                    top: 2070,
                    width: 470,
                    height: 180,
                    child: _InvisibleReferenceButton(
                      semanticsLabel: '로그인 방식 변경하기',
                      onTap: _changeLoginMethod,
                    ),
                  ),
                  Positioned(
                    key: const Key('certificate-issue'),
                    left: 650,
                    top: 2070,
                    width: 390,
                    height: 180,
                    child: _InvisibleReferenceButton(
                      semanticsLabel: 'NH인증서 발급 또는 재발급',
                      onTap: _changeLoginMethod,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: MediaQuery.paddingOf(context).top,
              child: const ColoredBox(
                key: Key('certificate-status-bar-background'),
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvisibleReferenceButton extends StatelessWidget {
  const _InvisibleReferenceButton({
    required this.semanticsLabel,
    required this.onTap,
  });

  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: const SizedBox.expand(),
      ),
    );
  }
}
