import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_data.dart';
import '../core/auth_service.dart';
import 'bank_logo.dart';
import 'data_management_screen.dart';
import 'design_canvas.dart';
import 'transfer_recipient_screen.dart';

const _detailsInk = Colors.black;
const _detailsMuted = Colors.black;
const _detailsSecondary = Colors.black;
const _detailsGreen = Color(0xFF159757);

enum _HistoryPeriodMode { monthly, range }

enum _HistoryRangePreset { week, month, threeMonths, sixMonths }

enum _HistoryType { all, deposit, withdrawal, shinhanAtm }

enum _HistorySort { newest, oldest }

@immutable
class _HistoryFilter {
  const _HistoryFilter({
    required this.periodMode,
    required this.rangePreset,
    required this.startDate,
    required this.endDate,
    required this.month,
    required this.type,
    required this.sort,
    this.minimumAmount,
    this.maximumAmount,
  });

  factory _HistoryFilter.initial(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return _HistoryFilter(
      periodMode: _HistoryPeriodMode.range,
      rangePreset: _HistoryRangePreset.month,
      startDate: _subtractMonths(today, 1),
      endDate: today,
      month: DateTime(today.year, today.month),
      type: _HistoryType.all,
      sort: _HistorySort.newest,
    );
  }

  final _HistoryPeriodMode periodMode;
  final _HistoryRangePreset rangePreset;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime month;
  final _HistoryType type;
  final _HistorySort sort;
  final int? minimumAmount;
  final int? maximumAmount;

  _HistoryFilter copyWith({
    _HistoryPeriodMode? periodMode,
    _HistoryRangePreset? rangePreset,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? month,
    _HistoryType? type,
    _HistorySort? sort,
    int? minimumAmount,
    int? maximumAmount,
    bool clearMinimumAmount = false,
    bool clearMaximumAmount = false,
  }) {
    return _HistoryFilter(
      periodMode: periodMode ?? this.periodMode,
      rangePreset: rangePreset ?? this.rangePreset,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      month: month ?? this.month,
      type: type ?? this.type,
      sort: sort ?? this.sort,
      minimumAmount: clearMinimumAmount
          ? null
          : minimumAmount ?? this.minimumAmount,
      maximumAmount: clearMaximumAmount
          ? null
          : maximumAmount ?? this.maximumAmount,
    );
  }

  String get periodLabel => switch (periodMode) {
    _HistoryPeriodMode.monthly =>
      '${month.year}년 ${month.month.toString().padLeft(2, '0')}월',
    _HistoryPeriodMode.range => switch (rangePreset) {
      _HistoryRangePreset.week => '1주일',
      _HistoryRangePreset.month => '1개월',
      _HistoryRangePreset.threeMonths => '3개월',
      _HistoryRangePreset.sixMonths => '6개월',
    },
  };

  String get typeLabel => switch (type) {
    _HistoryType.all => '전체',
    _HistoryType.deposit => '입금',
    _HistoryType.withdrawal => '출금',
    _HistoryType.shinhanAtm => '신한 ATM',
  };

  String get sortLabel => sort == _HistorySort.newest ? '최신순' : '과거순';

  String get summaryLabel => '$periodLabel · $typeLabel · $sortLabel';

  String get rangeLabel {
    String date(DateTime value) =>
        '${value.year}.${value.month.toString().padLeft(2, '0')}.'
        '${value.day.toString().padLeft(2, '0')}';
    if (periodMode == _HistoryPeriodMode.monthly) {
      final start = DateTime(month.year, month.month);
      final end = DateTime(month.year, month.month + 1, 0);
      return '${date(start)} ~ ${date(end)}';
    }
    return '${date(startDate)} ~ ${date(endDate)}';
  }

  List<LedgerTransaction> apply(List<LedgerTransaction> source) {
    final filtered = source.where((transaction) {
      final occurred = transaction.occurredAt;
      final inPeriod = periodMode == _HistoryPeriodMode.monthly
          ? occurred.year == month.year && occurred.month == month.month
          : !occurred.isBefore(startDate) &&
                occurred.isBefore(endDate.add(const Duration(days: 1)));
      if (!inPeriod) return false;

      final typeMatches = switch (type) {
        _HistoryType.all => true,
        _HistoryType.deposit => transaction.signedAmount >= 0,
        _HistoryType.withdrawal => transaction.signedAmount < 0,
        _HistoryType.shinhanAtm => transaction.channel.toUpperCase().contains(
          'ATM',
        ),
      };
      if (!typeMatches) return false;

      final amount = transaction.signedAmount.abs();
      if (minimumAmount != null && amount < minimumAmount!) return false;
      if (maximumAmount != null && amount > maximumAmount!) return false;
      return true;
    }).toList();
    filtered.sort((left, right) {
      final comparison = left.occurredAt.compareTo(right.occurredAt);
      if (comparison != 0) {
        return sort == _HistorySort.newest ? -comparison : comparison;
      }
      return sort == _HistorySort.newest
          ? right.id.compareTo(left.id)
          : left.id.compareTo(right.id);
    });
    return filtered;
  }
}

DateTime _subtractMonths(DateTime date, int months) {
  final targetMonth = DateTime(date.year, date.month - months);
  final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
  return DateTime(
    targetMonth.year,
    targetMonth.month,
    date.day > lastDay ? lastDay : date.day,
  );
}

