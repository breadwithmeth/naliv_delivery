// Contract tests for the endpoints the home screen depends on.
//
// These pin the *frozen* request shape (method, path, query, headers) and the
// normalization each method promises, so a signature change made while the
// backend stays put is caught here instead of in production.
//
// Transport is intercepted with `http.runWithClient`, which `package:http`
// resolves through a zone-scoped client factory. That is what lets the existing
// static `ApiService` — top-level `http.get` calls and all — be tested without
// restructuring it. No request leaves the process: `MockClient` performs no I/O.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Base path, asserted so a change to `ApiService.baseUrl` fails loudly.
const String _apiPath = '/api';

/// Records every intercepted request and answers with [body].
///
/// [status] and [body] are per-test so each case can pin both the success and
/// the failure contract of the method under test.
({http.Client client, List<http.Request> requests}) _intercept(
  Object? body, {
  int status = 200,
  Map<String, String> headers = const <String, String>{},
  String? rawBody,
}) {
  final requests = <http.Request>[];
  final client = MockClient((request) async {
    requests.add(request);
    return http.Response(
      rawBody ?? (body == null ? '' : jsonEncode(body)),
      status,
      headers: <String, String>{
        'content-type': 'application/json',
        ...headers,
      },
    );
  });
  return (client: client, requests: requests);
}

