import 'package:flutter/material.dart';

import '../core/money.dart';
import '../core/product_view.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'app_icon.dart';

/// The catalogue's product card: a 3-up grid tile, 110 × [height] at the design's 375 pt width.
///
/// Measured from `Каталог - Все товары` (full) and the horizontal strips in `Каталог` (dense):
///
/// | element | full | dense |
/// |---|---|---|
/// | card | 110 × 240 | 110 × 213 |
/// | artwork | 102 × 107, r6, inset 4 | same |
/// | badges | `-10%` on `#880514`, `+100` on `#E0AB62`, r3, 8 px glyph + 8/500 | same |
/// | title | 12/500 | 10/500 |
/// | country | 8/400 muted | — |
/// | old price | 8/400 struck | 6/400 struck |
/// | price | 16/700 | 14/700 |
/// | saving | 8/500 gold | 6/500 gold |
/// | stepper | 102 × 30, r8, accent @75 % | same |
///
/// The bottom group (prices → stepper) is anchored to the bottom edge, so cards with and
/// without a saving line keep their steppers on the same baseline — which is what the frames show.
class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.title,
    required this.price,
    this.oldPrice,
    this.saving,
    this.country,
    this.volume,
    this.imageUrl,
    this.discount,
    this.bonus,
    this.quantity = 0,
    this.dense = false,
    this.onTap,
    this.onIncrement,
    this.onDecrement,
    super.key,
  });

  final String title;
  final int price;

  /// Struck-through previous price.
  final int? oldPrice;

  /// «Выгода 1317 ₸» — omitted when the item carries no promotion.
  final int? saving;

  /// Origin of the drink, e.g. «Италия». Hidden in [dense].
  final String? country;

  /// e.g. «0,5 л», right-aligned on the title row. Hidden in [dense].
  final String? volume;

  final String? imageUrl;

  /// `-10%` badge.
  final String? discount;

  /// `+100` bonus badge.
  final String? bonus;

  /// Units in the cart; 0 shows the collapsed stepper. A double: weight items come in fractions.
  final num quantity;

  final bool dense;

  final VoidCallback? onTap;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  static const double height = 240;
  static const double denseHeight = 213;
  static const double _artworkHeight = 107;
  static const double _inset = 4;
  static const double _textInset = 4;
  static const double _stepperHeight = 30;
  static const double _badgeRadius = 3;

  double get _cardHeight => dense ? denseHeight : height;

  /// Whole units print bare; fractional (weight) amounts print two decimals — the same rule the
  /// old card used.
  String get _quantityLabel => quantity == quantity.roundToDouble()
      ? quantity.toStringAsFixed(0)
      : quantity.toStringAsFixed(2);

  /// Builds a card from the frozen item mapping ([ProductView]).
  factory ProductCard.fromView(
    ProductView view, {
    bool dense = false,
    num? quantity,
    VoidCallback? onTap,
    VoidCallback? onIncrement,
    VoidCallback? onDecrement,
    Key? key,
  }) {
    return ProductCard(
      key: key,
      title: view.title,
      country: view.country,
      volume: view.volume,
      price: view.price,
      oldPrice: view.oldPrice,
      saving: view.saving,
      discount: view.discount,
      bonus: view.bonus,
      imageUrl: view.imageUrl,
      // The cart is the live source of truth for the stepper, so callers override this.
      quantity: quantity ?? view.quantity,
      dense: dense,
      onTap: onTap,
      onIncrement: onIncrement,
      onDecrement: onDecrement,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: _cardHeight,
        child: AppSurfaceShell(
          palette: palette,
          child: Padding(
            padding: const EdgeInsets.all(_inset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _artwork(palette),
                SizedBox(height: dense ? _inset : AppSpacing.md),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _textInset),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: (dense
                                        ? AppTypography.labelMedium
                                        : AppTypography.bodySmallMedium)
                                    .copyWith(color: palette.textPrimary),
                              ),
                            ),
                            if (!dense && volume != null)
                              Text(
                                volume!,
                                style: AppTypography.caption
                                    .copyWith(color: palette.textPrimary),
                              ),
                          ],
                        ),
                        // The dense strip card drops the origin line to fit 213 px.
                        if (!dense && country != null)
                          Text(
                            country!,
                            style: AppTypography.caption
                                .copyWith(color: palette.textSecondary),
                          ),
                        const Spacer(),
                        if (oldPrice != null)
                          Text(
                            formatTenge(oldPrice!),
                            style: (dense
                                    ? AppTypography.base(size: 6)
                                    : AppTypography.caption)
                                .copyWith(
                              color: palette.textSecondary,
                              decoration: TextDecoration.lineThrough,
                              height: 1,
                            ),
                          ),
                        Text(
                          formatTenge(price),
                          style: (dense
                                  ? AppTypography.base(
                                      size: 14, weight: 700, height: 1.3)
                                  : AppTypography.title)
                              .copyWith(color: palette.textPrimary),
                        ),
                        if (saving != null)
                          Text(
                            'Выгода ${formatTenge(saving!)}',
                            style: (dense
                                    ? AppTypography.base(
                                        size: 6, weight: 500, height: 1.3)
                                    : AppTypography.captionMedium)
                                .copyWith(color: palette.gold, height: 1),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: dense ? _inset : AppSpacing.md),
                _stepper(palette),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _artwork(AppPalette palette) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: SizedBox(
        height: _artworkHeight,
        width: double.infinity,
        child: Stack(
          children: [
            // The design fills the artwork box with white artwork on white (`#FFFFFF` + image).
            Positioned.fill(
              child: imageUrl == null
                  ? const ColoredBox(color: Colors.white)
                  : Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const ColoredBox(color: Colors.white),
                    ),
            ),
            // Badges are inset 8 px from the card edge, i.e. 4 px inside the artwork box.
            Positioned(left: _inset, top: _inset, child: badges(palette)),
          ],
        ),
      ),
    );
  }

  Widget _stepper(AppPalette palette) {
    return SizedBox(
      height: _stepperHeight,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.accentSoft,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
            ),
          ),
          // Not in the cart: the design shows the same pill holding a single centred plus.
          // In the cart: minus 9 px from the left, plus 9 px from the right, count centred.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: 0,
            child: quantity <= 0
                ? GestureDetector(
                    onTap: onIncrement,
                    behavior: HitTestBehavior.opaque,
                    child: const Center(child: _PlusGlyph()),
                  )
                : Row(
                    children: [
                      const SizedBox(width: 9),
                      StepTap(
                        label: 'Убрать одну штуку',
                        onTap: onDecrement,
                        child: const _MinusGlyph(),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            _quantityLabel,
                            style: AppTypography.bodyMedium
                                .copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                      StepTap(
                        label: 'Добавить одну штуку',
                        onTap: onIncrement,
                        child: const _PlusGlyph(),
                      ),
                      const SizedBox(width: 9),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Badge row: `-10%` then `+100`, stacked, 2 px apart.
  Widget badges(AppPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (discount != null)
          _badge(palette, AppIcons.fire, discount!, palette.brandRed),
        if (discount != null && bonus != null) const SizedBox(height: 2),
        if (bonus != null)
          _badge(palette, AppIcons.bonusStar, bonus!, palette.gold),
      ],
    );
  }

  Widget _badge(AppPalette palette, String icon, String label, Color fill) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2.6),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(_badgeRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 8, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTypography.base(size: 8, weight: 500)
                .copyWith(color: Colors.white, height: 1),
          ),
        ],
      ),
    );
  }
}

