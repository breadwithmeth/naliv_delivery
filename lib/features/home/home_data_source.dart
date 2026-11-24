import 'dart:async';

import '../../core/json_payload.dart';
import '../../core/kitchen_policy.dart';
import '../../services/auth_service.dart';
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
///   Табачная продукция 7, Безалкогольные напитки 2). The design's home shows up to six
///   tiles plus one large promo card. The promo card is the kitchen supercategory and exists
///   only where [KitchenPolicy] sells the kitchen; the remaining supercategories, by priority,
///   become the (up to six) tiles. Tile artwork is the supercategory's first
///   category image, because the supercategory objects themselves carry no image field.
/// * **Banners** — `GET /promotions/active` may return campaigns without cover
///   artwork; their real names remain visible against the design's red fill.
/// * **Bonuses** — `GET /bonuses` gives `totalBonuses` and `bonusCard.cardUuid`; the QR payload
///   is the raw `cardUuid`, which is what the existing main page already sends to the till.
class HomeDataSource {
  const HomeDataSource({
    this.businessId,
    this.session,
    this.allowDefaultBusiness = true,
    this.onBusinessSelected,
  });

  // An explicit persisted cart store must never fall back to another store.
  final int? businessId;

  /// A session already verified by the route owner; `null` loads public home.
  final AuthSession? session;
  final bool allowDefaultBusiness;
  final Future<bool> Function(Map<String, dynamic> business)?
      onBusinessSelected;

  Future<HomeViewData> load() async {
    final auth = session;
    final citiesFuture = ApiService.getAvailableCities(
      useCachedCredential: false,
    );
    final bonusesFuture = auth != null && auth.isCurrent
        ? ApiService.getUserBonuses(credentialToken: auth.token)
        : Future<Map<String, dynamic>?>.value();
    final (businessResponse, categoryResponse) = await (
      ApiService.getBusinesses(page: 1, limit: 1000),
      ApiService.getSuperCategories(),
    ).wait;
    final businesses = _listOf(businessResponse, 'businesses');
    if (businesses.isEmpty) {
      throw StateError('Не удалось загрузить магазины');
    }

    final business = _pickBusiness(businesses);
    final storeId = business == null ? null : _int(business['id']);
    if (business != null &&
        onBusinessSelected != null &&
        !await onBusinessSelected!(business)) {
      throw StateError('Не удалось сохранить выбранный магазин');
    }
    final supercategories = _listOf(categoryResponse, 'supercategories');
    // Only the kitchen is eligible for the large promo card.
    final visible = KitchenPolicy.filterSupercategories(
      supercategories,
      storeId,
    );
    final promoSuper = KitchenPolicy.isAvailableForBusiness(storeId)
        ? visible.where(_isKitchen).firstOrNull
        : null;
    final tiles = ([
      for (final category in visible)
        if (!identical(category, promoSuper)) category,
    ]..sort(
            (a, b) => _int(b['priority']).compareTo(_int(a['priority'])),
          ))
        .take(6)
        .toList();
    final homeCategories = [
      for (final category in tiles)
        HomeCategory(
          id: _int(category['supercategory_id']),
          title: _string(category['name']) ?? '',
          imageUrl: _firstCategoryImage(category),
        ),
    ];
    final (
      promotions,
      productSections,
      activeOrder,
      bonusResponse,
      cityRows,
    ) = await (
      ApiService.getActivePromotions(businessId: storeId),
      storeId == null
          ? Future.value(const <HomeProductSection>[])
          : _productSections(
              storeId: storeId,
              rawCategories: tiles,
              categories: homeCategories,
            ),
      auth == null
          ? Future<HomeActiveOrder?>.value()
          : _activeOrder(storeId, auth),
      bonusesFuture,
      citiesFuture,
    ).wait;
    final cities = {
      for (final city in cityRows ?? const <Map<String, dynamic>>[])
        if (_cityId(city['city_id']) case final id?) id: _string(city['name']),
    };
    final stores = <HomeStore>[];
    for (final raw in businesses) {
      final id = _int(raw['id']);
      if (id <= 0) continue;
      final cityId = _cityId(raw['city_id']);
      stores.add(
        HomeStore(
          id: id,
          name: _string(raw['name']) ?? 'Градусы24',
          address: _string(raw['address']) ?? '',
          cityId: cityId,
          city: _string(raw['_cityName'] ?? raw['city_name']) ?? cities[cityId],
        ),
      );
    }

    // One session owns all private fields, including results that finished
    // while the store-scoped public requests were still running.
    final signedIn = auth?.isCurrent ?? false;
    final bonuses = switch (signedIn ? bonusResponse : null) {
      {'success': true, 'data': Map<String, dynamic> data} => data,
      _ => null,
    };
    final balance = switch (bonuses?['totalBonuses']) {
      final num value => value,
      final String value => num.tryParse(value),
      _ => null,
    };
    final cardCode = switch (bonuses?['bonusCard']) {
      {'cardUuid': final String value} => payloadString(value),
      _ => null,
    };

    return HomeViewData(
      storeName: _string(business?['name']) ?? 'Выберите магазин',
      storeAddress: _string(business?['address']) ??
          'Магазин сохранённой корзины не определён',
      storeId: storeId,
      storeCityId: _cityId(business?['city_id']),
      stores: stores,
      activeOrder: signedIn ? activeOrder : null,
      signedIn: signedIn,
      bonusBalance: balance != null && balance.isFinite ? balance : null,
      bonusCardCode: cardCode,
      banners: _banners(_listOf(promotions, 'promotions')),
      promoCard: promoSuper == null
          ? null
          : HomePromoCard(
              id: _int(promoSuper['supercategory_id']),
              title: _string(promoSuper['name']) ?? '',
              subtitle: _string(promoSuper['description']) ?? '',
              imageUrl: _firstCategoryImage(promoSuper),
            ),
      categories: homeCategories,
      productSections: productSections,
    );
  }

