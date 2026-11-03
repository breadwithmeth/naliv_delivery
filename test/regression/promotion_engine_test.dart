import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/model/cart_item.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/promotion_engine.dart';
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('promotion award selection', () {
    test('picks the promotion that gifts the most at the current quantity', () {
      final promotions = [_subtract(1, 2, 1), _subtract(2, 3, 1)];
      expect(
          selectSubtractPromotion(promotions, paidQuantity: 3)?.label, '2+1');
      expect(subtractPromotionFreeQuantity(3, promotions), 1);
      expect(
          selectSubtractPromotion(promotions, paidQuantity: 6)?.label, '2+1');
      expect(subtractPromotionFreeQuantity(6, promotions), 3);
    });

    test('prefers the larger gift when the free count ties', () {
      // 6+2 and 3+1 both gift two units at six paid units; the larger gift wins.
      final promotions = [_subtract(1, 6, 2), _subtract(2, 3, 1)];
      expect(
          selectSubtractPromotion(promotions, paidQuantity: 6)?.label, '6+2');
      expect(subtractPromotionFreeQuantity(6, promotions), 2);
    });

    test('ignores promotions outside their validity window', () {
      final expired = _subtract(1, 2, 1)
        ..['end_date'] = '2000-01-01T00:00:00.000Z';
      final future = _subtract(2, 2, 1)
        ..['start_date'] = '2999-01-01T00:00:00.000Z';
      expect(selectSubtractPromotion([expired, future]), isNull);
      expect(subtractPromotionFreeQuantity(4, [expired]), 0);
      final expiredPercent = _percent(3, 10)
        ..['end_date'] = '2000-01-01T00:00:00.000Z';
      expect(
          applyPromotionsToPaidBaseTotal(
              unitPrice: 1000, quantity: 2, promotions: [expiredPercent]),
          2000);
    });

    test('reads the window the server nests under promotion', () {
      final nested = {
        'detail_id': 8692,
        'type': 'SUBTRACT',
        'base_amount': 2,
        'add_amount': 1,
        'name': '2+1',
        'promotion': {'end_promotion_date': '2000-01-01T00:00:00.000Z'},
      };
      expect(selectSubtractPromotion([nested]), isNull);
      final live = {
        'detail_id': 8692,
        'type': 'SUBTRACT',
        'base_amount': 2,
        'add_amount': 1,
        'name': '2+1',
        'promotion': {'end_promotion_date': '2999-01-01T00:00:00.000Z'},
      };
      expect(selectSubtractPromotion([live])?.label, '2+1');
    });

    test('ignores price promotions, malformed entries and unusable amounts',
        () {
      final promotions = [
        _percent(1, 10),
        {'detail_id': 2, 'type': 'SUBTRACT', 'base_amount': 0, 'add_amount': 1},
        {'detail_id': 3, 'type': 'SUBTRACT', 'base_amount': 2, 'add_amount': 0},
        {'detail_id': 4},
      ];
      expect(selectSubtractPromotion(promotions), isNull);
      expect(subtractPromotionFreeQuantity(6, promotions), 0);
      expect(evaluatePromotion(paidQuantity: 6, promotions: promotions).label,
          isNull);
    });
  });

  group('forward and inverse gift rule', () {
    for (final award in [
      _subtract(1, 2, 1),
      _subtract(1, 3, 1),
      _subtract(1, 2, 2),
    ]) {
      test('round trips every paid quantity for ${award['name']}', () {
        final promotions = [award];
        for (var paid = 0; paid <= 12; paid++) {
          final free =
              subtractPromotionFreeQuantity(paid.toDouble(), promotions);
          final physical = paid + free;
          final restored = subtractPromotionPaidQuantityForPhysicalQuantity(
              physical, promotions);
          expect(restored, paid.toDouble(),
              reason: 'paid $paid, free $free, physical $physical');
        }
      });
    }

    test('refuses a physical quantity no paid basket can produce', () {
      expect(
          subtractPromotionPaidQuantityForPhysicalQuantity(
              3, [_subtract(1, 3, 1)]),
          isNull);
      expect(
          subtractPromotionPaidQuantityForPhysicalQuantity(
              4, [_subtract(1, 3, 1)]),
          3);
    });

    test('refuses a candidate that the canonical best award would enlarge', () {
      final promotions = [_subtract(1, 2, 1), _subtract(2, 3, 1)];
      expect(subtractPromotionPaidQuantityForPhysicalQuantity(5, promotions),
          isNull);
      for (var paid = 0; paid <= 16; paid++) {
        final physical =
            paid + subtractPromotionFreeQuantity(paid.toDouble(), promotions);
        final restored = subtractPromotionPaidQuantityForPhysicalQuantity(
            physical, promotions);
        expect(restored, paid.toDouble());
        expect(
            evaluatePromotion(paidQuantity: restored!, promotions: promotions)
                .physicalQuantity,
            physical);
      }
    });

    test('reports qualification progress and the distance to the next gift',
        () {
      final promotions = [_subtract(1, 2, 1)];
      final before = evaluatePromotion(paidQuantity: 1, promotions: promotions);
      expect(before.unlocked, isFalse);
      expect(before.nextGiftIn, 1);
      expect(before.progress, closeTo(0.5, 0.001));
      expect(before.label, '2+1');

      final at = evaluatePromotion(paidQuantity: 2, promotions: promotions);
      expect(at.unlocked, isTrue);
      expect(at.nextGiftIn, 0);
      expect(at.freeQuantity, 1);
      expect(at.physicalQuantity, 3);
    });
  });

  group('physical pour gift', () {
    final threePlusOne = [_subtract(1, 3, 1)];

    test('gift is floor(litres / (base + add)) * add; the rest is paid', () {
      for (final (litres, gift) in [
        (0.0, 0.0),
        (3.0, 0.0),
        (3.999, 0.0),
        (4.0, 1.0),
        (7.0, 1.0),
        (8.0, 2.0),
        (12.0, 3.0),
      ]) {
        final result = evaluatePhysicalGift(
            physicalQuantity: litres, promotions: threePlusOne);
        expect(result.giftQuantity, gift, reason: '$litres l');
        expect(result.paidQuantity, litres - gift, reason: '$litres l');
        expect(
            subtractPromotionGiftWithinPhysicalQuantity(litres, threePlusOne),
            gift);
      }
    });

    test('it agrees with the inverse wherever the inverse exists', () {
      for (final promotions in [
        threePlusOne,
        [_subtract(1, 2, 1), _subtract(2, 3, 1)],
        [_subtract(1, 6, 2), _subtract(2, 3, 1)],
      ]) {
        for (var litres = 0; litres <= 30; litres++) {
          final paid = subtractPromotionPaidQuantityForPhysicalQuantity(
              litres.toDouble(), promotions);
          if (paid == null) continue;
          expect(
              litres -
                  subtractPromotionGiftWithinPhysicalQuantity(
                      litres.toDouble(), promotions),
              paid,
              reason: '$litres l');
        }
      }
    });

    test('the bonus offer exists only when the added litres cost nothing', () {
      PhysicalGiftEvaluation at(double litres, List<Map<String, dynamic>> p) =>
          evaluatePhysicalGift(physicalQuantity: litres, promotions: p);
      expect(at(0, threePlusOne).bonusQuantity, isNull);
      expect(at(0, threePlusOne).nextGiftIn, 4);
      expect(at(2, threePlusOne).bonusQuantity, isNull);
      expect(at(2, threePlusOne).nextGiftIn, 2);
      expect(at(3, threePlusOne).bonusQuantity, 1);
      expect(at(3, threePlusOne).nextGiftIn, 1);
      expect(at(4, threePlusOne).bonusQuantity, isNull);
      expect(at(4, threePlusOne).nextGiftIn, 4);
      expect(at(7, threePlusOne).bonusQuantity, 1);
      expect(at(8, threePlusOne).bonusQuantity, isNull);
      final sixPlusTwo = [_subtract(1, 6, 2)];
      expect(at(6, sixPlusTwo).bonusQuantity, 2);
      expect(at(5, sixPlusTwo).bonusQuantity, isNull);
      expect(at(5, sixPlusTwo).nextGiftIn, 3);
    });

    test('the offer follows the customer-best promotion, not a weaker one', () {
      final promotions = [_subtract(1, 2, 1), _subtract(2, 3, 1)];
      final two =
          evaluatePhysicalGift(physicalQuantity: 2, promotions: promotions);
      expect(two.bonusQuantity, 1); // 2+1 completes at 3 l.
      final three =
          evaluatePhysicalGift(physicalQuantity: 3, promotions: promotions);
      expect(three.giftQuantity, 1);
      expect(three.bonusQuantity, isNull); // 3+1 alone would add no gift here.
      expect(three.nextGiftIn, 3);
    });

    test('ties prefer the larger gift; ended promotions give nothing', () {
      final tie = evaluatePhysicalGift(
          physicalQuantity: 8,
          promotions: [_subtract(1, 6, 2), _subtract(2, 3, 1)]);
      expect(tie.giftQuantity, 2);
      expect(tie.award?.label, '6+2');
      final ended = evaluatePhysicalGift(physicalQuantity: 8, promotions: [
        _subtract(1, 3, 1, endDate: '2000-01-01T00:00:00.000Z'),
      ]);
      expect(ended.giftQuantity, 0);
      expect(ended.award, isNull);
      expect(ended.nextGiftIn, isNull);
      expect(ended.bonusQuantity, isNull);
    });
  });

  group('cart promotion freshness', () {
    test('the catalogue replaces a stored promotion when the row is touched',
        () async {
      final cart = CartProvider();
      expect(cart.addItem(_row(quantity: 2, promotions: [_subtract(1, 2, 1)])),
          isTrue);
      expect(cart.activeDisplayGroups.single.freeQuantity, 1);
      expect(cart.activeDisplayGroups.single.totalOrderQuantity, 3);

      // The promotion ended server-side: the same item now arrives without it.
      expect(cart.addItem(_row(quantity: 1, promotions: const [])), isTrue);
      final group = cart.activeDisplayGroups.single;
      expect(group.totalQuantity, 3);
      expect(group.freeQuantity, 0);
      expect(group.totalPrice, 3000);
    });

    test('a repeated order never overwrites live promotions', () {
      final cart = CartProvider();
      expect(cart.addItem(_row(quantity: 1, promotions: [_subtract(1, 2, 1)])),
          isTrue);
      expect(cart.activeDisplayGroups.single.freeQuantity, 0);
      // Repeat-order rows carry the promotions of the historical order; merging them must not
      // replace the live ones the catalogue already delivered.
      expect(
          cart.addDisplayGroupItems([
            _row(quantity: 1, promotions: const []),
          ]),
          isTrue);
      final group = cart.activeDisplayGroups.single;
      expect(group.totalQuantity, 2);
      expect(group.freeQuantity, 1);
      expect(group.totalPrice, 2000);
    });

    test('a newly published promotion applies as soon as the item is touched',
        () async {
      final cart = CartProvider();
      expect(cart.addItem(_row(quantity: 1, promotions: const [])), isTrue);
      expect(cart.activeDisplayGroups.single.freeQuantity, 0);

      expect(cart.addItem(_row(quantity: 1, promotions: [_subtract(1, 2, 1)])),
          isTrue);
      final group = cart.activeDisplayGroups.single;
      expect(group.totalQuantity, 2);
      expect(group.freeQuantity, 1);
      expect(group.totalPrice, 2000);
    });
  });
}
