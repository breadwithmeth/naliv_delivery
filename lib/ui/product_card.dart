import 'package:flutter/material.dart';

import '../core/money.dart';
import '../core/quantity.dart';
import '../core/product_view.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'app_icon.dart';
import 'surfaces.dart';

/// A readable product card shared by grids and horizontal recommendation strips.
///
/// Consumers use [widthFor], [heightFor] and [columnsFor] with the inherited text
/// scaler. Artwork is capped at 96 px; wrapped text takes priority over media.
class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.title,
    required this.price,
    this.oldPrice,
    this.country,
    this.volume,
    this.imageUrl,
    this.discount,
    this.bonus,
    this.quantity = 0,
    this.available = true,
    this.onTap,
    this.onIncrement,
    this.onDecrement,
    super.key,
  });

  final String title;
  final int price;
  final int? oldPrice;
  final String? country;
  final String? volume;
  final String? imageUrl;
  final String? discount;
  final String? bonus;
  final num quantity;
  final bool available;
  final VoidCallback? onTap;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  static const double _artworkHeight = 96;

  /// Returns the minimum width needed for readable text and separate controls.
  static double widthFor(BuildContext context) {
    final scaled = MediaQuery.textScalerOf(context).scale(16);
    return 142 + (scaled > 16 ? (scaled - 16) * 5.5 : 0);
  }

  /// Reserves scaled text and actions without enlarging artwork.
  ///
  /// Grid and strip parents set [hasOldPrice] when any visible item has one.
  static double heightFor(BuildContext context, {bool hasOldPrice = false}) {
    final scaler = MediaQuery.textScalerOf(context);
    final name = (scaler.scale(14) * 1.3).ceilToDouble() * 2;
    final metadata = (scaler.scale(12) * 1.3).ceilToDouble();
    final prices =
        (scaler.scale(16) * 1.3).ceilToDouble() + (hasOldPrice ? metadata : 0);
    return _artworkHeight +
        AppSpacing.touchTarget +
        AppSpacing.md * 5 +
        name +
        metadata +
        prices;
  }

  /// Returns a grid column count that does not squeeze text into tiny tiles.
  static int columnsFor(BuildContext context, double availableWidth,
          {double spacing = AppSpacing.md}) =>
      ((availableWidth + spacing) / (widthFor(context) + spacing))
          .floor()
          .clamp(1, 4)
          .toInt();

  factory ProductCard.fromView(
    ProductView view, {
    num? quantity,
    VoidCallback? onTap,
    VoidCallback? onIncrement,
    VoidCallback? onDecrement,
    Key? key,
  }) =>
      ProductCard(
        key: key,
        title: view.title,
        country: view.country,
        volume: view.volume,
        price: view.price,
        oldPrice: view.oldPrice,
        discount: view.discount,
        bonus: view.bonus,
        imageUrl: view.imageUrl,
        available: view.available,
        quantity: quantity ?? view.quantity,
        onTap: onTap,
        onIncrement: onIncrement,
        onDecrement: onDecrement,
      );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final metadata = country?.isNotEmpty == true
        ? volume?.isNotEmpty == true
            ? '$country · $volume'
            : country!
        : volume ?? '';
    final prices = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (oldPrice != null)
          Text(formatTenge(oldPrice!),
              style: AppTypography.strikethrough
                  .copyWith(color: palette.textSecondary)),
        Text(formatTenge(price),
            style: AppTypography.title.copyWith(color: palette.textPrimary)),
      ],
    );
    final control = ProductQuantityControl(
      quantity: quantity,
      onIncrement: available ? onIncrement : null,
      onDecrement: onDecrement,
    );
    return SizedBox(
      width: widthFor(context),
      height: heightFor(context, hasOldPrice: oldPrice != null),
      child: AppSurface(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: InkWell(
                onTap: onTap,
                borderRadius: AppRadii.smAll,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Flexible(
                      child: ClipRRect(
                        borderRadius: AppRadii.smAll,
                        child: SizedBox(
                          height: _artworkHeight,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              imageUrl?.isNotEmpty == true
                                  ? Image.network(imageUrl!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) =>
                                          _missingArt(palette))
                                  : _missingArt(palette),
                              Positioned(
                                left: AppSpacing.xs,
                                right: AppSpacing.xs,
                                top: AppSpacing.xs,
                                child: Wrap(
                                  spacing: AppSpacing.xs,
                                  runSpacing: AppSpacing.xs,
                                  children: [
                                    if (discount != null)
                                      _badge(AppIcons.fire, discount!,
                                          palette.brandRed),
                                    if (bonus != null)
                                      _badge(AppIcons.bonusStar, bonus!,
                                          palette.gold,
                                          foreground:
                                              Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? Colors.black
                                                  : Colors.white),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmallMedium
                            .copyWith(color: palette.textPrimary)),
                    if (metadata.isNotEmpty)
                      Text(metadata,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label
                              .copyWith(color: palette.textSecondary)),
                    if (!available)
                      Text('Нет в наличии',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label
                              .copyWith(color: palette.textSecondary)),
                    const SizedBox(height: AppSpacing.md),
                    prices,
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: quantity <= 0
                  ? SizedBox(width: AppSpacing.touchTarget, child: control)
                  : control,
            ),
          ],
        ),
      ),
    );
  }

  Widget _missingArt(AppPalette palette) => ColoredBox(
        color: palette.surfaceMuted,
        child: Center(
            child: Icon(Icons.image_outlined,
                color: palette.textSecondary, size: 32)),
      );

  Widget _badge(String icon, String label, Color fill,
          {Color foreground = Colors.white}) =>
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(color: fill, borderRadius: AppRadii.xsAll),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(icon, size: 12, color: foreground),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMedium.copyWith(color: foreground)),
            ),
          ],
        ),
      );
}