  Future<HomeActiveOrder?> _activeOrder(int? storeId, AuthSession auth) async {
    if (!auth.isCurrent) return null;
    try {
      final orders = await ApiService.getMyActiveOrdersList(
        businessId: storeId,
        credentialToken: auth.token,
      ).timeout(const Duration(seconds: 5));
      if (!auth.isCurrent || orders.isEmpty) return null;
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

  bool _isKitchen(Map<String, dynamic> supercategory) =>
      KitchenPolicy.isKitchenSupercategory(
        id: _int(supercategory['supercategory_id']),
        name: _string(supercategory['name']),
      );

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
      throw StateError('Магазин сохранённой корзины недоступен');
    }
    return allowDefaultBusiness ? businesses.first : null;
  }

  List<HomeBanner> _banners(List<Map<String, dynamic>> promotions) {
    final withArt =
        promotions.where((p) => (_string(p['cover']) ?? '').isNotEmpty);
    final source = withArt.isNotEmpty ? withArt : promotions.take(3);
    return [
      for (final promo in source.take(6))
        HomeBanner(
          promotionId: _int(
                    promo['marketing_promotion_id'] ??
                        promo['promotion_id'] ??
                        promo['id'],
                  ) >
                  0
              ? _int(
                  promo['marketing_promotion_id'] ??
                      promo['promotion_id'] ??
                      promo['id'],
                )
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

  List<Map<String, dynamic>> _asList(Object? value) {
    if (value is! List) return const [];
    return [
      for (final entry in value)
        if (entry is Map) entry.cast<String, dynamic>(),
    ];
  }

  int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  int? _cityId(Object? value) {
    final id = switch (value) {
      final int value => value,
      final String value => int.tryParse(value),
      _ => null,
    };
    return id != null && id > 0 ? id : null;
  }

  String? _string(Object? value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? null : text;
  }
}
