import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/money.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'app_icon.dart';
import 'liquid_glass_dock.dart';

/// The sharp, accessible foreground of the single floating cart dock.
///
/// `LiquidGlassDock` supplies the full-bleed frosted bar this sits in.
/// An empty cart shows a compact brand stamp that rises [stampOverhang] above
/// the bar. Once the cart has items the stamp becomes one orange capsule with
/// the item count and the total, so the destination and its value read as a
/// single action. Consumers reserve [clearanceFor] plus their bottom inset for
/// the final scrolling item.
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

  /// Diameter of the empty-cart brand stamp.
  static const double stampSize = 60;

  /// How far the empty-cart stamp rises above the bar's top edge.
  static const double stampOverhang = 12;

  /// Minimum height of the filled capsule.
  static const double capsuleHeight = 52;

  static const double _topPadding = AppSpacing.md;

  static double _capsuleHeight(BuildContext context) => math.max(
      capsuleHeight, MediaQuery.textScalerOf(context).scale(17) * 1.25 + 20);

  static double _barHeight(BuildContext context) =>
      _topPadding +
      math.max(stampSize - stampOverhang, _capsuleHeight(context));

  /// The space the dock occupies above the bottom safe-area inset, plus a
  /// gutter: the stamp's rise, the bar and the dock's base padding.
  static double clearanceFor(BuildContext context) =>
      stampOverhang +
      _barHeight(context) +
      LiquidGlassDock.basePadding +
      AppSpacing.xl;

  bool get _filled => itemCount > 0 && total != null;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final overhang = _filled ? 0.0 : stampOverhang;
    return DockOverhang(
      extent: overhang,
      child: Semantics(
        container: true,
        button: true,
        enabled: onTap != null,
        label: _filled
            ? 'Открыть корзину, товаров: $itemCount, ${formatTenge(total!)}'
            : 'Открыть корзину',
        child: ExcludeSemantics(
          child: SizedBox(
            height: overhang + _barHeight(context),
            child: Padding(
              padding: EdgeInsets.only(top: _filled ? _topPadding : 0),
              child: Align(
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween(begin: .92, end: 1.0).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _filled
                      ? _capsule(context, key: const ValueKey('filled'))
                      : _stamp(context, key: const ValueKey('empty')),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stamp(BuildContext context, {Key? key}) => Material(
        key: key,
        type: MaterialType.transparency,
        child: InkResponse(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const SizedBox.square(
            dimension: stampSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AppIcon(AppIcons.cartFab, width: stampSize, height: stampSize),
                AppIcon(AppIcons.cart, size: 26, color: Colors.white),
              ],
            ),
          ),
        ),
      );

  Widget _capsule(BuildContext context, {Key? key}) {
    final palette = context.palette;
    final count = itemCount > 99 ? '99+' : '$itemCount';
    return ConstrainedBox(
      key: key,
      constraints: BoxConstraints(
        minWidth: 200,
        minHeight: _capsuleHeight(context),
      ),
      child: Material(
        color: palette.accent,
        shape: const StadiumBorder(),
        elevation: 0,
        shadowColor: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 22, 6),
            child: LayoutBuilder(builder: (context, constraints) {
              final labelStyle = AppTypography.base(size: 15, weight: 500)
                  .copyWith(color: Colors.white.withValues(alpha: .9));
              final totalStyle = AppTypography.base(size: 17, weight: 700)
                  .copyWith(color: Colors.white);
              final scaler = MediaQuery.textScalerOf(context);
              double widthOf(String text, TextStyle style) {
                final painter = TextPainter(
                  text: TextSpan(text: text, style: style),
                  textDirection: Directionality.of(context),
                  textScaler: scaler,
                  maxLines: 1,
                )..layout();
                final width = painter.width;
                painter.dispose();
                return width;
              }

              // Icon, gap, label, divider and total; the label goes first
              // when the bar is too narrow, so the total stays readable.
              final showLabel = 36 +
                      AppSpacing.md +
                      widthOf('Корзина', labelStyle) +
                      21 +
                      widthOf(formatTenge(total!), totalStyle) <=
                  constraints.maxWidth;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 36,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        const AppIcon(AppIcons.cart,
                            size: 24, color: Colors.white),
                        Positioned(
                          right: -4,
                          top: -2,
                          child: Container(
                            constraints: const BoxConstraints(
                                minWidth: 18, minHeight: 18),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: AppRadii.pillAll,
                            ),
                            child: Text(
                              count,
                              style: AppTypography.base(size: 11, weight: 700)
                                  .copyWith(color: palette.accent, height: 1.2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  if (showLabel) ...[
                    Text('Корзина', maxLines: 1, style: labelStyle),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Container(
                        width: 1,
                        height: 18,
                        color: Colors.white.withValues(alpha: .45),
                      ),
                    ),
                  ],
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatTenge(total!),
                        maxLines: 1,
                        softWrap: false,
                        style: totalStyle,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}
