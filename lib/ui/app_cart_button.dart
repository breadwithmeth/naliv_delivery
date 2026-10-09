import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/money.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'app_icon.dart';
import 'surfaces.dart';

/// The single floating cart control, without a bottom navigation bar.
///
/// A shared full-width glass layer carries the starburst and, for a non-empty
/// cart, its count and total. Consumers reserve [clearanceFor] plus their inset.
class AppCartButton extends StatelessWidget {
  const AppCartButton({
    required this.itemCount,
    this.total,
    this.onTap,
    this.visible = true,
    super.key,
  });

  final int itemCount;

  /// Order total; null hides the amount and falls back to the round shape.
  final num? total;
  final VoidCallback? onTap;
  final bool visible;

  /// The design's starburst badge.
  static const double roundSize = 78;

  /// The pill's left edge, measured from the badge's left edge in the frames' `Union`.
  static const double _pillInset = 47;
  static const double _pillRadius = AppRadii.pill;
  static const double _pillHeight = 34;
  static const double _badgeSize = 32;

  /// Figma's GLASS blur; the design never draws these shapes without it.
  static const double _blur = 18;

  /// Reserves space for the floating control, its bottom gap and text scaling.
  static double clearanceFor(BuildContext context) =>
      (MediaQuery.textScalerOf(context).scale(16) * 2.6 + 36)
          .clamp(roundSize + 26, double.infinity)
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
        borderRadius:
            BorderRadius.circular(_filled ? _pillRadius : roundSize / 2),
        child: ExcludeSemantics(
          child: SizedBox(
            width: math.max(0, MediaQuery.sizeOf(context).width - 32),
            height: roundSize + 26,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AppGlassPanel(
                    radius: 24,
                    height: 66,
                    child: SizedBox.shrink(),
                  ),
                ),
                _filled ? _filledBody(context, palette) : _round(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _round() => const SizedBox(
        width: roundSize,
        height: roundSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AppIcon(
              AppIcons.cartFab,
              width: roundSize,
              height: roundSize,
            ),
            AppIcon(AppIcons.cart, size: 39.3, color: Colors.white),
          ],
        ),
      );

  Widget _filledBody(BuildContext context, AppPalette palette) {
    final scaler = MediaQuery.textScalerOf(context);
    final priceStyle = AppTypography.title.copyWith(color: Colors.white);
    // Bounded by the screen gutters: a long total shrinks instead of widening the control.
    // The design's own pill width is the floor, so the bounds stay ordered on tiny windows.
    final pillMax = math.max(
      125.0,
      MediaQuery.sizeOf(context).width - AppSpacing.xxxl * 2 - _pillInset,
    );
    final pillHeight = (scaler.scale(16) * 1.3 + AppSpacing.xxl)
        .clamp(_pillHeight, roundSize)
        .toDouble();
    final badgeSize =
        scaler.scale(20).clamp(_badgeSize, AppSpacing.touchTarget).toDouble();
    return SizedBox(
      height: roundSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The badge covers this much of the pill, exactly as the design's `Union` does.
              const SizedBox(width: _pillInset),
              ConstrainedBox(
                constraints: BoxConstraints(minWidth: 125, maxWidth: pillMax),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_pillRadius),
                    boxShadow: AppShadows.control(palette),
                  ),
                  child: AppGlassPanel(
                    radius: _pillRadius,
                    tint: palette.accentSoft,
                    blur: _blur,
                    height: pillHeight,
                    padding: const EdgeInsets.only(
                      left: roundSize - _pillInset + AppSpacing.md,
                      right: AppSpacing.md,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatTenge(total!),
                        maxLines: 1,
                        style: priceStyle,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          _round(),
          Positioned(
            left: 0,
            top: 0,
            child: SizedBox(
              width: badgeSize,
              height: badgeSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.brandRed,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Text(
                        '$itemCount',
                        maxLines: 1,
                        style: AppTypography.labelMedium.copyWith(
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
