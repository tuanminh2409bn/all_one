import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/app_data.dart';
import '../core/auth_service.dart';
import '../core/bank_catalog.dart';
import '../core/pin_security.dart';
import 'auth_sheet.dart';
import 'bank_logo.dart';
import 'data_management_screen.dart';
import 'design_canvas.dart';

const _ink = Color(0xFF111827);
const _muted = Color(0xFF818A99);
const _line = Color(0xFFD9DDE5);
const _blue = Color(0xFF0969F6);
const _pinBlue = Color(0xFF005DFA);
const _recipientInk = Color(0xFF303846);
const _recipientMuted = Color(0xFF657084);
const _recipientPlaceholder = Color(0xFF8A93A4);
const _recipientSectionStyle = TextStyle(
  color: _recipientInk,
  fontSize: 20,
  fontWeight: FontWeight.w500,
  fontVariations: [FontVariation('wght', 580)],
  letterSpacing: -.45,
);
const _amountSourceHeaderStyle = TextStyle(
  fontSize: 23,
  fontWeight: FontWeight.w700,
);

enum TransferFlowResult { failed }

Future<void> showTransferFailurePopup(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0x8A000000),
    builder: (_) => const _TransferFailurePopup(),
  );
}

enum _TransferStage { recipient, amount, confirmation, pin }

enum _TransferPinMode { legacy, loading, verify, create, confirm }

class TransferRecipientScreen extends StatefulWidget {
  TransferRecipientScreen({
    super.key,
    AppDataStore? dataStore,
    this.auth,
    this.initialPinKeys,
  }) : assert(initialPinKeys == null || initialPinKeys.length == 10),
       dataStore = dataStore ?? AppDataStore.shared;

  final AppDataStore dataStore;
  final AuthService? auth;
  @visibleForTesting
  final List<String>? initialPinKeys;

  @override
  State<TransferRecipientScreen> createState() =>
      _TransferRecipientScreenState();
}

class _TransferRecipientScreenState extends State<TransferRecipientScreen> {
  _TransferStage _stage = _TransferStage.recipient;
  bool _manualEntry = false;
  bool _favoriteRecipientsExpanded = false;
  bool _myAccountsExpanded = false;
  bool _recentRecipientsExpanded = true;
  bool _reviewDetailsExpanded = true;
  bool _sourceAccountSelectorVisible = false;
  String _account = '';
  String? _bank;
  String? _recipientName;
  String? _destinationAccountId;
  int _amount = 0;
  String? _sourceAccountId;
  final List<String> _pinDigits = [];
  List<String> _pinKeys = const [];
  _TransferPinMode _pinMode = _TransferPinMode.legacy;
  String? _pendingTransferPin;
  String? _pinSetupError;
  int _pinFailedAttempts = 0;
  bool _pinBusy = false;

  @override
  void initState() {
    super.initState();
    showDeviceStatusBar(darkIcons: true, backgroundColor: Colors.white);
    widget.dataStore.addListener(_handleDataChange);
  }

  @override
  void dispose() {
    widget.dataStore.removeListener(_handleDataChange);
    super.dispose();
  }

  void _handleDataChange() {
    if (mounted) setState(() {});
  }

  List<_SourceAccount> get _availableSourceAccounts => [
    for (final account in widget.dataStore.accounts)
      _SourceAccount(
        id: account.id,
        productName: account.accountType,
        bankCode: account.bankCode,
        bank: account.bankDisplayName,
        ownerName: account.ownerName,
        accountNumber: account.accountNumber,
        availableBalance: widget.dataStore.balanceFor(account.id),
      ),
  ];

  _SourceAccount? get _selectedSourceAccount {
    final accounts = _availableSourceAccounts;
    if (accounts.isEmpty) return null;
    for (final account in accounts) {
      if (account.id == _sourceAccountId) return account;
    }
    return accounts.first;
  }

  bool get _canContinue =>
      _account.isNotEmpty && _bank != null && _selectedSourceAccount != null;

