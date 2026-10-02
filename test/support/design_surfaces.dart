// Development-only synthetic states and credentials; strict transports never reach production.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/core/destinations.dart';
import 'package:naliv_delivery/core/product_view.dart';
import 'package:naliv_delivery/core/theme_controller.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/cart/ui/cart_page.dart';
import 'package:naliv_delivery/features/catalog/ui/category_products_page.dart';
import 'package:naliv_delivery/features/catalog/ui/supercategory_page.dart';
import 'package:naliv_delivery/features/certificates/certificate_purchase_session.dart';
import 'package:naliv_delivery/features/certificates/ui/certificate_purchase_sheet.dart';
import 'package:naliv_delivery/features/checkout/ui/payment_success_page.dart';
import 'package:naliv_delivery/features/bonuses/ui/bonus_history_page.dart';
import 'package:naliv_delivery/features/bonuses/ui/bonus_how_it_works_page.dart';
import 'package:naliv_delivery/features/onboarding/ui/intro_slides_page.dart';
import 'package:naliv_delivery/features/search/ui/search_page.dart';
import 'package:naliv_delivery/features/favorites/ui/favorites_page.dart';
import 'package:naliv_delivery/features/home/ui/home_store_sheet.dart';
import 'package:naliv_delivery/pages/login_page.dart';
import 'package:naliv_delivery/pages/notification_settings_page.dart';
import 'package:naliv_delivery/pages/profile_setup_page.dart';
import 'package:naliv_delivery/utils/smart_cart.dart';
import 'package:naliv_delivery/utils/subtract_promotion_math.dart';
import 'package:naliv_delivery/widgets/app_loading_screen.dart';
import 'package:naliv_delivery/widgets/authentication_wrapper.dart';
import 'package:naliv_delivery/features/home/home_view_data.dart';
import 'package:naliv_delivery/features/home/ui/home_page.dart';
import 'package:naliv_delivery/features/profile/ui/profile_page.dart';
import 'package:naliv_delivery/features/profile/profile_account.dart';
import 'package:naliv_delivery/features/certificates/ui/certificates_page.dart';
import 'package:naliv_delivery/features/orders/ui/orders_page.dart';
import 'package:naliv_delivery/features/faq/ui/faq_page.dart';
import 'package:naliv_delivery/pages/checkout_page.dart';
import 'package:naliv_delivery/pages/map_address_page.dart';
import 'package:naliv_delivery/pages/onboarding_page.dart';
import 'package:naliv_delivery/pages/payment_method_page.dart';
import 'package:naliv_delivery/pages/product_detail_page.dart';
import 'package:naliv_delivery/pages/profile_addresses_page.dart';
import 'package:naliv_delivery/pages/profile_cards_page.dart';
import 'package:naliv_delivery/pages/promotion_items_page.dart';
import 'package:naliv_delivery/pages/order_detail_page.dart';
import 'package:naliv_delivery/pages/help_chat_page.dart';
import 'package:naliv_delivery/services/chat_api_service.dart';
import 'package:naliv_delivery/utils/api.dart' show ApiService;
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:naliv_delivery/utils/liked_items_provider.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/models/cart_item.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/location_service.dart';
import 'package:naliv_delivery/widgets/address_selection_modal_material.dart';
import 'package:provider/provider.dart';

import 'fixture_map_tiles.dart';
import 'configuration_items.dart';
import 'bottling_surface_items.dart';
import 'remaining_milestone_fixture.dart';

const surfaceIds = <String>[
  'home',
  'catalog',
  'all_products',
  'cart',
  'profile',
  'profile_guest',
  'promotion',
  'orders',
  'order_detail',
  'support',
  'certificates',
  'onboarding',
  'addresses',
  'address_map',
  'address_details',
  'cards',
  'payment_method',
  'payment_kaspi',
  'checkout_delivery',
  'checkout_pickup',
  'checkout_error',
  'certificate_purchase',
  'product_options',
  'product_pour',
  'payment_success',
  'product_pour_real',
  'product_pour_gift',
  'product_pour_three_plus_one',
  'product_pour_fractional',
  'product_replacement',
  'search',
  'favorites',
  'bonus_history',
  'bonus_explainer',
  'faq',
  'notifications',
  'intro',
  'sign_in',
  'profile_setup',
  'startup',
  'active_route',
];
const designSurfaceSize = Size(375, 812);
const designSurfaceInsets = EdgeInsets.only(top: 48, bottom: 34);

enum CardFixtureScenario {
  loaded,
  empty,
  readTimeout,
  partial,
  invalid,
  authentication,
  linkTimeout
}

const surfaceFixturePreferences = <String, Object>{
  'telemetry_consent_enabled': false,
  'auth_token': 'fixture-only',
  'chat_widget_session': '{"id":"fixture-session","token":"fixture-chat"}',
  'onboarding_selected_city': 'Караганда',
  'selected_business':
      '{"id":1,"name":"Тестовый магазин","address":"Тестовый адрес, 16","city":"Караганда","city_id":2}',
  'selected_business_id': 1,
  'selected_address':
      '{"id":501,"address":"Тестовый адрес, 16","street":"Тестовый адрес","house":"16","city":"Караганда","country":"Казахстан","lat":49.8047,"lon":73.1094,"entrance":"2","floor":"7","apartment":"45"}',
};

const _fixtureAccount = ProfileAccount(
  name: 'Айжан · фикстура',
  phone: '+7 (000) 000-00-00',
  addressSummary: '1 адрес · Тестовый адрес, 16',
  cardsSummary: '1 карта · 4400••••1234',
);

const _fixtureAddress = <String, dynamic>{
  'id': 501,
  'address': 'Тестовый адрес, 16',
  'street': 'Тестовый адрес',
  'house': '16',
  'city': 'Караганда',
  'country': 'Казахстан',
  'lat': 49.8047,
  'lon': 73.1094,
  'entrance': '2',
  'floor': '7',
  'apartment': '45',
};

const _fixtureAddressFeature = <String, dynamic>{
  'type': 'Feature',
  'geometry': {
    'type': 'Point',
    'coordinates': [73.1094, 49.8047],
  },
  'properties': {
    'geocoding': {
      'country': 'Казахстан',
      'city': 'Караганда',
      'street': 'Тестовый адрес',
      'housenumber': '16',
      'name': 'Тестовый адрес, 16',
    },
  },
};

