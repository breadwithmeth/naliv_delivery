import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../design/motion.dart';
import '../design/theme.dart';

const _orange = Color(0xfff97300);
const _logo = 'assets/startup/logo1.png';

/// The store can still be loading after the one-time launch animation ends.
class AppLoadingScreen extends StatelessWidget {
  const AppLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Image.asset(
        _logo,
        width: 200,
        color: context.palette.accent,
        semanticLabel: 'Загрузка Градусы24',
      ),
    ),
  );
}

/// Paints the go.gradusy24.kz intro over the real route, not in its place.
class AppLaunchIntro extends StatefulWidget {
  const AppLaunchIntro({required this.child, super.key});

  final Widget child;

  @override
  State<AppLaunchIntro> createState() => _AppLaunchIntroState();
}

const _duration = Duration(milliseconds: 4950);
const _reveal = 1600 / 4950;

class _AppLaunchIntroState extends State<AppLaunchIntro>
    with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(vsync: this, duration: _duration)
    ..addListener(_advance);
  bool _revealed = false;
  bool _finished = false;

  void _advance() {
    if (_clock.value >= _reveal && !_revealed ||
        _clock.isCompleted && !_finished) {
      setState(() {
        _revealed = true;
        _finished = _clock.isCompleted;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_finished) return;
    if (AppMotion.reduced(context)) {
      _clock.stop();
      _revealed = _finished = true;
    } else if (!_clock.isAnimating) {
      _clock.forward();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    fit: StackFit.expand,
    children: [
      ExcludeFocus(
        excluding: !_revealed,
        child: ExcludeSemantics(
          excluding: !_revealed,
          child: IgnorePointer(ignoring: !_revealed, child: widget.child),
        ),
      ),
      if (!_finished)
        IgnorePointer(
          child: Semantics(
            textDirection: TextDirection.ltr,
            label: _revealed ? null : 'Загрузка Градусы24',
            child: ExcludeSemantics(child: _IntroArtwork(_clock)),
          ),
        ),
    ],
  );
}

class _IntroArtwork extends StatelessWidget {
  const _IntroArtwork(this.clock);
  final Animation<double> clock;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    fit: StackFit.expand,
    children: [
      ClipPath(
        clipper: _RevealClip(clock),
        child: ColoredBox(
          color: _orange,
          child: LayoutBuilder(
            builder: (_, bounds) => Center(
              child: Image.asset(
                _logo,
                width:
                    .8 * math.min(420.0, math.max(0.0, bounds.maxWidth - 20)),
              ),
            ),
          ),
        ),
      ),
      Flow(
        delegate: _StampFlight(clock),
        children: [
          for (final stamp in _stamps) ...[
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: stamp.blur,
                sigmaY: stamp.blur,
              ),
              child: Image.asset(stamp.asset),
            ),
            Image.asset(stamp.asset),
          ],
        ],
      ),
      CustomPaint(
        painter: _IntroLine(clock, MediaQuery.viewPaddingOf(context).bottom),
      ),
    ],
  );
}

// The orange frame lifts off the destination with the site's rounded leading edge.
class _RevealClip extends CustomClipper<Path> {
  _RevealClip(this.clock) : super(reclip: clock);
  final Animation<double> clock;

  @override
  Path getClip(Size size) {
    final t = ((clock.value - _reveal) * 4950 / 520).clamp(0.0, 1.0);
    final y = size.height * (1 - t);
    final arch = size.height * .18 * math.sin(math.pi * t);
    return Path()
      ..lineTo(size.width, 0)
      ..lineTo(size.width, y)
      ..quadraticBezierTo(size.width / 2, y - arch, 0, y)
      ..close();
  }

  @override
  bool shouldReclip(_RevealClip old) => old.clock != clock;
}

