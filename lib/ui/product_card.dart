import 'package:flutter/material.dart';

import '../core/money.dart';
import '../core/quantity.dart';
import '../core/product_view.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'app_icon.dart';
import 'surfaces.dart';

/// A product card with proportional artwork, complete identity and unit pricing.
///
/// Grid and rail consumers pass their real width and products to [heightFor].
/// Names and known attributes wrap without truncation or text-scale overrides.
class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.title,
    required this.price,
    this.oldPrice,
    this.metadata = const [],
    this.unitPriceLabel,
    this.quantityUnit,
    this.imageUrl,
    this.discount,
    this.promo,
    this.bonus,
    this.quantity = 0,
    this.available = true,
    this.onTap,
    this.onIncrement,
    this.onDecrement,
    super.key,
  });

  final String title;
  final num price;
  final num? oldPrice;
  final List<String> metadata;
  final String? unitPriceLabel;
  final String? quantityUnit;
  final String? imageUrl;
  final String? discount;

  /// The gift promotion label, after a price discount in badge priority.
  final String? promo;
  final String? bonus;
  final num quantity;
  final bool available;
  final VoidCallback? onTap;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  /// Returns the artwork-led width of a horizontal product rail.
  static double widthFor(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return 144 + (scale - 1).clamp(0, double.infinity) * 100;
  }

  static double _textHeight(
    BuildContext context,
    String text,
    TextStyle style,
    double width,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: width);
    final height = painter.height.ceilToDouble();
    painter.dispose();
    return height;
  }

  static double _heightForContent(
    BuildContext context, {
    required double width,
    required String title,
    required String metadata,
    required String price,
    String? oldPrice,
    bool unavailable = false,
  }) {
    final innerWidth =
        (width - AppSpacing.md).clamp(1, double.infinity).toDouble();
    return innerWidth +
        AppSpacing.md +
        AppSpacing.sm +
        _textHeight(context, title, AppTypography.bodySmallMedium, innerWidth) +
        (metadata.isEmpty
            ? 0
            : AppSpacing.xxs +
                _textHeight(context, metadata, AppTypography.label, innerWidth)) +
        (unavailable
            ? _textHeight(context, 'Нет в наличии', AppTypography.label, innerWidth)
            : 0) +
        AppSpacing.xs +
        (oldPrice == null
            ? 0
            : _textHeight(context, oldPrice, AppTypography.strikethrough, innerWidth)) +
        _textHeight(context, price, AppTypography.title, innerWidth) +
        AppSpacing.sm +
        AppSpacing.touchTarget +
        (MediaQuery.textScalerOf(context).scale(16) * 1.3).ceilToDouble() +
        AppSpacing.xxs;
  }

  /// Reserves artwork and all visible text at the consumer's actual card width.
  static double heightFor(
    BuildContext context, {
    double? width,
    Iterable<ProductView> products = const [],
    bool hasOldPrice = false,
  }) {
    final cardWidth = width ?? widthFor(context);
    var height = 0.0;
    for (final product in products) {
      final itemHeight = _heightForContent(
        context,
        width: cardWidth,
        title: product.title,
        metadata: product.metadata.join(' · '),
        price: product.unitPriceLabel,
        oldPrice: product.oldPrice == null ? null : formatTenge(product.oldPrice!),
        unavailable: !product.available,
      );
      if (itemHeight > height) height = itemHeight;
    }
    return height > 0
        ? height
        : _heightForContent(
            context,
            width: cardWidth,
            title: 'Название товара',
            metadata: 'Страна · объём',
            price: '1000 ₸/шт',
            oldPrice: hasOldPrice ? '1000 ₸' : null,
          );
  }

  /// Keeps the reference three columns at 375 px, adapting only when needed.
  static int columnsFor(BuildContext context, double availableWidth,
      {double spacing = AppSpacing.md}) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final minimumWidth = 106 + (scale - 1).clamp(0, double.infinity) * 100;
    return ((availableWidth + spacing) / (minimumWidth + spacing))
        .floor()
        .clamp(1, 4)
        .toInt();
  }

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
        metadata: view.metadata,
        unitPriceLabel: view.unitPriceLabel,
        quantityUnit: view.unit,
        price: view.price,
        oldPrice: view.oldPrice,
        discount: view.discount,
        promo: view.promo,
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
    final identity = metadata.join(' · ');
    final priceLabel = unitPriceLabel ?? formatTenge(price);
    final control = ProductQuantityControl(
      quantity: quantity,
      unit: quantityUnit,
      onIncrement: available ? onIncrement : null,
      onDecrement: onDecrement,
    );
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
        final width = constraints.hasTightWidth
            ? constraints.maxWidth
            : widthFor(context).clamp(0, constraints.maxWidth).toDouble();
        return SizedBox(
          width: width,
          height: _heightForContent(
            context,
            width: width,
            title: title,
            metadata: identity,
            price: priceLabel,
            oldPrice: oldPrice == null ? null : formatTenge(oldPrice!),
            unavailable: !available,
          ),
          child: AppSurface(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: onTap,
                  borderRadius: AppRadii.smAll,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: AppRadii.smAll,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ColoredBox(
                                color: Colors.white,
                                child: imageUrl?.isNotEmpty == true
                                    ? Image.network(
                                        imageUrl!,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) =>
                                            _missingArt(palette),
                                      )
                                    : _missingArt(palette),
                              ),
                              Positioned(
                                left: AppSpacing.xs,
                                right: AppSpacing.xs,
                                top: AppSpacing.xs,
                                child: Wrap(
                                  spacing: AppSpacing.xs,
                                  runSpacing: AppSpacing.xxs,
                                  children: badges.take(2).toList(growable: false),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        title,
                        style: AppTypography.bodySmallMedium
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
                const Spacer(),
                const SizedBox(height: AppSpacing.xs),
                if (oldPrice != null)
                  Text(
                    formatTenge(oldPrice!),
                    style: AppTypography.strikethrough
                        .copyWith(color: palette.textSecondary),
                  ),
                Text(
                  priceLabel,
                  style: AppTypography.title.copyWith(color: palette.textPrimary),
                ),
                const SizedBox(height: AppSpacing.sm),
                control,
              ],
            ),
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

/// Separate stock-aware quantity actions with a readable fractional count.
class ProductQuantityControl extends StatelessWidget {
  const ProductQuantityControl({
    required this.quantity,
    this.onIncrement,
    this.onDecrement,
    this.unit,
    super.key,
  });

  final num quantity;
  final String? unit;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = formatQuantity(
      quantity.toDouble(),
      quantityUnitLabel(unit) ?? '',
    );
    final foreground = onIncrement == null
        ? palette.textSecondary
        : palette.textOnAccent;
    return LayoutBuilder(
      builder: (context, constraints) {
        final countPainter = TextPainter(
          text: TextSpan(text: label, style: AppTypography.bodyMedium),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final inline = constraints.maxWidth >=
            AppSpacing.touchTarget * 2 + countPainter.width + AppSpacing.md;
        countPainter.dispose();
        final count = Text(
          label,
          key: ValueKey(label),
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(color: foreground),
        );
        final actions = Row(
          children: [
            StepTap(
              label: 'Уменьшить количество',
              onTap: onDecrement,
              child: Icon(
                Icons.remove,
                color: onDecrement == null
                    ? palette.textSecondary
                    : palette.textOnAccent,
                size: 20,
              ),
            ),
            Expanded(child: inline ? count : const SizedBox.shrink()),
            StepTap(
              label: 'Увеличить количество',
              onTap: onIncrement,
              child: Icon(Icons.add, color: foreground, size: 20),
            ),
          ],
        );
        return DecoratedBox(
          decoration: BoxDecoration(
            color: onIncrement == null && onDecrement == null
                ? palette.surfaceMuted
                : palette.accent,
            borderRadius: AppRadii.mdAll,
          ),
          child: quantity <= 0
              ? StepTap(
                  label: 'Добавить',
                  onTap: onIncrement,
                  width: double.infinity,
                  child: Icon(Icons.add, color: foreground, size: 20),
                )
              : inline
                  ? actions
                  : Column(
                      children: [
                        const SizedBox(height: AppSpacing.xxs),
                        count,
                        actions,
                      ],
                    ),
        );
      },
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
