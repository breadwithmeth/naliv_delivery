import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/services/repeat_order_service.dart';
import 'package:naliv_delivery/model/item.dart';
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

    test('repeat reconstructs paid 3+1 from fulfilled four-litre bottle group',
        () {
      final item = syntheticThreePlusOneSurfaceItem(onlyOneLitre: true);
      final source = CartProvider();
      expect(source.syncItemBottleCounts(item, [], {93101: 3}), isTrue);
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
      expect(group.totalQuantity, 3);
      expect(group.freeQuantity, 1);
      expect(group.bottleCounts, {93101: 4});
      expect(
          group.totalPrice, 3400); // Catalog drink tariff, not invoice average.
      final repeated = CartProvider();
      expect(repeated.addDisplayGroupItems(result.items), isTrue);
      expect(repeated.toJsonForOrder(), source.toJsonForOrder());
      expect(repeated.getTotalPrice(), 3400);
    });

    test('repeat preserves mixed whole paid and gift container capacities', () {
      final item = syntheticThreePlusOneSurfaceItem();
      final source = CartProvider();
      expect(source.syncItemBottleCounts(item, [], {93103: 1}), isTrue);
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
      expect(repeated.activeDisplayGroups.single.totalQuantity, 3);
      expect(repeated.activeDisplayGroups.single.bottleCounts,
          {93101: 1, 93103: 1});
      expect(repeated.getTotalPrice(), 3250);
      expect(repeated.toJsonForOrder(), source.toJsonForOrder());
    });

    test(
        'repeat retains exact noncanonical gift bottles through edit and reload',
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
      expect(cart.activeDisplayGroups.single.totalQuantity, 4);
      expect(cart.activeDisplayGroups.single.bottleCounts, {3094: 6});
      expect(cart.getTotalPrice(), 4220);
      await SharedPreferences.getInstance();
      final restored = CartProvider();
      await restored.loadCart();
      final group = restored.activeDisplayGroups.single;
      expect(restored.syncItemBottleCounts(item, [], group.paidBottleCounts),
          isTrue);
      expect(restored.activeDisplayGroups.single.bottleCounts, {3094: 6});
      expect(restored.getTotalPrice(), 4220);
      expect(restored.toJsonForOrder().single['amount'], 6);
    });

    test('repeat refuses impossible paid inverse and whole gift subset', () {
      final item = capturedPourSurfaceItem(gift: true);
      for (final (amount, relation) in [(2, 3094), (6, 3097)]) {
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
        expect(result.items, isEmpty);
        expect(result.skippedItems, [contains(item.name)]);
      }
    });

    test('repeat leaves plain non-pour SUBTRACT behavior unchanged', () {
      final item =
          Item(itemId: 99, name: 'Вода', price: 100, unit: 'шт', promotions: [
        ItemPromotion(
            promotionId: 1,
            name: '3+1',
            discountType: 'SUBTRACT',
            discountValue: 0,
            baseAmount: 3,
            addAmount: 1),
      ]);
      final result = RepeatOrderService.buildCartItemsFromOrder({
        'business_id': 7,
        'items': [
          {
            'item_id': 99,
            'name': item.name,
            'amount': 3,
            'item_data': item.toJson()
          },
        ],
      });
      expect(result.items.single.quantity, 3);
      expect(result.items.single.totalPrice, 300);
    });

    test('extractDeliveryAddress maps saved checkout fields', () {
      final restored =
          RepeatOrderService.extractDeliveryAddress(<String, dynamic>{
        'delivery_type': 'DELIVERY',
        'extra': 'Позвонить за 5 минут',
        'delivery_address': <String, dynamic>{
          'address': 'ул. Абая, 10',
          'street': 'Абая',
          'house': '10',
          'lat': 43.2389,
          'lon': 76.8897,
          'entrance': '2',
          'floor': '5',
          'apartment': '21',
          'other': 'Домофон 21',
          'city': 'Алматы',
          'country': 'Казахстан',
        },
      });

      expect(restored, isNotNull);
      expect(restored?['address'], 'ул. Абая, 10');
      expect(restored?['street'], 'Абая');
      expect(restored?['house'], '10');
      expect(restored?['entrance'], '2');
      expect(restored?['floor'], '5');
      expect(restored?['apartment'], '21');
      expect(restored?['comment'], 'Домофон 21');
      expect(restored?['point'], <String, dynamic>{
        'lat': 43.2389,
        'lon': 76.8897,
      });
      expect(restored?['source'], 'repeat_order');
      expect(restored?['timestamp'], isNotEmpty);
    });

    test('resolveDeliveryType falls back to pickup heuristics', () {
      final deliveryType =
          RepeatOrderService.resolveDeliveryType(<String, dynamic>{
        'delivery_address': <String, dynamic>{
          'address': 'Самовывоз',
        },
      });

      expect(deliveryType, 'PICKUP');
    });
  });
}