/// Runs [action] with every `http` call in the zone routed to [client].
Future<T> _withClient<T>(http.Client client, Future<T> Function() action) =>
    http.runWithClient(action, () => client);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('city payload failure is not a valid zero-city response', () async {
    for (final payload in [
      null,
      <String, Object>{},
      [null]
    ]) {
      final stub = _intercept({
        'success': true,
        'data': {'cities': payload},
      });
      expect(await _withClient(stub.client, ApiService.getAvailableCities),
          isNull);
    }
    final empty = _intercept({
      'success': true,
      'data': {'cities': <Object>[]},
    });
    expect(await _withClient(empty.client, ApiService.getAvailableCities),
        isEmpty);
  });

  group('home endpoints · businesses', () {
    test('GETs the paged businesses path and unwraps data', () async {
      final stub = _intercept({
        'success': true,
        'data': {
          'businesses': [
            {'id': 7, 'name': 'Градусы24', 'address': 'Бухар-Жырау 70'},
          ],
        },
      });

      final result = await _withClient(
        stub.client,
        () => ApiService.getBusinesses(page: 2, limit: 5),
      );

      expect(stub.requests, hasLength(1));
      final request = stub.requests.single;
      expect(request.method, 'GET');
      expect(request.url.path, '$_apiPath/businesses');
      expect(
        request.url.queryParameters,
        <String, String>{'page': '2', 'limit': '5'},
      );
      expect(request.headers['Accept'], 'application/json');
      expect(request.headers['Content-Type'], 'application/json');

      // The envelope is unwrapped: callers get `data`, not the whole body.
      expect(result, isA<Map<String, dynamic>>());
      expect(result!['businesses'], hasLength(1));
      expect((result['businesses'] as List).single['id'], 7);
    });

    test('returns null, not a throw, when the API reports failure', () async {
      final stub = _intercept({'success': false, 'message': 'nope'});

      final result =
          await _withClient(stub.client, () => ApiService.getBusinesses());

      expect(result, isNull);
    });

    test('returns null on a non-200 response', () async {
      final stub = _intercept({'success': true}, status: 500);

      final result =
          await _withClient(stub.client, () => ApiService.getBusinesses());

      expect(result, isNull);
    });

    test('returns null for a malformed successful response', () async {
      final stub = _intercept(null, rawBody: '{not-json');

      final result =
          await _withClient(stub.client, () => ApiService.getBusinesses());

      expect(result, isNull);
    });
  });

  group('home endpoints · supercategories', () {
    test('normalizes missing and singleton child collections to lists',
        () async {
      final stub = _intercept({
        'success': true,
        'data': {
          'supercategories': [
            {
              'supercategory_id': 100,
              'name': 'Кухня',
              // A singleton map must arrive as a one-element list...
              'categories': {'category_id': 5, 'name': 'Готовые блюда'},
              // ...and an absent collection as an empty one, never null.
              'subcategories': null,
            },
          ],
        },
      });

      final result =
          await _withClient(stub.client, () => ApiService.getSuperCategories());

      expect(stub.requests.single.url.path,
          '$_apiPath/categories/supercategories');
      expect(stub.requests.single.method, 'GET');
      expect(stub.requests.single.headers['Content-Type'], 'application/json');

      expect(result, hasLength(1));
      final supercategory = result!.single;
      expect(supercategory['supercategory_id'], 100);
      expect(supercategory['name'], 'Кухня');

      final categories = supercategory['categories'] as List;
      expect(categories, hasLength(1));
      expect(categories.single['category_id'], 5);
      expect(supercategory['subcategories'], isEmpty);
    });

    test('returns null when the response is not marked successful', () async {
      final stub = _intercept({'success': false});

      final result =
          await _withClient(stub.client, () => ApiService.getSuperCategories());

      expect(result, isNull);
    });
  });

  group('home endpoints · active promotions', () {
    test('sends limit and offset, and omits business_id when unknown',
        () async {
      final stub = _intercept({
        'success': true,
        'data': {'promotions': []}
      });

      await _withClient(
        stub.client,
        () => ApiService.getActivePromotions(limit: 12, offset: 0),
      );

      final request = stub.requests.single;
      expect(request.url.path, '$_apiPath/promotions/active');
      expect(request.method, 'GET');
      expect(request.headers['Content-Type'], 'application/json');
      expect(request.headers['Accept'], 'application/json');
      expect(request.url.queryParameters, <String, String>{
        'limit': '12',
        'offset': '0',
      });
      expect(request.url.queryParameters.containsKey('business_id'), isFalse);
    });

    test('adds business_id when the store is known', () async {
      final stub = _intercept({
        'success': true,
        'data': {'promotions': []}
      });

      await _withClient(
        stub.client,
        () => ApiService.getActivePromotions(businessId: 7, limit: 5),
      );

      expect(stub.requests.single.url.queryParameters['business_id'], '7');
    });

    test('returns the whole envelope, not the inner data', () async {
      final stub = _intercept({
        'success': true,
        'data': {'promotions': []},
      });

      final result = await _withClient(
        stub.client,
        () => ApiService.getActivePromotions(),
      );

      // Unlike getBusinesses, this one hands back the envelope — the shape
      // HomeDataSource reads.
      expect(result!['success'], isTrue);
      expect(result['data'], isA<Map<String, dynamic>>());
    });
  });

  group('home endpoints · bonuses', () {
    test('makes no request at all when there is no session', () async {
      final stub = _intercept({
        'success': true,
        'data': {'totalBonuses': 164}
      });

      final result =
          await _withClient(stub.client, () => ApiService.getUserBonuses());

      expect(result, isNull);
      // The guard must short-circuit before the network, not after a 401.
      expect(stub.requests, isEmpty);
    });

    test('authorizes with the stored token and returns the decoded body',
        () async {
      final token = _buildToken(
        DateTime.now().toUtc().add(const Duration(hours: 2)),
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auth_token': token,
      });

      final stub = _intercept({
        'success': true,
        'data': {
          'totalBonuses': 164,
          'bonusCard': {'cardUuid': 'card-uuid-1'},
        },
      });

      final result =
          await _withClient(stub.client, () => ApiService.getUserBonuses());

      final request = stub.requests.single;
      expect(request.url.path, '$_apiPath/bonuses');
      expect(request.headers['Authorization'], 'Bearer $token');
      expect(request.headers['Content-Type'], 'application/json');

      // Deliberately *not* the same shape as getBusinesses: this one returns the
      // raw decoded body, so callers must read through `data`. HomeDataSource
      // unwraps it; if this ever started returning the inner map too, the bonus
      // card would silently read zero.
      expect(result!.containsKey('totalBonuses'), isFalse);
      expect(result['data']['totalBonuses'], 164);
      expect(result['data']['bonusCard']['cardUuid'], 'card-uuid-1');
    });
  });

  group('auth endpoints · send code', () {
    test('POSTs phone_number and reports the send result', () async {
      final stub = _intercept({'success': true, 'message': 'Код отправлен'});

      final result = await _withClient(
        stub.client,
        () => ApiService.sendAuthCode('+77772851609'),
      );

      final request = stub.requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '$_apiPath/auth/send-code');
      expect(jsonDecode(request.body), <String, dynamic>{
        'phone_number': '+77772851609',
      });
      expect(request.headers['Content-Type'], 'application/json');

      expect(result.success, isTrue);
      expect(result.message, 'Код отправлен');
      expect(result.statusCode, 200);
      expect(result.cooldownSeconds, isNull);
    });

    test('returns a failed result for malformed JSON', () async {
      final stub = _intercept(null, rawBody: '{not-json');

      final result = await _withClient(
        stub.client,
        () => ApiService.sendAuthCode('+77772851609'),
      );

      expect(result.success, isFalse);
      expect(result.statusCode, 200);
      expect(result.message, 'Не удалось отправить код.');
    });

    test('accepts only 200 — verify-code, by contrast, answers 202', () async {
      final stub = _intercept({'success': true}, status: 201);

      final result = await _withClient(
        stub.client,
        () => ApiService.sendAuthCode('+77772851609'),
      );

      expect(result.success, isFalse);
      expect(result.statusCode, 201);
      expect(result.cooldownSeconds, isNull);
    });

    test('reads the cooldown from retry-after on 429', () async {
      final stub = _intercept(
        {'success': false, 'message': 'Слишком много запросов'},
        status: 429,
        headers: const {'retry-after': '45'},
      );

      final result = await _withClient(
        stub.client,
        () => ApiService.sendAuthCode('+77772851609'),
      );

      expect(result.success, isFalse);
      expect(result.cooldownSeconds, 45);
    });

    test('falls back from message wording to a 60 second default', () async {
      final fromMessage = await _withClient(
        _intercept(
          {'success': false, 'message': 'Повторите через 2 минуты'},
          status: 429,
        ).client,
        () => ApiService.sendAuthCode('+77772851609'),
      );
      expect(fromMessage.cooldownSeconds, 120);

      final unparseable = await _withClient(
        _intercept(
          {'success': false, 'message': 'Слишком много запросов'},
          status: 429,
        ).client,
        () => ApiService.sendAuthCode('+77772851609'),
      );
      expect(unparseable.cooldownSeconds, 60);
    });
  });

  group('auth endpoints · verify code', () {
    test('POSTs both fields and stores the session token', () async {
      final token = _buildToken(
        DateTime.now().toUtc().add(const Duration(hours: 2)),
      );
      final stub = _intercept(
        {
          'success': true,
          'data': {
            'token': token,
            'user': {'id': 1},
          },
        },
        status: 202,
      );

      final result = await _withClient(
        stub.client,
        () => ApiService.verifyAuthCode('+77772851609', '1234'),
      );

      final request = stub.requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '$_apiPath/auth/verify-code');
      expect(jsonDecode(request.body), <String, dynamic>{
        'phone_number': '+77772851609',
        'onetime_code': '1234',
      });
      expect(request.headers['Content-Type'], 'application/json');

      expect(result!['token'], token);

      // Verifying is what starts the session: both the token and the expiry
      // decoded from it must land in storage, or every later authenticated
      // call silently degrades to a guest.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), token);
      expect(prefs.getString('token_expiry'), isNotNull);
    });

    test('rejects a 200 answer and stores nothing', () async {
      final stub = _intercept({
        'success': true,
        'data': {'token': 'irrelevant'},
      });

      final result = await _withClient(
        stub.client,
        () => ApiService.verifyAuthCode('+77772851609', '1234'),
      );

      expect(result, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), isNull);
    });

    test('returns null when the code is refused', () async {
      final stub = _intercept(
        {'success': false, 'message': 'Неверный код'},
        status: 202,
      );

      final result = await _withClient(
        stub.client,
        () => ApiService.verifyAuthCode('+77772851609', '0000'),
      );

      expect(result, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), isNull);
    });

    test('returns null and stores nothing for malformed JSON', () async {
      final stub = _intercept(null, status: 202, rawBody: '{not-json');

      final result = await _withClient(
        stub.client,
        () => ApiService.verifyAuthCode('+77772851609', '1234'),
      );

      expect(result, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), isNull);
    });
  });

  group('auth endpoints · full info', () {
    test('makes no request without a session', () async {
      final stub = _intercept({'success': true, 'data': <String, dynamic>{}});

      final result =
          await _withClient(stub.client, () => ApiService.getFullInfo());

      expect(result, isNull);
      expect(stub.requests, isEmpty);
    });

    test('authorizes and unwraps the user payload', () async {
      final token = _buildToken(
        DateTime.now().toUtc().add(const Duration(hours: 2)),
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auth_token': token,
      });
      final stub = _intercept({
        'success': true,
        'data': {
          'user': {'name': 'Аскар'},
          'addresses': <Object>[],
          'cards': <Object>[],
        },
      });

      final result =
          await _withClient(stub.client, () => ApiService.getFullInfo());

      final request = stub.requests.single;
      expect(request.method, 'GET');
      expect(request.url.path, '$_apiPath/auth/full-info');
      expect(request.headers['Authorization'], 'Bearer $token');
      expect(request.headers['Content-Type'], 'application/json');

      expect(result!['user']['name'], 'Аскар');
      expect(result['addresses'], isEmpty);
    });

    test('returns null when the server rejects the session', () async {
      final token = _buildToken(
        DateTime.now().toUtc().add(const Duration(hours: 2)),
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auth_token': token,
      });
      final stub = _intercept(
        {'success': false, 'message': 'Unauthorized'},
        status: 401,
      );

      final result =
          await _withClient(stub.client, () => ApiService.getFullInfo());

      expect(result, isNull);
    });
  });

  group('catalog endpoints · category items', () {
    test('scopes the nested path by store and returns the envelope', () async {
      final stub = _intercept({
        'success': true,
        'data': {'items': <Object>[]},
      });

      final result = await _withClient(
        stub.client,
        () =>
            ApiService.getCategoryItems(12, businessId: 7, page: 3, limit: 20),
      );

      final request = stub.requests.single;
      expect(request.method, 'GET');
      expect(request.url.path, '$_apiPath/categories/12/items');
      expect(request.url.queryParameters, <String, String>{
        'business_id': '7',
        'page': '3',
        'limit': '20',
      });
      expect(request.headers['Content-Type'], 'application/json');
      expect(request.headers['Accept'], 'application/json');

      // Envelope, not the inner data — same shape as the promotions endpoint.
      expect(result!['success'], isTrue);
      expect(result['data'], isA<Map<String, dynamic>>());
    });
  });
}

/// Minimal unsigned JWT carrying only the `exp` claim, which is all
/// `ApiService.getAuthToken` inspects to decide whether a session is alive.
String _buildToken(DateTime expiry) {
  final seconds = DateTime.fromMillisecondsSinceEpoch(
        (expiry.toUtc().millisecondsSinceEpoch ~/ 1000) * 1000,
        isUtc: true,
      ).millisecondsSinceEpoch ~/
      1000;
  String segment(Map<String, Object> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${segment({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${segment({'exp': seconds})}.signature';
}
