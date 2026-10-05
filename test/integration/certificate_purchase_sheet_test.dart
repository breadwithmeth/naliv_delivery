import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/certificates/ui/certificates_page.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, {int status = 200}) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

http.Response _cards(List<Map<String, Object>> cards) => _json({
      'success': true,
      'data': {'cards': cards}
    });

Map<String, Object> _card(String id) =>
    {'halyk_id': id, 'card_mask': '**** **** **** 4444'};

Future<void> _pump(
  WidgetTester tester, {
  Future<bool> Function(Uri)? openCardForm,
}) async {
  await tester.binding.setSurfaceSize(const Size(375, 812));
  await tester.pumpWidget(ChangeNotifierProvider(
    create: (_) => CartProvider(),
    child: MaterialApp(
      theme: AppTheme.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(top: 48, bottom: 34),
        ),
        child: child!,
      ),
      home: CertificatesPage(openCardForm: openCardForm),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('certificate-buy')));
  await tester.tap(find.byKey(const ValueKey('certificate-buy')));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

bool _canPurchase(WidgetTester tester) =>
    tester
        .widget<FilledButton>(
            find.byKey(const ValueKey('certificate-purchase-submit')))
        .onPressed !=
    null;

void main() {
  setUp(() =>
      SharedPreferences.setMockInitialValues({'auth_token': 'fixture-only'}));

  testWidgets(
      'failed cards read disables purchase and retry recovers real selection',
      (tester) async {
    var failRead = true;
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/certificates') {
        return _json({
          'success': true,
          'data': {'certificates': []}
        });
      }
      if (request.method == 'GET' && request.url.path == '/api/user/cards') {
        expect(request.url.queryParameters, {'source': 'halyk'});
        return failRead
            ? http.Response('unavailable', 503)
            : _cards([_card('server-card')]);
      }
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    });
    await http.runWithClient(() async {
      await _pump(tester);
      expect(find.byKey(const ValueKey('certificate-cards-error')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('certificate-cards-empty')), findsNothing);
      expect(_canPurchase(tester), isFalse);
      expect(
        tester
            .widget<TextButton>(
                find.byKey(const ValueKey('certificate-add-card')))
            .onPressed,
        isNotNull,
      );
      failRead = false;
      await _tap(tester, 'certificate-refresh-cards');
      expect(find.byKey(const ValueKey('certificate-card-server-card')),
          findsOneWidget);
      expect(_canPurchase(tester), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'cancelled binding cannot create a payable card, server refresh can',
      (tester) async {
    var cards = <Map<String, Object>>[];
    var hostedLaunches = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/certificates') {
        return _json({
          'success': true,
          'data': {'certificates': []}
        });
      }
      if (request.method == 'GET' && request.url.path == '/api/user/cards') {
        return _cards(cards);
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/payments/generate-add-card-link') {
        return _json({
          'success': true,
          'data': {'addCardLink': 'https://fixture-bank.example/attach'}
        });
      }
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    });
    await http.runWithClient(() async {
      await _pump(tester, openCardForm: (uri) async {
        hostedLaunches++;
        expect(uri.host, 'fixture-bank.example');
        return true;
      });
      expect(_canPurchase(tester), isFalse);
      await _tap(tester, 'certificate-add-card');
      expect(hostedLaunches, 1);
      expect(_canPurchase(tester), isFalse);
      await _tap(tester, 'refresh-card-list');
      expect(_canPurchase(tester), isFalse);
      await _tap(tester, 'cancel-card-add');
      expect(_canPurchase(tester), isFalse);
      expect(find.byKey(const ValueKey('certificate-card-server-new')),
          findsNothing);
      cards = [_card('server-new')];
      await _tap(tester, 'certificate-refresh-cards');
      expect(find.byKey(const ValueKey('certificate-card-server-new')),
          findsOneWidget);
      expect(_canPurchase(tester), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'pending reopen and status failure retain identity without charging again',
      (tester) async {
    var charges = 0;
    var statusReads = 0;
    var issued = false;
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/certificates') {
        return _json({
          'success': true,
          'data': {
            'certificates': issued
                ? [
                    {'code': 'REAL-ISSUED-CODE', 'balance': 7777.25}
                  ]
                : []
          }
        });
      }
      if (request.method == 'GET' && request.url.path == '/api/user/cards') {
        return _cards([_card('server-payable')]);
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/certificates/purchase') {
        charges++;
        expect(jsonDecode(request.body), {
          'amount': 7777.25,
          'payment_type': 'card',
          'halyk_card_id': 'server-payable',
          'recipient_login': '77010000000',
          'message': 'Подарок',
        });
        return _json({
          'success': true,
          'data': {
            'purchase_id': 'purchase-kept',
            'payment_status': 'pending',
            'certificate': {'code': 'DO-NOT-ISSUE-PENDING'},
          }
        });
      }
      if (request.method == 'GET' &&
          request.url.path ==
              '/api/certificates/purchases/purchase-kept/status') {
        statusReads++;
        if (statusReads == 1) {
          return _json({'success': false, 'error': 'Проверка недоступна'},
              status: 503);
        }
        issued = true;
        return _json({
          'success': true,
          'data': {
            'payment_status': 'completed',
            'certificate': {'code': 'REAL-ISSUED-CODE'}
          }
        });
      }
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    });
    await http.runWithClient(() async {
      await _pump(tester);
      await tester.enterText(
          find.byKey(const ValueKey('certificate-purchase-amount')), '7777,25');
      await tester.enterText(
          find.byKey(const ValueKey('certificate-purchase-recipient')),
          '77010000000');
      await tester.enterText(
          find.byKey(const ValueKey('certificate-purchase-message')),
          'Подарок');
      await _tap(tester, 'certificate-purchase-submit');
      expect(find.byKey(const ValueKey('certificate-purchase-pending')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('certificate-issued-code')), findsNothing);
      await _tap(tester, 'certificate-purchase-close');
      await _tap(tester, 'certificate-buy');
      expect(
          tester
              .widget<TextField>(
                  find.byKey(const ValueKey('certificate-purchase-amount')))
              .controller!
              .text,
          '7777,25');
      expect(find.byKey(const ValueKey('certificate-purchase-submit')),
          findsNothing);
      await _tap(tester, 'certificate-refresh-status');
      expect(find.byKey(const ValueKey('certificate-purchase-pending')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('certificate-issued-code')), findsNothing);
      await _tap(tester, 'certificate-refresh-status');
      expect(find.byKey(const ValueKey('certificate-issued-code')),
          findsOneWidget);
      expect(find.text('REAL-ISSUED-CODE'), findsOneWidget);
      await _tap(tester, 'certificate-purchase-done');
      expect(
          find.byKey(const ValueKey('certificate-issued-code')), findsNothing);
      expect(find.text('REAL-ISSUED-CODE'), findsOneWidget);
      expect(charges, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'partial card data never offers a summary row or raw PAN for purchase',
      (tester) async {
    var includeValid = true;
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/certificates') {
        return _json({
          'success': true,
          'data': {'certificates': []},
        });
      }
      if (request.method == 'GET' && request.url.path == '/api/user/cards') {
        return _json({
          'success': true,
          'data': {
            'cards': [
              if (includeValid)
                {
                  'id': 'summary-row',
                  'halyk_id': 'bank-payable',
                  'card_mask': '****4444',
                },
              {'mask': '****1234'},
              {'halyk_id': 'unsafe', 'card_mask': '4111111111111111'},
            ],
          },
        });
      }
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    });
    await http.runWithClient(() async {
      await _pump(tester);
      expect(find.byKey(const ValueKey('certificate-cards-partial')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('certificate-card-bank-payable')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('certificate-card-summary-row')),
          findsNothing);
      expect(
          find.byKey(const ValueKey('certificate-card-unsafe')), findsNothing);
      expect(_canPurchase(tester), isTrue);
      includeValid = false;
      await _tap(tester, 'certificate-refresh-cards');
      expect(find.byKey(const ValueKey('certificate-cards-partial')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('certificate-cards-empty')), findsNothing);
      expect(_canPurchase(tester), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('card authentication loss disables purchase and offers sign-in',
      (tester) async {
    var unauthorized = false;
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/certificates') {
        return _json({
          'success': true,
          'data': {'certificates': []},
        });
      }
      if (request.method == 'GET' && request.url.path == '/api/user/cards') {
        return unauthorized
            ? http.Response('Unauthorized', 401)
            : _cards([_card('existing')]);
      }
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    });
    await http.runWithClient(() async {
      await _pump(tester);
      expect(_canPurchase(tester), isTrue);
      unauthorized = true;
      await _tap(tester, 'certificate-refresh-cards');
      expect(find.byKey(const ValueKey('certificate-card-existing')),
          findsNothing);
      expect(find.byKey(const ValueKey('card-sign-in')), findsOneWidget);
      expect(_canPurchase(tester), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    await tester.binding.setSurfaceSize(null);
  });
}
