import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/auth_service.dart';
import '../core/pin_security.dart';
import 'auth_sheet.dart';
import 'app_loading_transition.dart';
import 'design_canvas.dart';
import 'entry_reference_canvas.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({
    super.key,
    required this.auth,
    this.showEntryLoading = false,
  });

  final AuthService auth;
  final bool showEntryLoading;

  @override
  State<PinScreen> createState() => _PinScreenState();
}

enum _AccessPinMode { loading, legacy, verify, create, confirm }

class _PinScreenState extends State<PinScreen> {
  static const _entryLoadingDuration = Duration(milliseconds: 600);
  static const _initialKeypadDigits = <int>[4, 7, 2, 6, 8, 5, 3, 9, 0, 1];
  static const _keyCenters = <Offset>[
    Offset(203, 1530),
    Offset(603, 1530),
    Offset(1003, 1530),
    Offset(203, 1767),
    Offset(603, 1767),
    Offset(1003, 1767),
    Offset(203, 2004),
    Offset(603, 2004),
    Offset(1003, 2004),
    Offset(603, 2244),
  ];
  static const _dotCenters = <double>[393, 477, 561, 645, 729, 813];
  static const _dotCenterY = 702.0;
  static const _dotDiameter = 52.0;

  final List<int> _digits = [];
  final List<int> _keypadDigits = List<int>.of(_initialKeypadDigits);
  _AccessPinMode _mode = _AccessPinMode.loading;
  String? _pendingPin;
  String? _setupError;
  int _failedAttempts = 0;
  bool _busy = false;
  bool _navigating = false;
  bool _keypadWasShuffled = false;
  Timer? _entryLoadingTimer;
  late bool _showEntryLoading;

  @override
  void initState() {
    super.initState();
    _showEntryLoading = widget.showEntryLoading;
    showDeviceStatusBar(darkIcons: true, backgroundColor: Colors.white);
    unawaited(_loadPinState());
    if (_showEntryLoading) {
      _entryLoadingTimer = Timer(_entryLoadingDuration, () {
        if (mounted) setState(() => _showEntryLoading = false);
      });
    }
  }

  @override
  void dispose() {
    _entryLoadingTimer?.cancel();
    super.dispose();
  }

  bool get _inputLocked =>
      _mode == _AccessPinMode.loading ||
      (_mode == _AccessPinMode.verify &&
          _failedAttempts >= PinSecurityService.maxAttempts);

  String get _enteredPin => _digits.join();

  String get _instruction => switch (_mode) {
    _AccessPinMode.create => '간편비밀번호 6자리를 설정해 주세요.',
    _AccessPinMode.confirm => '간편비밀번호 6자리를 다시 입력해 주세요.',
    _ => '간편비밀번호 6자리를 입력해 주세요.',
  };

  String? get _errorMessage {
    if (_setupError != null) return _setupError;
    if (_mode != _AccessPinMode.verify || _failedAttempts == 0) return null;
    return '비밀번호가 일치하지 않아요. ($_failedAttempts/${PinSecurityService.maxAttempts})';
  }

  Future<void> _loadPinState() async {
    if (!widget.auth.isSignedIn) {
      if (mounted) setState(() => _mode = _AccessPinMode.legacy);
      return;
    }
    final status = await widget.auth.pinStatus(PinPurpose.appAccess);
    if (!mounted) return;
    setState(() {
      _digits.clear();
      _pendingPin = null;
      _setupError = null;
      _failedAttempts = status.failedAttempts;
      _mode = status.configured ? _AccessPinMode.verify : _AccessPinMode.create;
    });
  }

  void _addDigit(int digit) {
    if (_digits.length == 6 || _navigating || _busy || _inputLocked) return;
    setState(() => _digits.add(digit));
    if (_digits.length == 6) {
      Future<void>.delayed(const Duration(milliseconds: 150), _submitPin);
    }
  }

