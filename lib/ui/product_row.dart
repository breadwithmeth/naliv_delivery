import 'package:flutter/material.dart';

import '../core/money.dart';
import '../core/product_view.dart';
import '../core/quantity.dart';
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
    this.category,
    this.country,
    this.identityLabel,
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
  final String? category;
  final String? country;
  final String? identityLabel;
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
        category: view.category ?? view.type,
        country: view.country,
        identityLabel: [
          if (view.volume case final volume?) volume,
          if (view.weightLabel case final weight?) weight,
        ].join(' · '),
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
    final identity = identityLabel ?? metadata.join(' · ');
    final normalizedUnit = quantityUnit?.toLowerCase().replaceAll('.', '');
    final perPiece = const ['шт', 'pcs', 'piece'].contains(normalizedUnit);
    final priceLabel =
        perPiece ? formatTenge(price) : unitPriceLabel ?? formatTenge(price);
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final artWidth = (constraints.maxWidth * (scale > 1.3 ? .28 : .35))
              .clamp(72.0, 180.0);
          final artwork = Stack(
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
                            cacheWidth: (artWidth *
                                    MediaQuery.devicePixelRatioOf(context))
                                .ceil(),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => _missingArt(palette),
                          )
                        : _missingArt(palette),
                  ),
                ),
              ),
              if (promo != null)
                Positioned(
                  left: AppSpacing.xs,
                  right: AppSpacing.xs,
                  bottom: AppSpacing.xs,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.accent,
                      borderRadius: AppRadii.smAll,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: Text(promo!,
                          style: AppTypography.captionMedium
                              .copyWith(color: palette.textOnAccent)),
                    ),
                  ),
                ),
              if (onLike != null)
                Positioned(
                  top: AppSpacing.xs,
                  right: AppSpacing.xs,
                  child: Semantics(
                    container: true,
                    button: true,
                    label: liked ? 'Убрать из избранного' : 'В избранное',
                    onTap: onLike,
                    excludeSemantics: true,
                    toggled: liked,
                    child: liked
                        ? IconButton(
                            tooltip: 'Убрать из избранного',
                            onPressed: onLike,
                            style: IconButton.styleFrom(
                              minimumSize:
                                  const Size.square(AppSpacing.touchTarget),
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
                            fill: palette.surfaceMuted,
                            color: palette.textPrimary,
                          ),
                  ),
                ),
            ],
          );
          return Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(right: artWidth + AppSpacing.xs),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 106),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          onTap: onTap,
                          borderRadius: AppRadii.smAll,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (category != null || country != null)
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      if (category != null)
                                        Flexible(
                                          child: Text(category!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.caption
                                                  .copyWith(
                                                      color: palette
                                                          .textSecondary)),
                                        ),
                                      if (category != null && country != null)
                                        const SizedBox(width: AppSpacing.xs),
                                      if (country != null)
                                        Flexible(
                                          child: Text(country!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.caption
                                                  .copyWith(
                                                      color: palette.gold)),
                                        ),
                                    ],
                                  ),
                                Semantics(
                                  label: [
                                    title,
                                    ...metadata,
                                    if (discount != null) 'Скидка $discount',
                                    if (bonus != null)
                                      'Предварительно $bonus бонусов',
                                  ].join(' · '),
                                  child: ExcludeSemantics(
                                    child: Text(
                                      title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.bodySmallMedium
                                          .copyWith(color: palette.textPrimary),
                                    ),
                                  ),
                                ),
                                if (identity.isNotEmpty)
                                  Text(identity,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.caption.copyWith(
                                          color: palette.textSecondary)),
                                if (!available)
                                  Text('Нет в наличии',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.caption.copyWith(
                                          color: palette.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        LayoutBuilder(builder: (context, textConstraints) {
                          final quantityLabel = formatQuantity(
                            quantity.toDouble(),
                            perPiece
                                ? ''
                                : quantityUnitLabel(quantityUnit) ?? '',
                          );
                          final countPainter = TextPainter(
                            text: TextSpan(
                              text: quantityLabel,
                              style: AppTypography.bodyMedium,
                            ),
                            textDirection: Directionality.of(context),
                            textScaler: MediaQuery.textScalerOf(context),
                          )..layout();
                          final controlWidth = quantity <= 0
                              ? AppSpacing.touchTarget
                              : (AppSpacing.touchTarget * 2 +
                                      countPainter.width +
                                      AppSpacing.md)
                                  .clamp(AppSpacing.touchTarget * 2,
                                      textConstraints.maxWidth);
                          countPainter.dispose();
                          final pricePainter = TextPainter(
                            text: TextSpan(
                                text: priceLabel,
                                style: AppTypography.headline),
                            textDirection: Directionality.of(context),
                            textScaler: MediaQuery.textScalerOf(context),
                          )..layout();
                          final inline = pricePainter.width +
                                  controlWidth +
                                  AppSpacing.xs <=
                              textConstraints.maxWidth;
                          pricePainter.dispose();
                          final amount = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (oldPrice != null)
                                Text(formatTenge(oldPrice!),
                                    style: AppTypography.strikethrough.copyWith(
                                        color: palette.textSecondary)),
                              Text(priceLabel,
                                  style: AppTypography.headline
                                      .copyWith(color: palette.textPrimary)),
                              if (saving != null)
                                Text('Выгода ${formatTenge(saving!)}',
                                    style: AppTypography.caption
                                        .copyWith(color: palette.gold)),
                            ],
                          );
                          final control = SizedBox(
                            width: controlWidth,
                            child: ProductQuantityControl(
                              quantity: quantity,
                              unit: perPiece ? null : quantityUnit,
                              onIncrement: available ? onIncrement : null,
                              onDecrement: onDecrement,
                            ),
                          );
                          return inline
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(child: amount),
                                    const SizedBox(width: AppSpacing.xs),
                                    control,
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    amount,
                                    const SizedBox(height: AppSpacing.xs),
                                    Align(
                                        alignment: Alignment.centerRight,
                                        child: control),
                                  ],
                                );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: artWidth,
                child: artwork,
              ),
            ],
          );
        },
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
