import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/core/money.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/model/cart_item.dart';
import 'package:naliv_delivery/pages/checkout_page.dart';
import 'package:naliv_delivery/pages/login_page.dart';
import 'package:naliv_delivery/pages/profile_setup_page.dart';
import 'package:naliv_delivery/pages/payment_method_page.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/bottling_surface_items.dart';
import '../support/preferences_store.dart';

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
  Future<http.Response> Function(http.Request)? bonuses;
  Future<http.Response> Function(http.Request)? bag;
  Completer<http.Response>? verification;
  bool profileRequired = false;
  bool profileCompleted = false;
  int profileWrites = 0;
  int bonusReads = 0;
  int accountReads = 0;
  int bagId = 48044;
  double bagPrice = 30;
  double bonusBalance = 900;

  Future<void> initialize({bool empty = false}) async {
    await business.setSelectedBusiness(
        {'id': 1, 'name': 'Градусы24', 'address': 'Караганда, Магазин, 1'});
    await cart.bindBusiness(1);
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
      case ('GET', '/api/auth/full-info'):
        accountReads++;
        return _json({
          'success': true,
          'data': {
            'user': {
              'id': 'checkout-fixture-user',
              'name': profileRequired && !profileCompleted ? '' : 'Тестовый Получатель',
              'date_of_birth': profileRequired && !profileCompleted
                  ? ''
                  : '${DateTime.now().year - 25}-01-01',
            },
          },
        });
      case ('POST', '/api/auth/send-code'):
        expectSync(jsonDecode(request.body), {'phone_number': '+77000000000'});
        return _json({'success': true});
      case ('POST', '/api/auth/verify-code'):
        expectSync(jsonDecode(request.body), {
          'phone_number': '+77000000000',
          'onetime_code': '123456',
        });
        return verification == null
            ? _json({'success': true, 'data': {'token': 'fixture-only'}}, 202)
            : await verification!.future;
      case ('PATCH', '/api/users/profile'):
        expectSync(profileRequired, isTrue);
        expectSync(jsonDecode(request.body), {
          'name': 'Тестовый Получатель',
          'first_name': 'Тестовый',
          'last_name': 'Получатель',
          'date_of_birth': '${DateTime.now().year - 25}-01-01',
          'sex': 0,
        });
        profileCompleted = true;
        profileWrites++;
        return _json({'success': true});
      case ('GET', '/api/items/search'):
        expectSync(request.url.queryParameters, {
          'name': 'майка',
          'business_id': '1',
          'page': '1',
          'limit': '100',
        });
        return bag != null
            ? await bag!(request)
            : _json({
                'success': true,
                'data': {
                  'items': [
                    {
                      'item_id': bagId,
                      'code': 'KR-00002264',
                      'name': 'Майка фирменная',
                      'price': bagPrice,
                      'amount': 100,
                      'visible': 1,
                      'unit': 'шт',
                      'quantity_step': 1,
                      'category': {'category_id': 191, 'name': 'Утилитарное'},
                      'options': <Object>[],
                      'promotions': <Object>[],
                    },
                  ],
                },
              });
      case ('GET', '/api/bonuses'):
        bonusReads++;
        return bonuses != null
            ? await bonuses!(request)
            : _json({
                'success': true,
                'data': {'totalBonuses': bonusBalance}
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
        expectSync(request.url.queryParameters, {'source': 'halyk'});
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
    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('checkout-scroll')),
      matching: find.byType(Scrollable),
    ).first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pump();
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: scrollable,
    );
  }
  await Scrollable.ensureVisible(
    tester.element(find.byKey(ValueKey(key))),
    alignment: 0.5,
  );
  await tester.pump();
}