class AccountDetailsScreen extends StatefulWidget {
  AccountDetailsScreen({
    super.key,
    required this.auth,
    this.initialScrollOffset = 0,
    AppDataStore? dataStore,
    this.accountId,
    this.nowProvider,
  }) : dataStore = dataStore ?? AppDataStore.shared;

  final AuthService auth;
  final AppDataStore dataStore;
  final String? accountId;
  final double initialScrollOffset;
  final DateTime Function()? nowProvider;

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  late final ScrollController _scrollController;
  late double _scrollOffset;
  late _HistoryFilter _historyFilter;
  bool _showTransactionBalances = true;

  DateTime get _now => widget.nowProvider?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    showDeviceStatusBar(darkIcons: true, backgroundColor: Colors.white);
    _scrollOffset = widget.initialScrollOffset;
    _historyFilter = _HistoryFilter.initial(_now);
    _scrollController = ScrollController(
      initialScrollOffset: widget.initialScrollOffset,
    )..addListener(_handleScroll);
    widget.dataStore.addListener(_handleDataChange);
  }

  void _handleScroll() {
    if (!mounted) return;
    final offset = _scrollController.offset;
    if ((offset - _scrollOffset).abs() > 1) {
      setState(() => _scrollOffset = offset);
    }
  }

  @override
  void dispose() {
    widget.dataStore.removeListener(_handleDataChange);
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    showDeviceStatusBar(
      darkIcons: true,
      backgroundColor: const Color(0xFFF0F3FA),
    );
    super.dispose();
  }

  void _handleDataChange() {
    if (mounted) setState(() {});
  }

  void _toggleTransactionBalances() {
    setState(() {
      _showTransactionBalances = !_showTransactionBalances;
    });
  }

  void _goHome() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  Future<void> _openTransferRecipient() async {
    final result = await Navigator.of(context).push<TransferFlowResult>(
      MaterialPageRoute<TransferFlowResult>(
        builder: (_) => TransferRecipientScreen(
          dataStore: widget.dataStore,
          auth: widget.auth,
        ),
      ),
    );
    if (!mounted) return;
    if (result == TransferFlowResult.failed) {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop(result);
      } else {
        await showTransferFailurePopup(context);
      }
      return;
    }
    showDeviceStatusBar(darkIcons: true, backgroundColor: Colors.white);
  }

  Future<void> _openManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DataManagementScreen(
          store: widget.dataStore,
          initialAccountId: _selectedAccount?.id,
        ),
      ),
    );
  }

  Future<void> _openHistoryFilter() async {
    final now = _now;
    final currentYear = now.year;
    final account = _selectedAccount;
    final recordedYears = <int>{
      if (_historyFilter.month.year <= currentYear) _historyFilter.month.year,
      currentYear - 100,
      if (account != null)
        ...widget.dataStore
            .transactionsFor(account.id)
            .map((transaction) => transaction.occurredAt.year)
            .where((year) => year <= currentYear),
    };
    final firstYear = recordedYears.reduce(
      (left, right) => left < right ? left : right,
    );
    final lastYear = recordedYears.reduce(
      (left, right) => left > right ? left : right,
    );
    final availableYears = <int>[
      for (var year = firstYear; year <= lastYear; year++) year,
    ];
    final nextFilter = await showModalBottomSheet<_HistoryFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x990F1420),
      builder: (sheetContext) => MediaQuery(
        data: MediaQuery.of(
          sheetContext,
        ).copyWith(textScaler: TextScaler.noScaling),
        child: _HistoryFilterSheet(
          initialFilter: _historyFilter,
          availableYears: availableYears,
          latestSelectableDate: DateTime(now.year, now.month, now.day),
        ),
      ),
    );
    if (!mounted || nextFilter == null) return;
    setState(() => _historyFilter = nextFilter);
  }

  BankAccount? get _selectedAccount {
    final activeAccounts = widget.dataStore.accounts;
    final requested = widget.accountId;
    if (requested != null) {
      for (final account in activeAccounts) {
        if (account.id == requested) return account;
      }
    }
    return activeAccounts.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final account = _selectedAccount;
    final allTransactions = account == null
        ? const <LedgerTransaction>[]
        : widget.dataStore.transactionsFor(account.id);
    final transactions = _historyFilter.apply(allTransactions);
    final requiredContentHeight =
        _TransactionLayoutMetrics.contentBottom(transactions) +
        _TransactionLayoutMetrics.bottomPadding;
    final contentHeight = requiredContentHeight > 1700
        ? requiredContentHeight
        : 1700.0;
    final collapsed = _scrollOffset >= 360;

    return DesignCanvas(
      backgroundColor: Colors.white,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Colors.white)),
          Positioned.fill(
            child: SingleChildScrollView(
              key: const Key('account-details-scroll'),
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: mockupWidth,
                height: contentHeight,
                child: Stack(
                  children: [
                    _AccountSummary(
                      balance: account == null
                          ? 0
                          : widget.dataStore.balanceFor(account.id),
                      onManage: _openManagement,
                      onTransfer: _openTransferRecipient,
                    ),
                    _TransactionList(
                      account: account,
                      transactions: transactions,
                      store: widget.dataStore,
                      filterLabel: _historyFilter.summaryLabel,
                      rangeLabel: _historyFilter.rangeLabel,
                      onFilterTap: _openHistoryFilter,
                      showTransactionBalances: _showTransactionBalances,
                      onBalanceVisibilityTap: _toggleTransactionBalances,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 301,
            child: const ColoredBox(color: Colors.white),
          ),
          if (collapsed) ...[
            const Positioned(
              left: 0,
              right: 0,
              top: 301,
              height: 66,
              child: ColoredBox(color: Color(0xFFF6F6F6)),
            ),
            _FilterBar(
              top: 301,
              filterKey: const Key('account-history-filter-collapsed'),
              label: _historyFilter.summaryLabel,
              onTap: _openHistoryFilter,
            ),
          ],
          _AccountIdentity(account: account),
          _DetailsHeader(onBack: _goHome, onHome: _goHome),
        ],
      ),
    );
  }
}

