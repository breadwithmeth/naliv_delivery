import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/orders/ui/orders_page.dart';
import 'package:naliv_delivery/model/cart_item.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object value) => http.Response(jsonEncode(value), 200,
    headers: {'content-type': 'application/json'});

Map<String, dynamic> _order(int id, String status) => {
      'order_id': id,
      'business_id': 1,
      'log_timestamp': '2026-07-10T23:00:00+05:00',
      'payable_amount': 1234.5,
      'payment_confirmed': false,
      'current_status': {'status': status},
      'items': [
        {
          'item_id': 7,
          'item_name': 'Исторический напиток',
          'price': 2000,
          'amount': 0.5,
          'total_cost': 1000,
          'unit': 'л',
          'item_type': 'Напиток',
          'volume_liters': 0.5,
          'alcohol_percent': 5.5,
        },
      ],
    };

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auth_token': 'fixture-only'});
    await initializeDateFormatting('ru');
  });

  testWidgets(
      'returned order neither claims computed earning nor repays or erases a fresh cart',
      (tester) async {
    final cart = CartProvider();
    await cart.ensureLoaded();
    expect(await cart.bindBusiness(1), isTrue);
    cart.addItem(CartItem(
      itemId: 99,
      name: 'Новый товар',
      price: 700,
      quantity: 2,
      stepQuantity: 1,
      selectedVariants: [],
      promotions: [],
    ));
    var detailReads = 0;
    var ledgerReads = 0;
    final orders = [_order(47, '71'), _order(48, '4'), _order(49, '1')];
    final client = MockClient((request) async {
      expect(request.method, 'GET', reason: 'History must not mutate orders');
      if (request.url.path == '/api/orders/my-orders') {
        return _json({
          'success': true,
          'data': {'orders': orders},
        });
      }
      if (request.url.path == '/api/orders/47') {
        detailReads++;
        return _json({
          'success': true,
          'data': {'order': orders.first},
        });
      }
      if (request.url.path == '/api/bonuses') {
        ledgerReads++;
        return _json({
          'success': true,
          'data': {
            'totalBonuses': -10.5,
            'bonusHistory': [
              {
                'bonusId': 5,
                'orderId': 47,
                'returnId': 'RETURN-47',
                'amount': -30.5,
                'timestamp': '2026-07-11T12:00:00+05:00',
              },
            ],
          },
        });
      }
      throw StateError('Unexpected fixture request: $request');
    });
    await http.runWithClient(() async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: cart,
        child: MaterialApp(theme: AppTheme.dark(), home: const OrdersPage()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('−30,5 бонусов'), findsOneWidget);
      expect(find.text('+30 бонусов'), findsNothing);
      expect(find.text('≈+30 бонусов'), findsOneWidget);
      expect(find.text('1\u00a0234,5 ₸'), findsWidgets);
      await tester.tap(find.text('№47'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('order-detail-pay-button')), findsNothing);
      expect(find.text('+30 бонусов'), findsNothing);
      expect(find.text('−30,5 бонусов'), findsOneWidget);
      expect(find.text('Возврат №RETURN-47'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Кол-во'), 200);
      expect(find.text('0.5 л'), findsOneWidget);
      expect(find.textContaining('5,5%'), findsOneWidget);
      expect(cart.items.single.itemId, 99);
      expect(cart.items.single.quantity, 2);
      final scrollable = find.byType(Scrollable).first;
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(detailReads, 2);
      expect(ledgerReads, 3);
      expect(find.byKey(const ValueKey('order-detail-pay-button')), findsNothing);
      expect(cart.items.single.itemId, 99);
      expect(cart.items.single.quantity, 2);
      final stored = (await SharedPreferences.getInstance())
          .getString('cart_items');
      expect(stored, contains('Новый товар'));
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    cart.dispose();
    await tester.binding.setSurfaceSize(null);
  });
}