Future<void> _fillDraft(WidgetTester tester) async {
  for (final entry in const {
    'checkout-entrance': '2Б',
    'checkout-floor': '4',
    'checkout-apartment': '12',
    'checkout-promo-code': 'DRAFT-PROMO',
    'checkout-certificate-code': 'DRAFT-CERT',
  }.entries) {
    await _show(tester, entry.key);
    await tester.enterText(find.byKey(ValueKey(entry.key)), entry.value);
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

Future<void> _expectDraft(WidgetTester tester) async {
  for (final entry in const {
    'checkout-entrance': '2Б',
    'checkout-floor': '4',
    'checkout-apartment': '12',
    'checkout-promo-code': 'DRAFT-PROMO',
    'checkout-certificate-code': 'DRAFT-CERT',
  }.entries) {
    await _show(tester, entry.key);
    expect(
        tester.widget<TextField>(find.byKey(ValueKey(entry.key))).controller!.text,
        entry.value);
  }
}

Future<void> _requestLoginCode(WidgetTester tester) async {
  await _show(tester, 'checkout-sign-in');
  await tester.tap(find.byKey(const ValueKey('checkout-sign-in')));
  await tester.pumpAndSettle();
  await tester.enterText(
      find.byKey(const ValueKey('auth-phone-input')), '+77000000000');
  await tester.ensureVisible(find.byKey(const ValueKey('request-code-button')));
  await tester.tap(find.byKey(const ValueKey('request-code-button')));
  await tester.pumpAndSettle();
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

  for (final requireProfile in [false, true]) {
    testWidgets(
        'guest login resumes the same checkout draft with required profile=$requireProfile',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fixture = _Fixture()..profileRequired = requireProfile;
      await fixture.initialize();
      await http.runWithClient(() async {
        await _pump(tester, fixture);
        final state = tester.state(find.byType(CheckoutPage));
        final route = ModalRoute.of(tester.element(find.byType(CheckoutPage)));
        final rows = jsonEncode(fixture.cart.toJsonForOrder());
        await _fillDraft(tester);
        await _requestLoginCode(tester);
        await tester.enterText(
            find.byKey(const ValueKey('auth-code-input')), '123456');
        await tester.pumpAndSettle();
        if (requireProfile) {
          expect(find.byType(ProfileSetupPage), findsOneWidget);
          expect(state.mounted, isTrue);
          expect(fixture.creates, isEmpty);
          await tester.enterText(
              find.byKey(const ValueKey('profile-setup-name')),
              'Тестовый Получатель');
          await tester.tap(
              find.byKey(const ValueKey('profile-setup-birthday')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('OK'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(
              find.byKey(const ValueKey('profile-setup-save')));
          await tester.tap(find.byKey(const ValueKey('profile-setup-save')));
          await tester.pumpAndSettle();
          expect(fixture.profileWrites, 1);
        }
        expect(find.byType(LoginPage), findsNothing);
        expect(identical(tester.state(find.byType(CheckoutPage)), state), isTrue);
        expect(ModalRoute.of(tester.element(find.byType(CheckoutPage))), route);
        expect(jsonEncode(fixture.cart.toJsonForOrder()), rows);
        expect(fixture.cart.businessId, 1);
        expect(fixture.business.selectedBusinessId, 1);
        expect(fixture.bonusReads, greaterThanOrEqualTo(1));
        await _expectDraft(tester);
        expect(find.byKey(const ValueKey('checkout-benefit-applied')), findsNothing);
        expect(_enabled(tester), isTrue);
        expect(fixture.creates, isEmpty);
        await _dispose(tester, fixture);
      }, () => fixture.client);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  testWidgets('cancelled and late login keep the checkout fields and rows',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final fixture = _Fixture()
      ..verification = Completer<http.Response>();
    await fixture.initialize();
    await http.runWithClient(() async {
      await _pump(tester, fixture);
      final state = tester.state(find.byType(CheckoutPage));
      final rows = jsonEncode(fixture.cart.toJsonForOrder());
      await _fillDraft(tester);
      await _requestLoginCode(tester);
      await tester.enterText(
          find.byKey(const ValueKey('auth-code-input')), '123456');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(identical(tester.state(find.byType(CheckoutPage)), state), isTrue);
      await _expectDraft(tester);
      fixture.verification!.complete(_json({
        'success': true,
        'data': {'token': 'fixture-only'},
      }, 202));
      await tester.pumpAndSettle();
      expect(identical(tester.state(find.byType(CheckoutPage)), state), isTrue);
      expect(jsonEncode(fixture.cart.toJsonForOrder()), rows);
      await _expectDraft(tester);
      expect(fixture.creates, isEmpty);
      expect(fixture.cart.clears, 0);
      await _dispose(tester, fixture);
    }, () => fixture.client);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('same normalized store selection preserves the draft and cart',
      (tester) async {
    final fixture = _Fixture();
    await fixture.initialize();
    await fixture.business.setSelectedBusiness({'id': ' 01 ', 'name': 'Ignored'});
    await http.runWithClient(() async {
      await _pump(tester, fixture);
      await _fillDraft(tester);
      final rows = jsonEncode(fixture.cart.toJsonForOrder());
      final total = fixture.cart.getTotalPrice();
      await _show(tester, 'checkout-store');
      await tester.tap(find.byKey(const ValueKey('checkout-store')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('checkout-store-option-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('checkout-confirm-store')), findsNothing);
      expect(jsonEncode(fixture.cart.toJsonForOrder()), rows);
      expect(fixture.cart.getTotalPrice(), total);
      expect(fixture.cart.clears, 0);
      await _expectDraft(tester);
      await _dispose(tester, fixture);
    }, () => fixture.client);
  });

  for (final rejectedKey in ['selected_business', 'cart_items']) {
    testWidgets(
        'rejected $rejectedKey store switch preserves rows options amount and checkout draft',
        (tester) async {
      final preferences = OnboardingPreferences({'auth_token': 'fixture-only'})
        ..install();
      final fixture = _Fixture();
      await fixture.initialize();
      fixture.cart.addItem(CartItem(
        itemId: 88,
        name: 'Товар с опцией',
        price: 100,
        quantity: 2,
        stepQuantity: 1,
        selectedVariants: [
          {
            'variant_id': 8801,
            'required': 0,
            'price': 25,
            'price_type': 'ADD',
            'parent_item_amount': 1,
          },
        ],
        promotions: [],
      ));
      await http.runWithClient(() async {
        await _pump(tester, fixture);
        await _fillDraft(tester);
        final prefs = await SharedPreferences.getInstance();
        final persisted = prefs.getString('cart_items');
        final rows = jsonEncode(fixture.cart.toJsonForOrder());
        preferences.rejectedKeys.add(rejectedKey);
        await _show(tester, 'checkout-store');
        await tester.tap(find.byKey(const ValueKey('checkout-store')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('checkout-store-option-2')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('checkout-confirm-store')));
        await tester.pumpAndSettle();
        expect(find.byType(CheckoutPage), findsOneWidget);
        expect(fixture.business.selectedBusinessId, 1);
        expect(fixture.cart.businessId, 1);
        expect(jsonEncode(fixture.cart.toJsonForOrder()), rows);
        expect(fixture.cart.getTotalPrice(), 1250);
        expect(fixture.cart.clears, 0);
        await prefs.reload();
        expect(prefs.getString('cart_items'), persisted);
        await _expectDraft(tester);
        expect(fixture.creates, isEmpty);
        await _dispose(tester, fixture);
      }, () => fixture.client);
    });
  }

  testWidgets('tobacco delivery and fractional weight do not inflate bonus redemption',
      (tester) async {
    final fixture = _Fixture();
    await fixture.initialize(empty: true);
    final weight = Item(
      itemId: 92,
      name: 'Сыр',
      price: 1000.5,
      amount: 2,
      unit: 'кг',
      stepQuantity: 0.25,
      category: ItemCategory(categoryId: 9, name: 'Еда'),
    );
    expect(fixture.cart.addItem(CartItem(
      itemId: weight.itemId,
      name: weight.name,
      price: weight.price,
      quantity: 0.75,
      stepQuantity: 0.25,
      selectedVariants: [],
      promotions: [],
      itemData: weight.toJson(),
    )), isTrue);
    final tobacco = Item(
      itemId: 93,
      name: 'Марка',
      price: 4000,
      amount: 10,
      unit: 'шт.',
      category: ItemCategory(categoryId: 7, name: 'Табачная продукция'),
    );
    expect(fixture.cart.addItem(CartItem(
      itemId: tobacco.itemId,
      name: tobacco.name,
      price: tobacco.price,
      quantity: 1,
      stepQuantity: 1,
      selectedVariants: [],
      promotions: [],
      itemData: tobacco.toJson(),
    )), isTrue);
    await http.runWithClient(() async {
      await _pump(tester, fixture);
      await _show(tester, 'checkout-bonus-toggle');
      await tester.tap(find.byKey(const ValueKey('checkout-bonus-toggle')));
      await tester.pumpAndSettle();
      expect(
          tester.widget<Text>(find.byKey(const ValueKey('checkout-total'))).data,
          formatTenge(5355.375));
      await tester.tap(find.byKey(const ValueKey('checkout-submit')));
      await tester.pumpAndSettle();
      final body = fixture.creates.single;
      expect(body['bonus_amount'], 225);
      expect(body['total_amount'], closeTo(5355.375, 0.000000001));
      expect((body['items'] as List).cast<Map>()
          .singleWhere((row) => row['item_id'] == 92)['amount'], 0.75);
      expect(fixture.bonusReads, 2);
      await _dispose(tester, fixture);
    }, () => fixture.client);
  });

  testWidgets('fresh changed bonus balance requires consent before any creation',
      (tester) async {
    final fixture = _Fixture();
    await fixture.initialize();
    await http.runWithClient(() async {
      await _pump(tester, fixture);
      await _show(tester, 'checkout-bonus-toggle');
      await tester.tap(find.byKey(const ValueKey('checkout-bonus-toggle')));
      await tester.pumpAndSettle();
      fixture.bonusBalance = 7.9;
      await tester.tap(find.byKey(const ValueKey('checkout-submit')));
      await tester.pumpAndSettle();
      expect(fixture.creates, isEmpty);
      expect(fixture.cart.getTotalPrice(), 1000);
      await _show(tester, 'checkout-bonus-toggle');
      await tester.tap(find.byKey(const ValueKey('checkout-bonus-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('checkout-submit')));
      await tester.pumpAndSettle();
      expect(fixture.creates.single['bonus_amount'], 7);
      expect(fixture.creates.single['total_amount'], 1823);
      await _dispose(tester, fixture);
    }, () => fixture.client);
  });

  testWidgets('a different purchased bag cannot suppress the verified branded SKU',
      (tester) async {
    final fixture = _Fixture()..bagId = 177..bagPrice = 40;
    await fixture.initialize();
    fixture.cart.addItem(CartItem(
      itemId: 777,
      name: 'Чёрный пакет',
      price: 10,
      quantity: 1,
      stepQuantity: 1,
      selectedVariants: [],
      promotions: [],
    ));
    await http.runWithClient(() async {
      await _pump(tester, fixture,
          page: const CheckoutPage(initialDeliveryType: 'PICKUP'));
      await tester.tap(find.byKey(const ValueKey('checkout-submit')));
      await tester.pumpAndSettle();
      final body = fixture.creates.single;
      expect(body['total_amount'], 1050);
      expect((body['items'] as List).cast<Map>()
          .where((row) => row['item_id'] == 177).toList(), [
        {'item_id': 177, 'amount': 1, 'options': <Object>[]},
      ]);
      expect((body['items'] as List).cast<Map>()
          .singleWhere((row) => row['item_id'] == 777)['amount'], 1);
      await _dispose(tester, fixture);
    }, () => fixture.client);
  });

  testWidgets('an unavailable branded SKU blocks order without substituting a bag',
      (tester) async {
    final fixture = _Fixture();
    await fixture.initialize();
    fixture.bag = (_) async => _json({
      'success': true,
      'data': {'items': <Object>[]},
    });
    await http.runWithClient(() async {
      await _pump(tester, fixture,
          page: const CheckoutPage(initialDeliveryType: 'PICKUP'));
      expect(_enabled(tester), isFalse);
      expect(fixture.creates, isEmpty);
      await _show(tester, 'checkout-bag-retry');
      fixture.bag = null;
      await tester.tap(find.byKey(const ValueKey('checkout-bag-retry')));
      await tester.pumpAndSettle();
      expect(_enabled(tester), isTrue);
      expect(fixture.cart.clears, 0);
      await _dispose(tester, fixture);
    }, () => fixture.client);
  });
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
    expect(fixture.cart.syncItemBottleCounts(item, [], {3094: 1, 3095: 1}),
        isTrue);
    final itemSubtotal = fixture.cart.getTotalPrice();
    expect(itemSubtotal, 2990);
    await http.runWithClient(() async {
      await _pump(tester, fixture);
      await tester.tap(find.byKey(const ValueKey('checkout-mode-pickup')));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('checkout-total')))
              .data,
          formatTenge(3020));
      await tester.tap(find.byKey(const ValueKey('checkout-submit')));
      await tester.pumpAndSettle();
      final body = fixture.creates.single;
      expect(body['total_amount'], itemSubtotal + 30); // Existing bag contract.
      final lines = (body['items'] as List)
          .cast<Map>()
          .where((line) => line['item_id'] == 1186)
          .toList();
      expect(lines.fold<num>(0, (sum, line) => sum + (line['amount'] as num)), 4);
      final containers = <int, num>{};
      for (final line in lines) {
        for (final option in (line['options'] as List).cast<Map>()) {
          final relation = option['option_item_relation_id'] as int;
          final volume = {3094: 1, 3095: 2}[relation]!;
          expect(option['amount'], 1);
          final count = (line['amount'] as num) / volume;
          containers.update(relation, (existing) => existing + count,
              ifAbsent: () => count);
        }
      }
      expect(containers, {3094: 2, 3095: 1});
      expect(fixture.cart.clears, 1);
      expect(
          tester
              .widget<PaymentMethodPage>(find.byType(PaymentMethodPage))
              .displayAmount,
          3020);
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
          formatTenge(3430));
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
          formatTenge(1830));
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
          formatTenge(1430));
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
          formatTenge(2530));
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
          formatTenge(2830));
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
          formatTenge(1730));
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
          formatTenge(1330));
      await _show(tester, 'checkout-bonus-toggle');
      await tester.tap(find.byKey(const ValueKey('checkout-bonus-toggle')));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('checkout-total')))
              .data,
          formatTenge(1530));
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
