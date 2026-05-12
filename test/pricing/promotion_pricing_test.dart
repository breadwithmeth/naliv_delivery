import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/models/cart_item.dart';
import 'package:naliv_delivery/utils/subtract_promotion_math.dart';

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

    test('subtract promo keeps paid quantity and surfaces gifted value separately', () {
      final item = CartItem(
        itemId: 1,
        name: 'Beer',
        price: 1000,
        quantity: 2,
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

      expect(item.subtotalBeforePromotions, 3100);
      expect(item.totalPrice, 2100);
    });
  });

  group('subtract promotion bundle helpers', () {
    const promotions = <Map<String, dynamic>>[
      <String, dynamic>{
        'discount_type': 'SUBTRACT',
        'base_amount': 3,
        'add_amount': 1,
      },
    ];

    test('snaps quantity changes to promo thresholds', () {
      expect(
        subtractPromotionBundleTargetQuantity(0, promotions, direction: 1),
        3,
      );
      expect(
        subtractPromotionBundleTargetQuantity(2, promotions, direction: 1),
        3,
      );
      expect(
        subtractPromotionBundleTargetQuantity(4, promotions, direction: 1),
        6,
      );
      expect(
        subtractPromotionBundleTargetQuantity(4, promotions, direction: -1),
        3,
      );
      expect(
        subtractPromotionBundleTargetQuantity(2, promotions, direction: -1),
        0,
      );
    });

    test('formats paid and free quantities as a bundle label', () {
      expect(
        subtractPromotionBundleLabel(2, promotions, formatQuantity: _formatQty),
        '2',
      );
      expect(
        subtractPromotionBundleLabel(3, promotions, formatQuantity: _formatQty),
        '3+1',
      );
      expect(
        subtractPromotionBundleLabel(6, promotions, formatQuantity: _formatQty),
        '6+2',
      );
    });
  });
}

String _formatQty(double qty) {
  return (qty - qty.roundToDouble()).abs() < 0.001 ? qty.toStringAsFixed(0) : qty.toStringAsFixed(2);
}
