import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/core/product_view.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/cart/ui/cart_page.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/ui/product_card.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Item _item({List<Map<String, dynamic>> promotions = const []}) =>
    Item.fromJson({
      'item_id': 91,
      'name': 'Aperol',
      'price': 13170,
      'unit': 'л',
      'amount': 50,
      'promotions': promotions,
    });

const _giftPromotion = {
  'detail_id': 8692,
  'type': 'SUBTRACT',
  'base_amount': 2,
  'add_amount': 1,
  'name': '2+1',
  'promotion': {
    'marketing_promotion_id': 355,
    'name': 'Выгодный розлив',
    'end_promotion_date': '2999-01-01T00:00:00.000Z',
  },
};

Future<void> _pumpCard(WidgetTester tester, Item item) async {
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Center(child: ProductCard.fromView(ProductView.fromItem(item))),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a gift promotion is advertised on the card', (tester) async {
    await _pumpCard(tester, _item(promotions: [_giftPromotion]));
    expect(find.text('2+1'), findsOneWidget);
  });

  testWidgets('a price discount and a gift promotion can share the card',
      (tester) async {
    await _pumpCard(
        tester,
        _item(promotions: [
          {
            'detail_id': 1,
            'type': 'DISCOUNT',
            'discount': 10,
            'name': '-10%',
          },
          _giftPromotion,
        ]));
    expect(find.text('-10%'), findsOneWidget);
    expect(find.text('2+1'), findsOneWidget);
  });

  testWidgets('a discounted card keeps the bonus chip', (tester) async {
    // The frames show `-10%` and `+100` together; the bonus must survive a price discount.
    await _pumpCard(
        tester,
        _item(promotions: [
          {
            'detail_id': 1,
            'type': 'DISCOUNT',
            'discount': 10,
            'name': '-10%',
          },
        ]));
    expect(find.text('-10%'), findsOneWidget);
    expect(find.textContaining('+'), findsOneWidget);
  });

  testWidgets('an item without promotions advertises nothing', (tester) async {
    await _pumpCard(tester, _item());
    expect(find.text('2+1'), findsNothing);
    expect(find.text('-10%'), findsNothing);
  });

  testWidgets('an expired gift promotion is not advertised', (tester) async {
    await _pumpCard(
        tester,
        _item(promotions: [
          {
            'detail_id': 1,
            'type': 'SUBTRACT',
            'base_amount': 2,
            'add_amount': 1,
            'name': '2+1',
            'promotion': {'end_promotion_date': '2000-01-01T00:00:00.000Z'},
          },
        ]));
    expect(find.text('2+1'), findsNothing);
  });


  group('cart gift line', () {
    testWidgets('free units appear as their own 0 ₸ line with the rule',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final item = _item(promotions: [_giftPromotion]);
      final cart = CartProvider();
      await cart.bindBusiness(1);
      cart.incrementCatalogItem(item);
      cart.incrementCatalogItem(item);
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(ChangeNotifierProvider<CartProvider>.value(
        value: cart,
        child: MaterialApp(theme: AppTheme.light(), home: const CartPage()),
      ));
      await tester.pumpAndSettle();

      final group = cart.activeDisplayGroups.single;
      expect(group.freeQuantity, 1);
      expect(find.byKey(ValueKey('cart-gift-${group.key}')), findsOneWidget);
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('cart-gift-label')))
              .data,
          'Подарок · 1 л');
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('cart-gift-price')))
              .data,
          '0 ₸');
      // The gift is not charged: two paid litres at 13 170 ₸.
      expect(cart.getTotalPrice(), 26340);
    });

    testWidgets('a cart without gifts shows no gift line', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final cart = CartProvider();
      await cart.bindBusiness(1);
      cart.incrementCatalogItem(_item());
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(ChangeNotifierProvider<CartProvider>.value(
        value: cart,
        child: MaterialApp(theme: AppTheme.light(), home: const CartPage()),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cart-gift-label')), findsNothing);
    });
  });
}
