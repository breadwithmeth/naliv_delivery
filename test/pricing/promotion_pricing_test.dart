import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/models/cart_item.dart';

void main() {
  group('ItemPromotion', () {
    test('derives effective percent for fixed discounts', () {
      final promotion = ItemPromotion(
        promotionId: 1,
        name: 'Fixed',
        discountType: 'FIXED',
        discountValue: 100,
      );

      expect(promotion.calculateDiscountedPrice(1000), 900);
      expect(promotion.calculateSavings(1000), 100);
      expect(promotion.calculateEffectiveDiscountPercent(1000), 10);
    });
  });

  group('CartItem.totalPrice', () {
    test('applies fixed discount per unit quantity', () {
      final item = CartItem(
        itemId: 1,
        name: 'Beer',
        price: 1000,
        quantity: 2,
        stepQuantity: 1,
        selectedVariants: const <Map<String, dynamic>>[],
        promotions: const <Map<String, dynamic>>[
          <String, dynamic>{
            'discount_type': 'FIXED',
            'discount_value': 100,
          },
        ],
      );

      expect(item.totalPrice, 1800);
    });

    test('keeps bottle price outside percent discount', () {
      final item = CartItem(
        itemId: 1,
        name: 'Beer',
        price: 1000,
        quantity: 1,
        stepQuantity: 1,
        selectedVariants: const <Map<String, dynamic>>[
          <String, dynamic>{
            'parent_item_amount': 1,
            'price': 50,
          },
        ],
        promotions: const <Map<String, dynamic>>[
          <String, dynamic>{
            'discount_type': 'PERCENT',
            'discount_value': 10,
          },
        ],
      );

      expect(item.subtotalBeforePromotions, 1050);
      expect(item.totalPrice, 950);
    });

    test('subtract promo keeps bottle price on free liters', () {
      final item = CartItem(
        itemId: 1,
        name: 'Beer',
        price: 1000,
        quantity: 3,
        stepQuantity: 1,
        selectedVariants: const <Map<String, dynamic>>[
          <String, dynamic>{
            'parent_item_amount': 1,
            'price': 50,
          },
        ],
        promotions: const <Map<String, dynamic>>[
          <String, dynamic>{
            'discount_type': 'SUBTRACT',
            'base_amount': 2,
            'add_amount': 1,
          },
        ],
      );

      expect(item.subtotalBeforePromotions, 3150);
      expect(item.totalPrice, 2150);
    });
  });
}
