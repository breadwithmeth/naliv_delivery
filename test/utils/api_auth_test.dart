import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
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

  test('backfills expiry from a valid JWT and keeps the user logged in', () async {
    final expiry = _truncateToJwtSecond(
      DateTime.now().toUtc().add(const Duration(hours: 2)),
    );
    final token = _buildToken(expiry);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_token': token,
    });

    expect(await ApiService.isUserLoggedIn(), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), token);
    expect(prefs.getString('token_expiry'), expiry.toIso8601String());
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
