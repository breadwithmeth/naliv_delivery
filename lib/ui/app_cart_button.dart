import 'package:flutter/material.dart';

import '../core/money.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'app_icon.dart';

/// The single floating cart control. Two shapes, both measured from the design:
///
/// * empty cart — the 78 px scalloped button from `Главная`, cart glyph only;
/// * filled cart — the 133.2 × 42 pill from `Поиск - Удачный поиск`: item-count badge,
///   cart glyph, then the order total (`92 190 ₸`, 14/400).
///
/// There is deliberately no bottom bar behind it: the product has no tab bar, and the design's
/// own search frames show the pill floating on its own.
class AppCartButton extends StatelessWidget {
  const AppCartButton({
    required this.itemCount,
    this.total,
    this.onTap,
    this.visible = true,
    super.key,
  });

  final int itemCount;

  /// Order total in whole tenge; null hides the amount and falls back to the round shape.
  final int? total;
  final VoidCallback? onTap;
  final bool visible;

  static const double pillHeight = 42;
  static const double _pillRadius = 11;
  static const double roundSize = 78;

  static const double _badge = 18;
  static const double _gap = 5.6;
  static const double _padding = 12;

  /// Height to reserve at the bottom of a scrollable so content clears the button.
  static const double clearance = pillHeight + 34;

  bool get _filled => itemCount > 0 && total != null;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: _filled ? _pill(context, palette) : _round(context, palette),
    );
  }

  Widget _round(BuildContext context, AppPalette palette) {
    return SizedBox(
      width: roundSize,
      height: roundSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The exported SVG carries a drop-shadow filter that flutter_svg ignores, so the
          // design's shadow is applied here instead.
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: AppShadows.control(palette),
            ),
            child: const SizedBox(width: roundSize, height: roundSize),
          ),
          const AppIcon(AppIcons.cartFab, width: roundSize, height: roundSize),
          const AppIcon(AppIcons.cart, size: 39.3, color: Colors.white),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, AppPalette palette) {
    return Container(
      height: pillHeight,
      padding: const EdgeInsets.symmetric(horizontal: _padding),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(_pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _badge,
            height: _badge,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.brandRed,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$itemCount',
              style: AppTypography.base(size: 9, weight: 500).copyWith(
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: _gap),
          const AppIcon(AppIcons.cart, size: 22, color: Colors.white),
          const SizedBox(width: _gap),
          Text(
            formatTenge(total!),
            style: AppTypography.body.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
