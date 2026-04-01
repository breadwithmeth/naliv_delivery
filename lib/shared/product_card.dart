import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/item.dart' as ItemModel;
import '../utils/cart_provider.dart';
import '../models/cart_item.dart';
import '../globals.dart' as globals;
import '../pages/product_detail_page.dart';
import '../utils/api.dart';
import '../utils/bonus_rules.dart';
import '../utils/liked_storage_service.dart';
import '../utils/business_provider.dart';
import '../utils/liked_items_provider.dart';
import '../utils/responsive.dart';

class ProductCard extends StatefulWidget {
  final ItemModel.Item item;

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
    try {
      final newValue = await ApiService.toggleLikeItem(widget.item.itemId);
      if (newValue != null) {
        setState(() => _isLikedOverride = newValue);
        if (_businessId != null) {
          LikedStorageService.setLiked(
            businessId: _businessId!,
            itemId: widget.item.itemId,
            liked: newValue,
          );
          final likedProvider = Provider.of<LikedItemsProvider>(context, listen: false);
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
    final isWeightItem = _isWeightUnit(item.unit);
    final portionWeight = _resolvePortionWeight(item);

    // Promotion calculations
    final promo = item.hasPromotions ? item.promotions!.first : null;
    final hasActivePromo = promo != null && promo.isActive;
    final isSubtractPromo = hasActivePromo && promo.discountType == 'SUBTRACT';
    final hasDiscount = hasActivePromo && !isSubtractPromo;
    final discountedPrice = hasDiscount ? promo.calculateDiscountedPrice(item.price) : item.price;
    final discountPercent = hasDiscount
        ? (promo.discountType == 'PERCENT'
            ? promo.discountValue.round()
            : item.price > 0
                ? ((1 - discountedPrice / item.price) * 100).round()
                : 0)
        : 0;
    final isLowStock = item.amount != null && item.amount! > 0 && item.amount! <= 5;
    final savingsAmount = hasDiscount ? (item.price - discountedPrice) * (isWeightItem && portionWeight > 0 ? portionWeight : 1) : 0.0;
    final bonusPoints = _calculateBonusPoints(item, discountedPrice);
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
            _imageSection(item, hasDiscount, discountPercent, isLowStock, bonusPoints),

            // ── Info ──
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(9.s, 7.s, 9.s, 9.s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: _text,
                        height: 1.25,
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
    ItemModel.Item item,
    bool hasDiscount,
    int discountPercent,
    bool isLowStock,
    int bonusPoints,
  ) {
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
                color: _cardDark,
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

          // Bottom gradient for badge readability
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
                if (isLowStock)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.s, vertical: 4.s),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8.s),
                    ),
                    child: Text(
                      'Мало',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                        color: _orange,
                        height: 1.1,
                      ),
                    ),
                  ),
                if (hasDiscount) ...[
                  if (isLowStock) SizedBox(height: 6.s),
                  Container(
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
                  ),
                ],
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

          // ── Bottom row: promos/options (left) + bonus (right) ──
          Positioned(
            bottom: 7.s,
            left: 7.s,
            right: 7.s,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Left: promo + option badges
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      if (item.hasPromotions)
                        ...item.promotions!.map((p) => _promoBadge(
                              p.description ?? p.name,
                            )),
                      if (item.hasOptions) _optionBadge(item),
                    ],
                  ),
                ),
                // Right: bonus points badge
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

  // ─── Promo badge ─────────────────────────────────────────
  Widget _promoBadge(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.s, vertical: 3.s),
      decoration: BoxDecoration(
        color: _orange,
        borderRadius: BorderRadius.circular(6.s),
        boxShadow: [
          BoxShadow(
            color: _orange.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w800,
          color: Colors.black,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ─── Option badge (shows option names) ───────────────────
  Widget _optionBadge(ItemModel.Item item) {
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
  int _calculateBonusPoints(ItemModel.Item item, double price) {
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
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: Text(
              '${_formatPrice(mainPrice)} ₸',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w900,
                color: _text,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (portionLabel != null) ...[
            SizedBox(width: 6.s),
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
        ],
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

  bool _isWeightUnit(String? unit) {
    final u = unit?.toLowerCase().trim();
    if (u == null) return false;
    if (u.contains('кг') || u.contains('kg')) return true;
    // Exclude common piece/liquid units
    if (u.contains('шт') || u.contains('л')) return false;
    return false;
  }

  double _resolvePortionWeight(ItemModel.Item item) {
    if (item.quantity != null && item.quantity! > 0) return item.quantity!;
    if (item.stepQuantity != null && item.stepQuantity! > 0) {
      return item.stepQuantity!;
    }
    return item.effectiveStepQuantity;
  }

  // ─── Cart section ────────────────────────────────────────
  Widget _cartSection(ItemModel.Item item) {
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
    ItemModel.Item item,
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
    ItemModel.Item item,
    CartProvider cartProvider,
    num? maxAmount,
  ) {
    final bool canAdd = maxAmount == null || maxAmount.toDouble() > 0;
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
                      name: item.name,
                      price: item.price,
                      quantity: stepQuantity,
                      stepQuantity: stepQuantity,
                      image: item.image,
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
                item.hasOptions ? Icons.tune : Icons.shopping_bag_outlined,
                size: 14.s,
                color: canAdd ? Colors.black : _textMute,
              ),
              SizedBox(width: 5.s),
              Text(
                item.hasOptions ? 'Выбрать опции' : 'В корзину',
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
