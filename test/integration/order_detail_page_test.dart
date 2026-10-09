import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/pages/order_detail_page.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/bonuses') {
        return http.Response(jsonEncode({
          'success': true,
          'data': {'totalBonuses': 0, 'bonusHistory': <Object>[]},
        }), 200);
      }
      if (request.method != 'GET' || request.url.path != '/api/orders/45') {
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
    await http.runWithClient(() async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      expect(find.text('Не передано'), findsOneWidget);
      expect(find.text('0 ₸'), findsNothing);
      await tester.scrollUntilVisible(find.text('Одна из позиций'), 200);
      expect(find.text('Одна из позиций'), findsOneWidget);
    }, () => client);
  });

  testWidgets(
      'repeated status transitions retain distinct event times in order',
      (tester) async {
    final client = MockClient((request) async {
      if (request.method != 'GET' || request.url.path != '/api/orders/45') {
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
    }, () => client);
  });
}
