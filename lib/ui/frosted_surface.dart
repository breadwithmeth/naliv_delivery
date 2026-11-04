import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../design/theme.dart';
import '../design/tokens.dart';

/// The app's one translucent material: the "glass" of the design (`#141414` /
/// `#FFFFFF` at 75 % over a background blur) done as X or YouTube do it, with a
/// single small backdrop blur, a theme tint, a hairline edge and a shadow that
/// stays outside the shape.
///
/// [FrostedDock] (the bottom bar), the cart button, the round top-bar discs
/// (`AppIconButton`), floating fields and orange controls use these tokens so
/// the material reads the same everywhere.
abstract final class Frost {
  /// Blur radius. Strong enough that text behind turns into colour, small
  /// enough to stay cheap for control-sized regions.
  static const double sigma = 18;

  static final ui.ImageFilter blur = ui.ImageFilter.blur(
    sigmaX: sigma,
    sigmaY: sigma,
    tileMode: TileMode.clamp,
  );

  /// Neutral fill for controls and fields.
  static Color tint(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF141414).withValues(alpha: 0.72)
          : Colors.white.withValues(alpha: 0.78);

  /// Fill for orange glass (cart, primary floating actions). Kept nearly
  /// opaque so white text and glyphs stay legible over any content.
  static Color accent(BuildContext context) =>
      context.palette.accent.withValues(alpha: 0.9);

  /// Hairline drawn around frosted shapes so they separate from content of a
  /// similar colour.
  static Color edge(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06);
}

/// Marks a subtree that is already drawn over a frosted backdrop, such as the
/// controls inside a scrolled [FrostedHeaderLayout]. A [FrostedSurface] inside
/// it paints only its tint: blurring an already blurred region again would cost
/// a second backdrop pass and look the same.
class FrostedScope extends InheritedWidget {
  const FrostedScope({required super.child, super.key});

  static bool isInside(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FrostedScope>() != null;

  @override
  bool updateShouldNotify(FrostedScope oldWidget) => false;
}

/// A frosted shape: blurred backdrop, [tint], hairline edge and an outer
/// shadow, clipped to [borderRadius].
///
/// With [MediaQueryData.highContrast] the surface is opaque instead.
class FrostedSurface extends StatelessWidget {
  const FrostedSurface({
    required this.child,
    this.borderRadius = AppRadii.lgAll,
    this.tint,
    this.padding = EdgeInsets.zero,
    this.shadow = true,
    this.edge = true,
    super.key,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// Fill drawn over the blur; defaults to [Frost.tint].
  final Color? tint;
  final EdgeInsetsGeometry padding;
  final bool shadow;
  final bool edge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fill = tint ?? Frost.tint(context);
    final opaque = MediaQuery.highContrastOf(context);
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: opaque ? Color.alphaBlend(fill, palette.background) : fill,
        borderRadius: borderRadius,
        border:
            edge ? Border.all(color: Frost.edge(context), width: 0.5) : null,
      ),
      child: Padding(padding: padding, child: child),
    );
    final blurred = opaque || FrostedScope.isInside(context)
        ? content
        : BackdropFilter(filter: Frost.blur, child: content);
    final clipped = ClipRRect(borderRadius: borderRadius, child: blurred);
    if (!shadow) return clipped;
    return CustomPaint(
      painter: _OuterShadowPainter(
        borderRadius: borderRadius,
        color: palette.shadow,
      ),
      child: clipped,
    );
  }
}

/// The design's control shadow (`radius 8, offset (0, 4)`), drawn only outside
/// the shape so a translucent fill is not darkened by its own shadow.
class _OuterShadowPainter extends CustomPainter {
  const _OuterShadowPainter({required this.borderRadius, required this.color});

  final BorderRadius borderRadius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || color.a == 0) return;
    final shape = borderRadius.toRRect(Offset.zero & size);
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect((Offset.zero & size).inflate(24))
      ..addRRect(shape);
    canvas
      ..save()
      ..clipPath(outside)
      ..drawRRect(
        shape.shift(const Offset(0, 4)),
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_OuterShadowPainter oldDelegate) =>
      borderRadius != oldDelegate.borderRadius || color != oldDelegate.color;
}

