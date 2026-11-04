import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/money.dart';
import '../core/quantity.dart';
import '../core/product_view.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'app_icon.dart';
import 'motion_widgets.dart';
import 'text_width_cache.dart';
import '../utils/smart_cart.dart';

/// Tells every [ProductCard] below it which optional price lines exist somewhere in the
/// collection, so each card reserves the same slots and prices and buttons line up.
class ProductCardLayout extends InheritedWidget {
  const ProductCardLayout({
    required this.hasOldPrice,
    required this.hasSaving,
    required super.child,
    super.key,
  });

  /// Derives the flags from the products a grid or rail is about to show.
  ///
  /// A null collection is treated as the tallest case, so cards can never be clipped.
  static ({bool hasOldPrice, bool hasSaving}) flagsOf(
    Iterable<ProductView>? products,
  ) {
    if (products == null) return (hasOldPrice: true, hasSaving: true);
    var oldPrice = false;
    var saving = false;
    for (final product in products) {
      oldPrice = oldPrice || product.oldPrice != null;
      saving = saving || product.saving != null;
    }
    return (hasOldPrice: oldPrice, hasSaving: saving);
  }

  final bool hasOldPrice;
  final bool hasSaving;

  static ProductCardLayout? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProductCardLayout>();

  @override
  bool updateShouldNotify(ProductCardLayout oldWidget) =>
      hasOldPrice != oldWidget.hasOldPrice || hasSaving != oldWidget.hasSaving;
}

/// Every vertical measure of a card, derived from its width and the text scaler.
///
/// The same numbers size the card's slots and the grid/rail row height, so a row of cards
/// has one height and nothing inside it can overflow.
class _CardMetrics {
  _CardMetrics(
    this.width,
    TextScaler scaler, {
    required this.hasOldPrice,
    required this.hasSaving,
  }) {
    double line(double size, [int lines = 1]) =>
        (scaler.scale(size) * 1.3 * lines).ceilToDouble();
    nameHeight = line(13, 2);
    metaHeight = line(12);
    oldPriceHeight = line(12);
    priceHeight = line(16);
    savingHeight = line(12);
    pillHeight = math.max(34.0, (scaler.scale(14) * 1.2 + 10).ceilToDouble());
    hitHeight = math.max(AppSpacing.touchTarget, pillHeight + 8);
  }

  static const double pad = 4;
  static const double textInset = 4;
  static const double imageGap = 8;
  static const double nameGap = 2;
  static const double minGap = 6;
  static const double ctaGap = 6;
  static const double maxImageHeight = 170;

  final double width;
  final bool hasOldPrice;
  final bool hasSaving;
  late final double nameHeight;
  late final double metaHeight;
  late final double oldPriceHeight;
  late final double priceHeight;
  late final double savingHeight;
  late final double pillHeight;
  late final double hitHeight;

  double get innerWidth => width - pad * 2;
  double get textWidth => innerWidth - textInset * 2;
  double get imageHeight =>
      math.min(innerWidth * 1.1, maxImageHeight).roundToDouble();
  double get priceBlockHeight =>
      (hasOldPrice ? oldPriceHeight : 0) +
      priceHeight +
      (hasSaving ? savingHeight : 0);
  double get ctaReserve => ctaGap + pillHeight;

  double get extent =>
      pad +
      imageHeight +
      imageGap +
      nameHeight +
      nameGap +
      metaHeight +
      minGap +
      priceBlockHeight +
      ctaReserve +
      pad;
}

