import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';

/// A full-bleed frosted bottom bar with a separate sharp foreground.
///
/// The bar spans the whole width, sits flush on the bottom edge (under the
/// system inset) and rounds only its top corners. [dock] is laid out inside it
/// with [horizontalPadding] on both sides and the bottom safe-area inset plus
/// [basePadding] below, so callers only describe their own vertical rhythm.
///
/// A foreground that projects above the bar (the cart stamp) declares how far
/// with [DockOverhang]; that strip belongs to the foreground's layout box, so
/// the projecting part stays hit-testable, but the bar starts below it.
///
/// The material is the ordinary translucent bar of X or YouTube: the page runs
/// full-bleed behind it in its own repaint boundary, one [ui.ImageFilter.blur]
/// backdrop softens only the bar's rectangle, and a theme tint plus a hairline
/// top edge finish it. With [MediaQueryData.highContrast] the bar is an opaque
/// surface instead. There is no loading state: the first frame already has its
/// final geometry.
class FrostedDock extends StatefulWidget {
  const FrostedDock({
    required this.content,
    required this.dock,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(20)),
    this.tint,
    this.onDockHeightChanged,
    super.key,
  });

  final Widget content;
  final Widget? dock;
  final BorderRadius borderRadius;

  /// Overrides the translucent fill; defaults to a theme-dependent tint.
  final Color? tint;

  /// Reports the bar's height after layout, excluding the bottom safe-area
  /// inset (which the bar also covers) and any [DockOverhang]. Content that
  /// must stay clear of the bar reserves this plus the inset. Reports 0 while
  /// the foreground is empty.
  final ValueChanged<double>? onDockHeightChanged;

  /// Space between the foreground and the page's left and right edges.
  static const double horizontalPadding = AppSpacing.xxxl;

  /// Space under the foreground, on top of the bottom safe-area inset.
  static const double basePadding = AppSpacing.xs;

  @override
  State<FrostedDock> createState() => _FrostedDockState();
}

class _DockGeometry {
  double reportedHeight = 0;
}

/// Carries a foreground's declared overhang from [DockOverhang] to the layout.
class _DockScope extends InheritedWidget {
  const _DockScope({required this.overhang, required super.child});

  final ValueNotifier<double> overhang;

  @override
  bool updateShouldNotify(_DockScope oldWidget) =>
      overhang != oldWidget.overhang;
}

/// Declares that the surrounding [FrostedDock] foreground projects [extent]
/// logical pixels above the bar.
///
/// The foreground's own box includes that strip (so the projecting control is
/// hit-testable); the dock starts the bar [extent] below the top of the box.
/// Outside a [FrostedDock] this is transparent.
class DockOverhang extends StatefulWidget {
  const DockOverhang({required this.extent, required this.child, super.key});

  final double extent;
  final Widget child;

  @override
  State<DockOverhang> createState() => _DockOverhangState();
}

class _DockOverhangState extends State<DockOverhang> {
  ValueNotifier<double>? _target;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next =
        context.dependOnInheritedWidgetOfExactType<_DockScope>()?.overhang;
    if (next == _target) return;
    _target?.value = 0;
    _target = next;
    _target?.value = widget.extent;
  }

  @override
  void didUpdateWidget(covariant DockOverhang oldWidget) {
    super.didUpdateWidget(oldWidget);
    _target?.value = widget.extent;
  }

  @override
  void dispose() {
    _target?.value = 0;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

enum _DockSlot { content, backdrop, dock }

class _FrostedDockState extends State<FrostedDock> {
  final _geometry = _DockGeometry();
  final _overhang = ValueNotifier<double>(0);

  @override
  void dispose() {
    _overhang.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dock == null) return widget.content;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _DockScope(
      overhang: _overhang,
      child: CustomMultiChildLayout(
        delegate: _DockLayout(
          geometry: _geometry,
          overhang: _overhang,
          bottomInset: MediaQuery.paddingOf(context).bottom,
          onHeightChanged: _reportDockHeight,
        ),
        children: [
          LayoutId(
            id: _DockSlot.content,
            child: RepaintBoundary(
              child: ColoredBox(
                color: context.palette.background,
                child: widget.content,
              ),
            ),
          ),
          LayoutId(
            id: _DockSlot.backdrop,
            child: _FrostedBar(
              borderRadius: widget.borderRadius,
              tint: widget.tint,
              dark: dark,
              opaque: MediaQuery.highContrastOf(context),
            ),
          ),
          LayoutId(id: _DockSlot.dock, child: widget.dock!),
        ],
      ),
    );
  }

  bool _heightReportScheduled = false;
  double _pendingHeight = 0;

  void _reportDockHeight(double height) {
    _pendingHeight = height;
    if (_heightReportScheduled || widget.onDockHeightChanged == null) return;
    _heightReportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _heightReportScheduled = false;
      if (mounted) widget.onDockHeightChanged?.call(_pendingHeight);
    });
  }
}