  void _back() {
    if (_stage == _TransferStage.pin) {
      setState(() => _stage = _TransferStage.confirmation);
    } else if (_stage == _TransferStage.confirmation) {
      setState(() => _stage = _TransferStage.amount);
    } else if (_stage == _TransferStage.amount) {
      setState(() => _stage = _TransferStage.recipient);
    } else if (_manualEntry) {
      setState(() => _manualEntry = false);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _appendAccount(String key) => setState(() {
    // Korean account numbers are numeric and do not exceed 30 digits. The
    // cap prevents an accidental long press from creating an unusable entry.
    if (_account.length + key.length <= 30) _account += key;
  });
  void _deleteAccount() => setState(() {
    if (_account.isNotEmpty) {
      _account = _account.substring(0, _account.length - 1);
    }
  });

  List<_Recipient> get _accountSuggestions {
    final query = AppDataStore.normalizedAccountNumber(_account);
    if (query.length < 4) return const [];

    final seenAccounts = <String>{};
    final matches = <(int score, int order, _Recipient recipient)>[];
    var order = 0;
    for (final recipient in [..._savedRecipients, ..._ownAccounts]) {
      final accountNumber = AppDataStore.normalizedAccountNumber(
        recipient.account,
      );
      final bankCode = recipient.bankCode ?? recipient.bank;
      final uniqueKey = '$bankCode:$accountNumber';
      final score = accountNumber.startsWith(query)
          ? 0
          : accountNumber.contains(query)
          ? 1
          : -1;
      if (score >= 0 && seenAccounts.add(uniqueKey)) {
        matches.add((score, order, recipient));
      }
      order += 1;
    }
    matches.sort((first, second) {
      final byRelevance = first.$1.compareTo(second.$1);
      return byRelevance != 0 ? byRelevance : first.$2.compareTo(second.$2);
    });
    return [
      for (final match in matches.take(AppDataStore.maxSavedRecipients))
        match.$3,
    ];
  }

  void _appendAmount(String key) => setState(() {
    final digits = key == '00' ? 2 : 1;
    for (var i = 0; i < digits; i++) {
      _amount *= 10;
    }
    if (key != '00') _amount += int.parse(key);
  });
  void _deleteAmount() => setState(() => _amount ~/= 10);

  Future<void> _pickBank() async {
    final selected = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '은행 선택 닫기',
      barrierColor: const Color(0x8B27303E),
      pageBuilder: (_, __, ___) => _BankSelectorDialog(initialBank: _bank),
    );
    if (selected != null && mounted) setState(() => _bank = selected);
  }

  void _chooseRecipient(_Recipient recipient) {
    if (_selectedSourceAccount == null) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('출금 계좌가 없습니다'),
          content: const Text('출금 계좌를 먼저 추가해주세요.'),
          actions: [
            FilledButton(
              key: const Key('missing-source-confirm'),
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() {
      _bank = recipient.bank;
      _account = recipient.account;
      _recipientName = recipient.name;
      _destinationAccountId = recipient.internalAccountId;
      _stage = _TransferStage.amount;
    });
  }

  _Recipient? get _matchingManualRecipient {
    final selectedBank = _bank;
    final normalizedAccount = AppDataStore.normalizedAccountNumber(_account);
    if (selectedBank == null || normalizedAccount.isEmpty) return null;

    for (final recipient in [..._savedRecipients, ..._ownAccounts]) {
      final isSameBank =
          recipient.bank == selectedBank || recipient.bankCode == selectedBank;
      final isSameAccount =
          AppDataStore.normalizedAccountNumber(recipient.account) ==
          normalizedAccount;
      if (isSameBank && isSameAccount) return recipient;
    }
    return null;
  }

  void _continueManualEntry() {
    final recipient = _matchingManualRecipient;
    setState(() {
      // Matching ignores separators so a digits-only manual entry can still
      // restore the exact presentation saved for this recipient. The amount
      // screen mirrors that saved account number, including hyphens.
      if (recipient != null) _account = recipient.account;
      _recipientName = recipient?.name;
      _destinationAccountId = recipient?.internalAccountId;
      _stage = _TransferStage.amount;
    });
  }

  List<_Recipient> get _savedRecipients {
    final recipients = widget.dataStore.recipients.toList()
      ..sort((first, second) {
        if (first.favorite == second.favorite) return 0;
        return first.favorite ? -1 : 1;
      });
    return [
      for (final recipient in recipients.take(AppDataStore.maxSavedRecipients))
        _Recipient(
          recipient.displayName,
          recipient.bankCode,
          recipient.accountNumber,
          BankCatalog.logoAsset(recipient.bankCode),
          bankCode: recipient.bankCode,
          recipientId: recipient.id,
          favorite: recipient.favorite,
        ),
    ];
  }

  List<_Recipient> get _ownAccounts => [
    for (final account in widget.dataStore.accounts)
      _Recipient(
        account.accountType,
        account.bankDisplayName,
        account.accountNumber,
        BankCatalog.logoAsset(account.bankCode),
        bankCode: account.bankCode,
        internalAccountId: account.id,
      ),
  ];

  Future<void> _openRecipientManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            DataManagementScreen(store: widget.dataStore, initialTab: 2),
      ),
    );
  }

  void _startManualEntry() {
    setState(() {
      _manualEntry = true;
      _account = '';
      _bank = null;
      _recipientName = null;
      _destinationAccountId = null;
    });
  }

  Future<void> _searchRecipients() async {
    final selected = await showSearch<_Recipient?>(
      context: context,
      delegate: _RecipientSearchDelegate([
        ..._ownAccounts,
        ..._savedRecipients,
      ]),
    );
    if (selected != null && mounted) _chooseRecipient(selected);
  }

  Future<void> _toggleFavorite(_Recipient recipient) async {
    final recipientId = recipient.recipientId;
    if (recipientId == null) return;
    for (final saved in widget.dataStore.recipients) {
      if (saved.id == recipientId) {
        await widget.dataStore.saveRecipient(
          saved.copyWith(favorite: !saved.favorite),
        );
        return;
      }
    }
  }

  void _startPinEntry() {
    final needsProtectedPin = widget.auth?.isSignedIn ?? false;
    setState(() {
      _pinDigits.clear();
      _pinKeys = List<String>.unmodifiable(
        widget.initialPinKeys ?? _shuffledPinKeys(),
      );
      _pinMode = needsProtectedPin
          ? _TransferPinMode.loading
          : _TransferPinMode.legacy;
      _pendingTransferPin = null;
      _pinSetupError = null;
      _pinFailedAttempts = 0;
      _pinBusy = false;
      _stage = _TransferStage.pin;
    });
    if (needsProtectedPin) unawaited(_loadTransferPinState());
  }

  Future<void> _loadTransferPinState() async {
    final auth = widget.auth;
    if (auth == null || !auth.isSignedIn) return;
    final status = await auth.pinStatus(PinPurpose.transfer);
    if (!mounted) return;
    setState(() {
      _pinDigits.clear();
      _pendingTransferPin = null;
      _pinSetupError = null;
      _pinFailedAttempts = status.failedAttempts;
      _pinMode = status.configured
          ? _TransferPinMode.verify
          : _TransferPinMode.create;
    });
  }

  List<String> _shuffledPinKeys([List<String>? previous]) {
    final keys = List<String>.generate(10, (index) => '$index');
    keys.shuffle(Random());
    // A re-arrange action must visibly change the layout even in the very
    // unlikely event that a random shuffle returns the previous permutation.
    if (previous != null && _samePinOrder(keys, previous)) {
      final first = keys.removeAt(0);
      keys.add(first);
    }
    return keys;
  }

  bool _samePinOrder(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  void _rearrangePinKeys() {
    if (_pinInputLocked || _pinBusy) return;
    setState(() => _pinKeys = _shuffledPinKeys(_pinKeys));
  }

  void _deletePinDigit() {
    if (_pinDigits.isNotEmpty && !_pinInputLocked && !_pinBusy) {
      setState(_pinDigits.removeLast);
    }
  }

  Future<void> _appendPinDigit(String digit) async {
    if (_pinDigits.length >= 4 || _pinInputLocked || _pinBusy) return;
    var completed = false;
    setState(() {
      _pinDigits.add(digit);
      completed = _pinDigits.length == 4;
    });
    if (!completed) return;
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (mounted) await _submitTransferPin();
  }

  bool get _pinInputLocked =>
      _pinMode == _TransferPinMode.loading ||
      (_pinMode == _TransferPinMode.verify &&
          _pinFailedAttempts >= PinSecurityService.maxAttempts);

  String get _enteredTransferPin => _pinDigits.join();

  String get _transferPinTitle => switch (_pinMode) {
    _TransferPinMode.create => '계좌 비밀번호 설정',
    _TransferPinMode.confirm => '비밀번호 다시 입력',
    _ => '계좌 비밀번호',
  };

  String? get _transferPinError {
    if (_pinSetupError != null) return _pinSetupError;
    if (_pinMode != _TransferPinMode.verify || _pinFailedAttempts == 0) {
      return null;
    }
    return '비밀번호가 일치하지 않아요. ($_pinFailedAttempts/${PinSecurityService.maxAttempts})';
  }

  Future<void> _submitTransferPin() async {
    if (!mounted || _pinBusy || _pinDigits.length != 4) return;
    final pin = _enteredTransferPin;
    final auth = widget.auth;
    switch (_pinMode) {
      case _TransferPinMode.loading:
        return;
      case _TransferPinMode.legacy:
        await _completeTransferAfterPin();
        return;
      case _TransferPinMode.create:
        setState(() {
          _pendingTransferPin = pin;
          _pinDigits.clear();
          _pinSetupError = null;
          _pinMode = _TransferPinMode.confirm;
        });
        return;
      case _TransferPinMode.confirm:
        if (_pendingTransferPin != pin) {
          setState(() {
            _pinDigits.clear();
            _pinSetupError = '비밀번호가 일치하지 않아요. 다시 입력해주세요.';
          });
          return;
        }
        if (auth == null) return;
        setState(() => _pinBusy = true);
        await auth.setPin(PinPurpose.transfer, pin);
        if (!mounted) return;
        await _completeTransferAfterPin();
        return;
      case _TransferPinMode.verify:
        if (auth == null) return;
        setState(() => _pinBusy = true);
        final result = await auth.verifyPin(PinPurpose.transfer, pin);
        if (!mounted) return;
        if (result.matched) {
          await _completeTransferAfterPin();
          return;
        }
        setState(() {
          _pinBusy = false;
          _pinDigits.clear();
          _pinFailedAttempts = result.failedAttempts;
        });
    }
  }

  Future<void> _resetTransferPin() async {
    final auth = widget.auth;
    if (auth == null || _pinBusy || !auth.isSignedIn) return;
    final authenticated = await showFirebaseReauthenticationSheet(
      context,
      auth: auth,
    );
    if (!authenticated || !mounted) return;
    setState(() => _pinBusy = true);
    await auth.clearPin(PinPurpose.transfer);
    if (!mounted) return;
    setState(() {
      _pinBusy = false;
      _pinDigits.clear();
      _pendingTransferPin = null;
      _pinSetupError = null;
      _pinFailedAttempts = 0;
      _pinMode = _TransferPinMode.create;
    });
  }

  Future<void> _completeTransferAfterPin() async {
    final source = _selectedSourceAccount;
    if (source == null || _amount <= 0) return;
    if (!mounted) return;
    await _returnToHome();
  }

  Future<void> _returnToHome() async {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(TransferFlowResult.failed);
      return;
    }
    await showTransferFailurePopup(context);
  }

  @override
  Widget build(BuildContext context) {
    final sourceAccount = _selectedSourceAccount;
    final androidPinFullBleed =
        _stage == _TransferStage.pin &&
        Theme.of(context).platform == TargetPlatform.android;
    final actionButtonBottom = _stage == _TransferStage.amount
        ? 20.0
        : _stage == _TransferStage.confirmation
        ? 48.0
        : 54.0;
    final actionButtonHeight = _stage == _TransferStage.confirmation
        ? 78.0
        : 79.0;
    return PopScope(
      onPopInvokedWithResult: (_, __) => showDeviceStatusBar(
        darkIcons: true,
        backgroundColor: const Color(0xFFF0F3FA),
      ),
      child: DesignCanvas(
        fullWidthBottomColor: androidPinFullBleed ? _pinBlue : null,
        fullWidthBottomTop: androidPinFullBleed ? 870 : null,
        fullWidthBottomKey: androidPinFullBleed
            ? const Key('android-transfer-pin-blue-background')
            : null,
        child: Material(
          color: Colors.white,
          child: Stack(
            children: [
              _TopControls(
                onBack: _back,
                onManageRecipients: _openRecipientManagement,
                showBack: _stage != _TransferStage.pin,
                showRecipientActions:
                    _stage == _TransferStage.recipient && !_manualEntry,
              ),
              if (_stage == _TransferStage.confirmation)
                _TransferReviewPage(
                  sourceAccount: sourceAccount!,
                  bank: _bank ?? '토스뱅크',
                  // The final review intentionally follows the banking
                  // reference and shows the destination as digits only.
                  account: AppDataStore.normalizedAccountNumber(_account),
                  recipientName: _recipientName,
                  recipientUsesHonorific: _destinationAccountId == null,
                  amount: _amount,
                  detailsExpanded: _reviewDetailsExpanded,
                  onToggleDetails: () => setState(
                    () => _reviewDetailsExpanded = !_reviewDetailsExpanded,
                  ),
                )
              else if (_stage == _TransferStage.pin)
                _TransferPinPage(
                  title: _transferPinTitle,
                  enteredDigits: _pinDigits.length,
                  keys: _pinKeys,
                  errorMessage: _transferPinError,
                  showReset:
                      _pinMode == _TransferPinMode.verify &&
                      _pinFailedAttempts > 0,
                  inputEnabled: !_pinInputLocked && !_pinBusy,
                  onDigit: _appendPinDigit,
                  onDelete: _deletePinDigit,
                  onRearrange: _rearrangePinKeys,
                  onReset: _resetTransferPin,
                )
              else if (_stage == _TransferStage.amount && sourceAccount != null)
                _AmountPage(
                  sourceAccount: sourceAccount,
                  bank: _bank ?? '토스뱅크',
                  account: _account.isEmpty ? '100237698805' : _account,
                  recipientName: _recipientName,
                  recipientUsesHonorific: _destinationAccountId == null,
                  amount: _amount,
                  onDigit: _appendAmount,
                  onDelete: _deleteAmount,
                  onChooseSourceAccount: () =>
                      setState(() => _sourceAccountSelectorVisible = true),
                )
              else if (_manualEntry)
                _ManualEntry(
                  account: _account,
                  bank: _bank,
                  suggestions: _accountSuggestions,
                  onDigit: _appendAccount,
                  onDelete: _deleteAccount,
                  onClear: () => setState(() => _account = ''),
                  onChooseBank: _pickBank,
                  onSelectSuggestion: _chooseRecipient,
                )
              else
                _RecipientLanding(
                  ownAccounts: _ownAccounts,
                  recipients: _savedRecipients,
                  favoriteRecipientsExpanded: _favoriteRecipientsExpanded,
                  myAccountsExpanded: _myAccountsExpanded,
                  recentRecipientsExpanded: _recentRecipientsExpanded,
                  onSearch: _searchRecipients,
                  onEditFavorites: _openRecipientManagement,
                  onToggleFavoriteRecipients: () => setState(
                    () => _favoriteRecipientsExpanded =
                        !_favoriteRecipientsExpanded,
                  ),
                  onToggleMyAccounts: () => setState(
                    () => _myAccountsExpanded = !_myAccountsExpanded,
                  ),
                  onToggleRecentRecipients: () => setState(
                    () =>
                        _recentRecipientsExpanded = !_recentRecipientsExpanded,
                  ),
                  onManual: _startManualEntry,
                  onCamera: _startManualEntry,
                  onSelect: _chooseRecipient,
                  onToggleFavorite: _toggleFavorite,
                ),
              if ((_stage != _TransferStage.recipient || _manualEntry) &&
                  _stage != _TransferStage.pin)
                Positioned(
                  left: 28,
                  right: 28,
                  bottom: actionButtonBottom,
                  height: actionButtonHeight,
                  child: FilledButton(
                    key: const Key('transfer-next'),
                    onPressed: _stage == _TransferStage.amount
                        ? (_amount > 0
                              ? () => setState(() {
                                  _reviewDetailsExpanded = true;
                                  _stage = _TransferStage.confirmation;
                                })
                              : null)
                        : (_stage == _TransferStage.confirmation
                              ? _startPinEntry
                              : _canContinue && sourceAccount != null
                              ? _continueManualEntry
                              : null),
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      disabledBackgroundColor: const Color(0xFFF0F3F8),
                      disabledForegroundColor: const Color(0xFF98A1B1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _stage == _TransferStage.confirmation ? '보내기' : '다음',
                      style: TextStyle(
                        fontSize: _manualEntry ? 22 : 23,
                        fontWeight: _manualEntry
                            ? FontWeight.w500
                            : FontWeight.w700,
                        fontVariations: [
                          FontVariation('wght', _manualEntry ? 500 : 700),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_sourceAccountSelectorVisible)
                _SourceAccountSelector(
                  accounts: _availableSourceAccounts,
                  selectedAccount: sourceAccount!,
                  onSelect: (account) => setState(() {
                    _sourceAccountId = account.id;
                    _sourceAccountSelectorVisible = false;
                  }),
                  onClose: () =>
                      setState(() => _sourceAccountSelectorVisible = false),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopControls extends StatelessWidget {
  const _TopControls({
    required this.onBack,
    required this.onManageRecipients,
    required this.showBack,
    required this.showRecipientActions,
  });
  final VoidCallback onBack;
  final VoidCallback onManageRecipients;
  final bool showBack;
  final bool showRecipientActions;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (showBack)
        Positioned(
          left: 24,
          top: 111,
          child: IconButton(
            key: const Key('transfer-back'),
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 24),
          ),
        ),
      if (showRecipientActions)
        const Positioned(
          right: 142,
          top: 120,
          child: Text(
            '다건이체',
            key: Key('transfer-multiple'),
            style: TextStyle(
              color: _blue,
              fontSize: 20,
              fontWeight: FontWeight.w500,
              fontVariations: [FontVariation('wght', 560)],
              letterSpacing: -.1,
            ),
          ),
        ),
      if (showRecipientActions)
        Positioned(
          right: 89,
          top: 99,
          width: 45,
          height: 45,
          child: IconButton(
            key: const Key('transfer-quick-recipient'),
            onPressed: onManageRecipients,
            padding: const EdgeInsets.all(6.5),
            icon: const _RecipientQuickTransferIcon(),
          ),
        ),
      Positioned(
        right: 21,
        top: 110,
        child: IconButton(
          key: const Key('transfer-home'),
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
          icon: const _TransferCloseIcon(),
        ),
      ),
    ],
  );
}

class _RecipientQuickTransferIcon extends StatelessWidget {
  const _RecipientQuickTransferIcon();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _RecipientQuickTransferPainter());
  }
}

class _TransferCloseIcon extends StatelessWidget {
  const _TransferCloseIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 30,
      child: CustomPaint(painter: _TransferClosePainter()),
    );
  }
}

class _TransferClosePainter extends CustomPainter {
  const _TransferClosePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(const Offset(5.5, 5.5), const Offset(24.5, 24.5), paint)
      ..drawLine(const Offset(24.5, 5.5), const Offset(5.5, 24.5), paint);
  }

  @override
  bool shouldRepaint(_TransferClosePainter oldDelegate) => false;
}

class _RecipientQuickTransferPainter extends CustomPainter {
  const _RecipientQuickTransferPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawCircle(const Offset(10, 7), 4, paint);

    final person = Path()
      ..moveTo(4, 22)
      ..cubicTo(5, 16.5, 7.5, 14, 11, 14)
      ..cubicTo(13.5, 14, 15, 15, 16, 16.5);
    canvas.drawPath(person, paint);

    final arrow = Path()
      ..moveTo(16, 22)
      ..lineTo(26, 22)
      ..moveTo(22, 18)
      ..lineTo(26, 22)
      ..lineTo(22, 27);
    canvas.drawPath(arrow, paint);
  }

  @override
  bool shouldRepaint(_RecipientQuickTransferPainter oldDelegate) => false;
}

class _RecipientLanding extends StatelessWidget {
  const _RecipientLanding({
    required this.ownAccounts,
    required this.recipients,
    required this.favoriteRecipientsExpanded,
    required this.myAccountsExpanded,
    required this.recentRecipientsExpanded,
    required this.onSearch,
    required this.onEditFavorites,
    required this.onToggleFavoriteRecipients,
    required this.onToggleMyAccounts,
    required this.onToggleRecentRecipients,
    required this.onManual,
    required this.onCamera,
    required this.onSelect,
    required this.onToggleFavorite,
  });
  final List<_Recipient> ownAccounts;
  final List<_Recipient> recipients;
  final bool favoriteRecipientsExpanded;
  final bool myAccountsExpanded;
  final bool recentRecipientsExpanded;
  final VoidCallback onSearch;
  final VoidCallback onEditFavorites;
  final VoidCallback onToggleFavoriteRecipients;
  final VoidCallback onToggleMyAccounts;
  final VoidCallback onToggleRecentRecipients;
  final VoidCallback onManual;
  final VoidCallback onCamera;
  final ValueChanged<_Recipient> onSelect;
  final ValueChanged<_Recipient> onToggleFavorite;
  @override
  Widget build(BuildContext context) {
    final favoriteRecipients = recipients
        .where((recipient) => recipient.favorite)
        .toList(growable: false);
    final favoriteOffset = favoriteRecipientsExpanded
        ? favoriteRecipients.length * 97.0
        : 0.0;
    final ownAccountsOffset = myAccountsExpanded
        ? ownAccounts.length * 97.0
        : 0.0;
    final recentOffset = favoriteOffset + ownAccountsOffset;
    return Stack(
      children: [
        const Positioned(
          left: 28,
          top: 201,
          child: Text(
            '누구에게 보낼까요?',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w600,
              fontVariations: [FontVariation('wght', 650)],
              letterSpacing: -1.5,
            ),
          ),
        ),
        Positioned(
          right: 26,
          top: 196,
          child: _SquareIcon(
            key: const Key('transfer-recipient-search'),
            icon: Icons.search_rounded,
            onTap: onSearch,
          ),
        ),
        Positioned(
          left: 28,
          right: 28,
          top: 283,
          height: 70,
          child: InkWell(
            key: const Key('transfer-manual-entry'),
            onTap: onManual,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Transform.translate(
                offset: const Offset(0, -5),
                child: const Text(
                  '계좌번호 직접 입력',
                  style: TextStyle(
                    fontSize: 21,
                    color: _recipientPlaceholder,
                    fontWeight: FontWeight.w400,
                    fontVariations: [FontVariation('wght', 470)],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 28,
          top: 296,
          child: IconButton(
            key: const Key('transfer-camera'),
            onPressed: onCamera,
            icon: const Icon(Icons.photo_camera_outlined, size: 30),
          ),
        ),
        const Positioned(
          left: 28,
          right: 28,
          top: 354,
          child: Divider(color: _line, height: 1),
        ),
        const Positioned(
          left: 28,
          top: 387,
          child: Text(
            '자주쓰는 계좌',
            key: Key('transfer-favorite-label'),
            style: _recipientSectionStyle,
          ),
        ),
        Positioned(
          left: 152,
          top: 382,
          width: 49,
          height: 36,
          child: TextButton(
            key: const Key('transfer-favorite-edit'),
            onPressed: onEditFavorites,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: _recipientInk,
              backgroundColor: const Color(0xFFF3F5F8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            child: const Text(
              '편집',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontVariations: [FontVariation('wght', 560)],
              ),
            ),
          ),
        ),
        Positioned(
          right: 28,
          top: 375,
          child: _CountChip(
            '${favoriteRecipients.length}개',
            favoriteRecipientsExpanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            key: const Key('transfer-favorite-toggle'),
            onTap: onToggleFavoriteRecipients,
          ),
        ),
        if (favoriteRecipientsExpanded)
          ...List.generate(
            favoriteRecipients.length,
            (index) => Positioned(
              left: 28,
              right: 25,
              top: 431 + (index * 97),
              height: 78,
              child: _RecipientRow(
                recipient: favoriteRecipients[index],
                onTap: () => onSelect(favoriteRecipients[index]),
                onFavorite: () => onToggleFavorite(favoriteRecipients[index]),
                keyPrefix: 'favorite-recipient',
              ),
            ),
          ),
        Positioned(
          left: 28,
          top: 461 + favoriteOffset,
          child: const Text(
            '내 계좌',
            key: Key('transfer-own-account-label'),
            style: _recipientSectionStyle,
          ),
        ),
        Positioned(
          right: 28,
          top: 449 + favoriteOffset,
          child: _CountChip(
            myAccountsExpanded ? '${ownAccounts.length}개' : '0개',
            myAccountsExpanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            key: const Key('transfer-my-accounts-toggle'),
            onTap: onToggleMyAccounts,
          ),
        ),
        if (myAccountsExpanded)
          ...List.generate(
            ownAccounts.length,
            (index) => Positioned(
              left: 28,
              right: 25,
              top: 505 + favoriteOffset + (index * 97),
              height: 78,
              child: _RecipientRow(
                recipient: ownAccounts[index],
                onTap: () => onSelect(ownAccounts[index]),
              ),
            ),
          ),
        Positioned(
          left: 28,
          top: 535 + recentOffset,
          child: const Text(
            '최근',
            key: Key('transfer-recent-label'),
            style: _recipientSectionStyle,
          ),
        ),
        Positioned(
          right: 28,
          top: 523 + recentOffset,
          child: _CountChip(
            '${AppDataStore.maxSavedRecipients}개',
            recentRecipientsExpanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            key: const Key('transfer-recent-recipients-toggle'),
            onTap: onToggleRecentRecipients,
          ),
        ),
        if (recentRecipientsExpanded)
          Positioned(
            left: 28,
            right: 25,
            top: 600 + recentOffset,
            bottom: 0,
            child: ListView.separated(
              key: const Key('recent-recipient-list'),
              padding: EdgeInsets.zero,
              itemCount: recipients.length,
              separatorBuilder: (_, __) => const SizedBox(height: 19),
              itemBuilder: (context, index) {
                final recipient = recipients[index];
                return SizedBox(
                  height: 78,
                  child: _RecipientRow(
                    recipient: recipient,
                    onTap: () => onSelect(recipient),
                    onFavorite: () => onToggleFavorite(recipient),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SquareIcon extends StatelessWidget {
  const _SquareIcon({super.key, required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Ink(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, size: 34),
    ),
  );
}

class _CountChip extends StatelessWidget {
  const _CountChip(this.text, this.icon, {super.key, this.onTap});
  final String text;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(25),
    child: Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFF0F1F4)),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(
              color: _recipientInk,
              fontSize: 17,
              fontWeight: FontWeight.w500,
              fontVariations: [FontVariation('wght', 540)],
            ),
          ),
          const SizedBox(width: 4),
          Icon(icon, size: 22, color: _recipientInk),
        ],
      ),
    ),
  );
}

class _Recipient {
  const _Recipient(
    this.name,
    this.bank,
    this.account,
    this.logoAsset, {
    this.bankCode,
    this.internalAccountId,
    this.recipientId,
    this.favorite = false,
  });
  final String name, bank, account;
  final String logoAsset;
  final String? bankCode;
  final String? internalAccountId;
  final String? recipientId;
  final bool favorite;
}

class _RecipientRow extends StatelessWidget {
  const _RecipientRow({
    required this.recipient,
    required this.onTap,
    this.onFavorite,
    this.keyPrefix = 'recipient',
  });
  final _Recipient recipient;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final String keyPrefix;
  @override
  Widget build(BuildContext context) => InkWell(
    key: Key('$keyPrefix-${recipient.name}'),
    onTap: onTap,
    borderRadius: BorderRadius.circular(15),
    child: Row(
      children: [
        BankLogo(
          bankCode: recipient.bankCode ?? recipient.bank,
          size: BankLogoSize.picker,
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recipient.name,
                style: const TextStyle(
                  color: _recipientInk,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  fontVariations: [FontVariation('wght', 560)],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${recipient.bank} ${recipient.account}',
                style: const TextStyle(
                  fontSize: 17,
                  color: _recipientMuted,
                  fontWeight: FontWeight.w400,
                  fontVariations: [FontVariation('wght', 450)],
                ),
              ),
            ],
          ),
        ),
        if (onFavorite == null)
          const Icon(
            Icons.star_border_rounded,
            size: 31,
            color: Color(0xFF657084),
          )
        else
          GestureDetector(
            key: Key('$keyPrefix-favorite-${recipient.recipientId}'),
            behavior: HitTestBehavior.opaque,
            onTap: onFavorite,
            child: Icon(
              recipient.favorite
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              size: 31,
              color: recipient.favorite ? _blue : const Color(0xFF657084),
            ),
          ),
      ],
    ),
  );
}

class _RecipientSearchDelegate extends SearchDelegate<_Recipient?> {
  _RecipientSearchDelegate(this.recipients);

  final List<_Recipient> recipients;

  List<_Recipient> get _matches {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return recipients;
    return recipients.where((recipient) {
      return recipient.name.toLowerCase().contains(normalized) ||
          recipient.bank.toLowerCase().contains(normalized) ||
          recipient.account.toLowerCase().contains(normalized);
    }).toList();
  }

  @override
  String get searchFieldLabel => '이름, 은행, 계좌번호 검색';

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        key: const Key('recipient-search-clear'),
        onPressed: () => query = '',
        icon: const Icon(Icons.clear_rounded),
      ),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    key: const Key('recipient-search-back'),
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back_ios_new_rounded),
  );

  @override
  Widget buildResults(BuildContext context) => _buildMatches();

  @override
  Widget buildSuggestions(BuildContext context) => _buildMatches();

  Widget _buildMatches() {
    final matches = _matches;
    if (matches.isEmpty) {
      return const Center(child: Text('검색 결과가 없습니다.'));
    }
    return ListView.builder(
      key: const Key('recipient-search-results'),
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final recipient = matches[index];
        return ListTile(
          key: Key('recipient-search-${recipient.name}'),
          leading: BankLogo(
            bankCode: recipient.bankCode ?? recipient.bank,
            size: 42,
          ),
          title: Text(recipient.name),
          subtitle: Text('${recipient.bank} ${recipient.account}'),
          onTap: () => close(context, recipient),
        );
      },
    );
  }
}

class _ManualEntry extends StatelessWidget {
  static const _showAccountSuggestions = false;

  const _ManualEntry({
    required this.account,
    required this.bank,
    required this.suggestions,
    required this.onDigit,
    required this.onDelete,
    required this.onClear,
    required this.onChooseBank,
    required this.onSelectSuggestion,
  });
  final String account;
  final String? bank;
  final List<_Recipient> suggestions;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete, onClear, onChooseBank;
  final ValueChanged<_Recipient> onSelectSuggestion;
  @override
  Widget build(BuildContext context) {
    final hasSuggestions = _showAccountSuggestions && suggestions.isNotEmpty;
    const bankTop = 412.0;
    return Stack(
      children: [
        const Positioned(
          left: 28,
          top: 198,
          child: Text(
            '누구에게 보낼까요?',
            style: TextStyle(
              fontSize: 33.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.5,
            ),
          ),
        ),
        Positioned(
          left: 28,
          right: 28,
          top: 285,
          height: 110,
          child: _AccountBox(account: account, onClear: onClear),
        ),
        Positioned(
          left: 28,
          right: 28,
          top: bankTop,
          height: 104,
          child: _BankBox(bank: bank, onTap: onChooseBank),
        ),
        if (hasSuggestions)
          Positioned(
            left: 28,
            right: 28,
            top: 535,
            height: 44,
            child: _AccountSuggestions(
              suggestions: suggestions,
              onSelect: onSelectSuggestion,
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          top: 790,
          height: 355,
          child: _NumericPad(
            prefix: 'account',
            showDoubleZero: false,
            onDigit: onDigit,
            onDelete: onDelete,
          ),
        ),
      ],
    );
  }
}

class _AccountSuggestions extends StatelessWidget {
  const _AccountSuggestions({
    required this.suggestions,
    required this.onSelect,
  });

  final List<_Recipient> suggestions;
  final ValueChanged<_Recipient> onSelect;

  @override
  Widget build(BuildContext context) => ListView.separated(
    key: const Key('transfer-account-suggestions'),
    padding: EdgeInsets.zero,
    scrollDirection: Axis.horizontal,
    itemCount: suggestions.length,
    separatorBuilder: (_, __) => const SizedBox(width: 8),
    itemBuilder: (context, index) {
      final recipient = suggestions[index];
      return Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key(
            'transfer-account-suggestion-${recipient.recipientId ?? recipient.account}',
          ),
          onTap: () => onSelect(recipient),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            height: 44,
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.fromLTRB(16, 0, 17, 0),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F5FA),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BankLogo(
                  bankCode: recipient.bankCode ?? recipient.bank,
                  size: BankLogoSize.suggestion,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    '${recipient.name} ${recipient.account}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _AccountBox extends StatelessWidget {
  const _AccountBox({required this.account, required this.onClear});
  final String account;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) => Container(
    key: const Key('transfer-account-input'),
    padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
    decoration: BoxDecoration(
      border: Border.all(color: _blue, width: 3),
      borderRadius: BorderRadius.circular(17),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '계좌번호',
          style: TextStyle(
            color: _blue,
            fontSize: 17,
            fontWeight: FontWeight.w400,
            fontVariations: [FontVariation('wght', 400)],
            letterSpacing: -.2,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            if (account.isEmpty) ...[
              Container(
                key: const Key('transfer-account-caret'),
                width: 2,
                height: 34,
                color: const Color(0xFFB9DFFF),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                account.isEmpty ? '- 없이 숫자만 입력' : account,
                style: TextStyle(
                  fontSize: 26,
                  color: account.isEmpty ? _muted : _ink,
                  fontWeight: FontWeight.w300,
                  fontVariations: const [FontVariation('wght', 350)],
                  letterSpacing: -.4,
                ),
              ),
            ),
            if (account.isNotEmpty)
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  key: const Key('transfer-clear-account'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onClear,
                  icon: const Icon(Icons.cancel, color: Color(0xFF949CAA)),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

class _BankBox extends StatelessWidget {
  const _BankBox({required this.bank, required this.onTap});
  final String? bank;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton(
    key: const Key('transfer-bank-selector'),
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      alignment: Alignment.centerLeft,
      side: const BorderSide(color: _line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
    ),
    child: Row(
      children: [
        Expanded(
          child: bank == null
              ? const Text(
                  '은행 또는 증권사 선택',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 27,
                    fontWeight: FontWeight.w300,
                    fontVariations: [FontVariation('wght', 350)],
                    letterSpacing: -.4,
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '은행 또는 증권사 선택',
                      style: TextStyle(color: _muted, fontSize: 16),
                    ),
                    Text(
                      bank!,
                      style: const TextStyle(
                        fontSize: 23,
                        color: _ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
        const Icon(Icons.keyboard_arrow_down_rounded, color: _ink, size: 35),
      ],
    ),
  );
}

class _AmountPage extends StatelessWidget {
  const _AmountPage({
    required this.sourceAccount,
    required this.bank,
    required this.account,
    required this.recipientName,
    required this.recipientUsesHonorific,
    required this.amount,
    required this.onDigit,
    required this.onDelete,
    required this.onChooseSourceAccount,
  });
  final _SourceAccount sourceAccount;
  final String bank, account;
  final String? recipientName;
  final bool recipientUsesHonorific;
  final int amount;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback onChooseSourceAccount;
  @override
  Widget build(BuildContext context) {
    final entered = amount > 0;
    final sourceProductLabel = _sourceProductLabel(sourceAccount.productName);
    final sourceProductTruncated =
        sourceProductLabel != sourceAccount.productName;
    return Stack(
      children: [
        Positioned(
          left: 28,
          right: 28,
          top: 202,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                key: const Key('source-account-selector'),
                onTap: onChooseSourceAccount,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          key: const Key('amount-source-account-name'),
                          sourceProductLabel,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: _amountSourceHeaderStyle,
                        ),
                      ),
                      SizedBox(width: sourceProductTruncated ? 28 : 6),
                      const Text(
                        key: Key('amount-source-account-suffix'),
                        '계좌에서',
                        style: _amountSourceHeaderStyle,
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        key: Key('amount-source-account-arrow'),
                        size: 28,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _recipientLabel,
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              Text(
                key: const Key('amount-recipient-account'),
                '$bank $account',
                style: const TextStyle(
                  fontSize: 18,
                  color: Color(0xFF505866),
                  fontWeight: FontWeight.w500,
                  fontVariations: [FontVariation('wght', 500)],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 338,
          child: Column(
            children: [
              Text(
                entered ? '${_formatted(amount)}원' : '얼마를 보낼까요?',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  color: entered ? _ink : const Color(0xFF8C96A7),
                ),
              ),
              const SizedBox(height: 13),
              Text.rich(
                key: const Key('amount-available-balance'),
                TextSpan(
                  style: const TextStyle(
                    fontSize: 19,
                    color: Color(0xFF505866),
                    fontWeight: FontWeight.w500,
                    fontVariations: [FontVariation('wght', 500)],
                  ),
                  children: [
                    const TextSpan(text: '출금가능금액 '),
                    TextSpan(
                      text: '${_formatted(sourceAccount.availableBalance)}원',
                      style: const TextStyle(
                        color: Color(0xFF505866),
                        fontWeight: FontWeight.w500,
                        fontVariations: [FontVariation('wght', 500)],
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFF505866),
                        decorationThickness: 1.4,
                        decorationStyle: TextDecorationStyle.solid,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Positioned(
          left: 29,
          right: 29,
          top: 730,
          child: _AmountShortcuts(),
        ),
        Positioned(
          left: 47,
          right: 47,
          top: 845,
          height: 300,
          child: _NumericPad(
            prefix: 'amount',
            showDoubleZero: true,
            onDigit: onDigit,
            onDelete: onDelete,
          ),
        ),
      ],
    );
  }

  String get _recipientLabel {
    if (recipientName == null) return '아래 계좌로';
    final suffix = recipientUsesHonorific && !recipientName!.endsWith('님')
        ? '님'
        : '';
    return '$recipientName$suffix 계좌로';
  }

  static String _sourceProductLabel(String value) {
    const visibleCharacterCount = 19;
    final characters = value.runes;
    if (characters.length <= visibleCharacterCount) return value;
    return '${String.fromCharCodes(characters.take(visibleCharacterCount))}...';
  }

  static String _formatted(int value) => value.toString().replaceAllMapped(
    RegExp(r'(?<!^)(?=(\d{3})+$)'),
    (_) => ',',
  );
}

class _SourceAccount {
  const _SourceAccount({
    required this.id,
    required this.productName,
    required this.bankCode,
    required this.bank,
    required this.ownerName,
    required this.accountNumber,
    required this.availableBalance,
  });

  final String id;
  final String productName;
  final String bankCode;
  final String bank;
  final String ownerName;
  final String accountNumber;
  final int availableBalance;

  String get logoAsset => BankCatalog.logoAsset(bankCode);
}

class _SourceAccountSelector extends StatelessWidget {
  const _SourceAccountSelector({
    required this.accounts,
    required this.selectedAccount,
    required this.onSelect,
    required this.onClose,
  });

  final List<_SourceAccount> accounts;
  final _SourceAccount selectedAccount;
  final ValueChanged<_SourceAccount> onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: const Key('source-account-sheet'),
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const Key('source-account-sheet-barrier'),
            onTap: onClose,
            child: const ColoredBox(color: Color(0x92535A65)),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 490,
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                const Positioned(
                  left: 29,
                  top: 31,
                  child: Text(
                    '출금계좌 선택',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
                  ),
                ),
                Positioned(
                  right: 24,
                  top: 24,
                  child: IconButton(
                    key: const Key('source-account-sheet-close'),
                    onPressed: onClose,
                    icon: const _TransferCloseIcon(),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 102,
                  bottom: 0,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: accounts.length,
                    itemExtent: 194,
                    itemBuilder: (context, index) {
                      final account = accounts[index];
                      return _SourceAccountOption(
                        account: account,
                        selected: account.id == selectedAccount.id,
                        onTap: () => onSelect(account),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SourceAccountOption extends StatelessWidget {
  const _SourceAccountOption({
    required this.account,
    required this.selected,
    required this.onTap,
  });

  final _SourceAccount account;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: Key('source-account-option-${account.bank}-${account.accountNumber}'),
    onTap: onTap,
    child: ColoredBox(
      color: selected ? const Color(0xFFEAF1FF) : Colors.white,
      child: Stack(
        children: [
          Positioned(
            left: 28,
            top: 31,
            width: BankLogoSize.sourceAccount,
            height: BankLogoSize.sourceAccount,
            child: BankLogo(
              bankCode: account.bankCode,
              size: BankLogoSize.sourceAccount,
            ),
          ),
          Positioned(
            left: 91,
            top: 31,
            right: 58,
            child: Text(
              account.productName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
          ),
          Positioned(
            left: 91,
            top: 67,
            child: Text(
              '${account.bank} ${account.accountNumber}',
              style: const TextStyle(fontSize: 18, color: _muted),
            ),
          ),
          if (selected)
            const Positioned(
              right: 31,
              top: 35,
              child: Icon(
                Icons.check_rounded,
                color: _blue,
                size: 29,
                weight: 700,
              ),
            ),
          Positioned(
            right: 30,
            bottom: 30,
            child: Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 18, color: _muted),
                children: [
                  const TextSpan(text: '출금가능금액  '),
                  TextSpan(
                    text:
                        '${_AmountPage._formatted(account.availableBalance)}원',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              key: Key(
                'source-account-balance-${account.bank}-${account.accountNumber}',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AmountShortcuts extends StatelessWidget {
  const _AmountShortcuts();
  @override
  Widget build(BuildContext context) => const Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      _AmountChip('+1만'),
      _AmountChip('+5만'),
      _AmountChip('+10만'),
      _AmountChip('전액'),
    ],
  );
}

class _AmountChip extends StatelessWidget {
  const _AmountChip(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: 123,
    height: 47,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFFF1F4F8),
      borderRadius: BorderRadius.circular(25),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
    ),
  );
}

class _NumericPad extends StatelessWidget {
  const _NumericPad({
    required this.prefix,
    required this.showDoubleZero,
    required this.onDigit,
    required this.onDelete,
  });
  final String prefix;
  final bool showDoubleZero;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final values = [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      if (showDoubleZero) '00' else '',
      '0',
    ];
    return GridView.count(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: showDoubleZero ? 2.2 : 2.3,
      children: [
        ...values.map(
          (value) => TextButton(
            key: Key('$prefix-key-$value'),
            onPressed: value.isEmpty ? null : () => onDigit(value),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 35,
                fontWeight: showDoubleZero ? FontWeight.w700 : FontWeight.w400,
                fontVariations: [
                  FontVariation('wght', showDoubleZero ? 700 : 400),
                ],
                color: _ink,
              ),
            ),
          ),
        ),
        IconButton(
          key: Key('$prefix-delete'),
          onPressed: onDelete,
          icon: const Icon(Icons.backspace_outlined, size: 38, weight: 700),
        ),
      ],
    );
  }
}

class _BankSelectorDialog extends StatefulWidget {
  const _BankSelectorDialog({this.initialBank});
  final String? initialBank;
  @override
  State<_BankSelectorDialog> createState() => _BankSelectorDialogState();
}

class _BankSelectorDialogState extends State<_BankSelectorDialog> {
  bool securities = false;

  @override
  Widget build(BuildContext context) {
    final names = securities
        ? BankCatalog.securitiesCodes
        : BankCatalog.bankCodes;
    // The selector lives on its own Navigator route. Rendering its fixed
    // coordinates directly in Android logical pixels made a 50 px logo appear
    // about 75 physical pixels on devices such as the Samsung reference
    // handset. Scale the complete 589 px artwork to the route width so the
    // sheet, tiles, labels and logos all retain the original proportions on
    // both tabs. Its height may extend below the route and is deliberately
    // clipped above Android's persistent system navigation bar.
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / mockupWidth;
        final hiddenBottom = max(
          0.0,
          mockupHeight - (constraints.maxHeight / scale),
        );
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: mockupWidth * scale,
              height: mockupHeight * scale,
              child: FittedBox(
                fit: BoxFit.fill,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: mockupWidth,
                  height: mockupHeight,
                  child: MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.noScaling),
                    child: Material(
                      color: Colors.transparent,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 129,
                            bottom: 0,
                            child: GestureDetector(
                              onTap: () {},
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(26),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        28,
                                        19,
                                        20,
                                        3,
                                      ),
                                      child: Row(
                                        children: [
                                          const Expanded(
                                            child: Text(
                                              '은행 또는 증권사 선택',
                                              style: TextStyle(
                                                fontSize: 26,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            key: const Key(
                                              'bank-selector-close',
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              size: 35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        _BankTab(
                                          label: '은행',
                                          selected: !securities,
                                          onTap: () => setState(
                                            () => securities = false,
                                          ),
                                        ),
                                        _BankTab(
                                          label: '증권사',
                                          selected: securities,
                                          onTap: () =>
                                              setState(() => securities = true),
                                        ),
                                      ],
                                    ),
                                    Expanded(
                                      child: GridView.builder(
                                        key: Key(
                                          securities
                                              ? 'bank-selector-list-securities'
                                              : 'bank-selector-list-banks',
                                        ),
                                        padding: EdgeInsets.fromLTRB(
                                          28,
                                          61,
                                          28,
                                          34 + hiddenBottom,
                                        ),
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 3,
                                              mainAxisExtent: 134,
                                              mainAxisSpacing: 11,
                                              crossAxisSpacing: 12,
                                            ),
                                        itemCount: names.length,
                                        itemBuilder: (_, i) => _BankTile(
                                          name: names[i],
                                          index: i,
                                          onTap: () =>
                                              Navigator.pop(context, names[i]),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BankTab extends StatelessWidget {
  const _BankTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      key: Key('bank-tab-$label'),
      onTap: onTap,
      child: Container(
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected
                  ? const Color(0xFF667084)
                  : const Color(0xFFE3E5EA),
              width: selected ? 3 : 1,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 22,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? _ink : _muted,
          ),
        ),
      ),
    ),
  );
}

class _BankTile extends StatelessWidget {
  const _BankTile({
    required this.name,
    required this.index,
    required this.onTap,
  });
  final String name;
  final int index;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final asset = BankCatalog.tryLogoAsset(name);
    const colors = [
      Color(0xFF0959DD),
      Color(0xFF3979D8),
      Color(0xFF655642),
      Color(0xFF1476B4),
      Color(0xFF168653),
      Color(0xFF376C9D),
      Color(0xFF047BB9),
      Color(0xFF22669E),
    ];
    return InkWell(
      key: Key('bank-$name'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 134,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F3FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const SizedBox(height: 20),
            SizedBox.square(
              key: Key('bank-logo-frame-$name'),
              dimension: BankLogoSize.picker,
              child: asset != null
                  ? BankLogo(bankCode: name, size: BankLogoSize.picker)
                  : Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors[index % colors.length],
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        name.substring(0, 1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransferReviewPage extends StatelessWidget {
  const _TransferReviewPage({
    required this.sourceAccount,
    required this.bank,
    required this.account,
    required this.recipientName,
    required this.recipientUsesHonorific,
    required this.amount,
    required this.detailsExpanded,
    required this.onToggleDetails,
  });

  final _SourceAccount sourceAccount;
  final String bank;
  final String account;
  final String? recipientName;
  final bool recipientUsesHonorific;
  final int amount;
  final bool detailsExpanded;
  final VoidCallback onToggleDetails;

  String get _recipientLabel {
    if (recipientName == null) return '아래 계좌로';
    final suffix = recipientUsesHonorific && !recipientName!.endsWith('님')
        ? '님'
        : '';
    return '$recipientName$suffix 계좌로';
  }

  @override
  Widget build(BuildContext context) {
    final logoAsset = BankCatalog.tryLogoAsset(bank);
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 226,
          child: Center(
            child: Container(
              key: const Key('transfer-review-logo'),
              width: 76,
              height: 76,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE8EDF5)),
              ),
              child: logoAsset == null
                  ? const Icon(
                      Icons.account_balance_rounded,
                      color: _blue,
                      size: 46,
                    )
                  : BankLogo(bankCode: bank, size: 72),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 320,
          child: Text(
            key: const Key('transfer-review-title'),
            '$_recipientLabel\n${_AmountPage._formatted(amount)}원 보낼까요?',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _ink,
              fontSize: 33,
              height: 1.42,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.1,
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          top: 437,
          child: Text(
            key: Key('transfer-review-fee'),
            '수수료 무료',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF626B79),
              fontSize: 20,
              fontWeight: FontWeight.w400,
              fontVariations: [FontVariation('wght', 450)],
            ),
          ),
        ),
        if (detailsExpanded)
          Positioned(
            left: 28,
            right: 28,
            top: 515,
            height: 230,
            child: _TransferDetailsCard(
              sourceAccount: sourceAccount,
              bank: bank,
              account: account,
              recipientName: recipientName,
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          top: detailsExpanded ? 721 : 513,
          child: Center(
            child: InkWell(
              key: const Key('transfer-review-details-toggle'),
              onTap: onToggleDetails,
              borderRadius: BorderRadius.circular(28),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFDCE1E9),
                    width: 1.5,
                  ),
                ),
                child: Transform.scale(
                  scale: 1.3,
                  child: Icon(
                    detailsExpanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    color: _ink,
                    size: 31,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TransferDetailsCard extends StatelessWidget {
  const _TransferDetailsCard({
    required this.sourceAccount,
    required this.bank,
    required this.account,
    required this.recipientName,
  });

  final _SourceAccount sourceAccount;
  final String bank;
  final String account;
  final String? recipientName;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('transfer-review-details-card'),
    padding: const EdgeInsets.fromLTRB(28, 29, 28, 14),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F8FA),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        _TransferDetailRow(
          label: '보내는 계좌',
          value: '${sourceAccount.bank} ${sourceAccount.accountNumber}',
        ),
        const SizedBox(height: 18),
        _TransferDetailRow(label: '받는 계좌', value: '$bank $account'),
        const SizedBox(height: 18),
        _TransferDetailRow(
          label: '받는분 메모',
          value: sourceAccount.ownerName,
          editable: true,
        ),
        const SizedBox(height: 20),
        _TransferDetailRow(
          label: '내통장 메모',
          value: recipientName ?? '아래 계좌',
          editable: true,
        ),
      ],
    ),
  );
}

class _TransferDetailRow extends StatelessWidget {
  const _TransferDetailRow({
    required this.label,
    required this.value,
    this.editable = false,
  });

  final String label;
  final String value;
  final bool editable;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 145,
        child: Text(
          label,
          style: const TextStyle(
            // The reference uses a medium, cool-gray label. The prior
            // regular weight rendered too pale on physical Android devices.
            fontSize: 22,
            color: Color(0xFF303846),
            fontWeight: FontWeight.w800,
            fontVariations: [FontVariation('wght', 780)],
            letterSpacing: -.35,
          ),
          maxLines: 1,
          overflow: TextOverflow.clip,
        ),
      ),
      Expanded(
        child: Text(
          value,
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _recipientInk,
            fontSize: editable ? 20 : 19,
            fontWeight: FontWeight.w400,
            fontVariations: const [FontVariation('wght', 450)],
            letterSpacing: editable ? .4 : 1.2,
          ),
        ),
      ),
      if (editable) ...[
        const SizedBox(width: 4),
        const Icon(Icons.edit_outlined, size: 20, color: _recipientMuted),
      ],
    ],
  );
}

class _TransferPinPage extends StatelessWidget {
  const _TransferPinPage({
    required this.title,
    required this.enteredDigits,
    required this.keys,
    required this.errorMessage,
    required this.showReset,
    required this.inputEnabled,
    required this.onDigit,
    required this.onDelete,
    required this.onRearrange,
    required this.onReset,
  });

  final String title;
  final int enteredDigits;
  final List<String> keys;
  final String? errorMessage;
  final bool showReset;
  final bool inputEnabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback onRearrange;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final padKeys = keys.isEmpty
        ? const ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']
        : keys;
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 286,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 377,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              4,
              (index) => Container(
                key: Key('transfer-pin-indicator-$index'),
                width: 29,
                height: 29,
                margin: const EdgeInsets.symmetric(horizontal: 13.5),
                decoration: BoxDecoration(
                  color: index < enteredDigits ? _pinBlue : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: index == enteredDigits || index < enteredDigits
                        ? _pinBlue
                        : const Color(0xFF858C99),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (errorMessage case final message?)
          Positioned(
            key: const Key('transfer-pin-error'),
            left: 70,
            right: 70,
            top: 442,
            height: 45,
            child: Center(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFE33232),
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  fontVariations: [FontVariation('wght', 500)],
                  letterSpacing: -.7,
                ),
              ),
            ),
          ),
        if (showReset)
          Positioned(
            left: 204,
            top: 765,
            width: 181,
            height: 58,
            child: FilledButton(
              key: const Key('transfer-pin-reset'),
              onPressed: onReset,
              style: FilledButton.styleFrom(
                foregroundColor: const Color(0xFF111827),
                backgroundColor: const Color(0xFFF3F6FA),
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: const Text(
                '비밀번호 재설정',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.6,
                ),
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          top: 870,
          bottom: 0,
          child: ColoredBox(
            color: _pinBlue,
            child: Transform.translate(
              offset: const Offset(0, -1),
              child: GridView.count(
                key: const Key('transfer-pin-keypad'),
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                childAspectRatio: 2.1815,
                children: [
                  ...padKeys
                      .take(9)
                      .map(
                        (value) => _PinKey(
                          key: Key('transfer-pin-key-$value'),
                          label: value,
                          onTap: inputEnabled ? () => onDigit(value) : null,
                        ),
                      ),
                  Transform.translate(
                    offset: const Offset(-1, 0),
                    child: _PinKey(
                      key: const Key('transfer-pin-rearrange'),
                      label: '재배열',
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.5,
                      onTap: inputEnabled ? onRearrange : null,
                    ),
                  ),
                  _PinKey(
                    key: Key('transfer-pin-key-${padKeys[9]}'),
                    label: padKeys[9],
                    onTap: inputEnabled ? () => onDigit(padKeys[9]) : null,
                  ),
                  IconButton(
                    key: const Key('transfer-pin-delete'),
                    onPressed: inputEnabled ? onDelete : null,
                    icon: Transform.translate(
                      offset: const Offset(0, 2),
                      child: const Icon(
                        Icons.backspace_outlined,
                        color: Colors.white,
                        size: 38,
                        weight: 400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({
    super.key,
    required this.label,
    required this.onTap,
    this.fontSize = 32,
    this.fontWeight = FontWeight.w600,
    this.letterSpacing = 0,
  });

  final String label;
  final VoidCallback? onTap;
  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(foregroundColor: Colors.white),
    child: Text(
      label,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
      ),
    ),
  );
}

class _TransferFailurePopup extends StatelessWidget {
  const _TransferFailurePopup();

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final scale = min(
      viewport.width / mockupWidth,
      viewport.height / mockupHeight,
    );

    return Center(
      child: SizedBox(
        width: 523 * scale,
        height: 336 * scale,
        child: FittedBox(
          fit: BoxFit.contain,
          child: Material(
            elevation: 2,
            shadowColor: const Color(0x18000000),
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: SizedBox(
              width: 523,
              height: 336,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(27, 45, 27, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      key: Key('transfer-failure-code'),
                      'DEP20180',
                      style: TextStyle(
                        fontSize: 20.5,
                        height: 1.38,
                        color: Color(0xFFFF5C73),
                        fontWeight: FontWeight.w500,
                        fontVariations: [FontVariation('wght', 500)],
                        letterSpacing: -.45,
                      ),
                    ),
                    const SizedBox(height: 14.5),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TransferFailureBodyLine('전화금융사고 및 기타금융사고 등록고객은 지급거래'),
                        _TransferFailureBodyLine('불가합니다. 고객사고 정보 확인후 거래하세요.'),
                        _TransferFailureBodyLine(
                          '고객사고 등록으로 거래가 불가합니다. 신한은행 영업점',
                        ),
                        _TransferFailureBodyLine('또는 콜센터로 문의해 주시기 바랍니다.'),
                      ],
                    ),
                    const Spacer(),
                    FilledButton(
                      key: const Key('transfer-failure-home-confirm'),
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF035CF8),
                        minimumSize: const Size.fromHeight(67),
                        maximumSize: const Size.fromHeight(67),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '확인',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransferFailureBodyLine extends StatelessWidget {
  const _TransferFailureBodyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 28.5,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        key: Key('transfer-failure-body-$text'),
        text,
        maxLines: 1,
        softWrap: false,
        style: const TextStyle(
          fontSize: 20.5,
          height: 1.38,
          color: Color(0xFF505866),
          fontWeight: FontWeight.w500,
          fontVariations: [FontVariation('wght', 500)],
          letterSpacing: -.45,
        ),
      ),
    ),
  );
}