/// A compact photo-first card with the complete identity in its description.
///
/// The anatomy is fixed: artwork, a two-line name, one meta line, then the price block and
/// the cart control pinned to the bottom. Long names ellipsize (the full text stays in the
/// semantics label), so cards in one row always share a height and their prices and
/// buttons share baselines. Inside a [ProductGrid] or [ProductRail] the height is dictated
/// by the parent; on its own the card sizes itself from the same metrics.
class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.title,
    required this.price,
    this.oldPrice,
    this.saving,
    this.metadata = const [],
    this.country,
    this.volume,
    this.unitPriceLabel,
    this.quantityUnit,
    this.imageUrl,
    this.discount,
    this.promo,
    this.bonus,
    this.quantity = 0,
    this.step = 1,
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
  final String? country;
  final String? volume;
  final String? unitPriceLabel;
  final String? quantityUnit;
  final String? imageUrl;
  final String? discount;

  /// The active gift promotion label.
  final String? promo;
  final String? bonus;
  final num quantity;

  /// One step of the stepper; at the last step the minus deletes the item.
  final num step;
  final bool available;
  final VoidCallback? onTap;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  /// An extra control (for example a favourite toggle) overlaid on the artwork's top
  /// corner. It brings its own hit target.
  final Widget? trailingAction;

  static final TextStyle _nameStyle = AppTypography.base(size: 13, weight: 500);
  static final TextStyle _metaStyle = AppTypography.base(size: 12);
  static final TextStyle _countStyle =
      AppTypography.base(size: 14, weight: 700, height: 1.2);

  static double _scaleOf(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(14) / 14;

  /// The width of a card in a horizontal rail: about two and a half fit at 375 px.
  static double widthFor(BuildContext context) =>
      128 + math.max(0.0, _scaleOf(context) - 1.15) * 120;

  /// The height of every card [width] wide at the current text scale.
  ///
  /// [hasOldPrice] / [hasSaving] say whether any card in the collection shows those price
  /// lines; they default to the tallest case.
  static double extentFor(
    BuildContext context,
    double width, {
    bool hasOldPrice = true,
    bool hasSaving = true,
  }) =>
      _CardMetrics(
        width,
        MediaQuery.textScalerOf(context),
        hasOldPrice: hasOldPrice,
        hasSaving: hasSaving,
      ).extent;

  /// Fits three compact cards at 375 px, fewer for narrow screens or large text.
  static int columnsFor(BuildContext context, double availableWidth,
      {double spacing = AppSpacing.sm}) {
    final minimumWidth = 104 + math.max(0.0, _scaleOf(context) - 1.15) * 160;
    return ((availableWidth + spacing) / (minimumWidth + spacing))
        .floor()
        .clamp(1, 6)
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
        country: view.country,
        volume: view.volume,
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
        step: (quantity ?? view.quantity) <= 0 ? 1 : _stepOf(view),
        onTap: onTap,
        onIncrement: onIncrement,
        onDecrement: onDecrement,
        trailingAction: trailingAction,
      );

  static num _stepOf(ProductView view) {
    final selection = SmartCartSelection(view.source);
    return selection.usesPourFlow
        ? selection.minBottleVolume
        : view.source.effectiveStepQuantity;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final basis = quantityUnitLabel(quantityUnit);
    final priceLabel = basis == 'шт'
        ? formatTenge(price)
        : unitPriceLabel ??
            '${formatTenge(price)}${basis == null ? '' : '/$basis'}';
    final description = [
      title,
      ...metadata,
      if (country != null && !metadata.contains(country)) country!,
      if (volume != null && !metadata.contains(volume)) volume!,
      priceLabel,
      if (oldPrice != null) 'Прежняя цена ${formatTenge(oldPrice!)}',
      if (saving != null) 'Выгода ${formatTenge(saving!)}',
      if (discount != null) 'Скидка $discount',
      if (promo != null) 'Акция $promo',
      if (bonus != null) 'Бонусы $bonus',
      if (!available) 'Нет в наличии',
    ].join('. ');
    final layout = ProductCardLayout.maybeOf(context);
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasTightWidth
            ? constraints.maxWidth
            : widthFor(context)
                .clamp(constraints.minWidth, constraints.maxWidth)
                .toDouble();
        final metrics = _CardMetrics(
          width,
          scaler,
          hasOldPrice: oldPrice != null || (layout?.hasOldPrice ?? false),
          hasSaving: saving != null || (layout?.hasSaving ?? false),
        );
        final height =
            constraints.hasTightHeight ? constraints.maxHeight : metrics.extent;
        final card = SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: Material(
                  color: palette.surface,
                  surfaceTintColor: Colors.transparent,
                  borderRadius: AppRadii.lgAll,
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(_CardMetrics.pad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _pressRegion(
                            Semantics(
                              label: description,
                              button: onTap != null,
                              onTap: onTap,
                              excludeSemantics: true,
                              child: InkWell(
                                onTap: onTap,
                                borderRadius: AppRadii.smAll,
                                child: _content(context, palette, metrics,
                                    priceLabel, basis),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: metrics.ctaReserve),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: metrics.hitHeight,
                child: _CardCta(
                  quantity: quantity,
                  step: step,
                  unit: quantityUnit,
                  onIncrement: available ? onIncrement : null,
                  onDecrement: onDecrement,
                  pillHeight: metrics.pillHeight,
                  hitHeight: metrics.hitHeight,
                  countStyle: _countStyle,
                ),
              ),
              if (trailingAction != null)
                Positioned(
                  top: _CardMetrics.pad,
                  right: _CardMetrics.pad,
                  child: trailingAction!,
                ),
            ],
          ),
        );
        return onTap == null
            ? card
            : PressScale(wholeSurface: false, child: card);
      },
    );
  }

  /// Only the details area presses the card; the cart control and the trailing action
  /// are separate buttons and leave the card still.
  Widget _pressRegion(Widget child) =>
      onTap == null ? child : PressScaleTrigger(child: child);

  Widget _content(
    BuildContext context,
    AppPalette palette,
    _CardMetrics metrics,
    String priceLabel,
    String? basis,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: metrics.imageHeight,
          child: _artwork(context, palette, metrics),
        ),
        const SizedBox(height: _CardMetrics.imageGap),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: _CardMetrics.textInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _nameStyle.copyWith(color: palette.textPrimary),
              ),
              const SizedBox(height: _CardMetrics.nameGap),
              SizedBox(
                height: metrics.metaHeight,
                child: _meta(palette, metrics),
              ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: _CardMetrics.textInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (metrics.hasOldPrice)
                SizedBox(
                  height: metrics.oldPriceHeight,
                  width: double.infinity,
                  child: oldPrice == null
                      ? null
                      : Text(
                          '${formatTenge(oldPrice!)}${basis == null || basis == 'шт' ? '' : '/$basis'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.strikethrough
                              .copyWith(color: palette.textSecondary),
                        ),
                ),
              Text(
                priceLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.title.copyWith(color: palette.textPrimary),
              ),
              if (metrics.hasSaving)
                SizedBox(
                  height: metrics.savingHeight,
                  width: double.infinity,
                  child: saving == null
                      ? null
                      : Text(
                          'Выгода ${formatTenge(saving!)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelMedium
                              .copyWith(color: palette.gold),
                        ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Volume and country as one quiet line, e.g. «0,75 л · Франция»: the volume
  /// leads because it distinguishes otherwise identical names.
  Widget _meta(AppPalette palette, _CardMetrics metrics) {
    final parts = [
      if (volume?.trim().isNotEmpty == true) volume!.trim(),
      if (country?.trim().isNotEmpty == true) country!.trim(),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _metaStyle.copyWith(color: palette.textSecondary),
    );
  }

  Widget _artwork(
    BuildContext context,
    AppPalette palette,
    _CardMetrics metrics,
  ) {
    final art = imageUrl?.isNotEmpty == true
        ? Image.network(
            imageUrl!,
            width: double.infinity,
            height: double.infinity,
            cacheWidth:
                (metrics.innerWidth * MediaQuery.devicePixelRatioOf(context))
                    .ceil(),
            fit: BoxFit.contain,
            // Paint-time alpha instead of an Opacity layer: no offscreen buffer per card.
            opacity: available ? null : _dimmedArt,
            frameBuilder: fadeInImageFrame,
            errorBuilder: (_, __, ___) => _missingArt(palette, available),
          )
        : _missingArt(palette, available);
    return Stack(
      fit: StackFit.expand,
      children: [
        // The 6 px inset keeps the artwork inside the 8 px corner arc, so a rounded fill
        // looks the same as clipping it and costs no clip layer per card.
        DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadii.mdAll,
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: art,
          ),
        ),
        if (discount != null || promo != null || bonus != null)
          Positioned(
            top: AppSpacing.xs,
            left: AppSpacing.xs,
            right: AppSpacing.xs,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: AppSpacing.xxs,
              children: [
                if (discount != null)
                  _Badge(
                    icon: AppIcons.fire,
                    label: discount!,
                    fill: palette.brandRed,
                    foreground: Colors.white,
                  ),
                if (promo != null)
                  _Badge(
                    icon: AppIcons.fire,
                    label: promo!,
                    fill: palette.accent,
                    foreground: palette.textOnAccent,
                  ),
                if (bonus != null)
                  _Badge(
                    icon: AppIcons.bonusStar,
                    label: bonus!,
                    fill: const Color(0xFFE0AB62),
                    foreground: Colors.black,
                  ),
              ],
            ),
          ),
        if (!available)
          Positioned(
            left: AppSpacing.xs,
            right: AppSpacing.xs,
            bottom: AppSpacing.xs,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.surface.withValues(alpha: .92),
                  borderRadius: AppRadii.xsAll,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  child: Text(
                    'Нет в наличии',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.base(size: 11, weight: 500)
                        .copyWith(color: palette.textPrimary),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  static const Animation<double> _dimmedArt = AlwaysStoppedAnimation(.4);

  Widget _missingArt(AppPalette palette, bool available) => Semantics(
        image: true,
        label: 'Нет фото',
        child: Center(
          child: Icon(
            Icons.image_outlined,
            color: available
                ? palette.textSecondary
                : palette.textSecondary.withValues(alpha: .4),
            size: 32,
          ),
        ),
      );
}

/// A small status badge over the artwork: icon plus a one-line label, 11 px minimum.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
    required this.fill,
    required this.foreground,
  });

  final String icon;
  final String label;
  final Color fill;
  final Color foreground;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: fill, borderRadius: AppRadii.xsAll),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: 10, color: foreground),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.base(size: 11, weight: 500)
                      .copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      );
}