const _fixtureOrder = <String, dynamic>{
  'order_id': 45,
  'log_timestamp': '2026-10-01T11:40:00Z',
  'user': {'phone': '+7 (000) 000-00-00'},
  'payment_method': 'Картой',
  'delivery_type': 'DELIVERY',
  'delivery_address': {'address': 'Тестовый адрес, 16'},
  'business': {
    'id': 1,
    'name': 'Тестовый магазин',
    'address': 'Тестовый адрес, 16'
  },
  'items': [
    {'item_id': 1, 'name': 'Тестовый напиток', 'amount': 1, 'price': 13170},
    {'item_id': 2, 'name': 'Тестовая закуска', 'amount': 2, 'price': 13170},
  ],
  'cost_summary': {
    'items_total': 39510,
    'delivery_fee': 900,
    'total_sum': 40410
  },
  'current_status': {'status': '4'},
  'order_statuses': [
    {'status': '4', 'log_timestamp': '2026-10-01T12:00:00Z'}
  ],
};

const _sampleAddress = 'Тестовый адрес, 16';
const _sampleName = 'Aperol, Аперитив, Италия, 0,5 л';

const _homeData = HomeViewData(
  storeName: 'Тестовый магазин',
  storeAddress: _sampleAddress,
  signedIn: false,
  banners: [
    HomeBanner(
      promotionId: 7,
      title: 'Предложения недели',
      fill: Color(0xFF880514),
    ),
  ],
  promoCard: HomePromoCard(id: 1, title: 'Кухня', subtitle: 'Готовые блюда'),
  categories: [
    HomeCategory(id: 1, title: 'Слабоалкогольное', fill: Color(0xFFF16800)),
    HomeCategory(id: 2, title: 'Еда и закуски', fill: Color(0xFFF16800)),
    HomeCategory(id: 3, title: 'Крепкий алкоголь', fill: Color(0xFFF16800)),
    HomeCategory(id: 4, title: 'Безалкогольное', fill: Color(0xFFF16800)),
    HomeCategory(id: 5, title: 'Табак', fill: Color(0xFFF16800)),
    HomeCategory(id: 6, title: 'Прочее', fill: Color(0xFFF16800)),
  ],
);

Item _sampleItem(int id, {String category = 'Аперитив'}) => Item(
      itemId: id,
      name: _sampleName,
      price: 13170,
      image: '',
      amount: 20,
      unit: 'шт.',
      category: ItemCategory(categoryId: 10, name: category),
    );

final List<ProductView> _products = [
  for (var id = 100; id < 109; id++)
    ProductView.fromItem(_sampleItem(id, category: 'Белое')),
];

CartProvider _cartFor(String surface) {
  final cart = CartProvider();
  if (surface == 'cart' || surface.startsWith('checkout_')) _seedCart(cart);
  return cart;
}

void _seedCart(CartProvider cart) {
  for (final (id, quantity) in [(100, 1.0), (101, 6.0), (102, 1.0)]) {
    final item = _sampleItem(id);
    cart.addItem(CartItem(
      itemId: id,
      name: item.name,
      price: item.price,
      quantity: quantity,
      stepQuantity: 1,
      image: item.image,
      selectedVariants: const [],
      promotions: const [],
      itemData: item.toJson(),
    ));
  }
}

// Only explicitly recognized synthetic operations are accepted; unknown calls
// remain recorded even when the UI handles the resulting transport exception.
class SurfaceFixtureClient extends MockClient {
  SurfaceFixtureClient({void Function(String)? onUnexpectedRequest})
      : super((request) => _respond(request, onUnexpectedRequest));

  static final List<String> unexpectedRequests = [];
  static CardFixtureScenario cardScenario = CardFixtureScenario.loaded;
  static bool _cardScenarioConsumed = false;
  static final Map<String, dynamic> _fixtureUser = {
    'id': 999,
    'name': 'Айжан · фикстура',
    'login': '+7 (000) 000-00-00',
    'date_of_birth': '1990-08-05',
    'sex': 0,
  };

  static void configureCards(CardFixtureScenario scenario) {
    cardScenario = scenario;
    _cardScenarioConsumed = false;
  }

  static CartProvider? _orderCart;
  static void useCartForOrders(CartProvider? cart) => _orderCart = cart;

  static bool _boundFixtureCard = false;
  static void confirmFixtureCardBinding() => _boundFixtureCard = true;
  static List<Map<String, dynamic>> get cards => [
        if (cardScenario != CardFixtureScenario.empty)
          {
            'id': 'fixture-card-1',
            'card_id': 'fixture-card-1',
            'mask': '4400••••1234'
          },
        if (_boundFixtureCard)
          {
            'id': 'fixture-card-2',
            'card_id': 'fixture-card-2',
            'mask': '4400••••5678'
          },
      ];

  static void resetUnexpectedRequests() {
    unexpectedRequests.clear();
    _chatMessages.removeWhere((message) => (message['id'] as int) > 1);
    _fixtureLikes.clear();
    _boundFixtureCard = false;
    _orderCart = null;
    configureCards(CardFixtureScenario.loaded);
    _fixtureUser
      ..['name'] = 'Айжан · фикстура'
      ..['date_of_birth'] = '1990-08-05'
      ..['sex'] = 0;
    RemainingMilestoneFixture.reset();
  }

  static final _orderCatalog = <int, Item>{
    for (var id = 100; id < 109; id++) id: _sampleItem(id),
    1: fixturePourItem(),
    502: fixtureOptionItem(),
    30318: capturedPourSurfaceItem(),
    9201: fractionalPourSurfaceItem(),
    1186: capturedPourSurfaceItem(gift: true),
    9301: syntheticThreePlusOneSurfaceItem(),
    9202: fractionalPourSurfaceItem(replacement: true),
  };

