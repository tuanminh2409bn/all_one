import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_data.dart';
import 'bank_logo.dart';
import 'tlj_artwork_paths.dart';

const _designWidth = 588.0;
const _normalHomeTextScale = 1.0;
const _largeHomeTextMultiplier = 1.13;
const _homeBackground = Color(0xFFEEF2F3);
const _ink = Colors.black;
const _green = Color(0xFF159757);
const _cardRadius = 24.0;

class NativeHomeView extends StatelessWidget {
  const NativeHomeView({
    super.key,
    required this.scrollController,
    required this.benefitsKey,
    required this.assetsKey,
    required this.accountName,
    required this.account,
    required this.balanceLabel,
    required this.netAssetsLabel,
    required this.spendingLabel,
    required this.scheduledLabel,
    required this.hideAmounts,
    required this.largeText,
    required this.nhSelected,
    required this.onAccountTap,
    required this.onToggleLargeText,
    required this.onMenuTap,
    required this.onSelectNh,
    required this.onSelectOther,
    required this.onLimitRelease,
    required this.onOpenDetails,
    required this.onTransfer,
    required this.onCopyAccount,
    required this.onToggleHide,
    required this.onAccounts,
    required this.onAllAccounts,
    required this.onScrollToAssets,
  });

  final ScrollController scrollController;
  final GlobalKey benefitsKey;
  final GlobalKey assetsKey;
  final String accountName;
  final BankAccount? account;
  final String balanceLabel;
  final String netAssetsLabel;
  final String spendingLabel;
  final String scheduledLabel;
  final bool hideAmounts;
  final bool largeText;
  final bool nhSelected;
  final VoidCallback onAccountTap;
  final VoidCallback onToggleLargeText;
  final VoidCallback onMenuTap;
  final VoidCallback onSelectNh;
  final VoidCallback onSelectOther;
  final VoidCallback onLimitRelease;
  final VoidCallback onOpenDetails;
  final VoidCallback onTransfer;
  final VoidCallback? onCopyAccount;
  final VoidCallback onToggleHide;
  final VoidCallback onAccounts;
  final VoidCallback onAllAccounts;
  final VoidCallback onScrollToAssets;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final scale = mediaQuery.size.width / _designWidth;
    final textScale =
        _normalHomeTextScale * (largeText ? _largeHomeTextMultiplier : 1.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.white,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarDividerColor: Colors.white,
      ),
      child: MediaQuery(
        data: mediaQuery.copyWith(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(top: 54 * scale),
              child: ColoredBox(
                color: _homeBackground,
                child: _HomeScale(
                  scale: scale,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 130 * scale,
                        height: 760 * scale,
                        child: AnimatedBuilder(
                          animation: scrollController,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment(0.12, 0.04),
                                radius: 0.92,
                                colors: [
                                  Color(0xB8D8EEE8),
                                  Color(0x70E0EDF0),
                                  Color(0x00EEF2F3),
                                ],
                                stops: [0, 0.6, 1],
                              ),
                            ),
                          ),
                          builder: (context, child) {
                            final offset = scrollController.hasClients
                                ? scrollController.offset
                                : 0.0;
                            return Transform.translate(
                              offset: Offset(0, -offset),
                              child: child,
                            );
                          },
                        ),
                      ),
                      Positioned.fill(
                        child: SingleChildScrollView(
                          key: const Key('home-scroll'),
                          controller: scrollController,
                          physics: const ClampingScrollPhysics(),
                          padding: EdgeInsets.only(bottom: 36 * scale),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(height: 147 * scale),
                              const _EventBanner(),
                              SizedBox(height: 43 * scale),
                              _FinanceTabs(
                                nhSelected: nhSelected,
                                onSelectNh: onSelectNh,
                                onSelectOther: onSelectOther,
                              ),
                              SizedBox(height: 18 * scale),
                              _AccountCard(
                                account: account,
                                balanceLabel: balanceLabel,
                                hideAmounts: hideAmounts,
                                onLimitRelease: onLimitRelease,
                                onOpenDetails: onOpenDetails,
                                onTransfer: onTransfer,
                                onCopy: onCopyAccount,
                                onToggleHide: onToggleHide,
                              ),
                              SizedBox(height: 44 * scale),
                              const _TljBanner(),
                              SizedBox(height: 61 * scale),
                              KeyedSubtree(
                                key: benefitsKey,
                                child: const _SectionTitle('오늘의 혜택'),
                              ),
                              SizedBox(height: 26 * scale),
                              const _DailyPointCard(),
                              SizedBox(height: 51 * scale),
                              _ShortcutGrid(
                                onAccounts: onAccounts,
                                onAllAccounts: onAllAccounts,
                              ),
                              SizedBox(height: 58 * scale),
                              const _SectionTitle('내 모임'),
                              SizedBox(height: 16 * scale),
                              const _MoimBanner(),
                              SizedBox(height: 20 * scale),
                              _SpendingSection(
                                spendingLabel: spendingLabel,
                                scheduledLabel: scheduledLabel,
                                onToggleHide: onToggleHide,
                              ),
                              SizedBox(height: 61 * scale),
                              KeyedSubtree(
                                key: assetsKey,
                                child: _AssetsSection(
                                  netLabel: netAssetsLabel,
                                  onToggleHide: onToggleHide,
                                  onAccounts: onAccounts,
                                ),
                              ),
                              SizedBox(height: 60 * scale),
                              const _LifestyleRow(),
                              SizedBox(height: 63 * scale),
                              const _SectionTitle('NH금융그룹'),
                              SizedBox(height: 16 * scale),
                              const _GroupGrid(),
                              SizedBox(height: 77 * scale),
                              const _HomeSettingsLink(),
                              SizedBox(height: 72 * scale),
                            ],
                          ),
                        ),
                      ),
                      _HeaderBar(
                        accountName: accountName,
                        largeText: largeText,
                        onAccountTap: onAccountTap,
                        onToggleLargeText: onToggleLargeText,
                        onMenuTap: onMenuTap,
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 22 * scale,
                        child: AnimatedBuilder(
                          animation: scrollController,
                          builder: (context, child) {
                            final offset = scrollController.hasClients
                                ? scrollController.offset
                                : 0.0;
                            if (offset >= 280 * scale) {
                              return const SizedBox.shrink();
                            }
                            return Center(child: child);
                          },
                          child: _AssetsFab(onTap: onScrollToAssets),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: _HomeScale(
            scale: scale,
            child: const _BottomNavigation(),
          ),
        ),
      ),
    );
  }
}