/// The translucent bar material, sized by [_DockLayout] to exactly the bar.
class _FrostedBar extends StatelessWidget {
  const _FrostedBar({
    required this.borderRadius,
    required this.tint,
    required this.dark,
    required this.opaque,
  });

  /// Blur radius of the backdrop; strong enough that text under the bar reads
  /// as colour, cheap enough for a bar-sized region.
  static const double _sigma = 20;

  static final _blur = ui.ImageFilter.blur(
    sigmaX: _sigma,
    sigmaY: _sigma,
    tileMode: TileMode.clamp,
  );

  final BorderRadius borderRadius;
  final Color? tint;
  final bool dark;
  final bool opaque;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final edge = CustomPaint(
      painter: _TopEdgePainter(
        borderRadius: borderRadius,
        color: palette.divider.withValues(alpha: dark ? 0.5 : 0.7),
      ),
    );
    if (opaque) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: edge,
        ),
      );
    }
    final fill = tint ??
        (dark
            ? const Color(0xFF0E0E10).withValues(alpha: 0.66)
            : Colors.white.withValues(alpha: 0.76));
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: _blur,
        child: ColoredBox(color: fill, child: edge),
      ),
    );
  }
}

/// A 0.5 px outline of the bar's rounded top, cut off where the straight
/// sides begin so nothing is drawn along the screen edge or the bottom.
class _TopEdgePainter extends CustomPainter {
  const _TopEdgePainter({required this.borderRadius, required this.color});

  static const double _width = 0.5;

  final BorderRadius borderRadius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final reach = math.max(borderRadius.topLeft.y, borderRadius.topRight.y);
    final outline = (Offset.zero & size).deflate(_width / 2);
    canvas
      ..clipRect(Rect.fromLTWH(0, 0, size.width, reach + _width))
      ..drawRRect(
        borderRadius.toRRect(outline),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _width
          ..color = color,
      );
  }

  @override
  bool shouldRepaint(_TopEdgePainter oldDelegate) =>
      color != oldDelegate.color || borderRadius != oldDelegate.borderRadius;
}

class _DockLayout extends MultiChildLayoutDelegate {
  _DockLayout({
    required this.geometry,
    required this.overhang,
    required this.bottomInset,
    required this.onHeightChanged,
  }) : super(relayout: overhang);

  final _DockGeometry geometry;
  final ValueNotifier<double> overhang;
  final double bottomInset;
  final ValueChanged<double> onHeightChanged;

  @override
  void performLayout(Size size) {
    final bottomPadding = bottomInset + FrostedDock.basePadding;
    final width = math.max(0.0, size.width - FrostedDock.horizontalPadding * 2);
    final dock = layoutChild(
      _DockSlot.dock,
      BoxConstraints(
        minWidth: width,
        maxWidth: width,
        maxHeight: math.max(0.0, size.height - bottomPadding),
      ),
    );
    // An empty foreground (a hidden cart button) has no material at all.
    final present = dock.height > 0.5;
    final projecting = present ? math.min(overhang.value, dock.height) : 0.0;
    final barHeight = present ? dock.height - projecting + bottomPadding : 0.0;
    final reported = present ? barHeight - bottomInset : 0.0;
    if ((reported - geometry.reportedHeight).abs() > 0.5) {
      geometry.reportedHeight = reported;
      onHeightChanged(reported);
    }
    positionChild(
      _DockSlot.dock,
      Offset(
        FrostedDock.horizontalPadding,
        size.height - bottomPadding - dock.height,
      ),
    );
    layoutChild(
      _DockSlot.backdrop,
      BoxConstraints.tight(Size(present ? size.width : 0, barHeight)),
    );
    positionChild(_DockSlot.backdrop, Offset(0, size.height - barHeight));
    layoutChild(_DockSlot.content, BoxConstraints.tight(size));
    positionChild(_DockSlot.content, Offset.zero);
  }

  @override
  bool shouldRelayout(covariant _DockLayout oldDelegate) =>
      geometry != oldDelegate.geometry ||
      overhang != oldDelegate.overhang ||
      bottomInset != oldDelegate.bottomInset;
}
