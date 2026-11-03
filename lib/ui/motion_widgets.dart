import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../design/motion.dart';

/// Shrinks its child slightly while a pointer is down on it.
///
/// A raw [Listener] drives it, so it never joins the gesture arena: taps, scrolling and
/// inner buttons behave exactly as without it. The press is released as soon as the
/// pointer travels past the touch slop, so a scroll that starts on the surface does not
/// leave it shrunken. Use it on large tappable surfaces only.
///
/// With [wholeSurface] false the scale follows only a [PressScaleTrigger] descendant, for
/// surfaces that hold their own buttons (a product card's cart control).
class PressScale extends StatefulWidget {
  const PressScale({
    required this.child,
    this.scale = .97,
    this.wholeSurface = true,
    this.enabled = true,
    super.key,
  });

  final Widget child;
  final double scale;
  final bool wholeSurface;

  /// Whether the surface reacts at all (a tile without a destination does not).
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;
  int? _pointer;
  Offset _origin = Offset.zero;

  void _down(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _origin = event.position;
    _set(true);
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    if ((event.position - _origin).distance > kTouchSlop) _set(false);
  }

  void _end(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _set(false);
  }

  void _set(bool pressed) {
    if (_pressed == pressed || !mounted) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final active = _pressed && !AppMotion.reduced(context);
    final scaled = AnimatedScale(
      scale: active ? widget.scale : 1,
      duration: active ? AppMotion.pressDown : AppMotion.pressUp,
      curve: AppMotion.out,
      child: widget.child,
    );
    if (!widget.wholeSurface || !widget.enabled) return scaled;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _end,
      onPointerCancel: _end,
      child: scaled,
    );
  }
}

/// The press region of a [PressScale] created with `wholeSurface: false`.
class PressScaleTrigger extends StatelessWidget {
  const PressScaleTrigger({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_PressScaleState>();
    if (state == null) return child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: state._down,
      onPointerMove: state._move,
      onPointerUp: state._end,
      onPointerCancel: state._end,
      child: child,
    );
  }
}

/// Cross-fades (with a small scale) between two states of a control.
///
/// [stateKey] names the state shown; when it changes the previous child fades out, ignores
/// the pointer and drops out of the semantics tree while the new one arrives. The first
/// build never animates.
class AnimatedSwap extends StatelessWidget {
  const AnimatedSwap({
    required this.stateKey,
    required this.child,
    this.duration = AppMotion.swap,
    this.scale = .92,
    this.scaleCurve = AppMotion.out,
    super.key,
  });

  final Object stateKey;
  final Widget child;
  final Duration duration;

  /// The incoming child's starting scale.
  final double scale;
  final Curve scaleCurve;

  @override
  Widget build(BuildContext context) {
    final current = ValueKey<Object>(stateKey);
    // Reduced motion: the control simply changes.
    if (AppMotion.reduced(context)) return child;
    final length = AppMotion.of(context, duration);
    return AnimatedSwitcher(
      duration: length,
      reverseDuration: length * .7,
      switchInCurve: Curves.linear,
      switchOutCurve: Curves.linear,
      transitionBuilder: (child, animation) {
        final outgoing = child.key != current;
        return IgnorePointer(
          ignoring: outgoing,
          child: ExcludeSemantics(
            excluding: outgoing,
            child: FadeTransition(
              opacity: animation.drive(CurveTween(
                  curve: outgoing ? AppMotion.leave : AppMotion.out)),
              child: ScaleTransition(
                scale: animation.drive(Tween(begin: scale, end: 1.0).chain(
                    CurveTween(
                        curve: outgoing ? AppMotion.leave : scaleCurve))),
                child: child,
              ),
            ),
          ),
        );
      },
      child: KeyedSubtree(key: current, child: child),
    );
  }
}

/// A number that slides vertically to its next value: up when [value] grows, down when it
/// shrinks, cross-fading as it goes. The first build never animates.
class AnimatedCount extends StatefulWidget {
  const AnimatedCount({
    required this.text,
    required this.value,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.duration = AppMotion.count,
    super.key,
  });

  /// What is shown.
  final String text;

  /// The quantity [text] stands for; only its direction of change matters.
  final num value;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final Duration duration;

  @override
  State<AnimatedCount> createState() => _AnimatedCountState();
}

class _AnimatedCountState extends State<AnimatedCount> {
  /// 1 when the value grew, -1 when it shrank, 0 when only the text changed.
  int _direction = 0;

