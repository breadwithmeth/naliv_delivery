import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/core/product_view.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/product/ui/product_page.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/liked_items_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Item _item(List<Map<String, dynamic>> promotions) => Item.fromJson({
      'item_id': 9501,
      'name': 'Пиво бутылочное',
      'price': 1000,
      'unit': 'шт',
      'amount': 30,
      'promotions': promotions,
    });

const _threePlusOne = {
  'detail_id': 1,
  'type': 'SUBTRACT',
  'base_amount': 3,
  'add_amount': 1,
  'name': '3+1',
};

Future<CartProvider> _pump(WidgetTester tester, Item item) async {
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final cart = CartProvider();
  addTearDown(cart.dispose);
  await cart.bindBusiness(1);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: cart),
      ChangeNotifierProvider(create: (_) => LikedItemsProvider()),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: ProductPage(view: ProductView.fromItem(item), businessId: 1),
    ),
  ));
  await tester.pumpAndSettle();
  return cart;
}

String _state(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('product-promotion-state')))
    .data!;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      '3+1 states the rule and follows the units the customer added, never adding any',
      (tester) async {
    final item = _item([_threePlusOne]);
    final cart = await _pump(tester, item);
    expect(find.text('Возьмите 4 шт — платите за 3 шт'), findsOneWidget);
    expect(_state(tester), 'До подарка: ещё 4 шт');
    for (final (quantity, state) in [
      (1.0, 'До подарка: ещё 3 шт'),
      (2.0, 'До подарка: ещё 2 шт'),
      (3.0, 'Добавьте ещё 1 шт — это бесплатно'),
      (4.0, 'Подарок в корзине: 1 шт'),
      (5.0, 'До подарка: ещё 3 шт'),
      (7.0, 'Добавьте ещё 1 шт — это бесплатно'),
      (8.0, 'Подарок в корзине: 2 шт'),
    ]) {
      expect(cart.syncItemSelectionQuantity(item, [], quantity), isTrue);
      await tester.pump();
      expect(_state(tester), state, reason: '$quantity in the cart');
      expect(cart.getCatalogQuantity(item), quantity);
    }
  });

  testWidgets('the stepper adds one unit at a time, so three units cost three',
      (tester) async {
    final item = _item([_threePlusOne]);
    final cart = await _pump(tester, item);
    expect(_state(tester), 'До подарка: ещё 4 шт');
    for (var step = 0; step < 3; step++) {
      cart.incrementCatalogItem(item);
    }
    await tester.pump();
    expect(cart.getCatalogQuantity(item), 3);
    expect(cart.activeDisplayGroups.single.freeQuantity, 0);
    expect(cart.getTotalPrice(), 3000);
    expect(_state(tester), 'Добавьте ещё 1 шт — это бесплатно');
    cart.incrementCatalogItem(item);
    await tester.pump();
    expect(cart.getCatalogQuantity(item), 4);
    expect(cart.activeDisplayGroups.single.freeQuantity, 1);
    expect(cart.getTotalPrice(), 3000);
    expect(cart.toJsonForOrder().single['amount'], 4);
    expect(_state(tester), 'Подарок в корзине: 1 шт');
  });

  testWidgets('the free unit is offered only when it is free and added on tap',
      (tester) async {
    final item = _item([_threePlusOne]);
    final cart = await _pump(tester, item);
    final offer = find.byKey(const ValueKey('product-promotion-add-free'));
    for (final quantity in [1.0, 2.0]) {
      cart.syncItemSelectionQuantity(item, [], quantity);
      await tester.pump();
      expect(offer, findsNothing, reason: '$quantity in the cart');
    }
    cart.syncItemSelectionQuantity(item, [], 3);
    await tester.pump();
    // Offered, not taken: three units stay three until the customer taps.
    expect(cart.getCatalogQuantity(item), 3);
    expect(find.text('+1 шт в подарок'), findsOneWidget);
    await tester.ensureVisible(offer);
    await tester.tap(offer);
    await tester.pump();
    expect(cart.getCatalogQuantity(item), 4);
    expect(cart.getTotalPrice(), 3000);
    expect(offer, findsNothing);
  });

  testWidgets('a page without an active SUBTRACT promotion shows no gift card',
      (tester) async {
    await _pump(
        tester,
        _item([
          {
            'detail_id': 2,
            'type': 'PERCENT',
            'discount': 10,
            'name': '-10%',
          },
          {
            ..._threePlusOne,
            'end_date': '2000-01-01T00:00:00.000Z',
          },
        ]));
    expect(find.byKey(const ValueKey('product-promotion')), findsNothing);
    expect(find.byKey(const ValueKey('product-promotion-state')), findsNothing);
  });
}
