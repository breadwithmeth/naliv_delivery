import '../../utils/api.dart';
import '../../utils/order_ui_helpers.dart';
import '../catalog/catalog_data_source.dart';
import 'home_view_data.dart';

/// Loads the home screen's data from the existing (frozen) API surface.
///
/// Mapping decisions, each grounded in what the live backend actually returns:
///
/// * **Category tiles** — `GET /categories/supercategories` returns 7 supercategories
///   (Кухня 100, Аксессуары 20, Слабоалкогольные напитки 10, Еда и закуски 9, Крепкие напитки 8,
///   Табачная продукция 7, Безалкогольные напитки 2). The design's home shows exactly six
///   tiles plus one large promo card, so the highest-priority supercategory becomes the promo
///   card and the remaining six become the tiles. Tile artwork is the supercategory's first
///   category image, because the supercategory objects themselves carry no image field.
/// * **Banners** — `GET /promotions/active` may return campaigns without cover
///   artwork; their real names remain visible against the design's red fill.
/// * **Bonuses** — `GET /bonuses` gives `totalBonuses` and `bonusCard.cardUuid`; the QR payload
///   is the raw `cardUuid`, which is what the existing main page already sends to the till.
/// * **Notifications** — no unread-count endpoint exists; the header opens preferences.
class HomeDataSource {
  const HomeDataSource({this.businessId});

  /// Store to show in the address card; falls back to the first business returned.
  final int? businessId;

  Future<HomeViewData> load() async {
    final businessesFuture = ApiService.getBusinesses(page: 1, limit: 1000);
    final categoriesFuture = ApiService.getSuperCategories();
    final bonusesFuture = ApiService.getUserBonuses();
    final citiesFuture = ApiService.getAvailableCities();
    final signedInFuture = ApiService.isUserLoggedIn();

    final viewFuture = () async {
      final core = await Future.wait<Object?>([
        businessesFuture,
        categoriesFuture,
      ]);
      final businesses = _listOf(core[0], 'businesses');
      if (businesses.isEmpty) {
        throw StateError('Не удалось загрузить магазины');
      }

      final business = _pickBusiness(businesses);
      final storeId = business == null ? null : _int(business['id']);
      final supercategories = _listOf(core[1], 'supercategories');
      final ordered = [...supercategories]
        ..sort((a, b) => _int(b['priority']).compareTo(_int(a['priority'])));

      final promoSuper = ordered.isNotEmpty ? ordered.first : null;
      final tiles = ordered.skip(1).take(6).toList();
      final homeCategories = [
        for (final category in tiles)
          HomeCategory(
            id: _int(category['supercategory_id']),
            title: _string(category['name']) ?? '',
            imageUrl: _firstCategoryImage(category),
          ),
      ];
      final scoped = await Future.wait<Object?>([
        ApiService.getActivePromotions(businessId: storeId),
        storeId == null
            ? Future.value(const <HomeProductSection>[])
            : _productSections(
                storeId: storeId,
                rawCategories: tiles,
                categories: homeCategories,
              ),
        signedInFuture.then(
          (signedIn) => signedIn ? _activeOrder(storeId) : null,
        ),
      ]);
      final bonuses = _mapOf(await bonusesFuture);
      final cities = {
        for (final city in _asList(await citiesFuture))
          _int(city['city_id']): _string(city['name']),
      };
      final promotions = _listOf(scoped[0], 'promotions');
      final signedIn = await signedInFuture;
      final productSections = scoped[1] as List<HomeProductSection>;
      final activeOrder = scoped[2] as HomeActiveOrder?;
      final stores = [
        for (final raw in businesses)
          if (_int(raw['id']) > 0)
            HomeStore(
              id: _int(raw['id']),
              name: _string(raw['name']) ?? 'Градусы24',
              address: _string(raw['address']) ?? '',
              city: _string(raw['_cityName'] ?? raw['city_name']) ??
                  cities[_int(raw['city_id'])],
            ),
      ];

      return HomeViewData(
        storeName: _string(business?['name']) ?? 'Градусы24',
        storeAddress: _string(business?['address']) ?? '',
        storeId: storeId,
        stores: stores,
        activeOrder: activeOrder,
        signedIn: signedIn,
        bonusBalance: bonuses?['totalBonuses'] is num
            ? (bonuses!['totalBonuses'] as num).toInt()
            : int.tryParse('${bonuses?['totalBonuses'] ?? ''}'),
        bonusCardCode: _string(bonuses?['bonusCard']?['cardUuid']),
        banners: _banners(promotions),
        promoCard: promoSuper == null
            ? null
            : HomePromoCard(
                id: _int(promoSuper['supercategory_id']),
                title: _string(promoSuper['name']) ?? '',
                // No marketing copy in the API; the design's subtitle is not invented here.
                subtitle: _string(promoSuper['description']) ?? '',
                imageUrl: _firstCategoryImage(promoSuper),
              ),
        categories: homeCategories,
        productSections: productSections,
      );
    }();

    // Observe every independent read immediately, including early failures.
    final results = await Future.wait<Object?>([
      viewFuture,
      bonusesFuture,
      citiesFuture,
      signedInFuture,
    ]);
    return results[0] as HomeViewData;
  }

