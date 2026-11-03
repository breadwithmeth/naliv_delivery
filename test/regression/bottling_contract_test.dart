import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/core/product_view.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/model/cart_item.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/smart_cart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/bottling_surface_items.dart';

Map<String, dynamic> _captured(int id) {
  final fixture = jsonDecode(
          File('test/fixtures/public_bottling_catalog.json').readAsStringSync())
      as Map;
  final sample = (fixture['category_samples'] as List)
      .cast<Map>()
      .singleWhere((sample) => sample['item']['item_id'] == id);
  return Map<String, dynamic>.from(sample['item'] as Map);
}

// Boundary changes are synthetic; the fixture preserves the unmodified GETs.
Item _boundary(
    {List<double> volumes = const [0.5, 1.25],
    double stock = 20,
    String priceType = 'ADD',
    double optionPrice = 100,
    bool taste = false}) {
  final payload = _captured(30318);
  payload['amount'] = stock;
  payload['options'] = [
    if (taste)
      {
        'option_id': 1,
        'name': 'Вкус',
        'required': 1,
        'selection': 'SINGLE',
        'variants': [
          {
            'relation_id': 1,
            'item_id': 900,
            'item_name': 'Классический',
            'parent_item_amount': 3,
            'price_type': 'ADD',
            'price': 0
          },
          {
            'relation_id': 2,
            'item_id': 901,
            'item_name': 'Ягодный',
            'parent_item_amount': 3,
            'price_type': 'ADD',
            'price': 0
          },
        ],
      },
    {
      'option_id': 579,
      'name': 'Литраж',
      'required': 1,
      'selection': 'SINGLE',
      'variants': [
        for (var index = 0; index < volumes.length; index++)
          {
            'relation_id': 2710 + index,
            'item_id': 1091 + index,
            'item_name': 'Бутылка ${volumes[index]} л',
            'parent_item_amount': volumes[index],
            'price_type': priceType,
            'price': optionPrice
          },
      ],
    },
  ];
  return Item.fromJson(payload);
}

Future<CartProvider> _load(Map<String, dynamic> state) async {
  SharedPreferences.setMockInitialValues({'cart_items': jsonEncode(state)});
  final cart = CartProvider();
  await cart.loadCart();
  return cart;
}

Map<String, dynamic> _row(
  Item item,
  SmartCartSelection selection,
  ItemOptionItem bottle,
  int count, {
  Map<int, int>? legacyGifts,
}) =>
    {
      ...CartItem(
        itemId: item.itemId,
        name: item.name,
        price: item.price,
        quantity: selection.volumeForBottle(bottle) * count,
        stepQuantity: selection.volumeForBottle(bottle),
        selectedVariants: selection.buildVariantMaps(bottle: bottle),
        promotions: [
          for (final promotion in item.promotions ?? const <ItemPromotion>[])
            promotion.toJson(),
        ],
        itemData: item.toJson(),
        maxAmount: item.amount,
      ).toJson(),
      if (legacyGifts != null)
        'giftBottleCounts': {
          for (final entry in legacyGifts.entries) '${entry.key}': entry.value,
        },
    };

/// A cart saved by the current build: the rows hold the physical bottles picked.
Future<CartProvider> _restorePersisted(
    Item item, Map<int, int> bottleCounts) async {
  final selection = SmartCartSelection(item);
  return _load({
    'version': 2,
    'business_id': 1,
    'items': [
      for (final bottle in selection.bottleVariants)
        if ((bottleCounts[bottle.relationId] ?? 0) > 0)
          _row(item, selection, bottle, bottleCounts[bottle.relationId]!),
    ],
  });
}

