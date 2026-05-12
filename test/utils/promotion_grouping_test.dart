import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/utils/promotion_grouping.dart';

void main() {
  test('detects the divider boundary between promo and regular items', () {
    final promoItem = _buildItem(
      itemId: 1,
      promotions: <ItemPromotion>[
        ItemPromotion(
          promotionId: 10,
          name: 'Promo',
          discountType: 'PERCENT',
          discountValue: 10,
        ),
      ],
    );
    final regularItem = _buildItem(itemId: 2);

    expect(hasPromotionBoundaryAfter(<Item>[promoItem, regularItem], 0), isTrue);
  });

  test('keeps regular separators inside the same item section', () {
    final firstPromo = _buildItem(
      itemId: 1,
      promotions: <ItemPromotion>[
        ItemPromotion(
          promotionId: 10,
          name: 'Promo',
          discountType: 'PERCENT',
          discountValue: 10,
        ),
      ],
    );
    final secondPromo = _buildItem(
      itemId: 2,
      promotions: <ItemPromotion>[
        ItemPromotion(
          promotionId: 11,
          name: 'Promo 2',
          discountType: 'FIXED',
          discountValue: 100,
        ),
      ],
    );
    final regularItem = _buildItem(itemId: 3);

    expect(hasPromotionBoundaryAfter(<Item>[firstPromo, secondPromo, regularItem], 0), isFalse);
    expect(hasPromotionBoundaryAfter(<Item>[firstPromo, secondPromo, regularItem], 1), isTrue);
    expect(hasPromotionBoundaryAfter(<Item>[regularItem], 0), isFalse);
  });
}

Item _buildItem({
  required int itemId,
  List<ItemPromotion> promotions = const <ItemPromotion>[],
}) {
  return Item(
    itemId: itemId,
    name: 'Item $itemId',
    price: 1000,
    amount: 10,
    quantity: 1,
    unit: 'шт.',
    promotions: promotions,
  );
}
