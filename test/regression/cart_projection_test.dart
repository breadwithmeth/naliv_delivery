import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/model/cart_item.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/smart_cart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/bottling_surface_items.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('listeners see current groups and totals after every row mutation', () {
    final cart = CartProvider();
    addTearDown(cart.dispose);
    final changes = <List<Object>>[];
    cart.addListener(() => changes.add([
          cart.displayGroups.map((group) => group.itemId).toList(),
          cart.displayItemCount,
          cart.getTotalPrice(),
        ]));
    expect(cart.displayGroups, isEmpty);
    expect(cart.hasActiveItems, isFalse);
    expect(cart.getTotalPrice(), 0);

    expect(cart.addItem(_row(1, 1)), isTrue);
    expect(cart.addItem(_row(2, 2)), isTrue);
    expect(cart.addItem(_row(1, 1)), isTrue);
    expect(cart.getTotalQuantityForItem(1), 2);
    cart.updateQuantity(1, 0);
    expect(cart.displayGroups.map((group) => group.itemId), [1, 2]);
    expect(cart.activeDisplayGroups.single.itemId, 2);
    cart.updateQuantity(1, 1);
    cart.removeItem(1);
    expect(cart.getTotalQuantityForItem(1), 0);
    cart.clearCart();
    expect(cart.toJsonForOrder(), isEmpty);
    expect(changes, [
      [
        [1],
        1,
        10.0
      ],
      [
        [1, 2],
        2,
        50.0
      ],
      [
        [1, 2],
        2,
        60.0
      ],
      [
        [1, 2],
        1,
        40.0
      ],
      [
        [1, 2],
        2,
        50.0
      ],
      [
        [2],
        1,
        40.0
      ],
      [<int>[], 0, 0.0],
    ]);
  });

  test('loading replaces a previously read projection and merges saved rows',
      () async {
    SharedPreferences.setMockInitialValues({
      'cart_items': jsonEncode([
        _row(1, 1).toJson(),
        _row(1, 2).toJson(),
        _row(2, 0).toJson(),
      ]),
    });
    final cart = CartProvider();
    addTearDown(cart.dispose);
    expect(cart.displayGroups, isEmpty);
    expect(cart.displayItemCount, 0);
    expect(cart.getTotalPrice(), 0);

    await cart.loadCart();
    expect(cart.displayGroups.map((group) => group.itemId), [1, 2]);
    expect(cart.activeDisplayGroups.single.totalQuantity, 3);
    expect(cart.displayItemCount, 1);
    expect(cart.getTotalPrice(), 30);
    expect(cart.getTotalQuantityForItem(1), 3);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'cart_items',
        jsonEncode([
          _row(2, 2).toJson(),
          _row(3, 1).toJson(),
          _row(1, 0).toJson(),
        ]));
    await cart.loadCart();
    expect(cart.displayGroups.map((group) => group.itemId), [2, 3, 1]);
    expect(cart.activeDisplayGroups.map((group) => group.itemId), [2, 3]);
    expect(cart.displayItemCount, 2);
    expect(cart.getTotalPrice(), 70);
    expect(cart.getTotalQuantityForItem(1), 0);
    expect(cart.toJsonForOrder().map((row) => row['amount']), [2.0, 1.0]);
  });

  test('paid-volume changes publish the repaired retained gift allocation', () {
    final item = syntheticThreePlusOneSurfaceItem(onlyOneLitre: true);
    final selection = SmartCartSelection(item);
    final row = CartItem(
      itemId: item.itemId,
      name: item.name,
      price: item.price,
      quantity: 3,
      stepQuantity: 1,
      giftBottleCounts: {93101: 1},
      selectedVariants:
          selection.buildVariantMaps(bottle: selection.filteredBottles.single),
      promotions:
          item.promotions!.map((promotion) => promotion.toJson()).toList(),
      itemData: item.toJson(),
    );
    final cart = CartProvider();
    addTearDown(cart.dispose);
    expect(cart.addDisplayGroupItems([row]), isTrue);
    expect(cart.activeDisplayGroups.single.bottleCounts, {93101: 4});
    expect(cart.getTotalPrice(), 3400);

    cart.updateQuantity(item.itemId, 2, row.selectedVariants);
    final reduced = cart.activeDisplayGroups.single;
    expect(reduced.allocationIssue, isNull);
    expect(reduced.totalQuantity, 2);
    expect(reduced.freeQuantity, 0);
    expect(reduced.bottleCounts, {93101: 2});
    expect(cart.getTotalPrice(), 2200);
    expect(cart.toJsonForOrder().single['amount'], 2.0);

    cart.updateQuantity(item.itemId, 6, row.selectedVariants);
    expect(cart.activeDisplayGroups.single.bottleCounts, {93101: 8});
    expect(cart.getTotalPrice(), 6800);
    expect(cart.toJsonForOrder().single['amount'], 8.0);
  });

  test('stock reservations follow refused edits, removal and zero restoration',
      () {
    final payload =
        syntheticThreePlusOneSurfaceItem(onlyOneLitre: true, stock: 5).toJson();
    (payload['options'] as List).add(ItemOption(
      optionId: 8,
      name: 'Вкус',
      required: 1,
      selection: 'SINGLE',
      optionItems: [
        for (final id in [41, 42, 43])
          ItemOptionItem(
            relationId: id,
            itemId: 900 + id,
            itemName: 'Вкус $id',
            priceType: 'ADD',
            price: 0,
            parentItemAmount: 1,
          ),
      ],
    ).toJson());
    final item = Item.fromJson(payload);
    final selection = SmartCartSelection(item);
    final plain = selection.defaultNonBottleVariants;
    final berry = _flavor(plain, 42);
    final edited = _flavor(plain, 43);
    final cart = CartProvider();
    addTearDown(cart.dispose);
    expect(cart.syncItemBottleCounts(item, plain, {93101: 3}), isTrue);
    expect(cart.syncItemBottleCounts(item, berry, {93101: 1}), isTrue);
    expect(cart.displayItemCount, 2);
    expect(cart.getTotalPrice(), 4500);
    final before = cart.toJsonForOrder();

    expect(cart.syncItemBottleCounts(item, plain, {93101: 4}), isFalse);
    expect(
        cart.syncItemBottleCounts(item, berry, {93101: 3},
            previousBaseVariants: plain),
        isFalse);
    expect(cart.toJsonForOrder(), before);
    expect(cart.getTotalPrice(), 4500);

    cart.removeDisplayGroup(cart.activeDisplayGroups.last);
    expect(cart.displayItemCount, 1);
    expect(cart.syncItemBottleCounts(item, plain, {93101: 4}), isTrue);
    expect(cart.activeDisplayGroups.single.totalOrderQuantity, 5);
    expect(
        cart.syncItemBottleCounts(item, edited, {93101: 3},
            previousBaseVariants: plain),
        isTrue);
    expect(cart.getCatalogQuantity(item), 0);
    expect(
        cart.displayGroups.single.key, selection.displayKeyForVariants(edited));
    expect(cart.syncItemBottleCounts(item, berry, {93101: 1}), isTrue);

    cart.updateDisplayGroupBottleCounts(cart.displayGroups.first, {93101: 0});
    expect(cart.displayGroups.map((group) => group.key), [
      selection.displayKeyForVariants(edited),
      selection.displayKeyForVariants(berry),
    ]);
    expect(cart.displayGroups.first.totalQuantity, 0);
    expect(cart.activeDisplayGroups.single.totalOrderQuantity, 1);
    expect(cart.getTotalPrice(), 1100);
    expect(cart.syncItemBottleCounts(item, edited, {93101: 3}), isTrue);
    expect(cart.activeDisplayGroups.map((group) => group.totalOrderQuantity),
        [4.0, 1.0]);
    expect(cart.getTotalPrice(), 4500);
  });
}

CartItem _row(int id, double quantity) => CartItem(
      itemId: id,
      name: 'Товар $id',
      price: id * 10.0,
      quantity: quantity,
      stepQuantity: 1,
      selectedVariants: const [],
      promotions: const [],
    );

List<Map<String, dynamic>> _flavor(
        List<Map<String, dynamic>> variants, int id) =>
    [
      Map<String, dynamic>.from(variants.single)
        ..['variant_id'] = id
        ..['relation_id'] = id
        ..['item_id'] = 900 + id
        ..['item_name'] = 'Вкус $id',
    ];
