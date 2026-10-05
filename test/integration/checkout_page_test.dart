import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/model/cart_item.dart';
import 'package:naliv_delivery/pages/checkout_page.dart';
import 'package:naliv_delivery/pages/payment_method_page.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/bottling_surface_items.dart';

const _address = <String, dynamic>{
  'address': 'Караганда, Тестовая, 16',
  'street': 'Тестовая',
  'house': '16',
  'lat': 49.8,
  'lon': 73.1,
};

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

http.Response _quote(double cost) => _json({
      'success': true,
      'data': {
        'delivery_cost': cost,
        'base_delivery_cost': cost - 100,
        'service_fee_amount': 100
      },
    });

class _Cart extends CartProvider {
  int clears = 0;
  @override
  void clearCart() {
    clears++;
    super.clearCart();
  }
}

class _Fixture {
  final cart = _Cart();
  final business = BusinessProvider();
  final creates = <Map<String, dynamic>>[];
  final unknown = <String>[];
  Future<http.Response> Function(http.Request)? quote;
  Future<http.Response> Function(http.Request)? promo;
  Future<http.Response> Function(http.Request)? certificate;
  Future<http.Response> Function(http.Request)? create;

  Future<void> initialize({bool empty = false}) async {
    await business.setSelectedBusiness(
        {'id': 1, 'name': 'Градусы24', 'address': 'Караганда, Магазин, 1'});
    if (!empty) {
      cart.addItem(CartItem(
          itemId: 99,
          name: 'Вода',
          price: 1000,
          quantity: 1,
          stepQuantity: 1,
          selectedVariants: [],
          promotions: []));
    }
  }

  late final client = MockClient((request) async {
    final authorization = request.headers['authorization'];
    if (authorization != null && authorization != 'Bearer fixture-only') {
      throw StateError('Non-fixture checkout credentials');
    }
    switch ((request.method, request.url.path)) {
      case ('GET', '/api/bonuses'):
        return _json({
          'success': true,
          'data': {'totalBonuses': 900}
        });
      case ('GET', '/api/delivery/calculate-by-address'):
        return quote == null ? _quote(800) : await quote!(request);
      case ('POST', '/api/orders/validate-promo-code'):
        return promo == null
            ? _json({
                'success': true,
                'data': {'promo_discount': 100, 'final_delivery_price': 800}
              })
            : await promo!(request);
      case ('POST', '/api/certificates/validate'):
        return certificate == null
            ? _json({
                'success': true,
                'data': {
                  'can_use': true,
                  'max_available_amount': 500,
                  'certificate': {'id': 81, 'code': 'GIFT', 'balance': 500},
                }
              })
            : await certificate!(request);
      case ('POST', '/api/orders/create-order-no-payment'):
        creates.add(Map<String, dynamic>.from(jsonDecode(request.body) as Map));
        return create == null
            ? _json({
                'success': true,
                'data': {'order_id': 'fixture-order'}
              }, 201)
            : await create!(request);
      case ('GET', '/api/user/cards'):
        expect(request.url.queryParameters, {'source': 'halyk'});
        return _json({
          'success': true,
          'data': {'cards': <Object>[]}
        });
      case ('GET', '/api/users/cities'):
        return _json({
          'success': true,
          'data': {
            'cities': [
              {'id': 1, 'name': 'Караганда'}
            ]
          }
        });
      case ('GET', '/api/businesses'):
        return _json({
          'success': true,
          'data': {
            'businesses': [
              {
                'id': 1,
                'name': 'Градусы24',
                'address': 'Караганда, Магазин, 1'
              },
              {
                'id': 2,
                'name': 'Другой магазин',
                'address': 'Караганда, Магазин, 2'
              },
            ]
          }
        });
      default:
        unknown.add('${request.method} ${request.url}');
        throw StateError(
            'Unexpected fixture request: ${request.method} ${request.url}');
    }
  });
}

Future<void> _pump(
  WidgetTester tester,
  _Fixture fixture, {
  CheckoutPage page = const CheckoutPage(initialAddress: _address),
  bool settle = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(375, 812));
  await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<CartProvider>.value(value: fixture.cart),
        ChangeNotifierProvider<BusinessProvider>.value(value: fixture.business),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 48, bottom: 34),
            ),
            child: child!),
        home: page,
      )));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }
}

