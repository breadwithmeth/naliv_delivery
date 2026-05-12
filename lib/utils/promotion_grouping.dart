import '../model/item.dart' as item_model;

bool itemHasActivePromotion(item_model.Item item) {
  return (item.promotions ?? const <item_model.ItemPromotion>[]).any((promotion) => promotion.isActive);
}

bool hasPromotionBoundaryAfter(
  List<item_model.Item> orderedItems,
  int leadingIndex,
) {
  if (leadingIndex < 0 || leadingIndex >= orderedItems.length - 1) {
    return false;
  }

  return itemHasActivePromotion(orderedItems[leadingIndex]) && !itemHasActivePromotion(orderedItems[leadingIndex + 1]);
}
