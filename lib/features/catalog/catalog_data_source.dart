import '../../core/product_view.dart';
import '../../model/item.dart';
import '../../utils/api.dart' hide Item;
import 'catalog_view_data.dart';

/// Reads the catalogue from the frozen API.
///
/// Every method returns presentation-ready values ([CategoryRef], [ProductView]) so screens hold
/// no parsing logic, and every call takes the business id because item prices, availability and
/// promotions are per store.
class CatalogDataSource {
  const CatalogDataSource({required this.businessId});

  final int businessId;

  /// All supercategories, with their categories and subcategories flattened into [CategoryRef]s.
  Future<List<SupercategoryView>> supercategories() async {
    final raw = await ApiService.getSuperCategories();
    if (raw == null) {
      throw StateError('Не удалось загрузить категории');
    }
    return [
      for (final entry in raw) _supercategory(entry),
    ];
  }

  /// Free-text product search, using the same response shape as a category listing.
  Future<List<ProductView>> search(String query, {int limit = 40}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final response = await ApiService.searchItemsTyped(
      trimmed,
      businessId: businessId,
      limit: limit,
    );
    if (response == null || !response.success) {
      throw StateError('Не удалось выполнить поиск');
    }
    return [
      for (final entry in response.data.items)
        ProductView.fromItem(Item.fromCategoryItem(entry)),
    ];
  }

  /// The user's liked items. ApiService already unwraps the response's `data`.
  ///
  /// Returns the page's products plus whether the backend has more, so a caller can append.
  Future<({List<ProductView> items, bool hasMore})> likedItems({
    int page = 1,
    int limit = 20,
  }) async {
    final raw = await ApiService.getLikedItems(
      businessId: businessId,
      page: page,
      limit: limit,
    );
    if (raw == null) throw StateError('Не удалось загрузить избранное');
    final entries = raw['items'];
    final items = <ProductView>[
      if (entries is List)
        for (final entry in entries)
          if (entry is Map)
            ProductView.fromItem(
                Item.fromCategoryItem(entry.cast<String, dynamic>())),
    ];
    final pagination = raw['pagination'];
    var hasMore = false;
    if (pagination is Map) {
      final totalPages =
          _int(pagination['total_pages'] ?? pagination['totalPages']);
      final current = _int(pagination['page']);
      if (totalPages != null && current != null) hasMore = current < totalPages;
    }
    return (items: items, hasMore: hasMore);
  }

  /// One supercategory by id, or null when the API no longer returns it.
  Future<SupercategoryView?> supercategory(int supercategoryId) async {
    final all = await supercategories();
    for (final entry in all) {
      if (entry.id == supercategoryId) return entry;
    }
    return null;
  }

  /// Card-ready products of a leaf category.
  ///
  /// The API returns items of nested subcategories too (`categories_included`), which is why a
  /// single call for «Вино» can carry «Аперитив» items — the same behaviour the old catalogue
  /// relied on.
  Future<List<ProductView>> items(
    int categoryId, {
    int page = 1,
    int limit = 60,
  }) async =>
      (await itemsPage(categoryId, page: page, limit: limit)).items;

  Future<({List<ProductView> items, bool hasMore})> itemsPage(
    int categoryId, {
    int page = 1,
    int limit = 60,
  }) async {
    final response = await ApiService.getCategoryItemsTyped(
      categoryId,
      businessId: businessId,
      page: page,
      limit: limit,
    );
    if (response == null || !response.success) {
      throw StateError('Не удалось загрузить товары категории');
    }
    return (
      items: [
        for (final entry in response.data.items)
          ProductView.fromItem(Item.fromCategoryItem(entry)),
      ],
      hasMore: response.data.pagination.hasNextPage,
    );
  }

  SupercategoryView _supercategory(Map<String, dynamic> raw) {
    final name = _string(raw['name']) ?? '';
    return SupercategoryView(
      id: _int(raw['supercategory_id']) ?? _int(raw['id']) ?? 0,
      name: name,
      description: _string(raw['description']),
      imageUrl: _string(raw['img']),
      subcategories: [
        for (final category in _maps(raw['categories']))
          // A category with subcategories is a grouping; the design lists its leaves, and the
          // API's own order is preserved because the design's chips follow it.
          ...(() {
            final subs = _maps(category['subcategories']);
            if (subs.isEmpty) {
              final id = _int(category['category_id']);
              final categoryName = _string(category['name']) ?? '';
              return id == null
                  ? const <CategoryRef>[]
                  : [CategoryRef(id: id, name: categoryName)];
            }
            return [
              for (final sub in subs)
                if (_int(sub['category_id']) case final id?)
                  CategoryRef(id: id, name: _string(sub['name']) ?? ''),
            ];
          })(),
      ],
    );
  }

  Iterable<Map<String, dynamic>> _maps(Object? value) {
    if (value is! List) return const [];
    return [
      for (final entry in value)
        if (entry is Map) entry.cast<String, dynamic>(),
    ];
  }

  int? _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse('${value ?? ''}');

  String? _string(Object? value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? null : text;
  }
}