bool _enabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.byKey(const ValueKey('checkout-submit')))
        .onPressed !=
    null;

Future<void> _show(WidgetTester tester, String key) async {
  await tester.pump();
  final target = find.byKey(ValueKey(key));
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('checkout-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
  }
  await Scrollable.ensureVisible(
    tester.element(find.byKey(ValueKey(key))),
    alignment: 0.5,
  );
  await tester.pump();
}

Future<void> _dispose(WidgetTester tester, _Fixture fixture) async {
  expect(fixture.unknown, isEmpty);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.binding.setSurfaceSize(null);
}

void main() {
  setUp(() =>
      SharedPreferences.setMockInitialValues({'auth_token': 'fixture-only'}));

  testWidgets(
      'captured mixed bottling subtotal and group gifts reach checkout unchanged',
      (tester) async {
    final captured = jsonDecode(
        File('test/fixtures/public_bottling_catalog.json')
            .readAsStringSync()) as Map;
    final sample = (captured['category_samples'] as List)
        .cast<Map>()
        .singleWhere((sample) => sample['item']['item_id'] == 1186);
    final item =
        Item.fromJson(Map<String, dynamic>.from(sample['item'] as Map));
    final fixture = _Fixture();
    await fixture.initialize(empty: true);
    expect(fixture.cart.syncItemBottleCounts(item, [], {3094: 1, 3097: 1}),
        isTrue);
    final itemSubtotal = fixture.cart.getTotalPrice();
    expect(itemSubtotal, 3920);
    await http.runWithClient(() async {
      await _pump(tester, fixture);
      await tester.tap(find.byKey(const ValueKey('checkout-mode-pickup')));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('checkout-total')))
              .data,
          '3950 ₸');
      await tester.tap(find.byKey(const ValueKey('checkout-submit')));
      await tester.pumpAndSettle();
      final body = fixture.creates.single;
      expect(body['total_amount'], itemSubtotal + 30); // Existing bag contract.
      final lines = (body['items'] as List)
          .cast<Map>()
          .where((line) => line['item_id'] == 1186)
          .toList();
      expect(lines.map((line) => line['amount']), [1.0, 3.0, 2.0]);
      expect(lines.map((line) => line['options']), [
        [
          {'option_item_relation_id': 3094, 'amount': 1}
        ],
        [
          {'option_item_relation_id': 3097, 'amount': 1}
        ],
        [
          {'option_item_relation_id': 3095, 'amount': 1}
        ],
      ]);
      expect(fixture.cart.clears, 1);
      expect(
          tester
              .widget<PaymentMethodPage>(find.byType(PaymentMethodPage))
              .displayAmount,
          3950);
      await _dispose(tester, fixture);
    }, () => fixture.client);
  });

  testWidgets(
      '3+1 checkout carries four fully charged physical one-litre bottles',
      (tester) async {
    final fixture = _Fixture();
    await fixture.initialize(empty: true);
    final item = syntheticThreePlusOneSurfaceItem(onlyOneLitre: true);
    expect(fixture.cart.syncItemBottleCounts(item, [], {93101: 3}), isTrue);
    expect(fixture.cart.getTotalPrice(), 3400);
    await http.runWithClient(() async {
      await _pump(tester, fixture);
      await tester.tap(find.byKey(const ValueKey('checkout-mode-pickup')));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('checkout-total')))
              .data,
          '3430 ₸');
      await tester.tap(find.byKey(const ValueKey('checkout-submit')));
      await tester.pumpAndSettle();
      final body = fixture.creates.single;
      expect(body['total_amount'], 3430); // Four bottles, plus existing bag.
      final line = (body['items'] as List)
          .cast<Map>()
          .singleWhere((line) => line['item_id'] == item.itemId);
      expect(line['amount'], 4);
      expect(line['options'], [
        {'option_item_relation_id': 93101, 'amount': 1},
      ]);
      expect(
          tester
              .widget<PaymentMethodPage>(find.byType(PaymentMethodPage))
              .displayAmount,
          3430);
      await _dispose(tester, fixture);
    }, () => fixture.client);
  });

  testWidgets(
      'failed delivery quote blocks creation and explicit retry recovers',
      (tester) async {
    final fixture = _Fixture();
    await fixture.initialize();
    var failed = true;
    fixture.quote =
        (_) async => failed ? _json({'success': false}, 503) : _quote(800);
    await http.runWithClient(() async {
      await _pump(tester, fixture);
      expect(_enabled(tester), isFalse);
      expect(fixture.creates, isEmpty);
      failed = false;
      await _show(tester, 'checkout-quote-retry');
      await tester.tap(find.byKey(const ValueKey('checkout-quote-retry')));
      await tester.pumpAndSettle();
      expect(_enabled(tester), isTrue);
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('checkout-total')))
              .data,
          '1830 ₸');
      await _dispose(tester, fixture);
    }, () => fixture.client);
  });

  testWidgets(
      'new address quote starts while the old request is pending and late reply is ignored',
      (tester) async {
    final fixture = _Fixture();
    await fixture.initialize();
    final old = Completer<http.Response>();
    final points = <String>[];
    fixture.quote = (request) {
      points.add(request.url.queryParameters['lat']!);
      return points.length == 1 ? old.future : Future.value(_quote(400));
    };
    await http.runWithClient(() async {
      await _pump(tester, fixture,
          settle: false,
          page: CheckoutPage(
            initialAddress: _address,
            addressPicker: (_, __, ___) async =>
                {..._address, 'address': 'Другой адрес', 'lat': 50.0},
          ));
      expect(_enabled(tester), isFalse);
      await tester.tap(find.byKey(const ValueKey('checkout-address')));
      await tester.pump();
      await tester.pump();
      expect(points, ['49.8', '50.0']);
      expect(_enabled(tester), isTrue);
      old.complete(_quote(1600));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('checkout-total')))
              .data,
          '1430 ₸');
      await _dispose(tester, fixture);
    }, () => fixture.client);
  });

  testWidgets(
      'cart change replaces a pending quote rather than dropping the next calculation',
      (tester) async {
    final fixture = _Fixture();
    await fixture.initialize();
    final old = Completer<http.Response>();
    var requests = 0;
    fixture.quote =
        (_) => ++requests == 1 ? old.future : Future.value(_quote(500));
    await http.runWithClient(() async {
      await _pump(tester, fixture, settle: false);
      fixture.cart.updateQuantity(99, 2);
      await tester.pump();
      await tester.pump();
      expect(requests, 2);
      expect(_enabled(tester), isTrue);
      old.complete(_json({'success': false}, 503));
      await tester.pumpAndSettle();
      expect(_enabled(tester), isTrue);
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('checkout-total')))
              .data,
          '2530 ₸');
      await _dispose(tester, fixture);
    }, () => fixture.client);
  });

  testWidgets(
      'accepted create freezes payable amount, suppresses double submit and clears once',
      (tester) async {
    final fixture = _Fixture();
    await fixture.initialize();
    final accepted = Completer<http.Response>();
    fixture.create = (_) => accepted.future;
    await http.runWithClient(() async {
      await _pump(tester, fixture);
      final submit = find.byKey(const ValueKey('checkout-submit'));
      await tester.tap(submit);
      await tester.tap(submit);
      await tester.pump();
      expect(fixture.creates, hasLength(1));
      expect(fixture.cart.hasActiveItems, isTrue);
      expect(_enabled(tester), isFalse);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(CheckoutPage), findsOneWidget);
      expect(fixture.creates, hasLength(1));
      final body = fixture.creates.single;
      expect(body['total_amount'], 1830);
      expect(body.containsKey('saved_card_id'), isFalse);
      expect(body['apartment'], '');
      expect(body['entrance'], '');
      expect(body['floor'], '');
      expect(body['delivery_time'], 'NOW');
      expect(body['courier_tips'], 0);
      expect(body['items'], [
        {'item_id': 99, 'amount': 1.0, 'options': <Object>[]},
        {'item_id': 48044, 'amount': 1, 'options': <Object>[]},
      ]);
      accepted.complete(_json({
        'success': true,
        'data': {'order_id': 'accepted-order'}
      }, 201));
      await tester.pumpAndSettle();
      expect(fixture.cart.hasActiveItems, isFalse);
      expect(fixture.cart.clears, 1);
      final payment =
          tester.widget<PaymentMethodPage>(find.byType(PaymentMethodPage));
      expect(payment.displayAmount, 1830);
      expect(payment.orderData['order_id'], 'accepted-order');
      await _dispose(tester, fixture);
    }, () => fixture.client);
  });

  testWidgets(
      'refused create preserves input and cart and allows an explicit later submission',
      (tester) async {
    final fixture = _Fixture();
    await fixture.initialize();
    fixture.create = (_) async => _json({
          'success': false,
          'error': {'message': 'Магазин закрыт'}
        }, 409);
    await http.runWithClient(() async {
      await _pump(tester, fixture);
      await tester.enterText(
          find.byKey(const ValueKey('checkout-entrance')), '2Б');
      await tester.tap(find.byKey(const ValueKey('checkout-submit')));
      await tester.pumpAndSettle();
      expect(fixture.cart.getTotalQuantityForItem(99), 1);
      expect(fixture.cart.clears, 0);
      expect(_enabled(tester), isTrue);
      await _show(tester, 'checkout-entrance');
      expect(
          tester
              .widget<TextField>(
                  find.byKey(const ValueKey('checkout-entrance')))
              .controller!
              .text,
          '2Б');
      expect(fixture.creates.single['entrance'], '2Б');
      fixture.create = null;
      await tester.tap(find.byKey(const ValueKey('checkout-submit')));
      await tester.pumpAndSettle();
      expect(fixture.creates, hasLength(2));
      expect(fixture.creates.last['entrance'], '2Б');
      expect(fixture.cart.clears, 1);
      expect(find.byType(PaymentMethodPage), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(
          (jsonDecode(prefs.getString('selected_address')!) as Map)['entrance'],
          '2Б');
      await _dispose(tester, fixture);
    }, () => fixture.client);
  });

  testWidgets(
      'malformed accepted create cannot clear cart or become another automatic mutation',
      (tester) async {
    final fixture = _Fixture();
    await fixture.initialize();
    fixture.create = (_) async => _json({
          'success': true,
          'data': {'total_amount': 1830}
        }, 201);
    await http.runWithClient(() async {
      await _pump(tester, fixture);
      await tester.tap(find.byKey(const ValueKey('checkout-submit')));
      await tester.pumpAndSettle();
      expect(fixture.cart.hasActiveItems, isTrue);
      expect(fixture.cart.clears, 0);
      expect(find.byType(PaymentMethodPage), findsNothing);
      expect(_enabled(tester), isFalse);
      await tester.pump(const Duration(seconds: 10));
      expect(fixture.creates, hasLength(1));
      await _dispose(tester, fixture);
    }, () => fixture.client);
  });

  testWidgets(
      'pickup excludes address and fees and late delivery quote cannot change payment',
      (tester) async {
    final fixture = _Fixture();
    await fixture.initialize();
    final pending = Completer<http.Response>();
    fixture.quote = (_) => pending.future;
    await http.runWithClient(() async {
      await _pump(tester, fixture, settle: false);
      await tester.tap(find.byKey(const ValueKey('checkout-mode-pickup')));
      await tester.pump();
      pending.complete(_quote(1800));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('checkout-address')), findsNothing);
      expect(find.byKey(const ValueKey('checkout-entrance')), findsNothing);
      expect(_enabled(tester), isTrue);
      await tester.tap(find.byKey(const ValueKey('checkout-submit')));
      await tester.pumpAndSettle();
      final body = fixture.creates.single;
      expect(body['total_amount'], 1030);
      expect(body['delivery_type'], 'PICKUP');
      expect(body['lat'], 0.0);
      expect(body['lon'], 0.0);
      expect(body['street'], '');
      expect(body['apartment'], '');
      expect(
          tester
              .widget<PaymentMethodPage>(find.byType(PaymentMethodPage))
              .displayAmount,
          1030);
      await _dispose(tester, fixture);
    }, () => fixture.client);
  });

  testWidgets('late promo validation cannot discount a changed cart',
      (tester) async {
    final fixture = _Fixture();
    await fixture.initialize();
    final pending = Completer<http.Response>();
    var validations = 0;
    fixture.promo = (_) {
      validations++;
      return pending.future;
    };
    await http.runWithClient(() async {
      await _pump(tester, fixture);
      await _show(tester, 'checkout-promo-code');
      await tester.enterText(
          find.byKey(const ValueKey('checkout-promo-code')), 'PROMO');
      await _show(tester, 'checkout-apply-promo');
      await tester.tap(find.byKey(const ValueKey('checkout-apply-promo')));
      await tester.pump();
      expect(validations, 1);
      fixture.cart.updateQuantity(99, 2);
      await tester.pump();
      pending.complete(_json({
        'success': true,
        'data': {'promo_discount': 1000, 'final_delivery_price': 0}
      }));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('checkout-benefit-applied')), findsNothing);
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('checkout-total')))
              .data,
          '2830 ₸');
      await _dispose(tester, fixture);
    }, () => fixture.client);
  });

  testWidgets(
      'certificate replaces promo and bonuses replace certificate with actual bounded amounts',
      (tester) async {
    final fixture = _Fixture();
    await fixture.initialize();
    await http.runWithClient(() async {
      await _pump(tester, fixture);
      await _show(tester, 'checkout-promo-code');
      await tester.enterText(
          find.byKey(const ValueKey('checkout-promo-code')), 'PROMO');
      await _show(tester, 'checkout-apply-promo');
      await tester.tap(find.byKey(const ValueKey('checkout-apply-promo')));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('checkout-total')))
              .data,
          '1730 ₸');
      await _show(tester, 'checkout-certificate-code');
      await tester.enterText(
          find.byKey(const ValueKey('checkout-certificate-code')), 'GIFT');
      await _show(tester, 'checkout-apply-certificate');
      await tester
          .tap(find.byKey(const ValueKey('checkout-apply-certificate')));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('checkout-total')))
              .data,
          '1330 ₸');
      await _show(tester, 'checkout-bonus-toggle');
      await tester.tap(find.byKey(const ValueKey('checkout-bonus-toggle')));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('checkout-total')))
              .data,
          '1530 ₸');
      await tester.tap(find.byKey(const ValueKey('checkout-submit')));
      await tester.pumpAndSettle();
      final body = fixture.creates.single;
      expect(body['bonus_amount'], 300);
      expect(body['use_bonuses'], isTrue);
      expect(body.containsKey('promo_code'), isFalse);
      expect(body.containsKey('certificate_id'), isFalse);
      expect(body.containsKey('certificate_code'), isFalse);
      expect(find.byType(PaymentMethodPage), findsOneWidget);
      await _dispose(tester, fixture);
    }, () => fixture.client);
  });

  testWidgets(
      'store change waits for confirmation and cancellation preserves store preferences and cart',
      (tester) async {
    final fixture = _Fixture();
    await fixture.initialize();
    await http.runWithClient(() async {
      await _pump(tester, fixture);
      await tester.tap(find.byKey(const ValueKey('checkout-store')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('checkout-store-option-2')));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('checkout-confirm-store')), findsOneWidget);
      expect(fixture.cart.getTotalQuantityForItem(99), 1);
      expect(fixture.business.selectedBusinessId, 1);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(
          (jsonDecode(prefs.getString('selected_business')!) as Map)['id'], 1);
      expect(fixture.cart.clears, 0);
      expect(fixture.business.selectedBusinessId, 1);
      await _dispose(tester, fixture);
    }, () => fixture.client);
  });

  testWidgets(
      'guests cannot submit and an empty cart never presents order creation',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final fixture = _Fixture();
    await fixture.initialize();
    await http.runWithClient(() async {
      await _pump(tester, fixture);
      expect(_enabled(tester), isFalse);
      fixture.cart.clearCart();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('checkout-submit')), findsNothing);
      expect(find.byKey(const ValueKey('checkout-empty')), findsOneWidget);
      expect(fixture.creates, isEmpty);
      await _dispose(tester, fixture);
    }, () => fixture.client);
  });
}