  @override
  void didUpdateWidget(AnimatedCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _direction = widget.value.compareTo(oldWidget.value).sign;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ValueKey<String>(widget.text);
    final direction = _direction.toDouble();
    final label = Text(
      widget.text,
      key: current,
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      softWrap: widget.softWrap,
    );
    // Reduced motion: the number simply changes.
    if (AppMotion.reduced(context)) return label;
    final length = AppMotion.of(context, widget.duration);
    return AnimatedSwitcher(
      duration: length,
      reverseDuration: length * .75,
      switchInCurve: Curves.linear,
      switchOutCurve: Curves.linear,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.center,
        children: [
          ...previousChildren,
          if (currentChild != null) currentChild,
        ],
      ),
      transitionBuilder: (child, animation) {
        final outgoing = child.key != current;
        final curve = outgoing ? AppMotion.leave : AppMotion.out;
        // The incoming number starts below (growing) or above (shrinking) its slot and the
        // outgoing one leaves the opposite way.
        final shift = outgoing ? -direction * .5 : direction * .5;
        return ExcludeSemantics(
          excluding: outgoing,
          child: FadeTransition(
            opacity: animation.drive(CurveTween(curve: curve)),
            child: SlideTransition(
              position: animation.drive(Tween(
                begin: Offset(0, shift),
                end: Offset.zero,
              ).chain(CurveTween(curve: curve))),
              child: child,
            ),
          ),
        );
      },
      child: label,
    );
  }
}

/// Briefly scales its child up and settles it back when [value] changes (and
/// [shouldBump] agrees): small "pop" feedback for a badge whose count grew.
class Bump<T> extends StatefulWidget {
  const Bump({
    required this.value,
    required this.child,
    this.shouldBump,
    this.peak = 1.25,
    this.duration = AppMotion.bump,
    super.key,
  });

  final T value;
  final Widget child;

  /// Defaults to bumping on every change.
  final bool Function(T previous, T next)? shouldBump;
  final double peak;
  final Duration duration;

  @override
  State<Bump<T>> createState() => _BumpState<T>();
}

class _BumpState<T> extends State<Bump<T>> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);
  late Animation<double> _scale = _build();

  Animation<double> _build() => TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: widget.peak)
              .chain(CurveTween(curve: AppMotion.out)),
          weight: 35,
        ),
        TweenSequenceItem(
          tween: Tween(begin: widget.peak, end: 1.0)
              .chain(CurveTween(curve: AppMotion.overshoot)),
          weight: 65,
        ),
      ]).animate(_controller);

  @override
  void didUpdateWidget(Bump<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.peak != oldWidget.peak) _scale = _build();
    if (widget.value == oldWidget.value) return;
    if (widget.shouldBump?.call(oldWidget.value, widget.value) == false) return;
    if (AppMotion.reduced(context)) return;
    _controller.duration = widget.duration;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}

/// A network image `frameBuilder` that fades the picture in after its first decode.
///
/// Images already in the cache (`wasSynchronouslyLoaded`) appear at once, so scrolling back
/// over loaded artwork never flickers.
Widget fadeInImageFrame(
  BuildContext context,
  Widget child,
  int? frame,
  bool wasSynchronouslyLoaded,
) {
  if (wasSynchronouslyLoaded) return child;
  return AnimatedOpacity(
    opacity: frame == null ? 0 : 1,
    duration: AppMotion.of(context, AppMotion.image),
    curve: AppMotion.out,
    child: child,
  );
}

/// Fades and scales its child in once, when it is first mounted.
///
/// Pass `animate: false` for children that are part of a screen's first frame, so nothing
/// moves on initial build. Give it a key when siblings can come and go around it.
class AppearIn extends StatefulWidget {
  const AppearIn({
    required this.child,
    this.animate = true,
    this.scale = .9,
    this.duration = AppMotion.swap,
    super.key,
  });

  final Widget child;
  final bool animate;
  final double scale;
  final Duration duration;

  @override
  State<AppearIn> createState() => _AppearInState();
}

class _AppearInState extends State<AppearIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.animate && !AppMotion.reduced(context)) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _controller.drive(CurveTween(curve: AppMotion.out)),
        child: ScaleTransition(
          scale: _controller.drive(Tween(begin: widget.scale, end: 1.0)
              .chain(CurveTween(curve: AppMotion.out))),
          child: widget.child,
        ),
      );
}
