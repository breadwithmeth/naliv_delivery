import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/features/certificates/certificate_purchase_session.dart';
import 'package:naliv_delivery/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/preferences_store.dart';

http.Response _json(Object body, {int status = 200}) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

CertificatePurchaseSession _draft() => CertificatePurchaseSession()
  ..amountText = '12 345,67'
  ..recipientLogin = '  77010000000  '
  ..message = '  Для тебя  '
  ..selectedCardId = 'bank-card-b';

class _RefusedFinancialPreferences extends OnboardingPreferences {
  _RefusedFinancialPreferences() : super({'auth_token': 'fixture-only'});

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auth_token': 'fixture-only'});
    await AuthService.notifySessionChanged();
    await AuthService.bindAuthenticatedIdentity('certificate-fixture-user');
  });

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
      SharedPreferences.setMockInitialValues({'auth_token': 'fixture-only'});
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
    SharedPreferences.setMockInitialValues({'auth_token': 'fixture-only'});
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

  for (final status in [408, 500, 503]) {
    test('JSON $status certificate response cannot permit a second charge',
        () async {
      final session = _draft();
      addTearDown(session.dispose);
      final unknown = <String>[];
      var charges = 0;
      final client = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path == '/api/certificates/purchase') {
          charges++;
          expect(request.headers['authorization'], 'Bearer fixture-only');
          return _json({
            'success': false,
            'error': {'message': 'Ответ сервера недоступен'},
          }, status: status);
        }
        unknown.add('${request.method} ${request.url}');
        throw StateError('Unexpected certificate request');
      });
      addTearDown(() => expect(unknown, isEmpty));
      await http.runWithClient(() async {
        await session.purchase();
        await session.purchase();
      }, () => client);
      expect(charges, 1);
      expect(session.unconfirmed, isTrue);
      expect(session.canPurchase, isFalse);
      expect(session.certificate, isNull);
    });
  }

  test('refused durable certificate intent sends no charge', () async {
    _RefusedFinancialPreferences().install();
    final session = _draft();
    addTearDown(session.dispose);
    final unknown = <String>[];
    var charges = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path == '/api/certificates/purchase') {
        charges++;
        return _json({'success': false, 'error': 'Fixture refusal'});
      }
      unknown.add('${request.method} ${request.url}');
      throw StateError('Unexpected certificate request');
    });
    addTearDown(() => expect(unknown, isEmpty));
    await http.runWithClient(session.purchase, () => client);
    expect(charges, 0);
    expect(session.certificate, isNull);
    expect(session.error, isNotNull);
  });

  test(
      'pending purchase identity survives session recreation for status-only recovery',
      () async {
    final first = _draft();
    final restored = _draft();
    addTearDown(restored.dispose);
    final unknown = <String>[];
    var charges = 0;
    var statusReads = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path == '/api/certificates/purchase') {
        charges++;
        return _json({
          'success': true,
          'data': {
            'purchase_id': 'durable-purchase',
            'payment_status': 'pending',
          },
        });
      }
      if (request.method == 'GET' &&
          request.url.path ==
              '/api/certificates/purchases/durable-purchase/status') {
        statusReads++;
        return _json({
          'success': true,
          'data': {
            'payment_status': 'completed',
            'certificate': {'code': 'RECOVERED-ONLY-BY-READ'},
          },
        });
      }
      unknown.add('${request.method} ${request.url}');
      throw StateError('Unexpected certificate request');
    });
    addTearDown(() => expect(unknown, isEmpty));
    await http.runWithClient(() async {
      await first.purchase();
      first.dispose();
      await restored.refreshStatus();
      expect(restored.purchaseId, 'durable-purchase');
      expect(restored.certificate?['code'], 'RECOVERED-ONLY-BY-READ');
      await restored.purchase();
    }, () => client);
    expect(charges, 1);
    expect(statusReads, 1);
  });

  test('unknown purchase without identity survives session recreation',
      () async {
    final first = _draft();
    final restored = _draft();
    addTearDown(restored.dispose);
    final unknown = <String>[];
    var charges = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path == '/api/certificates/purchase') {
        charges++;
        return http.Response('{malformed', 200);
      }
      unknown.add('${request.method} ${request.url}');
      throw StateError('Unexpected certificate request');
    });
    addTearDown(() => expect(unknown, isEmpty));
    await http.runWithClient(() async {
      await first.purchase();
      first.dispose();
      await restored.purchase();
    }, () => client);
    expect(charges, 1);
    expect(restored.purchaseId, isNull);
    expect(restored.unconfirmed, isTrue);
    expect(restored.canPurchase, isFalse);
  });

  test('JSON 503 retains purchase identity for existing status recovery',
      () async {
    final session = _draft();
    addTearDown(session.dispose);
    final unknown = <String>[];
    var charges = 0;
    var statusReads = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path == '/api/certificates/purchase') {
        charges++;
        return _json({
          'success': false,
          'error': 'Ответ сервера недоступен',
          'data': {
            'purchase_id': 'identity-from-503',
            'payment_status': 'pending',
          },
        }, status: 503);
      }
      if (request.method == 'GET' &&
          request.url.path ==
              '/api/certificates/purchases/identity-from-503/status') {
        statusReads++;
        return _json({
          'success': true,
          'data': {'payment_status': 'pending'},
        });
      }
      unknown.add('${request.method} ${request.url}');
      throw StateError('Unexpected certificate request');
    });
    addTearDown(() => expect(unknown, isEmpty));
    await http.runWithClient(() async {
      await session.purchase();
      expect(session.purchaseId, 'identity-from-503');
      await session.refreshStatus();
      await session.purchase();
    }, () => client);
    expect(charges, 1);
    expect(statusReads, 1);
    expect(session.unconfirmed, isTrue);
  });

  test(
      'account switch isolates unresolved intent and returning account stays locked',
      () async {
    await AuthService.bindAuthenticatedIdentity('certificate-account-a');
    addTearDown(() => AuthService.bindAuthenticatedIdentity(null));
    final accountA = _draft();
    final restoredA = _draft();
    addTearDown(accountA.dispose);
    addTearDown(restoredA.dispose);
    final unknown = <String>[];
    final credentials = <String?>[];
    final client = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path == '/api/certificates/purchase') {
        credentials.add(request.headers['authorization']);
        return request.headers['authorization'] == 'Bearer fixture-account-b'
            ? _json({'success': false, 'error': 'Оплата отклонена'},
                status: 400)
            : _json({'success': false, 'error': 'Ответ не получен'},
                status: 503);
      }
      unknown.add('${request.method} ${request.url}');
      throw StateError('Unexpected certificate request');
    });
    addTearDown(() => expect(unknown, isEmpty));
    await http.runWithClient(() async {
      await accountA.purchase();
      await AuthService.saveToken('fixture-account-b');
      await AuthService.bindAuthenticatedIdentity('certificate-account-b');
      final accountB = _draft();
      addTearDown(accountB.dispose);
      await accountB.purchase();
      expect(accountB.canPurchase, isTrue);
      await AuthService.saveToken('fixture-only');
      await AuthService.bindAuthenticatedIdentity('certificate-account-a');
      await restoredA.purchase();
    }, () => client);
    expect(credentials, ['Bearer fixture-only', 'Bearer fixture-account-b']);
    expect(restoredA.unconfirmed, isTrue);
    expect(restoredA.canPurchase, isFalse);
  });

  test('late purchase completion cannot expose another accounts certificate',
      () async {
    await AuthService.bindAuthenticatedIdentity('certificate-account-a');
    addTearDown(() => AuthService.bindAuthenticatedIdentity(null));
    final session = _draft();
    addTearDown(session.dispose);
    final response = Completer<http.Response>();
    final sent = Completer<void>();
    final unknown = <String>[];
    var charges = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path == '/api/certificates/purchase') {
        charges++;
        expect(request.headers['authorization'], 'Bearer fixture-only');
        if (!sent.isCompleted) sent.complete();
        return response.future;
      }
      unknown.add('${request.method} ${request.url}');
      throw StateError('Unexpected certificate request');
    });
    addTearDown(() => expect(unknown, isEmpty));
    await http.runWithClient(() async {
      final purchase = session.purchase();
      await sent.future;
      await AuthService.saveToken('fixture-account-b');
      await AuthService.bindAuthenticatedIdentity('certificate-account-b');
      response.complete(_json({
        'success': true,
        'data': {
          'purchase_id': 'account-a-purchase',
          'payment_status': 'completed',
          'certificate': {'code': 'PRIVATE-ACCOUNT-A-CODE'},
        },
      }));
      await purchase;
      expect(session.certificate, isNull);
      await session.purchase();
    }, () => client);
    expect(charges, 1);
  });
}
