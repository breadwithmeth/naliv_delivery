import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/orders/ui/orders_page.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auth_token': 'fixture-only'});
    await initializeDateFormatting('ru');
  });

  for (final brightness in Brightness.values) {
    testWidgets(
        'scaled order total remains inside its tappable card at 320px / $brightness',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 812));
      final cart = CartProvider();
      int? opened;
      final client = MockClient((request) async {
        if (request.method != 'GET' ||
            request.url.path != '/api/orders/my-orders') {
          throw StateError(
              'Unexpected fixture request: ${request.method} ${request.url}');
        }
        return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'orders': [
                  {
                    'order_id': 45,
                    'log_timestamp': '2026-10-01T11:40:00Z',
                    'current_status': {'status': '4'},
                    'total_amount': 40410
                  },
                ]
              }
            }),
            200);
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(ChangeNotifierProvider<CartProvider>.value(
          value: cart,
          child: MaterialApp(
            theme: brightness == Brightness.dark
                ? AppTheme.dark()
                : AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(top: 48, bottom: 34),
                textScaler: const TextScaler.linear(2),
              ),
              child: child!,
            ),
            home: OrdersPage(
                businessId: 1,
                onOpenOrder: (order) => opened = order['order_id'] as int),
          ),
        ));
        await tester.pumpAndSettle();
        final total = find.text('40\u00a0410 ₸');
        final card = find
            .ancestor(of: total, matching: find.byType(GestureDetector))
            .first;
        final cardRect = tester.getRect(card);
        final totalRect = tester.getRect(total);
        expect(totalRect.top, greaterThanOrEqualTo(cardRect.top));
        expect(totalRect.bottom, lessThanOrEqualTo(cardRect.bottom));
        expect(totalRect.right, lessThanOrEqualTo(cardRect.right));
        await tester.tap(total);
        expect(opened, 45);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
      cart.dispose();
      await tester.binding.setSurfaceSize(null);
    });
  }
}
