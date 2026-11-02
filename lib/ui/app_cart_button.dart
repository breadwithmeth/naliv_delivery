import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/money.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'app_icon.dart';

/// The sharp, accessible foreground of the single floating cart dock.
///
/// `LiquidGlassDock` supplies the material around the entire control. Consumers
/// reserve [clearanceFor] plus their bottom inset for the final scrolling item.
class AppCartButton extends StatelessWidget {
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

  /// The brand stamp that carries the cart glyph; the dock is exactly one stamp
  /// plus its padding tall, so its radius (36) is a full capsule.
  static const double roundSize = 56;
  static const double _minimumHeight = 72;
  static const double _lineHeight = 1.2;

  static double clearanceFor(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    // The filled state stacks "Корзина" over the total, each on one line (the total
    // scales down rather than wrapping), so the dock's height is exactly this.
    final textHeight = scaler.scale(12) * _lineHeight +
        AppSpacing.xs +
        scaler.scale(18) * _lineHeight +
        AppSpacing.md * 2;
    return math.max(_minimumHeight, textHeight) + AppSpacing.xl * 2;
  }

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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _minimumHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxxl,
                  vertical: AppSpacing.md,
                ),
                child: Center(
                  heightFactor: 1,
                  child: _filled
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _cartMark(context),
                            const SizedBox(width: AppSpacing.xl),
                            Flexible(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Корзина',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.labelMedium.copyWith(
                                      color: palette.textPrimary,
                                      height: _lineHeight,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Text(
                                      formatTenge(total!),
                                      maxLines: 1,
                                      softWrap: false,
                                      style: AppTypography.title.copyWith(
                                        color: palette.textPrimary,
                                        fontSize: 18,
                                        height: _lineHeight,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : _cartMark(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cartMark(BuildContext context) => SizedBox(
        width: roundSize,
        height: roundSize,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            const AppIcon(
              AppIcons.cartFab,
              width: roundSize,
              height: roundSize,
            ),
            const AppIcon(
              AppIcons.cart,
              size: roundSize * .5,
              color: Colors.white,
            ),
            if (itemCount > 0)
              Positioned(
                left: -AppSpacing.sm,
                top: -AppSpacing.sm,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.palette.brandRed,
                    borderRadius: AppRadii.pillAll,
                  ),
                  child: Text(
                    '$itemCount',
                    style: AppTypography.labelMedium.copyWith(
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}
