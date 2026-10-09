import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/cart/ui/cart_page.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/pages/product_detail_page.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('keeps display order stable when regrouping an existing item', () async {
    final first = _pourItem();
    final second = Item(
        itemId: 802,
        name: 'Чипсы',
        price: 500,
        amount: 10,
        quantity: 1,
        unit: 'шт.');
    final cart = CartProvider();
    addTearDown(cart.dispose);
    expect(await cart.bindBusiness(1), isTrue);
    cart
      ..syncItemBottleCounts(first, [], {1: 1})
      ..incrementCatalogItem(second);
    expect(
        cart.displayGroups.map((group) => group.itemId).toList(), [801, 802]);
    cart.syncItemBottleCounts(first, [], {2: 1});
    expect(
        cart.displayGroups.map((group) => group.itemId).toList(), [801, 802]);
  });

  testWidgets(
      'cart quantity controls mutate quantity without entering the editor',
      (tester) async {
    final item = Item(
        itemId: 703,
        name: 'Тоник',
        price: 700,
        amount: 4,
        quantity: 1,
        unit: 'шт.');
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await cart.bindBusiness(1);
    cart.syncItemSelectionQuantity(item, [], 3);
    final semantics = tester.ensureSemantics();
    try {
      await _mount(tester, cart);
      await tester.tap(find.bySemanticsLabel('Добавить одну штуку'));
      await tester.pumpAndSettle();
      expect(cart.getCatalogQuantity(item), 4);
      expect(cart.getTotalPrice(), 2800);
      expect(find.byType(ProductDetailPage), findsNothing);
      await tester.tap(find.bySemanticsLabel('Убрать одну штуку'));
      await tester.pumpAndSettle();
      expect(cart.getCatalogQuantity(item), 3);
      expect(cart.getTotalPrice(), 2100);
      expect(find.byType(ProductDetailPage), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
      'the final weight portion has an explicit delete, not a decrement',
      (tester) async {
    final item = Item(
        itemId: 704,
        name: 'Сыр',
        price: 5000,
        amount: 2,
        quantity: 0.25,
        stepQuantity: 0.25,
        unit: 'кг.');
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await cart.bindBusiness(1);
    cart.syncItemSelectionQuantity(item, [], 0.5);
    final semantics = tester.ensureSemantics();
    try {
      await _mount(tester, cart);
      await tester.tap(find.bySemanticsLabel('Убрать одну штуку'));
      await tester.pumpAndSettle();
      expect(cart.activeDisplayGroups.single.totalQuantity, 0.25);
      expect(cart.getTotalPrice(), 1250);
      expect(find.bySemanticsLabel('Убрать одну штуку'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Удалить товар'));
      await tester.pumpAndSettle();
      expect(cart.items, isEmpty);
      expect(cart.hasActiveItems, isFalse);
    } finally {
      semantics.dispose();
    }
  });
}

Future<void> _mount(WidgetTester tester, CartProvider cart) async {
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ChangeNotifierProvider<CartProvider>.value(
    value: cart,
    child: MaterialApp(theme: AppTheme.dark(), home: const CartPage()),
  ));
  await tester.pumpAndSettle();
}

Item _pourItem() => Item(
      itemId: 801,
      name: 'Разливное пиво',
      price: 1000,
      amount: 8,
      unit: 'л.',
      options: [
        ItemOption(
            optionId: 1,
            name: 'Тара',
            required: 1,
            selection: 'SINGLE',
            optionItems: [
              ItemOptionItem(
                  relationId: 1,
                  itemId: 101,
                  priceType: 'FIXED',
                  itemName: 'Бутылка 1 л',
                  price: 50,
                  parentItemAmount: 1),
              ItemOptionItem(
                  relationId: 2,
                  itemId: 102,
                  priceType: 'FIXED',
                  itemName: 'Бутылка 2 л',
                  price: 120,
                  parentItemAmount: 2),
            ])
      ],
    );