  Future<HomeActiveOrder?> _activeOrder(int? storeId) async {
    try {
      final orders = await ApiService.getMyActiveOrdersList(
        businessId: storeId,
      ).timeout(const Duration(seconds: 5));
      if (orders.isEmpty) return null;
      final order = orders.first;
      final id =
          _string(order['order_id'] ?? order['order_uuid'] ?? order['id']);
      if (id == null) return null;
      return HomeActiveOrder(
        id: id,
        status: resolveOrderStatusText(order),
        source: order,
      );
    } on Object {
      // Status is supplemental; errors never hide public home content.
      return null;
    }
  }

  Future<List<HomeProductSection>> _productSections({
    required int storeId,
    required List<Map<String, dynamic>> rawCategories,
    required List<HomeCategory> categories,
  }) async {
    final source = CatalogDataSource(businessId: storeId);
    final indices = List<int>.generate(categories.length, (index) => index)
      ..sort((a, b) => _sectionOrder(categories[a].title)
          .compareTo(_sectionOrder(categories[b].title)));
    final sections = await Future.wait<HomeProductSection?>([
      for (final index in indices.take(3))
        () async {
          final categoryId = _firstLeafCategoryId(rawCategories[index]);
          if (categoryId == null) return null;
          try {
            final products = await source
                .items(categoryId, limit: 10)
                .timeout(const Duration(seconds: 5));
            if (products.isEmpty) return null;
            return HomeProductSection(
              category: categories[index],
              products: products,
            );
          } on Object {
            // Product rows are supplementary; the main home surface remains usable.
            return null;
          }
        }(),
    ]);
    return sections.whereType<HomeProductSection>().toList(growable: false);
  }

  int _sectionOrder(String title) {
    final name = title.toLowerCase();
    if (name.contains('слабоалкогольн')) return 0;
    if (name.contains('еда') || name.contains('закуски')) return 1;
    if (name.contains('крепк')) return 2;
    return 3;
  }

  int? _firstLeafCategoryId(Map<String, dynamic> node) {
    final children = [
      ..._asList(node['categories']),
      ..._asList(node['subcategories']),
    ];
    for (final child in children) {
      final leafId = _firstLeafCategoryId(child);
      if (leafId != null) return leafId;
    }
    final id = _int(node['category_id'] ?? node['id']);
    return id == 0 ? null : id;
  }

  Map<String, dynamic>? _pickBusiness(List<Map<String, dynamic>> businesses) {
    if (businesses.isEmpty) return null;
    if (businessId != null) {
      for (final b in businesses) {
        if (_int(b['id']) == businessId) return b;
      }
    }
    return businesses.first;
  }

  List<HomeBanner> _banners(List<Map<String, dynamic>> promotions) {
    final withArt =
        promotions.where((p) => (_string(p['cover']) ?? '').isNotEmpty);
    final source = withArt.isNotEmpty ? withArt : promotions.take(3);
    return [
      for (final promo in source.take(6))
        HomeBanner(
          promotionId: _int(promo['marketing_promotion_id'] ??
                      promo['promotion_id'] ??
                      promo['id']) >
                  0
              ? _int(promo['marketing_promotion_id'] ??
                  promo['promotion_id'] ??
                  promo['id'])
              : null,
          title: _string(promo['name']) ?? '',
          imageUrl: _string(promo['cover']),
        ),
    ];
  }

  String? _firstCategoryImage(Map<String, dynamic> supercategory) {
    for (final category in _asList(supercategory['categories'])) {
      final image = _string(category['img']);
      if (image != null && image.isNotEmpty) return image;
    }
    return null;
  }

  /// The API mixes "whole body" and "already unwrapped" responses, so both are accepted.
  Object? _payloadOf(Object? response) {
    if (response is Map && response.containsKey('data')) {
      return response['data'];
    }
    return response;
  }

  List<Map<String, dynamic>> _listOf(Object? response, String key) {
    final payload = _payloadOf(response);
    final value = payload is Map ? payload[key] : payload;
    return _asList(value);
  }

  Map<String, dynamic>? _mapOf(Object? response) {
    final payload = _payloadOf(response);
    return payload is Map ? payload.cast<String, dynamic>() : null;
  }

  List<Map<String, dynamic>> _asList(Object? value) {
    if (value is! List) return const [];
    return [
      for (final entry in value)
        if (entry is Map) entry.cast<String, dynamic>(),
    ];
  }

  int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  String? _string(Object? value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? null : text;
  }
}
