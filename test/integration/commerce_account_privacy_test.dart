import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/certificates/ui/certificates_page.dart';
import 'package:naliv_delivery/features/orders/ui/orders_page.dart';
import 'package:naliv_delivery/pages/order_detail_page.dart';
import 'package:naliv_delivery/pages/payment_method_page.dart';
import 'package:naliv_delivery/pages/profile_cards_page.dart';
import 'package:naliv_delivery/services/auth_service.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _Consumer { orders, orderDetail, certificates, profileCards, payment }

const _privateAddress = 'PRIVATE-ACCOUNT-A-ADDRESS';
const _privateCertificate = 'PRIVATE-ACCOUNT-A-CERTIFICATE';
const _order = <String, dynamic>{
  'order_id': 45,
  'business_id': 1,
  'delivery_type': 'DELIVERY',
  'payable_amount': 1234.5,
  'log_timestamp': '2026-10-01T12:00:00+05:00',
  'payment_confirmed': false,
  'current_status': {'status': '1'},
  'delivery_address': {
    'address': _privateAddress,
    'street': 'Тестовая',
    'house': '16',
    'lat': 49.8,
    'lon': 73.1,
  },
  'items': <Object>[],
};

http.Response _json(Object value, [int status = 200]) => http.Response(
      jsonEncode(value),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

class _Fixture {
  _Fixture(this.consumer, {this.deferOldResponse = false});

  final _Consumer consumer;
  final bool deferOldResponse;
  final oldResponse = Completer<http.Response>();
  final unknown = <String>[];
  int oldAccountReads = 0;
  int newAccountReads = 0;

  http.Response get privateResponse => switch (consumer) {
        _Consumer.orders => _json({
            'success': true,
            'data': {
              'orders': [_order]
            },
          }),
        _Consumer.orderDetail => _json({
            'success': true,
            'data': {'order': _order},
          }),
        _Consumer.certificates => _json({
            'success': true,
            'data': {
              'certificates': [
                {'code': _privateCertificate, 'balance': 10000},
              ],
            },
          }),
        _Consumer.profileCards || _Consumer.payment => _json({
            'success': true,
            'data': {
              'cards': [
                {
                  'halyk_id': 'private-account-a-card',
                  'card_mask': '**** **** **** 4444',
                },
              ],
            },
          }),
      };

  late final client = MockClient((request) async {
    final authorization = request.headers['authorization'];
    if (request.method != 'GET' ||
        (authorization != 'Bearer fixture-account-a' &&
            authorization != 'Bearer fixture-account-b')) {
      unknown.add('${request.method} ${request.url} $authorization');
      throw StateError('Unexpected private commerce request');
    }
    final expectedPath = switch (consumer) {
      _Consumer.orders => '/api/orders/my-orders',
      _Consumer.orderDetail => '/api/orders/45',
      _Consumer.certificates => '/api/certificates',
      _Consumer.profileCards || _Consumer.payment => '/api/user/cards',
    };
    if (request.url.path == '/api/bonuses' &&
        consumer != _Consumer.certificates) {
      return authorization == 'Bearer fixture-account-a'
          ? _json({
              'success': true,
              'data': {'totalBonuses': 0, 'bonusHistory': <Object>[]},
            })
          : _json({'success': false, 'error': 'Fixture unavailable'}, 503);
    }
    if (request.url.path != expectedPath) {
      unknown.add('${request.method} ${request.url}');
      throw StateError('Unexpected private commerce endpoint');
    }
    final expectedQuery = switch (consumer) {
      _Consumer.orders => {'page': '1'},
      _Consumer.orderDetail => <String, String>{},
      _Consumer.certificates => {
          'status': 'active',
          'limit': '50',
          'offset': '0',
        },
      _Consumer.profileCards || _Consumer.payment => {'source': 'halyk'},
    };
    expectSync(request.url.queryParameters, expectedQuery);
    if (authorization == 'Bearer fixture-account-b') {
      newAccountReads++;
      return _json({'success': false, 'error': 'Fixture unavailable'}, 503);
    }
    oldAccountReads++;
    return deferOldResponse ? oldResponse.future : privateResponse;
  });

  Finder get privateContent => switch (consumer) {
        _Consumer.orders => find.text('№45'),
        _Consumer.orderDetail => find.text(_privateAddress),
        _Consumer.certificates => find.text(_privateCertificate),
        _Consumer.profileCards =>
          find.byKey(const ValueKey('saved-card-private-account-a-card')),
        _Consumer.payment =>
          find.byKey(const ValueKey('payment-card-private-account-a-card')),
      };
}

Future<void> _pump(WidgetTester tester, _Fixture fixture,
    {bool settle = true}) async {
  await tester.binding.setSurfaceSize(const Size(600, 1000));
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => CartProvider()),
      ChangeNotifierProvider(create: (_) => BusinessProvider()),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: switch (fixture.consumer) {
        _Consumer.orders => const OrdersPage(),
        _Consumer.orderDetail => const OrderDetailPage(order: _order),
        _Consumer.certificates => const CertificatesPage(),
        _Consumer.profileCards => const ProfileCardsPage(),
        _Consumer.payment => const PaymentMethodPage(orderData: {
            'order_id': 45,
            'business_id': 1,
            'payable_amount': 1234.5,
            'current_status': {'status': '60'},
          }),
      },
    ),
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }
}

