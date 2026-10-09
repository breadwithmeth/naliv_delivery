import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/pages/card_flow.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object? value, {int status = 200}) =>
    http.Response(jsonEncode(value), status);

Matcher _failure(SavedCardReadFailure reason) => isA<SavedCardReadException>()
    .having((error) => error.reason, 'reason', reason);

void main() {
  setUp(() =>
      SharedPreferences.setMockInitialValues({'auth_token': 'fixture-only'}));

  test('Halyk collection keeps charge identity and isolates unsafe records',
      () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/user/cards');
      expect(request.url.queryParameters, {'source': 'halyk'});
      expect(request.headers['Authorization'], 'Bearer fixture-only');
      return _json({
        'success': true,
        'data': {
          'cards': [
            {
              'id': 'summary-row',
              'card_id': 'provider-card',
              'halyk_id': 'chargeable-bank-id',
              'card_mask': '****4444',
            },
            {'mask': '****1234'},
            {'id': 'unsafe', 'mask': '4111111111111111'},
            null,
          ],
        },
      });
    });
    await http.runWithClient(() async {
      final result =
          SavedCard.parse(await ApiService.getUserCards(source: 'halyk'));
      expect(result.cards.where((card) => card.canCharge).single.chargeId,
          'chargeable-bank-id');
      expect(result.cards.map((card) => card.mask), ['****4444', '****1234']);
      expect(result.cards.last.chargeId, isNull);
      expect(result.rejectedCount, 2);
      expect(result.complete, isFalse);
    }, () => client);
  });

  test('only a supplied empty cards list is genuinely empty', () async {
    for (final data in [
      null,
      <String, Object>{},
      {'cards': null},
      <Object>[]
    ]) {
      final client =
          MockClient((_) async => _json({'success': true, 'data': data}));
      await http.runWithClient(() async {
        await expectLater(ApiService.getUserCards(source: 'halyk'),
            throwsA(_failure(SavedCardReadFailure.invalidData)));
      }, () => client);
    }
    final empty = MockClient((_) async => _json({
          'success': true,
          'data': {'cards': <Object>[]},
        }));
    await http.runWithClient(() async {
      final result =
          SavedCard.parse(await ApiService.getUserCards(source: 'halyk'));
      expect(result.cards, isEmpty);
      expect(result.complete, isTrue);
    }, () => empty);
  });

  test('server refusal and unreadable JSON are not an empty collection',
      () async {
    for (final response in [
      _json({
        'success': false,
        'data': {'cards': <Object>[]}
      }),
      http.Response('{not-json', 200),
      http.Response('unavailable', 503),
    ]) {
      final client = MockClient((_) async => response);
      await http.runWithClient(() async {
        await expectLater(ApiService.getUserCards(source: 'halyk'),
            throwsA(isA<SavedCardReadException>()));
      }, () => client);
    }
  });

  test(
      'absent and expired sessions require sign-in without contacting the bank',
      () async {
    for (final values in <Map<String, Object>>[
      {},
      {
        'auth_token': 'fixture-only',
        'token_expiry': DateTime.utc(2000).toIso8601String(),
      },
    ]) {
      SharedPreferences.setMockInitialValues(values);
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        throw StateError(
            'Unexpected request: ${request.method} ${request.url}');
      });
      await http.runWithClient(() async {
        await expectLater(ApiService.getUserCards(source: 'halyk'),
            throwsA(_failure(SavedCardReadFailure.authentication)));
        final link = await ApiService.generateAddCardLinkResult();
        expect(link.authRequired, isTrue);
        expect(link.success, isFalse);
        expect(link.link, isNull);
        expect(requests, 0);
      }, () => client);
    }
  });

  test('HTTP 401 during read or link preparation is authentication loss',
      () async {
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer fixture-only');
      if (request.method == 'GET' && request.url.path == '/api/user/cards') {
        return http.Response('Unauthorized', 401);
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/payments/generate-add-card-link') {
        return http.Response('Unauthorized', 401);
      }
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    });
    await http.runWithClient(() async {
      await expectLater(ApiService.getUserCards(source: 'halyk'),
          throwsA(_failure(SavedCardReadFailure.authentication)));
      final link = await ApiService.generateAddCardLinkResult();
      expect(link.authRequired, isTrue);
      expect(link.success, isFalse);
      expect(link.link, isNull);
    }, () => client);
  });
}
