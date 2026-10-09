import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/checkout/ui/payment_success_page.dart';
import 'package:naliv_delivery/features/orders/ui/orders_page.dart';
import 'package:naliv_delivery/model/cart_item.dart';
import 'package:naliv_delivery/pages/order_detail_page.dart';
import 'package:naliv_delivery/pages/payment_method_page.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/order_payment_guard.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _PaymentStore extends InMemorySharedPreferencesStore {
  _PaymentStore() : super.withData({'flutter.auth_token': 'fixture-only'});

  bool rejectPaymentWrites = false;
  Completer<Map<String, Object>>? heldRead;

  void install() {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = this;
  }

  @override
  Future<Map<String, Object>> getAll() async =>
      heldRead == null ? super.getAll() : heldRead!.future;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (rejectPaymentWrites && key.startsWith('flutter.order_payment_guard.')) {
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}

const _draft = <String, dynamic>{
  'order_id': 1101,
  'business_id': 1,
  'payable_amount': 1200,
  'current_status': {'status': '60'},
};

http.Response _json(Object value) => http.Response(jsonEncode(value), 200,
    headers: {'content-type': 'application/json'});

Future<CartProvider> _cart() async {
  final cart = CartProvider();
  await cart.bindBusiness(1);
  cart.addItem(CartItem(
    itemId: 83,
    name: 'Другой товар',
    price: 1000,
    quantity: 2,
    stepQuantity: 1,
    selectedVariants: [],
    promotions: [],
  ));
  return cart;
}

