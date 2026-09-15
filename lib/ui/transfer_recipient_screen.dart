import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_data.dart';
import '../core/auth_service.dart';
import '../core/bank_catalog.dart';
import '../core/pin_security.dart';
import 'auth_sheet.dart';
import 'bank_logo.dart';
import 'data_management_screen.dart';
import 'design_canvas.dart';

const _ink = Color(0xFF111827);
const _muted = Color(0xFF62696B);
const _line = Color(0xFFD9DDE5);
const _green = Color(0xFF159757);
const _recipientInk = Color(0xFF303846);
const _recipientMuted = Color(0xFF62696B);
const _recipientPlaceholder = Color(0xFF62696B);
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
    this.initialBankPickerScrollOffset = 0,
  }) : assert(initialPinKeys == null || initialPinKeys.length == 10),
       dataStore = dataStore ?? AppDataStore.shared;

  final AppDataStore dataStore;
  final AuthService? auth;
  @visibleForTesting
  final List<String>? initialPinKeys;
  @visibleForTesting
  final double initialBankPickerScrollOffset;

  @override
  State<TransferRecipientScreen> createState() =>
      _TransferRecipientScreenState();
}

class _TransferRecipientScreenState extends State<TransferRecipientScreen> {
  _TransferStage _stage = _TransferStage.recipient;
  bool _manualEntry = true;
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
  final TextEditingController _accountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    showDeviceStatusBar(darkIcons: true, backgroundColor: Colors.white);
    widget.dataStore.addListener(_handleDataChange);
  }

  @override
  void dispose() {
    widget.dataStore.removeListener(_handleDataChange);
    _accountController.dispose();
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
    } else {
      Navigator.of(context).pop();
    }
  }

  void _setAccount(String value) {
    setState(() => _account = value);
  }

  void _clearAccount() {
    _accountController.clear();
    setState(() => _account = '');
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
      barrierColor: const Color(0x52000000),
      pageBuilder: (_, __, ___) => _BankSelectorDialog(
        initialBank: _bank,
        initialScrollOffset: widget.initialBankPickerScrollOffset,
      ),
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
    final account = recipient?.account ?? _account;
    _accountController.text = account;
    setState(() {
      // Matching ignores separators so a digits-only manual entry can still
      // restore the exact presentation saved for this recipient. The amount
      // screen mirrors that saved account number, including hyphens.
      _account = account;
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
    _accountController.clear();
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
    final mediaQuery = MediaQuery.of(context);
    final canvasScale = min(
      mediaQuery.size.width / mockupWidth,
      mediaQuery.size.height / mockupHeight,
    );
    final bottomSystemInset =
        (_stage == _TransferStage.amount ||
                _stage == _TransferStage.confirmation) &&
            Theme.of(context).platform == TargetPlatform.android &&
            canvasScale > 0
        ? mediaQuery.viewPadding.bottom / canvasScale
        : 0.0;
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
        fullWidthBottomColor: androidPinFullBleed ? _green : null,
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
                onCancel: () => Navigator.of(context).pop(),
                showBack: _stage != _TransferStage.pin,
                showCancel: _stage == _TransferStage.recipient,
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
                  bottomInset: bottomSystemInset,
                )
              else if (_manualEntry)
                _ManualEntry(
                  controller: _accountController,
                  account: _account,
                  bank: _bank,
                  recentRecipients: _savedRecipients,
                  ownAccounts: _ownAccounts,
                  onAccountChanged: _setAccount,
                  onClear: _clearAccount,
                  onChooseBank: _pickBank,
                  onSelectRecipient: _chooseRecipient,
                  canContinue: _canContinue && sourceAccount != null,
                  onContinue: _continueManualEntry,
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
              if (_stage != _TransferStage.recipient &&
                  _stage != _TransferStage.pin)
                Positioned(
                  left: 28,
                  right: 28,
                  bottom: actionButtonBottom + bottomSystemInset,
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
                      backgroundColor: _green,
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
    required this.onCancel,
    required this.showBack,
    required this.showCancel,
    required this.showRecipientActions,
  });
  final VoidCallback onBack;
  final VoidCallback onManageRecipients;
  final VoidCallback onCancel;
  final bool showBack;
  final bool showCancel;
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
              color: _green,
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
      if (showCancel)
        Positioned(
          right: 28,
          top: 113,
          child: TextButton(
            key: const Key('transfer-cancel'),
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: _recipientMuted,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              '취소',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                letterSpacing: -.4,
              ),
            ),
          ),
        )
      else
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
                    fontWeight: FontWeight.w600,
                    fontVariations: [FontVariation('wght', 600)],
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
                  fontWeight: FontWeight.w600,
                  fontVariations: [FontVariation('wght', 600)],
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
              color: recipient.favorite ? _green : const Color(0xFF657084),
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

