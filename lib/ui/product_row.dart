import 'package:flutter/material.dart';

import '../core/money.dart';
import '../core/product_view.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'app_icon.dart';
import 'app_icon_button.dart';
import 'product_card.dart';
import 'surfaces.dart';

/// A content-sized product row for search and favorites.
///
/// Known identity attributes and price units stay visible next to proportional
/// artwork. Rows grow with real names and the inherited OS text scaler.
class ProductRow extends StatelessWidget {
  const ProductRow({
    super.key,
    required this.title,
    required this.price,
    this.metadata = const [],
    this.unitPriceLabel,
    this.quantityUnit,
    this.discount,
    this.promo,
    this.bonus,
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
  final num price;
  final List<String> metadata;
  final String? unitPriceLabel;
  final String? quantityUnit;
  final String? discount;
  final String? promo;
  final String? bonus;
  final num? oldPrice;
  final num? saving;
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
        metadata: view.metadata,
        unitPriceLabel: view.unitPriceLabel,
        quantityUnit: view.unit,
        discount: view.discount,
        promo: view.promo,
        bonus: view.bonus,
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
    final identity = metadata.join(' · ');
    final badges = <Widget>[
      if (discount != null)
        AppPromoChip(
          icon: AppIcons.fire,
          label: discount!,
          fill: palette.brandRed,
        ),
      if (promo != null)
        AppPromoChip(
          icon: AppIcons.fire,
          label: promo!,
          fill: palette.accent,
          foreground: palette.textOnAccent,
        ),
      if (bonus != null)
        AppPromoChip(
          icon: AppIcons.bonusStar,
          label: bonus!,
          fill: palette.gold,
          foreground: Colors.black,
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final artWidth = constraints.maxWidth * (scale > 1.3 ? .3 : .4);
        final artwork = SizedBox(
          width: artWidth,
          height: artWidth,
          child: Stack(
            fit: StackFit.expand,
            children: [
              InkWell(
                onTap: onTap,
                child: ClipRRect(
                  borderRadius: AppRadii.smAll,
                  child: ColoredBox(
                    color: Colors.white,
                    child: imageUrl?.isNotEmpty == true
                        ? Image.network(
                            imageUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => _missingArt(palette),
                          )
                        : _missingArt(palette),
                  ),
                ),
              ),
              if (onLike != null)
                Positioned(
                  top: AppSpacing.xs,
                  right: AppSpacing.xs,
                  child: Semantics(
                    toggled: liked,
                    child: liked
                        ? IconButton(
                            tooltip: 'Убрать из избранного',
                            onPressed: onLike,
                            style: IconButton.styleFrom(
                              minimumSize: const Size.square(AppSpacing.touchTarget),
                              backgroundColor:
                                  palette.brandRed.withValues(alpha: .25),
                            ),
                            icon: Icon(Icons.favorite,
                                color: palette.brandRed, size: 20),
                          )
                        : AppIconButton(
                            asset: AppIcons.heart,
                            tooltip: 'В избранное',
                            onTap: onLike,
                            size: AppSpacing.touchTarget,
                            glyphSize: 20,
                            blur: 0,
                            fill: palette.surfaceMuted,
                            color: palette.textPrimary,
                          ),
                  ),
                ),
            ],
          ),
        );
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: AppRadii.smAll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleMedium
                        .copyWith(color: palette.textPrimary),
                  ),
                  if (identity.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      identity,
                      style: AppTypography.label
                          .copyWith(color: palette.textSecondary),
                    ),
                  ],
                  if (!available)
                    Text(
                      'Нет в наличии',
                      style: AppTypography.label
                          .copyWith(color: palette.textSecondary),
                    ),
                ],
              ),
            ),
            if (badges.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xxs,
                children: badges.take(2).toList(growable: false),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            if (oldPrice != null)
              Text(
                formatTenge(oldPrice!),
                style: AppTypography.strikethrough
                    .copyWith(color: palette.textSecondary),
              ),
            Text(
              unitPriceLabel ?? formatTenge(price),
              style: AppTypography.headline.copyWith(color: palette.textPrimary),
            ),
            if (saving != null)
              Text(
                'Выгода ${formatTenge(saving!)}',
                style: AppTypography.labelMedium.copyWith(color: palette.gold),
              ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: quantity <= 0
                  ? SizedBox(
                      width: AppSpacing.touchTarget,
                      child: ProductQuantityControl(
                        quantity: quantity,
                        unit: quantityUnit,
                        onIncrement: available ? onIncrement : null,
                        onDecrement: onDecrement,
                      ),
                    )
                  : ProductQuantityControl(
                      quantity: quantity,
                      unit: quantityUnit,
                      onIncrement: available ? onIncrement : null,
                      onDecrement: onDecrement,
                    ),
            ),
          ],
        );
        return AppSurface(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: text,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              artwork,
            ],
          ),
        );
      },
    );
  }

  Widget _missingArt(AppPalette palette) => ColoredBox(
        color: Colors.white,
        child: Center(
            child: Icon(Icons.image_outlined,
                color: palette.textSecondary, size: 32)),
      );
}
