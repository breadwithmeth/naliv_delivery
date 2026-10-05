// Regressions for API acknowledgment, authentication and malformed city data.
// All requests stay in the zone-scoped MockClient; no HTTP leaves the process.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Base path, asserted so a change to `ApiService.baseUrl` fails loudly.
const String _apiPath = '/api';

/// Records every intercepted request and answers with [body].
({http.Client client, List<http.Request> requests}) _intercept(
  Object? body, {
  int status = 200,
  required String path,
  String method = 'GET',
  String? rawBody,
}) {
  final requests = <http.Request>[];
  final unexpected = <http.Request>[];
  addTearDown(() => expect(unexpected, isEmpty));
  final client = MockClient((request) async {
    requests.add(request);
    if (request.method != method ||
        request.url.path != path ||
        request.url.queryParameters.isNotEmpty) {
      unexpected.add(request);
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    }
    return http.Response(
      rawBody ?? (body == null ? '' : jsonEncode(body)),
      status,
      headers: const {'content-type': 'application/json'},
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
      final stub = _intercept(
        {
          'success': true,
          'data': {'cities': payload},
        },
        path: '$_apiPath/users/cities',
      );
      expect(await _withClient(stub.client, ApiService.getAvailableCities),
          isNull);
    }
    final empty = _intercept(
      {
        'success': true,
        'data': {'cities': <Object>[]},
      },
      path: '$_apiPath/users/cities',
    );
    expect(await _withClient(empty.client, ApiService.getAvailableCities),
        isEmpty);
  });

  group('auth endpoints · send code', () {
    test('accepts only 200 — verify-code, by contrast, answers 202', () async {
      final stub = _intercept(
        {'success': true},
        status: 201,
        path: '$_apiPath/auth/send-code',
        method: 'POST',
      );

      final result = await _withClient(
        stub.client,
        () => ApiService.sendAuthCode('+77772851609'),
      );

      expect(result.success, isFalse);
      expect(result.statusCode, 201);
      expect(result.cooldownSeconds, isNull);
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
        path: '$_apiPath/auth/verify-code',
        method: 'POST',
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
      final stub = _intercept(
        {
          'success': true,
          'data': {'token': 'irrelevant'},
        },
        path: '$_apiPath/auth/verify-code',
        method: 'POST',
      );

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
        path: '$_apiPath/auth/verify-code',
        method: 'POST',
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
      final stub = _intercept(
        null,
        status: 202,
        rawBody: '{not-json',
        path: '$_apiPath/auth/verify-code',
        method: 'POST',
      );

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
        path: '$_apiPath/auth/full-info',
      );

      final result =
          await _withClient(stub.client, () => ApiService.getFullInfo());

      expect(result, isNull);
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
