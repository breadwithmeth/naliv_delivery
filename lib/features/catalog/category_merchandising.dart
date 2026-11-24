import '../../core/product_view.dart';

/// Ranks one complete store category, preserving the original card objects.
/// Paginated or authoritative server-ranked feeds must not use this policy.
List<ProductView> rankCompleteCategory(
  List<ProductView> items, {
  List<int> priorityItemIds = const [],
}) {
  final priority = <int, List<ProductView>?>{
    for (final id in priorityItemIds) id: null,
  };
  final campaigns = <ProductView>[];
  final remainder = <ProductView>[];
  for (final view in items) {
    final eligible = view.available && view.source.isVisible;
    if (eligible && priority.containsKey(view.itemId)) {
      final bucket = priority[view.itemId];
      if (bucket == null) {
        priority[view.itemId] = [view];
      } else {
        bucket.add(view);
      }
    } else if (eligible &&
        view.source.promotions?.any((promotion) => promotion.isActive) ==
            true) {
      campaigns.add(view);
    } else {
      remainder.add(view);
    }
  }
  return [
    for (final bucket in priority.values)
      if (bucket != null) ...bucket,
    ...campaigns,
    ...remainder,
  ];
}
