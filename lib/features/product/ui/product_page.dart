import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/money.dart';
import '../../../core/product_view.dart';
import '../../../core/quantity.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../model/cart_item.dart';
import '../../../model/item.dart';
import '../../../ui/app_icon.dart';
import '../../../ui/app_icon_button.dart';
import '../../../ui/surfaces.dart';
import '../../../utils/cart_provider.dart';
import '../../../utils/liked_items_provider.dart';
import '../../../utils/bonus_rules.dart';
import '../../../utils/promotion_engine.dart';

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
  bool _added = false;
  bool _expanded = false;
  bool _canIncrement(CartProvider cart, double quantity) {
    if (!widget.view.available || cart.hasUnresolvedBusiness) return false;
    final next = quantity + widget.view.source.effectiveStepQuantity;
    final reserved = cart.activeDisplayGroups
        .where((group) => group.itemId == widget.view.itemId)
        .fold<double>(0, (sum, group) => sum + group.totalOrderQuantity);
    final current = quantity +
        subtractPromotionFreeQuantity(quantity, _activePromotions);
    final required = next + subtractPromotionFreeQuantity(next, _activePromotions);
    final stock = widget.view.source.amount;
    return stock == null || reserved - current + required <= stock + 0.0000001;
  }

  static const double _heroHeight = 320;
  static const double _actionBarHeight = 129;

  Future<void> _addToCart() async {
    final cart = context.read<CartProvider>();
    final quantity = cart.getCatalogQuantity(widget.view.source);
    if (quantity <= 0) {
      if (!_canIncrement(cart, quantity)) return;
      cart.incrementCatalogItem(widget.view.source);
    }
    if (cart.getCatalogQuantity(widget.view.source) <= 0) return;
    setState(() => _added = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _added = false);
  }

  /// The active `N+M` promotion, its rule and how far the customer is from the next gift.
  ///
  /// Returns null when the item carries no usable gift promotion, so the page keeps the frames'
  /// geometry for ordinary products.
  Widget? _promotionCard(num quantity) {
    final evaluation = evaluatePromotion(
      paidQuantity: quantity.toDouble(),
      promotions: _activePromotions,
    );
    final award = evaluation.award;
    if (award == null) return null;
    final palette = context.palette;
    final unit = widget.view.unit?.trim().isNotEmpty == true
        ? widget.view.unit!.trim()
        : 'шт';
    final unlocked = evaluation.unlocked && evaluation.freeQuantity > 0;
    return AppSurface(
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
            'За каждые ${formatQuantity(award.baseAmount.toDouble(), unit)} — '
            '${formatQuantity(award.addAmount.toDouble(), unit)} в подарок',
            style: AppTypography.body.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: AppRadii.pillAll,
            child: LinearProgressIndicator(
              key: const ValueKey('product-promotion-progress'),
              value: unlocked ? 1 : evaluation.progress,
              minHeight: 6,
              backgroundColor: palette.surfaceMuted,
              color: palette.accent,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            unlocked
                ? 'Подарок в корзине: '
                    '${formatQuantity(evaluation.freeQuantity, unit)}'
                : 'Добавьте ещё ${formatQuantity(evaluation.nextGiftIn, unit)}, '
                    'чтобы получить подарок',
            key: const ValueKey('product-promotion-state'),
            style: AppTypography.bodySmall.copyWith(
                color: unlocked ? palette.gold : palette.textSecondary),
          ),
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
    final cart = context.watch<CartProvider>();
    final liked = widget.businessId == null
        ? widget.liked
        : context
            .watch<LikedItemsProvider>()
            .isLiked(widget.businessId!, widget.view.itemId);
    final quantity = cart.getCatalogQuantity(widget.view.source);
    final topInset = MediaQuery.paddingOf(context).top;
    final total = CartItem.calculatePrice([
      CartItem(
        itemId: widget.view.itemId,
        name: widget.view.source.name,
        price: widget.view.source.price,
        quantity: quantity > 0
            ? quantity
            : widget.view.source.effectiveStepQuantity,
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
      backgroundColor: Theme.of(context).brightness == Brightness.light
          ? palette.surface
          : palette.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: _actionBarHeight +
                  MediaQuery.paddingOf(context).bottom +
                  AppSpacing.huge +
                  (MediaQuery.textScalerOf(context).scale(16) > 20 ? 120 : 0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Hero(imageUrl: widget.view.imageUrl, height: _heroHeight),
                const SizedBox(height: AppSpacing.xxxl),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _TitleBlock(view: widget.view)),
                      if (widget.view.discount != null || points > 0)
                        _Badges(
                          discount: widget.view.discount,
                          bonus: points > 0 ? '+$points' : null,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.huge),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                  child: _PriceStack(view: widget.view),
                ),
                const SizedBox(height: AppSpacing.huge),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                  child: _QuantityControl(
                    quantity: quantity,
                    unit: widget.view.unit,
                    onIncrement: _canIncrement(cart, quantity)
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
                if (_promotionCard(quantity) case final promoCard?) ...[
                  const SizedBox(height: AppSpacing.huge),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                    child: promoCard,
                  ),
                ],
                const SizedBox(height: AppSpacing.huge),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                  child: _Description(
                    text: widget.view.source.description ?? '',
                    expanded: _expanded,
                    onToggle: () => setState(() => _expanded = !_expanded),
                  ),
                ),
              ],
            ),
          ),
          // Fixed header: the frames keep it at y = 70 while the hero scrolls away.
          Positioned(
            left: AppSpacing.xxxl,
            right: AppSpacing.xxxl,
            top: topInset + 22,
            child: SizedBox(
              height: 57,
              child: Row(
                children: [
                  AppIconButton(
                    asset: AppIcons.back,
                    onTap: () => Navigator.of(context).maybePop(),
                    tooltip: 'Назад',
                  ),
                  const Spacer(),
                  AppIconButton(
                    // The design keeps the outline heart in both states and only tints the
                    // disc, so no filled glyph is needed here.
                    asset: AppIcons.heart,
                    onTap: widget.onLike,
                    tooltip: 'В избранное',
                    size: AppSpacing.touchTarget,
                    glyphSize: 24,
                    fill: liked
                        ? palette.brandRed.withValues(alpha: 0.5)
                        : palette.surface.withValues(alpha: 0.75),
                    color: liked ? Colors.white : palette.textPrimary,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ActionBar(
              total: total,
              added: _added,
              onAdd: quantity > 0 || _canIncrement(cart, quantity)
                  ? _addToCart
                  : null,
              onCart: widget.onCart,
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.imageUrl, required this.height});

  final String? imageUrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: Container(
        height: height,
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(48, 88, 48, 16),
        child: imageUrl == null
            ? const Icon(Icons.inventory_2_outlined, color: Colors.black38, size: 56)
            : Image.network(
                imageUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.inventory_2_outlined, color: Colors.black38, size: 56),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (view.category != null)
          Text(
            view.category!,
            style: AppTypography.bodySmall.copyWith(color: palette.textSecondary),
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          view.title,
          softWrap: true,
          style: AppTypography.displayBold.copyWith(color: palette.textPrimary),
        ),
        if (view.metadata.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            view.metadata.where((part) =>
                part.toLowerCase() != view.category?.toLowerCase()).join(' · '),
            style: AppTypography.bodySmall.copyWith(color: palette.textSecondary),
          ),
        ],
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
          AppPromoChip(icon: AppIcons.fire, label: discount!, fill: palette.brandRed),
        if (discount != null && bonus != null) const SizedBox(height: 8),
        if (bonus != null)
          Tooltip(
            message: 'Предварительная оценка бонусов',
            child: AppPromoChip(
                icon: AppIcons.bonusStar, label: bonus!, fill: palette.gold,
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
          view.unitPriceLabel,
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

class _QuantityControl extends StatelessWidget {
  const _QuantityControl({
    required this.quantity,
    this.unit,
    this.onIncrement,
    this.onDecrement,
  });

  final num quantity;
  final String? unit;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  String get _label => formatQuantity(quantity.toDouble(), unit ?? 'шт');

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
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
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Row(
            children: [
              _square(palette, onDecrement,
                  const Icon(Icons.remove_rounded), 'Уменьшить'),
              Expanded(
                child: Text(
                  _label,
                  textAlign: TextAlign.center,
                  style: AppTypography.base(size: 20, weight: 500)
                      .copyWith(color: palette.textPrimary),
                ),
              ),
              _square(palette, onIncrement,
                  const Icon(Icons.add_rounded), 'Увеличить'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _square(
      AppPalette palette, VoidCallback? onTap, Widget glyph, String tooltip) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(
        foregroundColor: palette.textOnAccent,
        minimumSize: const Size.square(AppSpacing.touchTarget),
        backgroundColor:
            onTap == null ? palette.accentFaint : palette.accentSoft,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg)),
      ),
      icon: glyph,
    );
  }
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
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Описание',
          style: AppTypography.title.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xxl),
        LayoutBuilder(
          builder: (context, constraints) {
            final style = AppTypography.bodyMedium
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

/// Glass action bar: total plus «В корзину», switching to the success pill once added.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.total,
    required this.added,
    this.onAdd,
    this.onCart,
  });

  final num total;
  final bool added;
  final VoidCallback? onAdd;
  final VoidCallback? onCart;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppGlassPanel(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(builder: (context, constraints) {
          final adaptive = constraints.maxWidth < 320 ||
              MediaQuery.textScalerOf(context).scale(16) > 20;
          final summary = Text(
            formatTenge(total),
            style: AppTypography.base(size: 24, weight: 700)
                .copyWith(color: palette.textPrimary),
          );
          final action = FilledButton(
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              minimumSize: const Size(175, 49),
              shape: const StadiumBorder(),
            ),
            child: Text(onAdd == null ? 'Нет в наличии' : 'В корзину'),
          );
          if (added) {
            return Semantics(
              liveRegion: true,
              child: AppGlassPanel(
                radius: AppRadii.pill,
                tint: palette.success.withValues(alpha: 0.75),
                child: InkWell(
                  onTap: onCart,
                  borderRadius: AppRadii.pillAll,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AppIcon(AppIcons.check,
                            size: 26, color: Colors.white),
                        const SizedBox(width: AppSpacing.xl),
                        Flexible(
                          child: Text(
                            'Добавлено в корзину',
                            textAlign: TextAlign.center,
                            style: AppTypography.title
                                .copyWith(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
          return adaptive
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
                ]);
        }),
      ),
    );
  }
}
