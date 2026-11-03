import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/typography.dart';
import 'app_top_bar.dart';
import 'frosted_surface.dart';

/// The floating header of a product screen.
///
/// Over the hero photo it is nothing but its [leading] and [trailing] glass
/// discs (they blur the photo behind them). Once the page has scrolled the
/// hero's bottom edge under the header, the header area, status bar included,
/// becomes the same frosted gradient as [FrostedHeaderLayout]'s and the product
/// [title] fades in between the discs, so the name stays on screen while the
/// description scrolls.
///
/// The fade follows the scroll offset of [controller] directly rather than
/// running a timer, so it reverses exactly with the finger. Place it as the
/// last child of a `Stack` over the scroll view, aligned to the top.
class ProductHeroHeader extends StatefulWidget {
  const ProductHeroHeader({
    required this.controller,
    required this.heroHeight,
    required this.title,
    required this.background,
    required this.leading,
    required this.trailing,
    super.key,
  });

  final ScrollController controller;

  /// Height of the hero at the top of the scroll content.
  final double heroHeight;
  final String title;

  /// The page colour the frosted gradient is made of.
  final Color background;
  final Widget leading;
  final Widget trailing;

  /// How far the scroll runs while the header goes from clear to frosted.
  static const double _fadeExtent = 24;

  @override
  State<ProductHeroHeader> createState() => _ProductHeroHeaderState();
}

class _ProductHeroHeaderState extends State<ProductHeroHeader> {
  final _offset = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(ProductHeroHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
      _onScroll();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    _offset.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (widget.controller.hasClients) {
      _offset.value = widget.controller.position.pixels;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final topInset = MediaQuery.paddingOf(context).top;
    final barTop = topInset + 22;
    final height = barTop + AppTopBar.height;
    // The header turns frosted once the hero ends under its lower edge.
    final start = (widget.heroHeight - height).clamp(0.0, double.infinity);
    final stepped = MediaQuery.disableAnimationsOf(context);
    final opaque = MediaQuery.highContrastOf(context);
    final controls = Padding(
      padding: EdgeInsets.only(top: barTop, left: 16, right: 16),
      child: SizedBox(
        height: AppTopBar.height,
        child: Row(children: [widget.leading, const Spacer(), widget.trailing]),
      ),
    );
    return SizedBox(
      height: height,
      child: ValueListenableBuilder<double>(
        valueListenable: _offset,
        child: controls,
        builder: (context, offset, controls) {
          var t = ((offset - start) / ProductHeroHeader._fadeExtent)
              .clamp(0.0, 1.0);
          if (stepped) t = t > 0 ? 1.0 : 0.0;
          final base = widget.background;
          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              if (t > 0)
                // Plain scrim like every page header: the page colour fading to
                // transparent below the bar. Glass stays on the discs only.
                Positioned(
                  key: const ValueKey('backdrop'),
                  top: 0,
                  left: 0,
                  right: 0,
                  height: height + 28,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0, 0.55, 1],
                          colors: opaque
                              ? [base, base, base]
                              : [
                                  base.withValues(alpha: t),
                                  base.withValues(alpha: 0.92 * t),
                                  base.withValues(alpha: 0),
                                ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (t > 0)
                Positioned(
                  key: const ValueKey('title'),
                  left: 16 + 44 + 8,
                  right: 16 + 44 + 8,
                  top: barTop,
                  height: AppTopBar.height,
                  child: ExcludeSemantics(
                    child: Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, 6 * (1 - t)),
                        child: Center(
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: AppTypography.headline
                                .copyWith(color: palette.textPrimary),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              KeyedSubtree(key: const ValueKey('controls'), child: controls!),
            ],
          );
        },
      ),
    );
  }
}
