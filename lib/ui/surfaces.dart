import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'app_icon.dart';

/// A rounded container in the design's material vocabulary: one of `background`, `surface`
/// or a translucent variant, with an explicit radius and no border unless asked.
///
/// The design puts almost everything on `surface` (dark `#141414` / light `#F2F2F2`) with
/// radius 10, and uses translucent fills (`#141414 @ 75%`) for chrome that sits over content.
class AppSurface extends StatelessWidget {
  const AppSurface({
    required this.child,
    this.fill,
    this.radius = AppRadii.lg,
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
    final decoration = BoxDecoration(
      color: fill ?? palette.surface,
      borderRadius: BorderRadius.circular(radius),
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
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}

/// Floating glass that reveals the actual content behind the surface.
class AppGlassPanel extends StatelessWidget {
  const AppGlassPanel({
    required this.child,
    this.radius = AppRadii.lg,
    this.borderRadius,
    this.blur = 18,
    this.tint,
    this.tintStrength = 1,
    this.padding,
    this.width,
    this.height,
    super.key,
  });

  final Widget child;
  final double radius;
  final BorderRadiusGeometry? borderRadius;
  final double blur;
  final Color? tint;
  final double tintStrength;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shape = borderRadius ?? BorderRadius.circular(radius);
    final base = tint ??
        palette.glassTint.withValues(alpha: isDark ? .12 : .52);
    final opacity = (base.a * tintStrength).clamp(0.0, 1.0).toDouble();
    final surface = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              Colors.white.withValues(alpha: isDark ? .06 : .18),
              base.withValues(alpha: opacity),
            ),
            base.withValues(alpha: opacity),
          ],
        ),
        borderRadius: shape,
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? .18 : .65),
          width: .8,
        ),
      ),
      child: child,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(alpha: isDark ? .14 : .08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: blur <= 0
            ? surface
            : BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: surface,
              ),
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
    super.key,
  });

  final String icon;
  final String label;
  final Color fill;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(color: fill, borderRadius: AppRadii.xsAll),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(icon, size: 12, color: foreground),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelMedium.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      );
}

/// A glass section action with a label and an accessible tap target.
class AppGlassChip extends StatelessWidget {
  const AppGlassChip({required this.label, this.onTap, super.key});

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
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.pillAll,
        child: SizedBox(
          height: pillHeight < AppSpacing.touchTarget
              ? AppSpacing.touchTarget
              : pillHeight,
          child: Center(
            child: AppGlassPanel(
              radius: AppRadii.pill,
              tint: onTap == null ? palette.surfaceMuted : palette.accentSoft,
              blur: 18,
              height: pillHeight,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Center(
                child: Text(
                  label,
                  style: AppTypography.labelMedium.copyWith(
                    color: onTap == null ? palette.textPrimary : Colors.black,
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
