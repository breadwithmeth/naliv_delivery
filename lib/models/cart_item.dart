import '../model/item.dart' as item_model;
import '../utils/subtract_promotion_math.dart';

class CartItem {
  final int itemId;
  final String name;
  final double price;
  double quantity;
  final double stepQuantity;
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
      image: json['image'] as String?,
      itemType: json['itemType'] as String?,
      packagingType: json['packagingType'] as String?,
      selectedVariants: (json['selectedVariants'] as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      promotions: (json['promotions'] as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      itemData: json['itemData'] is Map ? Map<String, dynamic>.from(json['itemData'] as Map) : null,
      maxAmount: json['maxAmount'] != null ? (json['maxAmount'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'stepQuantity': stepQuantity,
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

  Map<String, dynamic> toJsonForOrder() {
    return {
      'item_id': itemId,
      'amount': quantity,
      'options': selectedVariants.map((variant) {
        // API ожидает option_item_relation_id
        // Ищем ID варианта в разных возможных полях
        final relationId = variant['variant_id'] ?? variant['relation_id'] ?? variant['variant']?['relation_id'] ?? variant['variant']?['variant_id'];
        return {
          'option_item_relation_id': relationId,
          'amount': 1, // Обычно количество опций 1, если не указано иное
        };
      }).toList(),
    };
  }

  /// Обновляет количество с шагом и округлением вниз
  void updateQuantity(double newQuantity) {
    double step = stepQuantity;
    for (final variant in selectedVariants) {
      // Поддержка вложенной структуры variant
      if (variant.containsKey('parent_item_amount')) {
        step = (variant['parent_item_amount'] as num).toDouble();
        break;
      }
      if (variant.containsKey('variant') && variant['variant'] is Map) {
        final v = variant['variant'] as Map;
        if (v.containsKey('parent_item_amount')) {
          step = (v['parent_item_amount'] as num).toDouble();
          break;
        }
      }
    }
    final adjusted = (newQuantity / step).floor() * step;
    quantity = adjusted < 0 ? 0 : adjusted;
  }

  double get optionsTotal {
    var total = 0.0;

    for (final variant in selectedVariants) {
      double? parentAmt;
      double? varPrice;
      if (variant.containsKey('parent_item_amount') && variant.containsKey('price')) {
        parentAmt = (variant['parent_item_amount'] as num?)?.toDouble();
        varPrice = (variant['price'] as num?)?.toDouble();
      } else if (variant.containsKey('variant') && variant['variant'] is Map) {
        final v = variant['variant'] as Map;
        parentAmt = (v['parent_item_amount'] as num?)?.toDouble();
        varPrice = (v['price'] as num?)?.toDouble();
      }
      if (parentAmt != null && parentAmt > 0 && varPrice != null) {
        final multiplier = quantity / parentAmt;
        total += varPrice * multiplier;
      }
    }

    return total;
  }

  double get subtotalBeforePromotions => subtractPromotionDisplayBaseTotal(price, quantity, promotions) + optionsTotal;

  /// Вычисляет итоговую цену с учетом акций
  double get totalPrice {
    final optionsSubtotal = optionsTotal;
    final baseTotal = applyPromotionsToPaidBaseTotal(
      unitPrice: price,
      quantity: quantity,
      promotions: promotions,
    );
    return baseTotal + optionsSubtotal;
  }
}
