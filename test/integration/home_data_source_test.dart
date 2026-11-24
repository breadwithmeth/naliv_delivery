import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/features/home/home_data_source.dart';
import 'package:naliv_delivery/features/home/home_view_data.dart';
import 'package:naliv_delivery/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() => AuthService.bindAuthenticatedIdentity(null));

  test(
    'uses the verified credentials and selected store for private reads',
    () async {
      final session = await _startSession('account-a');
      final calls = <String>[];
      final home = await _withHomeApi(
        () => HomeDataSource(businessId: 2, session: session).load(),
        onBonuses: (authorization) {
          calls.add('bonuses: $authorization');
          return _response({'totalBonuses': 164});
        },
        onOrders: (authorization) {
          calls.add('orders: $authorization');
          return _orders(45);
        },
      );

      expect(
        calls,
        unorderedEquals([
          'bonuses: Bearer ${session.token}',
          'orders: Bearer ${session.token}',
        ]),
      );
      expect(home.signedIn, isTrue);
      expect(home.storeId, 2);
      expect(home.storeCityId, 3);
      expect(home.stores.map((store) => store.cityId), [2, 3]);
      expect(home.stores.map((store) => store.city), ['Караганда', 'Астана']);
      expect(home.activeOrder?.id, '45');
      expect(home.activeOrder?.status, 'Собирается');
      expect(home.activeOrder?.source['order_id'], 45);
      expect(home.bonusBalance, 164);
    },
  );

  for (final (name, cachedToken) in [
    ('malformed', 42),
    ('not verified', _token('cached-account')),
  ]) {
    test(
      'public home never reads private endpoints with a $name cache',
      () async {
        SharedPreferences.setMockInitialValues({'auth_token': cachedToken});
        final home = await _withHomeApi(
          () => const HomeDataSource(businessId: 2).load(),
        );

        expect(home.signedIn, isFalse);
        expect(home.storeName, 'Второй');
        expect(home.stores.last.city, 'Астана');
        expect(home.activeOrder, isNull);
        expect(home.bonusBalance, isNull);
        expect(home.bonusCardCode, isNull);
      },
    );
  }

  for (final (name, payload, balance, code)
      in <(String, Object, num?, String?)>[
    ('real zero without a card', {'totalBonuses': 0}, 0, null),
    (
      'decimal balance with malformed card',
      {'totalBonuses': '12.5', 'bonusCard': 'invalid'},
      12.5,
      null,
    ),
    (
      'balance with malformed card UUID',
      {
        'totalBonuses': 25,
        'bonusCard': {
          'cardUuid': <int>[1],
        },
      },
      25,
      null,
    ),
    (
      'balance with a missing card ID encoded as text',
      {
        'totalBonuses': 25,
        'bonusCard': {'cardUuid': 'null'},
      },
      25,
      null,
    ),
    (
      'valid card without a balance',
      {
        'bonusCard': {'cardUuid': 'card-uuid-7'},
      },
      null,
      'card-uuid-7',
    ),
    ('null balance', {'totalBonuses': null}, null, null),
    ('malformed balance', {'totalBonuses': 'not a number'}, null, null),
    ('NaN balance', {'totalBonuses': 'NaN'}, null, null),
    ('infinite balance', {'totalBonuses': 'Infinity'}, null, null),
    ('malformed data', <Object>[], null, null),
  ]) {
    test('handles $name without hiding the public home', () async {
      final home = await _loadWithBonuses(_response(payload));
      expect(home.signedIn, isTrue);
      expect(home.storeId, 2);
      expect(home.bonusBalance, balance);
      expect(home.bonusCardCode, code);
    });
  }

  test('does not show a balance on a rejected or unavailable read', () async {
    for (final response in [
      _response({'totalBonuses': 164}, success: false),
      http.Response('unavailable', 503),
    ]) {
      final home = await _loadWithBonuses(response);
      expect(home.signedIn, isTrue);
      expect(home.storeId, 2);
      expect(home.bonusBalance, isNull);
      expect(home.bonusCardCode, isNull);
    }
  });

  test(
    'discards both private responses after the active account changes',
    () async {
      final accountA = await _startSession('account-a');
      final aBonuses = Completer<http.Response>();
      final aOrders = Completer<http.Response>();
      final requestedBonuses = Completer<void>();
      final requestedOrders = Completer<void>();
      final tokenB = _token('account-b');
      final calls = <String>[];

      await _withHomeApi(
        () async {
          final oldHome = HomeDataSource(
            businessId: 2,
            session: accountA,
          ).load();
          late final HomeViewData stale;
          try {
            await Future.wait([
              requestedBonuses.future,
              requestedOrders.future,
            ]).timeout(const Duration(seconds: 3));

            await AuthService.saveToken(tokenB);
            final accountB = (await AuthService.captureSession())!;
            await AuthService.bindAuthenticatedIdentity('account-b');
            final newHome = await HomeDataSource(
              businessId: 2,
              session: accountB,
            ).load();
            expect(newHome.signedIn, isTrue);
            expect(newHome.bonusBalance, 33);
            expect(newHome.activeOrder?.id, '88');
          } finally {
            aBonuses.complete(
              _response({
                'totalBonuses': 164,
                'bonusCard': {'cardUuid': 'card-of-a'},
              }),
            );
            aOrders.complete(_orders(45));
            stale = await oldHome;
          }
          expect(stale.storeId, 2);
          expect(stale.signedIn, isFalse);
          expect(stale.bonusBalance, isNull);
          expect(stale.bonusCardCode, isNull);
          expect(stale.activeOrder, isNull);
        },
        onBonuses: (authorization) {
          calls.add('bonuses: $authorization');
          if (authorization == 'Bearer ${accountA.token}') {
            requestedBonuses.complete();
            return aBonuses.future;
          }
          return _response({'totalBonuses': 33});
        },
        onOrders: (authorization) {
          calls.add('orders: $authorization');
          if (authorization == 'Bearer ${accountA.token}') {
            requestedOrders.complete();
            return aOrders.future;
          }
          return _orders(88);
        },
      );

      expect(
        calls,
        unorderedEquals([
          'bonuses: Bearer ${accountA.token}',
          'orders: Bearer ${accountA.token}',
          'bonuses: Bearer $tokenB',
          'orders: Bearer $tokenB',
        ]),
      );
    },
  );
}

