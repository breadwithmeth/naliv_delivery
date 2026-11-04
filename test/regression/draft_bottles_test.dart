import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/model/cart_item.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/utils/draft_bottles.dart';
import 'package:naliv_delivery/utils/smart_cart.dart';

const _one = DraftBottle(
    itemId: 501,
    name: 'Пластиковая бутылка 1л с крышкой',
    price: 100,
    litres: 1);
const _two = DraftBottle(
    itemId: 502,
    name: 'Пластиковая бутылка 2л с крышкой',
    price: 120,
    litres: 2);
const _set = DraftBottleSet(oneLitre: _one, twoLitre: _two);

CartItem _draft(double litres,
    {String name = 'Пиво Wukong светлое розлив', int itemId = 77}) {
  final item = Item.fromJson({
    'item_id': itemId,
    'business_id': 11,
    'name': name,
    'price': 1000,
    'unit': 'л',
    'amount': 50,
    'promotions': [
      {
        'detail_id': 1,
        'type': 'SUBTRACT',
        'base_amount': 3,
        'add_amount': 1,
        'name': '3+1',
      },
    ],
  });
  return CartItem(
    itemId: item.itemId,
    name: item.name,
    price: item.price,
    quantity: litres,
    stepQuantity: 1,
    selectedVariants: const [],
    promotions: [for (final p in item.promotions!) p.toJson()],
    itemData: item.toJson(),
    maxAmount: item.amount,
  );
}

CartEvaluation _evaluate(List<CartItem> rows) =>
    CartEvaluation(CartDisplayGroup.groupItems(rows));

Map<Object?, Object?> _lines(CartEvaluation evaluation) => {
      for (final line in evaluation.toJsonForOrder())
        line['item_id']: line['amount'],
    };

void main() {
  setUp(() => DraftBottleCatalogue.instance.debugSet(11, _set));
  tearDown(() => DraftBottleCatalogue.instance.debugSet(11, null));

  test('the fewest 2 л and 1 л bottles hold the litres, part litres round up',
      () {
    expect(draftBottlesFor(1, _set), {_one: 1});
    expect(draftBottlesFor(3, _set), {_two: 1, _one: 1});
    expect(draftBottlesFor(4, _set), {_two: 2});
    expect(draftBottlesFor(2.5, _set), {_two: 1, _one: 1});
    expect(draftBottlesFor(0, _set), isEmpty);
    expect(draftBottlesFor(3, const DraftBottleSet(oneLitre: _one)), {_one: 3});
    expect(draftBottlesFor(3, const DraftBottleSet(twoLitre: _two)), {_two: 2});
  });

  test('a draft drink is priced and ordered with its bottles, gift litre too',
      () {
    final three = _evaluate([_draft(3)]);
    // 3 л: 3 000 ₸ drink + one 2 л (120) and one 1 л (100) bottle.
    expect(three.totalPrice, 3220);
    expect(three.groups.single.bottleBreakdownLabel, '2 л + 1 л');
    expect(_lines(three), {77: 3.0, 502: 1, 501: 1});

    final four = _evaluate([_draft(4)]);
    // The 4th litre is free; its bottles are not: two 2 л bottles.
    expect(four.totalPrice, 3240);
    expect(four.price.subtotalBeforePromotions, 4240);
    expect(_lines(four), {77: 4.0, 502: 2});
  });

  test('two draft drinks share bottle lines; other items get no bottles', () {
    final both = _evaluate([
      _draft(1),
      _draft(1, name: 'Квас розлив Живой', itemId: 78),
    ]);
    expect(_lines(both), {77: 1.0, 78: 1.0, 501: 2});

    final plain = _evaluate([_draft(2, name: 'Пиво Bud светлое ж/б')]);
    expect(plain.groups.single.draftBottles, isEmpty);
    expect(plain.totalPrice, 2000);
  });

  test('unknown store bottles block ordering instead of pricing without them',
      () {
    DraftBottleCatalogue.instance.debugSet(11, null);
    final evaluation = _evaluate([_draft(3)]);
    expect(evaluation.draftBottlesPending, isTrue);
    expect(evaluation.groups.single.draftBottles, isEmpty);
  });

  test('the store\'s own bottle names parse; other sizes are not used', () {
    int? litres(String name) => DraftBottleCatalogue.bottleLitres(name);
    expect(litres('Пластиковая бутылка 1л с крышкой'), 1);
    expect(litres('Пластиковая бутылка 2л'), 2);
    expect(litres('ПЛАСТИКОВАЯ БУТЫЛКА 2 л'), 2);
    expect(litres('Пластиковая бутылка 1.5 с крышкой'), isNull);
    expect(litres('Пластиковая бутылка 3л с крышкой'), isNull);
    expect(litres('Пиво бут WUKONG JU светлое 0.5'), isNull);
  });
}