class _HomeScale extends InheritedWidget {
  const _HomeScale({required this.scale, required super.child});

  final double scale;

  static double of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_HomeScale>()!.scale;
  }

  @override
  bool updateShouldNotify(_HomeScale oldWidget) => scale != oldWidget.scale;
}

TextStyle _style(
  BuildContext context,
  double size, {
  FontWeight weight = FontWeight.w500,
  Color color = _ink,
  double? height,
  double letterSpacing = -0.35,
}) {
  final scale = _HomeScale.of(context);
  final variableWeight = weight == FontWeight.w500
      ? 500.0
      : weight == FontWeight.w600
      ? 600.0
      : null;
  return TextStyle(
    fontSize: size * scale,
    fontWeight: variableWeight == null ? weight : FontWeight.w500,
    fontVariations: variableWeight == null
        ? null
        : [FontVariation('wght', variableWeight)],
    color: _highContrastHomeTextColor(color),
    height: height,
    letterSpacing: letterSpacing * scale,
  );
}

Color _highContrastHomeTextColor(Color color) {
  if (color == Colors.white) return color;
  return HSLColor.fromColor(color).saturation < .25 ? Colors.black : color;
}

bool _usesLargeHomeText(BuildContext context) {
  return MediaQuery.textScalerOf(context).scale(1) >
      _normalHomeTextScale + 0.01;
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.accountName,
    required this.largeText,
    required this.onAccountTap,
    required this.onToggleLargeText,
    required this.onMenuTap,
  });

  final String accountName;
  final bool largeText;
  final VoidCallback onAccountTap;
  final VoidCallback onToggleLargeText;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    final scale = _HomeScale.of(context);
    final signedIn = accountName != '로그인';
    return Positioned(
      key: const Key('home-native-header'),
      left: 0,
      right: 0,
      top: 0,
      height: 147 * scale,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 111 * scale,
            child: const ColoredBox(color: Colors.white),
          ),
          Positioned(
            left: 29 * scale,
            top: 56 * scale,
            width: 260 * scale,
            child: GestureDetector(
              key: const Key('home-account-name'),
              behavior: HitTestBehavior.opaque,
              onTap: onAccountTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      signedIn ? '$accountName ...' : accountName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          _style(
                            context,
                            25,
                            weight: FontWeight.w700,
                            height: 1.1,
                            letterSpacing: -0.8,
                          ).copyWith(
                            decoration: signedIn
                                ? TextDecoration.underline
                                : TextDecoration.none,
                            decorationThickness: 1.2,
                          ),
                    ),
                  ),
                  if (signedIn) ...[
                    SizedBox(width: 13 * scale),
                    Text(
                      '님',
                      style: _style(
                        context,
                        25,
                        weight: FontWeight.w500,
                        height: 1.1,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: 29 * scale,
            top: 98 * scale,
            child: const _FortuneChip(),
          ),
          Positioned(
            left: 318 * scale,
            top: 55 * scale,
            child: GestureDetector(
              key: const Key('home-native-large-text'),
              onTap: onToggleLargeText,
              child: Container(
                width: 82 * scale,
                height: 38 * scale,
                padding: EdgeInsets.all(3 * scale),
                decoration: BoxDecoration(
                  color: largeText
                      ? const Color(0xFFDCF2E6)
                      : const Color(0xFFE9EAEA),
                  borderRadius: BorderRadius.circular(19 * scale),
                ),
                child: Row(
                  children: [
                    Align(
                      alignment: largeText
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 32 * scale,
                        height: 32 * scale,
                        decoration: BoxDecoration(
                          color: largeText ? _green : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(color: Color(0x22000000), blurRadius: 3),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '큰글',
                        textAlign: TextAlign.center,
                        style: _style(
                          context,
                          14,
                          weight: FontWeight.w500,
                          color: const Color(0xFF666A6B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 8 * scale,
            top: 31 * scale,
            width: 180 * scale,
            height: 70 * scale,
            child: Image.asset(
              'assets/images/ref_header_actions.png',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
            ),
          ),
          Positioned(
            right: 24 * scale,
            top: 55 * scale,
            child: GestureDetector(
              key: const Key('home-menu-search'),
              behavior: HitTestBehavior.opaque,
              onTap: onMenuTap,
              child: SizedBox(width: 37 * scale, height: 37 * scale),
            ),
          ),
        ],
      ),
    );
  }
}

class _FortuneChip extends StatelessWidget {
  const _FortuneChip();

  @override
  Widget build(BuildContext context) {
    final scale = _HomeScale.of(context);
    return SizedBox(
      key: const Key('home-fortune-chip'),
      width: 124 * scale,
      height: 55 * scale,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 25 * scale,
            top: 0,
            width: 16 * scale,
            height: 10 * scale,
            child: CustomPaint(painter: _FortunePointerPainter()),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 8 * scale,
            height: 47 * scale,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                borderRadius: BorderRadius.circular(11 * scale),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '오늘 운세',
                      style: _style(
                        context,
                        16,
                        weight: FontWeight.w500,
                        color: Colors.white,
                        height: 1,
                        letterSpacing: -0.15,
                      ),
                    ),
                    SizedBox(width: 3 * scale),
                    SizedBox.square(
                      dimension: 16 * scale,
                      child: const CustomPaint(painter: _CloverPainter()),
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

class _FortunePointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.5, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF161616)
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_FortunePointerPainter oldDelegate) => false;
}

class _CloverPainter extends CustomPainter {
  const _CloverPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / 16;
    final leaf = Paint()..color = const Color(0xFF22A447);
    final stem = Paint()
      ..color = const Color(0xFF16863A)
      ..strokeWidth = 1.4 * unit
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.scale(unit, unit);
    for (final center in const [
      Offset(5.2, 5.2),
      Offset(10.8, 5.2),
      Offset(5.2, 10.2),
      Offset(10.8, 10.2),
    ]) {
      canvas.drawCircle(center, 3.15, leaf);
    }
    canvas.drawLine(const Offset(9, 10.5), const Offset(12.8, 15), stem);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CloverPainter oldDelegate) => false;
}

class _GrinningFacePainter extends CustomPainter {
  const _GrinningFacePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / 23;
    final face = Paint()..color = const Color(0xFFFFC83D);
    final ink = Paint()
      ..color = const Color(0xFF4D3100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.45 * unit
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(size.center(Offset.zero), size.shortestSide / 2, face);
    canvas.drawArc(
      Rect.fromLTWH(4.3 * unit, 5.7 * unit, 5.2 * unit, 4.4 * unit),
      .18,
      2.45,
      false,
      ink,
    );
    canvas.drawArc(
      Rect.fromLTWH(13.5 * unit, 5.7 * unit, 5.2 * unit, 4.4 * unit),
      .5,
      2.45,
      false,
      ink,
    );
    final mouth = RRect.fromRectAndRadius(
      Rect.fromLTWH(4.3 * unit, 11.2 * unit, 14.4 * unit, 7.2 * unit),
      Radius.circular(3.2 * unit),
    );
    canvas.drawRRect(mouth, Paint()..color = const Color(0xFF6A360B));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(5.2 * unit, 11.7 * unit, 12.6 * unit, 4.1 * unit),
        Radius.circular(1.4 * unit),
      ),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _GrinningFacePainter oldDelegate) => false;
}

class _EventBanner extends StatelessWidget {
  const _EventBanner();

  @override
  Widget build(BuildContext context) {
    final scale = _HomeScale.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 28 * scale),
      child: Container(
        height: 136 * scale,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD9EAFE), Color(0xFFCFE4FF)],
          ),
          borderRadius: BorderRadius.circular(_cardRadius * scale),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 30 * scale,
              top: 31 * scale,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '요즘 핫한 이벤트 뭐있지?',
                    style: _style(
                      context,
                      20,
                      weight: FontWeight.w500,
                      color: const Color(0xFF485762),
                      height: 1,
                    ),
                  ),
                  SizedBox(width: 6 * scale),
                  SizedBox.square(
                    dimension: 23 * scale,
                    child: const CustomPaint(painter: _GrinningFacePainter()),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 30 * scale,
              top: 69 * scale,
              child: Text(
                '보기만 해도 쌓이는 포인트',
                style: _style(
                  context,
                  25,
                  weight: FontWeight.w700,
                  letterSpacing: -0.8,
                ),
              ),
            ),
            Positioned(
              right: 10 * scale,
              top: 4 * scale,
              width: 145 * scale,
              height: 132 * scale,
              child: const Image(
                image: AssetImage('assets/images/home_event_gift.png'),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceTabs extends StatelessWidget {
  const _FinanceTabs({
    required this.nhSelected,
    required this.onSelectNh,
    required this.onSelectOther,
  });

  final bool nhSelected;
  final VoidCallback onSelectNh;
  final VoidCallback onSelectOther;

  @override
  Widget build(BuildContext context) {
    final scale = _HomeScale.of(context);
    return SizedBox(
      height: 34 * scale,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 29 * scale),
        child: Row(
          children: [
            GestureDetector(
              onTap: onSelectNh,
              child: Row(
                children: [
                  Text(
                    'NH농협',
                    style: _style(
                      context,
                      24,
                      weight: FontWeight.w700,
                      color: nhSelected ? _ink : const Color(0xFF9A9A9A),
                      letterSpacing: -0.8,
                    ),
                  ),
                  SizedBox(width: 4 * scale),
                  Transform.translate(
                    offset: Offset(0, -10 * scale),
                    child: Container(
                      width: 7 * scale,
                      height: 7 * scale,
                      decoration: BoxDecoration(
                        color: nhSelected ? _green : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 20 * scale),
            GestureDetector(
              onTap: onSelectOther,
              child: Text(
                '다른금융',
                style: _style(
                  context,
                  24,
                  weight: nhSelected ? FontWeight.w500 : FontWeight.w700,
                  color: nhSelected ? const Color(0xFF696F71) : _ink,
                  letterSpacing: -0.7,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.balanceLabel,
    required this.hideAmounts,
    required this.onLimitRelease,
    required this.onOpenDetails,
    required this.onTransfer,
    required this.onToggleHide,
    this.onCopy,
  });

  final BankAccount? account;
  final String balanceLabel;
  final bool hideAmounts;
  final VoidCallback onLimitRelease;
  final VoidCallback onOpenDetails;
  final VoidCallback onTransfer;
  final VoidCallback onToggleHide;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final scale = _HomeScale.of(context);
    final largeText = _usesLargeHomeText(context);
    final type = account?.accountType ?? 'NH올원모임통장';
    final bank = account?.bankDisplayName ?? 'NH농협은행';
    final number = account?.accountNumber ?? '302-2180-4371-91';
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 28 * scale),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_cardRadius * scale),
          boxShadow: [
            BoxShadow(
              color: const Color(0x14607173),
              blurRadius: 22 * scale,
              offset: Offset(0, 6 * scale),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          elevation: 0,
          borderRadius: BorderRadius.circular(_cardRadius * scale),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            key: const Key('home-account-card'),
            height: (largeText ? 342 : 326) * scale,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                28 * scale,
                35 * scale,
                26 * scale,
                31 * scale,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 54 * scale,
                        height: 59 * scale,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 3 * scale,
                              top: 11 * scale,
                              width: 48 * scale,
                              height: 48 * scale,
                              child: ClipRRect(
                                key: const Key('home-account-logo'),
                                borderRadius: BorderRadius.circular(14 * scale),
                                child:
                                    account == null || account!.bankCode == '농협'
                                    ? const _NhMark()
                                    : BankLogo(
                                        bankCode: account!.bankCode,
                                        size: 48 * scale,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 5 * scale),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type,
                              style: _style(
                                context,
                                21,
                                weight: FontWeight.w600,
                                letterSpacing: -0.7,
                              ),
                            ),
                            SizedBox(height: 5 * scale),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '$bank $number',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _style(
                                      context,
                                      20,
                                      weight: FontWeight.w500,
                                      color: const Color(0xFF62696B),
                                      letterSpacing: -0.45,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 6 * scale),
                                GestureDetector(
                                  onTap: onCopy,
                                  child: Text(
                                    '복사',
                                    style:
                                        _style(
                                          context,
                                          18,
                                          weight: FontWeight.w500,
                                          color: const Color(0xFF555B5D),
                                        ).copyWith(
                                          decoration: TextDecoration.underline,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.more_vert_rounded,
                        size: 29 * scale,
                        color: const Color(0xFF555555),
                      ),
                    ],
                  ),
                  SizedBox(height: 12 * scale),
                  Padding(
                    padding: EdgeInsets.only(left: 58 * scale),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10 * scale,
                        vertical: 5 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEEF0),
                        borderRadius: BorderRadius.circular(8 * scale),
                      ),
                      child: Text(
                        '한도제한',
                        style: _style(
                          context,
                          14,
                          weight: FontWeight.w500,
                          color: const Color(0xFFE56577),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10 * scale),
                  Padding(
                    padding: EdgeInsets.only(left: 58 * scale),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        key: const Key('home-balance-and-visibility'),
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(width: 2 * scale),
                          Text(
                            balanceLabel,
                            key: const Key('home-account-balance'),
                            style: _style(
                              context,
                              29,
                              weight: FontWeight.w700,
                              letterSpacing: -0.9,
                            ),
                          ),
                          SizedBox(width: 10 * scale),
                          GestureDetector(
                            onTap: onToggleHide,
                            child: Container(
                              key: const Key('home-balance-visibility'),
                              width: 62 * scale,
                              height: 38 * scale,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                  color: const Color(0xFFD7D9DA),
                                  width: 1 * scale,
                                ),
                                borderRadius: BorderRadius.circular(18 * scale),
                              ),
                              child: Text(
                                hideAmounts ? '보기' : '숨김',
                                style: _style(
                                  context,
                                  15,
                                  weight: FontWeight.w600,
                                  color: _ink,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    key: const Key('home-account-actions'),
                    children: [
                      Expanded(
                        child: _AccountAction(
                          label: '한도해제',
                          onTap: onLimitRelease,
                        ),
                      ),
                      SizedBox(width: 12 * scale),
                      Expanded(
                        child: _AccountAction(
                          label: '거래내역',
                          onTap: onOpenDetails,
                        ),
                      ),
                      SizedBox(width: 12 * scale),
                      Expanded(
                        child: _AccountAction(label: '이체', onTap: onTransfer),
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
}

class _AccountAction extends StatelessWidget {
  const _AccountAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = _HomeScale.of(context);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: Size.fromHeight(61 * scale),
        padding: EdgeInsets.zero,
        side: BorderSide(color: const Color(0xFFD6D9D9), width: 1.3 * scale),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13 * scale),
        ),
        foregroundColor: _ink,
      ),
      child: Transform.scale(
        scaleX: 1.14,
        scaleY: 1.12,
        child: Text(label, style: _style(context, 18, weight: FontWeight.w500)),
      ),
    );
  }
}

class _NhMark extends StatelessWidget {
  const _NhMark();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color(0xFF0875BE),
        borderRadius: BorderRadius.circular(14 * _HomeScale.of(context)),
      ),
      child: Center(
        child: Text(
          'NH',
          style: _style(
            context,
            16,
            weight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _TljBanner extends StatelessWidget {
  const _TljBanner();

  @override
  Widget build(BuildContext context) {
    final scale = _HomeScale.of(context);
    return SizedBox(
      height: 128 * scale,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 28 * scale,
            right: 28 * scale,
            top: 0,
            bottom: 0,
            child: const ColoredBox(color: Color(0xFFEDEFEF)),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _TljArtworkPainter(scale)),
          ),
          Positioned(
            left: 72 * scale,
            top: 42 * scale,
            child: Transform.scale(
              scaleX: 1.18,
              scaleY: 1.05,
              alignment: Alignment.topLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '뚜레쥬르',
                    style: _style(context, 19, weight: FontWeight.w500),
                  ),
                  SizedBox(height: 4 * scale),
                  Text(
                    '지금 바로',
                    style: _style(
                      context,
                      17,
                      weight: FontWeight.w500,
                      color: const Color(0xFF747A7B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 410 * scale,
            top: 43 * scale,
            child: Transform.scale(
              scaleX: 1.25,
              scaleY: 1.05,
              alignment: Alignment.topLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '고객 누구나',
                    style: _style(context, 18, weight: FontWeight.w500),
                  ),
                  SizedBox(height: 5 * scale),
                  Text(
                    '40%OFF',
                    style: _style(
                      context,
                      17,
                      weight: FontWeight.w700,
                      color: const Color(0xFFF04435),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 13 * scale,
            top: 8 * scale,
            child: Container(
              width: 21 * scale,
              height: 21 * scale,
              decoration: const BoxDecoration(
                color: Color(0xFFB7B9B9),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                'i',
                style: _style(
                  context,
                  13,
                  weight: FontWeight.w500,
                  color: Colors.white,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TljArtworkPainter extends CustomPainter {
  const _TljArtworkPainter(this.scale);

  final double scale;

  static const _face = Color(0xFFE6493A);
  static const _extrude = Color(0xFF9E1208);

  Path _loops(List<List<double>> loops) {
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final loop in loops) {
      if (loop.length < 6) {
        continue;
      }
      path.moveTo(loop[0] * scale, loop[1] * scale);
      for (var i = 2; i + 1 < loop.length; i += 2) {
        path.lineTo(loop[i] * scale, loop[i + 1] * scale);
      }
      path.close();
    }
    return path;
  }

  void _fillSmoothed(Canvas canvas, Path path, Color color) {
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 0.7 * scale
        ..isAntiAlias = true,
    );
  }

  void _paintOutlinedText(
    Canvas canvas,
    String text,
    Offset offset,
    double fontSize,
  ) {
    final base = TextStyle(
      fontFamily: 'NotoSansKRMedium',
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      height: 1,
      letterSpacing: -0.4 * scale,
    );
    final stroke = TextPainter(
      text: TextSpan(
        text: text,
        style: base.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.8 * scale
            ..strokeJoin = StrokeJoin.round
            ..color = Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final fill = TextPainter(
      text: TextSpan(
        text: text,
        style: base.copyWith(color: _face),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    stroke.paint(canvas, offset);
    fill.paint(canvas, offset);
  }

  void _paintBurst(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = const Color(0xFFFF5A05)
      ..strokeWidth = 1.7 * scale
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      canvas.drawLine(
        center,
        center + Offset(math.cos(angle), math.sin(angle)) * radius,
        paint,
      );
    }
  }

  void _paintSparkle(Canvas canvas, Offset center, double radius) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx + radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx - radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - radius)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF2B8B4E)
        ..isAntiAlias = true,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final swirl = Path()
      ..moveTo(331 * scale, 12 * scale)
      ..cubicTo(
        342 * scale,
        7 * scale,
        344 * scale,
        22 * scale,
        332 * scale,
        26 * scale,
      )
      ..cubicTo(
        324 * scale,
        28 * scale,
        326 * scale,
        16 * scale,
        336 * scale,
        15 * scale,
      );
    canvas.drawPath(
      swirl,
      Paint()
        ..color = const Color(0xFFB7D6EE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.9 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );

    _paintBurst(canvas, Offset(201.5 * scale, 91.5 * scale), 5.4 * scale);
    _paintSparkle(canvas, Offset(184 * scale, 111 * scale), 4.6 * scale);
    canvas.drawLine(
      Offset(274 * scale, 120.5 * scale),
      Offset(285 * scale, 125.5 * scale),
      Paint()
        ..color = const Color(0xFFF25C12)
        ..strokeWidth = 2.6 * scale
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );
    canvas.drawCircle(
      Offset(336.5 * scale, 93.5 * scale),
      1.5 * scale,
      Paint()..color = const Color(0xFF8EC4E8),
    );

    final digits = _loops(tljArtworkPaths['digitsFace']!);
    final terminal = Path()
      ..addRRect(
        RRect.fromLTRBR(
          198.5 * scale,
          82.5 * scale,
          214 * scale,
          97.5 * scale,
          Radius.circular(8 * scale),
        ),
      );
    canvas.save();
    canvas.translate(3.6 * scale, 3.1 * scale);
    _fillSmoothed(canvas, digits, _extrude);
    _fillSmoothed(canvas, terminal, _extrude);
    canvas.restore();
    _fillSmoothed(canvas, digits, _face);
    _fillSmoothed(canvas, terminal, _face);

    _paintOutlinedText(
      canvas,
      '최대',
      Offset(326.5 * scale, 37.5 * scale),
      19.5 * scale,
    );

    canvas.save();
    canvas.translate(-5.4 * scale, -1.6 * scale);
    _paintPercent(canvas, Colors.white, stroke: true);
    canvas.save();
    canvas.translate(2.4 * scale, 2.1 * scale);
    _paintPercent(canvas, _extrude);
    canvas.restore();
    _paintPercent(canvas, _face);
    canvas.restore();
  }

  void _paintPercent(Canvas canvas, Color color, {bool stroke = false}) {
    final rings = Path()..fillType = PathFillType.evenOdd;
    void ring(Offset center) {
      rings.addOval(Rect.fromCircle(center: center, radius: 8.4 * scale));
      rings.addOval(Rect.fromCircle(center: center, radius: 3.7 * scale));
    }

    ring(Offset(351.2 * scale, 75.8 * scale));
    ring(Offset(374.4 * scale, 92.2 * scale));
    final slash = RRect.fromLTRBR(
      -3.1 * scale,
      -20 * scale,
      3.1 * scale,
      20 * scale,
      Radius.circular(3.1 * scale),
    );
    final paint = stroke
        ? (Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 3.4 * scale
            ..isAntiAlias = true)
        : (Paint()
            ..color = color
            ..isAntiAlias = true);
    if (stroke) {
      canvas.drawPath(rings, paint);
    } else {
      _fillSmoothed(canvas, rings, color);
    }
    canvas.save();
    canvas.translate(362.8 * scale, 84.2 * scale);
    canvas.rotate(0.86);
    canvas.drawRRect(slash, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TljArtworkPainter oldDelegate) {
    return oldDelegate.scale != scale;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final scale = _HomeScale.of(context);
    return SizedBox(
      height: 35 * scale,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 29 * scale),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Transform.scale(
            scaleX: 1.0,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: _style(
                    context,
                    28,
                    weight: FontWeight.w700,
                    letterSpacing: -0.85,
                  ),
                ),
                if (label == '오늘의 혜택' || label == '내 모임') ...[
                  SizedBox(width: 5 * scale),
                  Icon(Icons.chevron_right_rounded, size: 28 * scale),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyPointCard extends StatelessWidget {
  const _DailyPointCard();

  @override
  Widget build(BuildContext context) {
    final scale = _HomeScale.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 28 * scale),
      child: Container(
        height: 95 * scale,
        padding: EdgeInsets.symmetric(horizontal: 28 * scale),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_cardRadius * scale),
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 58 * scale,
              child: const Image(
                key: Key('home-daily-point-hand'),
                image: AssetImage('assets/images/ref_daily_point.png'),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
            SizedBox(width: 18 * scale),
            Text(
              '매일 포인트 용돈 받기',
              style: _style(
                context,
                21,
                weight: FontWeight.w700,
                letterSpacing: -0.65,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutGrid extends StatelessWidget {
  const _ShortcutGrid({required this.onAccounts, required this.onAllAccounts});

  final VoidCallback onAccounts;
  final VoidCallback onAllAccounts;

  @override
  Widget build(BuildContext context) {
    final scale = _HomeScale.of(context);
    const items = <(String, String, int)>[
      ('계좌등록', 'assets/images/ref_shortcut_0.png', 1),
      ('전체계좌', 'assets/images/ref_shortcut_1.png', 2),
      ('공과금납부', 'assets/images/ref_shortcut_2.png', 0),
      ('이체한도변경', 'assets/images/ref_shortcut_3.png', 0),
      ('올원사장님+', 'assets/images/ref_shortcut_4.png', 0),
      ('올원룰렛', 'assets/images/ref_shortcut_5.png', 0),
      ('캐시백쿠폰몰', 'assets/images/ref_shortcut_6.png', 0),
      ('메뉴설정', 'assets/images/ref_shortcut_7.png', 0),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 28 * scale),
      child: Container(
        height: 257 * scale,
        padding: EdgeInsets.fromLTRB(
          17 * scale,
          26 * scale,
          17 * scale,
          15 * scale,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_cardRadius * scale),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisExtent: 108 * scale,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return GestureDetector(
              onTap: item.$3 == 1
                  ? onAccounts
                  : item.$3 == 2
                  ? onAllAccounts
                  : null,
              behavior: HitTestBehavior.opaque,
              child: Column(
                children: [
                  SizedBox.square(
                    dimension: 58 * scale,
                    child: Image(
                      image: AssetImage(item.$2),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  SizedBox(height: 9 * scale),
                  Text(
                    item.$1,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: _style(
                      context,
                      15,
                      weight: FontWeight.w500,
                      color: const Color(0xFF484E50),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MoimBanner extends StatelessWidget {
  const _MoimBanner();

  @override
  Widget build(BuildContext context) {
    final scale = _HomeScale.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 28 * scale),
      child: Container(
        height: 160 * scale,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFE8E6FB),
          borderRadius: BorderRadius.circular(_cardRadius * scale),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 30 * scale,
              top: 28 * scale,
              child: Text(
                '모임을 더 쉽고 편리하게',
                style: _style(
                  context,
                  17,
                  weight: FontWeight.w500,
                  color: const Color(0xFF66626D),
                ),
              ),
            ),
            Positioned(
              left: 30 * scale,
              top: 61 * scale,
              child: Text(
                '투명한 회비관리, 함께해요',
                style: _style(context, 22, weight: FontWeight.w600),
              ),
            ),
            Positioned(
              left: 30 * scale,
              top: 111 * scale,
              child: Text(
                'NH올원모임으로 시작하기',
                style: _style(context, 19, weight: FontWeight.w500),
              ),
            ),
            Positioned(
              right: 28 * scale,
              top: 28 * scale,
              width: 135 * scale,
              height: 105 * scale,
              child: const Image(
                image: AssetImage('assets/images/ref_moim_people_alpha.png'),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpendingSection extends StatelessWidget {
  const _SpendingSection({
    required this.spendingLabel,
    required this.scheduledLabel,
    required this.onToggleHide,
  });

  final String spendingLabel;
  final String scheduledLabel;
  final VoidCallback onToggleHide;

  @override
  Widget build(BuildContext context) {
    final scale = _HomeScale.of(context);
    return Column(
      children: [
        _DataSectionHeading(title: '내 소비', onToggleHide: onToggleHide),
        SizedBox(height: 18 * scale),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 28 * scale),
          child: Container(
            height: 286 * scale,
            padding: EdgeInsets.symmetric(horizontal: 30 * scale),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_cardRadius * scale),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 13,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: _MoneyRow(
                    iconAsset: 'assets/images/ref_spending_0.png',
                    label: '9월 지출',
                    value: spendingLabel,
                  ),
                ),
                Divider(height: 1, thickness: 1 * scale),
                Expanded(
                  child: _MoneyRow(
                    iconAsset: 'assets/images/ref_spending_1.png',
                    label: '카드결제 예정금액',
                    value: scheduledLabel,
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

class _DataSectionHeading extends StatelessWidget {
  const _DataSectionHeading({required this.title, required this.onToggleHide});

  final String title;
  final VoidCallback onToggleHide;

  @override
  Widget build(BuildContext context) {
    final scale = _HomeScale.of(context);
    return SizedBox(
      height: 48 * scale,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 29 * scale),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              key: ValueKey('home-data-title-$title'),
              style: _style(context, 25, weight: FontWeight.w700),
            ),
            const Spacer(),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '2026. 09. 09 기준',
                  key: ValueKey('home-data-date-$title'),
                  style: _style(
                    context,
                    16,
                    weight: FontWeight.w500,
                    color: const Color(0xFF747A7C),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
            SizedBox(width: 16 * scale),
            GestureDetector(
              onTap: onToggleHide,
              child: Container(
                key: ValueKey('home-data-hide-$title'),
                height: 38 * scale,
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF7D8385)),
                  borderRadius: BorderRadius.circular(14 * scale),
                ),
                child: Text(
                  '금액숨김',
                  style: _style(
                    context,
                    14,
                    weight: FontWeight.w500,
                    color: const Color(0xFF555B5D),
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

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.iconAsset,
    required this.label,
    required this.value,
  });

  final String iconAsset;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scale = _HomeScale.of(context);
    return Row(
      children: [
        SizedBox.square(
          dimension: 42 * scale,
          child: Image(
            image: AssetImage(iconAsset),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        SizedBox(width: 18 * scale),
        Text(label, style: _style(context, 21, weight: FontWeight.w500)),
        const Spacer(),
        Text(value, style: _style(context, 25, weight: FontWeight.w700)),
      ],
    );
  }
}

class _AssetsSection extends StatelessWidget {
  const _AssetsSection({
    required this.netLabel,
    required this.onToggleHide,
    required this.onAccounts,
  });

  final String netLabel;
  final VoidCallback onToggleHide;
  final VoidCallback onAccounts;

  @override
  Widget build(BuildContext context) {
    final scale = _HomeScale.of(context);
    return Column(
      children: [
        _DataSectionHeading(title: '내 자산', onToggleHide: onToggleHide),
        SizedBox(height: 14 * scale),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 28 * scale),
          child: Container(
            height: 464 * scale,
            padding: EdgeInsets.fromLTRB(
              30 * scale,
              26 * scale,
              30 * scale,
              20 * scale,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_cardRadius * scale),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 13,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 102 * scale,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 10 * scale),
                        child: Text(
                          '순자산',
                          style: _style(context, 23, weight: FontWeight.w700),
                        ),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Text(
                                netLabel,
                                style: _style(
                                  context,
                                  31,
                                  weight: FontWeight.w700,
                                  letterSpacing: -0.9,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 28 * scale,
                                color: const Color(0xFF6F7475),
                              ),
                            ],
                          ),
                          SizedBox(height: 7 * scale),
                          Text(
                            '지난번보다 0원 늘었어요',
                            style: _style(
                              context,
                              15,
                              weight: FontWeight.w500,
                              color: const Color(0xFF29A46B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 1 * scale),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _AssetRow(
                        iconAsset: 'assets/images/ref_asset_0.png',
                        label: '계좌',
                        value: netLabel,
                        onTap: onAccounts,
                      ),
                      const _AssetRow(
                        iconAsset: 'assets/images/ref_asset_1.png',
                        label: '대출',
                        value: '0원',
                      ),
                      const _AssetRow(
                        iconAsset: 'assets/images/ref_asset_2.png',
                        label: '투자',
                        value: '0원',
                      ),
                      const _AssetRow(
                        iconAsset: 'assets/images/ref_asset_3.png',
                        label: '부동산',
                        value: '내 부동산 관리하기',
                        mutedValue: true,
                      ),
                    ],
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

class _AssetRow extends StatelessWidget {
  const _AssetRow({
    required this.iconAsset,
    required this.label,
    required this.value,
    this.mutedValue = false,
    this.onTap,
  });

  final String iconAsset;
  final String label;
  final String value;
  final bool mutedValue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scale = _HomeScale.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          SizedBox.square(
            dimension: 40 * scale,
            child: Image(
              image: AssetImage(iconAsset),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          SizedBox(width: 17 * scale),
          Text(label, style: _style(context, 20, weight: FontWeight.w500)),
          const Spacer(),
          Text(
            value,
            style: _style(
              context,
              mutedValue ? 20 : 19,
              weight: mutedValue ? FontWeight.w500 : FontWeight.w500,
              color: mutedValue ? const Color(0xFF656B6D) : _ink,
            ),
          ),
          SizedBox(width: 3 * scale),
          Icon(
            Icons.chevron_right_rounded,
            size: 23 * scale,
            color: const Color(0xFF737879),
          ),
        ],
      ),
    );
  }
}

class _LifestyleRow extends StatelessWidget {
  const _LifestyleRow();

  @override
  Widget build(BuildContext context) {
    final scale = _HomeScale.of(context);
    return SizedBox(
      height: 336 * scale,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 28 * scale),
        children: [
          const _LifestyleCard(
            title: '모빌리티',
            caption: '내 자동차 지금\n시세는 얼마?',
            color: Color(0xFF6385F2),
            image: 'assets/images/ref_lifestyle_0.png',
          ),
          SizedBox(width: 14 * scale),
          const _LifestyleCard(
            title: '보험',
            caption: '내 가입보험\n한눈에 확인하려면?',
            color: Color(0xFF5595EE),
            image: 'assets/images/ref_lifestyle_1.png',
          ),
          SizedBox(width: 14 * scale),
          const _LifestyleCard(
            title: '혜택',
            caption: '생활 속 알찬 혜택을\n지금 확인하세요',
            color: Color(0xFF1AA98C),
            image: 'assets/images/home_daily_point.png',
          ),
        ],
      ),
    );
  }
}

class _LifestyleCard extends StatelessWidget {
  const _LifestyleCard({
    required this.title,
    required this.caption,
    required this.color,
    required this.image,
  });

  final String title;
  final String caption;
  final Color color;
  final String image;

  @override
  Widget build(BuildContext context) {
    final scale = _HomeScale.of(context);
    return Container(
      width: 250 * scale,
      padding: EdgeInsets.fromLTRB(
        20 * scale,
        28 * scale,
        20 * scale,
        33 * scale,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(_cardRadius * scale),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: _style(
                  context,
                  18,
                  weight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                size: 24 * scale,
                color: Colors.white,
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: Container(
              width: 105 * scale,
              height: 105 * scale,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              child: Image(
                image: AssetImage(image),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          const Spacer(),
          Text(
            caption,
            style: _style(
              context,
              20,
              weight: FontWeight.w500,
              color: Colors.white,
              height: 1.55,
              letterSpacing: -0.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupGrid extends StatelessWidget {
  const _GroupGrid();

  @override
  Widget build(BuildContext context) {
    final scale = _HomeScale.of(context);
    final largeText = _usesLargeHomeText(context);
    const items = <(String, String, String)>[
      ('NH투자증권', '다양한 투자상품과\n리서치', 'assets/images/ref_group_0.png'),
      ('NH농협카드', '일상 속 혜택을\n더욱 풍성하게', 'assets/images/ref_group_1.png'),
      ('NH농협생명', '든든한 보장과 함께\n준비하는 미래', 'assets/images/ref_group_2.png'),
      ('NH농협손해보험', '일상 속 위험을\n지켜주는 맞춤형 보장', 'assets/images/ref_group_3.png'),
      ('NH농협캐피탈', '대출이 필요할 때,\n언제나 든든한', 'assets/images/ref_group_4.png'),
      ('NH저축은행', '간편하게 대출 신청\n합리적인 예금조회', 'assets/images/ref_group_5.png'),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 28 * scale),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14 * scale,
          crossAxisSpacing: 14 * scale,
          mainAxisExtent: (largeText ? 246 : 210) * scale,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            padding: EdgeInsets.fromLTRB(
              28 * scale,
              26 * scale,
              22 * scale,
              16 * scale,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_cardRadius * scale),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.$1,
                    maxLines: 1,
                    style: _style(
                      context,
                      20,
                      weight: FontWeight.w500,
                      letterSpacing: -0.55,
                    ),
                  ),
                ),
                SizedBox(height: 7 * scale),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.$2,
                    softWrap: false,
                    style: _style(
                      context,
                      18,
                      weight: FontWeight.w500,
                      color: const Color(0xFF555B5D),
                      height: 1.5,
                    ),
                  ),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: SizedBox.square(
                    dimension: 67 * scale,
                    child: Image(
                      image: AssetImage(item.$3),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HomeSettingsLink extends StatelessWidget {
  const _HomeSettingsLink();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '홈 화면 설정',
        style:
            _style(
              context,
              18,
              weight: FontWeight.w500,
              color: const Color(0xFF555B5D),
            ).copyWith(
              decoration: TextDecoration.underline,
              decorationColor: const Color(0xFF62686A),
            ),
      ),
    );
  }
}

class _AssetsFab extends StatelessWidget {
  const _AssetsFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = _HomeScale.of(context);
    final largeText = _usesLargeHomeText(context);
    return GestureDetector(
      key: const Key('home-assets-fab'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30 * scale),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Container(
          width: (largeText ? 224 : 202) * scale,
          height: 60 * scale,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF19A85F), Color(0xFF277BEA)],
            ),
            borderRadius: BorderRadius.circular(30 * scale),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.scale(
                scaleX: 1.2,
                child: Text(
                  '내 자산 확인',
                  style: _style(
                    context,
                    18,
                    weight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.45,
                  ),
                ),
              ),
              SizedBox(width: 10 * scale),
              Icon(
                Icons.keyboard_double_arrow_down_rounded,
                size: 29 * scale,
                color: const Color(0xFF8CCAF7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation();

  @override
  Widget build(BuildContext context) {
    final scale = _HomeScale.of(context);
    return ColoredBox(
      color: _homeBackground,
      child: Material(
        key: const Key('home-bottom-navigation'),
        color: Colors.white,
        elevation: 3,
        shadowColor: const Color(0x18000000),
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28 * scale)),
        child: SafeArea(
          top: false,
          maintainBottomViewPadding: true,
          child: SizedBox(
            height: 83 * scale,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 21 * scale),
              child: const Row(
                children: [
                  _NavItem(label: '홈', kind: _NavKind.home, selected: true),
                  _NavItem(label: '금융상품', kind: _NavKind.products),
                  _NavItem(label: '내 자산', kind: _NavKind.my),
                  _NavItem(label: '포인트쌓기', kind: _NavKind.point),
                  _NavItem(label: '생활혜택', kind: _NavKind.gift),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _NavKind { home, products, my, point, gift }

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.kind,
    this.selected = false,
  });

  final String label;
  final _NavKind kind;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scale = _HomeScale.of(context);
    const color = Color(0xFF17191A);
    return Expanded(
      child: Padding(
        key: ValueKey('home-nav-${kind.name}'),
        padding: EdgeInsets.only(top: 18 * scale),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(
              width: 40 * scale,
              height: 40 * scale,
              child: _NavGlyph(kind: kind),
            ),
            SizedBox(height: 3 * scale),
            Transform.scale(
              scaleX: 1.08,
              child: Text(
                label,
                style: _style(
                  context,
                  15,
                  weight: selected ? FontWeight.w500 : FontWeight.w500,
                  color: color,
                  height: 0.8,
                  letterSpacing: -0.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavGlyph extends StatelessWidget {
  const _NavGlyph({required this.kind});

  final _NavKind kind;

  @override
  Widget build(BuildContext context) {
    final asset = switch (kind) {
      _NavKind.home => 'assets/images/ref_nav_home.png',
      _NavKind.products => 'assets/images/ref_nav_products.png',
      _NavKind.my => 'assets/images/ref_nav_my.png',
      _NavKind.point => 'assets/images/ref_nav_point.png',
      _NavKind.gift => 'assets/images/ref_nav_gift.png',
    };
    return Image(
      image: AssetImage(asset),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