/// The − glyph in the step control.
class _MinusGlyph extends StatelessWidget {
  const _MinusGlyph();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 9,
        height: 1.4,
        child: ColoredBox(color: Colors.white),
      );
}

/// The + glyph: the design draws it as an 11 × 11 union of two 9.6 px bars.
class _PlusGlyph extends StatelessWidget {
  const _PlusGlyph();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 11,
        height: 11,
        child: Stack(
          children: [
            Center(
              child: SizedBox(
                width: 9.6,
                height: 1.4,
                child: ColoredBox(color: Colors.white),
              ),
            ),
            Center(
              child: SizedBox(
                width: 1.4,
                height: 9.6,
                child: ColoredBox(color: Colors.white),
              ),
            ),
          ],
        ),
      );
}

/// The card's surface. Kept separate so [ProductCard] stays readable.
class AppSurfaceShell extends StatelessWidget {
  const AppSurfaceShell(
      {required this.child, required this.palette, super.key});

  final Widget child;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: child,
    );
  }
}

/// The 160 × 244 card used by the cart's «Вам также может понравиться» strip.
///
/// Measured from `Корзина`: artwork 152 × 159 (r6, inset 4); badges **side by side** at (8, 8)
/// rather than stacked, 46 × 17, r4, 10 px glyph + 10/500 label; title 12/500 with a stacked
/// origin block (8/400 muted over 8/400 gold) on the right; price stack (8/400 struck, 16/700,
/// 8/500 gold) bottom-left; step control 64 × 30 (r8, accent @75 %) bottom-right.
///
/// It is a separate widget rather than another flag on [ProductCard] because the layout differs
/// structurally — the badges run horizontally and the origin block stacks — and folding both into
/// one `build` would trade a readable widget for a thicket of conditionals.
class ProductCardWide extends StatelessWidget {
  const ProductCardWide({
    required this.title,
    required this.price,
    this.category,
    this.country,
    this.oldPrice,
    this.saving,
    this.imageUrl,
    this.discount,
    this.bonus,
    this.quantity = 0,
    this.onTap,
    this.onIncrement,
    this.onDecrement,
    super.key,
  });

