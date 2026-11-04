import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/cart/ui/cart_page.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/bottling_surface_items.dart';

void main() {
  testWidgets('the gift is a short chip that follows the picked bottles',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await cart.bindBusiness(1);
    expect(
        cart.syncItemBottleCounts(
            syntheticThreePlusOneSurfaceItem(onlyOneLitre: true),
            [],
            {93101: 4}),
        isTrue);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: cart,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const CartPage(),
      ),
    ));
    await tester.pump();
    final row = find.byKey(const ValueKey('cart-row-0'));
    expect(cart.activeDisplayGroups.single.totalOrderQuantity, 4);
    expect(cart.activeDisplayGroups.single.freeQuantity, 1);
    expect(cart.activeDisplayGroups.single.evaluate().paidQuantity, 3);
    expect(find.descendant(of: row, matching: find.text('1 л в подарок')),
        findsOneWidget);
    expect(find.textContaining('Тара для подарка'), findsNothing);
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
    expect(find.descendant(of: row, matching: find.text('2 л в подарок')),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('three litres of a 3+1 are all paid; the fourth is the gift',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await cart.bindBusiness(1);
    expect(
        cart.syncItemBottleCounts(
            syntheticThreePlusOneSurfaceItem(onlyOneLitre: true),
            [],
            {93101: 3}),
        isTrue);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: cart,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const CartPage(),
      ),
    ));
    await tester.pump();
    final row = find.byKey(const ValueKey('cart-row-0'));
    final group = cart.activeDisplayGroups.single;
    expect(group.totalOrderQuantity, 3);
    expect(group.freeQuantity, 0);
    expect(group.evaluate().paidQuantity, 3);
    expect(cart.toJsonForOrder().single['amount'], 3);
    expect(cart.evaluate().totalPrice, 3300); // 3 l at 1000 + 3 bottles at 100.
    // No gift yet, only an offer the customer may take.
    expect(find.text('1 л в подарок'), findsNothing);
    final offer = find.byKey(ValueKey('cart-free-offer-${group.key}'));
    expect(find.descendant(of: offer, matching: find.text('+1 л в подарок')),
        findsOneWidget);

    await tester.tap(offer);
    await tester.pump();
    final withGift = cart.activeDisplayGroups.single;
    expect(withGift.bottleCounts, {93101: 4});
    expect(withGift.freeQuantity, 1);
    expect(cart.toJsonForOrder().single['amount'], 4);
    // The fourth litre costs only its bottle: 3 paid litres + 4 bottles.
    expect(cart.evaluate().totalPrice, 3400);
    expect(find.descendant(of: row, matching: find.text('1 л в подарок')),
        findsOneWidget);
    expect(offer, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