class _ManualEntry extends StatefulWidget {
  const _ManualEntry({
    required this.controller,
    required this.account,
    required this.bank,
    required this.recentRecipients,
    required this.ownAccounts,
    required this.onAccountChanged,
    required this.onClear,
    required this.onChooseBank,
    required this.onSelectRecipient,
    required this.canContinue,
    required this.onContinue,
  });
  final TextEditingController controller;
  final String account;
  final String? bank;
  final List<_Recipient> recentRecipients;
  final List<_Recipient> ownAccounts;
  final ValueChanged<String> onAccountChanged;
  final VoidCallback onClear;
  final VoidCallback onChooseBank;
  final ValueChanged<_Recipient> onSelectRecipient;
  final bool canContinue;
  final VoidCallback onContinue;

  @override
  State<_ManualEntry> createState() => _ManualEntryState();
}

class _ManualEntryState extends State<_ManualEntry> {
  var _tabIndex = 0;

  List<_Recipient> get _visibleRecipients => switch (_tabIndex) {
    0 => widget.recentRecipients,
    1 =>
      widget.recentRecipients
          .where((recipient) => recipient.favorite)
          .toList(growable: false),
    2 => widget.ownAccounts,
    _ => const [],
  };

  String get _emptyMessage => switch (_tabIndex) {
    0 => '최근 이체 내역이 없습니다.',
    1 => '자주 쓰는 계좌가 없습니다.',
    2 => '등록된 내 계좌가 없습니다.',
    _ => '연락처가 없습니다.',
  };