  final String title;
  final int price;
  final String? category;
  final String? country;
  final int? oldPrice;
  final int? saving;
  final String? imageUrl;
  final String? discount;
  final String? bonus;
  final num quantity;
  final VoidCallback? onTap;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  static const double width = 160;
  static const double height = 244;
  static const double _artworkHeight = 159;
  static const double _stepperWidth = 64;
  static const double _stepperHeight = 30;

  factory ProductCardWide.fromView(
    ProductView view, {
    num? quantity,
    VoidCallback? onTap,
    VoidCallback? onIncrement,
    VoidCallback? onDecrement,
    Key? key,
  }) {
    return ProductCardWide(
      key: key,
      title: view.title,
      price: view.price,
      category: view.category,
      country: view.country,
      oldPrice: view.oldPrice,
      saving: view.saving,
      imageUrl: view.imageUrl,
      discount: view.discount,
      bonus: view.bonus,
      quantity: quantity ?? view.quantity,
      onTap: onTap,
      onIncrement: onIncrement,
      onDecrement: onDecrement,
    );
  }

  String get _quantityLabel => quantity == quantity.roundToDouble()
      ? quantity.toStringAsFixed(0)
      : quantity.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: SizedBox(
                    height: _artworkHeight,
                    width: double.infinity,
                    child: imageUrl == null
                        ? const ColoredBox(color: Colors.white)
                        : Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const ColoredBox(color: Colors.white),
                          ),
                  ),
                ),
                Positioned(
                  left: AppSpacing.xs,
                  top: AppSpacing.xs,
                  child: Row(
                    children: [
                      if (discount != null)
                        _badge(palette, AppIcons.fire, discount!,
                            palette.brandRed),
                      if (discount != null && bonus != null)
                        const SizedBox(width: AppSpacing.huge),
                      if (bonus != null)
                        _badge(
                            palette, AppIcons.bonusStar, bonus!, palette.gold),
                    ],
                  ),
                ),
                Positioned(
                  left: AppSpacing.xs,
                  top: 167,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmallMedium
                        .copyWith(color: palette.textPrimary),
                  ),
                ),
                if (category != null || country != null)
                  Positioned(
                    right: AppSpacing.xs,
                    top: 167,
                    width: 60,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (category != null)
                          Text(
                            category!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                                color: palette.textSecondary, height: 1),
                          ),
                        if (country != null)
                          Text(
                            country!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption
                                .copyWith(color: palette.gold, height: 1),
                          ),
                      ],
                    ),
                  ),
                Positioned(
                  left: AppSpacing.xs,
                  bottom: AppSpacing.md,
                  right: _stepperWidth + AppSpacing.md,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (oldPrice != null)
                        Text(
                          formatTenge(oldPrice!),
                          style: AppTypography.caption.copyWith(
                            color: palette.textSecondary,
                            decoration: TextDecoration.lineThrough,
                            height: 1,
                          ),
                        ),
                      Text(
                        formatTenge(price),
                        style: AppTypography.title
                            .copyWith(color: palette.textPrimary, height: 1.3),
                      ),
                      if (saving != null)
                        Text(
                          'Выгода ${formatTenge(saving!)}',
                          style: AppTypography.captionMedium
                              .copyWith(color: palette.gold, height: 1),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  right: AppSpacing.xs,
                  bottom: AppSpacing.xs + 4,
                  child: SizedBox(
                    width: _stepperWidth,
                    height: _stepperHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: palette.accentSoft,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: quantity <= 0
                          ? GestureDetector(
                              onTap: onIncrement,
                              behavior: HitTestBehavior.opaque,
                              child: const Center(child: _PlusGlyph()),
                            )
                          : Row(
                              children: [
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: onDecrement,
                                  behavior: HitTestBehavior.opaque,
                                  child: const SizedBox(
                                    width: 12,
                                    height: _stepperHeight,
                                    child: Center(child: _MinusGlyph()),
                                  ),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      _quantityLabel,
                                      style: AppTypography.bodyMedium
                                          .copyWith(color: Colors.white),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: onIncrement,
                                  behavior: HitTestBehavior.opaque,
                                  child: const SizedBox(
                                    width: 14,
                                    height: _stepperHeight,
                                    child: Center(child: _PlusGlyph()),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(AppPalette palette, String icon, String label, Color fill) {
    return Container(
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 10, color: Colors.white),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.base(size: 10, weight: 500)
                .copyWith(color: Colors.white, height: 1),
          ),
        ],
      ),
    );
  }
}

/// Step-control button that carries an accessibility label.
///
/// A screen reader otherwise announces the bare glyphs of the −/+ controls. The tap area stays
/// at the design's size: the frames' whole control is only 30 dp tall and 102 dp wide, so
/// widening the targets to 44 dp would have to distort the layout — that is a design decision,
/// not something to fix silently here.
class StepTap extends StatelessWidget {
  const StepTap({
    required this.label,
    required this.child,
    this.onTap,
    this.width = 12,
    super.key,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: width,
          height: 30,
          child: Center(child: child),
        ),
      ),
    );
  }
}
