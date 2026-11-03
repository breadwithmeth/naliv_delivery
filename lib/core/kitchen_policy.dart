import 'package:flutter/foundation.dart';

import '../model/cart_item.dart';
import '../model/item.dart';

/// «Кухня» is sold by exactly one store. This is the single place that knows which one.
///
/// The kitchen is supercategory [supercategoryId]. Items carry no supercategory, only their
/// category, so the policy keeps a registry of every category id under the kitchen
/// supercategory. It is seeded with the known «Еда (Кухня)» category and extended whenever a
/// supercategories payload is read ([registerSupercategories]).
abstract final class KitchenPolicy {
  /// «Градусы24, Бухар-Жырау 70, Караганда».
  static const int businessId = 11;
  static const int supercategoryId = 7;
  static const String supercategoryName = 'Кухня';
  static const int _seedCategoryId = 237;

  static final Set<int> _categoryIds = {_seedCategoryId};

  /// Category ids known to belong to the kitchen supercategory.
  static Set<int> get categoryIds => Set.unmodifiable(_categoryIds);

  /// Whether the kitchen may be loaded or ordered at the store [storeId].
  static bool isAvailableForBusiness(int? storeId) => storeId == businessId;

  /// Whether the supercategory is the kitchen, by id or (as a fallback) by its name.
  static bool isKitchenSupercategory({int? id, String? name}) =>
      id == supercategoryId ||
      name?.trim().toLowerCase() == supercategoryName.toLowerCase();

  static bool isKitchenCategoryId(int? id) =>
      id != null && _categoryIds.contains(id);

  /// Whether a catalogue item belongs to a kitchen category.
  static bool isKitchenItem(Item item) =>
      isKitchenCategoryId(item.categoryId) ||
      isKitchenCategoryId(item.category?.categoryId) ||
      isKitchenCategoryId(item.category?.parentId);

  /// Whether a persisted cart row is a kitchen item. Rows without a snapshot are unknowable
  /// and are never classified as kitchen.
  static bool isKitchenCartItem(CartItem row) {
    final snapshot = row.snapshotItem;
    return snapshot != null && isKitchenItem(snapshot);
  }

  /// Whether a raw order line (repeat order) is a kitchen item. Order lines may carry only a
  /// category name, so «Кухня» in the category name counts.
  static bool isKitchenOrderLine(Map<String, dynamic> line) {
    int? asInt(Object? value) =>
        value is num ? value.toInt() : int.tryParse('${value ?? ''}');
    final category = line['category'];
    final categoryMap =
        category is Map ? category.cast<String, dynamic>() : null;
    if (isKitchenCategoryId(asInt(line['category_id'])) ||
        isKitchenCategoryId(asInt(categoryMap?['category_id'])) ||
        isKitchenCategoryId(asInt(categoryMap?['parent_category']))) {
      return true;
    }
    final name = categoryMap?['name'];
    return name is String && name.toLowerCase().contains('кухня');
  }

  /// Whether [item] may be shown or added at the store [storeId].
  static bool allowsItem(Item item, int? storeId) =>
      isAvailableForBusiness(storeId) || !isKitchenItem(item);

  /// Items that may appear at the store [storeId].
  static List<T> filterItems<T>(
    Iterable<T> items,
    int? storeId,
    Item Function(T entry) itemOf,
  ) =>
      isAvailableForBusiness(storeId)
          ? items.toList(growable: false)
          : [
              for (final entry in items)
                if (!isKitchenItem(itemOf(entry))) entry,
            ];

  /// Drops the kitchen supercategory from raw API entries unless the kitchen is available.
  static List<Map<String, dynamic>> filterSupercategories(
    Iterable<Map<String, dynamic>> raw,
    int? storeId,
  ) {
    registerSupercategories(raw);
    return [
      for (final entry in raw)
        if (isAvailableForBusiness(storeId) ||
            !isKitchenSupercategory(
              id: _asInt(entry['supercategory_id'] ?? entry['id']),
              name: entry['name'] is String ? entry['name'] as String : null,
            ))
          entry,
    ];
  }

  /// Learns every category id under the kitchen supercategory from a raw
  /// `/categories/supercategories` payload.
  static void registerSupercategories(Iterable<Map<String, dynamic>> raw) {
    void collect(Object? node) {
      if (node is! Map) return;
      final id = _asInt(node['category_id']);
      if (id != null && id > 0) _categoryIds.add(id);
      for (final key in const ['categories', 'subcategories']) {
        final children = node[key];
        if (children is List) children.forEach(collect);
      }
    }

    for (final entry in raw) {
      final name = entry['name'];
      if (isKitchenSupercategory(
        id: _asInt(entry['supercategory_id'] ?? entry['id']),
        name: name is String ? name : null,
      )) {
        collect(entry);
      }
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    _categoryIds
      ..clear()
      ..add(_seedCategoryId);
  }

  static int? _asInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse('${value ?? ''}');
}