  void _removeDigit() {
    if (_digits.isEmpty || _navigating || _busy || _inputLocked) return;
    setState(() => _digits.removeLast());
  }

  void _shuffle() {
    if (_busy || _inputLocked) return;
    setState(() {
      final previousOrder = List<int>.of(_keypadDigits);
      _keypadDigits.shuffle();
      if (_keypadDigits.indexed.every(
        (entry) => entry.$2 == previousOrder[entry.$1],
      )) {
        final first = _keypadDigits.first;
        _keypadDigits[0] = _keypadDigits[1];
        _keypadDigits[1] = first;
      }
      _keypadWasShuffled = true;
    });
  }

  Future<void> _submitPin() async {
    if (!mounted || _busy || _digits.length != 6) return;
    final pin = _enteredPin;
    switch (_mode) {
      case _AccessPinMode.loading:
        return;
      case _AccessPinMode.legacy:
        _openHome();
        return;
      case _AccessPinMode.create:
        setState(() {
          _pendingPin = pin;
          _digits.clear();
          _setupError = null;
          _mode = _AccessPinMode.confirm;
        });
        return;
      case _AccessPinMode.confirm:
        if (_pendingPin != pin) {
          setState(() {
            _digits.clear();
            _setupError = '비밀번호가 일치하지 않아요. 다시 입력해주세요.';
          });
          return;
        }
        setState(() => _busy = true);
        await widget.auth.setPin(PinPurpose.appAccess, pin);
        if (mounted) _openHome();
        return;
      case _AccessPinMode.verify:
        setState(() => _busy = true);
        final result = await widget.auth.verifyPin(PinPurpose.appAccess, pin);
        if (!mounted) return;
        if (result.matched) {
          _openHome();
          return;
        }
        setState(() {
          _busy = false;
          _digits.clear();
          _failedAttempts = result.failedAttempts;
        });
    }
  }