/// A page whose header floats over its scrolling body.
///
/// At rest the header sits on the page background exactly like a normal
/// header. As soon as the body scrolls, content passes beneath it and the
/// header area — status bar included — fades in a plain gradient from the page
/// colour to transparent, reaching a little below the header. There is no blur
/// and no line: the floating controls keep their own frosted discs (the cart
/// button's material).
///
/// [body] receives the inset its scroll view must leave at the top (status bar
/// plus header). The layout handles the top safe area itself, so the page must
/// not wrap it in a top [SafeArea].
class FrostedHeaderLayout extends StatefulWidget {
  const FrostedHeaderLayout({
    required this.header,
    required this.body,
    this.estimatedHeaderHeight = 79,
    super.key,
  });

  /// Header content below the status bar (for example an `AppTopBar` and a
  /// row of tabs).
  final Widget header;

  /// Builds the scrolling body, which must add `topInset` to its top padding.
  final Widget Function(BuildContext context, double topInset) body;

  /// Header height used for the very first frame, before it is measured.
  /// `AppTopBar` alone is 79 (22 gap + 57 bar).
  final double estimatedHeaderHeight;

  @override
  State<FrostedHeaderLayout> createState() => _FrostedHeaderLayoutState();
}

class _FrostedHeaderLayoutState extends State<FrostedHeaderLayout> {
  late double _headerHeight = widget.estimatedHeaderHeight;
  final _scrolled = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _scrolled.dispose();
    super.dispose();
  }

  void _measured(double height) {
    if ((height - _headerHeight).abs() < 0.5) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _headerHeight = height);
    });
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth == 0 && notification.metrics.axis == Axis.vertical) {
      _scrolled.value = notification.metrics.pixels >
          notification.metrics.minScrollExtent + 0.5;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final statusBar = MediaQuery.paddingOf(context).top;
    final topInset = statusBar + _headerHeight;
    return Stack(
      children: [
        Positioned.fill(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: widget.body(context, topInset),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: topInset + _HeaderFade.tail,
          child: IgnorePointer(
            child: ValueListenableBuilder<bool>(
              valueListenable: _scrolled,
              builder: (context, scrolled, _) =>
                  _HeaderFade(scrolled: scrolled, solidUntil: topInset),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: EdgeInsets.only(top: statusBar),
            child: _SizeReporter(onHeight: _measured, child: widget.header),
          ),
        ),
      ],
    );
  }
}

/// The scrolled header's scrim: the page colour, fully solid behind the status
/// bar, title and every header control (so their text never sits over
/// content), fading to transparent [tail] px below the header.
class _HeaderFade extends StatelessWidget {
  const _HeaderFade({required this.scrolled, required this.solidUntil});

  static const double tail = 36;

  final bool scrolled;
  final double solidUntil;

  @override
  Widget build(BuildContext context) {
    final base = context.palette.background;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: scrolled ? 1 : 0),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      builder: (context, t, _) => LayoutBuilder(builder: (context, box) {
        if (t == 0 || box.maxHeight <= 0) return const SizedBox.expand();
        final end = (solidUntil / box.maxHeight).clamp(0.0, 0.98);
        return DecoratedBox(
          key: const ValueKey('header-scrim'),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, end, 1],
              colors: [
                base.withValues(alpha: t),
                base.withValues(alpha: t),
                base.withValues(alpha: 0),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// Reports its child's laid-out height whenever it changes.
class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onHeight, super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onHeight);

  @override
  void updateRenderObject(
      BuildContext context, _RenderSizeReporter renderObject) {
    renderObject.onHeight = onHeight;
  }
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onHeight);

  ValueChanged<double> onHeight;
  double? _last;

  @override
  void performLayout() {
    super.performLayout();
    if (_last != size.height) {
      _last = size.height;
      onHeight(size.height);
    }
  }
}
