import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/money.dart';
import '../../../core/product_view.dart';
import '../../../core/quantity.dart';
import '../../../design/motion.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../model/cart_item.dart';
import '../../../model/item.dart';
import '../../../ui/app_icon.dart';
import '../../../ui/app_icon_button.dart';
import '../../../ui/frosted_dock.dart';
import '../../../ui/motion_widgets.dart';
import '../../../ui/product_hero_header.dart';
import '../../../ui/surfaces.dart';
import '../../../utils/cart_provider.dart';
import '../../../utils/liked_items_provider.dart';
import '../../../utils/bonus_rules.dart';
import '../../../utils/promotion_engine.dart';
import '../../../utils/smart_cart.dart';

/// Product detail — the design's `Описание товара` frames.
///
/// This is the simple-product surface. Products with options or pour containers
/// open the complete configuration editor through `openProduct`.
class ProductPage extends StatefulWidget {
  const ProductPage({
    required this.view,
    this.liked = false,
    this.businessId,
    this.onLike,
    this.onCart,
    super.key,
  });

  final ProductView view;
  final bool liked;
  final int? businessId;

  /// Toggles the favourite flag; the caller owns the API call.
  final VoidCallback? onLike;

  /// Opens the cart; null hides the action bar's cart affordance.
  final VoidCallback? onCart;

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  /// True for a moment after this page added the item, to confirm the change.
  bool _justAdded = false;
  bool _expanded = false;
  double _actionBarHeight = 129;
  late final SmartCartSelection _selection =
      SmartCartSelection(widget.view.source);

  bool _canIncrement(CartProvider cart, double quantity) {
    if (!widget.view.available || cart.hasUnresolvedBusiness) return false;
    // The cart holds exactly what the customer added; a bottled drink steps by one smallest
    // bottle.
    final step = _selection.usesPourFlow
        ? _selection.minBottleVolume
        : widget.view.source.effectiveStepQuantity;
    final reserved = cart.activeDisplayGroups
        .where((group) => group.itemId == widget.view.itemId)
        .fold<double>(0, (sum, group) => sum + group.totalOrderQuantity);
    final stock = widget.view.source.amount;
    return stock == null || reserved + step <= stock + 0.0000001;
  }

