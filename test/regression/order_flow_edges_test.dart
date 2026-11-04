import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/services/repeat_order_service.dart';
import 'package:naliv_delivery/utils/auto_order_lines.dart';
import 'package:naliv_delivery/utils/order_flow_navigation.dart';

Map<String, dynamic> _line(int id, String name,
        {String? code, num amount = 1}) =>
    {
      'item_id': id,
      'name': name,
      if (code != null) 'code': code,
      'amount': amount,
      'price': 100,
    };

void main() {
  group('repeating an order', () {
    test('drops the bag and the draft bottles, keeps the drinks', () {
      final order = {
        'business_id': 11,
        'items': [
          _line(104298, 'Пиво розлив Wukong 1л 4.0% светлое', amount: 3),
          _line(113385, 'Пластиковая бутылка 2л с крышкой'),
          _line(113381, 'Пластиковая бутылка 1л с крышкой'),
          _line(900, 'Пакет-майка Градусы24', code: brandedBagCode),
          _line(555, 'Чипсы Lays 80 г'),
        ],
      };
      final result = RepeatOrderService.buildCartItemsFromOrder(order);
      expect(result.items.map((item) => item.itemId), [104298, 555]);
      expect(result.skippedItems, isEmpty);
    });

    test('a bottle bought on its own is kept when no drink is on tap', () {
      final order = {
        'business_id': 11,
        'items': [_line(113381, 'Пластиковая бутылка 1л с крышкой', amount: 2)],
      };
      expect(
          RepeatOrderService.buildCartItemsFromOrder(order).items.single.itemId,
          113381);
    });
  });

  group('a freshly created order', () {
    final request = {
      'delivery_type': 'DELIVERY',
      'street': 'Мира',
      'house': '86а',
      'lat': 50.05,
      'lon': 72.96,
      'entrance': '2',
      'floor': '7',
      'apartment': '45',
      'extra': 'домофон не работает',
    };

    test('keeps the address this checkout sent when the answer has none', () {
      final order = withSubmittedAddress(
          {'order_id': 901, 'delivery_address': null}, request);
      final address = order['delivery_address'] as Map;
      expect(address['address'], 'Мира, 86а');
      expect(address['apartment'], '45');
      expect(address['comment'], 'домофон не работает');
      expect(order['delivery_type'], 'DELIVERY');
    });

    test('the server\'s own address values win', () {
      final order = withSubmittedAddress({
        'order_id': 902,
        'delivery_address': {'address': 'Темиртау, Мира 86а', 'floor': ''},
      }, request);
      final address = order['delivery_address'] as Map;
      expect(address['address'], 'Темиртау, Мира 86а');
      expect(address['floor'], '7');
    });

    test('pickup orders get no delivery address', () {
      final order = withSubmittedAddress(
          {'order_id': 903}, {...request, 'delivery_type': 'PICKUP'});
      expect(order.containsKey('delivery_address'), isFalse);
      expect(order['delivery_type'], 'PICKUP');
    });
  });
}