/// A cart saved before pour rows held physical litres: only the paid bottles, plus the gift
/// bottles retained next to them, and no version marker.
Future<CartProvider> _restoreLegacy(
  Item item,
  Map<int, int> paidCounts, {
  Map<int, int>? giftCounts,
}) async {
  final selection = SmartCartSelection(item);
  return _load({
    'business_id': 1,
    'items': [
      for (final bottle in selection.bottleVariants)
        if ((paidCounts[bottle.relationId] ?? 0) > 0)
          _row(item, selection, bottle, paidCounts[bottle.relationId]!,
              legacyGifts: giftCounts),
    ],
  });
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('captured paid litres retain explicit mix, tariff and relation identity',
      () {
    final item = Item.fromJson(_captured(30318));
    final cart = CartProvider();
    expect(cart.syncItemBottleCounts(item, [], {2710: 2}), isTrue);
    expect(cart.activeDisplayGroups.single.bottleCounts, {2710: 2});
    expect(cart.getTotalPrice(), 5420); // 2 × 2600 + 2 × 110.
    expect(cart.toJsonForOrder(), [
      {
        'item_id': 30318,
        'amount': 2.0,
        'options': [
          {'option_item_relation_id': 2710, 'amount': 1}
        ]
      },
    ]);
    expect(cart.syncItemBottleCounts(item, [], {2711: 1}), isTrue);
    expect(cart.getTotalPrice(), 5300); // 2 × 2600 + 100.
  });

  test(
      'captured SUBTRACT gifts litres across mixed rows and orders every picked bottle',
      () {
    final item = Item.fromJson(_captured(1186));
    final cart = CartProvider();
    // 2 × 1 l + 2 × 2 l are 6 picked litres: 2+1 makes two of them free.
    expect(cart.syncItemBottleCounts(item, [], {3094: 2, 3095: 2}), isTrue);
    final group = cart.activeDisplayGroups.single;
    expect(group.totalQuantity, 6);
    expect(group.evaluate().totalQuantity, 4); // paid litres
    expect(group.freeQuantity, 2);
    expect(group.totalOrderQuantity, 6);
    expect(cart.getTotalPrice(), 3980); // 4 × 890 + 2 × 110 + 2 × 100.
    expect(group.subtotalBeforePromotions, 5760);
    expect(group.bottleCounts, {3094: 2, 3095: 2});
    final order = cart.toJsonForOrder();
    expect(order.map((line) => line['amount']), [2.0, 4.0]);
    expect(order.map((line) => line['options']), [
      [
        {'option_item_relation_id': 3094, 'amount': 1}
      ],
      [
        {'option_item_relation_id': 3095, 'amount': 1}
      ],
    ]);
  });

  test(
      'adopting a current promotion re-derives the gift and persists the physical order volume',
      () async {
    final older = Item.fromJson(_captured(1186)..['promotions'] = []);
    final current = Item.fromJson(_captured(1186));
    final cart = CartProvider();
    expect(cart.syncItemBottleCounts(older, [], {3094: 1}), isTrue);
    expect(cart.activeDisplayGroups.single.totalOrderQuantity, 1);

    expect(cart.syncItemBottleCounts(current, [], {3094: 2, 3095: 2}), isTrue);
    expect(cart.getTotalPrice(), 3980);
    expect(cart.activeDisplayGroups.single.totalOrderQuantity, 6);
    expect(cart.toJsonForOrder().map((row) => row['amount']), [2.0, 4.0]);
    await SharedPreferences.getInstance();
    final restored = CartProvider();
    await restored.loadCart();
    expect(restored.getTotalPrice(), 3980);
    expect(restored.activeDisplayGroups.single.freeQuantity, 2);
    expect(restored.toJsonForOrder().map((row) => row['amount']), [2.0, 4.0]);
  });

  test(
      '3+1 pays three litres, gifts the fourth and charges every ordinary tariff',
      () {
    final item = syntheticThreePlusOneSurfaceItem(onlyOneLitre: true);
    final cart = CartProvider();
    // Three litres earn nothing: the bonus litre is the customer's choice.
    expect(cart.syncItemBottleCounts(item, [], {93101: 3}), isTrue);
    var group = cart.activeDisplayGroups.single;
    expect(group.freeQuantity, 0);
    expect(group.totalOrderQuantity, 3);
    expect(group.totalPrice, 3300);
    expect(cart.syncItemBottleCounts(item, [], {93101: 4}), isTrue);
    group = cart.activeDisplayGroups.single;
    expect(group.totalQuantity, 4);
    expect(group.evaluate().totalQuantity, 3);
    expect(group.freeQuantity, 1);
    expect(group.totalOrderQuantity, 4);
    expect(group.bottleCounts, {93101: 4});
    expect(group.optionsTotal, 400);
    expect(group.totalPrice, 3400);
    expect(group.subtotalBeforePromotions, 4400);
    expect(CartItem.calculatePrice(cart.items).totalPrice, 3400);
    expect(cart.toJsonForOrder(), [
      {
        'item_id': 9301,
        'amount': 4.0,
        'options': [
          {'option_item_relation_id': 93101, 'amount': 1}
        ],
      },
    ]);
  });

  test(
      '3+1 with mixed one and one-and-a-half litre bottles gifts a litre of the mix',
      () {
    final item = syntheticThreePlusOneSurfaceItem();
    final cart = CartProvider();
    expect(cart.syncItemBottleCounts(item, [], {93103: 2}), isTrue);
    expect(cart.activeDisplayGroups.single.freeQuantity, 0); // 3 l.
    expect(cart.syncItemBottleCounts(item, [], {93101: 1, 93103: 2}), isTrue);
    final group = cart.activeDisplayGroups.single;
    expect(group.bottleCounts, {93101: 1, 93103: 2});
    expect(group.freeQuantity, 1);
    expect(group.evaluate().totalQuantity, 3);
    expect(group.optionsTotal, 340);
    expect(group.totalPrice, 3340);
    final order = cart.toJsonForOrder();
    expect(order.map((row) => row['amount']), [1.0, 3.0]);
    expect(
        order.map((row) =>
            (row['options'] as List).single['option_item_relation_id']),
        [93101, 93103]);
    expect(
        group.physicalItems
            .map((row) => row.physicalQuantity / row.stepQuantity),
        [1.0, 2.0]);
    // Which bottle carries the free drink is presentation: the litres add up either way.
    expect(
        group.physicalItems.fold<double>(0, (sum, row) => sum + row.quantity),
        3);
    expect(
        group.physicalItems
            .fold<double>(0, (sum, row) => sum + row.bottledGiftQuantity),
        1);
  });

  test('the withdrawn three-litre container is no longer offered', () {
    final selection = SmartCartSelection(capturedPourSurfaceItem());
    expect(selection.knownBottleRelationIds, contains(2713));
    expect(selection.bottleRelationIds, isNot(contains(2713)));
    expect(
        selection.filteredBottles.map((bottle) => bottle.relationId).toList(),
        [2710, 2711]);
    expect(selection.usesPourFlow, isTrue);
  });

  test('persisted 3L litres and tariff stay removable even with zero stock',
      () async {
    final item = capturedPourSurfaceItem().copyWith(amount: 0);
    final cart = await _restorePersisted(item, {2713: 2});
    final group = cart.activeDisplayGroups.single;
    expect(group.totalQuantity, 6);
    expect(group.bottleCounts, {2713: 2});
    expect(group.allocationIssue, isNull);
    expect(cart.items.single.stepQuantity, 3);
    expect(cart.getTotalPrice(), 15900);
    expect(cart.toJsonForOrder().single['amount'], 6);
    expect(group.canIncrease, isFalse);
    cart.incrementDisplayGroup(group);
    cart.updateQuantity(item.itemId, 9, cart.items.single.selectedVariants);
    expect(cart.syncItemBottleCounts(item, [], {2713: 3}), isFalse);
    expect(cart.activeDisplayGroups.single.totalQuantity, 6);
    expect(cart.syncItemBottleCounts(item, [], {2713: 1}), isTrue);
    expect(cart.activeDisplayGroups.single.bottleCounts, {2713: 1});
    expect(cart.getTotalPrice(), 7950);
    expect(cart.syncItemBottleCounts(item, [], {}), isTrue);
    expect(cart.activeDisplayGroups, isEmpty);
  });

  test('withdrawn 3L cannot enter a fresh cart through any add boundary', () {
    final item = capturedPourSurfaceItem();
    final selection = SmartCartSelection(item);
    final bottle = selection.bottleVariants
        .singleWhere((value) => value.relationId == 2713);
    final row = CartItem(
      itemId: item.itemId,
      name: item.name,
      price: item.price,
      quantity: 3,
      stepQuantity: 3,
      selectedVariants: selection.buildVariantMaps(bottle: bottle),
      promotions: const [],
      itemData: item.toJson(),
    );
    final cart = CartProvider();
    expect(cart.syncItemBottleCounts(item, [], {2713: 1}), isFalse);
    expect(cart.addItem(row), isFalse);
    expect(cart.addDisplayGroupItems([row]), isFalse);
    expect(
        cart.syncItemSelectionQuantity(item, row.selectedVariants, 3), isFalse);
    final onlyWithdrawn = _boundary(volumes: [3]);
    expect(SmartCartSelection(onlyWithdrawn).usesPourFlow, isTrue);
    expect(SmartCartSelection(onlyWithdrawn).containerIssue, isNotNull);
    cart.incrementCatalogItem(onlyWithdrawn);
    expect(cart.items, isEmpty);
  });

  test('persisted withdrawn gift capacity preserves ordinary tariff and amount',
      () async {
    final item = capturedPourSurfaceItem(gift: true).copyWith(amount: 0);
    // Nine litres of withdrawn three-litre bottles: 2+1 makes three of them free.
    final cart = await _restorePersisted(item, {3097: 3});
    final group = cart.activeDisplayGroups.single;
    expect(group.totalQuantity, 9);
    expect(group.freeQuantity, 3);
    expect(group.bottleCounts, {3097: 3});
    expect(group.optionsTotal, 450);
    expect(cart.getTotalPrice(), 5790);
    expect(cart.toJsonForOrder().single['amount'], 9);
    final restored = CartProvider();
    await restored.loadCart();
    expect(restored.activeDisplayGroups.single.bottleCounts, {3097: 3});
    expect(restored.toJsonForOrder().single['amount'], 9);
    restored.decrementDisplayGroup(restored.activeDisplayGroups.single);
    expect(restored.activeDisplayGroups.single.totalQuantity, 6);
    expect(restored.activeDisplayGroups.single.freeQuantity, 2);
    expect(restored.getTotalPrice(), 3860); // 4 × 890 + 2 × 150.
    restored.removeDisplayGroup(restored.activeDisplayGroups.single);
    expect(restored.items, isEmpty);
  });

  test(
      'a cart saved with paid litres and retained gift bottles keeps the same bottles',
      () async {
    final item = capturedPourSurfaceItem(gift: true).copyWith(amount: 0);
    final cart = await _restoreLegacy(item, {3097: 2}, giftCounts: {3097: 1});
    final group = cart.activeDisplayGroups.single;
    expect(group.bottleCounts, {3097: 3});
    expect(group.totalQuantity, 9);
    expect(group.freeQuantity, 3);
    expect(cart.getTotalPrice(), 5790);
    expect(cart.toJsonForOrder().single['amount'], 9);
    // The migrated rows are saved at once in the current format.
    expect(await cart.ensureSaved(), isTrue);
    final stored = jsonDecode(
            (await SharedPreferences.getInstance()).getString('cart_items')!)
        as Map;
    expect(stored['version'], 2);
    expect((stored['items'] as List).single.containsKey('giftBottleCounts'),
        isFalse);
    expect(((stored['items'] as List).single as Map)['quantity'], 9);
    final restored = CartProvider();
    await restored.loadCart();
    expect(restored.activeDisplayGroups.single.bottleCounts, {3097: 3});
    expect(restored.getTotalPrice(), 5790);
  });

  test(
      'a legacy gift held in another bottle becomes a physical row of that bottle',
      () async {
    final item = syntheticThreePlusOneSurfaceItem();
    final cart = await _restoreLegacy(item, {93103: 2}, giftCounts: {93101: 1});
    final group = cart.activeDisplayGroups.single;
    expect(group.bottleCounts, {93101: 1, 93103: 2});
    expect(group.freeQuantity, 1);
    expect(group.totalPrice, 3340);
    expect(cart.toJsonForOrder().map((row) => row['amount']), [3.0, 1.0]);
  });

  test(
      'a legacy cart without retained gifts keeps the gift its paid litres earned',
      () async {
    final item = syntheticThreePlusOneSurfaceItem(onlyOneLitre: true);
    final cart = await _restoreLegacy(item, {93101: 3});
    final group = cart.activeDisplayGroups.single;
    expect(group.bottleCounts, {93101: 4});
    expect(group.freeQuantity, 1);
    expect(group.totalPrice, 3400);
  });

  test('legacy rows without a gift or without a promotion are left alone',
      () async {
    final plain = await _restoreLegacy(
        syntheticThreePlusOneSurfaceItem(onlyOneLitre: true), {93101: 2});
    expect(plain.activeDisplayGroups.single.bottleCounts, {93101: 2});
    expect(plain.getTotalPrice(), 2200);
    final noPromotion = await _restoreLegacy(
        Item.fromJson(_captured(1186)..['promotions'] = []), {3094: 3});
    expect(noPromotion.activeDisplayGroups.single.bottleCounts, {3094: 3});
  });

  test('captured 2+1 charges the added bottle at its own ordinary tariff', () {
    final item = Item.fromJson(_captured(1186));
    final cart = CartProvider();
    expect(cart.syncItemBottleCounts(item, [], {3094: 1, 3095: 1}), isTrue);
    final group = cart.activeDisplayGroups.single;
    expect(group.totalQuantity, 3);
    expect(group.freeQuantity, 1);
    expect(group.totalOrderQuantity, 3);
    expect(group.bottleCounts, {3094: 1, 3095: 1});
    expect(group.optionsTotal, 210);
    expect(group.totalPrice, 1990);
    expect(cart.toJsonForOrder().map((row) => row['amount']), [1.0, 2.0]);
  });

  test('edit reload and batch stepping never gift the picked litres again',
      () async {
    final item = syntheticThreePlusOneSurfaceItem(onlyOneLitre: true);
    final cart = CartProvider();
    expect(cart.syncItemBottleCounts(item, [], {93101: 4}), isTrue);
    await SharedPreferences.getInstance();
    final restored = CartProvider();
    await restored.loadCart();
    var group = restored.activeDisplayGroups.single;
    expect(group.bottleCounts, {93101: 4});
    expect(group.freeQuantity, 1);
    expect(restored.syncItemBottleCounts(item, [], group.bottleCounts), isTrue);
    expect(restored.getTotalPrice(), 3400);
    restored.incrementDisplayGroup(restored.activeDisplayGroups.single);
    group = restored.activeDisplayGroups.single;
    expect(group.totalQuantity, 5);
    expect(group.freeQuantity, 1);
    expect(group.bottleCounts, {93101: 5});
    expect(group.totalPrice, 4500);
    restored.decrementDisplayGroup(group);
    group = restored.activeDisplayGroups.single;
    expect(group.totalQuantity, 4);
    expect(group.freeQuantity, 1);
    expect(group.totalPrice, 3400);
    restored.decrementDisplayGroup(group);
    group = restored.activeDisplayGroups.single;
    expect(group.totalQuantity, 3);
    expect(group.freeQuantity, 0);
    expect(group.bottleCounts, {93101: 3});
    expect(group.totalPrice, 3300);
  });

  test(
      'promotion boundary charges gift capacity without discounting any bottle',
      () {
    final payload =
        syntheticThreePlusOneSurfaceItem(onlyOneLitre: true).toJson();
    (payload['promotions'] as List).add(ItemPromotion(
            promotionId: 99,
            name: '10%',
            discountType: 'PERCENT',
            discountValue: 10)
        .toJson());
    final item = Item.fromJson(payload);
    final cart = CartProvider();
    expect(cart.syncItemBottleCounts(item, [], {93101: 2}), isTrue);
    expect(cart.getTotalPrice(), 2000);
    expect(cart.syncItemBottleCounts(item, [], {93101: 4}), isTrue);
    final group = cart.activeDisplayGroups.single;
    expect(group.optionsTotal, 400);
    expect(group.totalPrice, 3100); // 3000 × .9 + four bottles.
    expect(CartItem.calculatePrice(cart.items).discount, 300);
    expect(cart.syncItemBottleCounts(item, [], {93101: 8}), isTrue);
    expect(cart.activeDisplayGroups.single.freeQuantity, 2);
    expect(cart.activeDisplayGroups.single.bottleCounts, {93101: 8});
    expect(cart.getTotalPrice(), 6200);
  });

  test('a gift that is not a whole bottle never blocks the order', () {
    final payload = _boundary(volumes: [2]).toJson();
    payload['promotions'] = [
      ItemPromotion(
              promotionId: 2,
              name: '2+1',
              discountType: 'SUBTRACT',
              discountValue: 0,
              baseAmount: 2,
              addAmount: 1)
          .toJson(),
    ];
    final item = Item.fromJson(payload);
    final selection = SmartCartSelection(item);
    final cart = CartProvider();
    expect(selection.autoBottleBreakdown(2), {2710: 1});
    // Four litres in two 2 l bottles: one litre is free, though no bottle holds exactly that.
    expect(cart.syncItemBottleCounts(item, [], {2710: 2}), isTrue);
    final group = cart.activeDisplayGroups.single;
    expect(group.freeQuantity, 1);
    expect(group.allocationIssue, isNull);
    expect(group.totalOrderQuantity, 4);
    expect(group.totalPrice, 8000); // 3 × 2600 + 2 × 100.
    expect(cart.toJsonForOrder(), [
      {
        'item_id': item.itemId,
        'amount': 4.0,
        'options': [
          {'option_item_relation_id': 2710, 'amount': 1}
        ],
      },
    ]);
    expect(cart.syncItemSelectionQuantity(item, [], 2), isTrue);
    expect(cart.activeDisplayGroups.single.bottleCounts, {2710: 1});
  });

  test(
      'serialized mixed rows conserve exact capacity and charge each container',
      () {
    final item = Item.fromJson(_captured(1186));
    final cart = CartProvider();
    expect(cart.syncItemBottleCounts(item, [], {3094: 2, 3095: 2}), isTrue);
    final group = cart.activeDisplayGroups.single;
    final selection = SmartCartSelection(item);
    final order = cart.toJsonForOrder();
    var capacity = 0.0;
    var containerCharge = 0.0;
    for (final row in order) {
      final id = (row['options'] as List).single['option_item_relation_id'];
      // A legacy cart may hold a withdrawn container, so resolve against every container the
      // store identifies rather than the ones this client still offers.
      final bottle = selection.bottleVariants
          .singleWhere((bottle) => bottle.relationId == id);
      final amount = (row['amount'] as num).toDouble();
      final count = amount / selection.volumeForBottle(bottle);
      expect(count, count.roundToDouble());
      capacity += amount;
      containerCharge += count * bottle.price;
    }
    expect(capacity, 6);
    expect(containerCharge, 420);
    expect(group.totalPrice, 4 * 890 + containerCharge);
  });

  test('batch stepping repeats the whole picked set and recomputes the gift',
      () {
    final item = Item.fromJson(_captured(1186));
    final cart = CartProvider();
    expect(cart.syncItemBottleCounts(item, [], {3094: 2, 3095: 2}), isTrue);
    cart.incrementDisplayGroup(cart.activeDisplayGroups.single);
    var group = cart.activeDisplayGroups.single;
    expect(group.totalQuantity, 9);
    expect(group.freeQuantity, 3);
    expect(group.totalOrderQuantity, 9);
    expect(group.bottleCounts, {3094: 3, 3095: 3});
    expect(group.totalPrice, 5970); // 6 × 890 + 3 × 110 + 3 × 100.
    cart.decrementDisplayGroup(group);
    group = cart.activeDisplayGroups.single;
    expect(group.totalQuantity, 6);
    expect(group.bottleCounts, {3094: 2, 3095: 2});
    expect(group.totalPrice, 3980);
  });

  test('3+1 stock is the picked litres, gift included', () {
    final cart = CartProvider();
    expect(
        cart.syncItemBottleCounts(
            syntheticThreePlusOneSurfaceItem(onlyOneLitre: true, stock: 3),
            [],
            {93101: 4}),
        isFalse);
    expect(cart.items, isEmpty);
    expect(
        cart.syncItemBottleCounts(
            syntheticThreePlusOneSurfaceItem(onlyOneLitre: true, stock: 3),
            [],
            {93101: 3}),
        isTrue);
    expect(
        cart.syncItemBottleCounts(
            syntheticThreePlusOneSurfaceItem(onlyOneLitre: true, stock: 4),
            [],
            {93101: 4}),
        isTrue);
    final before = cart.toJsonForOrder();
    cart.incrementDisplayGroup(cart.activeDisplayGroups.single);
    expect(cart.toJsonForOrder(), before);
    expect(cart.getTotalPrice(), 3400);
  });

  test(
      'fractional volumes allocate exactly and impossible requests retain cart',
      () {
    final item = _boundary();
    final selection = SmartCartSelection(item);
    expect(selection.usesPourFlow, isTrue);
    expect(selection.autoBottleBreakdown(1.75), {2710: 1, 2711: 1});
    expect(() => selection.autoBottleBreakdown(0.25), throwsStateError);
    expect(() => selection.autoBottleBreakdown(1.1), throwsStateError);
    final cart = CartProvider();
    expect(cart.syncItemSelectionQuantity(item, [], 1.75), isTrue);
    final before = cart.items.map((item) => item.toJson()).toList();
    expect(cart.syncItemSelectionQuantity(item, [], 1.1), isFalse);
    expect(cart.items.map((item) => item.toJson()).toList(), before);
    expect(cart.activeDisplayGroups.single.totalQuantity, 1.75);
    expect(cart.getTotalPrice(), 4750);
  });

  test(
      'fractional capacity precision and large real capacities are not filtered',
      () {
    final item = _boundary(volumes: [0.33, 0.475, 1.5, 30], stock: 40);
    final selection = SmartCartSelection(item);
    expect(selection.filteredBottles.map(selection.volumeForBottle),
        [0.33, 0.475, 1.5, 30]);
    expect(selection.autoBottleBreakdown(0.95), {2711: 2});
    expect(selection.volumeLabel(0.475), '0.475 л');
    expect(selection.autoBottleBreakdown(30), {2713: 1});
  });

  test('automatic bottling minimizes count before earlier-capacity preference',
      () {
    final selection = SmartCartSelection(_boundary(volumes: [0.2, 0.3, 0.5]));
    expect(selection.autoBottleBreakdown(1), {2712: 2});
    expect(selection.autoBottleBreakdown(0), isEmpty);
  });

  test('equal bottle minima retain the earliest filtered-capacity preference',
      () {
    final selection = SmartCartSelection(_boundary(volumes: [0.8, 0.4, 0.6]));
    // 0.4 + 0.8 and 0.6 + 0.6 both use two bottles. The existing
    // allocator prefers the earlier filtered capacity (0.4), not input order.
    expect(selection.autoBottleBreakdown(1.2), {2711: 1, 2710: 1});
  });

  test('six-decimal coprime capacities retain exact paid-bottle quantities',
      () {
    final selection =
        SmartCartSelection(_boundary(volumes: [0.475001, 0.333333]));
    expect(selection.autoBottleBreakdown(4.75001), {2710: 10});
    expect(() => selection.autoBottleBreakdown(0.1), throwsStateError);
  });

  test('explicit millilitre label converts capacity without inventing a unit',
      () {
    final payload = _boundary(volumes: [0.5]).toJson();
    final bottle = payload['options'][0]['option_items'][0] as Map;
    bottle['item_name'] = 'Бутылка 500 мл';
    bottle['parent_item_amount'] = 500;
    final selection = SmartCartSelection(Item.fromJson(payload));
    expect(selection.volumeForBottle(selection.filteredBottles.single), 0.5);
    expect(
        selection
            .buildVariantMaps(bottle: selection.filteredBottles.single)
            .single['parent_item_amount'],
        0.5);
    bottle['item_name'] = 'Бутылка №2';
    bottle['parent_item_amount'] = 0;
    final unresolved = SmartCartSelection(Item.fromJson(payload));
    expect(unresolved.usesPourFlow, isFalse);
    expect(unresolved.containerIssue, isNotNull);
  });

  test('taste amount and packaged beer cannot select or step a container', () {
    final pour = _boundary(taste: true);
    final selection = SmartCartSelection(pour);
    expect(selection.containerOption!.optionId, 579);
    expect(pour.effectiveStepQuantity, 1);
    final packaged = pour.toJson()..['unit'] = 'шт';
    expect(SmartCartSelection(Item.fromJson(packaged)).usesPourFlow, isFalse);
  });

  test('replacement replaces base charge and ADD stays outside base discount',
      () {
    final item =
        _boundary(volumes: [1.25], priceType: 'replace', optionPrice: 500);
    final selection = SmartCartSelection(item);
    final row = CartItem(
      itemId: item.itemId,
      name: item.name,
      price: item.price,
      quantity: 1.25,
      stepQuantity: 1.25,
      itemData: item.toJson(),
      selectedVariants: [
        ...selection.buildVariantMaps(bottle: selection.filteredBottles.single),
        {
          'relation_id': 9,
          'price_type': 'ADD',
          'price': 30,
          'parent_item_amount': 1
        },
      ],
      promotions: [
        {'discount_type': 'PERCENT', 'discount_value': 10}
      ],
    );
    expect(row.paidUnitPrice, 400);
    expect(row.optionsTotal, 37.5);
    expect(row.subtotalBeforePromotions, 537.5);
    expect(row.totalPrice, 487.5); // 500 × .9 + 37.5; not 2600 × 1.25 + 500.
  });

  test('fixed discounts cannot transfer unused value between replacement rates',
      () {
    final payload =
        _boundary(volumes: [1, 2], priceType: 'REPLACE', optionPrice: 500)
            .toJson();
    payload['options'][0]['option_items'][1]['price'] = 2000;
    payload['promotions'] = [
      ItemPromotion(
              promotionId: 91,
              name: 'Fixed',
              discountType: 'FIXED',
              discountValue: 750)
          .toJson(),
    ];
    final item = Item.fromJson(payload);
    final cart = CartProvider();
    expect(cart.syncItemBottleCounts(item, [], {2710: 1, 2711: 1}), isTrue);
    expect(cart.items.map((row) => row.totalPrice), [0.0, 500.0]);
    expect(cart.getTotalPrice(), 500);
    expect(CartItem.calculatePrice(cart.items).discount, 2000);
  });

  test('invalid required pour choice preserves the opened configuration', () {
    final item = _boundary(taste: true);
    final original = SmartCartSelection(item).defaultNonBottleVariants;
    final cart = CartProvider();
    expect(cart.syncItemBottleCounts(item, original, {2711: 1}), isTrue);
    final before = cart.items.map((row) => row.toJson()).toList();
    final invalid = [
      Map<String, dynamic>.from(original.single)
        ..['relation_id'] = 0
        ..['variant_id'] = 0,
    ];
    expect(
        cart.syncItemBottleCounts(item, invalid, {2711: 1},
            previousBaseVariants: original),
        isFalse);
    expect(cart.items.map((row) => row.toJson()).toList(), before);
    expect(cart.activeDisplayGroups.single.totalQuantity, 1.25);
  });

  test(
      'invalid required packaged choice cannot report success or delete its draft',
      () {
    final item =
        Item.fromJson(_boundary(taste: true).toJson()..['unit'] = 'шт');
    final original = SmartCartSelection(item).defaultNonBottleVariants;
    final cart = CartProvider();
    expect(cart.syncItemSelectionQuantity(item, original, 1), isTrue);
    final before = cart.items.map((row) => row.toJson()).toList();
    final invalid = [
      for (final variant in original)
        Map<String, dynamic>.from(variant)
          ..['relation_id'] = 0
          ..['variant_id'] = 0,
    ];
    expect(
        cart.syncItemSelectionQuantity(item, invalid, 1,
            previousBaseVariants: original),
        isFalse);
    expect(cart.items.map((row) => row.toJson()).toList(), before);
    expect(cart.activeDisplayGroups.single.totalQuantity, 1);
  });

  test(
      'merge, repeat and persistence do not floor litres to an unrelated option',
      () async {
    final item = _boundary(taste: true);
    final selection = SmartCartSelection(item);
    final variants =
        selection.buildVariantMaps(bottle: selection.filteredBottles[1]);
    CartItem row() => CartItem(
        itemId: item.itemId,
        name: item.name,
        price: item.price,
        quantity: 1.25,
        stepQuantity: 1.25,
        itemData: item.toJson(),
        selectedVariants: variants,
        promotions: []);
    final cart = CartProvider();
    expect(cart.addItem(row()), isTrue);
    expect(cart.addItem(row()), isTrue);
    expect(cart.activeDisplayGroups.single.bottleCounts, {2711: 2});
    cart.incrementDisplayGroup(cart.activeDisplayGroups.single);
    expect(cart.activeDisplayGroups.single.bottleCounts, {2711: 3});
    await cart.loadCart();
    final restored = CartProvider();
    await restored.loadCart();
    expect(restored.activeDisplayGroups.single.totalQuantity, 3.75);
    expect(restored.activeDisplayGroups.single.bottleCounts, {2711: 3});
    expect(restored.getTotalPrice(), 10050);
  });

  test('catalog can restore a fractional bottle after removing its final batch',
      () {
    final item = _boundary();
    final cart = CartProvider();
    cart.incrementCatalogItem(item);
    cart.decrementCatalogItem(item);
    expect(cart.hasActiveItems, isFalse);
    cart.incrementCatalogItem(item);
    expect(cart.activeDisplayGroups.single.bottleCounts, {2710: 1});
    expect(cart.getTotalPrice(), 1400);
  });

  test('whole-container stock checks include gifts and sibling configurations',
      () {
    final payload = _captured(1186)..['amount'] = 5;
    final item = Item.fromJson(payload);
    final cart = CartProvider();
    expect(cart.syncItemBottleCounts(item, [], {3094: 5}), isTrue); // 5 litres.
    final before = cart.items.map((item) => item.toJson()).toList();
    expect(cart.syncItemBottleCounts(item, [], {3094: 6}), isFalse); // 6 > 5.
    expect(cart.items.map((item) => item.toJson()).toList(), before);
    final fractional = _boundary(taste: true, stock: 3);
    final selection = SmartCartSelection(fractional);
    final plain = selection.defaultNonBottleVariants;
    final berry = [
      Map<String, dynamic>.from(plain.single)
        ..['relation_id'] = 2
        ..['variant_id'] = 2
    ];
    final siblings = CartProvider();
    expect(siblings.syncItemBottleCounts(fractional, plain, {2711: 1}), isTrue);
    expect(siblings.syncItemBottleCounts(fractional, berry, {2711: 1}), isTrue);
    expect(
        siblings.syncItemBottleCounts(fractional, plain, {2711: 2}), isFalse);
    expect(siblings.activeDisplayGroups.map((group) => group.bottleCounts), [
      {2711: 1},
      {2711: 1}
    ]);
    expect(
        siblings.syncItemBottleCounts(fractional, berry, {2710: 1},
            previousBaseVariants: plain),
        isFalse); // Collision is atomic.
    expect(siblings.activeDisplayGroups.map((group) => group.totalQuantity),
        [1.25, 1.25]);
  });

  test('catalog compound discount matches the existing cart calculator', () {
    final item = Item(
        itemId: 90,
        name: 'Сыр',
        price: 1000,
        quantity: 0.25,
        stepQuantity: 0.25,
        unit: 'кг',
        promotions: [
          ItemPromotion(
              promotionId: 1,
              name: 'Fixed',
              discountType: 'FIXED',
              discountValue: 100),
          ItemPromotion(
              promotionId: 2,
              name: 'Percent',
              discountType: 'PERCENT',
              discountValue: 10),
        ]);
    expect(ProductView.fromItem(item).price, 810);
    final cart = CartProvider();
    expect(cart.syncItemSelectionQuantity(item, [], 0.5), isTrue);
    expect(cart.getTotalPrice(), 405);
  });
}
