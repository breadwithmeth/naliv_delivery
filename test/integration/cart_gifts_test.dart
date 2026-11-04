import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/core/money.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/cart/ui/cart_page.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/bottling_surface_items.dart';

Future<CartProvider> _cartWithLitres(WidgetTester tester, int litres) async {
  SharedPreferences.setMockInitialValues({});
  final cart = CartProvider();
  addTearDown(cart.dispose);
  await cart.bindBusiness(1);
  expect(
      cart.syncItemBottleCounts(
          syntheticThreePlusOneSurfaceItem(onlyOneLitre: true),
          [],
          {93101: litres}),
      isTrue);
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: cart,
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const CartPage(),
    ),
  ));
  await tester.pump();
  return cart;
}

void main() {
  testWidgets(
      'a gift that exists is told by the struck list price alone, never by a box',
      (tester) async {
    final cart = await _cartWithLitres(tester, 4);
    final group = cart.activeDisplayGroups.single;
    final row = find.byKey(const ValueKey('cart-row-0'));
    expect(group.totalOrderQuantity, 4);
    expect(group.freeQuantity, 1);
    expect(group.evaluate().paidQuantity, 3);
    // 3 paid litres and 4 bottles cost 3 400 ₸; without the gift it would be 4 400 ₸.
    expect(
        tester
            .widget<Text>(find.descendant(
                of: row,
                matching: find.byKey(ValueKey('cart-list-price-${group.key}'))))
            .data,
        formatTenge(4400));
    expect(find.descendant(of: row, matching: find.text(formatTenge(3400))),
        findsWidgets);
    expect(find.textContaining('в подарок'), findsNothing);
    expect(find.byKey(ValueKey('cart-gift-${group.key}')), findsNothing);
    // At four litres the next litre would not be free: no nudge.
    expect(find.byKey(ValueKey('cart-free-offer-${group.key}')), findsNothing);

    await tester.tap(
        find.descendant(of: row, matching: find.byIcon(Icons.add_rounded)));
    await tester.pump();
    expect(cart.activeDisplayGroups.single.bottleCounts, {93101: 5});
    expect(cart.activeDisplayGroups.single.totalQuantity, 5);
    expect(cart.activeDisplayGroups.single.freeQuantity, 1);
    expect(cart.activeDisplayGroups.single.totalOrderQuantity, 5);
    for (var step = 0; step < 3; step++) {
      await tester.tap(
          find.descendant(of: row, matching: find.byIcon(Icons.add_rounded)));
      await tester.pump();
    }
    expect(cart.activeDisplayGroups.single.bottleCounts, {93101: 8});
    expect(cart.activeDisplayGroups.single.freeQuantity, 2);
    expect(find.textContaining('в подарок'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'three litres of a 3+1 are all paid; the row offers the fourth for its bottle only',
      (tester) async {
    final cart = await _cartWithLitres(tester, 3);
    final group = cart.activeDisplayGroups.single;
    expect(group.totalOrderQuantity, 3);
    expect(group.freeQuantity, 0);
    expect(group.evaluate().paidQuantity, 3);
    expect(cart.toJsonForOrder().single['amount'], 3);
    expect(cart.evaluate().totalPrice, 3300); // 3 l at 1000 + 3 bottles at 100.
    expect(find.byKey(ValueKey('cart-list-price-${group.key}')), findsNothing);
    expect(find.textContaining('в подарок'), findsNothing);

    // The offer is priced by the real increment: the free litre costs its 100 ₸ bottle.
    final offer = find.byKey(ValueKey('cart-free-offer-${group.key}'));
    expect(offer, findsOneWidget);
    expect(
        find.descendant(
            of: offer, matching: find.text('Ещё 1 л за 100 ₸ — только бутылка')),
        findsOneWidget);
    // Offering is not adding: nothing changed until the customer asks.
    expect(cart.toJsonForOrder().single['amount'], 3);

    await tester.tap(find.byKey(ValueKey('cart-free-offer-add-${group.key}')));
    await tester.pump();
    final withGift = cart.activeDisplayGroups.single;
    expect(withGift.bottleCounts, {93101: 4});
    expect(withGift.freeQuantity, 1);
    expect(cart.toJsonForOrder().single['amount'], 4);
    // The fourth litre costs only its bottle: 3 paid litres + 4 bottles.
    expect(cart.evaluate().totalPrice, 3400);
    expect(find.byKey(ValueKey('cart-free-offer-${group.key}')), findsNothing);
    expect(find.byKey(ValueKey('cart-list-price-${group.key}')), findsOneWidget);
    expect(find.textContaining('в подарок'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
