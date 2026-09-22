import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import 'app_icon.dart';

/// The design's icon button: a translucent glass disc with a centred glyph.
///
/// Two recipes exist in the file and both are here:
/// * **top-bar actions** — 40 × 40, fully round, `#141414 @ 75 %`, glyph 17 px
///   (`Каталог - Все товары`, both `Menu` nodes);
/// * **inline actions** — 32 × 32, round or radius 8, glyph 20 px, fill chosen by the caller
///   (the favourite heart at `#880514 @ 50 %`, the address card's shop chip at accent @ 75 %).
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.asset,
    this.onTap,
    this.size = 40,
    this.glyphSize,
    this.fill,
    this.radius,
    this.tooltip,
    super.key,
  });

  final String asset;
  final VoidCallback? onTap;
  final double size;
  final double? glyphSize;
  final Color? fill;
  final double? radius;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final button = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: fill ?? palette.surface.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(radius ?? AppRadii.pill),
          boxShadow: AppShadows.control(palette),
        ),
        child: Center(
          child: AppIcon(asset, size: glyphSize ?? (size >= 40 ? 17 : 20)),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
