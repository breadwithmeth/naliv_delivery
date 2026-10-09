import '../../core/product_view.dart';
import '../../model/item.dart';
import '../../utils/api.dart';
import 'catalog_view_data.dart';

/// Reads the catalogue from the frozen API.
///
/// Every method returns presentation-ready values ([CategoryRef], [ProductView]) so screens hold
/// no parsing logic, and every call takes the business id because item prices, availability and
/// promotions are per store.
class CatalogDataSource {
  const CatalogDataSource({required this.businessId});

  final int businessId;
  static final _whitespace = RegExp(r'\s+');

  /// Reads supercategories without discarding their category hierarchy.
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
    final name = _name(raw['name']);
    final rawCategories = _maps(raw['categories']).toList(growable: false);
    final nameCounts = <String, int>{};
    void countLeaves(Iterable<Map<String, dynamic>> entries) {
      for (final entry in entries) {
        final children = _maps(entry['subcategories']).toList(growable: false);
        if (children.isEmpty) {
          final key = _name(entry['name']).toLowerCase();
          nameCounts.update(key, (count) => count + 1, ifAbsent: () => 1);
        } else {
          countLeaves(children);
        }
      }
    }

    countLeaves(rawCategories);
    final leaves = <CategoryRef>[];
    List<CategoryRef> parseCategories(
      Iterable<Map<String, dynamic>> entries, {
      int? parentId,
      String? parentName,
    }) {
      final categories = <CategoryRef>[];
      for (final entry in entries) {
        final id = _int(entry['category_id']);
        if (id == null) continue;
        final categoryName = _name(entry['name']);
        final children = parseCategories(
          _maps(entry['subcategories']),
          parentId: id,
          parentName: categoryName,
        );
        final category = CategoryRef(
          id: id,
          name: categoryName,
          parentId: parentId,
          parentName: parentName,
          needsParentContext:
              (nameCounts[categoryName.toLowerCase()] ?? 0) > 1,
          description: _string(entry['description']),
          imageUrl: _string(entry['img']),
          children: children,
        );
        categories.add(category);
        if (children.isEmpty) leaves.add(category);
      }
      return categories;
    }

    final id = _int(raw['supercategory_id']) ?? _int(raw['id']) ?? 0;
    final categories = parseCategories(
      rawCategories,
      parentId: id,
      parentName: name,
    );
    return SupercategoryView(
      id: id,
      name: name,
      description: _string(raw['description']),
      imageUrl: _string(raw['img']),
      categories: categories,
      leaves: leaves,
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

  String _name(Object? value) =>
      value?.toString().trim().replaceAll(_whitespace, ' ') ?? '';

  String? _string(Object? value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? null : text;
  }
}