  static const double _heroHeight = 320;

  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Adds the first step when the item is not in the cart; once it is, the
  /// same action opens the cart (quantity changes belong to the stepper).
  Future<void> _addToCart() async {
    final cart = context.read<CartProvider>();
    final quantity = cart.getCatalogQuantityForKey(widget.view.catalogKey);
    if (quantity > 0) {
      widget.onCart?.call();
      return;
    }
    if (!_canIncrement(cart, quantity)) return;
    cart.incrementCatalogItem(widget.view.source);
    if (cart.getCatalogQuantityForKey(widget.view.catalogKey) <= 0) return;
    HapticFeedback.lightImpact();
    setState(() => _justAdded = true);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) setState(() => _justAdded = false);
  }

  /// The active `N+M` promotion, its rule and how far the customer is from the next gift.
  ///
  /// Returns null when the item carries no usable gift promotion, so the page keeps the frames'
  /// geometry for ordinary products.
  ///
  /// [onIncrement] adds one more step; the card offers it only when that step
  /// would be free, and never takes it on the customer's behalf.
  Widget? _promotionCard(num quantity, {VoidCallback? onIncrement}) {
    final evaluation = evaluatePromotion(
      quantity: quantity.toDouble(),
      promotions: _activePromotions,
    );
    final award = evaluation.award;
    if (award == null) return null;
    final palette = context.palette;
    final unit = widget.view.unit?.trim().isNotEmpty == true
        ? widget.view.unit!.trim()
        : 'шт';
    String label(double value) => formatQuantity(value, unit);
    final remainder = evaluation.quantity % award.setSize;
    final unlocked = evaluation.giftQuantity > 0 && remainder <= 0.0000001;
    final progress = unlocked ? 1.0 : remainder / award.setSize;
    final bonus = evaluation.bonusQuantity;
    final freeStep = bonus != null &&
        onIncrement != null &&
        quantity > 0 &&
        (bonus - widget.view.source.effectiveStepQuantity).abs() <= 0.0000001;
    final light = Theme.of(context).brightness == Brightness.light;
    return AppSurface(
      fill: _raisedFill(context),
      radius: 18,
      border: light ? null : Border.all(color: palette.divider),
      shadow: light ? AppShadows.control(palette) : null,
      key: const ValueKey('product-promotion'),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(evaluation.name ?? 'Акция',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.title.copyWith(color: palette.gold)),
              ),
              AppPromoChip(
                icon: AppIcons.fire,
                label: evaluation.label!,
                fill: palette.accent,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            promotionRuleText(award, label),
            style: AppTypography.body.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: AppRadii.pillAll,
            child: LinearProgressIndicator(
              key: const ValueKey('product-promotion-progress'),
              value: progress,
              minHeight: 6,
              backgroundColor: palette.divider,
              color: palette.accent,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            unlocked
                ? 'Подарок в корзине: ${label(evaluation.giftQuantity)}'
                : bonus != null
                    ? 'Добавьте ещё ${label(bonus)} — это бесплатно'
                    : 'До подарка: ещё '
                        '${label(evaluation.nextGiftIn ?? award.setSize.toDouble())}',
            key: const ValueKey('product-promotion-state'),
            style: AppTypography.bodySmall.copyWith(
                color: unlocked || bonus != null
                    ? palette.gold
                    : palette.textSecondary),
          ),
          if (freeStep) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              key: const ValueKey('product-promotion-add-free'),
              onPressed: onIncrement,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, AppSpacing.touchTarget),
                foregroundColor: palette.accent,
                side: BorderSide(color: palette.accent),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              ),
              child: Text('+${label(bonus)} в подарок'),
            ),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _activePromotions => [
        for (final promotion
            in widget.view.source.promotions ?? const <ItemPromotion>[])
          if (promotion.isActive) promotion.toJson(),
      ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cartState = context.select<CartProvider, (double, bool)>((cart) {
      final quantity = cart.getCatalogQuantityForKey(widget.view.catalogKey);
      return (quantity, _canIncrement(cart, quantity));
    });
    final liked = widget.businessId == null
        ? widget.liked
        : context.select<LikedItemsProvider, bool>(
            (likes) => likes.isLiked(widget.businessId!, widget.view.itemId));
    final quantity = cartState.$1;
    final canIncrement = cartState.$2;
    final pageColor = Theme.of(context).brightness == Brightness.light
        ? palette.surface
        : palette.background;
    final total = CartItem.calculatePrice([
      CartItem(
        itemId: widget.view.itemId,
        name: widget.view.source.name,
        price: widget.view.source.price,
        quantity:
            quantity > 0 ? quantity : widget.view.source.effectiveStepQuantity,
        stepQuantity: widget.view.source.effectiveStepQuantity,
        selectedVariants: const [],
        promotions: _activePromotions,
        itemData: widget.view.source.toJson(),
      ),
    ]).totalPrice;
    final points = widget.view.available && widget.view.bonusEligible
        ? BonusRules.calculateEarnedBonuses(total)
        : 0;

    return Scaffold(
      backgroundColor: pageColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: FrostedDock(
            content: ColoredBox(
              color: pageColor,
              child: Stack(
                children: [
                  SingleChildScrollView(
                    controller: _scroll,
                    padding: EdgeInsets.only(
                      bottom: _actionBarHeight +
                          MediaQuery.paddingOf(context).bottom +
                          AppSpacing.xl * 2,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Hero(
                          imageUrl: widget.view.imageUrl,
                          height: _heroHeight,
                          label: widget.view.title,
                        ),
                        const SizedBox(height: AppSpacing.xxxl),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xxxl),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _TitleBlock(view: widget.view)),
                              if (widget.view.discount != null ||
                                  points > 0) ...[
                                const SizedBox(width: AppSpacing.xl),
                                _Badges(
                                  discount: widget.view.discount,
                                  bonus: points > 0 ? '+$points' : null,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (_specLabels(widget.view).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.xxxl,
                                AppSpacing.xl, AppSpacing.xxxl, 0),
                            child: _SpecChips(view: widget.view),
                          ),
                        const SizedBox(height: AppSpacing.huge),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xxxl),
                          child: _PriceStack(view: widget.view),
                        ),
                        const SizedBox(height: AppSpacing.huge),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xxxl),
                          child: _QuantityControl(
                            quantity: quantity > 0
                                ? quantity
                                : (canIncrement
                                    ? widget.view.source.effectiveStepQuantity
                                    : 0),
                            inCart: quantity > 0,
                            unit: widget.view.unit,
                            onIncrement: canIncrement
                                ? () => context
                                    .read<CartProvider>()
                                    .incrementCatalogItem(widget.view.source)
                                : null,
                            onDecrement: quantity > 0
                                ? () => context
                                    .read<CartProvider>()
                                    .decrementCatalogItem(widget.view.source)
                                : null,
                          ),
                        ),
                        if (_promotionCard(quantity,
                                onIncrement: canIncrement
                                    ? () => context
                                        .read<CartProvider>()
                                        .incrementCatalogItem(
                                            widget.view.source)
                                    : null)
                            case final promoCard?) ...[
                          const SizedBox(height: AppSpacing.huge),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xxxl),
                            child: promoCard,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.huge),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xxxl),
                          child: _Description(
                            text: widget.view.source.description ?? '',
                            expanded: _expanded,
                            onToggle: () =>
                                setState(() => _expanded = !_expanded),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ProductHeroHeader(
                      controller: _scroll,
                      heroHeight: _heroHeight,
                      title: widget.view.title,
                      background: pageColor,
                      leading: AppIconButton(
                        asset: AppIcons.back,
                        onTap: () => Navigator.of(context).maybePop(),
                        tooltip: 'Назад',
                      ),
                      trailing: AnimatedSwap(
                        stateKey: liked,
                        duration: AppMotion.pop,
                        scale: .6,
                        scaleCurve: AppMotion.overshoot,
                        child: AppIconButton(
                          asset: liked ? AppIcons.heartFilled : AppIcons.heart,
                          onTap: widget.onLike,
                          tooltip: 'В избранное',
                          size: AppSpacing.touchTarget,
                          glyphSize: 24,
                          fill: liked ? AppIconButton.likedFill(palette) : null,
                          color: liked ? Colors.white : palette.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            dock: _ActionBar(
              total: total,
              inCartQuantity: quantity > 0
                  ? formatQuantity(
                      quantity, quantityUnitLabel(widget.view.unit) ?? 'шт')
                  : null,
              justAdded: _justAdded,
              onAdd: quantity > 0
                  ? widget.onCart
                  : canIncrement
                      ? _addToCart
                      : null,
            ),
            onDockHeightChanged: (height) {
              if ((height - _actionBarHeight).abs() > 0.5) {
                setState(() => _actionBarHeight = height);
              }
            },
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.imageUrl, required this.height, this.label});

  final String? imageUrl;
  final double height;
  final String? label;

  static const Widget _placeholder =
      Icon(Icons.inventory_2_outlined, color: Colors.black38, size: 56);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: Container(
        height: height,
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(32, 88, 32, 16),
        child: imageUrl == null
            ? _placeholder
            : Image.network(
                imageUrl!,
                fit: BoxFit.contain,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
                frameBuilder: fadeInImageFrame,
                // The artwork box is height - 104 tall; decode no larger than it.
                cacheHeight: ((height - 104).clamp(1.0, height) *
                        MediaQuery.devicePixelRatioOf(context))
                    .ceil(),
                semanticLabel: label,
                errorBuilder: (_, __, ___) => _placeholder,
              ),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.view});

  final ProductView view;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final category = _categoryLabel(view);
    final country = _clean(view.country);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (category != null || country != null)
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              if (category != null)
                Text(category,
                    style: AppTypography.label
                        .copyWith(color: palette.textSecondary)),
              if (country != null)
                Text(country,
                    style: AppTypography.label.copyWith(color: palette.gold)),
            ],
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          view.title,
          softWrap: true,
          style: AppTypography.displayBold.copyWith(color: palette.textPrimary),
        ),
      ],
    );
  }
}

