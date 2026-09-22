import 'package:flutter/material.dart';

import '../core/app_data.dart';
import 'design_canvas.dart';

const _ink = Colors.black;
const _muted = Colors.black;
const _lightMuted = Colors.black;
const _divider = Color(0xFFF3F3F3);

class LimitReleaseScreen extends StatefulWidget {
  const LimitReleaseScreen({
    super.key,
    this.account,
    this.balance = 0,
    this.initialScrollOffset = 0,
  });

  final BankAccount? account;
  final int balance;

  /// Offset in the fixed 588 px-wide reference coordinate system.
  final double initialScrollOffset;

  @override
  State<LimitReleaseScreen> createState() => _LimitReleaseScreenState();
}

class _LimitReleaseScreenState extends State<LimitReleaseScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    showDeviceStatusBar(darkIcons: true, backgroundColor: Colors.white);
    _scrollController = ScrollController(
      initialScrollOffset: widget.initialScrollOffset,
      keepScrollOffset: false,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    showDeviceStatusBar(
      darkIcons: true,
      backgroundColor: const Color(0xFFEEF2F3),
    );
    super.dispose();
  }

  void _close() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return DesignCanvas(
      backgroundColor: Colors.white,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Colors.white)),
          Positioned.fill(
            child: SingleChildScrollView(
              key: const Key('limit-release-scroll'),
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 181),
                  _AccountSelection(
                    account: widget.account,
                    balance: widget.balance,
                  ),
                  const SizedBox(height: 47),
                  const SizedBox(
                    height: 12,
                    child: ColoredBox(color: _divider),
                  ),
                  const _InformationSection(),
                  const SizedBox(height: 72),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 170,
            child: ColoredBox(color: Colors.white),
          ),
          _LimitReleaseHeader(onBack: _close, onHome: _close),
        ],
      ),
    );
  }
}

class _LimitReleaseHeader extends StatelessWidget {
  const _LimitReleaseHeader({required this.onBack, required this.onHome});

