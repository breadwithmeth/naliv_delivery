import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import 'app_icon.dart';

/// An ordinary filled icon disc with a centred glyph.
///
/// Top-bar actions default to 40 × 40 with a 17 px glyph. Inline actions can
/// override the size, fill and radius without adding an optical effect.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.asset,
    this.onTap,
    this.size = 40,
    this.glyphSize,
    this.fill,
    this.color,
    this.radius,
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
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final discRadius = radius ?? AppRadii.pill;
    final fillColor = fill ?? palette.surface;
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
          color: fillColor,
          borderRadius: BorderRadius.circular(discRadius),
          boxShadow: AppShadows.control(palette),
        ),
        clipBehavior: Clip.antiAlias,
        child: glyph,
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