class _Badges extends StatelessWidget {
  const _Badges({this.discount, this.bonus});

  final String? discount;
  final String? bonus;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (discount != null)
          AppPromoChip(
              icon: AppIcons.fire, label: discount!, fill: palette.brandRed),
        if (discount != null && bonus != null) const SizedBox(height: 8),
        if (bonus != null)
          Tooltip(
            message: 'Предварительная оценка бонусов',
            child: AppPromoChip(
                icon: AppIcons.bonusStar,
                label: bonus!,
                fill: const Color(0xFFE0AB62),
                foreground: Colors.black),
          ),
      ],
    );
  }
}

class _PriceStack extends StatelessWidget {
  const _PriceStack({required this.view});

  final ProductView view;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (view.oldPrice != null)
          Text(
            formatTenge(view.oldPrice!),
            style: AppTypography.titleRegular.copyWith(
              color: palette.textSecondary,
              decoration: TextDecoration.lineThrough,
              height: 1.3,
            ),
          ),
        Text(
          view.unitPriceUnit == 'шт'
              ? formatTenge(view.discountedUnitPrice)
              : view.unitPriceLabel,
          style: AppTypography.base(size: 32, weight: 700)
              .copyWith(color: palette.accent),
        ),
        if (view.saving != null)
          Text(
            'Выгода ${formatTenge(view.saving!)}',
            style: AppTypography.titleMedium.copyWith(color: palette.gold),
          ),
      ],
    );
  }
}

