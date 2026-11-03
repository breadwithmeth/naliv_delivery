import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import 'app_icon.dart';
import 'frosted_surface.dart';

/// A round glass control with a centred glyph: back, search, like and the other
/// top-bar actions.
///
/// The disc is the design's glass: a [FrostedSurface] (`#141414` / white at
/// ≈75 % over a small backdrop blur, hairline edge, `0 4 8` shadow), so it reads
/// over a photo, a scrolled list or a plain page alike. Inside a scrolled
/// frosted header (a [FrostedScope]) it only paints its tint.
///
/// [fill] replaces the glass tint. A fully opaque [fill] has nothing to show
/// through, so the disc is drawn flat without a backdrop blur; list rows that
/// repeat a button per item use this to stay cheap. The visible disc is
/// [size] (40 by default); the touch target is never smaller than 44.
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

  /// Replaces the glass tint, for example soft red for a liked item.
  final Color? fill;
  final Color? color;
  final double? radius;
  final String? tooltip;

  /// Soft red glass for a favourite control that is on. Pair it with
  /// [AppIcons.heartFilled] and a white glyph.
  static Color likedFill(AppPalette palette) =>
      palette.brandRed.withValues(alpha: 0.75);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final discRadius = BorderRadius.circular(radius ?? AppRadii.pill);
    final solid = fill != null && fill!.a >= 0.99;
    final disc = solid
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: discRadius,
              boxShadow: AppShadows.control(palette),
            ),
          )
        : FrostedSurface(
            borderRadius: discRadius,
            tint: fill,
            child: const SizedBox.expand(),
          );
    final glyph = Center(
      child: AppIcon(
        asset,
        size: glyphSize ?? (size >= 40 ? 17 : 20),
        color: color ?? palette.textPrimary,
      ),
    );
    final button = ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: AppSpacing.touchTarget,
        minHeight: AppSpacing.touchTarget,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(width: size, height: size, child: disc),
          // Above the glass, so the ripple is visible; covers the full target.
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: discRadius,
                child: glyph,
              ),
            ),
          ),
        ],
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
