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
    expect(cart.activeDisplayGroups.single.evaluate().totalQuantity, 3);
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
}
