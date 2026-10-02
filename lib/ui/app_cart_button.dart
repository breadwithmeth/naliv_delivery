import 'package:flutter/material.dart';

import '../core/money.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'app_icon.dart';

/// The single floating cart control, without a bottom navigation bar.
///
/// The filled shape grows and wraps its readable count and price at large text
/// scales. Scrollable consumers reserve [clearanceFor] plus their device inset.
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

  static const double _pillRadius = 11;
  static const double roundSize = 78;

  static const double _gap = 5.6;
  static const double _padding = 12;

  /// Reserves space for the floating control, its bottom gap and text scaling.
  static double clearanceFor(BuildContext context) =>
      (MediaQuery.textScalerOf(context).scale(16) * 2.6 + 36)
          .clamp(roundSize, double.infinity)
          .toDouble() +
      AppSpacing.huge +
      AppSpacing.xxxl;

  bool get _filled => itemCount > 0 && total != null;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final palette = context.palette;
    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      label: _filled
          ? 'Открыть корзину, товаров: $itemCount, ${formatTenge(total!)}'
          : 'Открыть корзину',
      child: InkWell(
        onTap: onTap,
        borderRadius: _filled
            ? BorderRadius.circular(_pillRadius)
            : BorderRadius.circular(roundSize / 2),
        child: ExcludeSemantics(
          child: _filled ? _pill(context, palette) : _round(context, palette),
        ),
      ),
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
      constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
      padding: const EdgeInsets.symmetric(
          horizontal: _padding, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(_pillRadius),
      ),
      child: Wrap(
        spacing: _gap,
        runSpacing: AppSpacing.xs,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.brandRed,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$itemCount',
              style: AppTypography.labelMedium.copyWith(color: Colors.white),
            ),
          ),
          const AppIcon(AppIcons.cart, size: 22, color: Colors.white),
          Text(
            formatTenge(total!),
            style: AppTypography.body.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
