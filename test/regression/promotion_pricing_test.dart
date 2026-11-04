import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/model/cart_item.dart';

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

    CartItem subtractRow(double quantity) => CartItem(
          itemId: 1,
          name: 'Beer',
          price: 1000,
          quantity: quantity,
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

    test(
        'subtract promo makes the third unit free and surfaces its value separately',
        () {
      final item = subtractRow(3);

      // Two paid units plus their 50 ₸ options; the free third unit would have cost 1000.
      expect(item.subtotalBeforePromotions, 3100);
      expect(item.totalPrice, 2100);
    });

    test('subtract promo gifts nothing until the whole set is in the cart', () {
      final item = subtractRow(2);

      expect(item.subtotalBeforePromotions, 2100);
      expect(item.totalPrice, 2100);
    });
  });
}