/// White (light) / surface (dark) card with the frame's soft shadow, shared by the quantity
/// stepper and the spec chips.
Color _raisedFill(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : context.palette.surface;

class _QuantityControl extends StatelessWidget {
  const _QuantityControl({
    required this.quantity,
    required this.inCart,
    this.unit,
    this.onIncrement,
    this.onDecrement,
  });

  /// What the stepper shows: the cart quantity, or — before the item is in the cart — the
  /// step that «+» and «В корзину» will add.
  final num quantity;
  final bool inCart;
  final String? unit;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  String get _label => formatQuantity(quantity.toDouble(), unit ?? 'шт');

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final light = Theme.of(context).brightness == Brightness.light;
    final pending = !inCart && quantity > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Количество',
          style:
              AppTypography.titleRegular.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        AppSurface(
          radius: 18,
          fill: _raisedFill(context),
          padding: const EdgeInsets.all(5),
          border: light ? null : Border.all(color: palette.divider),
          shadow: light ? AppShadows.control(palette) : null,
          child: Row(
            children: [
              _square(palette, onDecrement, Icons.remove_rounded, 'Уменьшить'),
              Expanded(
                child: Semantics(
                  label:
                      pending ? 'Количество: $_label, ещё не в корзине' : null,
                  child: AnimatedCount(
                    text: _label,
                    value: quantity,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.base(size: 20, weight: 500).copyWith(
                        color: pending
                            ? palette.textSecondary
                            : palette.textPrimary),
                  ),
                ),
              ),
              _square(palette, onIncrement, Icons.add_rounded, 'Увеличить'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _square(
      AppPalette palette, VoidCallback? onTap, IconData glyph, String tooltip) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(
        foregroundColor: palette.textOnAccent,
        backgroundColor: palette.accent,
        disabledForegroundColor: palette.textOnAccent,
        disabledBackgroundColor: palette.accent.withValues(alpha: 0.35),
        fixedSize: const Size.square(AppSpacing.touchTarget),
        minimumSize: const Size.square(AppSpacing.touchTarget),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg)),
      ),
      icon: Icon(glyph, size: 24),
    );
  }
}

/// Facts the header does not already show: type, packaging, material, volume, weight, ABV.
///
/// Category and country sit above the title, so anything equal to them is dropped rather
/// than repeated.
class _SpecChips extends StatelessWidget {
  const _SpecChips({required this.view});

  final ProductView view;

  @override
  Widget build(BuildContext context) {
    final specs = _specLabels(view);
    if (specs.isEmpty) return const SizedBox.shrink();
    final palette = context.palette;
    final light = Theme.of(context).brightness == Brightness.light;
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final spec in specs)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: _raisedFill(context),
              borderRadius: AppRadii.pillAll,
              border: light ? null : Border.all(color: palette.divider),
            ),
            child: Text(
              spec,
              style: AppTypography.captionMedium
                  .copyWith(color: palette.textSecondary),
            ),
          ),
      ],
    );
  }
}

