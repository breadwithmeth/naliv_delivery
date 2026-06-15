import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/services/repeat_order_service.dart';

void main() {
  group('RepeatOrderService', () {
    test('buildCartItemsFromOrder restores valid lines and skips broken ones', () {
      final result = RepeatOrderService.buildCartItemsFromOrder(<String, dynamic>{
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

    test('extractDeliveryAddress maps saved checkout fields', () {
      final restored = RepeatOrderService.extractDeliveryAddress(<String, dynamic>{
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
      final deliveryType = RepeatOrderService.resolveDeliveryType(<String, dynamic>{
        'delivery_address': <String, dynamic>{
          'address': 'Самовывоз',
        },
      });

      expect(deliveryType, 'PICKUP');
    });
  });
}
