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
const _detailsDivider = Color(0xFFF1F4F8);
const _detailsAccountNumber = Color(0xFF505866);
const _detailsAccountLogoSize = 52.0;
const _detailsAccountTypeWidth = 427.0;
const _detailsAccountTypeStyle = TextStyle(
  color: Color(0xFF2D323C),
  fontFamily: 'NotoSansKR',
  fontSize: 22,
  fontWeight: FontWeight.w600,
  letterSpacing: -1,
);

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
      rangePreset: _HistoryRangePreset.threeMonths,
      startDate: _subtractMonths(today, 3),
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

  Future<void> _scrollToTop() {
    return _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
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
    final accountLabel = widget.auth.isSignedIn
        ? widget.auth.displayName
        : 'TÀI KHOẢN';
    final account = _selectedAccount;
    final accountType = _displayAccountType(account?.accountType);
    final accountSummaryOffset = _accountTypeWrapOffset(accountType);
    final allTransactions = account == null
        ? const <LedgerTransaction>[]
        : widget.dataStore.transactionsFor(account.id);
    final transactions = _historyFilter.apply(allTransactions);
    final requiredContentHeight =
        _TransactionLayoutMetrics.contentBottom(
          transactions,
          verticalOffset: accountSummaryOffset,
        ) +
        _TransactionLayoutMetrics.bottomPadding;
    final contentHeight = requiredContentHeight > 1780
        ? requiredContentHeight
        : 1780.0;
    final collapsed = _scrollOffset >= 340;

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
                      account: account,
                      accountType: accountType,
                      balance: account == null
                          ? 0
                          : widget.dataStore.balanceFor(account.id),
                      verticalOffset: accountSummaryOffset,
                      onTransfer: _openTransferRecipient,
                    ),
                    _TransactionList(
                      accountName: accountLabel,
                      account: account,
                      transactions: transactions,
                      store: widget.dataStore,
                      verticalOffset: accountSummaryOffset,
                      filterLabel: _historyFilter.summaryLabel,
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
            height: collapsed ? 199 : 185,
            child: const ColoredBox(color: Colors.white),
          ),
          if (collapsed) ...[
            const Positioned(
              left: 0,
              right: 0,
              top: 184,
              height: 15,
              child: ColoredBox(color: _detailsDivider),
            ),
            const Positioned(
              left: 0,
              right: 0,
              top: 199,
              height: 82,
              child: ColoredBox(color: Colors.white),
            ),
            _FilterBar(
              top: 214,
              filterKey: const Key('account-history-filter-collapsed'),
              label: _historyFilter.summaryLabel,
              onTap: _openHistoryFilter,
            ),
          ],
          _DetailsHeader(
            onBack: _goHome,
            onHome: _goHome,
            onManage: _openManagement,
          ),
          if (collapsed)
            Positioned(
              right: 29,
              bottom: 48,
              width: 68,
              height: 68,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: IconButton(
                  key: const Key('account-scroll-top'),
                  onPressed: _scrollToTop,
                  icon: const Icon(
                    Icons.arrow_upward_rounded,
                    size: 31,
                    color: _detailsInk,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailsHeader extends StatelessWidget {
  const _DetailsHeader({
    required this.onBack,
    required this.onHome,
    required this.onManage,
  });

  final VoidCallback onBack;
  final VoidCallback onHome;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 104,
      height: 66,
      child: Stack(
        children: [
          Positioned(
            left: 27,
            top: 2,
            width: 50,
            height: 50,
            child: IconButton(
              key: const Key('account-back'),
              onPressed: onBack,
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 28,
                color: _detailsInk,
              ),
            ),
          ),
          Positioned(
            right: 78,
            top: 2,
            width: 94,
            height: 50,
            child: TextButton(
              key: const Key('account-manage'),
              onPressed: onManage,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '계좌관리',
                style: TextStyle(
                  color: _detailsBlue,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.8,
                ),
              ),
            ),
          ),
          Positioned(
            right: 19,
            top: 5,
            width: 50,
            height: 50,
            child: IconButton(
              key: const Key('account-home'),
              onPressed: onHome,
              padding: EdgeInsets.zero,
              icon: const _AccountHomeIcon(key: Key('account-home-glyph')),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountSummary extends StatelessWidget {
  const _AccountSummary({
    required this.account,
    required this.accountType,
    required this.balance,
    required this.verticalOffset,
    required this.onTransfer,
  });

  final BankAccount? account;
  final String accountType;
  final int balance;
  final double verticalOffset;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 28,
          top: 201,
          width: 83,
          height: 33,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF344052),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(
              child: Text(
                '한도계좌',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 28,
          top: 245,
          width: _detailsAccountLogoSize,
          height: _detailsAccountLogoSize,
          child: account == null
              ? const Icon(Icons.account_balance_rounded)
              : BankLogo(
                  key: const Key('account-details-logo'),
                  bankCode: account!.bankCode,
                  size: _detailsAccountLogoSize,
                ),
        ),
        Positioned(
          left: 90,
          top: 243,
          width: _detailsAccountTypeWidth,
          child: Text(
            key: const Key('account-type-text'),
            accountType,
            softWrap: true,
            style: _detailsAccountTypeStyle,
          ),
        ),
        Positioned(
          left: 90,
          right: 72,
          top: 285 + verticalOffset,
          child: Row(
            children: [
              Flexible(
                child: Text(
                  key: const Key('account-number-text'),
                  account == null
                      ? '-'
                      : '${account!.bankDisplayName} ${account!.accountNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _detailsAccountNumber,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    fontVariations: [FontVariation('wght', 500)],
                    letterSpacing: -.5,
                  ),
                ),
              ),
              if (account != null) ...[
                const SizedBox(width: 5),
                GestureDetector(
                  key: const Key('account-copy'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Clipboard.setData(
                    ClipboardData(text: account!.accountNumber),
                  ),
                  child: const _AccountCopyIcon(key: Key('account-copy-glyph')),
                ),
              ],
            ],
          ),
        ),
        const Positioned(
          right: 30,
          top: 245,
          child: _AccountScanIcon(key: Key('account-scan-icon')),
        ),
        Positioned(
          left: 28,
          top: 330 + verticalOffset,
          child: Text(
            key: const Key('account-balance-text'),
            '${_formatDetailsMoney(balance)}원',
            style: const TextStyle(
              color: _detailsInk,
              fontSize: 34,
              fontWeight: FontWeight.w600,
              letterSpacing: -1.5,
            ),
          ),
        ),
        Positioned(
          left: 28,
          top: 381 + verticalOffset,
          child: Text(
            key: const Key('account-available-balance-text'),
            '출금가능금액 ${_formatDetailsMoney(balance)}원',
            style: const TextStyle(
              color: _detailsSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
              fontVariations: [FontVariation('wght', 500)],
              letterSpacing: -.5,
            ),
          ),
        ),
        Positioned(
          left: 28,
          top: 432 + verticalOffset,
          width: 533,
          height: 68,
          child: GestureDetector(
            key: const Key('account-transfer'),
            behavior: HitTestBehavior.opaque,
            onTap: onTransfer,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text(
                  '이체',
                  style: TextStyle(
                    color: _detailsBlue,
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 534 + verticalOffset,
          height: 15,
          child: const ColoredBox(color: _detailsDivider),
        ),
      ],
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

class _AccountScanIcon extends StatelessWidget {
  const _AccountScanIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 30,
      child: CustomPaint(painter: _AccountScanPainter()),
    );
  }
}

class _AccountCopyIcon extends StatelessWidget {
  const _AccountCopyIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 15,
      child: CustomPaint(painter: _AccountCopyPainter()),
    );
  }
}

class _AccountCopyPainter extends CustomPainter {
  const _AccountCopyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _detailsAccountNumber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;

    // The source-app glyph is not two complete overlapping rectangles. The
    // rear sheet is visible only as its upper and right edges, while the front
    // sheet is a closed square. Keeping those paths separate preserves the
    // crisp negative space visible in the original mockup at this small size.
    final rearSheet = Path()
      ..moveTo(4.65, 1.45)
      ..lineTo(13.45, 1.45)
      ..lineTo(13.45, 10.25);
    canvas.drawPath(rearSheet, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(1.55, 4.55, 8.9, 8.9),
        const Radius.circular(.35),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_AccountCopyPainter oldDelegate) => false;
}

class _AccountScanPainter extends CustomPainter {
  const _AccountScanPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _detailsInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;

    final corners = Path()
      ..moveTo(4.5, 10.5)
      ..lineTo(4.5, 4)
      ..lineTo(11, 4)
      ..moveTo(19, 4)
      ..lineTo(25.5, 4)
      ..lineTo(25.5, 10.5)
      ..moveTo(25.5, 19.5)
      ..lineTo(25.5, 27)
      ..lineTo(19, 27)
      ..moveTo(11, 27)
      ..lineTo(4.5, 27)
      ..lineTo(4.5, 19.5);
    canvas.drawPath(corners, paint);

    final plusPaint = Paint()
      ..color = _detailsInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(const Offset(11, 15), const Offset(19, 15), plusPaint)
      ..drawLine(const Offset(15, 11), const Offset(15, 19), plusPaint);
  }

  @override
  bool shouldRepaint(_AccountScanPainter oldDelegate) => false;
}

class _TransactionList extends StatelessWidget {
  const _TransactionList({
    required this.accountName,
    required this.account,
    required this.transactions,
    required this.store,
    required this.verticalOffset,
    required this.filterLabel,
    required this.onFilterTap,
    required this.showTransactionBalances,
    required this.onBalanceVisibilityTap,
  });

  final String accountName;
  final BankAccount? account;
  final List<LedgerTransaction> transactions;
  final AppDataStore store;
  final double verticalOffset;
  final String filterLabel;
  final VoidCallback onFilterTap;
  final bool showTransactionBalances;
  final VoidCallback onBalanceVisibilityTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _FilterBar(
          top: 558 + verticalOffset,
          filterKey: const Key('account-history-filter'),
          label: filterLabel,
          onTap: onFilterTap,
        ),
        Positioned(
          right: 28,
          top: 615 + verticalOffset,
          child: _BalanceVisibilityToggle(
            isVisible: showTransactionBalances,
            onTap: onBalanceVisibilityTap,
          ),
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
          top: 680 + verticalOffset,
          child: const Text(
            '거래내역이 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _detailsMuted, fontSize: 18),
          ),
        ),
      ];
    }
    final widgets = <Widget>[];
    var cursor = _TransactionLayoutMetrics.firstRowTop + verticalOffset;
    String? previousDate;
    for (final transaction in transactions) {
      final dateKey = _TransactionLayoutMetrics.dateKey(transaction);
      if (dateKey != previousDate) {
        if (previousDate != null) {
          widgets.add(
            Positioned(
              left: 28,
              right: 28,
              top: cursor + 4,
              child: const Divider(height: 1, color: Color(0xFFE8EBF0)),
            ),
          );
          cursor += _TransactionLayoutMetrics.dayDividerExtent;
        }
        widgets.add(
          Positioned(
            left: 28,
            top: cursor,
            child: Text(
              key: Key('account-transaction-date-$dateKey'),
              '${transaction.occurredAt.month}월 '
              '${transaction.occurredAt.day}일',
              style: const TextStyle(
                color: _detailsSecondary,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                fontVariations: [FontVariation('wght', 500)],
                letterSpacing: -.6,
              ),
            ),
          ),
        );
        cursor += _TransactionLayoutMetrics.dateHeaderExtent;
        previousDate = dateKey;
      }
      final signed = transaction.signedAmount;
      widgets.add(
        _TransactionRow(
          top: cursor,
          title: transaction.title,
          transactionId: transaction.id,
          time:
              '${_formatDetailsTime(transaction.occurredAt)} · '
              '${transaction.channel}',
          amount:
              '${signed >= 0 ? '+' : '-'}'
              '${_formatDetailsMoney(signed.abs())}원',
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
        child: AnimatedContainer(
          key: const Key('account-balance-visibility-track'),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: 72,
          height: 36,
          decoration: BoxDecoration(
            color: isVisible ? _detailsBlue : const Color(0xFF8E98A8),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                alignment: isVisible
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: isVisible ? 11 : 0,
                    right: isVisible ? 0 : 10,
                  ),
                  child: const Text(
                    '잔액',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.5,
                    ),
                  ),
                ),
              ),
              AnimatedAlign(
                key: const Key('account-balance-visibility-knob'),
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                alignment: isVisible
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
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

class _TransactionLayoutMetrics {
  const _TransactionLayoutMetrics._();

  static const firstRowTop = 652.0;
  static const dateHeaderExtent = 52.0;
  static const dayDividerExtent = 46.0;
  static const rowExtent = 110.0;
  static const bottomPadding = 150.0;

  static String dateKey(LedgerTransaction transaction) =>
      '${transaction.occurredAt.year}-${transaction.occurredAt.month}-'
      '${transaction.occurredAt.day}';

  static double contentBottom(
    List<LedgerTransaction> transactions, {
    required double verticalOffset,
  }) {
    var cursor = firstRowTop + verticalOffset;
    String? previousDate;
    for (final transaction in transactions) {
      final currentDate = dateKey(transaction);
      if (currentDate != previousDate) {
        if (previousDate != null) cursor += dayDividerExtent;
        cursor += dateHeaderExtent;
        previousDate = currentDate;
      }
      cursor += rowExtent;
    }
    return cursor;
  }
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
      left: 28,
      right: 28,
      top: top,
      height: 62,
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            top: 10,
            child: Icon(Icons.search_rounded, size: 35, color: _detailsInk),
          ),
          Positioned(
            right: 0,
            top: 3,
            child: GestureDetector(
              key: filterKey,
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 0, 11),
                child: Row(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF303641),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.7,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: _detailsInk,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
    required this.time,
    required this.amount,
    required this.balance,
    required this.showBalance,
    this.positive = false,
  });

  final double top;
  final String title;
  final String transactionId;
  final String time;
  final String amount;
  final String balance;
  final bool showBalance;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 28,
      right: 28,
      top: top,
      height: 100,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 6,
            width: 330,
            height: 34,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF27303D),
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -.8,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 4,
            child: Text(
              amount,
              style: TextStyle(
                color: positive ? _detailsBlue : _detailsInk,
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -.8,
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 49,
            child: Text(
              key: Key('account-transaction-time-$transactionId'),
              time,
              style: const TextStyle(
                color: _detailsSecondary,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                fontVariations: [FontVariation('wght', 500)],
                letterSpacing: -.5,
              ),
            ),
          ),
          if (showBalance)
            Positioned(
              right: 0,
              top: 49,
              child: Text(
                key: Key('account-transaction-balance-$transactionId'),
                balance,
                style: const TextStyle(
                  color: _detailsSecondary,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  fontVariations: [FontVariation('wght', 500)],
                  letterSpacing: -.5,
                ),
              ),
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

double _accountTypeWrapOffset(String accountType) {
  final wrappedPainter = TextPainter(
    text: TextSpan(text: accountType, style: _detailsAccountTypeStyle),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  )..layout(maxWidth: _detailsAccountTypeWidth);
  final singleLinePainter = TextPainter(
    text: const TextSpan(text: '가', style: _detailsAccountTypeStyle),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  )..layout(maxWidth: _detailsAccountTypeWidth);
  final extraHeight = wrappedPainter.height - singleLinePainter.height;
  return extraHeight > 0 ? extraHeight : 0;
}

String _displayAccountType(String? value) {
  if (value == null || value.isEmpty) return '등록된 계좌가 없습니다';
  if (value.startsWith('금융거래한도계좌2]')) return '[$value';
  return value;
}

String _formatDetailsTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
}
