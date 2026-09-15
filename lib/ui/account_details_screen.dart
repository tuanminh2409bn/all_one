import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_data.dart';
import '../core/auth_service.dart';
import 'bank_logo.dart';
import 'data_management_screen.dart';
import 'design_canvas.dart';
import 'transfer_recipient_screen.dart';

const _detailsInk = Color(0xFF141820);
const _detailsMuted = Color(0xFF626B79);
const _detailsSecondary = Color(0xFF505866);
const _detailsBlue = Color(0xFF0068F5);

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
      currentYear - 3,
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
      top: 76,
      height: 58,
      child: Stack(
        children: [
          Positioned(
            left: 26,
            top: 0,
            width: 50,
            height: 50,
            child: IconButton(
              key: const Key('account-back'),
              tooltip: '뒤로',
              onPressed: onBack,
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.arrow_back_rounded,
                size: 32,
                color: _detailsInk,
              ),
            ),
          ),
          const Positioned(
            left: 135,
            right: 135,
            top: 6,
            child: Text(
              '거래내역조회',
              key: Key('account-details-title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _detailsInk,
                fontSize: 24,
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
              icon: const _AccountHomeIcon(key: Key('account-home-glyph')),
            ),
          ),
          Positioned(
            right: 23,
            top: 6,
            child: Semantics(
              label: '메뉴 검색',
              image: true,
              child: const _AccountMenuSearchIcon(),
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
      right: 35,
      top: 202,
      height: 66,
      child: Row(
        children: [
          ClipRRect(
            key: const Key('account-details-logo'),
            borderRadius: BorderRadius.circular(16),
            child: SizedBox.square(
              dimension: 58,
              child: account == null || account!.bankCode == '농협'
                  ? const _AccountNhMark()
                  : BankLogo(bankCode: account!.bankCode, size: 58),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  key: const Key('account-type-text'),
                  accountType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _detailsInk,
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  key: const Key('account-number-text'),
                  '$bank  $number',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _detailsMuted,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.55,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 29,
            color: _detailsInk,
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
        const Positioned(
          left: 35,
          top: 309,
          child: Text(
            '잔액',
            style: TextStyle(
              color: _detailsSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.6,
            ),
          ),
        ),
        Positioned(
          right: 36,
          top: 305,
          child: Text(
            key: const Key('account-balance-text'),
            '${_formatDetailsMoney(balance)}원',
            style: const TextStyle(
              color: _detailsInk,
              fontSize: 28,
              fontWeight: FontWeight.w700,
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
          fontWeight: FontWeight.w600,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: ColoredBox(
        color: const Color(0xFFF5F5F5),
        child: Stack(
          children: [
            const Positioned(
              left: 62,
              top: 33,
              child: Text(
                '뚜레쥬르',
                style: TextStyle(
                  color: Color(0xFF3A3B3C),
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                ),
              ),
            ),
            const Positioned(
              left: 50,
              top: 68,
              child: Text(
                '사전예약 최대',
                style: TextStyle(
                  color: Color(0xFF686B6C),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.6,
                ),
              ),
            ),
            Positioned(
              left: 187,
              top: 10,
              width: 161,
              height: 107,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/transaction_tlj_cakes.jpg',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            const Positioned(
              right: 42,
              top: 33,
              child: Text(
                '추석 선물',
                style: TextStyle(
                  color: Color(0xFF3A3B3C),
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                ),
              ),
            ),
            const Positioned(
              right: 43,
              top: 67,
              child: Text(
                '30%OFF',
                style: TextStyle(
                  color: Color(0xFFF0442D),
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            Positioned(
              right: 9,
              top: 8,
              child: Container(
                width: 23,
                height: 23,
                decoration: const BoxDecoration(
                  color: Color(0xFFB9BABA),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'i',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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

class _AccountNhMark extends StatelessWidget {
  const _AccountNhMark();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF0875BE),
      child: Center(
        child: Text(
          'NH',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _AccountHomeIcon extends StatelessWidget {
  const _AccountHomeIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 30,
      child: CustomPaint(painter: _AccountHomePainter()),
    );
  }
}

class _AccountHomePainter extends CustomPainter {
  const _AccountHomePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _detailsInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final home = Path()
      ..moveTo(3, 12)
      ..lineTo(15, 2.5)
      ..lineTo(26.5, 12)
      ..moveTo(5, 10.5)
      ..lineTo(5, 26.5)
      ..lineTo(12, 26.5)
      ..lineTo(12, 17.5)
      ..lineTo(18, 17.5)
      ..lineTo(18, 26.5)
      ..lineTo(24.5, 26.5)
      ..lineTo(24.5, 10.5);

    canvas.drawPath(home, paint);
  }

  @override
  bool shouldRepaint(_AccountHomePainter oldDelegate) => false;
}

class _AccountMenuSearchIcon extends StatelessWidget {
  const _AccountMenuSearchIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 37,
      child: CustomPaint(painter: _AccountMenuSearchPainter()),
    );
  }
}

class _AccountMenuSearchPainter extends CustomPainter {
  const _AccountMenuSearchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = _detailsInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    for (final y in <double>[7, 15, 23]) {
      canvas.drawLine(Offset(2, y), Offset(28, y), stroke);
    }
    canvas.drawCircle(const Offset(27.5, 26), 6, stroke);
    canvas.drawLine(const Offset(32, 30.5), const Offset(35.5, 34), stroke);
  }

  @override
  bool shouldRepaint(_AccountMenuSearchPainter oldDelegate) => false;
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
          top: 670,
          filterKey: const Key('account-history-filter'),
          label: filterLabel,
          onTap: onFilterTap,
        ),
        Positioned(
          left: 35,
          top: 758,
          child: Text(
            key: const Key('account-history-range'),
            rangeLabel,
            style: const TextStyle(
              color: _detailsSecondary,
              fontSize: 19.5,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.55,
            ),
          ),
        ),
        Positioned(
          right: 35,
          top: 754,
          child: _BalanceVisibilityToggle(
            isVisible: showTransactionBalances,
            onTap: onBalanceVisibilityTap,
          ),
        ),
        const Positioned(
          left: 35,
          right: 35,
          top: 845,
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
          dateTime: _formatDetailsDateTime(transaction.occurredAt),
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
                fontWeight: FontWeight.w600,
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

  static const firstRowTop = 872.0;
  static const rowExtent = 176.0;
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
                padding: const EdgeInsets.fromLTRB(20, 18, 42, 18),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF444849),
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
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
  late _HistoryFilter _filter = widget.initialFilter;
  late final TextEditingController _minimumController;
  late final TextEditingController _maximumController;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
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
      _validationMessage = null;
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
      _validationMessage = null;
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

  void _submit() {
    final minimum = int.tryParse(_minimumController.text);
    final maximum = int.tryParse(_maximumController.text);
    if (_filter.periodMode == _HistoryPeriodMode.range &&
        _filter.startDate.isAfter(_filter.endDate)) {
      setState(() => _validationMessage = '시작일은 종료일보다 늦을 수 없어요.');
      return;
    }
    if (minimum != null && maximum != null && minimum > maximum) {
      setState(() => _validationMessage = '최소금액은 최대금액보다 클 수 없어요.');
      return;
    }
    Navigator.of(context).pop(
      _filter.copyWith(
        minimumAmount: minimum,
        maximumAmount: maximum,
        clearMinimumAmount: minimum == null,
        clearMaximumAmount: maximum == null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 1000;
    final horizontalPadding = compact ? 20.0 : 28.0;
    final modeHeight = compact ? 50.0 : 72.0;
    final presetHeight = compact ? 46.0 : 68.0;
    final fieldHeight = compact ? 48.0 : 64.0;
    final monthFieldHeight = compact ? 52.0 : 70.0;
    final typeHeight = compact ? 60.0 : 92.0;
    final optionHeight = compact ? 48.0 : 68.0;
    final amountHeight = compact ? 52.0 : 68.0;
    final sectionGap = compact ? 18.0 : 30.0;
    final choiceGap = compact ? 8.0 : 14.0;
    return FractionallySizedBox(
      heightFactor: compact ? .95 : .92,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  compact ? 14 : 24,
                  compact ? 12 : 20,
                  compact ? 4 : 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '조회 조건 설정',
                        style: TextStyle(
                          color: _detailsInk,
                          fontSize: compact ? 24 : 27,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('history-filter-close'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, size: compact ? 28 : 32),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    compact ? 4 : 8,
                    horizontalPadding,
                    compact ? 12 : 22,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _FilterSectionTitle('조회기간'),
                      SizedBox(height: choiceGap),
                      Row(
                        children: [
                          Expanded(
                            child: _FilterChoiceButton(
                              key: const Key('history-period-monthly'),
                              label: '월별',
                              selected:
                                  _filter.periodMode ==
                                  _HistoryPeriodMode.monthly,
                              height: modeHeight,
                              onTap: () => setState(
                                () => _filter = _filter.copyWith(
                                  periodMode: _HistoryPeriodMode.monthly,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: compact ? 8 : 12),
                          Expanded(
                            child: _FilterChoiceButton(
                              key: const Key('history-period-range'),
                              label: '기간별',
                              selected:
                                  _filter.periodMode ==
                                  _HistoryPeriodMode.range,
                              height: modeHeight,
                              onTap: () => setState(
                                () => _filter = _filter.copyWith(
                                  periodMode: _HistoryPeriodMode.range,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: compact ? 8 : 12),
                      if (_filter.periodMode == _HistoryPeriodMode.range) ...[
                        Row(
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
                                  selected: _filter.rangePreset == entry.$1,
                                  height: presetHeight,
                                  onTap: () => _setRangePreset(entry.$1),
                                ),
                              ),
                              if (entry.$1 != _HistoryRangePreset.sixMonths)
                                SizedBox(width: compact ? 6 : 10),
                            ],
                          ],
                        ),
                        SizedBox(height: compact ? 10 : 16),
                        Row(
                          children: [
                            Expanded(
                              child: _DateFilterField(
                                key: const Key('history-start-date'),
                                date: _filter.startDate,
                                height: fieldHeight,
                                compact: compact,
                                onTap: () => _pickRangeDate(start: true),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 9),
                              child: Text(
                                '-',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: _DateFilterField(
                                key: const Key('history-end-date'),
                                date: _filter.endDate,
                                height: fieldHeight,
                                compact: compact,
                                onTap: () => _pickRangeDate(start: false),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        InkWell(
                          key: const Key('history-month-field'),
                          onTap: _pickMonth,
                          child: Container(
                            height: monthFieldHeight,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Color(0xFFD4D8DF)),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_filter.month.year}년 '
                                    '${_filter.month.month.toString().padLeft(2, '0')}월',
                                    style: TextStyle(
                                      color: _detailsInk,
                                      fontSize: compact ? 19 : 24,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -.7,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 31,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: compact ? 18 : 34),
                      const _FilterSectionTitle('유형'),
                      SizedBox(height: choiceGap),
                      Row(
                        children: [
                          for (final entry in const [
                            (_HistoryType.all, '전체'),
                            (_HistoryType.deposit, '입금'),
                            (_HistoryType.withdrawal, '출금'),
                            (_HistoryType.shinhanAtm, '신한\nATM'),
                          ]) ...[
                            Expanded(
                              child: _FilterChoiceButton(
                                key: Key('history-type-${entry.$1.name}'),
                                label: entry.$2,
                                selected: _filter.type == entry.$1,
                                height: typeHeight,
                                onTap: () => setState(
                                  () => _filter = _filter.copyWith(
                                    type: entry.$1,
                                  ),
                                ),
                              ),
                            ),
                            if (entry.$1 != _HistoryType.shinhanAtm)
                              SizedBox(width: compact ? 6 : 10),
                          ],
                        ],
                      ),
                      SizedBox(height: sectionGap),
                      const _FilterSectionTitle('정렬'),
                      SizedBox(height: choiceGap),
                      Row(
                        children: [
                          Expanded(
                            child: _FilterChoiceButton(
                              key: const Key('history-sort-newest'),
                              label: '최신순',
                              selected: _filter.sort == _HistorySort.newest,
                              height: optionHeight,
                              onTap: () => setState(
                                () => _filter = _filter.copyWith(
                                  sort: _HistorySort.newest,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: compact ? 8 : 12),
                          Expanded(
                            child: _FilterChoiceButton(
                              key: const Key('history-sort-oldest'),
                              label: '과거순',
                              selected: _filter.sort == _HistorySort.oldest,
                              height: optionHeight,
                              onTap: () => setState(
                                () => _filter = _filter.copyWith(
                                  sort: _HistorySort.oldest,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: sectionGap),
                      const _FilterSectionTitle('금액범위'),
                      SizedBox(height: choiceGap),
                      Row(
                        children: [
                          Expanded(
                            child: _AmountFilterField(
                              key: const Key('history-minimum-amount'),
                              controller: _minimumController,
                              hint: '최소금액',
                              height: amountHeight,
                              compact: compact,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 9),
                            child: Text(
                              '-',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: _AmountFilterField(
                              key: const Key('history-maximum-amount'),
                              controller: _maximumController,
                              hint: '최대금액',
                              height: amountHeight,
                              compact: compact,
                            ),
                          ),
                        ],
                      ),
                      if (_validationMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _validationMessage!,
                          style: const TextStyle(
                            color: Color(0xFFE23A3A),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  compact ? 8 : 12,
                  horizontalPadding,
                  compact ? 12 : 18,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: compact ? 56 : 70,
                  child: FilledButton(
                    key: const Key('history-filter-apply'),
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _detailsBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(
                      '조회',
                      style: TextStyle(
                        fontSize: compact ? 20 : 24,
                        fontWeight: FontWeight.w700,
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

class _FilterSectionTitle extends StatelessWidget {
  const _FilterSectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 1000;
    return Text(
      label,
      style: TextStyle(
        color: _detailsSecondary,
        fontSize: compact ? 16 : 19,
        fontWeight: FontWeight.w600,
        letterSpacing: -.5,
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
  });

  final String label;
  final bool selected;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 1000;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _detailsBlue : const Color(0xFFD4D8DF),
            width: selected ? 1.8 : 1.1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? _detailsBlue : _detailsInk,
              fontSize: compact ? 17 : 20,
              height: 1.25,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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
    required this.height,
    required this.compact,
    required this.onTap,
  });

  final DateTime date;
  final double height;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFD4D8DF))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${date.year}.${date.month.toString().padLeft(2, '0')}.'
                '${date.day.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: _detailsSecondary,
                  fontSize: compact ? 15.5 : 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.calendar_month_outlined,
              color: _detailsInk,
              size: compact ? 24 : 28,
            ),
          ],
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
    required this.compact,
  });

  final TextEditingController controller;
  final String hint;
  final double height;
  final bool compact;

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
          fontSize: compact ? 15.5 : 18,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF9DA5B3)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD4D8DF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _detailsBlue, width: 1.8),
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

  int _lastMonthForYear(int year) {
    return year == widget.latestSelectableMonth.year
        ? widget.latestSelectableMonth.month
        : 12;
  }

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
    final compact = MediaQuery.sizeOf(context).height < 1000;
    final horizontalPadding = compact ? 20.0 : 28.0;
    final wheelItemExtent = compact ? 52.0 : 58.0;
    return SizedBox(
      height: compact ? 440 : 505,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  compact ? 14 : 22,
                  compact ? 12 : 20,
                  compact ? 4 : 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '조회 월 선택',
                        style: TextStyle(
                          color: _detailsInk,
                          fontSize: compact ? 24 : 27,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('history-month-picker-close'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, size: compact ? 28 : 32),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: wheelItemExtent,
                      color: const Color(0xFFF2F5FB),
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
                                          ? _detailsInk
                                          : const Color(0xFFBBC1CB),
                                      fontSize: compact ? 22 : 25,
                                      fontWeight: value == _year
                                          ? FontWeight.w500
                                          : FontWeight.w400,
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
                                          ? _detailsInk
                                          : const Color(0xFFBBC1CB),
                                      fontSize: compact ? 22 : 25,
                                      fontWeight: value == _month
                                          ? FontWeight.w500
                                          : FontWeight.w400,
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
                  compact ? 8 : 14,
                  horizontalPadding,
                  compact ? 12 : 18,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: compact ? 56 : 70,
                  child: FilledButton(
                    key: const Key('history-month-picker-apply'),
                    onPressed: () =>
                        Navigator.of(context).pop(DateTime(_year, _month)),
                    style: FilledButton.styleFrom(
                      backgroundColor: _detailsBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(
                      '조회',
                      style: TextStyle(
                        fontSize: compact ? 20 : 24,
                        fontWeight: FontWeight.w700,
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
            top: 34,
            width: 320,
            height: 36,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _detailsInk,
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.8,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 6,
            child: Text(
              positive ? '입금' : '출금',
              style: TextStyle(
                color: positive
                    ? const Color(0xFF1976D2)
                    : const Color(0xFFEF4D4F),
                fontSize: 19,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.6,
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 3,
            child: Text(
              key: Key('account-transaction-time-$transactionId'),
              dateTime,
              style: const TextStyle(
                color: _detailsSecondary,
                fontSize: 19.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 35,
            child: Text(
              amount,
              style: TextStyle(
                color: positive
                    ? const Color(0xFF1976D2)
                    : const Color(0xFFEF4D4F),
                fontSize: 26,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.8,
              ),
            ),
          ),
          if (showBalance)
            Positioned(
              right: 0,
              top: 75,
              child: Text(
                key: Key('account-transaction-balance-$transactionId'),
                '잔액 $balance',
                style: const TextStyle(
                  color: _detailsMuted,
                  fontSize: 18.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 30,
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
