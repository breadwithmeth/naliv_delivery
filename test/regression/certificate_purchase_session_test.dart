import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/features/certificates/certificate_purchase_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, {int status = 200}) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

CertificatePurchaseSession _draft() => CertificatePurchaseSession()
  ..amountText = '12 345,67'
  ..recipientLogin = '  77010000000  '
  ..message = '  Для тебя  '
  ..selectedCardId = 'bank-card-b';

void main() {
  setUp(() =>
      SharedPreferences.setMockInitialValues({'auth_token': 'fixture-only'}));

  test('positive finite custom amounts are accepted without invented limits',
      () {
    expect(CertificatePurchaseSession.parseAmount('0,01'), 0.01);
    expect(CertificatePurchaseSession.parseAmount('1 234 567'), 1234567);
    expect(CertificatePurchaseSession.parseAmount('10000.125'), 10000.125);
    for (final invalid in ['0', '-1', 'NaN', 'Infinity', '1e309', 'none']) {
      expect(CertificatePurchaseSession.parseAmount(invalid), isNull);
    }
  });

  test(
      'refused purchase retains input and a deliberate retry uses the real card payload',
      () async {
    final session = _draft();
    addTearDown(session.dispose);
    final payloads = <Object>[];
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/certificates/purchase');
      expect(request.headers['authorization'], 'Bearer fixture-only');
      payloads.add(jsonDecode(request.body));
      return payloads.length == 1
          ? _json({
              'success': false,
              'error': {'message': 'Отказ банка'}
            })
          : _json({
              'success': true,
              'data': {
                'payment_status': 'completed',
                'certificate': {'code': 'SERVER-CODE-ONLY'}
              }
            });
    });
    await http.runWithClient(() async {
      await session.purchase();
      expect(session.completed, isFalse);
      expect(session.canPurchase, isTrue);
      expect(session.amountText, '12 345,67');
      expect(session.recipientLogin, '  77010000000  ');
      expect(session.message, '  Для тебя  ');
      expect(session.selectedCardId, 'bank-card-b');
      session
        ..amountText = '17.25'
        ..recipientLogin = ''
        ..message = ''
        ..selectedCardId = 'bank-card-a';
      await session.purchase();
      expect(session.certificate!['code'], 'SERVER-CODE-ONLY');
      expect(payloads, [
        {
          'amount': 12345.67,
          'payment_type': 'card',
          'halyk_card_id': 'bank-card-b',
          'recipient_login': '77010000000',
          'message': 'Для тебя',
        },
        {
          'amount': 17.25,
          'payment_type': 'card',
          'halyk_card_id': 'bank-card-a',
        },
      ]);
    }, () => client);
  });

  test('duplicate taps and refused pending reads never repeat a charge',
      () async {
    final session = _draft();
    addTearDown(session.dispose);
    final purchase = Completer<http.Response>();
    var charges = 0;
    var reads = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path == '/api/certificates/purchase') {
        charges++;
        return purchase.future;
      }
      if (request.method == 'GET' &&
          request.url.path ==
              '/api/certificates/purchases/retained-purchase/status') {
        reads++;
        return reads == 1
            ? _json({'success': false, 'error': 'Статус временно недоступен'},
                status: 503)
            : _json({
                'success': true,
                'data': {
                  'payment_status': 'completed',
                  'certificate': {'code': 'ISSUED-AFTER-STATUS'}
                }
              });
      }
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    });
    await http.runWithClient(() async {
      final first = session.purchase();
      await session.purchase();
      purchase.complete(_json({
        'success': true,
        'data': {
          'purchase_id': 'retained-purchase',
          'payment_status': 'pending',
          'certificate': {'code': 'NOT-ISSUED-YET'},
        }
      }));
      await first;
      expect(charges, 1);
      expect(session.purchaseId, 'retained-purchase');
      expect(session.certificate, isNull);
      expect(session.unconfirmed, isTrue);
      await session.purchase();
      await session.refreshStatus();
      expect(session.purchaseId, 'retained-purchase');
      expect(session.amountText, '12 345,67');
      expect(session.canPurchase, isFalse);
      expect(session.certificate, isNull);
      await session.purchase();
      await session.refreshStatus();
      expect(session.certificate!['code'], 'ISSUED-AFTER-STATUS');
      expect(charges, 1);
      expect(reads, 2);
    }, () => client);
  });

  test('malformed or uncertain purchase responses cannot issue or recharge',
      () async {
    for (final body in [
      <String, Object>{},
      {
        'success': true,
        'data': {'payment_status': 'completed'}
      },
      {
        'success': true,
        'data': {
          'payment_status': 'completed',
          'certificate': {'code': 1234},
        }
      },
    ]) {
      final session = _draft();
      var charges = 0;
      final client = MockClient((request) async {
        charges++;
        return _json(body);
      });
      await http.runWithClient(() async {
        await session.purchase();
        await session.purchase();
      }, () => client);
      expect(session.certificate, isNull);
      expect(session.unconfirmed, isTrue);
      expect(session.canPurchase, isFalse);
      expect(charges, 1);
      session.dispose();
    }
    final session = _draft();
    addTearDown(session.dispose);
    var charges = 0;
    final client = MockClient((request) async {
      charges++;
      return http.Response('{malformed', 200);
    });
    await http.runWithClient(() async {
      await session.purchase();
      await session.purchase();
    }, () => client);
    expect(session.unconfirmed, isTrue);
    expect(session.certificate, isNull);
    expect(charges, 1);
  });
}