  @override
  Widget build(BuildContext context) {
    const tabs = ['최근', '자주', '내계좌', '연락처'];
    final recipients = _visibleRecipients;
    return Stack(
      children: [
        const Positioned(
          left: 28,
          top: 201,
          child: Text(
            '누구에게 보낼까요?',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.5,
            ),
          ),
        ),
        Positioned(
          left: 28,
          right: 28,
          top: 283,
          height: 79,
          child: TextField(
            key: const Key('transfer-account-input'),
            controller: widget.controller,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(30),
            ],
            onChanged: widget.onAccountChanged,
            style: const TextStyle(
              color: _ink,
              fontSize: 24,
              fontWeight: FontWeight.w500,
              letterSpacing: -.5,
            ),
            decoration: InputDecoration(
              hintText: '계좌번호를 입력해 주세요',
              hintStyle: const TextStyle(
                color: _recipientPlaceholder,
                fontSize: 25,
                fontWeight: FontWeight.w600,
                letterSpacing: -.65,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 30),
              suffixIcon: widget.account.isEmpty
                  ? null
                  : IconButton(
                      key: const Key('transfer-clear-account'),
                      onPressed: widget.onClear,
                      icon: const Icon(Icons.cancel, color: Color(0xFF949494)),
                    ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: const BorderSide(color: Color(0xFFD8D8D8)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: const BorderSide(color: _ink, width: 1.4),
              ),
            ),
          ),
        ),
        Positioned(
          left: 28,
          right: 28,
          top: 382,
          height: 80,
          child: _BankBox(bank: widget.bank, onTap: widget.onChooseBank),
        ),
        const Positioned(
          left: 28,
          top: 487,
          child: Text(
            '계좌번호를 입력하면 은행을 조회해 드릴게요',
            style: TextStyle(
              color: _recipientMuted,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -.45,
            ),
          ),
        ),
        Positioned(
          left: 28,
          right: 28,
          top: 554,
          height: 70,
          child: FilledButton(
            key: const Key('transfer-next'),
            onPressed: widget.canContinue ? widget.onContinue : null,
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              disabledBackgroundColor: const Color(0xFFE8E8E8),
              disabledForegroundColor: const Color(0xFF9C9C9C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              '다음',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w400),
            ),
          ),
        ),
        Positioned(
          left: 28,
          right: 28,
          top: 687,
          height: 62,
          child: Row(
            children: [
              for (var index = 0; index < tabs.length; index++)
                Expanded(
                  child: InkWell(
                    key: Key('transfer-recipient-tab-${tabs[index]}'),
                    onTap: () => setState(() => _tabIndex = index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          tabs[index],
                          style: TextStyle(
                            color: _tabIndex == index
                                ? _ink
                                : const Color(0xFF303030),
                            fontSize: 22,
                            fontWeight: _tabIndex == index
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          height: _tabIndex == index ? 3 : 1,
                          color: _tabIndex == index
                              ? _ink
                              : const Color(0xFFDADADA),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (recipients.isEmpty)
          Positioned(
            left: 28,
            right: 28,
            top: 844,
            child: Column(
              children: [
                Container(
                  key: const Key('transfer-recipient-empty-icon'),
                  width: 82,
                  height: 82,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5D5D5),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    '•••',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 5,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  _emptyMessage,
                  key: const Key('transfer-recipient-empty-message'),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 27,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          )
        else
          Positioned(
            left: 28,
            right: 28,
            top: 773,
            bottom: 28,
            child: ListView.separated(
              key: const Key('transfer-recipient-tab-list'),
              padding: EdgeInsets.zero,
              itemCount: recipients.length,
              separatorBuilder: (_, __) => const Divider(color: _line),
              itemBuilder: (context, index) {
                final recipient = recipients[index];
                return SizedBox(
                  height: 82,
                  child: _RecipientRow(
                    recipient: recipient,
                    onTap: () => widget.onSelectRecipient(recipient),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
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
      foregroundColor: _ink,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      alignment: Alignment.centerLeft,
      side: const BorderSide(color: Color(0xFFD8D8D8)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
    ),
    child: Row(
      children: [
        Expanded(
          child: bank == null
              ? const Text(
                  '은행을 선택해 주세요',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 25,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -.65,
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '은행/증권사',
                      style: TextStyle(
                        color: _recipientMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _institutionLabel(bank!),
                      style: const TextStyle(
                        fontSize: 23,
                        color: _ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
        const Icon(Icons.keyboard_arrow_down_rounded, color: _ink, size: 31),
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
    required this.bottomInset,
  });
  final _SourceAccount sourceAccount;
  final String bank, account;
  final String? recipientName;
  final bool recipientUsesHonorific;
  final int amount;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback onChooseSourceAccount;
  final double bottomInset;
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
        Positioned(
          left: 29,
          right: 29,
          top: 730 - bottomInset,
          child: const _AmountShortcuts(),
        ),
        Positioned(
          left: 47,
          right: 47,
          top: 845 - bottomInset,
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
                color: _green,
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
                fontWeight: showDoubleZero ? FontWeight.w500 : FontWeight.w400,
                fontVariations: [
                  FontVariation('wght', showDoubleZero ? 500 : 400),
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

class _InstitutionItem {
  const _InstitutionItem(
    this.value,
    this.label, {
    this.logoCode,
    this.fallbackColor = const Color(0xFF2464AA),
    this.fallbackMark,
  });

  final String value;
  final String label;
  final String? logoCode;
  final Color fallbackColor;
  final String? fallbackMark;
}

const _bankPickerItems = <_InstitutionItem>[
  _InstitutionItem('농협', 'NH농협', logoCode: '농협'),
  _InstitutionItem('국민', '국민은행', logoCode: '국민'),
  _InstitutionItem('기업', '기업은행', logoCode: '기업'),
  _InstitutionItem('산업', '산업은행', logoCode: '산업'),
  _InstitutionItem('신한', '신한은행', logoCode: '신한'),
  _InstitutionItem('우리', '우리은행', logoCode: '우리'),
  _InstitutionItem('하나', '하나은행', logoCode: '하나'),
  _InstitutionItem('한국씨티', '한국씨티은행', logoCode: '한국씨티'),
  _InstitutionItem('SC', 'SC제일은행', logoCode: 'SC'),
  _InstitutionItem('카카오뱅크', '카카오뱅크', logoCode: '카카오뱅크'),
  _InstitutionItem('케이뱅크', '케이뱅크', logoCode: '케이뱅크'),
  _InstitutionItem('토스뱅크', '토스뱅크', logoCode: '토스뱅크'),
  _InstitutionItem('경남', '경남은행', logoCode: '경남'),
  _InstitutionItem('광주', '광주은행', logoCode: '광주'),
  _InstitutionItem('아이엠뱅크(대구)', '아이엠뱅크 (구)대구', logoCode: '아이엠뱅크(대구)'),
  _InstitutionItem('부산', '부산은행', logoCode: '부산'),
  _InstitutionItem('전북', '전북은행', logoCode: '전북'),
  _InstitutionItem('회원수협', '수협', logoCode: '회원수협'),
  _InstitutionItem('제주', '제주은행', logoCode: '제주'),
  _InstitutionItem('산림조합', '산림조합중앙회', logoCode: '산림조합'),
  _InstitutionItem('신협', '신협중앙회', logoCode: '신협'),
  _InstitutionItem('새마을', '새마을금고', logoCode: '새마을'),
  _InstitutionItem('우체국', '우체국', logoCode: '우체국'),
  _InstitutionItem('저축은행', '저축은행', logoCode: '저축은행'),
  _InstitutionItem('도이치', '도이치은행', logoCode: '도이치'),
  _InstitutionItem('BOA', '뱅크오브아메리카', logoCode: 'BOA'),
  _InstitutionItem('중국공상', '중국공상은행', logoCode: '중국공상'),
  _InstitutionItem('중국', '중국은행', logoCode: '중국'),
  _InstitutionItem('중국건설', '중국건설은행', logoCode: '중국건설'),
  _InstitutionItem('BNP파리바', 'BNP파리바은행', logoCode: 'BNP파리바'),
  _InstitutionItem('HSBC', 'HSBC은행', logoCode: 'HSBC'),
  _InstitutionItem('JP모간', 'JP모건체이스은행', logoCode: 'JP모간'),
];

const _localTaxPickerItem = _InstitutionItem('지방세', '지방세입', logoCode: '지방세');

const _securitiesPickerItems = <_InstitutionItem>[
  _InstitutionItem('NH투자증권', 'NH투자증권', logoCode: '농협'),
  _InstitutionItem('교보증권', '교보증권', logoCode: '교보증권'),
  _InstitutionItem('대신증권', '대신증권', logoCode: '대신증권'),
  _InstitutionItem(
    '메리츠증권',
    '메리츠증권',
    fallbackColor: Color(0xFFE52525),
    fallbackMark: 'meritz',
  ),
  _InstitutionItem('미래에셋증권', '미래에셋증권', logoCode: '미래에셋증권'),
  _InstitutionItem(
    '부국증권',
    '부국증권',
    fallbackColor: Color(0xFF234D99),
    fallbackMark: '◇',
  ),
  _InstitutionItem('삼성증권', '삼성증권', logoCode: '삼성증권'),
  _InstitutionItem('신영증권', '신영증권', logoCode: '신영증권'),
  _InstitutionItem('신한투자증권', '신한투자증권', logoCode: '신한투자증권'),
  _InstitutionItem(
    '에스케이증권',
    '에스케이증권',
    fallbackColor: Color(0xFFE51E34),
    fallbackMark: 'SK',
  ),
  _InstitutionItem('유안타증권', '유안타증권', logoCode: '유안타증권'),
  _InstitutionItem(
    '유진투자증권',
    '유진투자증권',
    fallbackColor: Color(0xFFE23A36),
    fallbackMark: '●',
  ),
  _InstitutionItem(
    'LS증권',
    'LS증권',
    fallbackColor: Color(0xFF102B65),
    fallbackMark: 'LS',
  ),
  _InstitutionItem('카카오페이증권', '카카오페이증권', logoCode: '카카오페이증권'),
  _InstitutionItem('케이프투자증권', '케이프투자증권', logoCode: '케이프투자증권'),
  _InstitutionItem('키움증권', '키움증권', logoCode: '키움증권'),
  _InstitutionItem('토스증권', '토스증권', logoCode: '토스증권'),
  _InstitutionItem('하나증권', '하나증권', logoCode: '하나증권'),
  _InstitutionItem('아이엠증권', '아이엠증권', logoCode: '아이엠뱅크(대구)'),
  _InstitutionItem('한국투자증권', '한국투자증권', logoCode: '한국투자증권'),
  _InstitutionItem('한화투자증권', '한화투자증권', logoCode: '한화투자증권'),
  _InstitutionItem('현대차증권', '현대차증권', logoCode: '현대차증권'),
  _InstitutionItem('우리투자증권', '우리투자증권', logoCode: '우리'),
  _InstitutionItem('BNK증권', 'BNK증권', logoCode: '경남'),
];

String _institutionLabel(String value) {
  for (final institution in [
    ..._bankPickerItems,
    _localTaxPickerItem,
    ..._securitiesPickerItems,
  ]) {
    if (institution.value == value) return institution.label;
  }
  return value;
}

class _BankSelectorDialog extends StatefulWidget {
  const _BankSelectorDialog({this.initialBank, this.initialScrollOffset = 0});
  final String? initialBank;
  final double initialScrollOffset;
  @override
  State<_BankSelectorDialog> createState() => _BankSelectorDialogState();
}

class _BankSelectorDialogState extends State<_BankSelectorDialog> {
  bool securities = false;
  late final ScrollController _scrollController = ScrollController(
    initialScrollOffset: widget.initialScrollOffset,
  );

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final institutions = securities ? _securitiesPickerItems : _bankPickerItems;
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
                                clipBehavior: Clip.antiAlias,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(26),
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Column(
                                      children: [
                                        const SizedBox(height: 76),
                                        Expanded(
                                          child: ClipRect(
                                            child: CustomScrollView(
                                              key: Key(
                                                securities
                                                    ? 'bank-selector-list-securities'
                                                    : 'bank-selector-list-banks',
                                              ),
                                              controller: _scrollController,
                                              clipBehavior: Clip.hardEdge,
                                              slivers: [
                                                SliverToBoxAdapter(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.fromLTRB(
                                                          28,
                                                          74,
                                                          28,
                                                          24,
                                                        ),
                                                    child: SizedBox(
                                                      height: 64,
                                                      child: Row(
                                                        children: [
                                                          _BankTab(
                                                            label: '은행',
                                                            selected:
                                                                !securities,
                                                            left: true,
                                                            onTap: () => setState(
                                                              () => securities =
                                                                  false,
                                                            ),
                                                          ),
                                                          _BankTab(
                                                            label: '증권사',
                                                            selected:
                                                                securities,
                                                            left: false,
                                                            onTap: () => setState(
                                                              () => securities =
                                                                  true,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                SliverPadding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 35,
                                                      ),
                                                  sliver: SliverGrid(
                                                    gridDelegate:
                                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                                          crossAxisCount: 2,
                                                          mainAxisExtent: 72,
                                                          crossAxisSpacing: 24,
                                                        ),
                                                    delegate: SliverChildBuilderDelegate(
                                                      (context, index) {
                                                        final institution =
                                                            institutions[index];
                                                        return _InstitutionTile(
                                                          institution:
                                                              institution,
                                                          onTap: () =>
                                                              Navigator.pop(
                                                                context,
                                                                institution
                                                                    .value,
                                                              ),
                                                        );
                                                      },
                                                      childCount:
                                                          institutions.length,
                                                    ),
                                                  ),
                                                ),
                                                if (!securities) ...[
                                                  const SliverToBoxAdapter(
                                                    child: Padding(
                                                      padding: EdgeInsets.only(
                                                        top: 9,
                                                      ),
                                                      child: Divider(
                                                        height: 1,
                                                        color: Color(
                                                          0xFFE2E2E2,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  SliverPadding(
                                                    padding:
                                                        EdgeInsets.fromLTRB(
                                                          35,
                                                          20,
                                                          35,
                                                          34 + hiddenBottom,
                                                        ),
                                                    sliver: SliverToBoxAdapter(
                                                      child: SizedBox(
                                                        width: 245,
                                                        height: 60,
                                                        child: _InstitutionTile(
                                                          institution:
                                                              _localTaxPickerItem,
                                                          onTap: () =>
                                                              Navigator.pop(
                                                                context,
                                                                _localTaxPickerItem
                                                                    .value,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ] else
                                                  SliverToBoxAdapter(
                                                    child: SizedBox(
                                                      height: 34 + hiddenBottom,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      top: 0,
                                      height: 76,
                                      child: ColoredBox(
                                        color: Colors.white,
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            35,
                                            24,
                                            27,
                                            0,
                                          ),
                                          child: Row(
                                            children: [
                                              const Expanded(
                                                child: Text(
                                                  '은행/증권사 선택',
                                                  style: TextStyle(
                                                    fontSize: 26,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: -1.1,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                key: const Key(
                                                  'bank-selector-close',
                                                ),
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints.tightFor(
                                                      width: 42,
                                                      height: 42,
                                                    ),
                                                icon: const Icon(
                                                  Icons.close_rounded,
                                                  size: 35,
                                                  weight: 400,
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
    required this.left,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final bool left;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      key: Key('bank-tab-$label'),
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.horizontal(
            left: left ? const Radius.circular(11) : Radius.zero,
            right: left ? Radius.zero : const Radius.circular(11),
          ),
          border: Border.all(
            color: selected ? _ink : const Color(0xFFD2D2D2),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 21,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? _ink : _recipientMuted,
          ),
        ),
      ),
    ),
  );
}

class _InstitutionTile extends StatelessWidget {
  const _InstitutionTile({required this.institution, required this.onTap});

  final _InstitutionItem institution;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: Key('bank-${institution.value}'),
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Row(
      children: [
        SizedBox.square(
          key: Key('bank-logo-frame-${institution.value}'),
          dimension: 30,
          child: institution.logoCode == null
              ? _FallbackInstitutionLogo(institution: institution)
              : BankLogo(bankCode: institution.logoCode!, size: 30),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            institution.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -.55,
            ),
          ),
        ),
      ],
    ),
  );
}

class _FallbackInstitutionLogo extends StatelessWidget {
  const _FallbackInstitutionLogo({required this.institution});

  final _InstitutionItem institution;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: institution.fallbackColor,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Center(
      child: Text(
        institution.fallbackMark ?? institution.label.characters.first,
        maxLines: 1,
        style: TextStyle(
          color: Colors.white,
          fontSize: (institution.fallbackMark?.length ?? 1) > 3 ? 7 : 11,
          fontWeight: FontWeight.w700,
          letterSpacing: -.35,
        ),
      ),
    ),
  );
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
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE8EDF5)),
              ),
              child: logoAsset == null
                  ? const Icon(
                      Icons.account_balance_rounded,
                      color: _green,
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
              color: _recipientMuted,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontVariations: [FontVariation('wght', 600)],
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
                  color: index < enteredDigits ? _green : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: index == enteredDigits || index < enteredDigits
                        ? _green
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
            key: const Key('transfer-pin-keypad-background'),
            color: _green,
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
    this.fontWeight = FontWeight.w700,
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
                        backgroundColor: _green,
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
