import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/money.dart';
import '../design/motion.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'app_icon.dart';
import 'frosted_dock.dart';
import 'motion_widgets.dart';

/// The sharp, accessible foreground of the single floating cart dock.
///
/// `FrostedDock` supplies the full-bleed frosted bar this sits in. The control
/// is always the scalloped brand stamp, [stampSize] across, rising
/// [stampOverhang] above the bar. When the cart has items an orange glass pill
/// grows out from behind the stamp to its right and carries the total, and a
/// red count badge sits on the stamp's top-left shoulder; the stamp and pill
/// together stay centred on the screen, so the stamp slides aside as the pill
/// opens. Consumers reserve [clearanceFor] plus their bottom inset for the final
/// scrolling item.
class AppCartButton extends StatefulWidget {
  const AppCartButton({
    required this.itemCount,
    this.total,
    this.onTap,
    this.visible = true,
    super.key,
  });

  final int itemCount;
  final num? total;
  final VoidCallback? onTap;
  final bool visible;

  /// Diameter of the brand stamp.
  static const double stampSize = 78;

  /// How far the stamp rises above the bar's top edge.
  static const double stampOverhang = 27;

  /// Height of the total's pill at the design's text size; it grows with the
  /// user's text scale.
  static const double pillHeight = 34;

  /// Diameter of the count badge.
  static const double badgeSize = 32;

  /// Where the pill's left end starts, measured from the stamp's left edge: it
  /// begins behind the stamp's middle and emerges from its right side.
  static const double _pillStart = 47;

  /// The pill is centred a little below the stamp's centre, as in the design.
  static const double _pillDrop = 2;

  static const double _totalSize = 20;
  static const double _totalHeight = 1.3;

  static double _pillHeightFor(BuildContext context) => math.max(
        pillHeight,
        MediaQuery.textScalerOf(context).scale(_totalSize) * _totalHeight + 8,
      );

  /// Distance from the control's top to the pill's centre line.
  static double _pillCentre(BuildContext context) => math.max(
        stampSize / 2 + _pillDrop,
        _pillHeightFor(context) / 2,
      );

  /// Height of the control's box: the stamp, or the pill when large text makes
  /// it taller than the stamp's lower half.
  static double _boxHeight(BuildContext context) => math.max(
        stampSize,
        _pillCentre(context) + _pillHeightFor(context) / 2,
      );

  /// The space the dock occupies above the bottom safe-area inset, plus a
  /// gutter: the control's box (stamp rise included), the dock's base padding
  /// and the scroll gutter.
  static double clearanceFor(BuildContext context) =>
      _boxHeight(context) +
      FrostedDock.basePadding +
      AppSpacing.xl;

  bool get _filled => itemCount > 0 && total != null;

  @override
  State<AppCartButton> createState() => _AppCartButtonState();
}

