import 'package:flutter/material.dart';

import '../core/auth_service.dart';

const _green = Color(0xFF1AA35A);
const _darkGreen = Color(0xFF087A43);
const _ink = Color(0xFF171A1F);
const _muted = Color(0xFF737A86);
const _fieldFill = Color(0xFFF5F7F6);

Future<bool> showAuthSheet(
  BuildContext context, {
  required AuthService auth,
  AuthMode initialMode = AuthMode.signIn,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AuthSheet(
      auth: auth,
      initialMode: initialMode,
      reauthenticateOnly: false,
    ),
  );
  return result ?? false;
}

Future<bool> showFirebaseReauthenticationSheet(
  BuildContext context, {
  required AuthService auth,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AuthSheet(
      auth: auth,
      initialMode: AuthMode.signIn,
      reauthenticateOnly: true,
    ),
  );
  return result ?? false;
}

class _AuthSheet extends StatefulWidget {
  const _AuthSheet({
    required this.auth,
    required this.initialMode,
    required this.reauthenticateOnly,
  });

  final AuthService auth;
  final AuthMode initialMode;
  final bool reauthenticateOnly;

  @override
  State<_AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<_AuthSheet> {
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late AuthMode _mode = widget.initialMode;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    if (widget.reauthenticateOnly) {
      _emailController.text = widget.auth.currentEmail ?? '';
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = widget.reauthenticateOnly
        ? await widget.auth.reauthenticate(
            email: _emailController.text,
            password: _passwordController.text,
          )
        : await widget.auth.authenticate(
            mode: _mode,
            email: _emailController.text,
            password: _passwordController.text,
            displayName: _mode == AuthMode.register
                ? _displayNameController.text
                : null,
          );
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _message = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final isSignIn = _mode == AuthMode.signIn;
    final title = widget.reauthenticateOnly
        ? '계정을 확인해 주세요'
        : isSignIn
        ? '안녕하세요!'
        : '올원뱅크를 시작해요';
    final description = widget.reauthenticateOnly
        ? '안전한 이용을 위해 비밀번호를 다시 입력해 주세요.'
        : isSignIn
        ? '로그인하고 나만의 금융 생활을 시작하세요.'
        : '간단한 정보 입력으로 안전하게 가입할 수 있어요.';

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Color(0x24000000),
              blurRadius: 28,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD7DBD9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        key: const Key('auth-sheet-brand'),
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_green, _darkGreen],
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x331AA35A),
                              blurRadius: 12,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          color: Colors.white,
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NH올원뱅크',
                            style: TextStyle(
                              color: _ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '안전한 금융의 시작',
                            style: TextStyle(
                              color: _muted,
                              fontSize: 12,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        key: const Key('auth-sheet-close'),
                        tooltip: '닫기',
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close_rounded),
                        color: const Color(0xFF5F666F),
                        style: IconButton.styleFrom(
                          backgroundColor: _fieldFill,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 28,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 14,
                      height: 1.45,
                      letterSpacing: -0.25,
                    ),
                  ),
                  if (!widget.reauthenticateOnly) ...[
                    const SizedBox(height: 22),
                    _AuthModeSelector(
                      mode: _mode,
                      busy: _busy,
                      onChanged: (mode) => setState(() {
                        _mode = mode;
                        _message = null;
                      }),
                    ),
                  ],
                  const SizedBox(height: 20),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: _mode == AuthMode.register
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextField(
                              key: const Key('register-display-name'),
                              controller: _displayNameController,
                              textCapitalization: TextCapitalization.words,
                              autocorrect: false,
                              autofillHints: const [AutofillHints.name],
                              decoration: _fieldDecoration(
                                label: '표시 이름',
                                hint: '예: BUI PHUONG',
                                icon: Icons.person_outline_rounded,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  TextField(
                    key: const Key('auth-email'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    readOnly: widget.reauthenticateOnly,
                    autofillHints: const [AutofillHints.email],
                    decoration: _fieldDecoration(
                      label: '이메일',
                      hint: 'example@email.com',
                      icon: Icons.mail_outline_rounded,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('auth-password'),
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) {
                      if (!_busy) _submit();
                    },
                    decoration: _fieldDecoration(
                      label: '비밀번호',
                      hint: '비밀번호를 입력해 주세요',
                      icon: Icons.lock_outline_rounded,
                      suffix: IconButton(
                        key: const Key('auth-password-visibility'),
                        tooltip: _obscurePassword ? '비밀번호 보기' : '비밀번호 숨기기',
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 21,
                        ),
                      ),
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      key: const Key('auth-error-message'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFD83B45),
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _message!,
                              style: const TextStyle(
                                color: Color(0xFFB52D38),
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: _busy
                          ? null
                          : const [
                              BoxShadow(
                                color: Color(0x331AA35A),
                                blurRadius: 14,
                                offset: Offset(0, 6),
                              ),
                            ],
                    ),
                    child: FilledButton(
                      key: widget.reauthenticateOnly
                          ? const Key('reauthenticate-submit')
                          : const Key('authenticate-submit'),
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _green,
                        disabledBackgroundColor: const Color(0xFFA9D8BD),
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lock_open_rounded, size: 19),
                                const SizedBox(width: 7),
                                Text(
                                  widget.reauthenticateOnly
                                      ? '확인'
                                      : isSignIn
                                      ? '로그인'
                                      : '회원가입',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (!widget.reauthenticateOnly)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _mode = isSignIn
                                  ? AuthMode.register
                                  : AuthMode.signIn;
                              _message = null;
                            }),
                      child: Text(
                        isSignIn ? '계정이 없으신가요? 회원가입' : '이미 계정이 있으신가요? 로그인',
                        style: const TextStyle(
                          color: _darkGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.auth.firebaseReady
                            ? Icons.verified_user_outlined
                            : Icons.shield_outlined,
                        color: const Color(0xFF89918D),
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.auth.firebaseReady
                            ? 'Firebase 보안 인증으로 안전하게 보호됩니다'
                            : '입력한 정보는 안전하게 보호됩니다',
                        style: const TextStyle(
                          color: Color(0xFF89918D),
                          fontSize: 11,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(15)),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 21),
      suffixIcon: suffix,
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      labelStyle: const TextStyle(color: _muted, fontSize: 14),
      hintStyle: const TextStyle(color: Color(0xFFA4AAA7), fontSize: 13),
      prefixIconColor: const Color(0xFF747D78),
      suffixIconColor: const Color(0xFF747D78),
      border: border,
      enabledBorder: border,
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(15)),
        borderSide: BorderSide(color: _green, width: 1.5),
      ),
    );
  }
}

class _AuthModeSelector extends StatelessWidget {
  const _AuthModeSelector({
    required this.mode,
    required this.busy,
    required this.onChanged,
  });

  final AuthMode mode;
  final bool busy;
  final ValueChanged<AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _fieldFill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AuthModeButton(
              key: const Key('auth-mode-sign-in'),
              label: '로그인',
              selected: mode == AuthMode.signIn,
              onTap: busy ? null : () => onChanged(AuthMode.signIn),
            ),
          ),
          Expanded(
            child: _AuthModeButton(
              key: const Key('auth-mode-register'),
              label: '회원가입',
              selected: mode == AuthMode.register,
              onTap: busy ? null : () => onChanged(AuthMode.register),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthModeButton extends StatelessWidget {
  const _AuthModeButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      elevation: selected ? 1 : 0,
      shadowColor: const Color(0x22000000),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? _darkGreen : _muted,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