Future<void> _switchAccount() async {
  await AuthService.saveToken('fixture-account-b');
  await AuthService.bindAuthenticatedIdentity('commerce-account-b');
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auth_token': 'fixture-account-a'});
    await AuthService.notifySessionChanged();
    await AuthService.bindAuthenticatedIdentity('commerce-account-a');
    await initializeDateFormatting('ru');
  });

  tearDown(() => AuthService.bindAuthenticatedIdentity(null));

  for (final consumer in _Consumer.values) {
    testWidgets(
        '${consumer.name} clears cached account A data when account B refresh fails',
        (tester) async {
      final fixture = _Fixture(consumer);
      addTearDown(() => expect(fixture.unknown, isEmpty));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.binding.setSurfaceSize(null);
      });
      await http.runWithClient(() async {
        await _pump(tester, fixture);
        expect(fixture.privateContent, findsOneWidget);
        await _switchAccount();
        await tester.pumpAndSettle();
        expect(fixture.privateContent, findsNothing);
        if (consumer == _Consumer.payment) {
          expect(find.byKey(const ValueKey('payment-payable-amount')),
              findsNothing);
          final pay = find.byKey(const ValueKey('pay-order-button'));
          if (pay.evaluate().isNotEmpty) {
            expect(tester.widget<FilledButton>(pay).onPressed, isNull);
          }
        }
        expect(fixture.newAccountReads, greaterThanOrEqualTo(1));
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => fixture.client);
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets(
        '${consumer.name} rejects late account A response after account B read failure',
        (tester) async {
      final fixture = _Fixture(consumer, deferOldResponse: true);
      addTearDown(() => expect(fixture.unknown, isEmpty));
      addTearDown(() async {
        if (!fixture.oldResponse.isCompleted) {
          fixture.oldResponse.complete(fixture.privateResponse);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.binding.setSurfaceSize(null);
      });
      await http.runWithClient(() async {
        await _pump(tester, fixture, settle: false);
        expect(fixture.oldAccountReads, 1);
        await _switchAccount();
        await tester.pump();
        await tester.pump();
        fixture.oldResponse.complete(fixture.privateResponse);
        await tester.pumpAndSettle();
        expect(fixture.privateContent, findsNothing);
        if (consumer == _Consumer.payment) {
          expect(find.byKey(const ValueKey('payment-payable-amount')),
              findsNothing);
        }
        expect(fixture.newAccountReads, greaterThanOrEqualTo(1));
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => fixture.client);
      await tester.binding.setSurfaceSize(null);
    });
  }
}
