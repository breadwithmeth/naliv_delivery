import '../../utils/api.dart';
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
/// * **Banners** — `GET /promotions/active` currently returns 22 promotions all named «Акции»
///   with an **empty** `cover`. Only promotions that actually carry artwork become banners;
///   when none do, the first few are shown with the design's placeholder fill.
/// * **Bonuses** — `GET /bonuses` gives `totalBonuses` and `bonusCard.cardUuid`; the QR payload
///   is the raw `cardUuid`, which is what the existing main page already sends to the till.
/// * **Notifications** — no endpoint exists, so the badge count is 0.
class HomeDataSource {
  const HomeDataSource({this.businessId});

  /// Store to show in the address card; falls back to the first business returned.
  final int? businessId;

  /// Support line. Product copy, not data: `/businesses` exposes no phone number.
  static const String supportPhone = '+7 (777) 777-77-77';
  static const String supportCaption = 'Звонок в Call Center';

  Future<HomeViewData> load() async {
    // Fetched together: four independent endpoints, one round trip of latency.
    final responses = await Future.wait<Object?>([
      ApiService.getBusinesses(),
      ApiService.getSuperCategories(),
      ApiService.getActivePromotions(),
      ApiService.getUserBonuses(),
    ]);

    final businesses = _listOf(responses[0], 'businesses');
    final supercategories = _listOf(responses[1], 'supercategories');
    final promotions = _listOf(responses[2], 'promotions');
    final bonuses = _mapOf(responses[3]);

    final business = _pickBusiness(businesses);
    final ordered = [...supercategories]
      ..sort((a, b) => _int(b['priority']).compareTo(_int(a['priority'])));

    final promoSuper = ordered.isNotEmpty ? ordered.first : null;
    final tiles = ordered.skip(1).take(6).toList();
    final storeId = business == null ? null : _int(business['id']);
    final homeCategories = [
      for (final category in tiles)
        HomeCategory(
          id: _int(category['supercategory_id']),
          title: _string(category['name']) ?? '',
          imageUrl: _firstCategoryImage(category),
        ),
    ];
    final productSections = storeId == null
        ? const <HomeProductSection>[]
        : await _productSections(
            storeId: storeId,
            rawCategories: tiles,
            categories: homeCategories,
          );

    return HomeViewData(
      phone: supportPhone,
      callCenterLabel: supportCaption,
      storeName: _string(business?['name']) ?? 'Градусы24',
      storeAddress: _string(business?['address']) ?? '',
      storeId: storeId,
      notificationCount: 0,
      signedIn: await ApiService.isUserLoggedIn(),
      bonusBalance: bonuses == null ? null : _int(bonuses['totalBonuses']),
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
  }

  Future<List<HomeProductSection>> _productSections({
    required int storeId,
    required List<Map<String, dynamic>> rawCategories,
    required List<HomeCategory> categories,
  }) async {
    final source = CatalogDataSource(businessId: storeId);
    final sections = await Future.wait<HomeProductSection?>([
      for (var index = 0; index < categories.length && index < 3; index++)
        () async {
          final categoryId = _firstLeafCategoryId(rawCategories[index]);
          if (categoryId == null) return null;
          try {
            final products = await source.items(categoryId, limit: 10);
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
