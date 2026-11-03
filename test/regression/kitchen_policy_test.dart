import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/core/kitchen_policy.dart';
import 'package:naliv_delivery/features/catalog/catalog_data_source.dart';
import 'package:naliv_delivery/features/home/home_data_source.dart';
import 'package:naliv_delivery/model/cart_item.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/services/repeat_order_service.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/preferences_store.dart';

const _kitchenStore = 11;
const _otherStore = 5;

Item _item(int id, {required int categoryId, String? name, int? parentId}) =>
    Item(
      itemId: id,
      name: name ?? 'Товар $id',
      price: 1000,
      image: '',
      amount: 10,
      unit: 'шт.',
      category: ItemCategory(
        categoryId: categoryId,
        name: categoryId == 237 ? 'Еда (Кухня)' : 'Пиво',
        parentId: parentId,
      ),
    );

final _kitchenItem = _item(900, categoryId: 237, name: 'Плов');
final _beerItem = _item(901, categoryId: 58, name: 'Пиво');

CartItem _row(Item item, {double quantity = 1}) => CartItem(
      itemId: item.itemId,
      name: item.name,
      price: item.price,
      quantity: quantity,
      stepQuantity: 1,
      image: '',
      selectedVariants: const [],
      promotions: const [],
      itemData: item.toJson(),
    );

Map<String, dynamic> _rawItem(Item item) => {
      'item_id': item.itemId,
      'name': item.name,
      'price': 1000,
      'amount': 10,
      'measure': 'шт.',
      'category': {
        'category_id': item.category!.categoryId,
        'name': item.category!.name,
        'parent_category': item.category!.parentId ?? 0,
      },
    };

final _supercategories = [
  {
    'supercategory_id': 7,
    'name': 'Кухня',
    'priority': 100,
    'categories': [
      {
        'category_id': 237,
        'name': 'Еда (Кухня)',
        'parent_category': 0,
        'subcategories': [
          {'category_id': 238, 'name': 'Супы', 'parent_category': 237},
        ],
      },
    ],
  },
  {
    'supercategory_id': 4,
    'name': 'Слабоалкогольные напитки',
    'priority': 10,
    'categories': [
      {
        'category_id': 37,
        'name': 'Вино',
        'parent_category': 0,
        'subcategories': [
          {'category_id': 58, 'name': 'Игристое', 'parent_category': 37},
        ],
      },
    ],
  },
  {
    'supercategory_id': 5,
    'name': 'Еда и закуски',
    'priority': 9,
    'categories': [
      {'category_id': 49, 'name': 'Закуски', 'parent_category': 0},
    ],
  },
];

