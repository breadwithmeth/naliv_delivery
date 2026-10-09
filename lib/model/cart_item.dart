import 'item.dart' as item_model;
import '../utils/promotion_engine.dart';
import '../utils/smart_cart.dart';

typedef CartPriceBreakdown = ({
  double productSubtotal,
  double optionsTotal,
  double discount,
  double freeQuantity,
  double subtotalBeforePromotions,
  double totalPrice,
});

class CartItem {
  final int itemId;
  final String name;
  final double price;
  double quantity;
  final double stepQuantity;
  // Derived gift capacity, never persisted as newly paid drink quantity.
  final double bottledGiftQuantity;
  double get physicalQuantity => quantity + bottledGiftQuantity;
  final Map<int, int>? giftBottleCounts;
  final String? image;
  final String? itemType;
  final String? packagingType;
  final List<Map<String, dynamic>> selectedVariants;
  final List<Map<String, dynamic>> promotions;
  final Map<String, dynamic>? itemData;
  final double? maxAmount; // лимит доступного количества (остаток)

  CartItem({
    required this.itemId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.stepQuantity,
    this.bottledGiftQuantity = 0,
    this.giftBottleCounts,
    this.image,
    this.itemType,
    this.packagingType,
    required this.selectedVariants,
    required this.promotions,
    this.itemData,
    this.maxAmount,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      itemId: json['itemId'] as int,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      quantity: (json['quantity'] as num).toDouble(),
      stepQuantity: (json['stepQuantity'] as num).toDouble(),
      giftBottleCounts: json['giftBottleCounts'] is Map
          ? {
              for (final entry in (json['giftBottleCounts'] as Map).entries)
                int.parse(entry.key.toString()): (entry.value as num).toInt(),
            }
          : null,
      image: json['image'] as String?,
      itemType: json['itemType'] as String?,
      packagingType: json['packagingType'] as String?,
      selectedVariants: (json['selectedVariants'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      promotions: (json['promotions'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      itemData: json['itemData'] is Map
          ? Map<String, dynamic>.from(json['itemData'] as Map)
          : null,
      maxAmount: json['maxAmount'] != null
          ? (json['maxAmount'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'stepQuantity': stepQuantity,
      if (giftBottleCounts != null)
        'giftBottleCounts': {
          for (final entry in giftBottleCounts!.entries)
            entry.key.toString(): entry.value,
        },
      if (image != null) 'image': image,
      if (itemType != null) 'itemType': itemType,
      if (packagingType != null) 'packagingType': packagingType,
      'selectedVariants': selectedVariants,
      'promotions': promotions,
      if (itemData != null) 'itemData': itemData,
      if (maxAmount != null) 'maxAmount': maxAmount,
    };
  }

  CartItem copyWith({
    int? itemId,
    String? name,
    double? price,
    double? quantity,
    double? stepQuantity,
    double? bottledGiftQuantity,
    Map<int, int>? giftBottleCounts,
    bool clearGiftBottleCounts = false,
    String? image,
    String? itemType,
    String? packagingType,
    List<Map<String, dynamic>>? selectedVariants,
    List<Map<String, dynamic>>? promotions,
    Map<String, dynamic>? itemData,
    bool clearItemData = false,
    double? maxAmount,
  }) {
    return CartItem(
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      stepQuantity: stepQuantity ?? this.stepQuantity,
      bottledGiftQuantity: bottledGiftQuantity ?? this.bottledGiftQuantity,
      giftBottleCounts: clearGiftBottleCounts
          ? null
          : (giftBottleCounts ?? this.giftBottleCounts),
      image: image ?? this.image,
      itemType: itemType ?? this.itemType,
      packagingType: packagingType ?? this.packagingType,
      selectedVariants: selectedVariants ?? this.selectedVariants,
      promotions: promotions ?? this.promotions,
      itemData: clearItemData ? null : (itemData ?? this.itemData),
      maxAmount: maxAmount ?? this.maxAmount,
    );
  }

  item_model.Item? get snapshotItem {
    if (itemData == null) {
      return null;
    }

    try {
      return item_model.Item.fromJson(itemData!);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJsonForOrder({double? freeQuantity}) {
    final snapshot = snapshotItem;
    final pour = snapshot != null && SmartCartSelection(snapshot).usesPourFlow;
    freeQuantity ??=
        pour ? 0 : subtractPromotionFreeQuantity(quantity, promotions);
    return {
      'item_id': itemId,
      'amount': physicalQuantity + freeQuantity,
      'options': selectedVariants.map((variant) {
        // API ожидает option_item_relation_id
        // Ищем ID варианта в разных возможных полях
        final relationId = variant['variant_id'] ??
            variant['relation_id'] ??
            variant['variant']?['relation_id'] ??
            variant['variant']?['variant_id'];
        return {
          'option_item_relation_id': relationId,
          'amount': 1, // Обычно количество опций 1, если не указано иное
        };
      }).toList(),
    };
  }

  void updateQuantity(double newQuantity) {
    final step = stepQuantity > 0 ? stepQuantity : 1.0;
    final adjusted = ((newQuantity + 0.0000001) / step).floor() * step;
    quantity = adjusted < 0 ? 0 : adjusted;
  }

  static Map<String, dynamic> _variantData(Map<String, dynamic> variant) =>
      variant['variant'] is Map
          ? Map<String, dynamic>.from(variant['variant'] as Map)
          : variant;

  double get paidUnitPrice {
    double? replacement;
    for (final selected in selectedVariants) {
      final variant = _variantData(selected);
      if (variant['price_type']?.toString().toUpperCase() != 'REPLACE') {
        continue;
      }
      final amount = (variant['parent_item_amount'] as num?)?.toDouble() ?? 0;
      final value = (variant['price'] as num?)?.toDouble();
      if (amount > 0 && value != null) {
        replacement = (replacement ?? 0) + value / amount;
      }
    }
    return replacement ?? price;
  }

  double get optionsTotal {
    var total = 0.0;
    final snapshot = snapshotItem;
    final selection = snapshot == null ? null : SmartCartSelection(snapshot);
    for (final selected in selectedVariants) {
      final variant = _variantData(selected);
      if (variant['price_type']?.toString().toUpperCase() == 'REPLACE') {
        continue;
      }
      final amount = (variant['parent_item_amount'] as num?)?.toDouble() ?? 0;
      final value = (variant['price'] as num?)?.toDouble();
      if (amount > 0 && value != null) {
        final chargedQuantity = selection?.isBottleVariant(selected) == true
            ? physicalQuantity
            : quantity;
        total += value * chargedQuantity / amount;
      }
    }
    return total;
  }

  // The same calculation is used for a preview, a display group and checkout.
  // Paid drink selections are stable; gifts extend their physical container
  // allocation, with ordinary container tariffs outside base-product discounts.
  static CartPriceBreakdown calculatePrice(Iterable<CartItem> items) {
    var quantity = 0.0;
    var productSubtotal = 0.0;
    var options = 0.0;
    var paid = 0.0;
    List<Map<String, dynamic>>? promotions;
    for (final item in SmartCartSelection.withGiftContainers(items)) {
      promotions ??= item.promotions;
      if (item.physicalQuantity <= 0) continue;
      quantity += item.quantity;
      final rate = item.paidUnitPrice;
      productSubtotal += rate * item.quantity;
      paid += applyPromotionsToPaidBaseTotal(
          unitPrice: rate, quantity: item.quantity, promotions: promotions);
      options += item.optionsTotal;
    }
    final unitPrice = quantity > 0 ? productSubtotal / quantity : 0.0;
    final free =
        subtractPromotionFreeQuantity(quantity, promotions ?? const []);
    return (
      productSubtotal: productSubtotal,
      optionsTotal: options,
      discount: productSubtotal - paid,
      freeQuantity: free,
      subtotalBeforePromotions: productSubtotal + unitPrice * free + options,
      totalPrice: paid + options,
    );
  }

  double get subtotalBeforePromotions =>
      calculatePrice([this]).subtotalBeforePromotions;

  double get totalPrice => calculatePrice([this]).totalPrice;
}