String _token(String identity) {
  String part(Object data) =>
      base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
  final expires = DateTime.now().toUtc().add(const Duration(hours: 1));
  return '${part({'alg': 'HS256'})}.${part({
        'sub': identity,
        'exp': expires.millisecondsSinceEpoch ~/ 1000
      })}.signature';
}

Future<AuthSession> _startSession(String identity) async {
  SharedPreferences.setMockInitialValues({'auth_token': _token(identity)});
  final session = (await AuthService.captureSession())!;
  await AuthService.bindAuthenticatedIdentity(identity);
  return session;
}

Future<HomeViewData> _loadWithBonuses(http.Response response) async {
  final session = await _startSession('account-a');
  return _withHomeApi(
    () => HomeDataSource(businessId: 2, session: session).load(),
    onBonuses: (_) => response,
    onOrders: (_) => _response({'active_orders': <Object>[]}),
  );
}

http.Response _response(Object data, {bool success = true}) => http.Response(
      jsonEncode({'success': success, 'data': data}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

http.Response _orders(int id) => _response({
      'active_orders': [
        {
          'order_id': id,
          'current_status': {'status': 12},
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
      ],
    });

Future<T> _withHomeApi<T>(
  Future<T> Function() action, {
  FutureOr<http.Response> Function(String?)? onBonuses,
  FutureOr<http.Response> Function(String?)? onOrders,
}) {
  final unexpected = <String>[];
  addTearDown(() => expect(unexpected, isEmpty));
  return http.runWithClient(
    action,
    () => MockClient((request) async {
      final authorization = request.headers['authorization'];
      final query = request.url.queryParameters;
      if (request.method == 'GET') {
        switch (request.url.path) {
          case '/api/businesses'
              when authorization == null &&
                  query.length == 2 &&
                  query['page'] == '1' &&
                  query['limit'] == '1000':
            return _response({
              'businesses': [
                {'id': 1, 'name': 'Первый', 'city_id': 2},
                {'id': 2, 'name': 'Второй', 'city_id': 3},
              ],
            });
          case '/api/categories/supercategories'
              when query.isEmpty && authorization == null:
            return _response({'supercategories': <Object>[]});
          case '/api/users/cities' when query.isEmpty && authorization == null:
            return _response({
              'cities': [
                {'city_id': 2, 'name': 'Караганда'},
                {'city_id': 3, 'name': 'Астана'},
              ],
            });
          case '/api/promotions/active'
              when authorization == null &&
                  query.length == 3 &&
                  query['business_id'] == '2' &&
                  query['limit'] == '50' &&
                  query['offset'] == '0':
            return _response({'promotions': <Object>[]});
          case '/api/bonuses' when query.isEmpty && onBonuses != null:
            return onBonuses(authorization);
          case '/api/orders/my-active-orders'
              when query.length == 1 &&
                  query['business_id'] == '2' &&
                  onOrders != null:
            return onOrders(authorization);
        }
      }
      unexpected.add('${request.method} ${request.url}');
      throw StateError('Unexpected request: ${unexpected.last}');
    }),
  );
}