MockClient _client(List<Uri> requests) => MockClient((request) async {
      requests.add(request.url);
      if (request.method != 'GET') {
        throw StateError('Unexpected mutation ${request.method}');
      }
      final path = request.url.path;
      Map<String, dynamic> data;
      if (path.endsWith('/businesses')) {
        data = {
          'businesses': [
            for (final id in [_otherStore, _kitchenStore])
              {'id': id, 'name': 'Магазин $id', 'address': 'Адрес $id'},
          ],
        };
      } else if (path.endsWith('/users/cities')) {
        data = {'cities': <Object>[]};
      } else if (path.endsWith('/categories/supercategories')) {
        data = {'supercategories': _supercategories};
      } else if (path.endsWith('/promotions/active')) {
        data = {'promotions': <Object>[]};
      } else if (path.endsWith('/items/search') ||
          (path.contains('/categories/') && path.endsWith('/items'))) {
        data = {
          'items': [_rawItem(_beerItem), _rawItem(_kitchenItem)],
        };
      } else {
        return http.Response('{}', 404);
      }
      return http.Response(jsonEncode({'success': true, 'data': data}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    KitchenPolicy.resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    KitchenPolicy.resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  group('KitchenPolicy', () {
    test('kitchen is available only at store 11', () {
      expect(KitchenPolicy.isAvailableForBusiness(11), isTrue);
      for (final other in [null, 0, 1, 3, 5, 7, 9]) {
        expect(KitchenPolicy.isAvailableForBusiness(other), isFalse);
      }
    });

    test('recognises the supercategory by id or name', () {
      expect(KitchenPolicy.isKitchenSupercategory(id: 7), isTrue);
      expect(KitchenPolicy.isKitchenSupercategory(name: ' кухня '), isTrue);
      expect(
          KitchenPolicy.isKitchenSupercategory(id: 4, name: 'Вино'), isFalse);
    });

    test('registry is seeded and learns the kitchen tree only', () {
      expect(KitchenPolicy.isKitchenCategoryId(237), isTrue);
      expect(KitchenPolicy.isKitchenCategoryId(238), isFalse);
      KitchenPolicy.registerSupercategories(
          _supercategories.cast<Map<String, dynamic>>());
      expect(KitchenPolicy.isKitchenCategoryId(238), isTrue);
      expect(KitchenPolicy.isKitchenCategoryId(58), isFalse);
      expect(KitchenPolicy.isKitchenCategoryId(37), isFalse);
    });

    test('classifies items by category, parent category and order lines', () {
      expect(KitchenPolicy.isKitchenItem(_kitchenItem), isTrue);
      expect(KitchenPolicy.isKitchenItem(_beerItem), isFalse);
      expect(
          KitchenPolicy.isKitchenItem(_item(1, categoryId: 999, parentId: 237)),
          isTrue);
      expect(KitchenPolicy.allowsItem(_kitchenItem, 11), isTrue);
      expect(KitchenPolicy.allowsItem(_kitchenItem, 5), isFalse);
      expect(KitchenPolicy.allowsItem(_beerItem, 5), isTrue);
      expect(
          KitchenPolicy.isKitchenOrderLine({
            'category': {'name': 'Еда (Кухня)'}
          }),
          isTrue);
      expect(
          KitchenPolicy.isKitchenOrderLine({
            'category': {'category_id': 58, 'name': 'Пиво'}
          }),
          isFalse);
    });

    test('filterSupercategories drops the kitchen unless the store sells it',
        () {
      final raw = _supercategories.cast<Map<String, dynamic>>();
      expect(KitchenPolicy.filterSupercategories(raw, 5).map((e) => e['name']),
          ['Слабоалкогольные напитки', 'Еда и закуски']);
      expect(KitchenPolicy.filterSupercategories(raw, null), hasLength(2));
      expect(KitchenPolicy.filterSupercategories(raw, 11), hasLength(3));
    });
  });

  group('cart ingress', () {
    test('a cart bound to another store refuses kitchen items', () async {
      final cart = CartProvider();
      addTearDown(cart.dispose);
      expect(await cart.bindBusiness(_otherStore), isTrue);

      cart.incrementCatalogItem(_kitchenItem);
      expect(cart.hasActiveItems, isFalse);
      expect(cart.addItem(_row(_kitchenItem)), isFalse);
      expect(cart.syncItemSelectionQuantity(_kitchenItem, [], 1), isFalse);
      expect(cart.addDisplayGroupItems([_row(_kitchenItem)]), isFalse);
      expect(cart.hasActiveItems, isFalse);

      cart.incrementCatalogItem(_beerItem);
      expect(cart.hasActiveItems, isTrue);
      expect(cart.items.map((row) => row.itemId), [_beerItem.itemId]);
    });

    test('the kitchen store keeps accepting kitchen items', () async {
      final cart = CartProvider();
      addTearDown(cart.dispose);
      expect(await cart.bindBusiness(_kitchenStore), isTrue);
      cart.incrementCatalogItem(_kitchenItem);
      expect(cart.items.map((row) => row.itemId), [_kitchenItem.itemId]);
    });

    test('replaceForBusiness refuses kitchen rows outside store 11', () async {
      final cart = CartProvider();
      addTearDown(cart.dispose);
      expect(
          await cart.replaceForBusiness(
              _otherStore, [_row(_beerItem), _row(_kitchenItem)]),
          isFalse);
      expect(cart.items, isEmpty);
      expect(
          await cart.replaceForBusiness(
              _kitchenStore, [_row(_beerItem), _row(_kitchenItem)]),
          isTrue);
      expect(cart.items, hasLength(2));
    });

    test('a persisted cart of another store drops kitchen rows on restore',
        () async {
      OnboardingPreferences({
        'cart_items': jsonEncode({
          'business_id': _otherStore,
          'items': [_row(_kitchenItem).toJson(), _row(_beerItem).toJson()],
        }),
      }).install();
      final cart = CartProvider();
      addTearDown(cart.dispose);
      await cart.ensureLoaded();
      expect(cart.items.map((row) => row.itemId), [_beerItem.itemId]);
      expect(await cart.ensureSaved(), isTrue);
      final stored =
          (await SharedPreferences.getInstance()).getString('cart_items')!;
      expect(stored, isNot(contains('Плов')));
    });

    test('a persisted kitchen-store cart keeps its kitchen rows', () async {
      OnboardingPreferences({
        'cart_items': jsonEncode({
          'business_id': _kitchenStore,
          'items': [_row(_kitchenItem).toJson(), _row(_beerItem).toJson()],
        }),
      }).install();
      final cart = CartProvider();
      addTearDown(cart.dispose);
      await cart.ensureLoaded();
      expect(cart.items, hasLength(2));
    });
  });

  group('repeat order', () {
    Map<String, dynamic> order(int businessId) => {
          'business': {'id': businessId, 'name': 'Магазин'},
          'items': [
            {
              'item_id': _kitchenItem.itemId,
              'name': 'Плов',
              'price': 1000,
              'amount': 1,
              'category': {'category_id': 237, 'name': 'Еда (Кухня)'},
            },
            {
              'item_id': _beerItem.itemId,
              'name': 'Пиво',
              'price': 1000,
              'amount': 1,
              'category': {'category_id': 58, 'name': 'Игристое'},
            },
          ],
        };

    test('skips kitchen lines for another store and reports them', () {
      final result =
          RepeatOrderService.buildCartItemsFromOrder(order(_otherStore));
      expect(result.items.map((row) => row.itemId), [_beerItem.itemId]);
      expect(result.skippedItems, ['Плов']);
    });

    test('keeps kitchen lines for store 11', () {
      final result =
          RepeatOrderService.buildCartItemsFromOrder(order(_kitchenStore));
      expect(result.items, hasLength(2));
      expect(result.skippedItems, isEmpty);
    });
  });

  group('catalogue and home', () {
    test('home has no kitchen card or tile outside store 11', () async {
      final requests = <Uri>[];
      final data = await http.runWithClient(
        () => const HomeDataSource(businessId: _otherStore).load(),
        () => _client(requests),
      );
      expect(data.storeId, _otherStore);
      expect(data.promoCard, isNull);
      expect(data.categories.map((c) => c.title),
          ['Слабоалкогольные напитки', 'Еда и закуски']);
      expect(requests.where((uri) => uri.path.contains('/categories/237/')),
          isEmpty);
      for (final section in data.productSections) {
        expect(section.products.map((p) => p.itemId), [_beerItem.itemId]);
      }
    });

    test('home keeps the kitchen promo card at store 11', () async {
      final data = await http.runWithClient(
        () => const HomeDataSource(businessId: _kitchenStore).load(),
        () => _client(<Uri>[]),
      );
      expect(data.promoCard?.title, 'Кухня');
      expect(data.categories.map((c) => c.title),
          ['Слабоалкогольные напитки', 'Еда и закуски']);
    });

    test('catalogue hides kitchen supercategory, category and items', () async {
      final requests = <Uri>[];
      await http.runWithClient(() async {
        const other = CatalogDataSource(businessId: _otherStore);
        expect((await other.supercategories()).map((s) => s.id), [4, 5]);
        expect(await other.supercategory(7), isNull);
        requests.clear();
        final kitchenPage = await other.itemsPage(237);
        expect(kitchenPage.items, isEmpty);
        expect(requests, isEmpty, reason: 'kitchen category is never fetched');
        expect((await other.itemsPage(58)).items.map((p) => p.itemId), [901]);
        expect((await other.search('пл')).items.map((p) => p.itemId), [901]);

        const kitchen = CatalogDataSource(businessId: _kitchenStore);
        expect((await kitchen.supercategories()).map((s) => s.id), [7, 4, 5]);
        expect((await kitchen.supercategory(7))?.id, 7);
        expect((await kitchen.itemsPage(58)).items.map((p) => p.itemId),
            [901, 900]);
        expect((await kitchen.search('пл')).items.map((p) => p.itemId),
            [901, 900]);
      }, () => _client(requests));
    });
  });
}
