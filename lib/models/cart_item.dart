class CartItem {
  final int itemId;
  final String name;
  final double price;
  double quantity;
  final double stepQuantity;
  final List<Map<String, dynamic>> selectedVariants;
  final List<Map<String, dynamic>> promotions;

  CartItem({
    required this.itemId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.stepQuantity,
    required this.selectedVariants,
    required this.promotions,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      itemId: json['itemId'] as int,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      quantity: (json['quantity'] as num).toDouble(),
      stepQuantity: (json['stepQuantity'] as num).toDouble(),
      selectedVariants: (json['selectedVariants'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      promotions: (json['promotions'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'stepQuantity': stepQuantity,
      'selectedVariants': selectedVariants,
      'promotions': promotions,
    };
  }

  Map<String, dynamic> toJsonForOrder() {
    return {
      'item_id': itemId,
      'amount': quantity,
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
    quantity = adjusted;
  }

  /// Вычисляет итоговую цену с учетом акций
  double get totalPrice {
    double total = price * quantity;

    // Учитываем стоимость опций: price * (quantity / parent_item_amount)
    for (final variant in selectedVariants) {
      print(quantity);
      print('Variant: $variant');
      double? parentAmt;
      double? varPrice;
      if (variant.containsKey('parent_item_amount') &&
          variant.containsKey('price')) {
        parentAmt = (variant['parent_item_amount'] as num?)?.toDouble();
        varPrice = (variant['price'] as num?)?.toDouble();
      } else if (variant.containsKey('variant') && variant['variant'] is Map) {
        final v = variant['variant'] as Map;
        parentAmt = (v['parent_item_amount'] as num?)?.toDouble();
        varPrice = (v['price'] as num?)?.toDouble();
      }
      if (parentAmt != null && parentAmt > 0 && varPrice != null) {
        // Стоимость опций считается по полному количеству товара, без учета акции
        final multiplier = quantity / parentAmt;
        total += varPrice * multiplier;
      }
    }

    // SUBTRACT акции (учитываем ключи type/baseAmount/addAmount и discount_type/base_amount/add_amount)
    for (final promo in promotions) {
      final type =
          (promo['type'] as String?) ?? (promo['discount_type'] as String?);
      if (type == 'SUBTRACT') {
        final base = ((promo['baseAmount'] as num?) ??
                (promo['base_amount'] as num?) ??
                0)
            .toInt();
        final add =
            ((promo['addAmount'] as num?) ?? (promo['add_amount'] as num?) ?? 0)
                .toInt();
        final groupSize = base + add;
        if (groupSize > 0 && base > 0) {
          // Платим только за полные группы baseAmount, остаток игнорируем
          if (quantity >= groupSize) {
            // Если quantity меньше группы, то просто умножаем на базу
            final int count = (quantity ~/ groupSize);
            final payableCount = quantity - (count * add);
            // Базовая сумма по оплате и учет стоимости опций
            double subtotal = price * payableCount;
            for (final variant in selectedVariants) {
              double? parentAmt;
              double? varPrice;
              if (variant.containsKey('parent_item_amount') &&
                  variant.containsKey('price')) {
                parentAmt = (variant['parent_item_amount'] as num?)?.toDouble();
                varPrice = (variant['price'] as num?)?.toDouble();
              } else if (variant.containsKey('variant') &&
                  variant['variant'] is Map) {
                final v = variant['variant'] as Map;
                parentAmt = (v['parent_item_amount'] as num?)?.toDouble();
                varPrice = (v['price'] as num?)?.toDouble();
              }
              if (parentAmt != null && parentAmt > 0 && varPrice != null) {
                final multiplier = quantity / parentAmt;
                subtotal += varPrice * multiplier;
              }
            }
            total = subtotal;
          }
        }
      }
    }

    // DISCOUNT акции (учитываем ключи discount и discount_value)
    for (final promo in promotions) {
      final type =
          (promo['type'] as String?) ?? (promo['discount_type'] as String?);
      if (type == 'DISCOUNT') {
        final disc = ((promo['discount'] as num?) ??
                (promo['discount_value'] as num?) ??
                0)
            .toDouble();
        total = total * (1 - disc / 100);
      }
    }

    return total;
  }
}
