import 'package:flutter/material.dart';

import '../core/money.dart';
import '../core/quantity.dart';
import '../core/product_view.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'app_icon.dart';
import 'surfaces.dart';

/// A naturally sized product card with complete identity, pricing and offers.
///
/// Names and known attributes wrap without truncation or text-scale overrides.
class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.title,
    required this.price,
    this.oldPrice,
    this.saving,
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
    this.trailingAction,
    super.key,
  });

  final String title;
  final num price;
  final num? oldPrice;
  final num? saving;
  final List<String> metadata;
  final String? unitPriceLabel;
  final String? quantityUnit;
  final String? imageUrl;
  final String? discount;

  /// The active gift promotion label.
  final String? promo;
  final String? bonus;
  final num quantity;
  final bool available;
  final VoidCallback? onTap;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final Widget? trailingAction;

  /// Returns a readable width for a horizontal product rail.
  static double widthFor(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return 176 + (scale - 1).clamp(0, double.infinity) * 100;
  }

  /// Keeps two columns at phone widths and one for narrow or enlarged content.
  static int columnsFor(BuildContext context, double availableWidth,
      {double spacing = AppSpacing.md}) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final minimumWidth = 160 + (scale - 1).clamp(0, double.infinity) * 140;
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
    Widget? trailingAction,
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
        saving: view.saving,
        discount: view.discount,
        promo: view.promo,
        bonus: view.bonus,
        imageUrl: view.imageUrl,
        available: view.available,
        quantity: quantity ?? view.quantity,
        onTap: onTap,
        onIncrement: onIncrement,
        onDecrement: onDecrement,
        trailingAction: trailingAction,
      );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final priceLabel = unitPriceLabel ?? formatTenge(price);
    return SizedBox(
      width: widthFor(context),
      child: AppSurface(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: AppRadii.smAll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) => SizedBox(
                      height: (constraints.maxWidth * .8).clamp(96, 152),
                      child: ClipRRect(
                        borderRadius: AppRadii.smAll,
                        child: ColoredBox(
                          color: Colors.white,
                          child: imageUrl?.isNotEmpty == true
                              ? Image.network(
                                  imageUrl!,
                                  cacheWidth: (constraints.maxWidth *
                                          MediaQuery.devicePixelRatioOf(
                                              context))
                                      .ceil(),
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      _missingArt(palette),
                                )
                              : _missingArt(palette),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    title,
                    style: AppTypography.bodySmallSemibold
                        .copyWith(color: palette.textPrimary),
                  ),
                  if (metadata.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      metadata.join(' · '),
                      style: AppTypography.label
                          .copyWith(color: palette.textSecondary),
                    ),
                  ],
                  if (!available) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Нет в наличии',
                      style: AppTypography.label
                          .copyWith(color: palette.textSecondary),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  if (oldPrice != null)
                    Text(
                      formatTenge(oldPrice!),
                      style: AppTypography.strikethrough
                          .copyWith(color: palette.textSecondary),
                    ),
                  Text(
                    priceLabel,
                    style: AppTypography.title
                        .copyWith(color: palette.textPrimary),
                  ),
                  if (saving != null)
                    Text(
                      'Выгода ${formatTenge(saving!)}',
                      style: AppTypography.labelMedium
                          .copyWith(color: palette.textPrimary),
                    ),
                  if (discount != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _ProductFact(
                      icon: AppIcons.fire,
                      label: discount!,
                      semanticLabel: 'Скидка $discount',
                      fill: palette.brandRed,
                      foreground: Colors.white,
                    ),
                  ],
                  if (promo != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _ProductFact(
                      icon: AppIcons.fire,
                      label: 'Акция $promo',
                      fill: palette.accent,
                      foreground: palette.textOnAccent,
                    ),
                  ],
                  if (bonus != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _ProductFact(
                      icon: AppIcons.bonusStar,
                      label: 'Бонусы $bonus',
                      fill: palette.gold,
                      foreground:
                          Theme.of(context).brightness == Brightness.light
                              ? Colors.white
                              : Colors.black,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: ProductQuantityControl(
                    quantity: quantity,
                    unit: quantityUnit,
                    onIncrement: available ? onIncrement : null,
                    onDecrement: onDecrement,
                  ),
                ),
                if (trailingAction != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  trailingAction!,
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _missingArt(AppPalette palette) => Semantics(
        image: true,
        label: 'Нет фото',
        child: Center(
          child: Icon(
            Icons.image_outlined,
            color: palette.textSecondary,
            size: 32,
          ),
        ),
      );
}

class _ProductFact extends StatelessWidget {
  const _ProductFact({
    required this.icon,
    required this.label,
    required this.fill,
    required this.foreground,
    this.semanticLabel,
  });

  final String icon;
  final String label;
  final Color fill;
  final Color foreground;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: fill, borderRadius: AppRadii.xsAll),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(icon, size: 14, color: foreground),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  semanticsLabel: semanticLabel,
                  style: AppTypography.labelMedium.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
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
    final foreground = onIncrement == null && onDecrement == null
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
