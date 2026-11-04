import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/core/money.dart';
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

const _state = ValueKey('product-promotion-state');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      '3+1 states its rule once; one free nudge appears only at three units',
      (tester) async {
    final item = _item([_threePlusOne]);
    final cart = await _pump(tester, item);
    expect(find.text('Возьмите 4 шт — платите за 3 шт'), findsOneWidget);
    expect(find.byKey(const ValueKey('product-promotion-rule')), findsOneWidget);
    // No progress bar, no countdown, no state line outside the exact threshold.
    expect(find.byKey(const ValueKey('product-promotion-progress')),
        findsNothing);
    expect(find.byKey(_state), findsNothing);

    for (final quantity in [1.0, 2.0]) {
      expect(cart.syncItemSelectionQuantity(item, [], quantity), isTrue);
      await tester.pump();
      expect(find.byKey(_state), findsNothing, reason: '$quantity in the cart');
    }
    // A gift exists at 5 and 6 and the next unit is not free: only the saving shows.
    for (final quantity in [5.0, 6.0]) {
      expect(cart.syncItemSelectionQuantity(item, [], quantity), isTrue);
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(_state)).data,
          'Выгода ${formatTenge(1000)}',
          reason: '$quantity in the cart');
      expect(find.byKey(const ValueKey('product-promotion-add-free')),
          findsNothing);
    }

    for (final quantity in [3.0, 7.0]) {
      expect(cart.syncItemSelectionQuantity(item, [], quantity), isTrue);
      await tester.pump();
      expect(
          find.descendant(
              of: find.byKey(_state), matching: find.text('Ещё 1 шт — бесплатно')),
          findsOneWidget,
          reason: '$quantity in the cart');
      expect(find.byKey(const ValueKey('product-promotion-add-free')),
          findsOneWidget);
      // Offering is not adding.
      expect(cart.getCatalogQuantity(item), quantity);
    }
  });

  testWidgets(
      'taking the offer adds exactly one unit; the gift is then told by the saving only',
      (tester) async {
    final item = _item([_threePlusOne]);
    final cart = await _pump(tester, item);
    expect(cart.syncItemSelectionQuantity(item, [], 3), isTrue);
    await tester.pump();
    expect(cart.getTotalPrice(), 3000);
    expect(cart.activeDisplayGroups.single.freeQuantity, 0);

    await tester.ensureVisible(
        find.byKey(const ValueKey('product-promotion-add-free')));
    await tester.tap(find.byKey(const ValueKey('product-promotion-add-free')));
    await tester.pump();
    expect(cart.getCatalogQuantity(item), 4);
    expect(cart.activeDisplayGroups.single.freeQuantity, 1);
    expect(cart.getTotalPrice(), 3000);
    expect(cart.toJsonForOrder().single['amount'], 4);
    // The nudge is gone and the saving takes its place: a 1 000 ₸ unit was free.
    expect(find.byKey(const ValueKey('product-promotion-add-free')),
        findsNothing);
    expect(tester.widget<Text>(find.byKey(_state)).data,
        'Выгода ${formatTenge(1000)}');
    expect(find.textContaining('в подарок'), findsNothing);
    expect(find.textContaining('Подарок'), findsNothing);
    expect(find.textContaining('Ещё '), findsNothing);
  });

  testWidgets('the stepper adds one unit at a time, so three units cost three',
      (tester) async {
    final item = _item([_threePlusOne]);
    final cart = await _pump(tester, item);
    for (var step = 0; step < 3; step++) {
      cart.incrementCatalogItem(item);
    }
    await tester.pump();
    expect(cart.getCatalogQuantity(item), 3);
    expect(cart.activeDisplayGroups.single.freeQuantity, 0);
    expect(cart.getTotalPrice(), 3000);
    cart.incrementCatalogItem(item);
    await tester.pump();
    expect(cart.getCatalogQuantity(item), 4);
    expect(cart.activeDisplayGroups.single.freeQuantity, 1);
    expect(cart.getTotalPrice(), 3000);
    expect(cart.toJsonForOrder().single['amount'], 4);
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
    expect(find.byKey(_state), findsNothing);
  });
}