  Future<void> _resetPin() async {
    if (_busy || !widget.auth.isSignedIn) return;
    final authenticated = await showFirebaseReauthenticationSheet(
      context,
      auth: widget.auth,
    );
    if (!authenticated || !mounted) return;
    setState(() => _busy = true);
    await widget.auth.clearPin(PinPurpose.appAccess);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _digits.clear();
      _pendingPin = null;
      _setupError = null;
      _failedAttempts = 0;
      _mode = _AccessPinMode.create;
    });
  }

  void _openHome() {
    if (!mounted || _navigating) return;
    _navigating = true;
    Navigator.of(context).pushAndRemoveUntil<void>(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        pageBuilder: (_, animation, secondaryAnimation) =>
            AppLoadingTransition(auth: widget.auth),
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
        backgroundColor: Colors.white,
        body: Stack(
          fit: StackFit.expand,
          children: [
            EntryReferenceCanvas(
              asset: 'assets/images/entry_8_pin.png',
              backgroundColor: Colors.white,
              child: Stack(
                children: [
                  if (_mode == _AccessPinMode.create ||
                      _mode == _AccessPinMode.confirm)
                    const Positioned(
                      left: 150,
                      right: 150,
                      top: 330,
                      height: 330,
                      child: ColoredBox(color: Colors.white),
                    ),
                  if (_mode == _AccessPinMode.create ||
                      _mode == _AccessPinMode.confirm)
                    Positioned(
                      left: 120,
                      right: 120,
                      top: 385,
                      height: 260,
                      child: Column(
                        children: [
                          const Text(
                            'NH인증서',
                            style: TextStyle(
                              color: Color(0xFF111111),
                              fontSize: 70,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -2.5,
                            ),
                          ),
                          const SizedBox(height: 42),
                          Text(
                            _instruction,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF787878),
                              fontSize: 45,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Positioned(
                    key: Key('pin-close-cover'),
                    left: 1020,
                    top: 0,
                    width: 186,
                    height: 180,
                    child: ColoredBox(color: Colors.white),
                  ),
                  for (var index = 0; index < _digits.length; index++)
                    Positioned(
                      key: Key('app-pin-indicator-$index'),
                      left: _dotCenters[index] - (_dotDiameter / 2),
                      top: _dotCenterY - (_dotDiameter / 2),
                      width: _dotDiameter,
                      height: _dotDiameter,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFF149C4C),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  if (_errorMessage case final message?)
                    Positioned(
                      key: const Key('app-pin-error'),
                      left: 120,
                      right: 120,
                      top: 785,
                      height: 90,
                      child: Center(
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFD92D20),
                            fontSize: 31,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  if (_mode == _AccessPinMode.verify && _failedAttempts > 0)
                    Positioned(
                      left: 430,
                      top: 890,
                      width: 346,
                      height: 90,
                      child: FilledButton(
                        key: const Key('app-pin-reset'),
                        onPressed: _busy ? null : _resetPin,
                        style: FilledButton.styleFrom(
                          foregroundColor: const Color(0xFF202020),
                          backgroundColor: const Color(0xFFF1F3F4),
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                        child: const Text(
                          '비밀번호 재설정',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (_keypadWasShuffled)
                    for (var index = 0; index < _keyCenters.length; index++)
                      Positioned(
                        left: _keyCenters[index].dx - 108,
                        top: _keyCenters[index].dy - 68,
                        width: 216,
                        height: 136,
                        child: ColoredBox(
                          color: Colors.white,
                          child: Center(
                            child: Image.asset(
                              key: Key('app-pin-key-label-$index'),
                              'assets/images/pin_digit_${_keypadDigits[index]}.png',
                              width: 216,
                              height: 136,
                              fit: BoxFit.fill,
                              filterQuality: FilterQuality.high,
                              excludeFromSemantics: true,
                            ),
                          ),
                        ),
                      ),
                  for (var index = 0; index < _keypadDigits.length; index++)
                    Positioned(
                      key: Key('app-pin-key-${_keypadDigits[index]}'),
                      left: _keyCenters[index].dx - 108,
                      top: _keyCenters[index].dy - 68,
                      width: 216,
                      height: 136,
                      child: Semantics(
                        button: true,
                        label: '숫자 ${_keypadDigits[index]}',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _addDigit(_keypadDigits[index]),
                        ),
                      ),
                    ),
                  Positioned(
                    key: const Key('app-pin-rearrange'),
                    left: 92,
                    top: 2155,
                    width: 225,
                    height: 180,
                    child: Semantics(
                      button: true,
                      label: '숫자 재배열',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _shuffle,
                      ),
                    ),
                  ),
                  Positioned(
                    key: const Key('app-pin-delete'),
                    left: 890,
                    top: 2155,
                    width: 225,
                    height: 180,
                    child: Semantics(
                      button: true,
                      label: '한 자리 지우기',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _removeDigit,
                      ),
                    ),
                  ),
                  if (_showEntryLoading)
                    const Positioned.fill(
                      key: Key('pin-entry-loading'),
                      child: _PinEntryLoadingMask(),
                    ),
                ],
              ),
            ),
            if (_showEntryLoading)
              Positioned(
                left: 0,
                right: 0,
                top: padding.top,
                bottom: padding.bottom,
                child: const IgnorePointer(
                  child: Align(
                    alignment: Alignment(0, -0.03),
                    child: SizedBox.square(
                      key: Key('pin-entry-loading-logo'),
                      dimension: 72,
                      child: Image(
                        key: Key('pin-entry-loading-animation'),
                        image: AssetImage(
                          'assets/images/loading_certificate_to_pin.png',
                        ),
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        gaplessPlayback: true,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PinEntryLoadingMask extends StatelessWidget {
  const _PinEntryLoadingMask();

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: const Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 630,
            bottom: 0,
            child: ColoredBox(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