String? _clean(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// The grey label above the title: the API category, else the item type.
String? _categoryLabel(ProductView view) =>
    _clean(view.category) ?? _clean(view.type);

List<String> _specLabels(ProductView view) {
  final seen = <String>{};
  for (final shown in [_categoryLabel(view), _clean(view.country)]) {
    if (shown != null) seen.add(shown.toLowerCase());
  }
  final alcohol = _clean(view.alcoholLabel);
  final result = <String>[];
  for (final spec in [
    _clean(view.type),
    _clean(view.packagingType),
    _clean(view.material),
    _clean(view.volume),
    _clean(view.weightLabel),
    alcohol == null ? null : 'Крепость $alcohol',
  ]) {
    if (spec != null && seen.add(spec.toLowerCase())) result.add(spec);
  }
  return result;
}

/// «Описание» with the frame's clamp-and-toggle behaviour.
class _Description extends StatelessWidget {
  const _Description({
    required this.text,
    required this.expanded,
    this.onToggle,
  });

  final String text;
  final bool expanded;
  final VoidCallback? onToggle;

  static const int _clampLines = 6;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Catalogue placeholders such as "." carry no description to show.
    if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(text)) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ОПИСАНИЕ',
          semanticsLabel: 'Описание',
          style: AppTypography.title.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xxl),
        LayoutBuilder(
          builder: (context, constraints) {
            final style = AppTypography.bodySmallMedium
                .copyWith(color: palette.textSecondary, height: 1.3);
            final painter = TextPainter(
              text: TextSpan(text: text, style: style),
              maxLines: _clampLines,
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout(maxWidth: constraints.maxWidth);
            final overflows = painter.didExceedMaxLines;
            painter.dispose();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: style,
                  maxLines: expanded ? null : _clampLines,
                  overflow: expanded ? TextOverflow.visible : TextOverflow.clip,
                ),
                if (overflows) ...[
                  const SizedBox(height: AppSpacing.lg),
                  TextButton(
                    onPressed: onToggle,
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(44, 44),
                    ),
                    child: Text(
                      expanded ? 'Свернуть' : 'Читать далее',
                      style: AppTypography.bodyBold
                          .copyWith(color: palette.accent),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Sharp action foreground; the parent supplies the refractive material.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.total,
    required this.inCartQuantity,
    required this.justAdded,
    this.onAdd,
  });

  final num total;

  /// The formatted cart quantity, or null while the item is not in the cart.
  final String? inCartQuantity;
  final bool justAdded;

  /// Adds the item, or opens the cart once it is there; null when neither is possible.
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final inCart = inCartQuantity != null;
    return Padding(
      // The dock supplies the 16px sides and the safe-area inset below.
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.xxxl, 0, AppSpacing.xl),
      child: LayoutBuilder(builder: (context, constraints) {
        final adaptive = constraints.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(16) > 20;
        final summary = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatTenge(total),
              style: AppTypography.base(size: 24, weight: 700)
                  .copyWith(color: palette.textPrimary),
            ),
            if (inCart)
              Text(
                'В корзине: $inCartQuantity',
                style: AppTypography.bodySmall
                    .copyWith(color: palette.textSecondary),
              ),
          ],
        );
        final String label;
        final Widget? icon;
        if (onAdd == null && !inCart) {
          label = 'Нет в наличии';
          icon = null;
        } else if (justAdded) {
          label = 'Добавлено';
          icon = const Icon(Icons.check_rounded, size: 20);
        } else if (inCart) {
          label = onAdd == null ? 'В корзине' : 'Перейти в корзину';
          icon = null;
        } else {
          label = 'В корзину';
          icon = null;
        }
        final action = AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: FilledButton(
            key: ValueKey(label),
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              minimumSize: const Size(175, 49),
              shape: const StadiumBorder(),
              backgroundColor: justAdded ? palette.success : palette.accent,
              foregroundColor: justAdded ? Colors.black : palette.textOnAccent,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[icon, const SizedBox(width: 6)],
                Text(label),
              ],
            ),
          ),
        );
        return Semantics(
          liveRegion: true,
          child: adaptive
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    summary,
                    const SizedBox(height: AppSpacing.md),
                    action,
                  ],
                )
              : Row(children: [
                  Expanded(child: summary),
                  const SizedBox(width: AppSpacing.md),
                  action,
                ]),
        );
      }),
    );
  }
}
