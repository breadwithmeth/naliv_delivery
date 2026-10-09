import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import 'app_icon.dart';

/// The design's icon button: a glass disc with a centred glyph.
///
/// Two recipes exist in the file and both are here:
/// * **top-bar actions** — 40 × 40, fully round, `#141414 @ 75 %`, glyph 17 px
///   (`Каталог - Все товары`, both `Menu` nodes);
/// * **inline actions** — 32 × 32, round or radius 8, glyph 20 px, fill chosen by the caller
///   (the favourite heart at `#880514 @ 50 %`, the address card's shop chip at accent @ 75 %).
///
/// Every one of them carries Figma's GLASS material, so the disc blurs whatever shows
/// through it. Repeated rows pass `blur: 0` instead of paying for a save layer per item.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.asset,
    this.onTap,
    this.size = 40,
    this.glyphSize,
    this.fill,
    this.color,
    this.radius,
    this.blur = 18,
    this.tooltip,
    super.key,
  });

  final String asset;
  final VoidCallback? onTap;
  final double size;
  final double? glyphSize;
  final Color? fill;
  final Color? color;
  final double? radius;

  /// Backdrop blur of the design's GLASS; 0 disables the save layer.
  final double blur;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final discRadius = radius ?? AppRadii.pill;
    final fillColor = fill ?? palette.surface.withValues(alpha: 0.75);
    final glyph = Center(
      child: AppIcon(
        asset,
        size: glyphSize ?? (size >= 40 ? 17 : 20),
        color: color ?? palette.textPrimary,
      ),
    );
    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(discRadius),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(discRadius),
          boxShadow: AppShadows.control(palette),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(discRadius),
          child: blur > 0
              ? BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: BorderRadius.circular(discRadius),
                    ),
                    child: glyph,
                  ),
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: BorderRadius.circular(discRadius),
                  ),
                  child: glyph,
                ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