  static List<Map<String, dynamic>> _fixtureOrderItems(
      List<Map<String, dynamic>> rows) {
    final groups = _orderCart?.activeDisplayGroups;
    if (groups == null) {
      throw StateError('Fixture order requires its current cart snapshot');
    }
    final expected = <(CartDisplayGroup, Map<String, dynamic>, CartItem)>[];
    for (final group in groups) {
      final invoiceRows = group.toJsonForOrder();
      final physicalRows = group.selection?.usesPourFlow == true
          ? group.physicalItems
          : group.items;
      for (var index = 0; index < invoiceRows.length; index++) {
        expected.add((group, invoiceRows[index], physicalRows[index]));
      }
    }
    final consumed = <int>{};
    bool sameRow(Map<String, dynamic> first, Map<String, dynamic> second) {
      List<int> relations(Map<String, dynamic> row) => [
            for (final option in row['options'] as List)
              (option as Map)['option_item_relation_id'] as int,
          ]..sort();
      return first['item_id'] == second['item_id'] &&
          ((first['amount'] as num) - (second['amount'] as num)).abs() < 1e-6 &&
          jsonEncode(relations(first)) == jsonEncode(relations(second));
    }

    final result = <Map<String, dynamic>>[];
    var packageSeen = false;
    for (final row in rows) {
      final id = row['item_id'];
      if (id == 48044 &&
          !packageSeen &&
          row['amount'] == 1 &&
          (row['options'] as List).isEmpty) {
        packageSeen = true;
        result.add({...row, 'name': 'Пакет', 'price': 30});
        continue;
      }
      var index = -1;
      for (var candidate = 0; candidate < expected.length; candidate++) {
        if (!consumed.contains(candidate) &&
            sameRow(expected[candidate].$2, row)) {
          index = candidate;
          break;
        }
      }
      final item = _orderCatalog[id];
      if (index == -1 || item == null) {
        final reason = 'Fixture order row does not match current cart: $row';
        unexpectedRequests.add(reason);
        throw StateError(reason);
      }
      consumed.add(index);
      final physical = expected[index].$3;
      final lineTotal = applyPromotionsToPaidBaseTotal(
              unitPrice: physical.paidUnitPrice,
              quantity: physical.quantity,
              promotions: expected[index].$1.promotions) +
          physical.optionsTotal;
      result.add({
        ...row,
        'name': item.name,
        'item_data': item.toJson(),
        // Preserve the original paid/gift split. A gift row charges its
        // ordinary container tariff, not another promoted drink quantity.
        'price': lineTotal / (row['amount'] as num),
      });
    }
    if (consumed.length != expected.length) {
      throw StateError('Fixture order omitted a current cart row');
    }
    return result;
  }

