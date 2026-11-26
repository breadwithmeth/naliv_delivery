import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/pages/checkout_page.dart';
import 'package:naliv_delivery/pages/order_detail_page.dart';
import 'package:naliv_delivery/utils/app_navigator.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/haptic_calls.dart';
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
      final scrollable = find.descendant(
          of: find.byType(CustomScrollView), matching: find.byType(Scrollable));
      final information =
          find.byKey(const PageStorageKey('order-detail-information'));
      await tester.scrollUntilVisible(information, 200, scrollable: scrollable);
      await tester.tap(find.descendant(
          of: information, matching: find.text('Подробности заказа')));
      await tester.pumpAndSettle();
      final earlier = find.text('01.10.2026, 12:00');
      final later = find.text('01.10.2026, 12:10');
      await tester.scrollUntilVisible(earlier, 200, scrollable: scrollable);
      expect(later, findsOneWidget);
      expect(earlier, findsOneWidget);
      expect(
          tester.getTopLeft(later).dy, lessThan(tester.getTopLeft(earlier).dy));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }, () => client);
  });

  for (final restorable in [true, false]) {
    testWidgets(
      restorable
          ? 'repeat reports restored rows and known losses before opening the committed cart'
          : 'repeat reports only the known losses when no row can be restored',
      (tester) async {
    final calls = recordHapticCalls(tester);
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
    const restored = {
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
    };
    final source = {
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
        if (restorable) ...[
          restored,
          restored,
          {
            ...restored,
            'options': [
              {'option_item_relation_id': 91, 'item_name': 'Лайм', 'price': 0},
            ],
          },
        ],
        {'name': 'Строка без идентификатора'},
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
    var cartOpened = 0;
    void opener() => cartOpened++;
    AppNavigator.registerCartOpener(opener);
    addTearDown(() => AppNavigator.unregisterCartOpener(opener));
    await http.runWithClient(() async {
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<CartProvider>.value(value: cart),
          ChangeNotifierProvider<BusinessProvider>.value(value: business),
        ],
        child: MaterialApp(
          navigatorKey: AppNavigator.key,
          theme: AppTheme.light(),
          home: OrderDetailPage(order: source),
        ),
      ));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('order-detail-repeat-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Собираем корзину…'), findsNothing);
      expect(cartOpened, 0);
      if (!restorable) {
        expect(find.text('Не удалось повторить заказ'), findsOneWidget);
        expect(find.textContaining('Корзина не изменена.'), findsOneWidget);
        expect(find.textContaining('Восстановлено строк заказа:'), findsNothing);
        expect(find.byKey(const ValueKey('repeat-open-cart')), findsNothing);
        expect(calls, isEmpty);
        expect(cart.items, isEmpty);
        expect(tester.takeException(), isNull);
        return;
      }
      expect(find.text('Восстановлено строк заказа: 3'), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(AlertDialog),
              matching: find.textContaining('Строка без идентификатора')),
          findsOneWidget);
      expect(find.textContaining('Не удалось сохранить прежний адрес доставки'),
          findsOneWidget);
      expect(calls, [selectionClick]);
      await tester.tap(find.byKey(const ValueKey('repeat-open-cart')));
      await tester.pumpAndSettle();
      expect(cartOpened, 1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(calls, [selectionClick]);
      expect(find.byType(CheckoutPage), findsNothing);
      expect(cart.businessId, 7);
      expect(cart.items.map((item) => item.itemId), [8302, 8302]);
      expect(cart.items.map((item) => item.quantity), [4, 2]);
      expect(cart.items.first.selectedVariants, isEmpty);
      expect(cart.items.last.selectedVariants.single['relation_id'], 91);
      expect(cart.getTotalPrice(), 720);
      expect(business.selectedBusinessId, 7);
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString('selected_address')!), originalAddress);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }, () => client);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }
}
