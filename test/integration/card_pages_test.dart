import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/checkout/ui/payment_success_page.dart';
import 'package:naliv_delivery/features/orders/ui/orders_page.dart';
import 'package:naliv_delivery/model/cart_item.dart';
import 'package:naliv_delivery/pages/login_page.dart';
import 'package:naliv_delivery/pages/payment_method_page.dart';
import 'package:naliv_delivery/pages/profile_cards_page.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _response(Object? cards) => http.Response(
    jsonEncode({
      'success': true,
      'data': {'cards': cards},
    }),
    200,
    headers: {'content-type': 'application/json'});

Map<String, Object> _card(String id) =>
    {'id': id, 'mask': '**** **** **** 4444'};

Future<void> _pumpPage(
  WidgetTester tester,
  Widget page, {
  CartProvider? cart,
  bool settle = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(375, 812));
  final app = MaterialApp(
    theme: AppTheme.dark(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: const EdgeInsets.only(top: 48, bottom: 34),
      ),
      child: child!,
    ),
    home: page,
  );
  await tester.pumpWidget(cart == null
      ? app
      : ChangeNotifierProvider<CartProvider>.value(value: cart, child: app));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> _showControl(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    final scrollable = find.byType(Scrollable).first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pump();
    await tester.scrollUntilVisible(target, 200, scrollable: scrollable);
  }
  await Scrollable.ensureVisible(tester.element(target), alignment: .3);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() =>
      SharedPreferences.setMockInitialValues({'auth_token': 'fixture-only'}));

  testWidgets(
      'failed profile read is an error rather than an empty card book and retry recovers',
      (tester) async {
    var failed = true;
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/user/cards') {
        expect(request.url.queryParameters, {'source': 'halyk'});
        return failed
            ? http.Response('unavailable', 503)
            : _response([_card('server-a')]);
      }
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    });
    await http.runWithClient(() async {
      await _pumpPage(tester, const ProfileCardsPage());
      expect(find.text('Добавленных карт нет'), findsNothing);
      expect(find.text('Повторить'), findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('add-card-button')))
              .onPressed,
          isNotNull);
      failed = false;
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('saved-card-server-a')), findsOneWidget);
      expect(find.text('Повторить'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'opened provider stays pending until refresh proves a new identity, even at the same count',
      (tester) async {
    var cards = [_card('old')];
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/user/cards') {
        expect(request.url.queryParameters, {'source': 'halyk'});
        return _response(cards);
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/payments/generate-add-card-link') {
        return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'addCardLink': 'https://fixture-bank.example/card/attach'
              }
            }),
            200);
      }
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    });
    await http.runWithClient(() async {
      await _pumpPage(
          tester, ProfileCardsPage(openCardForm: (_) async => true));
      await tester.tap(find.byKey(const ValueKey('add-card-button')));
      await tester.pumpAndSettle();
      expect(
          find.text('Новая карта сохранена и готова к оплате'), findsNothing);
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('add-card-button')))
              .onPressed,
          isNull);
      await tester.tap(find.byKey(const ValueKey('refresh-card-list')));
      await tester.pumpAndSettle();
      expect(
          find.text('Новая карта сохранена и готова к оплате'), findsNothing);
      expect(find.byKey(const ValueKey('cancel-card-add')), findsOneWidget);
      cards = [_card('new')];
      await tester.tap(find.byKey(const ValueKey('refresh-card-list')));
      await tester.pumpAndSettle();
      expect(
          find.text('Новая карта сохранена и готова к оплате'), findsOneWidget);
      expect(find.byKey(const ValueKey('saved-card-new')), findsOneWidget);
      expect(find.byKey(const ValueKey('cancel-card-add')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'failed launch offers retry and opened-form cancellation restores adding without success',
      (tester) async {
    var opened = false;
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/user/cards') {
        expect(request.url.queryParameters, {'source': 'halyk'});
        return _response([_card('old')]);
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/payments/generate-add-card-link') {
        return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'addCardLink': 'https://fixture-bank.example/card/attach'
              }
            }),
            200);
      }
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    });
    await http.runWithClient(() async {
      await _pumpPage(
          tester, ProfileCardsPage(openCardForm: (_) async => opened));
      await tester.tap(find.byKey(const ValueKey('add-card-button')));
      await tester.pumpAndSettle();
      expect(find.text('Открыть форму снова'), findsOneWidget);
      expect(
          find.text('Новая карта сохранена и готова к оплате'), findsNothing);
      opened = true;
      await tester.tap(find.byKey(const ValueKey('add-card-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cancel-card-add')));
      await tester.pumpAndSettle();
      expect(find.text('Добавить новую карту'), findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('add-card-button')))
              .onPressed,
          isNotNull);
      expect(
          find.text('Новая карта сохранена и готова к оплате'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'payment read failure never selects a saved card, while explicit Kaspi remains supported',
      (tester) async {
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/user/cards') {
        return _response(null);
      }
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    });
    await http.runWithClient(() async {
      await _pumpPage(
          tester,
          const PaymentMethodPage(orderData: {
            'order_id': 'fixture-order',
            'payable_amount': 1200
          }));
      expect(find.text('Добавленных карт нет'), findsNothing);
      expect(find.text('Повторить'), findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('pay-order-button')))
              .onPressed,
          isNull);
      await tester.tap(find.byKey(const ValueKey('payment-kaspi')));
      await tester.pump();
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('pay-order-button')))
              .onPressed,
          isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    await tester.binding.setSurfaceSize(null);
  });
  testWidgets(
      'completed historical payment preserves the current cart and opens real order history',
      (tester) async {
    final cart = CartProvider();
    await cart.bindBusiness(1);
    cart.addItem(CartItem(
        itemId: 83,
        name: 'Другой товар',
        price: 1000,
        quantity: 2,
        stepQuantity: 1,
        selectedVariants: [],
        promotions: []));
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/user/cards') {
        return _response([_card('server-a')]);
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/orders/902/pay') {
        return http.Response(
            jsonEncode({
              'success': true,
              'data': {'payment_status': 'completed'}
            }),
            200);
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/orders/my-orders') {
        return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'orders': [
                  {
                    'order_id': 902,
                    'order_price': 1200,
                    'status': '0',
                    'payment_status': 'completed'
                  },
                ]
              }
            }),
            200);
      }
      if (request.method == 'GET' && request.url.path == '/api/bonuses') {
        return http.Response(jsonEncode({
          'success': true,
          'data': {'totalBonuses': 0, 'bonusHistory': <Object>[]},
        }), 200);
      }
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    });
    await http.runWithClient(() async {
      await _pumpPage(
          tester,
          const PaymentMethodPage(orderData: {
            'order_id': 902,
            'business_id': 1,
            'payable_amount': 1200,
          }),
          cart: cart);
      await _showControl(tester,
          find.byKey(const ValueKey('payment-card-server-a')));
      await tester.tap(find.byKey(const ValueKey('payment-card-server-a')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pay-order-button')));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<PaymentSuccessPage>(find.byType(PaymentSuccessPage))
              .orderId,
          '902');
      expect(cart.items.single.itemId, 83);
      expect(cart.items.single.quantity, 2);
      await tester.tap(find.byKey(const ValueKey('payment-success-orders')));
      await tester.pumpAndSettle();
      expect(find.byType(OrdersPage), findsOneWidget);
      expect(find.textContaining('902'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    cart.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'pending card payment cannot show success or submit another charge',
      (tester) async {
    var charges = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/user/cards') {
        return _response([_card('server-a')]);
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/orders/902/pay') {
        charges++;
        return http.Response(
            jsonEncode({
              'success': true,
              'data': {'payment_status': 'pending'}
            }),
            200);
      }
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    });
    await http.runWithClient(() async {
      await _pumpPage(
          tester,
          const PaymentMethodPage(orderData: {
            'order_id': 902,
            'business_id': 1,
            'payable_amount': 1200,
          }));
      await _showControl(tester,
          find.byKey(const ValueKey('payment-card-server-a')));
      await tester.tap(find.byKey(const ValueKey('payment-card-server-a')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pay-order-button')));
      await tester.pumpAndSettle();
      expect(find.byType(PaymentSuccessPage), findsNothing);
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('pay-order-button')))
              .onPressed,
          isNull);
      expect(
          find.byKey(const ValueKey('payment-pending-orders')), findsOneWidget);
      expect(charges, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'malformed charge acknowledgment locks resubmission instead of treating it as refusal',
      (tester) async {
    var charges = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/user/cards') {
        return _response([_card('server-a')]);
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/orders/902/pay') {
        charges++;
        return http.Response('{unreadable', 200);
      }
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    });
    await http.runWithClient(() async {
      await _pumpPage(
          tester,
          const PaymentMethodPage(orderData: {
            'order_id': 902,
            'business_id': 1,
            'payable_amount': 1200,
          }));
      await _showControl(tester,
          find.byKey(const ValueKey('payment-card-server-a')));
      await tester.tap(find.byKey(const ValueKey('payment-card-server-a')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pay-order-button')));
      await tester.pumpAndSettle();
      expect(find.byType(PaymentSuccessPage), findsNothing);
      expect(
          find.byKey(const ValueKey('payment-pending-orders')), findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('pay-order-button')))
              .onPressed,
          isNull);
      expect(charges, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'payment retains actual selected identity and disables it after a failed refresh',
      (tester) async {
    var failed = false;
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/user/cards') {
        return failed
            ? http.Response('unavailable', 503)
            : _response([
                {
                  'id': 'local-row',
                  'halyk_id': 'bank-a',
                  'card_mask': '**** **** **** 4444'
                },
                {'halyk_id': 'bank-b', 'card_mask': '**** **** **** 4949'},
              ]);
      }
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    });
    await http.runWithClient(() async {
      await _pumpPage(
          tester,
          const PaymentMethodPage(orderData: {
            'order_uuid': 'fixture-order',
            'total_amount': 1200
          }));
      final row = find.byKey(const ValueKey('payment-card-bank-b'));
      await _showControl(tester, row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pump();
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('pay-order-button')))
              .onPressed,
          isNotNull);
      failed = true;
      final refresh = find.byKey(const ValueKey('refresh-card-list'));
      await _showControl(tester, refresh);
      await tester.pumpAndSettle();
      await tester.tap(refresh);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('pay-order-button')))
              .onPressed,
          isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'profile and payment stalled reads expose retry and ignore late data',
      (tester) async {
    for (final profile in [true, false]) {
      final stalled = Completer<http.Response>();
      var reads = 0;
      final client = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/api/user/cards') {
          expect(request.url.queryParameters, {'source': 'halyk'});
          expect(request.headers['Authorization'], 'Bearer fixture-only');
          if (++reads == 1) return stalled.future;
          return _response([_card('retried')]);
        }
        throw StateError(
            'Unexpected request: ${request.method} ${request.url}');
      });
      await http.runWithClient(() async {
        await _pumpPage(
          tester,
          profile
              ? const ProfileCardsPage()
              : const PaymentMethodPage(orderData: {'order_id': 902}),
          settle: false,
        );
        await tester.pump(const Duration(seconds: 13));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('retry-card-read')), findsOneWidget);
        expect(find.text('Добавленных карт нет'), findsNothing);
        await tester
            .ensureVisible(find.byKey(const ValueKey('retry-card-read')));
        await tester.tap(find.byKey(const ValueKey('retry-card-read')));
        await tester.pumpAndSettle();
        final prefix = profile ? 'saved-card' : 'payment-card';
        expect(find.byKey(ValueKey('$prefix-retried')), findsOneWidget);
        stalled.complete(_response([_card('late')]));
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('$prefix-retried')), findsOneWidget);
        expect(find.byKey(ValueKey('$prefix-late')), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'authentication loss hides chargeable rows and offers explicit sign-in',
      (tester) async {
    for (final profile in [true, false]) {
      var unauthorized = false;
      var reads = 0;
      final client = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/api/user/cards') {
          reads++;
          return unauthorized
              ? http.Response('Unauthorized', 401)
              : _response([_card('existing')]);
        }
        throw StateError(
            'Unexpected request: ${request.method} ${request.url}');
      });
      await http.runWithClient(() async {
        await _pumpPage(
          tester,
          profile
              ? const ProfileCardsPage()
              : const PaymentMethodPage(orderData: {'order_id': 902}),
        );
        unauthorized = true;
        await _showControl(tester,
            find.byKey(const ValueKey('refresh-card-list')));
        await tester.tap(find.byKey(const ValueKey('refresh-card-list')));
        await tester.pumpAndSettle();
        final prefix = profile ? 'saved-card' : 'payment-card';
        expect(find.byKey(ValueKey('$prefix-existing')), findsNothing);
        expect(find.byKey(const ValueKey('card-sign-in')), findsOneWidget);
        if (profile) {
          expect(
            tester
                .widget<FilledButton>(
                    find.byKey(const ValueKey('add-card-button')))
                .onPressed,
            isNull,
          );
        } else {
          expect(
            tester
                .widget<FilledButton>(
                    find.byKey(const ValueKey('pay-order-button')))
                .onPressed,
            isNull,
          );
        }
        await tester.ensureVisible(find.byKey(const ValueKey('card-sign-in')));
        await tester.tap(find.byKey(const ValueKey('card-sign-in')));
        await tester.pumpAndSettle();
        expect(find.byType(LoginPage), findsOneWidget);
        expect(reads, 2);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('bank collection summaries display without becoming charge identities',
      (tester) async {
    final chargedIds = <String>[];
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/user/cards') {
        return _response([
          {
            'id': 'summary-row',
            'halyk_id': 'bank-safe',
            'card_mask': '****4444',
          },
          {'mask': '****1234'},
          {'id': 'pan', 'mask': '4111111111111111'},
        ]);
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/orders/902/pay') {
        chargedIds.add(jsonDecode(request.body)['card_id'] as String);
        return http.Response(jsonEncode({
          'success': false,
          'data': {'payment_status': 'failed'},
        }), 200);
      }
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    });
    await http.runWithClient(() async {
      await _pumpPage(tester, const ProfileCardsPage());
      expect(find.byKey(const ValueKey('saved-card-bank-safe')), findsOneWidget);
      expect(find.text('****1234'), findsOneWidget);
      expect(find.text('4111111111111111'), findsNothing);
      await _pumpPage(
          tester, const PaymentMethodPage(orderData: {
            'order_id': 902, 'payable_amount': 1200,
          }));
      expect(find.byKey(const ValueKey('card-read-partial')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('payment-card-bank-safe')),
        200,
      );
      expect(
          find.byKey(const ValueKey('payment-card-bank-safe')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('payment-card-summary-row')), findsNothing);
      expect(find.byKey(const ValueKey('payment-card-pan')), findsNothing);
      final summary = find.byKey(const ValueKey('payment-card-summary-1'));
      await _showControl(tester, summary);
      await tester.tap(summary);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pay-order-button')));
      await tester.pumpAndSettle();
      expect(chargedIds, ['bank-safe']);
      expect(find.text('4111111111111111'), findsNothing);
      await tester.tap(find.text('Понятно'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('resume refreshes a loaded bank collection without claiming binding success',
      (tester) async {
    var cards = <Object?>[
      {'halyk_id': 'bank-existing', 'card_mask': '****4444'},
      {'halyk_id': 'bank-existing', 'card_mask': null},
    ];
    var reads = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/user/cards') {
        reads++;
        return _response(cards);
      }
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    });
    await http.runWithClient(() async {
      await _pumpPage(tester, const ProfileCardsPage());
      expect(find.byKey(const ValueKey('saved-card-bank-existing')), findsOneWidget);
      cards = [
        {'halyk_id': 'bank-existing', 'card_mask': '****4949'},
        {'halyk_id': 'bank-refreshed', 'card_mask': '****1234'},
      ];
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(find.text('****4949'), findsOneWidget);
      expect(find.byKey(const ValueKey('saved-card-bank-refreshed')), findsOneWidget);
      expect(find.text('Новая карта сохранена и готова к оплате'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('primary payable amount prefers server summary over echoed total',
      (tester) async {
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/user/cards') {
        return _response(<Object>[]);
      }
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    });
    await http.runWithClient(() async {
      await _pumpPage(tester, const PaymentMethodPage(
        orderData: {
          'order_id': 'server-summary',
          'total_amount': 26340,
          'cost_summary': {'total_sum': 26370.25},
        },
        displayAmount: 26340,
        amountNotice: 'Сервер подтвердил другую сумму: 26 370,25 ₸',
      ));
      expect(find.text('26\u00a0370,25 ₸'), findsOneWidget);
      expect(find.text('26\u00a0340 ₸'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpPage(tester, const PaymentMethodPage(orderData: {
        'order_id': 'explicit-server-total',
        'payable_amount': 27000.5,
        'total_amount': 26340,
        'cost_summary': {'total_sum': 26370.25},
      }));
      expect(find.text('27\u00a0000,5 ₸'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('stalled bank preparation exposes retry without duplicate launch',
      (tester) async {
    final stalled = Completer<http.Response>();
    var links = 0;
    var launches = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/user/cards') {
        return _response([_card('existing')]);
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/payments/generate-add-card-link') {
        if (++links == 1) return stalled.future;
        return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'addCardLink': 'https://fixture-bank.example/card/attach'
              },
            }),
            200);
      }
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    });
    await http.runWithClient(() async {
      await _pumpPage(tester, ProfileCardsPage(openCardForm: (_) async {
        launches++;
        return true;
      }));
      await tester.tap(find.byKey(const ValueKey('add-card-button')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 13));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('retry-card-add')), findsOneWidget);
      expect(launches, 0);
      await tester.ensureVisible(find.byKey(const ValueKey('retry-card-add')));
      await tester.tap(find.byKey(const ValueKey('retry-card-add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cancel-card-add')), findsOneWidget);
      expect(links, 2);
      expect(launches, 1);
      stalled.complete(http.Response(
          jsonEncode({
            'success': true,
            'data': {'addCardLink': 'https://fixture-bank.example/card/late'},
          }),
          200));
      await tester.pumpAndSettle();
      expect(launches, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    await tester.binding.setSurfaceSize(null);
  });
}