/// Separate stock-aware quantity actions with a readable fractional count.
class ProductQuantityControl extends StatelessWidget {
  const ProductQuantityControl({
    required this.quantity,
    this.onIncrement,
    this.onDecrement,
    super.key,
  });

  final num quantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = formatQuantity(quantity.toDouble(), '');
    return DecoratedBox(
      decoration: BoxDecoration(
          color: quantity <= 0 && onIncrement != null
              ? palette.accent
              : palette.surfaceMuted,
          borderRadius: AppRadii.mdAll),
      child: quantity <= 0
          ? StepTap(
              label: 'Добавить',
              onTap: onIncrement,
              width: double.infinity,
              child: Icon(Icons.add,
                  color: onIncrement == null
                      ? palette.textSecondary
                      : Colors.black,
                  size: 20),
            )
          : Row(
              children: [
                StepTap(
                    label: 'Уменьшить количество',
                    onTap: onDecrement,
                    child: Icon(Icons.remove,
                        color: onDecrement == null
                            ? palette.textSecondary
                            : palette.textPrimary,
                        size: 20)),
                Expanded(
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      child: Text(label,
                          key: ValueKey(label),
                          style: AppTypography.bodyMedium
                              .copyWith(color: palette.textPrimary)),
                    ),
                  ),
                ),
                StepTap(
                    label: 'Увеличить количество',
                    onTap: onIncrement,
                    child: Icon(Icons.add,
                        color: onIncrement == null
                            ? palette.textSecondary
                            : palette.textPrimary,
                        size: 20)),
              ],
            ),
    );
  }
}

/// A labelled quantity action with a minimum 44 px hit target.
class StepTap extends StatelessWidget {
  const StepTap({
    required this.label,
    required this.child,
    this.onTap,
    this.width = AppSpacing.touchTarget,
    super.key,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        enabled: onTap != null,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.mdAll,
          child: SizedBox(
              width: width,
              height: AppSpacing.touchTarget,
              child: Center(child: child)),
        ),
      );
}
