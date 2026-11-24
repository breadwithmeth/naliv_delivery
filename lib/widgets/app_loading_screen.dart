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

// Shared timing in milliseconds for the seal flights and reveal.
const _flightDuration = 2750;
const _lastSealDelay = 500;
const _introDuration = _flightDuration + _lastSealDelay;
const _revealStart = 1600;
const _revealDuration = 520;
const _veilDuration = 240;
const _revealAt = _revealStart / _introDuration;
const _revealEnd = (_revealStart + _revealDuration) / _introDuration;

enum _LaunchPhase { intro, reveal, tail, finished }

class _AppLaunchIntroState extends State<AppLaunchIntro>
    with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _introDuration),
  )..addListener(_advance);
  _LaunchPhase _phase = _LaunchPhase.intro;
  bool get _revealed => _phase != _LaunchPhase.intro;

  void _advance() {
    final progress = _clock.value;
    final phase = _clock.isCompleted
        ? _LaunchPhase.finished
        : progress >= _revealEnd
        ? _LaunchPhase.tail
        : progress >= _revealAt
        ? _LaunchPhase.reveal
        : _LaunchPhase.intro;
    if (phase != _phase) setState(() => _phase = phase);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_phase == _LaunchPhase.finished) return;
    if (AppMotion.reduced(context)) {
      _clock.stop();
      _phase = _LaunchPhase.finished;
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
      if (_phase != _LaunchPhase.finished)
        IgnorePointer(
          child: Semantics(
            textDirection: TextDirection.ltr,
            label: _revealed ? null : 'Загрузка Градусы24',
            child: ExcludeSemantics(child: _IntroArtwork(_clock, _phase)),
          ),
        ),
    ],
  );
}

class _IntroArtwork extends StatelessWidget {
  const _IntroArtwork(this.clock, this.phase);
  final Animation<double> clock;
  final _LaunchPhase phase;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    fit: StackFit.expand,
    children: [
      if (phase != _LaunchPhase.tail)
        ClipPath(
          clipper: phase == _LaunchPhase.reveal ? _RevealClip(clock) : null,
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
    ],
  );
}

// The orange frame lifts off the destination with the site's rounded leading edge.
class _RevealClip extends CustomClipper<Path> {
  _RevealClip(this.clock) : super(reclip: clock);
  final Animation<double> clock;

  @override
  Path getClip(Size size) {
    final progress =
        (clock.value * _introDuration - _revealStart) / _revealDuration;
    final t = Curves.easeInOut.transform(progress.clamp(0.0, 1.0));
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

// Source layers 3 → 2 → 1. Keep the waypoints and timing in sync with web/index.html.
// Offsets are logical pixels relative to screen centre, not percentages.
const _stamps = [
  (
    asset: 'assets/startup/3.png',
    delay: 0,
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
    delay: 300,
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
    delay: _lastSealDelay,
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

const _waypoints = [0.0, .2, .52, .8, 1.0];

// Hermite coefficients. Adjacent spans share a monotone tangent, so a seal
// carries its velocity through a waypoint instead of starting a fresh ease.
class _FlightSegment {
  const _FlightSegment(this.start, this.linear, this.quadratic, this.cubic);

  final double start;
  final double linear;
  final double quadratic;
  final double cubic;

  double sample(double t) => start + t * (linear + t * (quadratic + t * cubic));

  static List<_FlightSegment> track(List<double> values) {
    final slopes = [
      for (var i = 0; i < values.length - 1; i++)
        (values[i + 1] - values[i]) / (_waypoints[i + 1] - _waypoints[i]),
    ];
    double tangent(int i) {
      if (i == 0) return slopes.first;
      if (i == slopes.length) return slopes.last;
      final before = slopes[i - 1];
      final after = slopes[i];
      return before * after <= 0 ? 0 : 2 * before * after / (before + after);
    }

    var from = tangent(0);
    return List.generate(slopes.length, (i) {
      final to = tangent(i + 1);
      final span = _waypoints[i + 1] - _waypoints[i];
      final a = from * span;
      final b = to * span;
      final delta = values[i + 1] - values[i];
      from = to;
      return _FlightSegment(
        values[i],
        a,
        3 * delta - 2 * a - b,
        a + b - 2 * delta,
      );
    }, growable: false);
  }
}

class _StampFlight extends FlowDelegate {
  _StampFlight(this.clock) : super(repaint: clock);
  final Animation<double> clock;
  static final _scaleTrack = _FlightSegment.track([.96, 1, 1.04, 1.02, 1]);
  static final _paths = [
    for (final stamp in _stamps)
      (
        x: _FlightSegment.track(stamp.x),
        y: _FlightSegment.track(stamp.y),
        angle: _FlightSegment.track(stamp.angle),
      ),
  ];

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      const BoxConstraints.tightFor(width: 553, height: 545);

  @override
  void paintChildren(FlowPaintingContext ctx) {
    final milliseconds = clock.value * _introDuration;
    final fade = Curves.ease.transform(
      ((milliseconds - _revealStart) / _veilDuration).clamp(0.0, 1.0),
    );
    for (var i = 0; i < _stamps.length; i++) {
      final stamp = _stamps[i];
      final t = (milliseconds - stamp.delay) / _flightDuration;
      if (t < 0 || t >= 1) continue;
      var k = 0;
      while (t > _waypoints[k + 1]) {
        k++;
      }
      final u = (t - _waypoints[k]) / (_waypoints[k + 1] - _waypoints[k]);
      final path = _paths[i];
      final y = path.y[k].sample(u);
      final x = path.x[k].sample(u);
      final angle = path.angle[k].sample(u) * (math.pi / 180);
      for (var layer = 0; layer < 2; layer++) {
        final echo = layer == 0;
        final scale = stamp.scale * (echo ? .92 : _scaleTrack[k].sample(u));
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
