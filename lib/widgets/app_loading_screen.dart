import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/motion.dart';
import '../design/theme.dart';

const _orange = Color(0xfff97300);
const _logo = 'assets/startup/logo1.png';
const _cap = 'assets/startup/launch-cap.png';
const _word = 'assets/startup/launch-word.png';

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
  const AppLaunchIntro({required this.child, this.visibleWindow, super.key});

  final Widget child;

  /// Completes when the host can display Flutter, not merely when Dart starts.
  /// An already visible, embedded preview has no host transition to await.
  final Future<void>? visibleWindow;

  @override
  State<AppLaunchIntro> createState() => _AppLaunchIntroState();
}

// Shared timing in milliseconds for the seal flights and reveal.
const _flightDuration = 2750;
const _lastSealDelay = 500;
const _revealStart = 1600;
const _revealDuration = 520;
const _veilDuration = 240;
const _tailFade = 320;
const _introDuration = _revealStart + _revealDuration + _tailFade;
const _revealAt = _revealStart / _introDuration;
const _revealEnd = (_revealStart + _revealDuration) / _introDuration;

enum _LaunchPhase { intro, reveal, tail, finished }

class _AppLaunchIntroState extends State<AppLaunchIntro>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _introDuration),
  )..addListener(_advance);
  _LaunchPhase _phase = _LaunchPhase.intro;
  bool get _revealed => _phase != _LaunchPhase.intro;
  bool _preparing = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _prepare() async {
    await Future.wait<void>([
      if (widget.visibleWindow case final window?) window,
      precacheImage(const AssetImage(_cap), context),
      precacheImage(const AssetImage(_word), context),
    ]);
    if (!mounted || _phase == _LaunchPhase.finished) return;
    // Paint the decoded cap at t=0 before a ticker can consume its entrance.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _phase == _LaunchPhase.finished) return;
    _ready = true;
    _syncPlayback(WidgetsBinding.instance.lifecycleState);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _syncPlayback(state);

  void _syncPlayback(AppLifecycleState? state) {
    if (!_ready || _phase == _LaunchPhase.finished) return;
    if (state == null || state == AppLifecycleState.resumed) {
      if (!_clock.isAnimating) _clock.forward();
    } else {
      _clock.stop();
    }
  }

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
    } else if (!_preparing) {
      _preparing = true;
      unawaited(_prepare());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
        // Paint the first Home frame under the opaque intro, not on the same
        // vsync that starts the reveal. Keep the covered route inaccessible.
        child: ExcludeSemantics(
          excluding: !_revealed,
          child: IgnorePointer(
            ignoring: !_revealed,
            child: RepaintBoundary(child: widget.child),
          ),
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
          child: const ColoredBox(color: _orange),
        ),
      Flow(
        delegate: _StampFlight(clock),
        children: [
          for (final stamp in _stamps) ...[
            Image.asset(stamp.echoAsset, opacity: clock.drive(stamp.echoOpacity)),
            Image.asset(stamp.asset, opacity: clock.drive(stamp.opacity)),
          ],
        ],
      ),
      if (phase == _LaunchPhase.intro)
        Flow(
          delegate: _Imprint(clock),
          children: [
            ClipRect(
              clipper: _UnrollWord(clock),
              child: Image.asset(
                _word,
                opacity: clock.drive(_imprintInk),
              ),
            ),
            Image.asset(
              _cap,
              opacity: clock.drive(_imprintInk),
            ),
          ],
        ),
    ],
  );
}

// A single impression: strike, unroll the original lockup, then lift it
// clear before the leading seal enters the letters. Coordinates are the
// exact ink crops in the 2450 × 553 master, not approximated text metrics.
const _wordFraction = 1854 / 2450;
const _capFraction = 553 / 2450;
const _imprintInk = _ImprintInk();

double _beat(double ms, double start, double end) =>
    ((ms - start) / (end - start)).clamp(0.0, 1.0);

double _unroll(double ms) => Curves.easeOutCubic.transform(_beat(ms, 130, 530));

double _release(double ms) => Curves.easeInCubic.transform(_beat(ms, 1080, 1290));

class _ImprintInk extends Animatable<double> {
  const _ImprintInk();

  @override
  double transform(double t) => 1 - _release(t * _introDuration);
}

