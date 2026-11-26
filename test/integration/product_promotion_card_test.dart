import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

import '../support/haptic_calls.dart';

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

Future<CartProvider> _pump(WidgetTester tester, Item item,
    {bool bindBusiness = true}) async {
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final cart = CartProvider();
  addTearDown(cart.dispose);
  if (bindBusiness) await cart.bindBusiness(1);
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
    enableQuantityClicks(tester);
    final impacts = recordHapticCalls(tester);
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
    expect(impacts, [selectionClick]);
    // The nudge is gone and the saving takes its place: a 1 000 ₸ unit was free.
    expect(find.byKey(const ValueKey('product-promotion-add-free')),
        findsNothing);
    expect(tester.widget<Text>(find.byKey(_state)).data,
        'Выгода ${formatTenge(1000)}');
    expect(find.textContaining('в подарок'), findsNothing);
    expect(find.textContaining('Подарок'), findsNothing);
    expect(find.textContaining('Ещё '), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('product stepper confirms first add and accepted later steps',
      (tester) async {
    enableQuantityClicks(tester);
    final impacts = recordHapticCalls(tester);
    final item = _item([_threePlusOne]);
    final cart = await _pump(tester, item);
    final increase = find.byTooltip('Увеличить');
    await Scrollable.ensureVisible(tester.element(increase), alignment: .4);
    await tester.pumpAndSettle();
    for (var quantity = 1; quantity <= 3; quantity++) {
      await tester.pump(const Duration(milliseconds: 90));
      await tester.tap(increase);
      expect(cart.getCatalogQuantity(item), quantity);
      await tester.pumpAndSettle();
      expect(impacts, [lightImpact, ...List.filled(quantity - 1, selectionClick)]);
    }
    expect(cart.activeDisplayGroups.single.freeQuantity, 0);
    expect(cart.getTotalPrice(), 3000);
    await tester.pump(const Duration(milliseconds: 90));
    await tester.tap(increase);
    await tester.pumpAndSettle();
    expect(cart.getCatalogQuantity(item), 4);
    expect(impacts, [lightImpact, selectionClick, selectionClick, selectionClick]);
    expect(cart.activeDisplayGroups.single.freeQuantity, 1);
    expect(cart.getTotalPrice(), 3000);
    expect(cart.toJsonForOrder().single['amount'], 4);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('product minus and free offer confirm accepted quantity edits',
      (tester) async {
    enableQuantityClicks(tester);
    final calls = recordHapticCalls(tester);
    final item = _item([_threePlusOne]);
    final cart = await _pump(tester, item);
    expect(cart.syncItemSelectionQuantity(item, [], 3), isTrue);
    await tester.pumpAndSettle();
    expect(calls, isEmpty);

    final offer = find.byKey(const ValueKey('product-promotion-add-free'));
    await tester.ensureVisible(offer);
    await tester.tap(offer);
    expect(cart.getCatalogQuantity(item), 4);
    expect(calls, [selectionClick]);
    final decrease = find.byTooltip('Уменьшить');
    await tester.ensureVisible(decrease);
    await tester.pump(const Duration(milliseconds: 90));
    await tester.tap(decrease);
    expect(cart.getCatalogQuantity(item), 3);
    expect(calls, [selectionClick, selectionClick]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('loading a persisted cart with the product visible is silent',
      (tester) async {
    final impacts = recordHapticCalls(tester);
    final item = _item([]);
    final storedCart = CartProvider();
    addTearDown(storedCart.dispose);
    await storedCart.bindBusiness(1);
    storedCart.incrementCatalogItem(item);
    expect(await storedCart.ensureSaved(), isTrue);

    final cart = await _pump(tester, item, bindBusiness: false);
    expect(cart.getCatalogQuantity(item), 0);
    await cart.loadCart();
    await tester.pumpAndSettle();
    expect(cart.getCatalogQuantity(item), 1);
    expect(find.text('В корзине: 1 шт'), findsOneWidget);
    expect(impacts, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('shopping still works when the haptics implementation is absent',
      (tester) async {
    final impacts = recordHapticCalls(tester, reply: () {
      throw MissingPluginException();
    });
    final item = _item([]);
    final cart = await _pump(tester, item);
    await tester.tap(find.widgetWithText(FilledButton, 'В корзину'));
    expect(cart.getCatalogQuantity(item), 1);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('В корзине: 1 шт'), findsOneWidget);
    expect(impacts, [lightImpact]);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('desktop adds to the cart without contacting haptics',
      (tester) async {
    final impacts = recordHapticCalls(tester);
    final item = _item([]);
    final cart = await _pump(tester, item);
    await tester.tap(find.widgetWithText(FilledButton, 'В корзину'));
    expect(cart.getCatalogQuantity(item), 1);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('В корзине: 1 шт'), findsOneWidget);
    expect(impacts, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

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