// Source layers 3 → 2 → 1, five linear keyframes at 0, .2, .52, .8, 1.
// Offsets are logical pixels relative to screen centre, not percentages.
const _stamps = [
  (
    asset: 'assets/startup/3.png',
    delay: 0.0,
    scale: 1.2,
    echo: 130.0,
    blur: 2.5,
    alpha: .20,
    veil: .10,
    ghost: .035,
    x: [-40.0, -18.0, 6.0, 26.0, 42.0],
    y: [1420.0, 980.0, 280.0, -520.0, -1420.0],
    angle: [-2.2, -1.1, .4, 1.5, 2.4],
  ),
  (
    asset: 'assets/startup/2.png',
    delay: .3,
    scale: 1.3,
    echo: 100.0,
    blur: 2.0,
    alpha: .18,
    veil: .085,
    ghost: .030,
    x: [30.0, 14.0, -4.0, -24.0, -38.0],
    y: [1400.0, 940.0, 180.0, -620.0, -1440.0],
    angle: [2.0, .9, -.5, -1.7, -2.7],
  ),
  (
    asset: 'assets/startup/1.png',
    delay: .5,
    scale: 1.5,
    echo: 72.0,
    blur: 1.5,
    alpha: .16,
    veil: .075,
    ghost: .025,
    x: [-18.0, -6.0, 8.0, 20.0, 30.0],
    y: [1380.0, 900.0, 80.0, -720.0, -1460.0],
    angle: [-1.2, -.4, .8, 1.8, 2.6],
  ),
];

class _StampFlight extends FlowDelegate {
  _StampFlight(this.clock) : super(repaint: clock);
  final Animation<double> clock;
  static const _times = [0.0, .2, .52, .8, 1.0];
  static const _scales = [.96, 1.0, 1.04, 1.02, 1.0];

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      const BoxConstraints.tightFor(width: 553, height: 545);

  @override
  void paintChildren(FlowPaintingContext ctx) {
    final seconds = clock.value * 4.95;
    final fade = ((seconds - 1.6) / .24).clamp(0.0, 1.0);
    for (var i = 0; i < _stamps.length; i++) {
      final stamp = _stamps[i];
      final t = (seconds - stamp.delay) / 2.75;
      if (t < 0 || t >= 1) continue;
      var k = 0;
      while (t > _times[k + 1]) {
        k++;
      }
      final u = (t - _times[k]) / (_times[k + 1] - _times[k]);
      double sample(List<double> values) =>
          values[k] + (values[k + 1] - values[k]) * u;
      final y = sample(stamp.y);
      final x = sample(stamp.x);
      final angle = sample(stamp.angle) * math.pi / 180;
      for (var layer = 0; layer < 2; layer++) {
        final echo = layer == 0;
        final scale = stamp.scale * (echo ? .92 : sample(_scales));
        final dy = ctx.size.height / 2 + y + (echo ? stamp.echo : 0);
        if (dy < -400 * scale || dy > ctx.size.height + 400 * scale) continue;
        ctx.paintChild(
          i * 2 + layer,
          transform:
              Matrix4.translationValues(
                  ctx.size.width / 2 + x * (echo ? .6 : 1),
                  dy,
                  0,
                )
                ..rotateZ(angle)
                ..scaleByDouble(scale, scale, 1, 1)
                ..translateByDouble(-276.5, -272.5, 0, 1),
          opacity: echo
              ? stamp.alpha + (stamp.ghost - stamp.alpha) * fade
              : 1 + (stamp.veil - 1) * fade,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_StampFlight oldDelegate) => clock != oldDelegate.clock;
}

class _IntroLine extends CustomPainter {
  _IntroLine(this.clock, this.bottom) : super(repaint: clock);
  final Animation<double> clock;
  final double bottom;
  final _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final width = math.min(520.0, size.width - 32);
    if (width <= 0) return;
    final x = (size.width - width) / 2;
    final y = size.height - bottom - 18;
    _paint.color = const Color(0x4dffffff);
    canvas.drawRect(Rect.fromLTWH(x, y, width, 2), _paint);
    _paint.color = clock.value < _reveal ? Colors.white : _orange;
    canvas.drawRect(Rect.fromLTWH(x, y, width * clock.value, 2), _paint);
  }

  @override
  bool shouldRepaint(_IntroLine old) =>
      old.clock != clock || old.bottom != bottom;
}
