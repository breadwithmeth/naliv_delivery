import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'app_icon.dart';

/// A rounded ordinary surface with an optional fill, border, shadow and clipping.
class AppSurface extends StatelessWidget {
  const AppSurface({
    required this.child,
    this.fill,
    this.radius = AppRadii.lg,
    this.borderRadius,
    this.padding,
    this.width,
    this.height,
    this.border,
    this.shadow,
    this.clip = false,
    this.onTap,
    super.key,
  });

  final Widget child;
  final Color? fill;
  final double radius;
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final BoxBorder? border;
  final List<BoxShadow>? shadow;
  final bool clip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final shape = borderRadius ?? BorderRadius.circular(radius);
    final decoration = BoxDecoration(
      color: fill ?? palette.surface,
      borderRadius: shape,
      border: border,
      boxShadow: shadow,
    );
    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: decoration,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: shape.resolve(Directionality.of(context)),
        child: content,
      ),
    );
  }
}

/// The promotion chip shared by cards, rows and the item page: an icon plus a short label
/// (`-10%`, `2+1`, `+100`) on a 4 px-radius fill, 12 px from the reference.
///
/// Cards place at most two of these on the artwork; the item page and cart rows use the same
/// recipe so a promotion is recognisable wherever it appears.
class AppPromoChip extends StatelessWidget {
  const AppPromoChip({
    required this.icon,
    required this.label,
    required this.fill,
    this.foreground = Colors.white,
    this.compact = false,
    super.key,
  });

  final String icon;
  final String label;
  final Color fill;
  final Color foreground;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 3 : AppSpacing.sm,
            vertical: compact ? 1 : AppSpacing.xs),
        decoration: BoxDecoration(color: fill, borderRadius: AppRadii.xsAll),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(icon, size: compact ? 9 : 12, color: foreground),
            SizedBox(width: compact ? 2 : AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelMedium
                    .copyWith(color: foreground, fontSize: compact ? 10 : null),
              ),
            ),
          ],
        ),
      );
}

/// An ordinary filled section action with a label and an accessible tap target.
class AppSectionAction extends StatelessWidget {
  const AppSectionAction({required this.label, this.onTap, super.key});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final labelHeight = MediaQuery.textScalerOf(context).scale(12) * 1.2;
    final pillHeight = labelHeight + 12 < 28 ? 28.0 : labelHeight + 12;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: AppSpacing.touchTarget),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.pillAll,
          child: SizedBox(
            height: pillHeight < AppSpacing.touchTarget
                ? AppSpacing.touchTarget
                : pillHeight,
            child: Center(
              child: AppSurface(
                radius: AppRadii.pill,
                fill: onTap == null
                    ? palette.surfaceMuted
                    : Color.alphaBlend(palette.accentSoft, palette.surface),
                height: pillHeight,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Center(
                  child: Text(
                    label,
                    style: AppTypography.labelMedium.copyWith(
                      color: onTap == null
                          ? palette.textSecondary
                          : palette.textOnAccent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
