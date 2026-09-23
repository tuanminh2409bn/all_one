import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_data.dart';
import '../core/auth_service.dart';
import '../core/data_bootstrap.dart';
import 'account_details_screen.dart';
import 'auth_sheet.dart';
import 'data_management_screen.dart';
import 'design_canvas.dart' show showDeviceStatusBar;
import 'limit_release_screen.dart';
import 'native_home_view.dart';
import 'transfer_loading_overlay.dart';
import 'transfer_recipient_screen.dart';

const _loginLabel = '로그인';
const _green = Color(0xFF159757);

class HomeScreen extends StatefulWidget {
  HomeScreen({
    super.key,
    required this.auth,
    this.initialScrollOffset = 0,
    AppDataStore? dataStore,
  }) : dataStore = dataStore ?? AppDataStore.shared;

  final AuthService auth;
  final AppDataStore dataStore;

  /// Offset is expressed in the 588 px-wide mockup coordinate system.
  final double initialScrollOffset;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ScrollController _homeScroll;
  bool _hideAmounts = false;
  bool _largeText = false;
  bool _nhTab = true;
  int _loadingPlaybackId = 0;
  final _benefitsKey = GlobalKey();
  final _assetsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    showDeviceStatusBar(darkIcons: true, backgroundColor: Colors.white);
    _homeScroll = ScrollController(
      initialScrollOffset: widget.initialScrollOffset,
      keepScrollOffset: false,
    );
    widget.dataStore.addListener(_handleDataChange);
  }

  @override
  void dispose() {
    widget.dataStore.removeListener(_handleDataChange);
    _homeScroll.dispose();
    super.dispose();
  }

  void _handleDataChange() {
    if (mounted) setState(() {});
  }

  String get _accountLabel =>
      widget.auth.isSignedIn ? widget.auth.displayName : _loginLabel;

  BankAccount? get _primaryAccount => widget.dataStore.accounts.firstOrNull;

  int get _balance {
    final account = _primaryAccount;
    return account == null ? 0 : widget.dataStore.balanceFor(account.id);
  }

  int get _netAssets {
    final accounts = widget.dataStore.accounts;
    if (accounts.isEmpty) return 750998;
    return accounts.fold(
      0,
      (total, account) => total + widget.dataStore.balanceFor(account.id),
    );
  }

  String _money(int amount) {
    if (_hideAmounts) return '******';
    final digits = amount.abs().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      final remaining = digits.length - index;
      buffer.write(digits[index]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
    }
    return buffer.toString();
  }

  Future<void> _showAccount() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final signedIn = widget.auth.isSignedIn;
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7DCDE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '계정',
                  style: TextStyle(
                    color: _green,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE7F5ED),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: _green,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            signedIn ? '${widget.auth.displayName} 님' : '로그인',
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            signedIn
                                ? '안전하게 로그인되어 있습니다.'
                                : '로그인하고 모든 금융 서비스를 이용해 보세요.',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                FilledButton(
                  key: const Key('account-auth-action'),
                  onPressed: () => Navigator.of(
                    sheetContext,
                  ).pop(signedIn ? 'logout' : 'login'),
                  style: FilledButton.styleFrom(
                    backgroundColor: signedIn
                        ? const Color(0xFF222728)
                        : _green,
                    minimumSize: const Size.fromHeight(55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    signedIn ? '로그아웃' : '로그인 / 회원가입',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    if (action == 'login') {
      final authenticated = await showAuthSheet(context, auth: widget.auth);
      if (authenticated) {
        await initializeUserData(widget.auth, store: widget.dataStore);
      }
      if (mounted) setState(() {});
    } else if (action == 'logout') {
      await widget.auth.signOut();
      await initializeUserData(widget.auth, store: widget.dataStore);
      if (mounted) setState(() {});
    }
  }

  Future<void> _openAccountDetails() async {
    await const AssetImage('assets/images/loading_original.png').evict();
    if (!mounted) return;

    final loadingDone = Completer<void>();
    final routeResult = Completer<TransferFlowResult?>();
    final playbackId = ++_loadingPlaybackId;
    final loadingOverlay = Overlay.of(context, rootOverlay: true);
    var routeOpened = false;
    late final OverlayEntry loadingEntry;

    void openDetails() {
      if (routeOpened || !mounted) return;
      routeOpened = true;
      final result = Navigator.of(context).push<TransferFlowResult>(
        PageRouteBuilder<TransferFlowResult>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, __, ___) => AccountDetailsScreen(
            auth: widget.auth,
            dataStore: widget.dataStore,
            accountId: _primaryAccount?.id,
          ),
        ),
      );
      loadingOverlay.rearrange([loadingEntry], below: loadingEntry);
      unawaited(
        result.then((value) {
          if (!routeResult.isCompleted) routeResult.complete(value);
        }),
      );
    }

    loadingEntry = OverlayEntry(
      builder: (_) => TransferLoadingOverlay(
        key: const Key('home-loading-to-account-details'),
        playbackKey: playbackId,
        duration: homeToAccountDetailsLoadingDuration,
        backdropSwitchDelay: homeToAccountDetailsScreenSwitchDelay,
        onBackdropSwitch: openDetails,
        onComplete: () {
          loadingEntry.remove();
          if (!loadingDone.isCompleted) loadingDone.complete();
        },
      ),
    );
    loadingOverlay.insert(loadingEntry);
    await loadingDone.future;
    if (!routeOpened) openDetails();
    if (!mounted) return;
    final result = await routeResult.future;
    if (!mounted) return;
    showDeviceStatusBar(darkIcons: true, backgroundColor: Colors.white);
    if (result == TransferFlowResult.failed) {
      await showTransferFailurePopup(context);
    }
  }

  Future<void> _openLimitRelease() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            LimitReleaseScreen(account: _primaryAccount, balance: _balance),
      ),
    );
    if (mounted) {
      showDeviceStatusBar(darkIcons: true, backgroundColor: Colors.white);
    }
  }

  Future<void> _openTransfer() async {
    await const AssetImage('assets/images/loading_original.png').evict();
    if (!mounted) return;

    final loadingDone = Completer<void>();
    final routeResult = Completer<TransferFlowResult?>();
    final playbackId = ++_loadingPlaybackId;
    var routeOpened = false;
    late final OverlayEntry loadingEntry;

    void openRecipient() {
      if (routeOpened || !mounted) return;
      routeOpened = true;
      unawaited(
        Navigator.of(context)
            .push<TransferFlowResult>(
              PageRouteBuilder<TransferFlowResult>(
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
                pageBuilder: (_, __, ___) => TransferRecipientScreen(
                  dataStore: widget.dataStore,
                  auth: widget.auth,
                ),
              ),
            )
            .then((result) {
              if (!routeResult.isCompleted) routeResult.complete(result);
            }),
      );
    }

    loadingEntry = OverlayEntry(
      builder: (_) => TransferLoadingOverlay(
        key: const Key('transfer-loading-homeToRecipient'),
        playbackKey: playbackId,
        duration: transferHomeToRecipientLoadingDuration,
        scrimDelay: transferHomeToRecipientScreenSwitchDelay,
        onScrimShown: openRecipient,
        onComplete: () {
          loadingEntry.remove();
          if (!loadingDone.isCompleted) loadingDone.complete();
        },
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(loadingEntry);
    await loadingDone.future;
    if (!routeOpened) openRecipient();
    final result = await routeResult.future;
    if (!mounted) return;
    showDeviceStatusBar(darkIcons: true, backgroundColor: Colors.white);
    if (result == TransferFlowResult.failed) {
      await showTransferFailurePopup(context);
    }
  }

  Future<void> _openData({int tab = 0}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DataManagementScreen(
          store: widget.dataStore,
          initialAccountId: _primaryAccount?.id,
          initialTab: tab,
        ),
      ),
    );
    if (mounted) {
      showDeviceStatusBar(darkIcons: true, backgroundColor: Colors.white);
    }
  }

  Future<void> _copyAccountNumber(String number) async {
    await Clipboard.setData(ClipboardData(text: number.replaceAll('-', '')));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('계좌번호가 복사되었습니다.')));
  }

  Future<void> _scrollToAssets() async {
    final targetContext = _assetsKey.currentContext;
    if (targetContext == null) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _scrollToBenefits() async {
    final targetContext = _benefitsKey.currentContext;
    if (targetContext == null) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = _primaryAccount;
    return NativeHomeView(
      scrollController: _homeScroll,
      benefitsKey: _benefitsKey,
      assetsKey: _assetsKey,
      accountName: _accountLabel,
      account: account,
      balanceLabel: '${_money(_balance)}원',
      netAssetsLabel: '${_money(_netAssets)}원',
      spendingLabel: '${_money(50700)}원',
      scheduledLabel: '${_money(0)}원',
      hideAmounts: _hideAmounts,
      largeText: _largeText,
      nhSelected: _nhTab,
      onAccountTap: _showAccount,
      onToggleLargeText: () => setState(() => _largeText = !_largeText),
      onMenuTap: _scrollToBenefits,
      onSelectNh: () => setState(() => _nhTab = true),
      onSelectOther: () => setState(() => _nhTab = false),
      onLimitRelease: _openLimitRelease,
      onOpenDetails: _openAccountDetails,
      onTransfer: _openTransfer,
      onCopyAccount: account == null
          ? null
          : () => _copyAccountNumber(account.accountNumber),
      onToggleHide: () => setState(() => _hideAmounts = !_hideAmounts),
      onAccounts: _openData,
      onAllAccounts: _openData,
      onScrollToAssets: _scrollToAssets,
    );
  }
}