class _AppCartButtonState extends State<AppCartButton>
    with SingleTickerProviderStateMixin {
  /// 0 while the cart is empty (stamp only), 1 with the pill fully open.
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: AppMotion.slide,
    value: widget._filled ? 1 : 0,
  );
  late final Animation<double> _open = CurvedAnimation(
    parent: _reveal,
    curve: AppMotion.out,
    reverseCurve: AppMotion.leave,
  );

  // What the pill shows. It keeps the last filled values while it closes, so
  // the total never flashes "0" on its way out.
  int _count = 0;
  num _total = 0;

  @override
  void initState() {
    super.initState();
    _remember();
  }

  @override
  void didUpdateWidget(AppCartButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _remember();
    final filled = widget._filled;
    if (filled == oldWidget._filled) return;
    if (AppMotion.reduced(context)) {
      _reveal.value = filled ? 1 : 0;
    } else if (filled) {
      _reveal.forward();
    } else {
      _reveal.reverse();
    }
  }

  void _remember() {
    if (!widget._filled) return;
    _count = widget.itemCount;
    _total = widget.total!;
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    final box = AppCartButton._boxHeight(context);
    return DockOverhang(
      extent: AppCartButton.stampOverhang,
      child: Semantics(
        container: true,
        button: true,
        enabled: widget.onTap != null,
        onTap: widget.onTap,
        label: widget._filled
            ? 'Открыть корзину, товаров: ${widget.itemCount}, '
                '${formatTenge(widget.total!)}'
            : 'Открыть корзину',
        child: ExcludeSemantics(
          child: SizedBox(
            height: box,
            child: Center(
              child: PressScale(
                enabled: widget.onTap != null,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTap,
                  child: AnimatedBuilder(
                    animation: _open,
                    builder: (context, _) => _group(context, _open.value, box),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Pill, total, stamp and badge, stacked back to front. The row of stamp slot
  /// plus visible total gives the group its width, so it stays centred as the
  /// pill opens.
  Widget _group(BuildContext context, double open, double box) {
    final pillHeight = AppCartButton._pillHeightFor(context);
    final centre = AppCartButton._pillCentre(context);
    final palette = context.palette;
    final shadow = AppShadows.control(palette);
    final pillFade = const Interval(0, .4).transform(open);
    final badgeScale =
        const Interval(.35, 1, curve: AppMotion.overshoot).transform(open);
    return SizedBox(
      height: box,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Paint the stamp's shadow behind both fills, never across the join.
          Positioned(
            left: 0,
            top: 0,
            width: AppCartButton.stampSize,
            height: AppCartButton.stampSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: shadow,
              ),
            ),
          ),
          if (open > 0)
            Positioned(
              key: const ValueKey('cart-pill'),
              left: AppCartButton._pillStart,
              right: 0,
              top: centre - pillHeight / 2,
              height: pillHeight,
              child: Opacity(
                opacity: pillFade,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.accent,
                    borderRadius: AppRadii.pillAll,
                    boxShadow: shadow,
                  ),
                ),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: AppCartButton.stampSize),
              if (open > 0)
                Flexible(
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment(-1, centre / box * 2 - 1),
                      widthFactor: open,
                      child: Opacity(
                        opacity: const Interval(.25, 1).transform(open),
                        child: _totalLabel(context),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const Positioned(
            key: ValueKey('cart-stamp'),
            left: 0,
            top: 0,
            child: _Stamp(),
          ),
          if (open > 0 && badgeScale > 0)
            Positioned(
              key: const ValueKey('cart-badge'),
              left: -4,
              top: -2,
              child: Transform.scale(
                scale: badgeScale,
                child: _badge(context),
              ),
            ),
        ],
      ),
    );
  }

  /// The total, hugging its content. Only when the dock is too narrow for it
  /// (large totals at large text sizes) does it scale down.
  Widget _totalLabel(BuildContext context) {
    return AnimatedSize(
      duration: AppMotion.of(context, AppMotion.count),
      curve: AppMotion.out,
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 2, right: AppSpacing.xxl),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: AnimatedCount(
            text: formatTenge(_total),
            value: _total,
            maxLines: 1,
            softWrap: false,
            style: AppTypography.base(
              size: AppCartButton._totalSize,
              weight: 600,
              height: AppCartButton._totalHeight,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(BuildContext context) {
    final count = _count > 99 ? '99+' : '$_count';
    return Bump<int>(
      value: _count,
      shouldBump: (previous, next) => next > previous,
      child: Container(
        constraints: const BoxConstraints(
          minWidth: AppCartButton.badgeSize,
          minHeight: AppCartButton.badgeSize,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.palette.brandRed,
          borderRadius: AppRadii.pillAll,
        ),
        child: Text(
          count,
          maxLines: 1,
          softWrap: false,
          style: AppTypography.base(
            size: 16,
            weight: 500,
            height: 1.1,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// The scalloped brand stamp with its white cart glyph.
class _Stamp extends StatelessWidget {
  const _Stamp();

  @override
  Widget build(BuildContext context) {
    const size = AppCartButton.stampSize;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AppIcon(
              AppIcons.cartFab,
              size: size,
              color: context.palette.accent,
            ),
            const AppIcon(
              AppIcons.cart,
              width: 37,
              height: 38,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
