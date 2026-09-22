import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';

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

/// Figma's GLASS material.
///
/// The REST API exposes GLASS as a bare `{type: GLASS}` with no parameters, so the blur and
/// tint here are tuned against the rendered frames rather than read from the file: the
/// design's floating chrome (bottom bar, cart button, store chip) blurs whatever scrolls
/// under it and lays [_tintStrength] of [AppPalette.glassTint] on top.
class AppGlassPanel extends StatelessWidget {
  const AppGlassPanel({
    required this.child,
    this.radius = AppRadii.lg,
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
  final double blur;
  final Color? tint;
  final double tintStrength;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final base = tint ?? palette.glassTint;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: base.withValues(alpha: base.a * tintStrength),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: child,
        ),
      ),
    );
  }
}