/// The card's cart control: an orange pill with white glyphs, drawn [pillHeight] tall at the
/// card's bottom edge inside a taller transparent hit area.
///
/// Add, decrease and increase keep their own labelled [StepTap]s (at least 44 px each way);
/// the decrease/increase taps overlap the count's neighbourhood rather than shrinking.
class _CardCta extends StatelessWidget {
  const _CardCta({
    required this.quantity,
    required this.step,
    required this.unit,
    required this.onIncrement,
    required this.onDecrement,
    required this.pillHeight,
    required this.hitHeight,
    required this.countStyle,
  });

  final num quantity;
  final num step;
  final String? unit;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final double pillHeight;
  final double hitHeight;
  final TextStyle countStyle;

  static const double _inset = _CardMetrics.pad;
  static const double _glyphZone = 36;

  @override
  Widget build(BuildContext context) => AnimatedSwap(
        stateKey: quantity <= 0,
        child: _state(context),
      );

  Widget _state(BuildContext context) {
    final palette = context.palette;
    final disabled = onIncrement == null && onDecrement == null;
    final fill =
        disabled ? palette.textSecondary.withValues(alpha: .2) : palette.accent;
    final glyph = disabled ? palette.textSecondary : palette.textOnAccent;
    // Centres the 44 px tap boxes' glyphs on the pill instead of on the whole hit area.
    final glyphShift = math.max(0.0, hitHeight - _inset * 2 - pillHeight);
    Widget icon(IconData data, {required bool enabled}) => Padding(
          padding: EdgeInsets.only(top: glyphShift),
          child: Icon(
            data,
            size: 20,
            color: enabled ? glyph : glyph.withValues(alpha: .45),
          ),
        );
    final pill = Positioned(
      left: _inset,
      right: _inset,
      bottom: _inset,
      height: pillHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(color: fill, borderRadius: AppRadii.mdAll),
      ),
    );
    if (quantity <= 0) {
      final light = Theme.of(context).brightness == Brightness.light;
      final enabled = onIncrement != null;
      // Not yet in the cart: a quiet raised pill, so a grid is not a wall of orange.
      // The solid orange stepper below then reads as a clear «in cart» state.
      final addFill = !enabled
          ? palette.textSecondary.withValues(alpha: .15)
          : light
              ? palette.background
              : Color.alphaBlend(
                  palette.accent.withValues(alpha: .18), palette.background);
      final addGlyph = enabled ? palette.accent : palette.textSecondary;
      final labelStyle = AppTypography.base(size: 13, weight: 600).copyWith(
          color: enabled ? palette.textPrimary : palette.textSecondary);
      return LayoutBuilder(builder: (context, constraints) {
        final labelWidth = TextWidthCache.of(
          'В корзину',
          labelStyle,
          MediaQuery.textScalerOf(context),
          Directionality.of(context),
        );
        final showLabel =
            labelWidth + 18 + 4 + 16 <= constraints.maxWidth - _inset * 2;
        return Stack(
          children: [
            Positioned(
              left: _inset,
              right: _inset,
              bottom: _inset,
              height: pillHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: addFill,
                  borderRadius: AppRadii.mdAll,
                  boxShadow: enabled && light
                      ? const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
              ),
            ),
            Positioned.fill(
              child: StepTap(
                label: 'Добавить',
                onTap: onIncrement,
                width: double.infinity,
                child: Padding(
                  padding: EdgeInsets.only(top: glyphShift),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 18, color: addGlyph),
                      if (showLabel) ...[
                        const SizedBox(width: 4),
                        ExcludeSemantics(
                          child:
                              Text('В корзину', maxLines: 1, style: labelStyle),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      });
    }
    final basis = quantityUnitLabel(unit);
    final withUnit = formatQuantity(
      quantity.toDouble(),
      basis == null || basis == 'шт' ? '' : basis,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final slot = constraints.maxWidth - _inset * 2 - _glyphZone * 2;
        final fits = TextWidthCache.of(
              withUnit,
              countStyle,
              MediaQuery.textScalerOf(context),
              Directionality.of(context),
            ) <=
            slot;
        final label = fits ? withUnit : formatQuantity(quantity.toDouble(), '');
        return Stack(
          children: [
            pill,
            Positioned(
              left: _inset + _glyphZone,
              right: _inset + _glyphZone,
              bottom: _inset,
              height: pillHeight,
              child: Center(
                child: AnimatedCount(
                  text: label,
                  value: quantity,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: countStyle.copyWith(color: glyph),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: StepTap(
                label: quantity <= step + 0.0001
                    ? 'Удалить из корзины'
                    : 'Уменьшить количество',
                onTap: onDecrement,
                child: icon(
                    quantity <= step + 0.0001
                        ? Icons.delete_outline_rounded
                        : Icons.remove,
                    enabled: onDecrement != null),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: StepTap(
                label: 'Увеличить количество',
                onTap: onIncrement,
                child: icon(Icons.add, enabled: onIncrement != null),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Separate stock-aware quantity actions with a readable fractional count.
class ProductQuantityControl extends StatelessWidget {
  const ProductQuantityControl({
    required this.quantity,
    this.step = 1,
    this.onIncrement,
    this.onDecrement,
    this.unit,
    super.key,
  });

  final num quantity;

  /// One step; at the last step the minus deletes the item.
  final num step;
  final String? unit;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final basis = quantityUnitLabel(unit);
    final label = formatQuantity(
      quantity.toDouble(),
      basis == null || basis == 'шт' ? '' : basis,
    );
    final foreground = onIncrement == null && onDecrement == null
        ? palette.textSecondary
        : palette.textOnAccent;
    return LayoutBuilder(
      builder: (context, constraints) {
        final inline = constraints.maxWidth >=
            AppSpacing.touchTarget * 2 +
                TextWidthCache.of(
                  label,
                  AppTypography.bodyMedium,
                  MediaQuery.textScalerOf(context),
                  Directionality.of(context),
                );
        final count = AnimatedCount(
          text: label,
          value: quantity,
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(color: foreground),
        );
        final actions = Row(
          children: [
            StepTap(
              label: quantity <= step + 0.0001
                  ? 'Удалить из корзины'
                  : 'Уменьшить количество',
              onTap: onDecrement,
              child: Icon(
                quantity <= step + 0.0001
                    ? Icons.delete_outline_rounded
                    : Icons.remove,
                color: onDecrement == null
                    ? palette.textOnAccent.withValues(alpha: 0.5)
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
          child: AnimatedSwap(
            stateKey: quantity <= 0,
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
