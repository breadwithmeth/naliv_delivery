import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/cart/ui/cart_page.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/bottling_surface_items.dart';

void main() {
  testWidgets('gift litres stay visible when paid bottle quantity changes',
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
    expect(cart.activeDisplayGroups.single.totalOrderQuantity, 4);
    expect(cart.activeDisplayGroups.single.totalQuantity, 3);
    await tester.tap(
        find.descendant(of: row, matching: find.byIcon(Icons.add_rounded)));
    await tester.pump();
    expect(cart.activeDisplayGroups.single.bottleCounts, {93101: 5});
    expect(cart.activeDisplayGroups.single.totalQuantity, 4);
    expect(cart.activeDisplayGroups.single.totalOrderQuantity, 5);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
