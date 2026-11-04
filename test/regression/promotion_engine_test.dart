import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/model/cart_item.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/promotion_engine.dart';
import 'package:naliv_delivery/utils/smart_cart.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _subtract(int detailId, int base, int add,
        {String? endDate}) =>
    {
      'detail_id': detailId,
      'type': 'SUBTRACT',
      'base_amount': base,
      'add_amount': add,
      'name': '$base+$add',
      if (endDate != null)
        'promotion': {
          'detail_id': detailId,
          'end_promotion_date': endDate,
        },
    };

Map<String, dynamic> _percent(int detailId, double discount) => {
      'detail_id': detailId,
      'type': 'PERCENT',
      'discount': discount,
      'name': '-$discount%',
    };

CartItem _row({
  int itemId = 500,
  double price = 1000,
  double quantity = 1,
  List<Map<String, dynamic>> promotions = const [],
}) =>
    CartItem(
      itemId: itemId,
      name: 'Товар',
      price: price,
      quantity: quantity,
      stepQuantity: 1,
      selectedVariants: const [],
      promotions: promotions,
    );

PromotionEvaluation _at(double quantity, List<Map<String, dynamic>> promotions,
        {DateTime? now}) =>
    evaluatePromotion(quantity: quantity, promotions: promotions, now: now);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('promotion award selection', () {
    test('picks the promotion that gifts the most at the current quantity', () {
      final promotions = [_subtract(1, 3, 1), _subtract(2, 6, 3)];
      final eight = _at(8, promotions);
      expect(eight.label, '3+1');
      expect(eight.giftQuantity, 2);
      final nine = _at(9, promotions);
      expect(nine.label, '6+3');
      expect(nine.giftQuantity, 3);
      expect(nine.paidQuantity, 6);
    });

    test('prefers the larger gift when the free count ties', () {
      // 6+2 and 3+1 both gift two units at eight; 12 gives 3+1 and 6+3 three each.
      expect(_at(8, [_subtract(1, 6, 2), _subtract(2, 3, 1)]).label, '6+2');
      expect(_at(8, [_subtract(2, 3, 1), _subtract(1, 6, 2)]).label, '6+2');
      final twelve = _at(12, [_subtract(1, 3, 1), _subtract(2, 6, 3)]);
      expect(twelve.giftQuantity, 3);
      expect(twelve.label, '6+3');
    });

    test('a gift that is already earned counts for every promotion', () {
      // 2+1 gifts one unit at three; 3+1 gifts none until four.
      final promotions = [_subtract(1, 2, 1), _subtract(2, 3, 1)];
      expect(_at(3, promotions).giftQuantity, 1);
      expect(_at(3, promotions).label, '2+1');
      expect(_at(6, promotions).giftQuantity, 2);
    });

    test('ignores promotions outside their validity window', () {
      final now = DateTime.utc(2026, 6, 1);
      final expired = _subtract(1, 2, 1)
        ..['end_date'] = '2000-01-01T00:00:00.000Z';
      final future = _subtract(2, 2, 1)
        ..['start_date'] = '2999-01-01T00:00:00.000Z';
      for (final promotion in [expired, future]) {
        final result = _at(6, [promotion], now: now);
        expect(result.giftQuantity, 0);
        expect(result.award, isNull);
        expect(result.hasPromotion, isFalse);
      }
      expect(promotionGiftQuantity(4, [expired, future], now: now), 0);
      final expiredPercent = _percent(3, 10)
        ..['end_date'] = '2000-01-01T00:00:00.000Z';
      expect(
          applyPromotionsToPaidBaseTotal(
              unitPrice: 1000,
              quantity: 2,
              promotions: [expiredPercent],
              now: now),
          2000);
    });

    test('the window is inclusive and decided by the supplied instant', () {
      final end = DateTime.utc(2027, 1, 1);
      final promotion = _subtract(1, 3, 1)
        ..['end_date'] = end.toIso8601String();
      expect(_at(4, [promotion], now: end).giftQuantity, 1);
      expect(
          _at(4, [promotion], now: end.add(const Duration(microseconds: 1)))
              .giftQuantity,
          0);
      // An ended promotion neither gifts nor advertises one.
      final ended = _at(3, [promotion], now: end.add(const Duration(days: 1)));
      expect(ended.nextGiftIn, isNull);
      expect(ended.bonusQuantity, isNull);
      final live =
          _at(3, [promotion], now: end.subtract(const Duration(days: 1)));
      expect(live.nextGiftIn, 1);
      expect(live.bonusQuantity, 1);
    });

    test('reads the window the server nests under promotion', () {
      final now = DateTime.utc(2026, 6, 1);
      final nested = {
        'detail_id': 8692,
        'type': 'SUBTRACT',
        'base_amount': 2,
        'add_amount': 1,
        'name': '2+1',
        'promotion': {'end_promotion_date': '2000-01-01T00:00:00.000Z'},
      };
      expect(_at(3, [nested], now: now).award, isNull);
      final live = {
        'detail_id': 8692,
        'type': 'SUBTRACT',
        'base_amount': 2,
        'add_amount': 1,
        'name': '2+1',
        'promotion': {'end_promotion_date': '2999-01-01T00:00:00.000Z'},
      };
      expect(_at(3, [live], now: now).label, '2+1');
      expect(_at(3, [live], now: now).giftQuantity, 1);
    });

    test('names the campaign by its marketing name, the chip by its label', () {
      final promotion = {
        ..._subtract(1, 2, 1),
        'promotion': {'name': 'Выгодный розлив'},
      };
      final result = _at(3, [promotion]);
      expect(result.name, 'Выгодный розлив');
      expect(result.label, '2+1');
    });

    test('ignores price promotions, malformed entries and unusable amounts',
        () {
      final promotions = [
        _percent(1, 10),
        {'detail_id': 2, 'type': 'SUBTRACT', 'base_amount': 0, 'add_amount': 1},
        {'detail_id': 3, 'type': 'SUBTRACT', 'base_amount': 2, 'add_amount': 0},
        {
          'detail_id': 5,
          'type': 'SUBTRACT',
          'base_amount': -2,
          'add_amount': 1
        },
        {'detail_id': 4},
      ];
      expect(promotionGiftQuantity(6, promotions), 0);
      final result = _at(6, promotions);
      expect(result.award, isNull);
      expect(result.label, isNull);
      expect(result.nextGiftIn, isNull);
      expect(result.bonusQuantity, isNull);
      expect(result.paidQuantity, 6);
    });

    test('reads amounts the API sends as strings and a lower-case type', () {
      final promotion = {
        'detail_id': 1,
        'type': 'subtract',
        'base_amount': '3',
        'add_amount': '1',
      };
      expect(_at(4, [promotion]).giftQuantity, 1);
      expect(_at(3, [promotion]).giftQuantity, 0);
    });
  });

  group('one rule: the cart holds what the customer added', () {
    final threePlusOne = [_subtract(1, 3, 1)];

    test('gift is floor(quantity / (base + add)) * add, the rest is paid', () {
      for (final (quantity, gift) in [
        (0.0, 0.0),
        (1.0, 0.0),
        (3.0, 0.0),
        (3.999, 0.0),
        (4.0, 1.0),
        (7.0, 1.0),
        (8.0, 2.0),
        (12.0, 3.0),
      ]) {
        final result = _at(quantity, threePlusOne);
        expect(result.quantity, quantity);
        expect(result.giftQuantity, gift, reason: '$quantity units');
        expect(result.paidQuantity, quantity - gift, reason: '$quantity units');
        expect(result.hasPromotion, isTrue);
        expect(promotionGiftQuantity(quantity, threePlusOne), gift);
      }
    });

    test('a 2+1 promotion makes the third bottle free, not the second', () {
      final twoPlusOne = [_subtract(1, 2, 1)];
      expect(_at(2, twoPlusOne).giftQuantity, 0);
      final three = _at(3, twoPlusOne);
      expect(three.giftQuantity, 1);
      expect(three.paidQuantity, 2);
      expect(_at(5, twoPlusOne).giftQuantity, 1);
      expect(_at(6, twoPlusOne).giftQuantity, 2);
    });

    test('a quantity that cannot be a gift multiple is never rounded up', () {
      expect(_at(3.5, threePlusOne).giftQuantity, 0);
      expect(_at(3.5, threePlusOne).paidQuantity, 3.5);
      expect(_at(-1, threePlusOne).giftQuantity, 0);
      expect(_at(double.nan, threePlusOne).giftQuantity, 0);
    });

    test('reports how many units to add before the gift grows', () {
      for (final (quantity, next) in [
        (0.0, 4.0),
        (1.0, 3.0),
        (2.0, 2.0),
        (3.0, 1.0),
        (4.0, 4.0),
        (5.0, 3.0),
        (6.0, 2.0),
        (7.0, 1.0),
        (8.0, 4.0),
      ]) {
        expect(_at(quantity, threePlusOne).nextGiftIn, next,
            reason: '$quantity units');
      }
    });

    test('the bonus offer exists only when the added units cost nothing', () {
      for (final (quantity, bonus) in [
        (0.0, null),
        (2.0, null),
        (3.0, 1.0),
        (4.0, null),
        (6.0, null),
        (7.0, 1.0),
        (8.0, null),
      ]) {
        expect(_at(quantity, threePlusOne).bonusQuantity, bonus,
            reason: '$quantity units');
      }
      final sixPlusTwo = [_subtract(1, 6, 2)];
      expect(_at(6, sixPlusTwo).bonusQuantity, 2);
      expect(_at(6, sixPlusTwo).nextGiftIn, 2);
      expect(_at(5, sixPlusTwo).bonusQuantity, isNull);
      expect(_at(5, sixPlusTwo).nextGiftIn, 3);
      expect(_at(0, sixPlusTwo).nextGiftIn, 8);
    });

    test('the offer follows the customer-best promotion, not a weaker one', () {
      final promotions = [_subtract(1, 2, 1), _subtract(2, 3, 1)];
      final two = _at(2, promotions);
      expect(two.bonusQuantity, 1); // 2+1 completes at three.
      expect(two.nextGiftIn, 1);
      final three = _at(3, promotions);
      expect(three.giftQuantity, 1);
      expect(three.bonusQuantity, isNull); // 3+1 alone would add no gift here.
      expect(three.nextGiftIn, 3);
    });

    test('price promotions never create a gift or an offer', () {
      final result = _at(5, [_percent(1, 10)]);
      expect(result.giftQuantity, 0);
      expect(result.award, isNull);
      expect(result.nextGiftIn, isNull);
      expect(result.bonusQuantity, isNull);
    });

    test('the rule is phrased as what the customer takes and pays for', () {
      String units(double value) => '${value.round()} шт';
      final three = _at(0, threePlusOne).award!;
      expect(three.setSize, 4);
      expect(
          promotionRuleText(three, units), 'Возьмите 4 шт — платите за 3 шт');
      final two = _at(0, [_subtract(1, 2, 1)]).award!;
      expect(promotionRuleText(two, units), 'Возьмите 3 шт — платите за 2 шт');
      expect(promotionRuleText(three, (value) => '${value.round()} л'),
          'Возьмите 4 л — платите за 3 л');
    });
  });

  group('price promotions on the paid units', () {
    test('FIXED takes money off every unit, PERCENT and DISCOUNT the rest', () {
      double total(List<Map<String, dynamic>> promotions) =>
          applyPromotionsToPaidBaseTotal(
              unitPrice: 1000, quantity: 3, promotions: promotions);
      expect(total(const []), 3000);
      expect(
          total([
            {'type': 'FIXED', 'discount': 100}
          ]),
          2700);
      expect(total([_percent(1, 10)]), 2700);
      expect(
          total([
            {'type': 'DISCOUNT', 'discount_value': 20}
          ]),
          2400);
      // FIXED first, then the percentage of what is left.
      expect(
          total([
            _percent(1, 10),
            {'type': 'FIXED', 'discount': 100},
          ]),
          closeTo(2430, 0.0001));
    });

    test('a discount never makes a unit cost less than nothing', () {
      expect(
          applyPromotionsToPaidBaseTotal(
              unitPrice: 100,
              quantity: 2,
              promotions: [
                {'type': 'FIXED', 'discount': 500}
              ]),
          0);
    });
  });

  group('cart under the single rule', () {
    final threePlusOne = [_subtract(1, 3, 1)];

    CartGroupExpectation expectation(double quantity) {
      final cart = CartProvider();
      addTearDown(cart.dispose);
      expect(cart.addItem(_row(quantity: quantity, promotions: threePlusOne)),
          isTrue);
      return CartGroupExpectation(cart);
    }

    test('three units of a 3+1 cost three units and carry no gift', () {
      final result = expectation(3);
      expect(result.group.freeQuantity, 0);
      expect(result.group.paidQuantity, 3);
      expect(result.group.totalOrderQuantity, 3);
      expect(result.group.physicalItems.single.quantity, 3);
      expect(result.group.physicalItems.single.bottledGiftQuantity, 0);
      expect(result.cart.evaluate().totalPrice, 3000);
      expect(result.cart.toJsonForOrder().single['amount'], 3);
    });

    test('the fourth unit is the gift: four are sent, three are paid', () {
      final result = expectation(4);
      expect(result.group.freeQuantity, 1);
      expect(result.group.paidQuantity, 3);
      expect(result.group.totalOrderQuantity, 4);
      expect(result.group.physicalItems.single.quantity, 3);
      expect(result.group.physicalItems.single.bottledGiftQuantity, 1);
      expect(result.cart.evaluate().totalPrice, 3000);
      expect(result.cart.toJsonForOrder().single['amount'], 4);
    });

    test('seven and eight units sit on the gift boundaries', () {
      final seven = expectation(7);
      expect(seven.group.freeQuantity, 1);
      expect(seven.cart.evaluate().totalPrice, 6000);
      expect(seven.cart.toJsonForOrder().single['amount'], 7);
      final eight = expectation(8);
      expect(eight.group.freeQuantity, 2);
      expect(eight.group.paidQuantity, 6);
      expect(eight.cart.evaluate().totalPrice, 6000);
      expect(eight.cart.toJsonForOrder().single['amount'], 8);
    });

    test('adding the fourth unit to three in the cart earns the gift', () {
      final cart = CartProvider();
      addTearDown(cart.dispose);
      expect(cart.addItem(_row(quantity: 3, promotions: threePlusOne)), isTrue);
      expect(cart.evaluate().totalPrice, 3000);
      cart.updateQuantity(500, 4);
      final group = cart.evaluate().activeGroups.single;
      expect(group.freeQuantity, 1);
      expect(cart.evaluate().totalPrice, 3000);
      expect(cart.toJsonForOrder().single['amount'], 4);
      cart.updateQuantity(500, 3);
      expect(cart.evaluate().activeGroups.single.freeQuantity, 0);
      expect(cart.toJsonForOrder().single['amount'], 3);
    });

    test('a 2+1 promotion over three bottles makes the third one free', () {
      final cart = CartProvider();
      addTearDown(cart.dispose);
      expect(cart.addItem(_row(quantity: 3, promotions: [_subtract(1, 2, 1)])),
          isTrue);
      final group = cart.evaluate().activeGroups.single;
      expect(group.freeQuantity, 1);
      expect(group.paidQuantity, 2);
      expect(group.totalOrderQuantity, 3);
      expect(cart.evaluate().totalPrice, 2000);
      expect(cart.toJsonForOrder().single['amount'], 3);
    });

    test('price promotions apply to the paid units only', () {
      final cart = CartProvider();
      addTearDown(cart.dispose);
      expect(
          cart.addItem(_row(quantity: 4, promotions: [
            ...threePlusOne,
            {'type': 'FIXED', 'discount': 100},
          ])),
          isTrue);
      // Three paid units at 900; the fourth is free, not discounted twice.
      expect(cart.evaluate().totalPrice, 2700);
      expect(cart.toJsonForOrder().single['amount'], 4);
    });

    test('the gift follows the instant the cart is evaluated at', () {
      final expiry = DateTime.utc(2027, 1, 1);
      final cart = CartProvider();
      addTearDown(cart.dispose);
      expect(
          cart.addItem(_row(quantity: 4, promotions: [
            _subtract(1, 3, 1)..['end_date'] = expiry.toIso8601String(),
          ])),
          isTrue);
      expect(cart.evaluate(now: expiry).totalPrice, 3000);
      expect(cart.evaluate(now: expiry).toJsonForOrder().single['amount'], 4);
      final after = cart.evaluate(now: expiry.add(const Duration(days: 1)));
      expect(after.totalPrice, 4000);
      expect(after.toJsonForOrder().single['amount'], 4);
    });
  });

  group('cart promotion freshness', () {
    test('the catalogue replaces a stored promotion when the row is touched',
        () async {
      final cart = CartProvider();
      addTearDown(cart.dispose);
      expect(cart.addItem(_row(quantity: 3, promotions: [_subtract(1, 2, 1)])),
          isTrue);
      expect(cart.activeDisplayGroups.single.freeQuantity, 1);
      expect(cart.activeDisplayGroups.single.totalOrderQuantity, 3);
      expect(cart.activeDisplayGroups.single.totalPrice, 2000);

      // The promotion ended server-side: the same item now arrives without it.
      expect(cart.addItem(_row(quantity: 1, promotions: const [])), isTrue);
      final group = cart.activeDisplayGroups.single;
      expect(group.totalQuantity, 4);
      expect(group.freeQuantity, 0);
      expect(group.totalPrice, 4000);
      await cart.ensureSaved();
    });

    test('a repeated order never overwrites live promotions', () async {
      final cart = CartProvider();
      addTearDown(cart.dispose);
      expect(cart.addItem(_row(quantity: 1, promotions: [_subtract(1, 2, 1)])),
          isTrue);
      expect(cart.activeDisplayGroups.single.freeQuantity, 0);
      // Repeat-order rows carry the promotions of the historical order; merging them must not
      // replace the live ones the catalogue already delivered.
      expect(
          cart.addDisplayGroupItems([
            _row(quantity: 2, promotions: const []),
          ]),
          isTrue);
      final group = cart.activeDisplayGroups.single;
      expect(group.totalQuantity, 3);
      expect(group.freeQuantity, 1);
      expect(group.totalPrice, 2000);
      await cart.ensureSaved();
    });

    test('a newly published promotion applies as soon as the item is touched',
        () async {
      final cart = CartProvider();
      addTearDown(cart.dispose);
      expect(cart.addItem(_row(quantity: 1, promotions: const [])), isTrue);
      expect(cart.activeDisplayGroups.single.freeQuantity, 0);

      expect(cart.addItem(_row(quantity: 2, promotions: [_subtract(1, 2, 1)])),
          isTrue);
      final group = cart.activeDisplayGroups.single;
      expect(group.totalQuantity, 3);
      expect(group.freeQuantity, 1);
      expect(group.totalPrice, 2000);
      await cart.ensureSaved();
    });
  });
}

/// The single cart group a test put into a fresh cart, with the cart for price and order checks.
class CartGroupExpectation {
  CartGroupExpectation(this.cart) : group = cart.evaluate().activeGroups.single;

  final CartProvider cart;
  final CartGroupEvaluation group;
}
