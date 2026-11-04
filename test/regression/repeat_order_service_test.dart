import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/services/repeat_order_service.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/smart_cart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/bottling_surface_items.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  group('RepeatOrderService', () {
    test('buildCartItemsFromOrder restores valid lines and skips broken ones',
        () {
      final result =
          RepeatOrderService.buildCartItemsFromOrder(<String, dynamic>{
        'business': <String, dynamic>{
          'id': 7,
          'name': 'Test shop',
        },
        'items': <dynamic>[
          <String, dynamic>{
            'item_id': 501,
            'name': 'Draft beer',
            'price': 1500,
            'amount': 2,
            'image': 'https://example.com/beer.png',
            'options': <dynamic>[
              <String, dynamic>{
                'option_item_relation_id': 91,
                'item_id': 901,
                'item_name': '1 л бутылка',
                'price': 60,
                'parent_item_amount': 1,
                'required': 1,
              },
            ],
          },
          <String, dynamic>{
            'name': 'Broken row',
            'amount': 1,
          },
        ],
      });

      expect(result.items, hasLength(1));
      expect(result.skippedItems, <String>['Broken row']);

      final restored = result.items.single;
      expect(restored.itemId, 501);
      expect(restored.quantity, 2);
      expect(restored.price, 1500);
      expect(restored.stepQuantity, 1);
      expect(restored.selectedVariants, hasLength(1));
      expect(restored.selectedVariants.single['relation_id'], 91);
      expect(restored.itemData?['business_id'], 7);
      expect(restored.toJsonForOrder()['options'], <Map<String, dynamic>>[
        <String, dynamic>{
          'option_item_relation_id': 91,
          'amount': 1,
        },
      ]);
    });

    test('repeat maps the fulfilled four-litre bottle group directly', () {
      final item = syntheticThreePlusOneSurfaceItem(onlyOneLitre: true);
      final source = CartProvider();
      expect(source.syncItemBottleCounts(item, [], {93101: 4}), isTrue);
      final result = RepeatOrderService.buildCartItemsFromOrder({
        'business_id': 7,
        'items': [
          for (final row in source.toJsonForOrder())
            {
              ...row,
              'name': item.name,
              'price': 850,
              'item_data': item.toJson()
            },
        ],
      });
      expect(result.skippedItems, isEmpty);
      final group = CartDisplayGroup.groupItems(result.items).single;
      expect(group.totalQuantity, 4);
      expect(group.freeQuantity, 1);
      expect(group.bottleCounts, {93101: 4});
      expect(
          group.totalPrice, 3400); // Catalog drink tariff, not invoice average.
      final repeated = CartProvider();
      expect(repeated.addDisplayGroupItems(result.items), isTrue);
      expect(repeated.toJsonForOrder(), source.toJsonForOrder());
      expect(repeated.getTotalPrice(), 3400);
    });

    test('repeat preserves mixed container capacities of the picked litres',
        () {
      final item = syntheticThreePlusOneSurfaceItem();
      final source = CartProvider();
      expect(
          source.syncItemBottleCounts(item, [], {93101: 1, 93103: 2}), isTrue);
      final result = RepeatOrderService.buildCartItemsFromOrder({
        'business_id': 7,
        'items': [
          for (final row in source.toJsonForOrder())
            {...row, 'name': item.name, 'item_data': item.toJson()},
        ],
      });
      expect(result.skippedItems, isEmpty);
      final repeated = CartProvider();
      expect(repeated.addDisplayGroupItems(result.items), isTrue);
      expect(repeated.activeDisplayGroups.single.totalQuantity, 4);
      expect(repeated.activeDisplayGroups.single.freeQuantity, 1);
      expect(repeated.activeDisplayGroups.single.bottleCounts,
          {93101: 1, 93103: 2});
      expect(repeated.getTotalPrice(), 3340);
      expect(repeated.toJsonForOrder(), source.toJsonForOrder());
    });

    test('repeat keeps the fulfilled bottles through edit and reload',
        () async {
      final item = capturedPourSurfaceItem(gift: true);
      final result = RepeatOrderService.buildCartItemsFromOrder({
        'business_id': 7,
        'items': [
          {
            'item_id': item.itemId,
            'name': item.name,
            'amount': 6,
            'item_data': item.toJson(),
            'options': [
              {'option_item_relation_id': 3094, 'amount': 1},
            ],
          },
        ],
      });
      expect(result.skippedItems, isEmpty);
      final cart = CartProvider();
      expect(cart.addDisplayGroupItems(result.items), isTrue);
      expect(cart.activeDisplayGroups.single.totalQuantity, 6);
      expect(cart.activeDisplayGroups.single.freeQuantity, 2);
      expect(cart.activeDisplayGroups.single.bottleCounts, {3094: 6});
      expect(cart.getTotalPrice(), 4220);
      await SharedPreferences.getInstance();
      final restored = CartProvider();
      await restored.loadCart();
      final group = restored.activeDisplayGroups.single;
      expect(
          restored.syncItemBottleCounts(item, [], group.bottleCounts), isTrue);
      expect(restored.activeDisplayGroups.single.bottleCounts, {3094: 6});
      expect(restored.getTotalPrice(), 4220);
      expect(restored.toJsonForOrder().single['amount'], 6);
    });

    test('repeat maps any fulfilled pour litres but refuses withdrawn bottles',
        () {
      final item = capturedPourSurfaceItem(gift: true);
      for (final (amount, relation, restored) in [
        (2, 3094, true), // Two litres: no gift, nothing impossible.
        (6, 3097, false), // The withdrawn three-litre container.
      ]) {
        final result = RepeatOrderService.buildCartItemsFromOrder({
          'business_id': 7,
          'items': [
            {
              'item_id': item.itemId,
              'name': item.name,
              'amount': amount,
              'item_data': item.toJson(),
              'options': [
                {'option_item_relation_id': relation, 'amount': 1},
              ],
            },
          ],
        });
        if (restored) {
          expect(result.skippedItems, isEmpty);
          expect(result.items.single.quantity, amount);
        } else {
          expect(result.items, isEmpty);
          expect(result.skippedItems, [contains(item.name)]);
        }
      }
    });

    test('repeat restores every fulfilled packaged quantity exactly as it is',
        () {
      Map<String, dynamic> snapshot(
              int id, List<Map<String, dynamic>> promos) =>
          {
            'item_id': id,
            'name': 'Товар',
            'price': 1000,
            'unit': 'шт',
            'step_quantity': 1,
            'amount': 20,
            'promotions': promos,
          };
      final threePlusOne = [
        {'type': 'SUBTRACT', 'base_amount': 3, 'add_amount': 1},
      ];
      // Neither three (a 3+1 never makes three bottles a set) nor five (no whole set of
      // either promotion) is an impossible total any more: a cart holds what was received.
      for (final (amount, gift, price) in [
        (3, 0.0, 3000.0),
        (4, 1.0, 3000.0),
        (5, 1.0, 4000.0),
        (8, 2.0, 6000.0),
      ]) {
        final original = <String, dynamic>{
          'business_id': 7,
          'items': [
            {
              'item_id': 9401,
              'name': 'Товар',
              'amount': amount,
              'item_data': snapshot(9401, threePlusOne),
            },
          ],
        };
        final result = RepeatOrderService.buildCartItemsFromOrder(original);
        expect(result.skippedItems, isEmpty, reason: '$amount received');
        expect(result.items.single.quantity, amount);
        final cart = CartProvider();
        expect(cart.addDisplayGroupItems(result.items), isTrue);
        final group = cart.activeDisplayGroups.single;
        expect(group.totalQuantity, amount);
        expect(group.freeQuantity, gift, reason: '$amount received');
        expect(cart.getTotalPrice(), price, reason: '$amount received');
        expect(cart.toJsonForOrder().single['amount'], amount);
        expect((original['items'] as List).single['amount'], amount);
      }
    });

    test(
        'repeat keeps a pour invoice at the litres fulfilled, never adding a gift',
        () {
      final snapshot =
          syntheticThreePlusOneSurfaceItem(onlyOneLitre: true).toJson();
      snapshot['promotions'] = [
        {'type': 'SUBTRACT', 'base_amount': 2, 'add_amount': 1},
        {'type': 'SUBTRACT', 'base_amount': 3, 'add_amount': 1},
      ];
      final result = RepeatOrderService.buildCartItemsFromOrder({
        'business_id': 7,
        'items': [
          {
            'item_id': snapshot['item_id'],
            'name': snapshot['name'],
            'amount': 5,
            'item_data': snapshot,
            'options': [
              {'option_item_relation_id': 93101, 'amount': 1},
            ],
          },
        ],
      });
      expect(result.skippedItems, isEmpty);
      final cart = CartProvider();
      expect(cart.addDisplayGroupItems(result.items), isTrue);
      expect(cart.toJsonForOrder().single['amount'], 5.0);
      expect(cart.activeDisplayGroups.single.freeQuantity, 1);
    });

    test('repeat packaged promotions preserves exact fulfilled physical count',
        () {
      final snapshot = {
        'item_id': 9402,
        'name': 'Товар',
        'price': 1000,
        'unit': 'шт',
        'step_quantity': 1,
        'amount': 20,
        'promotions': [
          {'type': 'SUBTRACT', 'base_amount': 2, 'add_amount': 1},
          {'type': 'SUBTRACT', 'base_amount': 3, 'add_amount': 1},
        ],
      };
      final result = RepeatOrderService.buildCartItemsFromOrder({
        'business_id': 7,
        'items': [
          {
            'item_id': 9402,
            'name': 'Товар',
            'amount': 6,
            'item_data': snapshot,
          },
        ],
      });
      expect(result.skippedItems, isEmpty);
      final cart = CartProvider();
      expect(cart.addDisplayGroupItems(result.items), isTrue);
      final group = cart.activeDisplayGroups.single;
      expect(group.totalQuantity, 6);
      expect(group.evaluate().paidQuantity, 4);
      expect(group.freeQuantity, 2);
      expect(cart.toJsonForOrder().single['amount'], 6);
      expect(cart.getTotalPrice(), 4000);
    });

    test(
        'repeat refuses withdrawn three-litre relations without repricing rows',
        () {
      final item = capturedPourSurfaceItem();
      final result = RepeatOrderService.buildCartItemsFromOrder({
        'business_id': 7,
        'items': [
          {
            'item_id': item.itemId,
            'name': item.name,
            'amount': 3,
            'item_data': item.toJson(),
            'options': [
              {'option_item_relation_id': 2713, 'amount': 1},
            ],
          },
        ],
      });
      expect(result.items, isEmpty);
      expect(result.skippedItems, [contains(item.name)]);
    });
  });
}