  static Future<http.Response> _respond(
      http.Request request, void Function(String)? onUnexpectedRequest) async {
    final url = request.url;
    if (url.scheme != 'https') return _reject(request, onUnexpectedRequest);
    if (url.host == 'bm.drawbridge.kz') {
      return _chatResponse(request, onUnexpectedRequest);
    }
    if (url.host != 'njt25.naliv.kz' || url.pathSegments.firstOrNull != 'api') {
      return _reject(request, onUnexpectedRequest);
    }
    final authorized =
        request.headers['Authorization'] == 'Bearer fixture-only';
    if (!authorized &&
        request.headers.keys
            .any((key) => key.toLowerCase() == 'authorization')) {
      return _reject(request, onUnexpectedRequest);
    }
    final remaining = await RemainingMilestoneFixture.respond(
      request,
      authorized: authorized,
      cards: cards,
      orderItems: _fixtureOrderItems,
      reject: () => _reject(request, onUnexpectedRequest),
    );
    if (remaining != null) return remaining;
    if (request.method == 'POST' &&
        url.path == '/api/auth/send-code' &&
        url.queryParameters.isEmpty) {
      final body = jsonDecode(request.body);
      if (body is Map &&
          body.length == 1 &&
          body['phone_number'] == '+70000000000') {
        return _json({
          'success': true,
          'message': 'Синтетический код: 123456. SMS не отправляется.'
        });
      }
      return _reject(request, onUnexpectedRequest);
    }
    if (request.method == 'POST' &&
        url.path == '/api/auth/verify-code' &&
        url.queryParameters.isEmpty) {
      final body = jsonDecode(request.body);
      if (body is Map &&
          body.length == 2 &&
          body['phone_number'] == '+70000000000' &&
          body['onetime_code'] == '123456') {
        if (cardScenario == CardFixtureScenario.authentication) {
          configureCards(CardFixtureScenario.loaded);
        }
        return http.Response(
            jsonEncode({
              'success': true,
              'data': {'token': 'fixture-only'},
            }),
            202,
            headers: {'content-type': 'application/json'});
      }
      return _reject(request, onUnexpectedRequest);
    }
    if (authorized &&
        request.method == 'GET' &&
        url.path == '/api/users/liked-items' &&
        const {'1', '2'}.contains(url.queryParameters['business_id']) &&
        url.queryParameters['page'] == '1' &&
        url.queryParameters['limit'] == '20' &&
        url.queryParameters.length == 3) {
      return _json({
        'success': true,
        'data': {
          'items': [for (final id in _fixtureLikes) _sampleItem(id).toJson()],
          'pagination': {'page': 1, 'total_pages': 1},
        }
      });
    }
    if (request.method == 'GET' &&
        url.path == '/api/items/search' &&
        const {'1', '2'}.contains(url.queryParameters['business_id']) &&
        url.queryParameters['page'] == '1' &&
        url.queryParameters['limit'] == '40' &&
        (url.queryParameters['name']?.trim().isNotEmpty ?? false) &&
        url.queryParameters.length == 4) {
      return _json({
        'success': true,
        'data': {
          'items': [
            if (url.queryParameters['name'] != 'нет')
              for (var id = 100; id < 103; id++) _sampleItem(id).toJson(),
          ],
          'pagination': {'page': 1, 'total_pages': 1},
        }
      });
    }
    if (authorized &&
        request.method == 'GET' &&
        url.path == '/api/auth/full-info' &&
        url.queryParameters.isEmpty) {
      return _json({
        'success': true,
        'data': {
          'user': Map<String, dynamic>.from(_fixtureUser),
          'addresses': [_fixtureAddress],
          'cards': [
            for (final card in cards) {'mask': card['mask']}
          ],
          'certificates': RemainingMilestoneFixture.certificates,
        }
      });
    }
    if (authorized &&
        request.method == 'PATCH' &&
        url.path == '/api/users/profile' &&
        url.queryParameters.isEmpty) {
      final body = jsonDecode(request.body);
      if (body is Map &&
          body.keys.every(const {
            'name',
            'first_name',
            'last_name',
            'date_of_birth',
            'sex'
          }.contains) &&
          body['name'] is String &&
          body['first_name'] is String &&
          body['date_of_birth'] is String &&
          body['sex'] is int) {
        _fixtureUser.addAll(body.cast<String, dynamic>());
        return _json({
          'success': true,
          'data': {'user': _fixtureUser}
        });
      }
      return _reject(request, onUnexpectedRequest);
    }
    if (authorized &&
        request.method == 'POST' &&
        url.path == '/api/users/liked-items/toggle' &&
        url.queryParameters.isEmpty) {
      final body = jsonDecode(request.body);
      if (body is Map && body.length == 1 && body['item_id'] is int) {
        final id = body['item_id'] as int;
        final liked = _fixtureLikes.add(id);
        if (!liked) _fixtureLikes.remove(id);
        return _json({
          'success': true,
          'data': {'is_liked': liked}
        });
      }
    }
    if (authorized &&
        request.method == 'GET' &&
        url.path == '/api/orders/45' &&
        url.queryParameters.isEmpty) {
      return _json({
        'success': true,
        'data': {'order': _fixtureOrder}
      });
    }
    if (authorized &&
        request.method == 'GET' &&
        url.path == '/api/orders/my-orders' &&
        url.queryParameters['page'] == '1' &&
        (url.queryParameters['business_id'] == null ||
            const {'1', '2'}.contains(url.queryParameters['business_id'])) &&
        url.queryParameters.keys
            .every(const {'page', 'business_id'}.contains)) {
      return _json({
        'success': true,
        'data': {
          'orders': [
            ...RemainingMilestoneFixture.orders.where((order) =>
                url.queryParameters['business_id'] == null ||
                order['business_id'].toString() ==
                    url.queryParameters['business_id']),
            _fixtureOrder,
          ]
        }
      });
    }
    if (authorized &&
        request.method == 'GET' &&
        url.path == '/api/certificates' &&
        {'active', 'redeemed', 'canceled'}
            .contains(url.queryParameters['status']) &&
        url.queryParameters['limit'] == '50' &&
        url.queryParameters['offset'] == '0' &&
        url.queryParameters.length == 3) {
      final status = url.queryParameters['status'];
      return _json({
        'success': true,
        'data': {
          'certificates': [
            if (status == 'active') ...RemainingMilestoneFixture.certificates,
            {
              'code': 'FIXT-URE0-0000-0001',
              'balance': status == 'active' ? 10000 : 0,
              'initial_amount': 10000,
              'status': status
            },
          ]
        },
      });
    }
    if (authorized &&
        request.method == 'POST' &&
        url.path == '/api/certificates/claim' &&
        url.queryParameters.isEmpty) {
      final body = jsonDecode(request.body);
      if (body is Map && body.length == 1 && body['code'] is String) {
        return _json(
            {'success': false, 'error': 'Фикстура: сертификат не найден'});
      }
    }
    if (authorized &&
        request.method == 'POST' &&
        url.path == '/api/payments/generate-add-card-link' &&
        url.queryParameters.isEmpty &&
        request.body.isEmpty) {
      if (cardScenario == CardFixtureScenario.linkTimeout &&
          !_cardScenarioConsumed) {
        _cardScenarioConsumed = true;
        return Completer<http.Response>().future;
      }
      return _json({
        'success': true,
        'data': {'addCardLink': 'https://fixture-bank.example/card/attach'},
      });
    }
    if (authorized &&
        request.method == 'GET' &&
        url.path == '/api/user/cards' &&
        url.queryParameters['source'] == 'halyk' &&
        url.queryParameters.length == 1) {
      if (cardScenario == CardFixtureScenario.authentication) {
        return http.Response('{"success":false}', 401,
            headers: {'content-type': 'application/json'});
      }
      if (cardScenario == CardFixtureScenario.readTimeout &&
          !_cardScenarioConsumed) {
        _cardScenarioConsumed = true;
        return Completer<http.Response>().future;
      }
      return _json({
        'success': true,
        'data': {
          'cards': [
            if (cardScenario != CardFixtureScenario.invalid) ...cards,
            if (cardScenario == CardFixtureScenario.partial ||
                cardScenario == CardFixtureScenario.invalid)
              {'mask': '4400••••9999'}, // Summary-only: cannot be charged.
          ]
        },
      });
    }
    if (authorized &&
        request.method == 'GET' &&
        url.path == '/api/bonuses' &&
        url.queryParameters.isEmpty) {
      return _json({
        'success': true,
        'data': {
          'totalBonuses': 3951,
          'bonusCard': {'cardUuid': 'fixture-card-code'},
          'bonusHistory': [
            {
              'bonusId': 1,
              'organizationId': 1,
              'amount': 250,
              'timestamp': '2026-10-01T12:00:00Z'
            },
            {
              'bonusId': 2,
              'organizationId': 1,
              'amount': -100,
              'timestamp': '2026-09-29T12:00:00Z'
            },
          ],
        },
      });
    }
    if (authorized &&
        request.method == 'GET' &&
        url.path == '/api/orders/my-active-orders' &&
        const {'1', '2'}.contains(url.queryParameters['business_id']) &&
        url.queryParameters.length == 1) {
      return _json({
        'success': true,
        'data': {'orders': []}
      });
    }
    if (request.method == 'GET' &&
        url.path == '/api/businesses' &&
        url.queryParameters['page'] == '1' &&
        url.queryParameters['limit'] == '1000' &&
        url.queryParameters.length == 2) {
      return _json({
        'success': true,
        'data': {
          'businesses': [
            {
              'id': 1,
              'name': 'Тестовый магазин',
              'address': _sampleAddress,
              'city_id': 2,
              'city': 'Караганда',
            },
            {
              'id': 2,
              'name': 'Второй тестовый магазин',
              'address': 'Другой тестовый адрес, 20',
              'city_id': 2,
              'city': 'Караганда',
            },
          ],
        },
      });
    }
    if (request.method == 'GET' &&
        const {'/api/businesses/1', '/api/businesses/2'}.contains(url.path) &&
        url.queryParameters.isEmpty) {
      return _json({
        'success': true,
        'data': {
          'id': url.pathSegments.last == '1' ? 1 : 2,
          'name': url.pathSegments.last == '1'
              ? 'Тестовый магазин'
              : 'Второй тестовый магазин',
          'address': url.pathSegments.last == '1'
              ? _sampleAddress
              : 'Другой тестовый адрес, 20',
          'city_id': 2
        },
      });
    }
    if (request.method == 'GET' &&
        url.path == '/api/promotions/active' &&
        const {'1', '2'}.contains(url.queryParameters['business_id']) &&
        url.queryParameters['limit'] == '50' &&
        url.queryParameters['offset'] == '0' &&
        url.queryParameters.length == 3) {
      return _json({
        'success': true,
        'data': {'promotions': []}
      });
    }
    if (request.method == 'GET' &&
        url.path == '/api/users/cities' &&
        url.queryParameters.isEmpty) {
      return _json({
        'success': true,
        'data': {
          'cities': [
            {'city_id': 2, 'name': 'Караганда', 'delivery_type': 'AREA'},
            {'city_id': 1, 'name': 'Павлодар', 'delivery_type': 'DISTANCE'},
          ],
        },
      });
    }
    if (request.method == 'GET' &&
        url.path == '/api/addresses/reverse' &&
        url.queryParameters.length == 2 &&
        double.tryParse(url.queryParameters['lat'] ?? '')?.isFinite == true &&
        double.tryParse(url.queryParameters['lon'] ?? '')?.isFinite == true) {
      return _json({
        'success': true,
        'data': [_fixtureAddressFeature]
      });
    }
    if (request.method == 'GET' &&
        url.path == '/api/addresses/search' &&
        (url.queryParameters['query']?.trim().length ?? 0) >= 2 &&
        url.queryParameters.keys.every(
          (key) => const {'query', 'city', 'country'}.contains(key),
        ) &&
        (url.queryParameters['city'] == null ||
            url.queryParameters['city'] == 'Караганда') &&
        (url.queryParameters['country'] == null ||
            url.queryParameters['country'] == 'Казахстан')) {
      return _json({
        'success': true,
        'data': {
          'features': [_fixtureAddressFeature]
        }
      });
    }
    if (request.method != 'GET' ||
        request.headers.keys
            .any((key) => key.toLowerCase() == 'authorization')) {
      return _reject(request, onUnexpectedRequest);
    }
    if (url.path == '/api/categories/supercategories' &&
        url.queryParameters.isEmpty) {
      return _json({
        'success': true,
        'data': {
          'supercategories': [
            {
              'supercategory_id': 90,
              'name': 'Кухня',
              'description': 'Готовые блюда',
              'priority': 100,
              'categories': [
                {'category_id': 90, 'name': 'Готовые блюда'}
              ],
            },
            {
              'supercategory_id': 1,
              'name': 'Слабоалкогольные напитки',
              'priority': 90,
              'categories': [
                {
                  'category_id': 2,
                  'name': 'Вино',
                  'subcategories': [
                    {'category_id': 10, 'name': 'Аперитив'},
                    {'category_id': 11, 'name': 'Белое'},
                    {'category_id': 12, 'name': 'Розовое'},
                  ],
                },
              ],
            },
            for (final (id, name) in const [
              (2, 'Еда и закуски'),
              (3, 'Крепкий алкоголь'),
              (4, 'Табачная продукция'),
              (5, 'Безалкогольное'),
              (6, 'Аксессуары'),
            ])
              {
                'supercategory_id': id,
                'name': name,
                'priority': 90 - id,
                'categories': [
                  {'category_id': 30 + id, 'name': name}
                ],
              },
          ],
        },
      });
    }
    if (url.pathSegments.length == 4 &&
        url.pathSegments[1] == 'categories' &&
        url.pathSegments[3] == 'items' &&
        {'10', '11', '12', '32', '33', '34', '35', '36', '90', '221'}
            .contains(url.pathSegments[2]) &&
        const {'1', '2'}.contains(url.queryParameters['business_id']) &&
        url.queryParameters['page'] == '1' &&
        {'10', '24', '60'}.contains(url.queryParameters['limit']) &&
        url.queryParameters.length == 3) {
      return _json({
        'success': true,
        'data': {
          'items': [
            if (const {'10', '11', '12'}.contains(url.pathSegments[2]))
              for (var id = 100; id < 109; id++)
                {
                  'item_id': id,
                  'name': _sampleName,
                  'price': 13170,
                  'amount': 20,
                  'measure': 'шт.',
                  'category': {'category_id': 10, 'name': 'Аперитив'},
                },
          ],
        },
      });
    }
    return _reject(request, onUnexpectedRequest);
  }

