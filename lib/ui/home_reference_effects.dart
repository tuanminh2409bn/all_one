import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'home_chevron_motion.dart';

const homeBenefitLabels = ['매일 포인트 용돈 받기', '쓸수록 돈 되는 생활혜택 모음', '지금 핫한 이벤트 보기'];
const _benefitIcons = ['point', 'bag', 'fire'];

/// The source's icon animation stays at native resolution; copy is live text.
class HomeBenefitStrip extends StatefulWidget {
  const HomeBenefitStrip({super.key, required this.scale});

  final double scale;

  @override
  State<HomeBenefitStrip> createState() => _HomeBenefitStripState();
}

class _HomeBenefitStripState extends State<HomeBenefitStrip>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 7500),
  );
  bool _reducedMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return RepaintBoundary(
      child: Semantics(
        label: homeBenefitLabels.join(', '),
        child: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final elapsed = _controller.value * 7500;
              final index = _reducedMotion ? 0 : (elapsed ~/ 2500) % 3;
              final messageTime = elapsed % 2500;
              final suffix = _reducedMotion ? '_still' : '';
              final reveal = _reducedMotion
                  ? double.infinity
                  : math.max(0.0, (messageTime - 150) * .35) * scale;
              return SizedBox(
                height: 70 * scale,
                child: Row(
                  children: [
                    Opacity(
                      opacity: _reducedMotion
                          ? 1
                          : (messageTime / 120).clamp(0.0, 1.0),
                      child: Image.asset(
                        'assets/images/home_benefit_${_benefitIcons[index]}$suffix.png',
                        key: ValueKey('home-benefit-icon-$index'),
                        width: 62 * scale,
                        height: 62 * scale,
                        filterQuality: FilterQuality.high,
                        gaplessPlayback: true,
                      ),
                    ),
                    SizedBox(width: 6 * scale),
                    Expanded(
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (bounds) {
                          final edge = reveal.clamp(0.0, bounds.width);
                          final feather = math.min(12 * scale, edge);
                          return LinearGradient(
                            colors: const [
                              Colors.white,
                              Colors.white,
                              Colors.transparent,
                              Colors.transparent,
                            ],
                            stops: [
                              0,
                              (edge - feather) / bounds.width,
                              edge / bounds.width,
                              1,
                            ],
                          ).createShader(bounds);
                        },
                        child: Text(
                          homeBenefitLabels[index],
                          key: const Key('home-benefit-label'),
                          textScaler: TextScaler.noScaling,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: 'NotoSansKRMedium',
                            fontSize: 24 * scale,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -.7 * scale,
                            height: 1.2,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Vector strokes driven by the measured 1.5-second reference sequence.
class HomeAssetChevrons extends StatefulWidget {
  const HomeAssetChevrons({super.key, required this.scale});

  final double scale;

  @override
  State<HomeAssetChevrons> createState() => _HomeAssetChevronsState();
}

class _HomeAssetChevronsState extends State<HomeAssetChevrons>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = .5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: SizedBox(
        width: 24 * widget.scale,
        height: 35 * widget.scale,
        child: CustomPaint(painter: _ChevronPainter(_controller)),
      ),
    ),
  );
}

class _ChevronPainter extends CustomPainter {
  _ChevronPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final frame =
        homeChevronFrames[(animation.value * homeChevronFrames.length).floor() %
            homeChevronFrames.length];
    canvas.save();
    canvas.scale(size.width / 48, size.height / 70);
    for (final (top, opacity) in [(frame.$1, frame.$2), (frame.$3, frame.$4)]) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(
        Path()
          ..moveTo(7, top - 108)
          ..lineTo(23, top - 92)
          ..lineTo(40, top - 108),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChevronPainter oldDelegate) =>
      animation != oldDelegate.animation;
}
