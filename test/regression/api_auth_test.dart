import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/services/auth_service.dart';
import 'package:naliv_delivery/services/notification_service.dart';
import 'package:naliv_delivery/services/push_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(NotificationService.installProvider(
        InMemoryPushProvider(supported: false)));
  });

  test('clears expired JWT sessions even without a cached expiry', () async {
    final token = _buildToken(
      DateTime.now().toUtc().subtract(const Duration(hours: 2)),
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_token': token,
    });

    expect(await ApiService.getAuthToken(), isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), isNull);
    expect(prefs.getString('token_expiry'), isNull);
  });

  test('old full-info success is not returned to a replacement session',
      () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'account-a'});
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final client = MockClient((request) {
      if (request.method != 'GET' ||
          request.url.path != '/api/auth/full-info' ||
          request.headers['Authorization'] != 'Bearer account-a') {
        throw StateError('Unexpected request: $request');
      }
      started.complete();
      return response.future;
    });
    await http.runWithClient(() async {
      final read = ApiService.getFullInfo();
      await started.future;
      await AuthService.saveToken('account-b');
      response.complete(http.Response(
        '{"success":true,"data":{"user":{"id":11,"name":"Account A"}}}',
        200,
        headers: {'content-type': 'application/json'},
      ));
      expect(await read, isNull);
      expect(await ApiService.getAuthToken(), 'account-b');
    }, () => client);
    client.close();
    await AuthService.bindAuthenticatedIdentity(null);
  });

  test(
      'old unauthorized read cannot end a newly established same-token session',
      () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'account-a'});
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final client = MockClient((request) {
      if (request.method != 'GET' ||
          request.url.path != '/api/auth/full-info') {
        throw StateError('Unexpected request: $request');
      }
      started.complete();
      return response.future;
    });
    await http.runWithClient(() async {
      final read = ApiService.getFullInfo();
      await started.future;
      await AuthService.saveToken('account-b');
      await AuthService.saveToken('account-a');
      response.complete(http.Response('{"success":false}', 401));
      expect(await read, isNull);
      expect(await ApiService.getAuthToken(), 'account-a');
    }, () => client);
    client.close();
    await AuthService.bindAuthenticatedIdentity(null);
  });
}

DateTime _truncateToJwtSecond(DateTime value) {
  final utc = value.toUtc();
  return DateTime.fromMillisecondsSinceEpoch(
    (utc.millisecondsSinceEpoch ~/ 1000) * 1000,
    isUtc: true,
  );
}

String _buildToken(DateTime expiry) {
  final encodedHeader = _encodeSegment(<String, Object>{
    'alg': 'HS256',
    'typ': 'JWT',
  });
  final encodedPayload = _encodeSegment(<String, Object>{
    'exp': _truncateToJwtSecond(expiry).millisecondsSinceEpoch ~/ 1000,
  });
  return '$encodedHeader.$encodedPayload.signature';
}

String _encodeSegment(Map<String, Object> value) {
  return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
}