  static const _chatBase = '/api/widget/wgt_Ioj4vp2arln68wZeSMeyWd4l';
  static final _fixtureLikes = <int>{};
  static final _chatMessages = <Map<String, dynamic>>[
    {
      'id': 1,
      'content': 'Здравствуйте! Чем можем помочь?',
      'fromMe': true,
      'timestamp': '2026-10-01T12:00:00Z',
      'senderUser': {'name': 'Поддержка · фикстура'}
    },
  ];

  static Future<http.Response> _chatResponse(
      http.Request request, void Function(String)? onUnexpectedRequest) async {
    final url = request.url;
    if (request.method == 'PATCH' &&
        url.path == '$_chatBase/sessions/fixture-session/profile' &&
        request.headers['Authorization'] == 'Bearer fixture-chat' &&
        url.queryParameters.isEmpty) {
      final body = jsonDecode(request.body);
      if (body is Map &&
          body.isNotEmpty &&
          body.keys.every(
              (key) => key == 'name' || key == 'phone' || key == 'email') &&
          body.values.every((value) => value is String)) {
        return _json({'success': true});
      }
    }
    if (request.method == 'GET' &&
        url.path == '$_chatBase/config' &&
        url.queryParameters.isEmpty) {
      return _json({
        'widget': {
          'name': 'Поддержка',
          'welcomeMessage': 'Напишите вопрос по заказу или оплате'
        }
      });
    }
    if (url.path == '$_chatBase/sessions/fixture-session/messages' &&
        request.headers['Authorization'] == 'Bearer fixture-chat') {
      if (request.method == 'GET' &&
          url.queryParameters['limit'] == '100' &&
          url.queryParameters.keys
              .every((key) => key == 'limit' || key == 'afterId')) {
        final after = int.tryParse(url.queryParameters['afterId'] ?? '') ?? 0;
        return _json({
          'messages': [
            for (final message in _chatMessages)
              if ((message['id'] as int) > after) message,
          ]
        });
      }
      if (request.method == 'POST' && url.queryParameters.isEmpty) {
        final body = jsonDecode(request.body);
        if (body is Map && body.length == 1 && body['content'] is String) {
          final message = <String, dynamic>{
            'id': _chatMessages.length + 1,
            'content': body['content'],
            'fromMe': false,
            'timestamp': '2026-10-01T12:01:00Z',
            'status': 'sent',
          };
          _chatMessages.add(message);
          return http.Response(jsonEncode({'message': message}), 201,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
      }
    }
    return _reject(request, onUnexpectedRequest);
  }

  static http.Response _json(Object data) => http.Response(
        jsonEncode(data),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  static Future<http.Response> _reject(
      http.Request request, void Function(String)? onUnexpectedRequest) {
    final message =
        'Unrecognized fixture HTTP request: ${request.method} ${request.url}';
    unexpectedRequests.add(message);
    onUnexpectedRequest?.call(message);
    throw StateError(message);
  }
}

/// A mounted, interactive fixture, not the live authenticated app or a production route.
/// The parent controls viewport and text scale; the dev shell is excluded from captures.
class DesignSurfaceApp extends StatefulWidget {
  const DesignSurfaceApp({
    required this.surface,
    required this.brightness,
    this.onSurfaceChanged,
    this.size = designSurfaceSize,
    this.textScaler = TextScaler.noScaling,
    this.viewInsets = EdgeInsets.zero,
    this.cardScenario = CardFixtureScenario.loaded,
    super.key,
  });

  final String surface;
  final Brightness brightness;
  final ValueChanged<String>? onSurfaceChanged;
  final Size size;
  final TextScaler textScaler;
  final EdgeInsets viewInsets;
  final CardFixtureScenario cardScenario;

  @override
  State<DesignSurfaceApp> createState() => _DesignSurfaceAppState();
}

class _DesignSurfaceAppState extends State<DesignSurfaceApp> {
  late final CartProvider _cart = _cartFor(widget.surface);
  final ThemeController _theme = ThemeController();
  final BusinessProvider _business = BusinessProvider();
  late final Future<void> _businessReady = _business.loadSavedBusiness();
  var _navigatorKey = GlobalKey<NavigatorState>();
  late String _surface = widget.surface;
  ChatApiService? _chatService;
  late ProfileAccount? _profileAccount =
      widget.surface == 'profile_guest' ? null : _fixtureAccount;
  final _tiles = FixtureTileProvider();
  bool _quoteFailureConfigured = false;

  @override
  void initState() {
    super.initState();
    SurfaceFixtureClient.configureCards(widget.surface == 'payment_kaspi'
        ? CardFixtureScenario.empty
        : widget.cardScenario);
    SurfaceFixtureClient.useCartForOrders(_cart);
  }

  Future<AddressLocateResult> _locateFixtureAddress() async =>
      const AddressLocateResult.unavailable(
        message:
            'Фикстура: доступ к геолокации отклонён. Выберите адрес вручную.',
      );

  Future<ProfileAccount?> _loadFixtureAccount() async {
    if (_profileAccount == null) return null;
    final info = await ApiService.getFullInfo();
    if (info == null) throw StateError('Fixture account read failed');
    return _profileAccount = ProfileAccount.fromJson(info);
  }

  Future<bool> _openFixtureCardForm(BuildContext context, Uri uri) async {
    if (uri != Uri.parse('https://fixture-bank.example/card/attach')) {
      throw StateError('Unexpected fixture bank URI: $uri');
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Фикстура банка · без реальной карты'),
        content: const Text(
          'Только синтетические данные. Подтверждение добавит новую карту '
          'в ответ фикстуры; приложение проверит её после обновления списка.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отменить в банке'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Подтвердить в фикстуре'),
          ),
        ],
      ),
    );
    if (confirmed == true) SurfaceFixtureClient.confirmFixtureCardBinding();
    return true; // The fixture provider opened; this is not binding proof.
  }

  MapAddressPage _fixtureMapPage() => MapAddressPage(
        initialLat: 49.8047,
        initialLon: 73.1094,
        initialAddress: _fixtureAddress,
        tileProvider: _tiles,
        locate: _locateFixtureAddress,
      );

  @override
  void didUpdateWidget(DesignSurfaceApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cardScenario != oldWidget.cardScenario) {
      SurfaceFixtureClient.configureCards(widget.surface == 'payment_kaspi'
          ? CardFixtureScenario.empty
          : widget.cardScenario);
      _navigatorKey = GlobalKey<NavigatorState>();
    }
    if (widget.surface != oldWidget.surface && _surface != widget.surface) {
      if (_surface == 'payment_kaspi' || widget.surface == 'payment_kaspi') {
        SurfaceFixtureClient.configureCards(widget.surface == 'payment_kaspi'
            ? CardFixtureScenario.empty
            : widget.cardScenario);
      }
      _surface = widget.surface;
      _navigatorKey = GlobalKey<NavigatorState>();
      if (_surface != 'support') _chatService = null;
      _quoteFailureConfigured = false;
      if ((_surface == 'cart' || _surface.startsWith('checkout_')) &&
          !_cart.hasActiveItems) {
        _seedCart(_cart);
      }
      if (widget.surface == 'profile_guest') _profileAccount = null;
      if (widget.surface == 'profile') _profileAccount = _fixtureAccount;
    }
    if (widget.brightness != oldWidget.brightness) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _theme.setMode(widget.brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light);
        }
      });
    }
  }

  @override
  void dispose() {
    SurfaceFixtureClient.useCartForOrders(null);
    _cart.dispose();
    _business.dispose();
    _theme.dispose();
    super.dispose();
  }

  void _select(String surface, {bool notifyParent = true}) {
    if (_surface == 'payment_kaspi' || surface == 'payment_kaspi') {
      SurfaceFixtureClient.configureCards(surface == 'payment_kaspi'
          ? CardFixtureScenario.empty
          : widget.cardScenario);
    }
    setState(() {
      _surface = surface;
      _navigatorKey = GlobalKey<NavigatorState>();
      _quoteFailureConfigured = false;
      if ((surface == 'cart' || surface.startsWith('checkout_')) &&
          !_cart.hasActiveItems) {
        _seedCart(_cart);
      }
    });
    if (surface != 'support') _chatService = null;
    if (surface == 'profile_guest') _profileAccount = null;
    if (surface == 'profile') _profileAccount = _fixtureAccount;
    if (notifyParent) widget.onSurfaceChanged?.call(surface);
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider<CartProvider>.value(value: _cart),
          ChangeNotifierProvider<ThemeController>.value(value: _theme),
          ChangeNotifierProvider(create: (_) => LikedItemsProvider()),
          ChangeNotifierProvider<BusinessProvider>.value(value: _business),
        ],
        child: Consumer<ThemeController>(
          builder: (context, theme, _) => MaterialApp(
            navigatorKey: _navigatorKey,
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: const [Locale('ru'), Locale('en')],
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: theme.mode == ThemeMode.system
                ? (widget.brightness == Brightness.dark
                    ? ThemeMode.dark
                    : ThemeMode.light)
                : theme.mode,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: widget.size,
                padding: designSurfaceInsets.copyWith(
                    bottom: widget.viewInsets.bottom > 0
                        ? 0
                        : designSurfaceInsets.bottom),
                viewPadding: designSurfaceInsets,
                viewInsets: widget.viewInsets,
                textScaler: widget.textScaler,
              ),
              child: child!,
            ),
            home: FutureBuilder<void>(
              future: _businessReady,
              builder: (context, snapshot) =>
                  snapshot.connectionState == ConnectionState.done
                      ? _page(context)
                      : const Scaffold(
                          body: Center(child: CircularProgressIndicator())),
            ),
          ),
        ),
      );

  Widget _withFixtureBack(Widget page) => PopScope(
        key: ValueKey(_surface),
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _select('home');
        },
        child: page,
      );

  Future<void> _openProfileDestination(
      BuildContext context, AppDestination destination) async {
    if (_profileAccount == null &&
        const {
          AppDestination.orders,
          AppDestination.certificates,
          AppDestination.addresses,
          AppDestination.cards,
        }.contains(destination)) {
      _select('sign_in');
      return;
    }
    final Widget page;
    switch (destination) {
      case AppDestination.orders:
        page = OrdersPage(
          businessId: 1,
          onCart: () => _showFixtureCart(context),
          onOpenOrder: (order) => Navigator.of(context).push<void>(
            MaterialPageRoute(
                builder: (_) => _fixtureOrderPage(context, order)),
          ),
        );
      case AppDestination.certificates:
        page = CertificatesPage(
          openCardForm: (uri) => _openFixtureCardForm(context, uri),
          onCart: () => _showFixtureCart(context),
        );
      case AppDestination.support:
        await _openFixtureSupport(context);
        return;
      case AppDestination.faq:
        page = const FaqPage();
      case AppDestination.addresses:
        page = ProfileAddressesPage(
          tileProvider: _tiles,
          locate: _locateFixtureAddress,
        );
      case AppDestination.cards:
        page = ProfileCardsPage(
          openCardForm: (uri) => _openFixtureCardForm(context, uri),
        );
      case AppDestination.favorites:
        page = FavoritesPage(
            businessId: 1, onCart: () => _showFixtureCart(context));
      case AppDestination.notifications:
        page = const NotificationSettingsPage();
      case AppDestination.bonuses:
        page = BonusHistoryPage(
          onHowItWorks: () => _select('bonus_explainer'),
          onCart: () => _showFixtureCart(context),
        );
      case AppDestination.profile:
        _select('profile');
        return;
      case AppDestination.home:
        _select('home');
        return;
    }
    if (context.mounted) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => page),
      );
    }
  }

  void _showFixtureCart(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    _quoteFailureConfigured = false;
    _select('cart');
  }

  CheckoutPage _fixtureCheckout(BuildContext context) {
    if (_surface == 'checkout_error' && !_quoteFailureConfigured) {
      RemainingMilestoneFixture.quoteFailures = 1;
      RemainingMilestoneFixture.createRefusals = 1;
      _quoteFailureConfigured = true;
    }
    return CheckoutPage(
      initialDeliveryType:
          _surface == 'checkout_pickup' ? 'PICKUP' : 'DELIVERY',
      initialAddress: _fixtureAddress,
      onCatalog: () => _select('catalog'),
      addressPicker: (context, address, detailsFirst) =>
          AddressSelectionModalHelper.show(
        context,
        initialAddress: address,
        openDetailsFirst: detailsFirst,
        tileProvider: _tiles,
        locate: _locateFixtureAddress,
      ),
      openCardForm: (uri) => _openFixtureCardForm(context, uri),
    );
  }

  Widget _fixtureOrderPage(BuildContext context, Map<String, dynamic> order) =>
      OrderDetailPage(
        order: order,
        onSupport: (resolved) => _openFixtureSupport(context, order: resolved),
      );

  Future<void> _openFixtureSupport(BuildContext context,
      {Map<String, dynamic>? order}) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => HelpChatPage(
        order: order,
        entryPoint: order == null ? 'profile' : 'order_detail',
        chatService: ChatApiService(
          client: SurfaceFixtureClient(),
          enableSocket: false,
        ),
      ),
    ));
  }

  Widget _page(BuildContext context) {
    switch (_surface) {
      case 'home':
        return HomePage(
          data: _homeData,
          cartItemCount: _cart.displayItemCount,
          cartTotal: _cart.displayItemCount == 0
              ? null
              : _cart.getTotalPrice().round(),
          onProfile: () => _select('profile_guest'),
          onCallCenter: () => _openFixtureSupport(context),
          onLiked: () => _select('favorites'),
          onNotifications: () => _select('notifications'),
          onPromo: (_) => _select('promotion'),
          onBonusHistory: () => _select('bonus_history'),
          onCart: () => _select('cart'),
          onCategory: (_) => _select('catalog'),
          onSearch: () => _select('search'),
          onStore: () async {
            final selected = await showModalBottomSheet<HomeStore>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const HomeStoreSheet(
                stores: [
                  HomeStore(
                      id: 1, name: 'Тестовый магазин', address: _sampleAddress),
                  HomeStore(
                      id: 2,
                      name: 'Второй тестовый магазин',
                      address: 'Другой тестовый адрес, 20'),
                ],
                selectedId: 1,
              ),
            );
            if (selected != null) {
              await _business.setSelectedBusiness({
                'id': selected.id,
                'name': selected.name,
                'address': selected.address,
              });
            }
          },
          onSignIn: () => _select('sign_in'),
        );
      case 'catalog':
        return _withFixtureBack(SupercategoryPage(
          supercategoryId: 1,
          businessId: _business.selectedBusinessId ?? 1,
          title: 'Слабоалкогольные напитки',
          onSearch: () => _select('search'),
          onCart: () => _select('cart'),
        ));
      case 'all_products':
        return _withFixtureBack(CategoryProductsPage(
          categoryId: 11,
          title: 'Белое',
          businessId: _business.selectedBusinessId ?? 1,
          initialItems: _products,
          onSearch: () => _select('search'),
          onCart: () => _select('cart'),
        ));
      case 'cart':
        return _withFixtureBack(CartPage(
          businessId: _business.selectedBusinessId ?? 1,
          address: _sampleAddress,
          onCatalog: () => _select('catalog'),
          onCheckout: () => Navigator.of(context).push<void>(MaterialPageRoute(
            builder: (_) => _fixtureCheckout(context),
          )),
        ));
      case 'profile':
        return _withFixtureBack(ProfilePage(
          account: _profileAccount,
          loadAccount: _loadFixtureAccount,
          onLogout: () async => _select('home'),
          onNavigate: (destination) =>
              _openProfileDestination(context, destination),
        ));
      case 'profile_guest':
        return _withFixtureBack(ProfilePage(
          loadAccount: _loadFixtureAccount,
          onSignIn: () async => _select('sign_in'),
          onLogout: () async {
            _profileAccount = null;
            _select('home');
          },
          onNavigate: (destination) =>
              _openProfileDestination(context, destination),
        ));
      case 'promotion':
        return _withFixtureBack(PromotionItemsPage(
          promotionId: 7,
          promotionName: 'Предложения недели',
          businessId: 1,
          initialItems: [for (var id = 100; id < 109; id++) _sampleItem(id)],
          onCart: () => _select('cart'),
        ));
      case 'orders':
        return _withFixtureBack(OrdersPage(
          businessId: 1,
          onCart: () => _select('cart'),
          onOpenOrder: (order) => Navigator.of(context).push<void>(
            MaterialPageRoute(
                builder: (_) => _fixtureOrderPage(context, order)),
          ),
        ));
      case 'order_detail':
        return _withFixtureBack(_fixtureOrderPage(context, _fixtureOrder));
      case 'support':
        return _withFixtureBack(HelpChatPage(
          entryPoint: 'profile',
          chatService: _chatService ??= ChatApiService(
            client: SurfaceFixtureClient(),
            enableSocket: false,
          ),
        ));
      case 'certificates':
        return _withFixtureBack(CertificatesPage(
          openCardForm: (uri) => _openFixtureCardForm(context, uri),
          onCart: () => _select('cart'),
        ));
      case 'onboarding':
        return OnboardingPage(
          initialCity: 'Караганда',
          onCompleted: () => _select('home'),
          actions: OnboardingActions(
            locationSupported: true,
            notificationsSupported: true,
            requestLocationPermission: () async => LocationPermissionResult(
              success: false,
              message: 'Фикстура: доступ к геолокации отклонён.',
              permissionStatus: LocationPermission.denied,
            ),
            locate: () async => null,
            enableNotifications: () async => false,
            openLocationSettings: () async => false,
          ),
        );
      case 'addresses':
        return _withFixtureBack(ProfileAddressesPage(
          tileProvider: _tiles,
          locate: _locateFixtureAddress,
        ));
      case 'address_map':
        return _withFixtureBack(_fixtureMapPage());
      case 'address_details':
        return _withFixtureBack(const AddressDetailsPage(
          address: 'Тестовый адрес, 16',
          initialEntrance: '2',
          initialFloor: '7',
          initialApartment: '45',
        ));
      case 'cards':
        return _withFixtureBack(ProfileCardsPage(
          openCardForm: (uri) => _openFixtureCardForm(context, uri),
        ));
      case 'payment_method':
      case 'payment_kaspi':
        return _withFixtureBack(PaymentMethodPage(
          orderData: const {
            'order_id': 'fixture-order',
            'payable_amount': 1200
          },
          openCardForm: (uri) => _openFixtureCardForm(context, uri),
        ));
      case 'checkout_delivery':
      case 'checkout_pickup':
      case 'checkout_error':
        return _withFixtureBack(_fixtureCheckout(context));
      case 'certificate_purchase':
        return _withFixtureBack(_CertificatePurchasePreview(
          openCardForm: (uri) => _openFixtureCardForm(context, uri),
          onIssued: () => _select('certificates'),
        ));
      case 'product_options':
      case 'product_pour':
        return _withFixtureBack(ProductDetailPage(
          item: _surface == 'product_pour'
              ? fixturePourItem()
              : fixtureOptionItem(),
          businessId: 1,
          onCart: () => _showFixtureCart(context),
        ));
      case 'product_pour_real':
      case 'product_pour_gift':
      case 'product_pour_three_plus_one':
      case 'product_pour_fractional':
      case 'product_replacement':
        return _withFixtureBack(ProductDetailPage(
          item: _surface == 'product_pour_real'
              ? capturedPourSurfaceItem()
              : _surface == 'product_pour_three_plus_one'
                  ? syntheticThreePlusOneSurfaceItem()
                  : _surface == 'product_pour_gift'
                      ? capturedPourSurfaceItem(gift: true)
                      : fractionalPourSurfaceItem(
                          replacement: _surface == 'product_replacement'),
          businessId: 1,
          onCart: () => _showFixtureCart(context),
        ));
      case 'search':
        return _withFixtureBack(SearchPage(
            businessId: _business.selectedBusinessId ?? 1,
            onCart: () => _select('cart')));
      case 'favorites':
        return _withFixtureBack(FavoritesPage(
            businessId: _business.selectedBusinessId ?? 1,
            onCart: () => _select('cart')));
      case 'bonus_history':
        return _withFixtureBack(BonusHistoryPage(
          onHowItWorks: () => _select('bonus_explainer'),
          onCart: () => _select('cart'),
        ));
      case 'bonus_explainer':
        return _withFixtureBack(
            BonusHowItWorksPage(onOpenFaq: () => _select('faq')));
      case 'faq':
        return _withFixtureBack(const FaqPage());
      case 'notifications':
        return _withFixtureBack(const NotificationSettingsPage());
      case 'intro':
        return IntroSlidesPage(onContinue: () async => _select('sign_in'));
      case 'sign_in':
        return _withFixtureBack(const LoginPage(startWithPhoneForm: true));
      case 'profile_setup':
        return ProfileSetupPage(
          initialUser: const {'name': '', 'date_of_birth': null, 'sex': 0},
          onCompleted: (_) async => _select('profile'),
        );
      case 'startup':
        return const AppLoadingScreen(message: 'Подготавливаем приложение');
      case 'active_route':
        return const AuthenticationWrapper();
      case 'payment_success':
        return _withFixtureBack(const PaymentSuccessPage(
          orderId: '45',
          businessId: 1,
        ));
      default:
        throw StateError('Unknown design surface $_surface');
    }
  }
}

class _CertificatePurchasePreview extends StatefulWidget {
  const _CertificatePurchasePreview({
    required this.openCardForm,
    required this.onIssued,
  });

  final Future<bool> Function(Uri) openCardForm;
  final VoidCallback onIssued;

  @override
  State<_CertificatePurchasePreview> createState() =>
      _CertificatePurchasePreviewState();
}

class _CertificatePurchasePreviewState
    extends State<_CertificatePurchasePreview> {
  final _session = CertificatePurchaseSession();
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _open();
    });
  }

  Future<void> _open() async {
    if (_opening) return;
    _opening = true;
    try {
      final issued = await showCertificatePurchase(
        context,
        session: _session,
        openCardForm: widget.openCardForm,
      );
      if (mounted && issued != null) widget.onIssued();
    } finally {
      _opening = false;
    }
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CertificatesPage(
        onBuy: _open,
        openCardForm: widget.openCardForm,
      );
}