Future<void> _pump(WidgetTester tester, CartProvider cart,
    {bool settle = true, Map<String, dynamic> orderData = _draft}) async {
  await tester.binding.setSurfaceSize(const Size(375, 812));
  await tester.pumpWidget(ChangeNotifierProvider<CartProvider>.value(
    value: cart,
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: PaymentMethodPage(orderData: Map<String, dynamic>.from(orderData)),
    ),
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

VoidCallback? _payAction(WidgetTester tester) {
  final action = find.byKey(const ValueKey('pay-order-button'));
  return action.evaluate().isEmpty
      ? null
      : tester.widget<FilledButton>(action).onPressed;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'auth_token': 'fixture-only'});
  });

  for (final acknowledgment in ['pending', 'unreadable']) {
    testWidgets(
        '$acknowledgment recovery cannot pay through history or a new route after reload',
        (tester) async {
      var posts = 0;
      final cart = await _cart();
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer fixture-only');
        if (request.method == 'GET' && request.url.path == '/api/user/cards') {
          return _json({
            'success': true,
            'data': {
              'cards': [
                {'id': 'saved-card', 'mask': '**** **** **** 4444'},
              ]
            }
          });
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/orders/1101/pay') {
          posts++;
          return acknowledgment == 'pending'
              ? _json({
                  'success': true,
                  'data': {'payment_status': 'pending'}
                })
              : http.Response('{unreadable', 200);
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/orders/my-orders') {
          return _json({
            'success': true,
            'data': {
              'orders': [_draft]
            }
          });
        }
        if (request.method == 'GET' && request.url.path == '/api/orders/1101') {
          return _json({
            'success': true,
            'data': {'order': _draft}
          });
        }
        if (request.method == 'GET' && request.url.path == '/api/bonuses') {
          return _json({
            'success': true,
            'data': {'totalBonuses': 0, 'bonusHistory': <Object>[]},
          });
        }
        throw StateError('Unexpected fixture request: $request');
      });
      await http.runWithClient(() async {
        await _pump(tester, cart);
        expect(_payAction(tester), isNotNull);
        await tester.tap(find.byKey(const ValueKey('pay-order-button')));
        await tester.pumpAndSettle();
        expect(_payAction(tester), isNull);
        expect(find.byType(PaymentSuccessPage), findsNothing);
        await tester.tap(find.byKey(const ValueKey('payment-pending-orders')));
        await tester.pumpAndSettle();
        expect(find.byType(OrdersPage), findsOneWidget);
        await tester.tap(find.textContaining('1101'));
        await tester.pumpAndSettle();
        expect(find.byType(OrderDetailPage), findsOneWidget);
        expect(find.byKey(const ValueKey('order-detail-pay-button')),
            findsNothing);
        expect(find.byKey(const ValueKey('order-detail-repeat-button')),
            findsNothing);
        await tester
            .tap(find.byKey(const ValueKey('order-detail-check-payment')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('order-detail-repeat-button')),
            findsNothing);
        expect(cart.items.single.itemId, 83);
        expect(cart.items.single.quantity, 2);
        final route =
            tester.state<NavigatorState>(find.byType(Navigator).first);
        route.pop();
        await tester.pumpAndSettle();
        route.pop();
        await tester.pumpAndSettle();
        expect(_payAction(tester), isNull);
        // Discard every route/state object and the preferences cache, retaining
        // only device storage, as on application reopening.
        await tester.pumpWidget(const SizedBox.shrink());
        SharedPreferences.resetStatic();
        await _pump(tester, cart);
        expect(_payAction(tester), isNull);
        expect(find.byKey(const ValueKey('payment-pending-orders')),
            findsOneWidget);
        final duplicate = await ApiService.payOrder('1101', 'saved-card');
        expect(duplicate['requestSent'], isFalse);
        expect(posts, 1);
        expect(cart.items.single.itemId, 83);
        expect(cart.items.single.quantity, 2);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
      cart.dispose();
      await tester.binding.setSurfaceSize(null);
    });
  }

  testWidgets(
      'restored completion never enables another payment or invents a new success',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'fixture-only',
      OrderPaymentGuard.preferenceKey('1101'): 'completed',
    });
    final cart = await _cart();
    var posts = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/user/cards') {
        return _json({
          'success': true,
          'data': {
            'cards': [
              {'id': 'saved-card', 'mask': '**** **** **** 4444'},
            ]
          }
        });
      }
      posts++;
      throw StateError('Restored completion must not pay again: $request');
    });
    await http.runWithClient(() async {
      await _pump(tester, cart);
      expect(await OrderPaymentGuard.read('1101'), OrderPaymentState.completed);
      expect(_payAction(tester), isNull);
      expect(find.byType(PaymentSuccessPage), findsNothing);
      expect((await ApiService.payOrder('1101', 'saved-card'))['requestSent'],
          isFalse);
      expect(posts, 0);
      expect(cart.items.single.itemId, 83);
      expect(cart.items.single.quantity, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    cart.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'pay remains disabled with loaded cards until the durable guard is read',
      (tester) async {
    final store = _PaymentStore();
    store.install();
    final cart = await _cart();
    await SharedPreferences.getInstance();
    final stored = await store.getAll();
    final held = Completer<Map<String, Object>>();
    store.heldRead = held;
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/user/cards') {
        return _json({
          'success': true,
          'data': {
            'cards': [
              {'id': 'saved-card', 'mask': '**** **** **** 4444'},
            ]
          }
        });
      }
      throw StateError('Unexpected fixture request: $request');
    });
    await http.runWithClient(() async {
      await _pump(tester, cart, settle: false);
      await tester.pump();
      expect(find.byKey(const ValueKey('payment-card-saved-card')),
          findsOneWidget);
      expect(_payAction(tester), isNull);
      store.heldRead = null;
      held.complete(stored);
      await tester.pumpAndSettle();
      expect(_payAction(tester), isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    cart.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'failed durable reservation retains the order draft and unrelated cart without success',
      (tester) async {
    final store = _PaymentStore()..rejectPaymentWrites = true;
    store.install();
    final cart = await _cart();
    var posts = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/user/cards') {
        return _json({
          'success': true,
          'data': {
            'cards': [
              {'id': 'saved-card', 'mask': '**** **** **** 4444'},
            ]
          }
        });
      }
      posts++;
      throw StateError('Storage failure must not send payment: $request');
    });
    await http.runWithClient(() async {
      await _pump(tester, cart);
      final draftBefore = jsonDecode(jsonEncode(tester
          .widget<PaymentMethodPage>(find.byType(PaymentMethodPage))
          .orderData));
      final cartBefore = cart.items.single.toJson();
      await tester.tap(find.byKey(const ValueKey('pay-order-button')));
      await tester.pumpAndSettle();
      expect(posts, 0);
      expect(find.byType(PaymentSuccessPage), findsNothing);
      expect(_payAction(tester), isNull);
      expect(
          tester
              .widget<PaymentMethodPage>(find.byType(PaymentMethodPage))
              .orderData,
          draftBefore);
      expect(cart.items.single.toJson(), cartBefore);
      expect(await OrderPaymentGuard.read('1101'), OrderPaymentState.ready);
      // Restored storage enables only an explicit retry, not automatic sending.
      store.rejectPaymentWrites = false;
      await tester.tap(find.byKey(const ValueKey('payment-state-refresh')));
      await tester.pumpAndSettle();
      expect(_payAction(tester), isNotNull);
      expect(posts, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    cart.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  for (final outcome in ['pending', 'unreadable', 'completed', 'refused']) {
    testWidgets(
        'Kaspi link $outcome stays server-confirmed and cannot duplicate an unresolved charge',
        (tester) async {
      final orderId = {
        'pending': 'kaspi-pending',
        'unreadable': 'kaspi-unreadable',
        'completed': 'kaspi-completed',
        'refused': 'kaspi-refused',
      }[outcome]!;
      final draft = {..._draft, 'order_id': orderId};
      final cart = await _cart();
      var creates = 0;
      var statusReads = 0;
      final heldStatus = Completer<http.Response>();
      final launches = <MethodCall>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        if (call.method != 'canLaunch' && call.method != 'launch') {
          throw StateError('Unexpected bank operation: ${call.method}');
        }
        expect(
            call.arguments['url'], 'https://fixture-bank.example/pay/$orderId');
        if (call.method == 'launch') launches.add(call);
        return true;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer fixture-only');
        if (request.method == 'GET' && request.url.path == '/api/user/cards') {
          return _json({
            'success': true,
            'data': {
              'cards': [
                {'id': 'saved-card', 'mask': '**** **** **** 4444'},
              ]
            }
          });
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/orders/$orderId/kaspi-qr/pay') {
          creates++;
          expect(jsonDecode(request.body), {'method': 'link'});
          return _json({
            'success': true,
            'data': {
              'paymentLink': 'https://fixture-bank.example/pay/$orderId',
              'behaviorOptions': {
                'StatusPollingInterval': 2,
                'PaymentConfirmationTimeout': 2,
              },
            },
          });
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/orders/$orderId/kaspi-qr/status') {
          statusReads++;
          return heldStatus.future;
        }
        throw StateError('Unexpected fixture request: $request');
      });
      await http.runWithClient(() async {
        await _pump(tester, cart, orderData: draft);
        await tester.tap(find.byKey(const ValueKey('payment-kaspi')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('pay-order-button')));
        await tester.pump();
        await tester.pump();
        expect(_payAction(tester), isNull);
        expect(find.byType(PaymentSuccessPage), findsNothing);
        expect(
            tester
                .widget<InkWell>(find.byKey(const ValueKey('payment-kaspi')))
                .onTap,
            isNull);
        await tester.pump(const Duration(seconds: 2));
        expect(statusReads, 1);
        expect(launches.single.arguments['useWebView'], isFalse);
        expect(launches.single.arguments['useSafariVC'], isFalse);
        heldStatus.complete(outcome == 'unreadable'
            ? http.Response('{unreadable', 200)
            : _json({
                'success': true,
                'data': {
                  'payment_status': outcome == 'refused' ? 'failed' : outcome,
                },
              }));
        await tester.pumpAndSettle();
        if (outcome == 'completed') {
          expect(find.byType(PaymentSuccessPage), findsOneWidget);
          expect(await OrderPaymentGuard.read(orderId),
              OrderPaymentState.completed);
        } else {
          expect(find.byType(PaymentSuccessPage), findsNothing);
          await tester.tap(find.text('Понятно'));
          await tester.pumpAndSettle();
          expect(
              await OrderPaymentGuard.read(orderId),
              outcome == 'refused'
                  ? OrderPaymentState.ready
                  : OrderPaymentState.unconfirmed);
          expect(_payAction(tester), outcome == 'refused' ? isNotNull : isNull);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        SharedPreferences.resetStatic();
        await _pump(tester, cart, orderData: draft);
        expect(_payAction(tester), outcome == 'refused' ? isNotNull : isNull);
        expect(creates, 1);
        expect(launches, hasLength(1));
        expect(find.byType(PaymentSuccessPage), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
      cart.dispose();
      await tester.binding.setSurfaceSize(null);
    });
  }

  testWidgets('failed bank opening reopens the accepted link after reload without another pay',
      (tester) async {
    const orderId = 'kaspi-reopen-same';
    const link = 'https://fixture-bank.example/pay/accepted-attempt';
    final cart = await _cart();
    var creates = 0;
    var completed = false;
    final openedLinks = <String>[];
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'canLaunch') return false;
      if (call.method != 'launch') {
        throw StateError('Unexpected bank operation: ${call.method}');
      }
      openedLinks.add(call.arguments['url'] as String);
      return openedLinks.length > 1;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/user/cards') {
        return _json({
          'success': true,
          'data': {'cards': <Object>[]},
        });
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/orders/$orderId/kaspi-qr/pay') {
        creates++;
        return _json({
          'success': true,
          'data': {'paymentLink': link},
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/orders/$orderId/kaspi-qr/status') {
        return _json({
          'success': true,
          'data': {'payment_status': completed ? 'completed' : 'pending'},
        });
      }
      throw StateError('Unexpected fixture request: $request');
    });
    await http.runWithClient(() async {
      final draft = {..._draft, 'order_id': orderId};
      await _pump(tester, cart, orderData: draft);
      await tester.tap(find.byKey(const ValueKey('pay-order-button')));
      await tester.pumpAndSettle();
      expect(find.byType(PaymentSuccessPage), findsNothing);
      expect(await OrderPaymentGuard.readKaspiLink(orderId), link);
      await tester.tap(find.text('Понятно'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reopen-kaspi-payment')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      SharedPreferences.resetStatic();
      await _pump(tester, cart, orderData: draft);
      expect(_payAction(tester), isNull);
      await tester.tap(find.byKey(const ValueKey('reopen-kaspi-payment')));
      await tester.pumpAndSettle();
      expect(openedLinks, [link, link]);
      expect(creates, 1);
      expect(find.byType(PaymentSuccessPage), findsNothing);
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(_payAction(tester), isNull);
      expect(await OrderPaymentGuard.read(orderId), OrderPaymentState.unconfirmed);
      completed = true;
      await tester.ensureVisible(find.byKey(const ValueKey('payment-state-refresh')));
      await tester.tap(find.byKey(const ValueKey('payment-state-refresh')));
      await tester.pumpAndSettle();
      expect(find.byType(PaymentSuccessPage), findsOneWidget);
      expect(await OrderPaymentGuard.readKaspiLink(orderId), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      SharedPreferences.resetStatic();
      await _pump(tester, cart, orderData: draft);
      expect(find.byType(PaymentSuccessPage), findsNothing);
      expect(find.byKey(const ValueKey('reopen-kaspi-payment')), findsNothing);
      expect(_payAction(tester), isNull);
      expect(creates, 1);
      expect(openedLinks, [link, link]);
      expect(cart.items.single.itemId, 83);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    cart.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  for (final responseKind in ['network', 'malformed', 'server-unavailable', 'refused']) {
    testWidgets('Kaspi $responseKind creation preserves the genuine retry boundary',
        (tester) async {
      final orderId = 'kaspi-create-$responseKind-boundary';
      final cart = await _cart();
      var creates = 0;
      final client = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/api/user/cards') {
          return _json({
            'success': true,
            'data': {'cards': <Object>[]},
          });
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/orders/$orderId/kaspi-qr/pay') {
          creates++;
          if (responseKind == 'network') {
            throw http.ClientException('Fixture connection dropped');
          }
          if (responseKind == 'malformed') return http.Response('{unreadable', 200);
          return http.Response(jsonEncode({
            'success': false,
            'error': 'Fixture refusal',
            'data': {'payment_status': 'failed'},
          }), responseKind == 'refused' ? 400 : 503);
        }
        throw StateError('Unexpected fixture request: $request');
      });
      await http.runWithClient(() async {
        final draft = {..._draft, 'order_id': orderId};
        await _pump(tester, cart, orderData: draft);
        await tester.tap(find.byKey(const ValueKey('pay-order-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Понятно'));
        await tester.pumpAndSettle();
        final refused = responseKind == 'refused';
        expect(await OrderPaymentGuard.read(orderId),
            refused ? OrderPaymentState.ready : OrderPaymentState.unconfirmed);
        expect(_payAction(tester), refused ? isNotNull : isNull);
        expect(find.byType(PaymentSuccessPage), findsNothing);
        expect(creates, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        SharedPreferences.resetStatic();
        await _pump(tester, cart, orderData: draft);
        expect(_payAction(tester), refused ? isNotNull : isNull);
        expect(creates, 1);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
      cart.dispose();
      await tester.binding.setSurfaceSize(null);
    });
  }

  testWidgets('closed historical orders cannot pay even without a payment flag',
      (tester) async {
    final cart = await _cart();
    var mutations = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/user/cards') {
        return _json({
          'success': true,
          'data': {'cards': [
            {'halyk_id': 'bank-card', 'card_mask': '****4444'},
          ]},
        });
      }
      mutations++;
      throw StateError('Closed order cannot charge: $request');
    });
    await http.runWithClient(() async {
      for (final status in ['4', '7', '71', '50']) {
        await _pump(tester, cart, orderData: {
          ..._draft,
          'order_id': 'closed-$status',
          'current_status': {'status': status},
        });
        expect(_payAction(tester), isNull);
        expect(find.byType(PaymentSuccessPage), findsNothing);
        expect(cart.items.single.itemId, 83);
        await tester.pumpWidget(const SizedBox.shrink());
      }
      expect(mutations, 0);
    }, () => client);
    cart.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('unreadable Kaspi creation persists uncertainty before any link',
      (tester) async {
    const orderId = 'kaspi-create-unknown';
    final cart = await _cart();
    var creates = 0;
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer fixture-only');
      if (request.method == 'GET' && request.url.path == '/api/user/cards') {
        return _json({
          'success': true,
          'data': {'cards': <Object>[]},
        });
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/orders/$orderId/kaspi-qr/pay') {
        creates++;
        return http.Response('{unreadable', 200);
      }
      throw StateError('Unexpected fixture request: $request');
    });
    await http.runWithClient(() async {
      final draft = {..._draft, 'order_id': orderId};
      await _pump(tester, cart, orderData: draft);
      await tester.tap(find.byKey(const ValueKey('pay-order-button')));
      await tester.pumpAndSettle();
      expect(
          await OrderPaymentGuard.read(orderId), OrderPaymentState.unconfirmed);
      expect(find.byType(PaymentSuccessPage), findsNothing);
      await tester.tap(find.text('Понятно'));
      await tester.pumpAndSettle();
      expect(_payAction(tester), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      SharedPreferences.resetStatic();
      await _pump(tester, cart, orderData: draft);
      expect(_payAction(tester), isNull);
      expect(creates, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    cart.dispose();
    await tester.binding.setSurfaceSize(null);
  });
}