class _DetailsHeader extends StatelessWidget {
  const _DetailsHeader({required this.onBack, required this.onHome});

  final VoidCallback onBack;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 100.5,
      height: 58,
      child: Stack(
        children: [
          Positioned(
            left: 35,
            top: -7,
            width: 56,
            height: 63,
            child: Image.asset(
              'assets/images/ref_transaction_back.png',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
            ),
          ),
          Positioned(
            left: 33,
            top: 0,
            width: 50,
            height: 50,
            child: IconButton(
              key: const Key('account-back'),
              tooltip: '뒤로',
              onPressed: onBack,
              padding: EdgeInsets.zero,
              icon: const SizedBox.shrink(),
            ),
          ),
          Positioned(
            left: 135,
            right: 135,
            top: 6,
            child: const Text(
              '거래내역조회',
              key: Key('account-details-title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _detailsInk,
                fontSize: 22.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
              ),
            ),
          ),
          Positioned(
            right: 76,
            top: 0,
            width: 50,
            height: 50,
            child: IconButton(
              key: const Key('account-home'),
              tooltip: '홈',
              onPressed: onHome,
              padding: EdgeInsets.zero,
              icon: const SizedBox.shrink(key: Key('account-home-glyph')),
            ),
          ),
          Positioned(
            right: 23,
            top: -6,
            width: 116,
            height: 63,
            child: Semantics(
              label: '메뉴 검색',
              image: true,
              child: Image.asset(
                'assets/images/ref_transaction_header_actions.png',
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountIdentity extends StatelessWidget {
  const _AccountIdentity({required this.account});

  final BankAccount? account;

  @override
  Widget build(BuildContext context) {
    final accountType = account?.accountType ?? 'NH올원모임통장';
    final bank = account?.bankDisplayName ?? 'NH농협은행';
    final number = account?.accountNumber ?? '302-2180-4371-91';
    return Positioned(
      left: 35,
      right: 42,
      top: 200,
      height: 66,
      child: Row(
        children: [
          ClipRRect(
            key: const Key('account-details-logo'),
            borderRadius: BorderRadius.circular(16),
            child: SizedBox.square(
              dimension: 58,
              child: account == null || account!.bankCode == '농협'
                  ? Image.asset(
                      'assets/images/ref_transaction_nh_logo.png',
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    )
                  : BankLogo(bankCode: account!.bankCode, size: 58),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.translate(
                  offset: const Offset(0, -1.1),
                  child: Text(
                    key: const Key('account-type-text'),
                    accountType,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _detailsInk,
                      fontSize: 22.5,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                      letterSpacing: -1,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Transform.translate(
                  offset: const Offset(0, -0.4),
                  child: Text(
                    key: const Key('account-number-text'),
                    '$bank $number',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _detailsMuted,
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                      letterSpacing: -0.65,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 29,
            height: 58,
            child: Transform.scale(
              scale: 2.32,
              child: Image.asset(
                'assets/images/ref_transaction_account_chevron.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountSummary extends StatelessWidget {
  const _AccountSummary({
    required this.balance,
    required this.onManage,
    required this.onTransfer,
  });

  final int balance;
  final VoidCallback onManage;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 42,
          top: 307.2,
          child: const Text(
            '잔액',
            style: TextStyle(
              color: _detailsSecondary,
              fontSize: 19.5,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.6,
            ),
          ),
        ),
        Positioned(
          right: 41.5,
          top: 300.5,
          child: Text(
            key: const Key('account-balance-text'),
            '${_formatDetailsMoney(balance)}원',
            style: const TextStyle(
              color: _detailsInk,
              fontSize: 29,
              fontWeight: FontWeight.w500,
              letterSpacing: -1.1,
            ),
          ),
        ),
        Positioned(
          left: 35,
          top: 377,
          width: 253,
          height: 61,
          child: _AccountActionButton(
            key: const Key('account-manage'),
            label: '계좌관리',
            onTap: onManage,
          ),
        ),
        Positioned(
          right: 35,
          top: 377,
          width: 253,
          height: 61,
          child: _AccountActionButton(
            key: const Key('account-transfer'),
            label: '이체',
            accent: true,
            onTap: onTransfer,
          ),
        ),
        const Positioned(
          left: 35,
          right: 35,
          top: 486,
          height: 127,
          child: _TransactionBanner(),
        ),
      ],
    );
  }
}

class _AccountActionButton extends StatelessWidget {
  const _AccountActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        foregroundColor: accent ? const Color(0xFF16A05A) : _detailsInk,
        side: BorderSide(
          color: accent ? const Color(0xFF16A05A) : const Color(0xFFD5D7D7),
          width: 1.25,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.8,
        ),
      ),
    );
  }
}

class _TransactionBanner extends StatelessWidget {
  const _TransactionBanner();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/ref_transaction_banner.png',
      key: const Key('account-transaction-promotion'),
      fit: BoxFit.fill,
      filterQuality: FilterQuality.high,
    );
  }
}

class _TransactionList extends StatelessWidget {
  const _TransactionList({
    required this.account,
    required this.transactions,
    required this.store,
    required this.filterLabel,
    required this.rangeLabel,
    required this.onFilterTap,
    required this.showTransactionBalances,
    required this.onBalanceVisibilityTap,
  });

  final BankAccount? account;
  final List<LedgerTransaction> transactions;
  final AppDataStore store;
  final String filterLabel;
  final String rangeLabel;
  final VoidCallback onFilterTap;
  final bool showTransactionBalances;
  final VoidCallback onBalanceVisibilityTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _FilterBar(
          top: 670.8,
          filterKey: const Key('account-history-filter'),
          label: filterLabel,
          onTap: onFilterTap,
        ),
        Positioned(
          left: 35,
          top: 751.3,
          child: Text(
            key: const Key('account-history-range'),
            rangeLabel,
            style: const TextStyle(
              color: _detailsSecondary,
              fontSize: 18.5,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.55,
            ),
          ),
        ),
        Positioned(
          right: 30,
          top: 751.8,
          child: _BalanceVisibilityToggle(
            isVisible: showTransactionBalances,
            onTap: onBalanceVisibilityTap,
          ),
        ),
        const Positioned(
          left: 35,
          right: 35,
          top: 847,
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E3E3)),
        ),
        ..._transactionWidgets(),
      ],
    );
  }

  List<Widget> _transactionWidgets() {
    if (account == null || transactions.isEmpty) {
      return [
        Positioned(
          left: 0,
          right: 0,
          top: 892,
          child: const Text(
            '거래내역이 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _detailsMuted,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ];
    }
    final widgets = <Widget>[];
    var cursor = _TransactionLayoutMetrics.firstRowTop;
    for (final transaction in transactions) {
      final signed = transaction.signedAmount;
      widgets.add(
        _TransactionRow(
          top: cursor,
          title: transaction.title,
          transactionId: transaction.id,
          dateTime:
              '${_formatDetailsDateTime(transaction.occurredAt)}'
              '${transaction.channel.trim().isEmpty ? '' : ' | ${transaction.channel.trim()}'}',
          amount: '${_formatDetailsMoney(signed.abs())}원',
          balance:
              '${_formatDetailsMoney(store.runningBalanceFor(transaction))}원',
          showBalance: showTransactionBalances,
          positive: signed >= 0,
        ),
      );
      cursor += _TransactionLayoutMetrics.rowExtent;
    }
    return widgets;
  }
}

class _BalanceVisibilityToggle extends StatelessWidget {
  const _BalanceVisibilityToggle({
    required this.isVisible,
    required this.onTap,
  });

  final bool isVisible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '거래 후 잔액 표시',
      button: true,
      toggled: isVisible,
      child: GestureDetector(
        key: const Key('account-balance-visibility-toggle'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isVisible ? '잔액 숨기기' : '잔액 보기',
              style: const TextStyle(
                color: _detailsInk,
                fontSize: 19,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              key: const Key('account-balance-visibility-track'),
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: 43,
              height: 29,
              decoration: BoxDecoration(
                color: isVisible
                    ? const Color(0xFF8D8F90)
                    : const Color(0xFF16A05A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: AnimatedAlign(
                key: const Key('account-balance-visibility-knob'),
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                alignment: isVisible
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  width: 25,
                  height: 25,
                  margin: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
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

class _TransactionLayoutMetrics {
  const _TransactionLayoutMetrics._();

  static const firstRowTop = 881.0;
  static const rowExtent = 179.0;
  static const bottomPadding = 80.0;

  static double contentBottom(List<LedgerTransaction> transactions) =>
      firstRowTop + (transactions.length * rowExtent);
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.top,
    required this.filterKey,
    required this.label,
    required this.onTap,
  });

  final double top;
  final Key filterKey;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: top,
      height: 66,
      child: ColoredBox(
        color: const Color(0xFFF6F6F6),
        child: Align(
          alignment: Alignment.centerRight,
          child: Semantics(
            label: '조회 조건 $label',
            button: true,
            child: GestureDetector(
              key: filterKey,
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 40.5, 18),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(width: 15),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 24,
                      color: _detailsInk,
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

class _HistoryFilterSheet extends StatefulWidget {
  const _HistoryFilterSheet({
    required this.initialFilter,
    required this.availableYears,
    required this.latestSelectableDate,
  });

  final _HistoryFilter initialFilter;
  final List<int> availableYears;
  final DateTime latestSelectableDate;

  @override
  State<_HistoryFilterSheet> createState() => _HistoryFilterSheetState();
}

class _HistoryFilterSheetState extends State<_HistoryFilterSheet> {
  late _HistoryFilter _filter;
  late final TextEditingController _minimumController;
  late final TextEditingController _maximumController;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter.copyWith(
      periodMode: _HistoryPeriodMode.monthly,
      month: DateTime(
        widget.latestSelectableDate.year,
        widget.latestSelectableDate.month,
      ),
      type: _HistoryType.all,
      sort: _HistorySort.oldest,
    );
    _minimumController = TextEditingController(
      text: _filter.minimumAmount?.toString() ?? '',
    );
    _maximumController = TextEditingController(
      text: _filter.maximumAmount?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _minimumController.dispose();
    _maximumController.dispose();
    super.dispose();
  }

  void _setRangePreset(_HistoryRangePreset preset) {
    final endDate = widget.latestSelectableDate;
    final startDate = switch (preset) {
      _HistoryRangePreset.week => endDate.subtract(const Duration(days: 7)),
      _HistoryRangePreset.month => _subtractMonths(endDate, 1),
      _HistoryRangePreset.threeMonths => _subtractMonths(endDate, 3),
      _HistoryRangePreset.sixMonths => _subtractMonths(endDate, 6),
    };
    setState(() {
      _filter = _filter.copyWith(
        periodMode: _HistoryPeriodMode.range,
        rangePreset: preset,
        startDate: startDate,
        endDate: endDate,
      );
    });
  }

  Future<void> _pickRangeDate({required bool start}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: start ? _filter.startDate : _filter.endDate,
      firstDate: DateTime(widget.availableYears.first),
      lastDate: widget.latestSelectableDate,
      helpText: start ? '시작일 선택' : '종료일 선택',
      cancelText: '취소',
      confirmText: '확인',
    );
    if (!mounted || selected == null) return;
    setState(() {
      _filter = start
          ? _filter.copyWith(startDate: selected)
          : _filter.copyWith(endDate: selected);
    });
  }

  Future<void> _pickMonth() async {
    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x990F1420),
      builder: (sheetContext) => MediaQuery(
        data: MediaQuery.of(
          sheetContext,
        ).copyWith(textScaler: TextScaler.noScaling),
        child: _MonthPickerSheet(
          initialMonth: _filter.month,
          availableYears: widget.availableYears,
          latestSelectableMonth: DateTime(
            widget.latestSelectableDate.year,
            widget.latestSelectableDate.month,
          ),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _filter = _filter.copyWith(month: selected));
  }

  Future<void> _showValidationDialog(String message) async {
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0x66000000),
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(35, 54, 35, 29),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                message,
                style: const TextStyle(
                  color: _detailsInk,
                  fontSize: 20,
                  height: 1.7,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 43),
              SizedBox(
                height: 71,
                child: OutlinedButton(
                  key: const Key('history-filter-validation-confirm'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _detailsGreen,
                    side: const BorderSide(color: _detailsGreen, width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final minimum = int.tryParse(_minimumController.text);
    final maximum = int.tryParse(_maximumController.text);
    final today = DateTime(
      widget.latestSelectableDate.year,
      widget.latestSelectableDate.month,
      widget.latestSelectableDate.day,
    );
    final startsInFuture = _filter.periodMode == _HistoryPeriodMode.monthly
        ? DateTime(_filter.month.year, _filter.month.month).isAfter(today)
        : _filter.startDate.isAfter(today);
    if (startsInFuture) {
      await _showValidationDialog('조회시작날짜는 오늘날짜이거나 과거날짜이어야합니다.');
      return;
    }
    if (_filter.periodMode == _HistoryPeriodMode.range &&
        _filter.startDate.isAfter(_filter.endDate)) {
      await _showValidationDialog('시작일은 종료일보다 늦을 수 없습니다.');
      return;
    }
    if (minimum != null && maximum != null && minimum > maximum) {
      await _showValidationDialog('최소금액은 최대금액보다 클 수 없습니다.');
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(
      _filter.copyWith(
        minimumAmount: _showAdvanced ? minimum : null,
        maximumAmount: _showAdvanced ? maximum : null,
        clearMinimumAmount: !_showAdvanced || minimum == null,
        clearMaximumAmount: !_showAdvanced || maximum == null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _buildReferenceFilter(context);

  Widget _buildReferenceFilter(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final unit = (mediaQuery.size.width / 588).clamp(.62, 1.0);
    double u(double value) => value * unit;
    final horizontalPadding = u(35);
    final choiceGap = u(7);
    final choiceHeight = u(54);

    return FractionallySizedBox(
      heightFactor: _showAdvanced ? .95 : .777,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(u(28))),
        ),
        child: Stack(
          children: [
            Positioned(
              left: horizontalPadding,
              right: u(72),
              top: u(28),
              height: u(46),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '조회 조건을 선택해 주세요',
                  style: TextStyle(
                    color: _detailsInk,
                    fontSize: u(27),
                    fontWeight: FontWeight.w700,
                    letterSpacing: u(-1),
                  ),
                ),
              ),
            ),
            Positioned(
              right: u(22),
              top: u(24),
              width: u(52),
              height: u(52),
              child: IconButton(
                key: const Key('history-filter-close'),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.close_rounded,
                  size: u(35),
                  color: _detailsInk,
                ),
              ),
            ),
            Positioned(
              left: horizontalPadding,
              top: u(108),
              child: _FilterSectionTitle('조회 기간', unit: unit),
            ),
            Positioned(
              left: horizontalPadding,
              right: horizontalPadding,
              top: u(155),
              height: choiceHeight,
              child: Row(
                children: [
                  for (final entry in const [
                    (_HistoryRangePreset.week, '1주일'),
                    (_HistoryRangePreset.month, '1개월'),
                    (_HistoryRangePreset.threeMonths, '3개월'),
                    (_HistoryRangePreset.sixMonths, '6개월'),
                  ]) ...[
                    Expanded(
                      child: _FilterChoiceButton(
                        key: Key('history-range-${entry.$1.name}'),
                        label: entry.$2,
                        selected:
                            _filter.periodMode == _HistoryPeriodMode.range &&
                            _filter.rangePreset == entry.$1,
                        height: choiceHeight,
                        unit: unit,
                        onTap: () => _setRangePreset(entry.$1),
                      ),
                    ),
                    if (entry.$1 != _HistoryRangePreset.sixMonths)
                      SizedBox(width: choiceGap),
                  ],
                ],
              ),
            ),
            Positioned(
              left: horizontalPadding,
              right: horizontalPadding,
              top: u(226),
              height: choiceHeight,
              child: Row(
                children: [
                  Expanded(
                    child: _FilterChoiceButton(
                      key: const Key('history-period-monthly'),
                      label: '월별',
                      selected:
                          _filter.periodMode == _HistoryPeriodMode.monthly,
                      height: choiceHeight,
                      unit: unit,
                      onTap: () => setState(
                        () => _filter = _filter.copyWith(
                          periodMode: _HistoryPeriodMode.monthly,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: choiceGap),
                  Expanded(
                    child: _FilterChoiceButton(
                      key: const Key('history-period-range'),
                      label: '기간선택',
                      selected: _filter.periodMode == _HistoryPeriodMode.range,
                      height: choiceHeight,
                      unit: unit,
                      onTap: () => setState(
                        () => _filter = _filter.copyWith(
                          periodMode: _HistoryPeriodMode.range,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: horizontalPadding,
              right: horizontalPadding,
              top: u(298),
              height: u(79),
              child: _buildPeriodField(unit),
            ),
            Positioned(
              left: horizontalPadding,
              top: u(430),
              child: _FilterSectionTitle('정렬 순서', unit: unit),
            ),
            Positioned(
              left: horizontalPadding,
              right: horizontalPadding,
              top: u(474),
              height: choiceHeight,
              child: Row(
                children: [
                  Expanded(
                    child: _FilterChoiceButton(
                      key: const Key('history-sort-newest'),
                      label: '최신순',
                      selected: _filter.sort == _HistorySort.newest,
                      height: choiceHeight,
                      unit: unit,
                      onTap: () => setState(
                        () => _filter = _filter.copyWith(
                          sort: _HistorySort.newest,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: choiceGap),
                  Expanded(
                    child: _FilterChoiceButton(
                      key: const Key('history-sort-oldest'),
                      label: '과거순',
                      selected: _filter.sort == _HistorySort.oldest,
                      height: choiceHeight,
                      unit: unit,
                      onTap: () => setState(
                        () => _filter = _filter.copyWith(
                          sort: _HistorySort.oldest,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: horizontalPadding,
              top: u(578),
              child: _FilterSectionTitle('조회 구분', unit: unit),
            ),
            Positioned(
              left: horizontalPadding,
              right: horizontalPadding,
              top: u(626),
              height: choiceHeight,
              child: Row(
                children: [
                  for (final entry in const [
                    (_HistoryType.all, '전체'),
                    (_HistoryType.deposit, '입금'),
                    (_HistoryType.withdrawal, '출금'),
                  ]) ...[
                    Expanded(
                      child: _FilterChoiceButton(
                        key: Key('history-type-${entry.$1.name}'),
                        label: entry.$2,
                        selected: _filter.type == entry.$1,
                        height: choiceHeight,
                        unit: unit,
                        onTap: () => setState(
                          () => _filter = _filter.copyWith(type: entry.$1),
                        ),
                      ),
                    ),
                    if (entry.$1 != _HistoryType.withdrawal)
                      SizedBox(width: choiceGap),
                  ],
                ],
              ),
            ),
            Positioned(
              left: horizontalPadding,
              right: horizontalPadding,
              top: u(728),
              height: u(48),
              child: Row(
                children: [
                  Text(
                    '상세',
                    style: TextStyle(
                      color: _detailsInk,
                      fontSize: u(20),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    key: const Key('history-filter-advanced-toggle'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: u(41),
                      height: u(27),
                      padding: EdgeInsets.all(u(2)),
                      decoration: BoxDecoration(
                        color: _showAdvanced
                            ? _detailsGreen
                            : const Color(0xFF858585),
                        borderRadius: BorderRadius.circular(u(16)),
                      ),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 160),
                        alignment: _showAdvanced
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: u(23),
                          height: u(23),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_showAdvanced)
              Positioned(
                left: horizontalPadding,
                right: horizontalPadding,
                top: u(790),
                height: u(58),
                child: Row(
                  children: [
                    Expanded(
                      child: _AmountFilterField(
                        key: const Key('history-minimum-amount'),
                        controller: _minimumController,
                        hint: '최소금액',
                        height: u(58),
                        unit: unit,
                      ),
                    ),
                    SizedBox(width: u(16)),
                    Text('~', style: TextStyle(fontSize: u(20))),
                    SizedBox(width: u(16)),
                    Expanded(
                      child: _AmountFilterField(
                        key: const Key('history-maximum-amount'),
                        controller: _maximumController,
                        hint: '최대금액',
                        height: u(58),
                        unit: unit,
                      ),
                    ),
                  ],
                ),
              ),
            Positioned(
              left: horizontalPadding,
              right: horizontalPadding,
              bottom: mediaQuery.padding.bottom,
              height: u(83),
              child: FilledButton(
                key: const Key('history-filter-apply'),
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _detailsGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(u(15)),
                  ),
                ),
                child: Text(
                  '확인',
                  style: TextStyle(
                    fontSize: u(24),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodField(double unit) {
    double u(double value) => value * unit;
    final border = Border.all(color: const Color(0xFFD7D7D7));
    if (_filter.periodMode == _HistoryPeriodMode.monthly) {
      return InkWell(
        key: const Key('history-month-field'),
        onTap: _pickMonth,
        borderRadius: BorderRadius.circular(u(14)),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: u(30)),
          decoration: BoxDecoration(
            border: border,
            borderRadius: BorderRadius.circular(u(14)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_filter.month.year}년 '
                  '${_filter.month.month.toString().padLeft(2, '0')}월',
                  style: TextStyle(
                    color: _detailsInk,
                    fontSize: u(27),
                    fontWeight: FontWeight.w500,
                    letterSpacing: u(-.8),
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: u(29),
                color: _detailsInk,
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        border: border,
        borderRadius: BorderRadius.circular(u(14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _DateFilterField(
              key: const Key('history-start-date'),
              date: _filter.startDate,
              unit: unit,
              onTap: () => _pickRangeDate(start: true),
            ),
          ),
          Text(
            '~',
            style: TextStyle(
              color: _detailsInk,
              fontSize: u(22),
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: _DateFilterField(
              key: const Key('history-end-date'),
              date: _filter.endDate,
              unit: unit,
              onTap: () => _pickRangeDate(start: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSectionTitle extends StatelessWidget {
  const _FilterSectionTitle(this.label, {this.unit = 1});

  final String label;
  final double unit;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: _detailsSecondary,
        fontSize: 19 * unit,
        fontWeight: FontWeight.w500,
        letterSpacing: -.5 * unit,
      ),
    );
  }
}

class _FilterChoiceButton extends StatelessWidget {
  const _FilterChoiceButton({
    super.key,
    required this.label,
    required this.selected,
    required this.height,
    required this.onTap,
    this.unit = 1,
  });

  final String label;
  final bool selected;
  final double height;
  final VoidCallback onTap;
  final double unit;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12 * unit),
          border: Border.all(
            color: selected ? _detailsGreen : const Color(0xFFD5D5D5),
            width: selected ? 1.7 * unit : 1.1 * unit,
          ),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? _detailsGreen : _detailsInk,
              fontSize: 20 * unit,
              height: 1.25,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _DateFilterField extends StatelessWidget {
  const _DateFilterField({
    super.key,
    required this.date,
    required this.onTap,
    this.unit = 1,
  });

  final DateTime date;
  final VoidCallback onTap;
  final double unit;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Center(
        child: Text(
          '${date.year}.${date.month.toString().padLeft(2, '0')}.'
          '${date.day.toString().padLeft(2, '0')}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _detailsInk,
            fontSize: 22 * unit,
            fontWeight: FontWeight.w500,
            letterSpacing: -.4 * unit,
          ),
        ),
      ),
    );
  }
}

class _AmountFilterField extends StatelessWidget {
  const _AmountFilterField({
    super.key,
    required this.controller,
    required this.hint,
    required this.height,
    this.unit = 1,
  });

  final TextEditingController controller;
  final String hint;
  final double height;
  final double unit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _detailsInk,
          fontSize: 18 * unit,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black),
          contentPadding: EdgeInsets.symmetric(horizontal: 10 * unit),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14 * unit),
            borderSide: const BorderSide(color: Color(0xFFD4D8DF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14 * unit),
            borderSide: BorderSide(color: _detailsGreen, width: 1.8 * unit),
          ),
        ),
      ),
    );
  }
}

class _MonthPickerSheet extends StatefulWidget {
  const _MonthPickerSheet({
    required this.initialMonth,
    required this.availableYears,
    required this.latestSelectableMonth,
  });

  final DateTime initialMonth;
  final List<int> availableYears;
  final DateTime latestSelectableMonth;

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late int _year;
  late int _month;
  late final List<int> _years;
  late final FixedExtentScrollController _yearController;
  late final FixedExtentScrollController _monthController;

  int _lastMonthForYear(int year) => 12;

  @override
  void initState() {
    super.initState();
    _years =
        widget.availableYears
            .where((year) => year <= widget.latestSelectableMonth.year)
            .toSet()
            .toList()
          ..sort();
    _year = widget.initialMonth.year.clamp(_years.first, _years.last).toInt();
    _month = widget.initialMonth.month
        .clamp(1, _lastMonthForYear(_year))
        .toInt();
    _yearController = FixedExtentScrollController(
      initialItem: _years.indexOf(_year),
    );
    _monthController = FixedExtentScrollController(initialItem: _month - 1);
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final unit = (mediaQuery.size.width / 588).clamp(.62, 1.0);
    double u(double value) => value * unit;
    final horizontalPadding = u(35);
    final wheelItemExtent = u(80);
    return SizedBox(
      height: mediaQuery.size.width * 1.23,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(u(28))),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  u(27),
                  u(22),
                  u(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '연/월을 선택해 주세요',
                        style: TextStyle(
                          color: _detailsInk,
                          fontSize: u(27),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('history-month-picker-close'),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.close_rounded, size: u(35)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: mediaQuery.size.width / 2,
                      right: horizontalPadding,
                      height: wheelItemExtent,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F7),
                          borderRadius: BorderRadius.circular(u(15)),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: ListWheelScrollView.useDelegate(
                            key: const Key('history-year-wheel'),
                            controller: _yearController,
                            itemExtent: wheelItemExtent,
                            physics: const FixedExtentScrollPhysics(),
                            diameterRatio: 1.7,
                            onSelectedItemChanged: (index) {
                              final nextYear = _years[index];
                              final nextMonth = _month
                                  .clamp(1, _lastMonthForYear(nextYear))
                                  .toInt();
                              setState(() {
                                _year = nextYear;
                                _month = nextMonth;
                              });
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted ||
                                    !_monthController.hasClients ||
                                    _monthController.selectedItem ==
                                        nextMonth - 1) {
                                  return;
                                }
                                _monthController.jumpToItem(nextMonth - 1);
                              });
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: _years.length,
                              builder: (context, index) {
                                final value = _years[index];
                                return Center(
                                  child: Text(
                                    '$value년',
                                    key: Key('history-year-option-$value'),
                                    style: TextStyle(
                                      color: value == _year
                                          ? _detailsGreen
                                          : _detailsInk,
                                      fontSize: u(24),
                                      fontWeight: value == _year
                                          ? FontWeight.w500
                                          : FontWeight.w500,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListWheelScrollView.useDelegate(
                            key: const Key('history-month-wheel'),
                            controller: _monthController,
                            itemExtent: wheelItemExtent,
                            physics: const FixedExtentScrollPhysics(),
                            diameterRatio: 1.7,
                            onSelectedItemChanged: (index) {
                              setState(() => _month = index + 1);
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: _lastMonthForYear(_year),
                              builder: (context, index) {
                                final value = index + 1;
                                return Center(
                                  child: Text(
                                    '${value.toString().padLeft(2, '0')}월',
                                    key: Key('history-month-option-$value'),
                                    style: TextStyle(
                                      color: value == _month
                                          ? _detailsGreen
                                          : _detailsInk,
                                      fontSize: u(24),
                                      fontWeight: value == _month
                                          ? FontWeight.w500
                                          : FontWeight.w500,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  u(8),
                  horizontalPadding,
                  0,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: u(83),
                  child: FilledButton(
                    key: const Key('history-month-picker-apply'),
                    onPressed: () =>
                        Navigator.of(context).pop(DateTime(_year, _month)),
                    style: FilledButton.styleFrom(
                      backgroundColor: _detailsGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(u(15)),
                      ),
                    ),
                    child: Text(
                      '확인',
                      style: TextStyle(
                        fontSize: u(24),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.top,
    required this.title,
    required this.transactionId,
    required this.dateTime,
    required this.amount,
    required this.balance,
    required this.showBalance,
    this.positive = false,
  });

  final double top;
  final String title;
  final String transactionId;
  final String dateTime;
  final String amount;
  final String balance;
  final bool showBalance;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 35,
      right: 35,
      top: top,
      height: _TransactionLayoutMetrics.rowExtent,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 36,
            width: 320,
            height: 36,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _detailsInk,
                fontSize: 24,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.8,
              ),
            ),
          ),
          Positioned(
            right: 5,
            top: positive ? 3 : 5.1,
            child: Text(
              positive ? '입금' : '출금',
              style: TextStyle(
                color: positive
                    ? const Color(0xFF1976D2)
                    : const Color(0xFFEF4D4F),
                fontSize: 19,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.6,
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: dateTime.contains('|') ? 1.25 : 1,
            width: 340,
            child: Text(
              key: Key('account-transaction-time-$transactionId'),
              dateTime,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _detailsSecondary,
                fontSize: 17,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.4,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: positive ? 36.7 : 33.4,
            child: Text(
              amount,
              style: TextStyle(
                color: positive
                    ? const Color(0xFF1976D2)
                    : const Color(0xFFEF4D4F),
                fontSize: 28,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.8,
              ),
            ),
          ),
          if (showBalance)
            Positioned(
              right: 0,
              top: positive ? 77.9 : 79,
              child: Text(
                key: Key('account-transaction-balance-$transactionId'),
                '잔액 $balance',
                style: const TextStyle(
                  color: _detailsMuted,
                  fontSize: 19.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 36,
            child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E3E3)),
          ),
        ],
      ),
    );
  }
}

String _formatDetailsMoney(int value) => value.toString().replaceAllMapped(
  RegExp(r'(?<!^)(?=(\d{3})+$)'),
  (_) => ',',
);

String _formatDetailsDateTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}.${two(value.month)}.${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
}
