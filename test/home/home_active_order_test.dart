import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/features/home/home_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('active order uses the selected store and the server status', () async {
    final expiration = DateTime.now().toUtc().add(const Duration(hours: 1));
    final expirationSeconds = expiration.millisecondsSinceEpoch ~/ 1000;
    String jwtPart(Object data) =>
        base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
    SharedPreferences.setMockInitialValues({
      'auth_token': '${jwtPart({'alg': 'HS256'})}.${jwtPart({
            'exp': expirationSeconds
          })}.signature',
    });
    final calls = <Uri>[];
    final home = await http.runWithClient(
      () => const HomeDataSource(businessId: 2).load(),
      () => MockClient((request) async {
        calls.add(request.url);
        final path = request.url.path;
        Object data;
        if (path.endsWith('/businesses')) {
          data = {
            'businesses': [
              {'id': 1, 'name': 'Первый', 'address': 'Улица 1'},
              {'id': 2, 'name': 'Второй', 'address': 'Улица 2'},
            ],
          };
        } else if (path.endsWith('/orders/my-active-orders')) {
          data = {
            'active_orders': [
              {
                'order_id': 45,
                'current_status': {'status': 12},
                'created_at': DateTime.now().toUtc().toIso8601String(),
              },
            ],
          };
        } else if (path.endsWith('/categories/supercategories')) {
          data = {'supercategories': <Object>[]};
        } else if (path.endsWith('/promotions/active')) {
          data = {'promotions': <Object>[]};
        } else if (path.endsWith('/users/cities')) {
          data = {'cities': <Object>[]};
        } else if (path.contains('bonuses')) {
          data = {'totalBonuses': 164};
        } else {
          return http.Response('{}', 404);
        }
        return http.Response(jsonEncode({'success': true, 'data': data}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );

    expect(home.activeOrder?.id, '45');
    expect(home.activeOrder?.status, 'Собирается');
    expect(home.activeOrder?.source['order_id'], 45);
    expect(
      calls
          .singleWhere((uri) => uri.path.endsWith('/orders/my-active-orders'))
          .queryParameters['business_id'],
      '2',
    );
  });
}
