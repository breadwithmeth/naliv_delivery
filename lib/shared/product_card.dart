import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/item.dart' as item_model;
import '../utils/cart_provider.dart';
import '../models/cart_item.dart';
import '../globals.dart' as globals;
import '../pages/product_detail_page.dart';
import '../utils/api.dart';
import '../utils/bonus_rules.dart';
import '../utils/liked_storage_service.dart';
import '../utils/business_provider.dart';
import '../utils/item_name_presentation.dart';
import '../utils/liked_items_provider.dart';
import '../utils/responsive.dart';

class ProductCard extends StatefulWidget {
  final item_model.Item item;

  const ProductCard({super.key, required this.item});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  // ─── Palette (mainPage) ──────────────────────────────────
  static const Color _card = Color(0xFF1E1E1E);
  static const Color _cardDark = Color(0xFF181818);
  static const Color _orange = Color(0xFFF6A10C);
  static const Color _red = Color(0xFFC23B30);
  static const Color _purple = Color(0xFF8B5CF6);
  static const Color _text = Colors.white;
  static const Color _textMute = Color(0xFF9FB0C8);

  bool _likeInProgress = false;
  bool? _isLikedOverride;
  int? _businessId;

  bool get _isLiked => _isLikedOverride ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
    final bid = businessProvider.selectedBusinessId;
    if (bid != null && bid != _businessId) {
      _businessId = bid;
      _initLikeState(bid);
    }
  }

  Future<void> _initLikeState(int businessId) async {
    final likedProvider = Provider.of<LikedItemsProvider>(context, listen: false);
    final providerLiked = likedProvider.isLiked(businessId, widget.item.itemId);
    if (providerLiked) {
      _isLikedOverride = true;
      setState(() {});
      return;
    }
    final liked = await LikedStorageService.isLiked(
      businessId: businessId,
      itemId: widget.item.itemId,
    );
    if (mounted) {
      setState(() => _isLikedOverride = liked);
      if (liked) {
        likedProvider.updateLike(businessId, widget.item.itemId, true);
      }
    }
  }

  Future<void> _toggleLike() async {
    if (_likeInProgress) return;
    setState(() => _likeInProgress = true);
    final likedProvider = Provider.of<LikedItemsProvider>(context, listen: false);
    try {
      final newValue = await ApiService.toggleLikeItem(widget.item.itemId);
      if (newValue != null && mounted) {
        setState(() => _isLikedOverride = newValue);
        if (_businessId != null) {
          LikedStorageService.setLiked(
            businessId: _businessId!,
            itemId: widget.item.itemId,
            liked: newValue,
          );
          likedProvider.updateLike(_businessId!, widget.item.itemId, newValue);
        }
      }
    } finally {
      if (mounted) setState(() => _likeInProgress = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final itemTitle = presentItemName(
      rawName: item.name,
      categoryName: item.category?.name,
    );
    final isWeightItem = _isWeightUnit(item.unit);
    final portionWeight = _resolvePortionWeight(item);
    final activePromotions = _activePromotions(item);
    final discountPromo = _primaryDiscountPromo(activePromotions);
    final subtractPromotions = _subtractPromotions(activePromotions);
    final isOutOfStock = item.amount != null && item.amount! <= 0;

    // Promotion calculations
    final hasDiscount = discountPromo != null;
    final discountedPrice = discountPromo?.calculateDiscountedPrice(item.price) ?? item.price;
    final discountPercent = discountPromo?.calculateEffectiveDiscountPercent(item.price) ?? 0;
    final isLowStock = !isOutOfStock && item.amount != null && item.amount! > 0 && item.amount! <= 5;
    final savingsAmount = hasDiscount ? (item.price - discountedPrice) * (isWeightItem && portionWeight > 0 ? portionWeight : 1) : 0.0;
    final bonusPoints = isOutOfStock ? 0 : _calculateBonusPoints(item, discountedPrice);
    final portionPrice = isWeightItem && portionWeight > 0 ? discountedPrice * portionWeight : null;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductDetailPage(item: item)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14.s),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Image ──
            _imageSection(
              item,
              hasDiscount,
              discountPercent,
              isLowStock,
              isOutOfStock,
              subtractPromotions,
              bonusPoints,
            ),

            // ── Info ──
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(9.s, 7.s, 9.s, 9.s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (itemTitle.type != null || itemTitle.countryName != null) ...[
                      Row(
                        children: [
                          if (itemTitle.type != null)
                            Expanded(
                              child: Text(
                                itemTitle.type!,
                                style: TextStyle(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w700,
                                  color: _textMute.withValues(alpha: 0.92),
                                  height: 1.15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          else
                            const Spacer(),
                          if (itemTitle.countryName != null)
                            Text(
                              itemTitle.countryName!,
                              style: TextStyle(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w800,
                                color: _orange.withValues(alpha: 0.92),
                                height: 1.15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                      SizedBox(height: 4.s),
                    ],
                    Text(
                      itemTitle.name,
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w800,
                        color: _text,
                        height: 1.22,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const Spacer(),

                    // ── Price ──
                    ..._priceBlock(
                      basePrice: item.price,
                      discountedPrice: discountedPrice,
                      hasDiscount: hasDiscount,
                      savingsAmount: savingsAmount,
                      isWeightItem: isWeightItem,
                      portionWeight: portionWeight,
                      portionPrice: portionPrice,
                      unit: item.unit,
                      pricingAttributes: itemTitle.pricingAttributes,
                    ),

                    SizedBox(height: 7.s),

                    // ── Cart button ──
                    _cartSection(item),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Image section ───────────────────────────────────────
  Widget _imageSection(
    item_model.Item item,
    bool hasDiscount,
    int discountPercent,
    bool isLowStock,
    bool isOutOfStock,
    List<item_model.ItemPromotion> subtractPromotions,
    int bonusPoints,
  ) {
    final hasBottomMeta = item.hasOptions || bonusPoints > 0;
    return AspectRatio(
      aspectRatio: 1.0,
      child: Stack(
        children: [
          // Product image
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14.s),
                topRight: Radius.circular(14.s),
              ),
              child: Container(
                color: item.hasImage ? Colors.white : _cardDark,
                child: item.hasImage
                    ? Image.network(
                        item.image!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(Icons.inventory_2_outlined, color: _textMute, size: 42.s),
                        ),
                      )
                    : Center(
                        child: Icon(Icons.inventory_2_outlined, color: _textMute, size: 42.s),
                      ),
              ),
            ),
          ),

          if (hasBottomMeta)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 42.s,
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14.s),
                  topRight: Radius.circular(14.s),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Top-left badges column ──
          Positioned(
            top: 8.s,
            left: 8.s,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasDiscount && discountPercent > 0) _discountBadge(discountPercent),
                ...subtractPromotions.map(
                  (promotion) => Padding(
                    padding: EdgeInsets.only(top: 6.s),
                    child: _subtractPromoBadge(promotion),
                  ),
                ),
                if (isOutOfStock || isLowStock)
                  Padding(
                    padding: EdgeInsets.only(
                      top: (hasDiscount && discountPercent > 0) || subtractPromotions.isNotEmpty ? 6.s : 0,
                    ),
                    child: _statusBadge(
                      isOutOfStock ? 'Нет в наличии' : 'Мало',
                      background: isOutOfStock ? Colors.black.withValues(alpha: 0.72) : Colors.black.withValues(alpha: 0.68),
                      foreground: isOutOfStock ? Colors.white.withValues(alpha: 0.92) : _orange,
                    ),
                  ),
              ],
            ),
          ),

          // ── Top-right like button ──
          Positioned(
            top: 8.s,
            right: 8.s,
            child: GestureDetector(
              onTap: _toggleLike,
              child: Container(
                padding: EdgeInsets.all(8.s),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 16.s,
                  color: _isLiked ? _red : Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),

          if (hasBottomMeta)
            Positioned(
              bottom: 7.s,
              left: 7.s,
              right: 7.s,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (item.hasOptions) _optionBadge(item),
                      ],
                    ),
                  ),
                  if (bonusPoints > 0) ...[
                    const SizedBox(width: 4),
                    _bonusBadge(bonusPoints),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusBadge(
    String label, {
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.s, vertical: 4.s),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8.s),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w800,
          color: foreground,
          height: 1.1,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _discountBadge(int discountPercent) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.s, vertical: 5.s),
      decoration: BoxDecoration(
        color: _red,
        borderRadius: BorderRadius.circular(9.s),
        boxShadow: [
          BoxShadow(
            color: _red.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, size: 12.s, color: Colors.white),
          SizedBox(width: 5.s),
          Text(
            '-$discountPercent%',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _subtractPromoBadge(item_model.ItemPromotion promotion) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.s, vertical: 4.s),
      decoration: BoxDecoration(
        color: _orange,
        borderRadius: BorderRadius.circular(8.s),
        boxShadow: [
          BoxShadow(
            color: _orange.withValues(alpha: 0.28),
            blurRadius: 7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.card_giftcard_rounded, size: 11.s, color: Colors.black),
          SizedBox(width: 4.s),
          Text(
            _subtractPromoLabel(promotion),
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  String _subtractPromoLabel(item_model.ItemPromotion promotion) {
    if (promotion.baseAmount > 0 && promotion.addAmount > 0) {
      return '${promotion.baseAmount}+${promotion.addAmount}';
    }
    final fallback = (promotion.description?.trim().isNotEmpty ?? false) ? promotion.description!.trim() : promotion.name.trim();
    return fallback.isEmpty ? 'Промо' : fallback;
  }

  List<item_model.ItemPromotion> _activePromotions(item_model.Item item) {
    return (item.promotions ?? const <item_model.ItemPromotion>[]).where((promotion) => promotion.isActive).toList(growable: false);
  }

  item_model.ItemPromotion? _primaryDiscountPromo(List<item_model.ItemPromotion> promotions) {
    for (final promotion in promotions) {
      final isDiscountType = promotion.discountType == 'PERCENT' || promotion.discountType == 'FIXED';
      if (isDiscountType && promotion.discountValue > 0) {
        return promotion;
      }
    }
    return null;
  }

  List<item_model.ItemPromotion> _subtractPromotions(List<item_model.ItemPromotion> promotions) {
    return promotions
        .where((promotion) => promotion.discountType == 'SUBTRACT' && promotion.baseAmount > 0 && promotion.addAmount > 0)
        .toList(growable: false);
  }

  // ─── Option badge (shows option names) ───────────────────
  Widget _optionBadge(item_model.Item item) {
    // Show first option names like "Объём • Крепость" instead of generic count
    final optionNames = item.options!.take(2).map((o) => o.name).join(' • ');
    final extra = item.options!.length > 2 ? ' +${item.options!.length - 2}' : '';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.s, vertical: 3.s),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6.s),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.tune, size: 9.s, color: _text),
          SizedBox(width: 3.s),
          Flexible(
            child: Text(
              '$optionNames$extra',
              style: TextStyle(
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
                color: _text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bonus points badge ──────────────────────────────────
  Widget _bonusBadge(int points) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.s, vertical: 3.s),
      decoration: BoxDecoration(
        color: _purple,
        borderRadius: BorderRadius.circular(6.s),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 10.s, color: Colors.white),
          SizedBox(width: 2.s),
          Text(
            '+$points',
            style: TextStyle(
              fontSize: 9.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bonus calculation helpers ──────────────────────────
  int _calculateBonusPoints(item_model.Item item, double price) {
    if (BonusRules.isBonusExcludedText(
      name: item.name,
      description: item.description,
      categoryName: item.category?.name,
      code: item.code,
    )) {
      return 0;
    }

    return BonusRules.calculateEarnedBonuses(price);
  }

  // ─── Price helpers ───────────────────────────────────────
  List<Widget> _priceBlock({
    required double basePrice,
    required double discountedPrice,
    required bool hasDiscount,
    required double savingsAmount,
    required bool isWeightItem,
    required double portionWeight,
    required double? portionPrice,
    required String? unit,
    required List<String> pricingAttributes,
  }) {
    final portionLabel = isWeightItem && portionWeight > 0 ? globals.formatQuantity(portionWeight, unit ?? 'кг') : null;

    final mainPrice = portionPrice ?? discountedPrice;
    final oldPrice = hasDiscount ? (portionPrice != null ? basePrice * portionWeight : basePrice) : null;

    return [
      if (hasDiscount && oldPrice != null) ...[
        Text(
          '${_formatPrice(oldPrice)} ₸',
          style: TextStyle(
            fontSize: 10.sp,
            color: _textMute.withValues(alpha: 0.45),
            decoration: TextDecoration.lineThrough,
            decorationColor: _textMute.withValues(alpha: 0.45),
            height: 1.1,
          ),
        ),
        SizedBox(height: 2.s),
      ],
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_formatPrice(mainPrice)} ₸',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w900,
                    color: _text,
                    height: 1.05,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (hasDiscount && savingsAmount >= 1) ...[
                  SizedBox(height: 2.s),
                  Text(
                    'Выгода ${_formatPrice(savingsAmount)} ₸',
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w700,
                      color: _orange,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (pricingAttributes.isNotEmpty) ...[
            SizedBox(width: 10.s),
            _pricingAccentBlock(pricingAttributes),
          ],
        ],
      ),
      if (portionLabel != null) ...[
        SizedBox(height: 2.s),
        Text(
          'за $portionLabel',
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
            color: _textMute,
            height: 1.1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
      if (isWeightItem) ...[
        SizedBox(height: 3.s),
        Text(
          '${_formatPrice(discountedPrice)} ₸/кг',
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
            color: _textMute.withValues(alpha: 0.8),
            height: 1.1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ];
  }

  Widget _pricingAccentBlock(List<String> facts) {
    final shown = facts.take(2).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: shown
          .map(
            (fact) => Padding(
              padding: EdgeInsets.only(bottom: 1.5.s),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: _pricingFactLabel(fact),
                      style: TextStyle(
                        fontSize: 8.sp,
                        fontWeight: FontWeight.w700,
                        color: _textMute.withValues(alpha: 0.7),
                        letterSpacing: 0.35,
                      ),
                    ),
                    TextSpan(
                      text: fact,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w900,
                        color: _orange,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  String _pricingFactLabel(String fact) {
    return fact.contains('%') ? 'КРЕП. ' : 'ОБЪЕМ ';
  }

  bool _isWeightUnit(String? unit) {
    final u = unit?.toLowerCase().trim();
    if (u == null) return false;
    if (u.contains('кг') || u.contains('kg')) return true;
    // Exclude common piece/liquid units
    if (u.contains('шт') || u.contains('л')) return false;
    return false;
  }

  double _resolvePortionWeight(item_model.Item item) {
    if (item.quantity != null && item.quantity! > 0) return item.quantity!;
    if (item.stepQuantity != null && item.stepQuantity! > 0) {
      return item.stepQuantity!;
    }
    return item.effectiveStepQuantity;
  }

  // ─── Cart section ────────────────────────────────────────
  Widget _cartSection(item_model.Item item) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, _) {
        final totalQuantity = cartProvider.getTotalQuantityForItem(item.itemId);
        final isInCart = totalQuantity > 0;
        final num? maxAmount = item.amount;
        final bool canIncrease = maxAmount == null || totalQuantity < maxAmount.toDouble();

        if (isInCart) {
          return _quantityControls(item, cartProvider, totalQuantity, maxAmount, canIncrease);
        } else {
          return _addToCartButton(item, cartProvider, maxAmount);
        }
      },
    );
  }

  // ─── Quantity controls (in-cart) ─────────────────────────
  Widget _quantityControls(
    item_model.Item item,
    CartProvider cartProvider,
    double totalQuantity,
    num? maxAmount,
    bool canIncrease,
  ) {
    return Row(
      children: [
        _ctrlButton(
          icon: Icons.remove,
          onPressed: () {
            final variants = cartProvider.getItemVariants(item.itemId);
            if (variants.isNotEmpty) {
              final v = variants.first;
              double step = v.stepQuantity;
              for (var sv in v.selectedVariants) {
                if (sv.containsKey('parent_item_amount')) {
                  step = (sv['parent_item_amount'] as num).toDouble();
                  break;
                }
              }
              cartProvider.updateQuantityWithVariants(item.itemId, v.selectedVariants, v.quantity - step);
            }
          },
        ),
        SizedBox(width: 5.s),
        Expanded(
          child: Container(
            height: 30.s,
            decoration: BoxDecoration(
              border: Border.all(color: _orange.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(7.s),
            ),
            child: Center(
              child: Text(
                item.effectiveStepQuantity == 1.0 ? totalQuantity.toStringAsFixed(0) : totalQuantity.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: _orange,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 5.s),
        _ctrlButton(
          icon: item.hasOptions ? Icons.settings : Icons.add,
          enabled: canIncrease,
          onPressed: canIncrease
              ? () {
                  if (item.hasOptions) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailPage(item: item)));
                  } else {
                    final variants = cartProvider.getItemVariants(item.itemId);
                    if (variants.isNotEmpty) {
                      final v = variants.first;
                      double step = v.stepQuantity;
                      for (var sv in v.selectedVariants) {
                        if (sv.containsKey('parent_item_amount')) {
                          step = (sv['parent_item_amount'] as num).toDouble();
                          break;
                        }
                      }
                      final target = v.quantity + step;
                      if (maxAmount != null && target > maxAmount.toDouble()) {
                        cartProvider.updateQuantityWithVariants(item.itemId, v.selectedVariants, maxAmount.toDouble());
                      } else {
                        cartProvider.updateQuantityWithVariants(item.itemId, v.selectedVariants, target);
                      }
                    }
                  }
                }
              : null,
        ),
      ],
    );
  }

  Widget _ctrlButton({
    required IconData icon,
    VoidCallback? onPressed,
    bool enabled = true,
  }) {
    return SizedBox(
      width: 30.s,
      height: 30.s,
      child: Material(
        color: enabled ? _orange : _cardDark,
        borderRadius: BorderRadius.circular(7.s),
        child: InkWell(
          borderRadius: BorderRadius.circular(7.s),
          onTap: onPressed,
          child: Center(
            child: Icon(icon, size: 14.s, color: enabled ? Colors.black : _textMute),
          ),
        ),
      ),
    );
  }

  // ─── Add-to-cart button ──────────────────────────────────
  Widget _addToCartButton(
    item_model.Item item,
    CartProvider cartProvider,
    num? maxAmount,
  ) {
    final itemTitle = presentItemName(
      rawName: item.name,
      categoryName: item.category?.name,
    );
    final bool canAdd = maxAmount == null || maxAmount.toDouble() > 0;
    final buttonLabel = canAdd ? (item.hasOptions ? 'Выбрать опции' : 'В корзину') : 'Нет в наличии';
    final buttonIcon = canAdd ? (item.hasOptions ? Icons.tune : Icons.shopping_bag_outlined) : Icons.remove_shopping_cart_outlined;
    return SizedBox(
      height: 30.s,
      child: Material(
        color: canAdd ? _orange : _cardDark,
        borderRadius: BorderRadius.circular(9.s),
        child: InkWell(
          borderRadius: BorderRadius.circular(9.s),
          onTap: canAdd
              ? () {
                  if (item.hasOptions) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailPage(item: item)));
                  } else {
                    final stepQuantity = item.effectiveStepQuantity;
                    cartProvider.addItem(CartItem(
                      itemId: item.itemId,
                      name: itemTitle.name,
                      price: item.price,
                      quantity: stepQuantity,
                      stepQuantity: stepQuantity,
                      image: item.image,
                      itemType: itemTitle.type,
                      packagingType: itemTitle.packagingType,
                      selectedVariants: [],
                      promotions: [],
                      maxAmount: item.amount?.toDouble(),
                    ));
                  }
                }
              : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                buttonIcon,
                size: 14.s,
                color: canAdd ? Colors.black : _textMute,
              ),
              SizedBox(width: 5.s),
              Text(
                buttonLabel,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: canAdd ? Colors.black : _textMute,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Price formatting ────────────────────────────────────
  static String _formatPrice(double price) {
    if (price >= 10000) {
      // "12 345" style for large prices
      final whole = price.truncate();
      final frac = price - whole;
      final parts = <String>[];
      var n = whole;
      while (n >= 1000) {
        parts.insert(0, (n % 1000).toString().padLeft(3, '0'));
        n = n ~/ 1000;
      }
      parts.insert(0, n.toString());
      final formatted = parts.join(' ');
      return frac > 0.005 ? '$formatted.${(frac * 100).round().toString().padLeft(2, '0')}' : formatted;
    }
    return price == price.roundToDouble() ? price.toStringAsFixed(0) : price.toStringAsFixed(2);
  }
}
