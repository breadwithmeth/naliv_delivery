import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/model/cart_item.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _threePlusOne = {
  'detail_id': 1,
  'type': 'SUBTRACT',
  'base_amount': 3,
  'add_amount': 1,
  'name': '3+1',
};

Item _item({List<Map<String, dynamic>> promotions = const [_threePlusOne]}) =>
    Item.fromJson({
      'item_id': 9501,
      'business_id': 1,
      'name': 'Пиво бутылочное',
      'price': 1000,
      'unit': 'шт',
      'amount': 30,
      'promotions': promotions,
    });

Map<String, dynamic> _row(Item item, double quantity) => CartItem(
      itemId: item.itemId,
      name: item.name,
      price: item.price,
      quantity: quantity,
      stepQuantity: 1,
      selectedVariants: const [],
      promotions: [
        for (final promotion in item.promotions ?? const <ItemPromotion>[])
          promotion.toJson(),
      ],
      itemData: item.toJson(),
      maxAmount: item.amount,
    ).toJson();

Future<CartProvider> _restore(
    Object? version, Item item, double quantity) async {
  SharedPreferences.setMockInitialValues({
    'cart_items': jsonEncode({
      if (version != null) 'version': version,
      'business_id': 1,
      'items': [_row(item, quantity)],
    }),
  });
  final cart = CartProvider();
  addTearDown(cart.dispose);
  await cart.loadCart();
  return cart;
}

void main() {
  for (final version in [2, null]) {
    test(
        'a ${version == null ? 'legacy' : 'version-$version'} cart of 3 paid '
        'units of a 3+1 keeps the 4 items it showed, at the same price',
        () async {
      final cart = await _restore(version, _item(), 3);
      final group = cart.activeDisplayGroups.single;
      expect(group.totalOrderQuantity, 4);
      expect(group.freeQuantity, 1);
      expect(cart.getTotalPrice(), 3000);
      expect(cart.toJsonForOrder().single['amount'], 4);

      // Saved at once in the current format, so it is never migrated twice.
      expect(await cart.ensureSaved(), isTrue);
      final stored = jsonDecode(
          (await SharedPreferences.getInstance()).getString('cart_items')!);
      expect(stored['version'], 3);
      expect((stored['items'] as List).single['quantity'], 4);
      final again = CartProvider();
      addTearDown(again.dispose);
      await again.loadCart();
      expect(again.activeDisplayGroups.single.totalOrderQuantity, 4);
      expect(again.getTotalPrice(), 3000);
    });
  }

  test('a current cart of 3 units of a 3+1 stays 3, with no gift', () async {
    final cart = await _restore(3, _item(), 3);
    final group = cart.activeDisplayGroups.single;
    expect(group.totalOrderQuantity, 3);
    expect(group.freeQuantity, 0);
    expect(cart.getTotalPrice(), 3000);
  });

  test('old carts without an earned gift or promotion are left as they were',
      () async {
    final short = await _restore(2, _item(), 2);
    expect(short.activeDisplayGroups.single.totalOrderQuantity, 2);
    expect(short.getTotalPrice(), 2000);
    final plain = await _restore(2, _item(promotions: const []), 3);
    expect(plain.activeDisplayGroups.single.totalOrderQuantity, 3);
    expect(plain.getTotalPrice(), 3000);
  });
}
