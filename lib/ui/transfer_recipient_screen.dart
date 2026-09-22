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
import 'transfer_loading_overlay.dart';

const _ink = Colors.black;
const _muted = Colors.black;
const _line = Color(0xFFD9DDE5);
const _green = Color(0xFF159757);
const _recipientGreen = Color(0xFF1F9A3F);
const _recipientInk = Colors.black;
const _recipientMuted = Colors.black;
const _recipientPlaceholder = Colors.black;
const _pinSymbolLeft = '__pin_symbol_left__';
const _pinSymbolRight = '__pin_symbol_right__';
const _recipientSectionStyle = TextStyle(
  color: _recipientInk,
  fontSize: 20,
  fontWeight: FontWeight.w500,
  fontVariations: [FontVariation('wght', 580)],
  letterSpacing: -.45,
);

enum TransferFlowResult { failed }

Future<void> showTransferFailurePopup(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0x72000000),
    barrierDismissible: false,
    builder: (_) => const _TransferFailurePopup(),
  );
}

enum _TransferStage {
  recipient,
  amount,
  confirmation,
  pin,
  pinMismatch,
  loadingAmount,
  loadingConfirmation,
  transferWarning,
}

enum _TransferPinMode { guest, loading, verify, create, confirm }

enum _TransferLoadingPhase {
  pinToWarning,
  warningToConfirmation,
  confirmationToResult,
}

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
  bool _sourceAccountSelectorVisible = false;
  String _account = '';
  String? _bank;
  String? _recipientName;
  String? _destinationAccountId;
  bool _showTransferWarning = false;
  int _amount = 0;
  String? _sourceAccountId;
  final List<String> _pinDigits = [];
  List<String> _pinKeys = const [];
  _TransferPinMode _pinMode = _TransferPinMode.guest;
  String? _pendingTransferPin;
  String? _pinSetupError;
  int _pinFailedAttempts = 0;
  bool _pinBusy = false;
  _TransferLoadingPhase? _loadingPhase;
  Duration? _loadingDuration;
  Completer<void>? _loadingCompletion;
  int _loadingPlaybackId = 0;
  final TextEditingController _accountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    showDeviceStatusBar(darkIcons: true, backgroundColor: Colors.white);
    widget.dataStore.addListener(_handleDataChange);
  }

  @override
  void dispose() {
    _loadingPlaybackId++;
    final completion = _loadingCompletion;
    if (completion != null && !completion.isCompleted) completion.complete();
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

  bool get _canContinue {
    final accountLength = AppDataStore.normalizedAccountNumber(_account).length;
    return accountLength >= 6 &&
        accountLength <= 20 &&
        _bank != null &&
        _selectedSourceAccount != null;
  }

  void _back() {
    if (_stage == _TransferStage.pin) {
      setState(() => _stage = _TransferStage.amount);
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

  void _appendAmount(String key) => setState(() {
    final digits = key == '00' ? 2 : 1;
    for (var i = 0; i < digits; i++) {
      _amount *= 10;
    }
    if (key != '00') _amount += int.parse(key);
  });
  void _deleteAmount() => setState(() => _amount ~/= 10);

  void _setAmount(int value) => setState(() => _amount = max(0, value));

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
      _showTransferWarning = recipient.showTransferWarning;
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
      _showTransferWarning = recipient?.showTransferWarning ?? false;
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
          bankCode: recipient.bankCode,
          recipientId: recipient.id,
          favorite: recipient.favorite,
          showTransferWarning: recipient.showTransferWarning,
        ),
    ];
  }

  List<_Recipient> get _ownAccounts => [
    for (final account in widget.dataStore.accounts)
      _Recipient(
        account.accountType,
        account.bankDisplayName,
        account.accountNumber,
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
      _showTransferWarning = false;
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
        widget.initialPinKeys == null
            ? _shuffledPinKeys()
            : [...widget.initialPinKeys!, _pinSymbolLeft, _pinSymbolRight],
      );
      _pinMode = needsProtectedPin
          ? _TransferPinMode.loading
          : _TransferPinMode.guest;
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
    final keys = <String>[
      ...List<String>.generate(10, (index) => '$index'),
      _pinSymbolLeft,
      _pinSymbolRight,
    ];
    final random = Random();
    if (previous == null || previous.length != keys.length) {
      keys.shuffle(random);
      return keys;
    }
    for (var attempt = 0; attempt < 64; attempt++) {
      keys.shuffle(random);
      if (!_sharesAnyPinSlot(keys, previous)) return keys;
    }
    final first = keys.removeAt(0);
    keys.add(first);
    return keys;
  }

  bool _sharesAnyPinSlot(List<String> first, List<String> second) {
    if (first.length != second.length) return true;
    for (var index = 0; index < first.length; index++) {
      if (first[index] == second[index]) return true;
    }
    return false;
  }

  void _rearrangePinKeys() {
    if (_pinInputLocked || _pinBusy) return;
    setState(() => _pinKeys = _shuffledPinKeys(_pinKeys));
  }

  Future<bool> _playTransferLoading(
    _TransferLoadingPhase phase,
    Duration duration, {
    _TransferStage? backdropStage,
    _TransferStage? backdropStageAfter,
    Duration? backdropStageDelay,
  }) async {
    if (_loadingPhase != null) return false;
    await const AssetImage('assets/images/loading_original.png').evict();
    if (!mounted) return false;

    final completion = Completer<void>();
    final playbackId = ++_loadingPlaybackId;
    setState(() {
      if (backdropStage != null) _stage = backdropStage;
      _loadingPhase = phase;
      _loadingDuration = duration;
      _loadingCompletion = completion;
    });
    if (backdropStageAfter != null && backdropStageDelay != null) {
      unawaited(
        Future<void>.delayed(backdropStageDelay, () {
          if (!mounted || playbackId != _loadingPlaybackId) return;
          setState(() => _stage = backdropStageAfter);
        }),
      );
    }

    await completion.future;
    if (!mounted || playbackId != _loadingPlaybackId) return false;
    setState(() {
      _loadingPhase = null;
      _loadingDuration = null;
      _loadingCompletion = null;
    });
    return true;
  }

  void _completeTransferLoading(int playbackId) {
    if (playbackId != _loadingPlaybackId) return;
    final completion = _loadingCompletion;
    if (completion != null && !completion.isCompleted) completion.complete();
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
    return null;
  }

  Future<void> _submitTransferPin() async {
    if (!mounted || _pinBusy || _pinDigits.length != 4) return;
    final pin = _enteredTransferPin;
    final auth = widget.auth;
    switch (_pinMode) {
      case _TransferPinMode.loading:
        return;
      case _TransferPinMode.guest:
        // Guest mode only operates on local demonstration data. There is no
        // authenticated account scope in which a persistent PIN can safely
        // be stored, so a complete four-digit entry continues the simulated
        // transfer without weakening signed-in PIN verification.
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
        await _showPinMismatch(result.failedAttempts);
    }
  }

  Future<void> _showPinMismatch(int failedAttempts) async {
    if (!mounted) return;
    setState(() {
      _pinBusy = false;
      _pinDigits.clear();
      _pinFailedAttempts = failedAttempts;
      _stage = _TransferStage.pinMismatch;
    });
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x4A000000),
      builder: (_) => _TransferPinMismatchPopup(failedAttempts: failedAttempts),
    );
    if (!mounted) return;
    setState(() => _stage = _TransferStage.pin);
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
    _pinBusy = false;
    final played = await _playTransferLoading(
      _TransferLoadingPhase.pinToWarning,
      transferPinAcceptedLoadingDuration,
      backdropStage: _TransferStage.loadingAmount,
    );
    if (!played || !mounted) return;
    if (!_showTransferWarning) {
      setState(() => _stage = _TransferStage.confirmation);
      return;
    }
    setState(() => _stage = _TransferStage.transferWarning);
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    final warningRoute = DialogRoute<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x4A000000),
      builder: (_) =>
          _TransferWarningPopup(recipientName: _recipientName ?? '받는 분'),
    );
    final confirmed = await Navigator.of(context).push<bool>(warningRoute);
    await warningRoute.completed;
    if (!mounted) return;
    if (confirmed != true) {
      setState(() => _stage = _TransferStage.amount);
      return;
    }
    final confirmationPlayed = await _playTransferLoading(
      _TransferLoadingPhase.warningToConfirmation,
      transferWarningToConfirmationLoadingDuration,
      backdropStage: _TransferStage.loadingAmount,
      backdropStageAfter: _TransferStage.loadingConfirmation,
      backdropStageDelay: transferWarningScreenSwitchDelay,
    );
    if (confirmationPlayed && mounted) {
      setState(() => _stage = _TransferStage.confirmation);
    }
  }

  Future<void> _returnToHome() async {
    final played = await _playTransferLoading(
      _TransferLoadingPhase.confirmationToResult,
      transferSubmissionLoadingDuration,
      backdropStage: _TransferStage.confirmation,
    );
    if (!played || !mounted) return;
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
    final loadingPlaybackId = _loadingPlaybackId;
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
    final actionButtonBottom = _stage == _TransferStage.amount
        ? 61.0
        : _stage == _TransferStage.confirmation
        ? 48.0
        : 54.0;
    final actionButtonHeight = _stage == _TransferStage.confirmation
        ? 78.0
        : 81.0;
    return PopScope(
      onPopInvokedWithResult: (_, __) => showDeviceStatusBar(
        darkIcons: true,
        backgroundColor: const Color(0xFFF0F3FA),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DesignCanvas(
            child: Material(
              color: Colors.white,
              child: Stack(
                children: [
                  _TopControls(
                    onBack: _back,
                    onManageRecipients: _openRecipientManagement,
                    onCancel: () => Navigator.of(context).pop(),
                    showBack:
                        _stage != _TransferStage.confirmation &&
                        _stage != _TransferStage.loadingConfirmation,
                    showCancel:
                        _stage == _TransferStage.recipient ||
                        _stage == _TransferStage.amount ||
                        _stage == _TransferStage.pin ||
                        _stage == _TransferStage.pinMismatch ||
                        _stage == _TransferStage.loadingAmount ||
                        _stage == _TransferStage.transferWarning,
                    showRecipientActions:
                        _stage == _TransferStage.recipient && !_manualEntry,
                  ),
                  if (_stage == _TransferStage.confirmation)
                    _TransferConfirmationPage(
                      sourceAccount: sourceAccount!,
                      bank: _bank ?? '토스뱅크',
                      // The final review intentionally follows the banking
                      // reference and shows the destination as digits only.
                      account: AppDataStore.normalizedAccountNumber(_account),
                      recipientName: _recipientName,
                      recipientUsesHonorific: _destinationAccountId == null,
                      amount: _amount,
                      onClose: _back,
                      onAddTransfer: () =>
                          setState(() => _stage = _TransferStage.recipient),
                      onTransfer: _returnToHome,
                    )
                  else if (_stage == _TransferStage.loadingConfirmation)
                    const _TransferConfirmationLoadingBackdrop()
                  else if (_stage == _TransferStage.pinMismatch ||
                      _stage == _TransferStage.loadingAmount ||
                      _stage == _TransferStage.transferWarning)
                    _TransferPinMismatchBackdrop(
                      sourceAccount: sourceAccount!,
                      bank: _bank ?? '토스뱅크',
                      account: _account,
                      recipientName: _recipientName,
                      amount: _amount,
                      showAmount: _stage == _TransferStage.loadingAmount,
                    )
                  else if (_stage == _TransferStage.pin)
                    _TransferPinPage(
                      title: _transferPinTitle,
                      sourceAccount: sourceAccount!,
                      bank: _bank ?? '토스뱅크',
                      account: _account,
                      recipientName: _recipientName,
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
                      onClose: _back,
                      onReset: _resetTransferPin,
                    )
                  else if (_stage == _TransferStage.amount &&
                      sourceAccount != null)
                    _AmountPage(
                      sourceAccount: sourceAccount,
                      bank: _bank ?? '토스뱅크',
                      account: _account.isEmpty ? '100237698805' : _account,
                      recipientName: _recipientName,
                      amount: _amount,
                      onDigit: _appendAmount,
                      onDelete: _deleteAmount,
                      onShortcut: _setAmount,
                      onChooseSourceAccount: () =>
                          setState(() => _sourceAccountSelectorVisible = true),
                      bottomInset: bottomSystemInset,
                    )
                  else if (_manualEntry)
                    _ManualEntry(
                      controller: _accountController,
                      bank: _bank,
                      recentRecipients: _savedRecipients,
                      ownAccounts: _ownAccounts,
                      onAccountChanged: _setAccount,
                      onChooseBank: _pickBank,
                      onSelectRecipient: _chooseRecipient,
                      onToggleFavorite: _toggleFavorite,
                      onManageRecipients: _openRecipientManagement,
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
                        () => _recentRecipientsExpanded =
                            !_recentRecipientsExpanded,
                      ),
                      onManual: _startManualEntry,
                      onCamera: _startManualEntry,
                      onSelect: _chooseRecipient,
                      onToggleFavorite: _toggleFavorite,
                    ),
                  if (_stage != _TransferStage.recipient &&
                      _stage != _TransferStage.pin &&
                      _stage != _TransferStage.pinMismatch &&
                      _stage != _TransferStage.loadingAmount &&
                      _stage != _TransferStage.loadingConfirmation &&
                      _stage != _TransferStage.transferWarning &&
                      _stage != _TransferStage.confirmation)
                    Positioned(
                      left: _stage == _TransferStage.amount ? 35 : 28,
                      right: _stage == _TransferStage.amount ? 35 : 28,
                      bottom: actionButtonBottom + bottomSystemInset,
                      height: actionButtonHeight,
                      child: FilledButton(
                        key: const Key('transfer-next'),
                        onPressed: _stage == _TransferStage.amount
                            ? (_amount > 0 ? _startPinEntry : null)
                            : (_stage == _TransferStage.confirmation
                                  ? _startPinEntry
                                  : _canContinue && sourceAccount != null
                                  ? _continueManualEntry
                                  : null),
                        style: FilledButton.styleFrom(
                          backgroundColor: _recipientGreen,
                          disabledBackgroundColor: const Color(0xFFE9E9E9),
                          disabledForegroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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
          if (_loadingPhase case final loadingPhase?)
            TransferLoadingOverlay(
              key: Key('transfer-loading-${loadingPhase.name}'),
              playbackKey: loadingPlaybackId,
              duration: _loadingDuration!,
              scrimDelay: switch (loadingPhase) {
                _TransferLoadingPhase.pinToWarning =>
                  transferPinAcceptedScrimDelay,
                _TransferLoadingPhase.warningToConfirmation =>
                  transferWarningScrimDelay,
                _ => Duration.zero,
              },
              onComplete: () => _completeTransferLoading(loadingPlaybackId),
            ),
        ],
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
          left: 20,
          top: 104,
          child: IconButton(
            key: const Key('transfer-back'),
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 30),
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
          right: 34,
          top: 106,
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
                fontWeight: FontWeight.w500,
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
    this.account, {
    this.bankCode,
    this.internalAccountId,
    this.recipientId,
    this.favorite = false,
    this.showTransferWarning = false,
  });
  final String name, bank, account;
  final String? bankCode;
  final String? internalAccountId;
  final String? recipientId;
  final bool favorite;
  final bool showTransferWarning;
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
          key: Key('$keyPrefix-bank-logo'),
          bankCode: recipient.bankCode ?? recipient.bank,
          size: 62,
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
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  fontVariations: [FontVariation('wght', 560)],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${_institutionLabel(recipient.bankCode ?? recipient.bank)} ${recipient.account}',
                key: Key('$keyPrefix-bank-account'),
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (onFavorite == null)
          _FavoriteStar(selected: recipient.favorite)
        else
          GestureDetector(
            key: Key('$keyPrefix-favorite-${recipient.recipientId}'),
            behavior: HitTestBehavior.opaque,
            onTap: onFavorite,
            child: _FavoriteStar(selected: recipient.favorite),
          ),
      ],
    ),
  );
}

class _FavoriteStar extends StatelessWidget {
  const _FavoriteStar({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 35,
    child: CustomPaint(
      key: Key(selected ? 'favorite-star-selected' : 'favorite-star-idle'),
      painter: _FavoriteStarPainter(selected: selected),
    ),
  );
}

class _FavoriteStarPainter extends CustomPainter {
  const _FavoriteStarPainter({required this.selected});

  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.shortestSide * .46;
    final innerRadius = outerRadius * .45;
    final path = Path();
    for (var point = 0; point < 10; point++) {
      final radius = point.isEven ? outerRadius : innerRadius;
      final angle = -pi / 2 + point * pi / 5;
      final offset = Offset(
        center.dx + cos(angle) * radius,
        center.dy + sin(angle) * radius,
      );
      if (point == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }
    path.close();
    final paint = Paint()
      ..isAntiAlias = true
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2.1
      ..style = selected ? PaintingStyle.fill : PaintingStyle.stroke
      ..color = selected ? _recipientGreen : const Color(0xFF9A9A9A);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_FavoriteStarPainter oldDelegate) =>
      oldDelegate.selected != selected;
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
    required this.bank,
    required this.recentRecipients,
    required this.ownAccounts,
    required this.onAccountChanged,
    required this.onChooseBank,
    required this.onSelectRecipient,
    required this.onToggleFavorite,
    required this.onManageRecipients,
    required this.canContinue,
    required this.onContinue,
  });
  final TextEditingController controller;
  final String? bank;
  final List<_Recipient> recentRecipients;
  final List<_Recipient> ownAccounts;
  final ValueChanged<String> onAccountChanged;
  final VoidCallback onChooseBank;
  final ValueChanged<_Recipient> onSelectRecipient;
  final ValueChanged<_Recipient> onToggleFavorite;
  final VoidCallback onManageRecipients;
  final bool canContinue;
  final VoidCallback onContinue;

  @override
  State<_ManualEntry> createState() => _ManualEntryState();
}

class _ManualEntryState extends State<_ManualEntry> {
  var _tabIndex = 0;
  var _favoriteCategory = '전체';
  var _favoriteQuery = '';
  var _showFavoriteImportHint = true;
  final _favoriteSearchController = TextEditingController();

  @override
  void dispose() {
    _favoriteSearchController.dispose();
    super.dispose();
  }

  List<_Recipient> get _favoriteRecipients {
    if (_favoriteCategory == '연락처') return const [];
    final query = _favoriteQuery.trim().toLowerCase();
    return widget.recentRecipients
        .where((recipient) {
          if (!recipient.favorite) return false;
          if (query.isEmpty) return true;
          return recipient.name.toLowerCase().contains(query) ||
              recipient.bank.toLowerCase().contains(query) ||
              recipient.account.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  List<_Recipient> get _visibleRecipients => switch (_tabIndex) {
    0 => widget.recentRecipients,
    1 => _favoriteRecipients,
    2 => widget.ownAccounts,
    _ => const [],
  };

  String get _emptyMessage => switch (_tabIndex) {
    0 => '최근 이체 내역이 없습니다.',
    1 => '등록된 계좌가 없습니다.',
    2 => '등록된 내 계좌가 없습니다.',
    _ => '연락처가 없습니다.',
  };

  @override
  Widget build(BuildContext context) {
    const tabs = ['최근', '자주', '내계좌', '연락처'];
    final recipients = _visibleRecipients;
    final hasSelectedBank = widget.bank != null;
    final selectedBankControlOffset = hasSelectedBank ? -60.0 : 0.0;
    return Stack(
      children: [
        const Positioned(
          left: 43,
          top: 194,
          child: Text(
            '누구에게 보낼까요?',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w500,
              letterSpacing: -1.3,
            ),
          ),
        ),
        Positioned(
          left: 35,
          right: 35,
          top: 286,
          height: 79,
          child: SizedBox.expand(
            child: TextField(
              key: const Key('transfer-account-input'),
              controller: widget.controller,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              textAlignVertical: TextAlignVertical.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(20),
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
                constraints: const BoxConstraints.tightFor(height: 79),
                hintStyle: const TextStyle(
                  color: Colors.black,
                  fontSize: 26,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -.65,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 24,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: const BorderSide(color: Color(0xFFD8D8D8)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: const BorderSide(
                    color: _recipientGreen,
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 35,
          right: 35,
          top: 382,
          height: 80,
          child: _BankBox(bank: widget.bank, onTap: widget.onChooseBank),
        ),
        if (!hasSelectedBank)
          const Positioned(
            left: 35,
            top: 487,
            child: Text(
              '계좌번호를 입력하면 은행을 조회해 드릴게요',
              style: TextStyle(
                color: _recipientMuted,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                letterSpacing: -.45,
              ),
            ),
          ),
        Positioned(
          left: 35,
          right: 35,
          top: 557 + selectedBankControlOffset,
          height: 70,
          child: FilledButton(
            key: const Key('transfer-next'),
            onPressed: widget.canContinue ? widget.onContinue : null,
            style: FilledButton.styleFrom(
              backgroundColor: _recipientGreen,
              disabledBackgroundColor: const Color(0xFFE6E6E6),
              disabledForegroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              '다음',
              style: TextStyle(
                color: widget.canContinue ? Colors.white : Colors.black,
                fontSize: 23,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        Positioned(
          left: 35,
          right: 35,
          top: 687 + selectedBankControlOffset,
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
                            color: _tabIndex == index ? _ink : Colors.black,
                            fontSize: 22,
                            fontWeight: _tabIndex == index
                                ? FontWeight.w500
                                : FontWeight.w500,
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
        if (_tabIndex == 1) ...[
          Positioned(
            left: 35,
            right: 35,
            top: 792,
            height: 79,
            child: Row(
              children: [
                SizedBox(
                  width: 183,
                  height: 79,
                  child: PopupMenuButton<String>(
                    key: const Key('transfer-favorite-category'),
                    initialValue: _favoriteCategory,
                    onSelected: (value) =>
                        setState(() => _favoriteCategory = value),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: '전체', child: Text('전체')),
                      PopupMenuItem(value: '계좌', child: Text('계좌')),
                      PopupMenuItem(value: '연락처', child: Text('연락처')),
                    ],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Container(
                      height: 79,
                      padding: const EdgeInsets.only(left: 31, right: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFD8D8D8)),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _favoriteCategory,
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -.6,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: _ink,
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    key: const Key('transfer-favorite-search'),
                    controller: _favoriteSearchController,
                    onChanged: (value) =>
                        setState(() => _favoriteQuery = value),
                    textAlignVertical: TextAlignVertical.center,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: '이름 또는 별칭',
                      hintStyle: const TextStyle(
                        color: Colors.black,
                        fontSize: 25,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -.5,
                      ),
                      contentPadding: const EdgeInsets.fromLTRB(25, 0, 13, 0),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 18),
                        child: SizedBox(
                          width: 43,
                          height: 44,
                          child: Image.asset(
                            'assets/images/ref_transfer_search.png',
                            key: const Key('transfer-favorite-search-icon'),
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 66,
                        minHeight: 79,
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
              ],
            ),
          ),
          const Positioned(
            right: 32,
            top: 895,
            child: _FavoriteRegistrationLink(),
          ),
          if (_showFavoriteImportHint)
            Positioned(
              left: 152,
              right: 35,
              top: 937,
              height: 65,
              child: _FavoriteImportHint(
                onClose: () => setState(() => _showFavoriteImportHint = false),
              ),
            ),
        ],
        if (_tabIndex == 0 && recipients.isNotEmpty)
          Positioned(
            right: 35,
            top: 727,
            child: TextButton(
              key: const Key('transfer-recipient-manage-link'),
              onPressed: widget.onManageRecipients,
              style: TextButton.styleFrom(
                foregroundColor: _ink,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '삭제하기',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                  decorationThickness: 1,
                ),
              ),
            ),
          ),
        if (recipients.isEmpty)
          Positioned(
            left: 28,
            right: 28,
            top: _tabIndex == 1 ? 1021 : 844,
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
                SizedBox(height: _tabIndex == 1 ? 21 : 32),
                Text(
                  _emptyMessage,
                  key: const Key('transfer-recipient-empty-message'),
                  style: TextStyle(
                    color: _ink,
                    fontSize: _tabIndex == 1 ? 30 : 27,
                    fontWeight: _tabIndex == 1
                        ? FontWeight.w500
                        : FontWeight.w600,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          )
        else
          Positioned(
            left: 35,
            right: 35,
            top: _tabIndex == 1 ? 1021 : 766,
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
                    onFavorite: recipient.recipientId == null
                        ? null
                        : () => widget.onToggleFavorite(recipient),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _FavoriteRegistrationLink extends StatelessWidget {
  const _FavoriteRegistrationLink();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '자주쓰는 계좌 또는 연락처 등록',
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '자주쓰는 계좌/연락처 등록',
            style: TextStyle(
              color: _ink,
              fontSize: 22,
              fontWeight: FontWeight.w500,
              letterSpacing: -.25,
            ),
          ),
          SizedBox(width: 4),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: Color(0xFF9B9B9B),
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _FavoriteImportHint extends StatelessWidget {
  const _FavoriteImportHint({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          right: 46,
          top: -15,
          width: 24,
          height: 16,
          child: CustomPaint(painter: _FavoriteHintPointerPainter()),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF343434),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                const SizedBox(width: 22),
                const Expanded(
                  child: Text(
                    'NH스마트뱅킹에서 정보를 가져올 수 있어요.',
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -.55,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('transfer-favorite-hint-close'),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 45,
                    height: 65,
                  ),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF858585),
                    size: 25,
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

class _FavoriteHintPointerPainter extends CustomPainter {
  const _FavoriteHintPointerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF343434));
  }

  @override
  bool shouldRepaint(_FavoriteHintPointerPainter oldDelegate) => false;
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
        if (bank == null)
          const Expanded(
            child: Text(
              '은행을 선택해 주세요',
              style: TextStyle(
                color: _ink,
                fontSize: 25,
                fontWeight: FontWeight.w500,
                letterSpacing: -.65,
              ),
            ),
          )
        else ...[
          BankLogo(
            key: const Key('transfer-selected-bank-logo'),
            bankCode: bank!,
            size: 46,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              _institutionLabel(bank!),
              key: const Key('transfer-selected-bank-label'),
              style: const TextStyle(
                fontSize: 25,
                color: _ink,
                fontWeight: FontWeight.w500,
                letterSpacing: -.65,
              ),
            ),
          ),
        ],
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
    required this.amount,
    required this.onDigit,
    required this.onDelete,
    required this.onShortcut,
    required this.onChooseSourceAccount,
    required this.bottomInset,
  });
  final _SourceAccount sourceAccount;
  final String bank, account;
  final String? recipientName;
  final int amount;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final ValueChanged<int> onShortcut;
  final VoidCallback onChooseSourceAccount;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final entered = amount > 0;
    return Stack(
      children: [
        _TransferRecipientIdentity(
          recipientName: recipientName,
          bank: bank,
          account: account,
        ),
        Positioned(
          left: 0,
          right: 0,
          top: entered ? 335 : 357,
          child: Column(
            children: [
              Text(
                entered ? '${_formatted(amount)}원' : '얼마를 보낼까요?',
                key: const Key('amount-display'),
                style: TextStyle(
                  fontSize: entered ? 45 : 38,
                  fontWeight: entered ? FontWeight.w500 : FontWeight.w600,
                  fontVariations: [FontVariation('wght', entered ? 520 : 600)],
                  color: Colors.black,
                  letterSpacing: entered ? -1.8 : -1.2,
                ),
              ),
              if (entered) ...[
                const SizedBox(height: 11),
                Text(
                  '${_formatted(amount)}원',
                  key: const Key('amount-secondary-display'),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 19,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          left: 35,
          right: 35,
          top: 556 - bottomInset,
          height: 75,
          child: _AmountSourceCard(
            account: sourceAccount,
            amount: amount,
            onTap: onChooseSourceAccount,
          ),
        ),
        Positioned(
          left: 33,
          right: 33,
          top: 668 - bottomInset,
          child: _AmountShortcuts(
            availableBalance: sourceAccount.availableBalance,
            onSelected: onShortcut,
          ),
        ),
        Positioned(
          left: 44,
          right: 44,
          top: 748 - bottomInset,
          height: 360,
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

  static String _formatted(int value) => value.toString().replaceAllMapped(
    RegExp(r'(?<!^)(?=(\d{3})+$)'),
    (_) => ',',
  );
}

class _TransferRecipientIdentity extends StatelessWidget {
  const _TransferRecipientIdentity({
    required this.recipientName,
    required this.bank,
    required this.account,
  });

  final String? recipientName;
  final String bank;
  final String account;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    top: 164,
    child: Column(
      children: [
        Text(
          recipientName ?? '받는 계좌',
          key: const Key('amount-recipient-name'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 21,
            fontWeight: FontWeight.w500,
            letterSpacing: -.35,
          ),
        ),
        const SizedBox(height: 13),
        Text(
          '${_institutionLabel(bank)} $account',
          key: const Key('amount-recipient-account'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.underline,
            decorationColor: Colors.black,
            decorationThickness: 1,
          ),
        ),
      ],
    ),
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
  const _AmountShortcuts({
    required this.availableBalance,
    required this.onSelected,
  });

  final int availableBalance;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _AmountChip('+1만', onTap: () => onSelected(10000)),
      const SizedBox(width: 8),
      _AmountChip('+5만', onTap: () => onSelected(50000)),
      const SizedBox(width: 8),
      _AmountChip('+10만', onTap: () => onSelected(100000)),
      const SizedBox(width: 8),
      _AmountChip('+100만', onTap: () => onSelected(1000000)),
      const SizedBox(width: 8),
      _AmountChip('전액', onTap: () => onSelected(availableBalance)),
    ],
  );
}

class _AmountChip extends StatelessWidget {
  const _AmountChip(this.text, {required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: SizedBox(
      height: 49,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: Colors.black,
          side: const BorderSide(color: Color(0xFFDEDEDE)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          text,
          maxLines: 1,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
        ),
      ),
    ),
  );
}

class _AmountSourceCard extends StatelessWidget {
  const _AmountSourceCard({
    required this.account,
    required this.amount,
    required this.onTap,
    this.emphasizeAmount = true,
  });

  final _SourceAccount account;
  final int amount;
  final VoidCallback onTap;
  final bool emphasizeAmount;

  @override
  Widget build(BuildContext context) {
    final digits = AppDataStore.normalizedAccountNumber(account.accountNumber);
    final suffix = digits.length <= 4
        ? digits
        : digits.substring(digits.length - 4);
    return Material(
      color: const Color(0xFFF8F8F8),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: const Key('source-account-selector'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17),
          child: Row(
            children: [
              Container(
                height: 31,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: const Color(0xFFE7E7E7)),
                ),
                child: const Text(
                  '한도제한',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${account.bank}($suffix)',
                  key: const Key('amount-source-account-name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -.7,
                  ),
                ),
              ),
              Text(
                '${_AmountPage._formatted(amount)}원',
                key: const Key('amount-source-card-value'),
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: emphasizeAmount
                      ? FontWeight.w500
                      : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                key: Key('amount-source-account-arrow'),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
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
      childAspectRatio: showDoubleZero ? 1.84 : 2.3,
      children: [
        ...values.map(
          (value) => TextButton(
            key: Key('$prefix-key-$value'),
            onPressed: value.isEmpty ? null : () => onDigit(value),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 35,
                fontWeight: FontWeight.w700,
                fontVariations: const [FontVariation('wght', 700)],
                color: _ink,
              ),
            ),
          ),
        ),
        IconButton(
          key: Key('$prefix-delete'),
          onPressed: onDelete,
          icon: const Icon(Icons.arrow_back_rounded, size: 35, weight: 500),
        ),
      ],
    );
  }
}

class _InstitutionItem {
  const _InstitutionItem(this.value, this.label, {required this.logoCode});

  final String value;
  final String label;
  final String logoCode;
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
  _InstitutionItem('메리츠증권', '메리츠증권', logoCode: '메리츠증권'),
  _InstitutionItem('미래에셋증권', '미래에셋증권', logoCode: '미래에셋증권'),
  _InstitutionItem('부국증권', '부국증권', logoCode: '부국증권'),
  _InstitutionItem('삼성증권', '삼성증권', logoCode: '삼성증권'),
  _InstitutionItem('신영증권', '신영증권', logoCode: '신영증권'),
  _InstitutionItem('신한투자증권', '신한투자증권', logoCode: '신한투자증권'),
  _InstitutionItem('에스케이증권', '에스케이증권', logoCode: '에스케이증권'),
  _InstitutionItem('유안타증권', '유안타증권', logoCode: '유안타증권'),
  _InstitutionItem('유진투자증권', '유진투자증권', logoCode: '유진투자증권'),
  _InstitutionItem('LS증권', 'LS증권', logoCode: 'LS증권'),
  _InstitutionItem('카카오페이증권', '카카오페이증권', logoCode: '카카오페이증권'),
  _InstitutionItem('케이프투자증권', '케이프투자증권', logoCode: '케이프투자증권'),
  _InstitutionItem('키움증권', '키움증권', logoCode: '키움증권'),
  _InstitutionItem('토스증권', '토스증권', logoCode: '토스증권'),
  _InstitutionItem('하나증권', '하나증권', logoCode: '하나증권'),
  _InstitutionItem('아이엠증권', '아이엠증권', logoCode: '아이엠증권'),
  _InstitutionItem('한국투자증권', '한국투자증권', logoCode: '한국투자증권'),
  _InstitutionItem('한화투자증권', '한화투자증권', logoCode: '한화투자증권'),
  _InstitutionItem('현대차증권', '현대차증권', logoCode: '현대차증권'),
  _InstitutionItem('우리투자증권', '우리투자증권', logoCode: '우리투자증권'),
  _InstitutionItem('BNK증권', 'BNK증권', logoCode: 'BNK증권'),
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
                                                  weight: 500,
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
          child: BankLogo(bankCode: institution.logoCode, size: 30),
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

class _TransferConfirmationLoadingBackdrop extends StatelessWidget {
  const _TransferConfirmationLoadingBackdrop();

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned(
        left: 0,
        right: 0,
        top: 107,
        child: Text(
          '이체확인',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: 25,
            fontWeight: FontWeight.w500,
            letterSpacing: -.7,
          ),
        ),
      ),
      const Positioned(right: 35, top: 112, child: _TransferCloseIcon()),
      Positioned(
        left: 40,
        right: 40,
        top: 299,
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              color: Colors.black,
              fontFamily: 'NotoSansKRMedium',
              fontSize: 32,
              height: 1.27,
              fontWeight: FontWeight.w500,
              letterSpacing: -.3,
            ),
            children: [
              TextSpan(
                text: '원',
                style: TextStyle(color: _recipientGreen),
              ),
              TextSpan(text: '을\n이체할까요?'),
            ],
          ),
        ),
      ),
      Positioned(
        left: 35,
        right: 35,
        bottom: 91,
        height: 81,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 172,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD4D4D4)),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                '이체추가',
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _recipientGreen,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _TransferConfirmationPage extends StatelessWidget {
  const _TransferConfirmationPage({
    required this.sourceAccount,
    required this.bank,
    required this.account,
    required this.recipientName,
    required this.recipientUsesHonorific,
    required this.amount,
    required this.onClose,
    required this.onAddTransfer,
    required this.onTransfer,
  });

  final _SourceAccount sourceAccount;
  final String bank;
  final String account;
  final String? recipientName;
  final bool recipientUsesHonorific;
  final int amount;
  final VoidCallback onClose;
  final VoidCallback onAddTransfer;
  final VoidCallback onTransfer;

  String get _headlineRecipient {
    final name = recipientName ?? '받는 분';
    if (name.length > 10) return '${name.substring(0, 10)}...';
    return name.length == 10 ? '$name...' : name;
  }

  String get _recipientMemo {
    final value = sourceAccount.ownerName.replaceAll(' ', '');
    return value.length > 10 ? value.substring(0, 10) : value;
  }

  @override
  Widget build(BuildContext context) {
    final logoAsset = BankCatalog.tryLogoAsset(bank);
    final buttonName = _headlineRecipient.substring(
      0,
      min(6, _headlineRecipient.length),
    );
    return Stack(
      children: [
        const Positioned(
          left: 0,
          right: 0,
          top: 107,
          child: Text(
            '이체확인',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontSize: 25,
              fontWeight: FontWeight.w500,
              letterSpacing: -.7,
            ),
          ),
        ),
        Positioned(
          right: 27,
          top: 99,
          child: IconButton(
            key: const Key('transfer-review-close'),
            onPressed: onClose,
            icon: const _TransferCloseIcon(),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 196,
          child: Center(
            child: Container(
              key: const Key('transfer-review-logo'),
              width: 98,
              height: 98,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(28),
              ),
              child: logoAsset == null
                  ? const Icon(
                      Icons.account_balance_rounded,
                      color: _green,
                      size: 46,
                    )
                  : BankLogo(bankCode: bank, size: 98),
            ),
          ),
        ),
        Positioned(
          left: 40,
          right: 40,
          top: 299,
          child: RichText(
            key: const Key('transfer-review-title'),
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                color: Colors.black,
                fontFamily: 'NotoSansKRMedium',
                fontSize: 32,
                height: 1.27,
                fontWeight: FontWeight.w500,
                letterSpacing: -.3,
              ),
              children: [
                TextSpan(
                  text: _headlineRecipient,
                  style: const TextStyle(color: _recipientGreen),
                ),
                TextSpan(text: recipientUsesHonorific ? '님께 ' : '께 '),
                TextSpan(
                  text: '${_AmountPage._formatted(amount)}원',
                  style: const TextStyle(color: _recipientGreen),
                ),
                const TextSpan(text: '을\n이체할까요?'),
              ],
            ),
          ),
        ),
        const Positioned(
          left: 35,
          right: 35,
          top: 446,
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE7E7E7)),
        ),
        Positioned(
          left: 41,
          right: 41,
          top: 489,
          child: Column(
            children: [
              _TransferConfirmationRow(
                label: '받는계좌',
                value: '${_institutionLabel(bank)} $account',
                valueColor: _recipientGreen,
              ),
              const SizedBox(height: 18),
              _TransferConfirmationRow(
                label: '출금계좌',
                value: _TransferPinPage._sourceAccountLabel(sourceAccount),
                valueScaleX: 1.14,
              ),
              const SizedBox(height: 16),
              _TransferConfirmationRow(
                label: '수수료',
                value: '${sourceAccount.ownerName}님은 수수\n료 면제!',
                valueColor: const Color(0xFF287AC7),
              ),
              const SizedBox(height: 28),
              _TransferConfirmationRow(
                label: '받는분에게 표기',
                value: _recipientMemo,
                editable: true,
              ),
              const SizedBox(height: 15),
              _TransferConfirmationRow(
                label: '나에게 표기',
                value: recipientName ?? '받는 분',
                editable: true,
              ),
              const SizedBox(height: 18),
              const _TransferConfirmationRow(
                label: '메모',
                value: '메모입력',
                editable: true,
                mutedValue: true,
              ),
            ],
          ),
        ),
        const Positioned(
          left: 35,
          right: 35,
          top: 856,
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE7E7E7)),
        ),
        Positioned(
          left: 35,
          right: 35,
          bottom: 91,
          height: 81,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 172,
                child: OutlinedButton(
                  key: const Key('transfer-review-add'),
                  onPressed: onAddTransfer,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Color(0xFFD4D4D4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    '이체추가',
                    style: TextStyle(fontSize: 27, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: FilledButton(
                  key: const Key('transfer-review-confirm'),
                  onPressed: onTransfer,
                  style: FilledButton.styleFrom(
                    backgroundColor: _recipientGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    '$buttonName...님께 이체',
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TransferConfirmationRow extends StatelessWidget {
  const _TransferConfirmationRow({
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF111111),
    this.editable = false,
    this.mutedValue = false,
    this.valueScaleX = 1.05,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool editable;
  final bool mutedValue;
  final double valueScaleX;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 174,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w500,
            letterSpacing: -.45,
          ),
        ),
      ),
      Expanded(
        child: Container(
          margin: editable ? const EdgeInsets.only(left: 112) : EdgeInsets.zero,
          padding: const EdgeInsets.only(bottom: 8),
          decoration: editable
              ? const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE7E7E7))),
                )
              : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Transform.scale(
                  alignment: Alignment.topRight,
                  scaleX: valueScaleX,
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: mutedValue ? Colors.black : valueColor,
                      fontSize: 20,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      letterSpacing: .4,
                    ),
                  ),
                ),
              ),
              if (editable) ...[
                const SizedBox(width: 6),
                const Icon(Icons.edit_outlined, size: 22),
              ],
            ],
          ),
        ),
      ),
    ],
  );
}

class _TransferPinMismatchBackdrop extends StatelessWidget {
  const _TransferPinMismatchBackdrop({
    required this.sourceAccount,
    required this.bank,
    required this.account,
    required this.recipientName,
    required this.amount,
    this.showAmount = false,
  });

  final _SourceAccount sourceAccount;
  final String bank;
  final String account;
  final String? recipientName;
  final int amount;
  final bool showAmount;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      _TransferRecipientIdentity(
        recipientName: recipientName,
        bank: bank,
        account: account,
      ),
      if (showAmount)
        Positioned(
          left: 0,
          right: 0,
          top: 620,
          child: Column(
            children: [
              Text(
                '${_AmountPage._formatted(amount)}원',
                key: const Key('loading-amount-display'),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 45,
                  fontWeight: FontWeight.w500,
                  fontVariations: [FontVariation('wght', 520)],
                  letterSpacing: -1.8,
                ),
              ),
              const SizedBox(height: 11),
              Text(
                '${_AmountPage._formatted(amount)}원',
                key: const Key('loading-amount-secondary-display'),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 19,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -.4,
                ),
              ),
            ],
          ),
        ),
      Positioned(
        left: 35,
        right: 35,
        top: 1137,
        height: 75,
        child: _AmountSourceCard(
          account: sourceAccount,
          amount: amount,
          onTap: () {},
          emphasizeAmount: false,
        ),
      ),
    ],
  );
}

class _TransferPinPage extends StatelessWidget {
  const _TransferPinPage({
    required this.title,
    required this.sourceAccount,
    required this.bank,
    required this.account,
    required this.recipientName,
    required this.enteredDigits,
    required this.keys,
    required this.errorMessage,
    required this.showReset,
    required this.inputEnabled,
    required this.onDigit,
    required this.onDelete,
    required this.onRearrange,
    required this.onClose,
    required this.onReset,
  });

  final String title;
  final _SourceAccount sourceAccount;
  final String bank;
  final String account;
  final String? recipientName;
  final int enteredDigits;
  final List<String> keys;
  final String? errorMessage;
  final bool showReset;
  final bool inputEnabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback onRearrange;
  final VoidCallback onClose;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final padKeys = keys.isEmpty
        ? const ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0']
        : keys;
    return Stack(
      children: [
        _TransferRecipientIdentity(
          recipientName: recipientName,
          bank: bank,
          account: account,
        ),
        const Positioned.fill(
          child: ColoredBox(
            key: Key('transfer-pin-dim-layer'),
            color: Color(0xB3000000),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 572,
          bottom: 0,
          child: Material(
            key: const Key('transfer-pin-sheet'),
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(31)),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned(
                  left: 36,
                  top: 37,
                  child: Text(
                    title.endsWith('입력') ? title : '$title 입력',
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -.9,
                    ),
                  ),
                ),
                Positioned(
                  right: 25,
                  top: 23,
                  child: IconButton(
                    key: const Key('transfer-pin-close'),
                    onPressed: onClose,
                    icon: const _TransferCloseIcon(),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 124,
                  child: Text(
                    _sourceAccountLabel(sourceAccount),
                    key: const Key('transfer-pin-source-account'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -.35,
                    ),
                  ),
                ),
                Positioned(
                  key: const Key('transfer-pin-indicators'),
                  left: 0,
                  right: 0,
                  top: 198,
                  height: 28,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var index = 0; index < enteredDigits; index++) ...[
                        if (index > 0) const SizedBox(width: 5),
                        DecoratedBox(
                          key: Key('transfer-pin-indicator-$index'),
                          decoration: const BoxDecoration(
                            color: _green,
                            shape: BoxShape.circle,
                          ),
                          child: const SizedBox.square(dimension: 28),
                        ),
                      ],
                    ],
                  ),
                ),
                if (errorMessage case final message?)
                  Positioned(
                    key: const Key('transfer-pin-error'),
                    left: 44,
                    right: 44,
                    top: 175,
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFE33232),
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (showReset)
                  Positioned(
                    right: 31,
                    top: 176,
                    child: TextButton(
                      key: const Key('transfer-pin-reset'),
                      onPressed: onReset,
                      child: const Text('비밀번호 재설정'),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 276,
                  height: 445,
                  child: _PinKeypad(
                    keys: padKeys,
                    enteredDigits: enteredDigits,
                    inputEnabled: inputEnabled,
                    onDigit: onDigit,
                    onDelete: onDelete,
                    onRearrange: onRearrange,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _sourceAccountLabel(_SourceAccount account) {
    final digits = AppDataStore.normalizedAccountNumber(account.accountNumber);
    final formatted = digits.length == 13
        ? '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7, 11)}-${digits.substring(11)}'
        : account.accountNumber;
    return '${account.bank} $formatted';
  }
}

class _PinKeypad extends StatelessWidget {
  const _PinKeypad({
    required this.keys,
    required this.enteredDigits,
    required this.inputEnabled,
    required this.onDigit,
    required this.onDelete,
    required this.onRearrange,
  });

  final List<String> keys;
  final int enteredDigits;
  final bool inputEnabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback onRearrange;

  @override
  Widget build(BuildContext context) {
    final keypadCells = <Widget>[
      for (final value in keys)
        if (value == _pinSymbolLeft)
          const _PinReferenceSymbol(
            key: Key('transfer-pin-symbol-left'),
            asset: 'assets/images/ref_transfer_pin_symbol_left.jpg',
          )
        else if (value == _pinSymbolRight)
          const _PinReferenceSymbol(
            key: Key('transfer-pin-symbol-right'),
            asset: 'assets/images/ref_transfer_pin_symbol_right.jpg',
          )
        else
          _PinDigitKey(value: value, enabled: inputEnabled, onDigit: onDigit),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const horizontalInset = 27.0;
        const cellAspectRatio = 1.42;
        final cellHeight =
            (constraints.maxWidth - horizontalInset * 2) / 4 / cellAspectRatio;
        return Column(
          key: const Key('transfer-pin-keypad'),
          children: [
            SizedBox(
              height: cellHeight * 3,
              child: GridView.count(
                padding: const EdgeInsets.symmetric(
                  horizontal: horizontalInset,
                ),
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                childAspectRatio: cellAspectRatio,
                children: keypadCells,
              ),
            ),
            SizedBox(
              key: const Key('transfer-pin-action-row'),
              height: cellHeight,
              child: Transform.translate(
                offset: const Offset(0, -3),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 27),
                  child: Row(
                    children: [
                      Expanded(
                        child: IconButton(
                          key: const Key('transfer-pin-rearrange'),
                          onPressed: inputEnabled ? onRearrange : null,
                          icon: Image.asset(
                            'assets/images/ref_transfer_pin_rearrange.png',
                            key: const Key('transfer-pin-rearrange-artwork'),
                            width: 62.5,
                            height: 62.5,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                      Expanded(
                        child: IconButton(
                          key: const Key('transfer-pin-delete'),
                          onPressed: inputEnabled ? onDelete : null,
                          icon: Image.asset(
                            'assets/images/ref_transfer_pin_delete.png',
                            key: const Key('transfer-pin-delete-artwork'),
                            width: 62.5,
                            height: 62.5,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          key: const Key('transfer-pin-ok'),
                          onPressed: enteredDigits == 4 ? () {} : null,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black,
                            disabledForegroundColor: Colors.black,
                          ),
                          child: const Text(
                            'OK',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w500,
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
        );
      },
    );
  }
}

class _PinDigitKey extends StatelessWidget {
  const _PinDigitKey({
    required this.value,
    required this.enabled,
    required this.onDigit,
  });

  final String value;
  final bool enabled;
  final ValueChanged<String> onDigit;

  @override
  Widget build(BuildContext context) => TextButton(
    key: Key('transfer-pin-key-$value'),
    onPressed: enabled ? () => onDigit(value) : null,
    style: TextButton.styleFrom(
      foregroundColor: Colors.black,
      disabledForegroundColor: Colors.black,
    ),
    child: Text(
      value,
      style: const TextStyle(fontSize: 35, fontWeight: FontWeight.w500),
    ),
  );
}

class _PinReferenceSymbol extends StatelessWidget {
  const _PinReferenceSymbol({super.key, required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) => Center(
    child: Image.asset(
      asset,
      width: 60,
      height: 60,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    ),
  );
}

class _TransferWarningPopup extends StatelessWidget {
  const _TransferWarningPopup({required this.recipientName});

  final String recipientName;

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final scale = min(
      viewport.width / mockupWidth,
      viewport.height / mockupHeight,
    );
    return Center(
      child: Transform.translate(
        offset: Offset(0, 21 * scale),
        child: SizedBox(
          width: 518 * scale,
          height: 301 * scale,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Material(
              key: const Key('transfer-warning-popup'),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: SizedBox(
                width: 518,
                height: 301,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(35, 26, 35, 29),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '한 번 더 확인해 주세요',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 35),
                      Text(
                        '최근에 송금한 적 없는 계좌입니다.\n$recipientName님에게 이체하시겠어요?',
                        key: const Key('transfer-warning-message'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          height: 1.55,
                          fontWeight: FontWeight.w500,
                          letterSpacing: .8,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 69,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                key: const Key('transfer-warning-cancel'),
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.black,
                                  side: const BorderSide(
                                    color: Color(0xFFD2D2D2),
                                    width: 1.4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  '취소',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: OutlinedButton(
                                key: const Key('transfer-warning-confirm'),
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _recipientGreen,
                                  side: const BorderSide(
                                    color: _recipientGreen,
                                    width: 1.4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  '확인',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
  }
}

class _TransferPinMismatchPopup extends StatelessWidget {
  const _TransferPinMismatchPopup({required this.failedAttempts});

  final int failedAttempts;

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final scale = min(
      viewport.width / mockupWidth,
      viewport.height / mockupHeight,
    );
    const bodyStyle = TextStyle(
      color: Colors.black,
      fontSize: 20,
      height: 1.62,
      fontWeight: FontWeight.w500,
      fontFamily: 'NotoSansKRMedium',
      letterSpacing: -.45,
    );

    return Center(
      child: Transform.translate(
        offset: Offset(0, 20 * scale),
        child: SizedBox(
          width: 518 * scale,
          height: 492 * scale,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Material(
              key: const Key('transfer-pin-mismatch-popup'),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: SizedBox(
                width: 518,
                height: 492,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(35, 34, 35, 29),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '안내',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 21,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.4,
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        height: 96,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: RichText(
                            key: const Key('transfer-pin-mismatch-message'),
                            textAlign: TextAlign.center,
                            softWrap: false,
                            text: TextSpan(
                              style: bodyStyle,
                              children: [
                                const TextSpan(text: '계좌 비밀번호가 '),
                                TextSpan(text: '$failedAttempts회'),
                                const TextSpan(
                                  text:
                                      ' 일치하지 않았습니다. 계좌 비\n밀번호는 현금카드 비밀번호와 다를 수 있으며 연속\n5회 오류 시 조회와 이체가 제한됩니다.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      const Text(
                        '(EFAB04934 :\n2609180319080EFABINOPT0111987601)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFE31624),
                          fontSize: 19,
                          height: 1.47,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -.2,
                        ),
                      ),
                      const SizedBox(height: 37),
                      SizedBox(
                        height: 43.75,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/ref_transfer_pin_phone.png',
                                width: 43.75,
                                height: 43.75,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                              const SizedBox(width: 3),
                              const Text(
                                '고객행복센터 : ',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 17.5,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -.45,
                                ),
                              ),
                              const _UnderlinedContact('1661-3000'),
                              const Text(
                                ', ',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 17.5,
                                ),
                              ),
                              const _UnderlinedContact('1522-3000'),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton(
                        key: const Key('transfer-pin-mismatch-confirm'),
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _recipientGreen,
                          side: const BorderSide(
                            color: _recipientGreen,
                            width: 1.4,
                          ),
                          minimumSize: const Size.fromHeight(69),
                          maximumSize: const Size.fromHeight(69),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          '확인',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
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
  }
}

class _UnderlinedContact extends StatelessWidget {
  const _UnderlinedContact(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Colors.black,
      fontSize: 17.5,
      fontWeight: FontWeight.w500,
      letterSpacing: -.35,
      decoration: TextDecoration.underline,
      decorationColor: Colors.black,
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
      child: Transform.translate(
        offset: Offset(0, 87 * scale),
        child: SizedBox(
          width: 435 * scale,
          height: 429 * scale,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Material(
              key: const Key('transfer-failure-popup'),
              elevation: 2,
              shadowColor: const Color(0x18000000),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox(
                width: 435,
                height: 429,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 24,
                      child: Center(
                        child: Image.asset(
                          'assets/images/ref_transfer_failure_brand.jpg',
                          key: const Key('transfer-failure-brand'),
                          width: 164,
                          height: 44,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 25,
                      right: 25,
                      top: 83,
                      child: Column(
                        children: [
                          Text(
                            '거래가 제한되었습니다.',
                            key: Key('transfer-failure-title'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 21,
                              height: 1.28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.5,
                            ),
                          ),
                          Text(
                            '(NH6901)',
                            key: Key('transfer-failure-code'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Positioned(
                      left: 25,
                      right: 25,
                      top: 153,
                      child: Text(
                        '고객님의 계좌가 금융거래 이상거래\n'
                        '(자금세탁 의심거래)로 확인되어\n'
                        '거래가 제한된 계좌입니다.',
                        key: Key('transfer-failure-reason'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 17.5,
                          height: 1.55,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -.35,
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 25,
                      right: 25,
                      top: 246,
                      child: Text(
                        '자세한 내용은 가까운 영업점 또는\n'
                        '고객행복센터(1661-3000)로\n'
                        '문의하시기 바랍니다.',
                        key: Key('transfer-failure-contact'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 17.5,
                          height: 1.55,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -.35,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 25,
                      right: 25,
                      top: 357,
                      height: 57,
                      child: FilledButton(
                        key: const Key('transfer-failure-home-confirm'),
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0AA64F),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '확인',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
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
    );
  }
}
