import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/model/cart_item.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/utils/bonus_rules.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/bottling_surface_items.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('one evaluation keeps gift rows pricing and submission on one instant',
      () async {
    final expiry = DateTime.utc(2027, 1, 1);
    final source =
        syntheticThreePlusOneSurfaceItem(onlyOneLitre: true).toJson();
    source['promotions'] = [
      for (final promotion in [
        {'type': 'SUBTRACT', 'base_amount': 3, 'add_amount': 1},
        {'type': 'FIXED', 'discount': 100},
        {'type': 'PERCENT', 'discount': 10},
      ])
        {...promotion, 'end_date': expiry.toIso8601String()},
    ];
    final item = Item.fromJson(source);
    final cart = CartProvider();
    addTearDown(cart.dispose);
    expect(cart.syncItemBottleCounts(item, [], {93101: 3}), isTrue);
    final revision = cart.contentRevision;
    final before = cart.evaluate(now: expiry);
    final group = before.activeGroups.single;
    expect(group.allocationIssue, isNull);
    expect(group.totalQuantity, 3);
    expect(group.freeQuantity, 1);
    expect(group.totalOrderQuantity, 4);
    expect(group.paidBottleCounts, {93101: 3});
    expect(group.bottleCounts, {93101: 4});
    expect(group.physicalItems.single.quantity, 3);
    expect(group.physicalItems.single.bottledGiftQuantity, 1);
    expect(group.price, (
      productSubtotal: 3000.0,
      optionsTotal: 400.0,
      discount: 570.0,
      freeQuantity: 1.0,
      subtotalBeforePromotions: 4400.0,
      totalPrice: 2830.0,
    ));
    expect(before.totalPrice, 2830);
    expect(before.toJsonForOrder(), [
      {
        'item_id': 9301,
        'amount': 4.0,
        'options': [
          {'option_item_relation_id': 93101, 'amount': 1},
        ],
      },
    ]);
    expect(
        BonusRules.calculateEligibleSubtotalForEvaluations(before.activeGroups),
        2830);

    final after =
        cart.evaluate(now: expiry.add(const Duration(microseconds: 1)));
    expect(cart.contentRevision, revision);
    expect(after.activeGroups.single.freeQuantity, 0);
    expect(after.activeGroups.single.bottleCounts, {93101: 3});
    expect(after.totalPrice, 3300);
    expect(after.toJsonForOrder().single['amount'], 3.0);
    expect(before.totalPrice, 2830);
    expect(before.toJsonForOrder().single['amount'], 4.0);
    await cart.ensureSaved();
  });

  test(
      'an operation snapshot does not follow later provider quantity mutations',
      () async {
    final cart = CartProvider();
    addTearDown(cart.dispose);
    expect(cart.addItem(_row(1, price: 100, quantity: 2)), isTrue);
    final evaluation = cart.evaluate();
    cart.updateQuantity(1, 3);
    expect(evaluation.totalPrice, 200);
    expect(evaluation.activeGroups.single.totalQuantity, 2);
    expect(evaluation.toJsonForOrder().single['amount'], 2.0);
    expect(cart.evaluate().totalPrice, 300);
    await cart.ensureSaved();
  });

  test('unrelated groups retain their own discounts in shared preview pricing',
      () {
    final first = _row(1, price: 100, quantity: 2, promotions: [
      {'type': 'PERCENT', 'discount': 10},
    ]);
    final second = _row(2, price: 200, quantity: 1, promotions: [
      {'type': 'FIXED', 'discount': 50},
    ]);
    final price = CartItem.calculatePrice([first, second]);
    expect(price.productSubtotal, 400);
    expect(price.discount, 70);
    expect(price.totalPrice, 330);
  });

  test(
      'catalogue quantity index follows default configuration changes and load',
      () async {
    Item item(int defaultRelation) => Item(
          itemId: 8401,
          name: 'Товар',
          price: 100,
          amount: 20,
          unit: 'шт',
          stepQuantity: 1,
          options: [
            ItemOption(
              optionId: 84,
              name: 'Вкус',
              required: 1,
              selection: 'SINGLE',
              optionItems: [
                for (final relation in [defaultRelation, 3 - defaultRelation])
                  ItemOptionItem(
                    relationId: relation,
                    itemId: 8400 + relation,
                    priceType: 'ADD',
                    itemName: 'Вкус $relation',
                    price: 0,
                    parentItemAmount: 1,
                  ),
              ],
            ),
          ],
        );
    final first = item(1);
    final second = item(2);
    final cart = CartProvider();
    addTearDown(cart.dispose);
    cart.incrementCatalogItem(first);
    expect(cart.getCatalogQuantity(first), 1);
    expect(cart.getCatalogQuantity(second), 0);
    cart.incrementCatalogItem(second);
    cart.incrementCatalogItem(second);
    expect(cart.getCatalogQuantity(first), 1);
    expect(cart.getCatalogQuantity(second), 2);
    expect(cart.getCatalogQuantityForKey('8401|1'), 1);
    expect(cart.getCatalogQuantityForKey('8401|2'), 2);
    expect(cart.getCatalogQuantityForKey('8401|999'), 0);
    expect(await cart.ensureSaved(), isTrue);
    final restarted = CartProvider();
    addTearDown(restarted.dispose);
    await restarted.ensureLoaded();
    expect(restarted.getCatalogQuantity(first), 1);
    expect(restarted.getCatalogQuantity(second), 2);
    expect(restarted.getCatalogQuantityForKey('8401|1'), 1);
    expect(restarted.getCatalogQuantityForKey('8401|2'), 2);
    restarted.removeDisplayGroup(restarted.displayGroups.first);
    expect(restarted.getCatalogQuantity(first), 0);
    expect(restarted.getCatalogQuantity(second), 2);
    expect(restarted.getCatalogQuantityForKey('8401|1'), 0);
    expect(restarted.getCatalogQuantityForKey('8401|2'), 2);
    restarted.clearCart();
    expect(restarted.getCatalogQuantity(second), 0);
    expect(restarted.getCatalogQuantityForKey('8401|2'), 0);
    await restarted.ensureSaved();
  });
}

CartItem _row(int id,
        {required double price,
        required double quantity,
        List<Map<String, dynamic>> promotions = const []}) =>
    CartItem(
      itemId: id,
      name: 'Товар $id',
      price: price,
      quantity: quantity,
      stepQuantity: 1,
      selectedVariants: const [],
      promotions: promotions,
    );
