import 'package:flutter/material.dart';

import '../core/money.dart';
import '../core/product_view.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'app_icon.dart';

/// The catalogue's wide product row — 343 × 114, used by search results and favourites.
///
/// Measured from `Поиск - Удачный поиск` (first result):
///
/// * artwork 140 × 106, r6, inset 4 on the **right**;
/// * left block (8 … 191): category 10/400 muted and origin 10/400 gold on the first line,
///   title 16/500 beneath it, then the price stack — struck 10/400, price 20/700,
///   «Выгода» 10/500 gold — bottom-left;
/// * like chip 32 × 32 r100 at the artwork's top-right corner (8 from the row's right edge);
/// * step control 76 × 30 r8, accent @75 %, at the bottom of the left block.
///
/// Rows are built with explicit offsets rather than a flow layout: the frame places these
/// elements independently, and a flow layout would drift on long titles.
class ProductRow extends StatelessWidget {
  const ProductRow({
    super.key,
    required this.title,
    required this.price,
    this.category,
    this.country,
    this.oldPrice,
    this.saving,
    this.imageUrl,
    this.quantity = 0,
    this.liked = false,
    this.onTap,
    this.onLike,
    this.onIncrement,
    this.onDecrement,
  });

  final String title;
  final int price;

  /// Grouping label above the title, e.g. «Аперитив».
  final String? category;
  final String? country;
  final int? oldPrice;
  final int? saving;
  final String? imageUrl;
  final num quantity;
  final bool liked;

  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  static const double height = 114;
  static const double _artworkWidth = 140;
  static const double _artworkHeight = 106;
  static const double _leftBlock = 183; // 8 … 191
  static const double _stepperWidth = 76;
  static const double _stepperHeight = 30;

  factory ProductRow.fromView(
    ProductView view, {
    bool liked = false,
    num? quantity,
    VoidCallback? onTap,
    VoidCallback? onLike,
    VoidCallback? onIncrement,
    VoidCallback? onDecrement,
    Key? key,
  }) {
    return ProductRow(
      key: key,
      title: view.title,
      price: view.price,
      category: view.category,
      country: view.country,
      oldPrice: view.oldPrice,
      saving: view.saving,
      imageUrl: view.imageUrl,
      quantity: quantity ?? view.quantity,
      liked: liked,
      onTap: onTap,
      onLike: onLike,
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
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Stack(
            children: [
              Positioned(
                right: AppSpacing.xs,
                top: AppSpacing.xs,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: SizedBox(
                    width: _artworkWidth,
                    height: _artworkHeight,
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
              ),
              Positioned(
                left: AppSpacing.md,
                top: AppSpacing.md,
                width: _leftBlock,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        category ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label
                            .copyWith(color: palette.textSecondary),
                      ),
                    ),
                    if (country != null)
                      Text(
                        country!,
                        style:
                            AppTypography.label.copyWith(color: palette.gold),
                      ),
                  ],
                ),
              ),
              Positioned(
                left: AppSpacing.md,
                top: 21,
                width: _leftBlock,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium
                      .copyWith(color: palette.textPrimary),
                ),
              ),
              // Price stack, anchored so a missing saving line does not move the price.
              Positioned(
                left: AppSpacing.md,
                bottom: AppSpacing.md,
                width: _leftBlock - _stepperWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (oldPrice != null)
                      Text(
                        formatTenge(oldPrice!),
                        style: AppTypography.label.copyWith(
                          color: palette.textSecondary,
                          decoration: TextDecoration.lineThrough,
                          height: 1,
                        ),
                      ),
                    Text(
                      formatTenge(price),
                      style: AppTypography.base(size: 20, weight: 700).copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                    if (saving != null)
                      Text(
                        'Выгода ${formatTenge(saving!)}',
                        style: AppTypography.labelMedium.copyWith(
                          color: palette.gold,
                          height: 1,
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                left: _leftBlock - _stepperWidth,
                bottom: AppSpacing.md,
                child: SizedBox(
                  width: _stepperWidth,
                  height: _stepperHeight,
                  child: _RowStepper(
                    quantity: quantity,
                    onIncrement: onIncrement,
                    onDecrement: onDecrement,
                  ),
                ),
              ),
              Positioned(
                right: AppSpacing.md,
                top: AppSpacing.md,
                child: _SemanticTap(
                  label: liked ? 'Убрать из избранного' : 'В избранное',
                  onTap: onLike,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: liked
                          ? palette.brandRed.withValues(alpha: 0.5)
                          : palette.surfaceMuted,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      // The design's `vuesax/bold/heart` sits inside a library instance that
                      // Figma's image API will not render, so the filled heart is Material's.
                      child: liked
                          ? Icon(Icons.favorite,
                              size: 18, color: palette.brandRed)
                          : AppIcon(AppIcons.heart,
                              size: 18, color: palette.textPrimary),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact step control for rows: 76 × 30 with the same empty/stepped behaviour as the card.
class _RowStepper extends StatelessWidget {
  const _RowStepper({
    required this.quantity,
    this.onIncrement,
    this.onDecrement,
  });

  final num quantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  String get _label => quantity == quantity.roundToDouble()
      ? quantity.toStringAsFixed(0)
      : quantity.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: quantity <= 0
          ? _SemanticTap(
              label: 'Добавить одну штуку',
              onTap: onIncrement,
              child: const Center(child: _Plus()),
            )
          : Row(
              children: [
                const SizedBox(width: 9),
                _SemanticTap(
                  label: 'Убрать одну штуку',
                  onTap: onDecrement,
                  child: const SizedBox(
                      width: 14, height: 30, child: Center(child: _Minus())),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _label,
                      style: AppTypography.bodyMedium
                          .copyWith(color: Colors.white),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onIncrement,
                  behavior: HitTestBehavior.opaque,
                  child: const SizedBox(
                      width: 14, height: 30, child: Center(child: _Plus())),
                ),
                const SizedBox(width: 9),
              ],
            ),
    );
  }
}

class _Minus extends StatelessWidget {
  const _Minus();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 9,
        height: 1.4,
        child: ColoredBox(color: Colors.white),
      );
}

class _Plus extends StatelessWidget {
  const _Plus();

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
                  child: ColoredBox(color: Colors.white)),
            ),
            Center(
              child: SizedBox(
                  width: 1.4,
                  height: 9.6,
                  child: ColoredBox(color: Colors.white)),
            ),
          ],
        ),
      );
}

/// Tap target that carries an accessibility label.
///
/// Swapped in for the bare `GestureDetector`s around the step control and the like disc, whose
/// glyphs a screen reader would otherwise announce as nothing. Keeps `behavior` at `opaque` so the
/// hit testing is unchanged.
class _SemanticTap extends StatelessWidget {
  const _SemanticTap({
    required this.label,
    required this.child,
    this.onTap,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: child,
        ),
      );
}