  final VoidCallback onBack;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 91,
      height: 58,
      child: Stack(
        children: [
          Positioned(
            left: 26,
            top: 0,
            width: 50,
            height: 50,
            child: IconButton(
              key: const Key('limit-release-back'),
              tooltip: '뒤로',
              onPressed: onBack,
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back_rounded, size: 32, color: _ink),
            ),
          ),
          const Positioned(
            left: 99,
            right: 99,
            top: 7,
            child: Text(
              key: Key('limit-release-title'),
              '한도제한 해제(NH농협은행)',
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.9,
              ),
            ),
          ),
          Positioned(
            right: 76,
            top: 0,
            width: 50,
            height: 50,
            child: IconButton(
              key: const Key('limit-release-home'),
              tooltip: '홈',
              onPressed: onHome,
              padding: EdgeInsets.zero,
              icon: const _HeaderHomeIcon(),
            ),
          ),
          Positioned(
            right: 23,
            top: 6,
            child: Semantics(
              label: '메뉴 검색',
              image: true,
              child: const _HeaderMenuSearchIcon(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountSelection extends StatelessWidget {
  const _AccountSelection({required this.account, required this.balance});

  final BankAccount? account;
  final int balance;

  @override
  Widget build(BuildContext context) {
    final type = account?.accountType ?? 'NH올원모임통장';
    final bank = account?.bankDisplayName ?? 'NH농협은행';
    final number = account?.accountNumber ?? '302-2180-4371-91';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '계좌 선택',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.7,
                ),
              ),
              Text(
                '해제 신청내역',
                style: TextStyle(
                  color: _muted,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.7,
                  decoration: TextDecoration.underline,
                  decorationThickness: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            key: const Key('limit-release-account-card'),
            height: 236,
            padding: const EdgeInsets.fromLTRB(31, 30, 29, 27),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFDADCDC), width: 1.2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF979B9C)),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text(
                      '한도제한계좌',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 40,
                  top: 53,
                  child: Text(
                    type,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.9,
                    ),
                  ),
                ),
                const Positioned(
                  right: 5,
                  top: 50,
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 22,
                    color: _ink,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 91,
                  child: Text(
                    '$bank $number',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 3),
                        child: Text(
                          '잔액',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${_formatMoney(balance)}원',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InformationSection extends StatelessWidget {
  const _InformationSection();

  static const _items = <String>[
    '농협은행 영업점 또는 비대면(인터넷·앱)에서 개설한 한도제한계좌(입출식통장)의 거래한도를 영업점 방문없이 해제신청하는 서비스입니다. (당일 1회 신청 가능)',
    '위 서비스는 사기이용계좌 피해가 없도록 금융거래목적을 확인한 고객에 한해 해제하고 있습니다.',
    '거래중지계좌는 비대면(인터넷·앱)에서 한도제한해제를 신청할 수 없습니다. 한도제한을 해제하려면 영업점에서 상담 후 신청해 주시기 바랍니다. 이용 중인 계좌가 아니라면 계좌를 해지해 주세요.',
    '한도제한 해제 신청 후 NH농협은행 한도제한 해제 조건에 충족되지 않을 경우 해제가 되지 않을 수 있습니다. (한도제한 해제 상세조건은 금융소비자보호를 위해 공개하지 않습니다.)',
    '한도제한 해제 신청 후 해제가 되지 않는 경우에는 영업점 또는 고객행복센터에 문의해 주시기 바랍니다.',
    '영업점에서 한도제한 해제 신청을 하는 경우에는 금융거래목적 확인을 위한 증빙서류를 요구할 수 있으며, 한도제한 해제가 되지 않을 수 있습니다.',
    '금융거래목적에 따른 영업점 제출서류(예시)\n급여계좌(재직증명서, 근로소득원천징수영수증 등), 자동이체(공과금/관리비 지로(납부) 용지, 보험증권 등), 기타(금융거래목적을 확인할 수 있는 증빙서류)',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 37, 31, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 31, color: _ink),
              SizedBox(width: 12),
              Text(
                '알아두세요',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                ),
              ),
              Spacer(),
              Icon(Icons.keyboard_arrow_up_rounded, size: 27, color: _ink),
            ],
          ),
          const SizedBox(height: 35),
          for (var index = 0; index < _items.length; index++) ...[
            _InformationBullet(
              key: ValueKey('limit-release-info-$index'),
              text: _items[index],
            ),
            if (index != _items.length - 1) const SizedBox(height: 19),
          ],
        ],
      ),
    );
  }
}

class _InformationBullet extends StatelessWidget {
  const _InformationBullet({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          width: 15,
          child: Text(
            '•',
            style: TextStyle(color: _lightMuted, fontSize: 18, height: 1.65),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: _muted,
              fontSize: 18.5,
              fontWeight: FontWeight.w600,
              height: 1.65,
              letterSpacing: -0.65,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderHomeIcon extends StatelessWidget {
  const _HeaderHomeIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 31,
      child: CustomPaint(painter: _HeaderHomePainter()),
    );
  }
}

class _HeaderHomePainter extends CustomPainter {
  const _HeaderHomePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final home = Path()
      ..moveTo(3, 12)
      ..lineTo(15.5, 2.5)
      ..lineTo(28, 12)
      ..moveTo(5.5, 10.5)
      ..lineTo(5.5, 28)
      ..lineTo(25.5, 28)
      ..lineTo(25.5, 10.5)
      ..moveTo(11.5, 28)
      ..lineTo(11.5, 19.5)
      ..lineTo(19.5, 19.5)
      ..lineTo(19.5, 28);
    canvas.drawPath(home, stroke);
  }

  @override
  bool shouldRepaint(_HeaderHomePainter oldDelegate) => false;
}

class _HeaderMenuSearchIcon extends StatelessWidget {
  const _HeaderMenuSearchIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 37,
      child: CustomPaint(painter: _HeaderMenuSearchPainter()),
    );
  }
}

class _HeaderMenuSearchPainter extends CustomPainter {
  const _HeaderMenuSearchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = _ink
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
  bool shouldRepaint(_HeaderMenuSearchPainter oldDelegate) => false;
}

String _formatMoney(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    final remaining = digits.length - index;
    buffer.write(digits[index]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return amount < 0 ? '-$buffer' : buffer.toString();
}
