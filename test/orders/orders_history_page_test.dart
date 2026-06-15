import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/pages/orders_history_page.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('renders repeat-order action for history entries', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
          ChangeNotifierProvider<BusinessProvider>(create: (_) => BusinessProvider()),
        ],
        child: MaterialApp(
          home: OrdersHistoryPage(
            initialActiveOrders: const <Map<String, dynamic>>[],
            initialHistoryOrders: <Map<String, dynamic>>[
              <String, dynamic>{
                'order_id': 321,
                'created_at': '2026-06-07T10:00:00.000Z',
                'delivery_type': 'DELIVERY',
                'business': <String, dynamic>{
                  'id': 3,
                  'name': 'Naliv Test Shop',
                  'address': 'ул. Тестовая, 5',
                },
                'delivery_address': <String, dynamic>{
                  'address': 'ул. Абая, 10',
                },
                'items': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'item_id': 501,
                    'name': 'Draft beer',
                    'price': 1500,
                    'amount': 2,
                  },
                ],
              },
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Повторить заказ'), findsOneWidget);
    expect(find.text('Открыть детали'), findsOneWidget);
  });
}
