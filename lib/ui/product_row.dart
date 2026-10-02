import 'package:flutter/material.dart';

import '../core/money.dart';
import '../core/product_view.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'app_icon.dart';
import 'product_card.dart';
import 'surfaces.dart';

/// A content-sized product row for search and favorites.
///
/// Product text wraps independently of artwork and quantity controls. The row
/// grows with the OS text scaler rather than using positioned 10 px labels.
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
    this.available = true,
    this.onTap,
    this.onLike,
    this.onIncrement,
    this.onDecrement,
  });

  final String title;
  final int price;
  final String? category;
  final String? country;
  final int? oldPrice;
  final int? saving;
  final String? imageUrl;
  final num quantity;
  final bool liked;
  final bool available;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  factory ProductRow.fromView(
    ProductView view, {
    bool liked = false,
    num? quantity,
    VoidCallback? onTap,
    VoidCallback? onLike,
    VoidCallback? onIncrement,
    VoidCallback? onDecrement,
    Key? key,
  }) =>
      ProductRow(
        key: key,
        title: view.title,
        price: view.price,
        category: view.category,
        country: view.country,
        oldPrice: view.oldPrice,
        saving: view.saving,
        imageUrl: view.imageUrl,
        available: view.available,
        quantity: quantity ?? view.quantity,
        liked: liked,
        onTap: onTap,
        onLike: onLike,
        onIncrement: onIncrement,
        onDecrement: onDecrement,
      );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  borderRadius: AppRadii.smAll,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (category?.isNotEmpty == true)
                        Text(category!,
                            style: AppTypography.bodySmall
                                .copyWith(color: palette.textSecondary)),
                      if (country?.isNotEmpty == true)
                        Text(country!,
                            style: AppTypography.bodySmall
                                .copyWith(color: palette.gold)),
                      Text(title,
                          style: AppTypography.titleMedium
                              .copyWith(color: palette.textPrimary)),
                      const SizedBox(height: AppSpacing.md),
                      if (oldPrice != null)
                        Text(formatTenge(oldPrice!),
                            style: AppTypography.strikethrough
                                .copyWith(color: palette.textSecondary)),
                      Text(formatTenge(price),
                          style: AppTypography.headline
                              .copyWith(color: palette.textPrimary)),
                      if (saving != null)
                        Text('Выгода ${formatTenge(saving!)}',
                            style: AppTypography.labelMedium
                                .copyWith(color: palette.gold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              SizedBox(
                width: 96,
                height: 106,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: InkWell(
                        onTap: onTap,
                        child: ClipRRect(
                          borderRadius: AppRadii.smAll,
                          child: imageUrl?.isNotEmpty == true
                              ? Image.network(imageUrl!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      _missingArt(palette))
                              : _missingArt(palette),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        tooltip: liked ? 'Убрать из избранного' : 'В избранное',
                        onPressed: onLike,
                        style: IconButton.styleFrom(
                          backgroundColor: liked
                              ? palette.brandRed.withValues(alpha: 0.5)
                              : palette.surfaceMuted,
                          minimumSize:
                              const Size.square(AppSpacing.touchTarget),
                        ),
                        icon: liked
                            ? Icon(Icons.favorite,
                                size: 20, color: palette.brandRed)
                            : AppIcon(AppIcons.heart,
                                size: 20, color: palette.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: ProductQuantityControl(
                quantity: quantity,
                onIncrement: available ? onIncrement : null,
                onDecrement: onDecrement,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _missingArt(AppPalette palette) => ColoredBox(
        color: Colors.white,
        child: Center(
            child: Icon(Icons.image_outlined,
                color: palette.textSecondary, size: 32)),
      );
}