class _UnrollWord extends CustomClipper<Rect> {
  _UnrollWord(this.clock) : super(reclip: clock);
  final Animation<double> clock;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(
    0, 0, size.width * _unroll(clock.value * _introDuration), size.height,
  );

  @override
  bool shouldReclip(_UnrollWord old) => old.clock != clock;
}

class _Imprint extends FlowDelegate {
  _Imprint(this.clock) : super(repaint: clock);
  final Animation<double> clock;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) {
    final width = .8 * (constraints.maxWidth - 20).clamp(0.0, 420.0);
    return BoxConstraints.tightFor(
      width: width * (i == 0 ? _wordFraction : _capFraction),
      height: width * _capFraction,
    );
  }

  @override
  void paintChildren(FlowPaintingContext ctx) {
    final ms = clock.value * _introDuration;
    if (ms >= 1290) return;
    final travel = _unroll(ms);
    final diameter = ctx.getChildSize(1)!.height;
    final travelX = (diameter / _capFraction - diameter) / 2 * travel;
    final x = (ctx.size.width - diameter) / 2;
    final dip = 4 * Curves.easeInCubic.transform(_beat(ms, 990, 1080));
    final y = (ctx.size.height - diameter) / 2 + dip - 52 * _release(ms);
    if (travel > 0) {
      ctx.paintChild(0, transform: Matrix4.translationValues(x - travelX, y, 0));
    }
    final scale = ms < 100
        ? 1.38 - .46 * Curves.easeInCubic.transform(_beat(ms, 0, 100))
        : .92 + .08 * Curves.easeOutCubic.transform(_beat(ms, 100, 200));
    final r = diameter / 2;
    ctx.paintChild(1, transform: Matrix4.translationValues(x + travelX + r, y + r, 0)
      ..rotateZ(-22 * math.pi / 180 * (1 - travel))
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-r, -r, 0, 1));
  }

  @override
  bool shouldRepaint(_Imprint old) => old.clock != clock;
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

// Modulate the bitmap's paint, not a composited layer around each moving seal.
class _FlightOpacity extends Animatable<double> {
  const _FlightOpacity(this.initial, this.veil);
  final double initial;
  final double veil;

  @override
  double transform(double t) {
    final ms = t * _introDuration;
    if (ms <= _revealStart) return initial;
    if (ms < _revealStart + _veilDuration) {
      return initial + (veil - initial) *
          Curves.ease.transform((ms - _revealStart) / _veilDuration);
    }
    return veil * (1 - ((ms - _revealStart - _revealDuration) / _tailFade).clamp(0.0, 1.0));
  }
}

// Source layers 3 → 2 → 1. Keep the waypoints and timing in sync with web/index.html.
// Offsets are logical pixels relative to screen centre, not percentages.
const _stamps = [
  (
    asset: 'assets/startup/3.png',
    delay: 0,
    scale: 1.2,
    echo: 130.0,
    echoAsset: 'assets/startup/3-echo.png',
    opacity: _FlightOpacity(1, .10),
    echoOpacity: _FlightOpacity(.20, .035),
    x: [-40.0, -18.0, 6.0, 26.0, 42.0],
    y: [1420.0, 980.0, 280.0, -520.0, -1420.0],
    angle: [-2.2, -1.1, .4, 1.5, 2.4],
  ),
  (
    asset: 'assets/startup/2.png',
    delay: 300,
    scale: 1.3,
    echo: 100.0,
    echoAsset: 'assets/startup/2-echo.png',
    opacity: _FlightOpacity(1, .085),
    echoOpacity: _FlightOpacity(.18, .030),
    x: [30.0, 14.0, -4.0, -24.0, -38.0],
    y: [1400.0, 940.0, 180.0, -620.0, -1440.0],
    angle: [2.0, .9, -.5, -1.7, -2.7],
  ),
  (
    asset: 'assets/startup/1.png',
    delay: _lastSealDelay,
    scale: 1.5,
    echo: 72.0,
    echoAsset: 'assets/startup/1-echo.png',
    opacity: _FlightOpacity(1, .075),
    echoOpacity: _FlightOpacity(.16, .025),
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
        );
      }
    }
  }

  @override
  bool shouldRepaint(_StampFlight oldDelegate) => clock != oldDelegate.clock;
}
