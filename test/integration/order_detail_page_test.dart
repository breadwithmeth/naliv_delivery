import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/pages/checkout_page.dart';
import 'package:naliv_delivery/pages/order_detail_page.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/preferences_store.dart';

Widget _host() => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => BusinessProvider()),
      ],
      child: MaterialApp(
          theme: AppTheme.light(),
          home: const OrderDetailPage(order: {'order_id': 45})),
    );

void main() {
  setUp(() =>
      SharedPreferences.setMockInitialValues({'auth_token': 'fixture-only'}));

  testWidgets('partial preview does not become a fabricated order total',
      (tester) async {
    final unexpected = <String>[];
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/bonuses') {
        return http.Response(
            jsonEncode({
              'success': true,
              'data': {'totalBonuses': 0, 'bonusHistory': <Object>[]},
            }),
            200);
      }
      if (request.method != 'GET' || request.url.path != '/api/orders/45') {
        unexpected.add('${request.method} ${request.url}');
        throw StateError('Unexpected request: ${request.url}');
      }
      return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'order': {
                'order_id': 45,
                'items_summary': {
                  'items_preview': [
                    {'name': 'Одна из позиций', 'amount': 1, 'price': 2500},
                  ]
                },
              }
            }
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    addTearDown(client.close);
    addTearDown(() => expect(unexpected, isEmpty));
    await http.runWithClient(() async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      expect(find.text('Не передано'), findsOneWidget);
      expect(find.text('0 ₸'), findsNothing);
      await tester.scrollUntilVisible(find.text('Одна из позиций'), 200);
      expect(find.text('Одна из позиций'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }, () => client);
  });

  testWidgets(
      'repeated status transitions retain distinct event times in order',
      (tester) async {
    final unexpected = <String>[];
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/bonuses') {
        return http.Response(
            jsonEncode({
              'success': true,
              'data': {'totalBonuses': 0, 'bonusHistory': <Object>[]},
            }),
            200);
      }
      if (request.method != 'GET' || request.url.path != '/api/orders/45') {
        unexpected.add('${request.method} ${request.url}');
        throw StateError('Unexpected request: ${request.url}');
      }
      return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'order': {
                'order_id': 45,
                'order_statuses': [
                  {'status': '1', 'log_timestamp': '2026-10-01T12:00:00'},
                  {'status': '1', 'log_timestamp': '2026-10-01T12:10:00'},
                ],
              }
            }
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    addTearDown(client.close);
    addTearDown(() => expect(unexpected, isEmpty));
    await http.runWithClient(() async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      final earlier = find.text('01.10.2026, 12:00');
      final later = find.text('01.10.2026, 12:10');
      await tester.scrollUntilVisible(earlier, 200);
      expect(later, findsOneWidget);
      expect(earlier, findsOneWidget);
      expect(
          tester.getTopLeft(later).dy, lessThan(tester.getTopLeft(earlier).dy));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }, () => client);
  });

  testWidgets(
      'repeat keeps committed cart but does not open checkout after address save refusal',
      (tester) async {
    const originalAddress = {
      'address': 'Исходный адрес',
      'lat': 52.28,
      'lon': 76.95,
    };
    final preferences = OnboardingPreferences({
      'auth_token': 'fixture-only',
      'selected_address': jsonEncode(originalAddress),
    })
      ..install();
    preferences.rejectedKeys.add('selected_address');
    final cart = CartProvider();
    final business = BusinessProvider();
    addTearDown(cart.dispose);
    addTearDown(business.dispose);
    final unexpected = <String>[];
    const source = {
      'order_id': 45,
      'business_id': 7,
      'business': {'id': 7, 'name': 'Магазин повторного заказа'},
      'current_status': {'status': '4'},
      'delivery_type': 'DELIVERY',
      'delivery_address': {
        'address': 'Адрес повторного заказа',
        'lat': 52.29,
        'lon': 76.96,
      },
      'items': [
        {
          'item_id': 8302,
          'name': 'Повторённый товар',
          'price': 120,
          'amount': 2,
          'item_data': {
            'item_id': 8302,
            'name': 'Повторённый товар',
            'price': 120,
            'unit': 'шт',
            'step_quantity': 1,
            'amount': 10,
          },
        },
      ],
    };
    http.Response jsonResponse(Object value) =>
        http.Response(jsonEncode(value), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        switch (request.url.path) {
          case '/api/orders/45':
            return jsonResponse({
              'success': true,
              'data': {'order': source},
            });
          case '/api/bonuses':
            return jsonResponse({
              'success': true,
              'data': {'totalBonuses': 0, 'bonusHistory': <Object>[]},
            });
        }
      }
      unexpected.add('${request.method} ${request.url}');
      throw StateError('Unexpected repeat fixture request');
    });
    addTearDown(client.close);
    addTearDown(() => expect(unexpected, isEmpty));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<CartProvider>.value(value: cart),
          ChangeNotifierProvider<BusinessProvider>.value(value: business),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const OrderDetailPage(order: source),
        ),
      ));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('order-detail-repeat-button')));
      // The repeat future intentionally awaits this acknowledgment dialog.
      // Its underlying button still animates while busy, so settling before
      // dismissing the dialog would wait on a non-terminating spinner.
      for (var frame = 0;
          frame < 20 && find.byType(AlertDialog).evaluate().isEmpty;
          frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(cart.businessId, 7);
      expect(cart.items.single.itemId, 8302);
      expect(cart.getTotalPrice(), 240);
      expect(business.selectedBusinessId, 7);
      expect(find.byType(CheckoutPage), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Корзина восстановлена'), findsOneWidget);
      expect(find.textContaining('адрес доставки не восстановлен'),
          findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString('selected_address')!), originalAddress);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(TextButton, 'Понятно'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(CheckoutPage), findsNothing);
      expect(cart.items.single.quantity, 2);
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('order-detail-repeat-button')))
              .onPressed,
          isNotNull);
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}
