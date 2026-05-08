import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/pages/cart_page.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('CartProvider order', () {
    test('keeps display order stable when regrouping an existing item', () {
      final firstItem = _buildPourItem(itemId: 801, name: 'First beer');
      final secondItem = Item(
        itemId: 802,
        name: 'Salted chips',
        price: 500,
        amount: 10,
        quantity: 1,
        unit: 'шт.',
      );
      final cartProvider = CartProvider()
        ..syncItemBottleCounts(
          firstItem,
          const <Map<String, dynamic>>[],
          <int, int>{1: 1},
        )
        ..incrementCatalogItem(secondItem);

      expect(
        cartProvider.displayGroups.map((group) => group.itemId).toList(growable: false),
        <int>[801, 802],
      );

      cartProvider.syncItemBottleCounts(
        firstItem,
        const <Map<String, dynamic>>[],
        <int, int>{2: 1},
      );

      expect(
        cartProvider.displayGroups.map((group) => group.itemId).toList(growable: false),
        <int>[801, 802],
      );
    });
  });

  group('CartPage layout', () {
    testWidgets('lays out standard cart rows without exceptions', (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final item = Item(
        itemId: 701,
        name: 'Sparkling water',
        price: 650,
        amount: 8,
        quantity: 1,
        unit: 'шт.',
      );
      final cartProvider = CartProvider()
        ..incrementCatalogItem(item)
        ..incrementCatalogItem(item)
        ..incrementCatalogItem(item);

      await tester.pumpWidget(_wrap(cartProvider));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Корзина'), findsOneWidget);
      expect(find.textContaining('Sparkling water'), findsOneWidget);
    });

    testWidgets('stepper taps do not open the detail page', (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final item = Item(
        itemId: 703,
        name: 'Tonic water',
        price: 700,
        amount: 8,
        quantity: 1,
        unit: 'шт.',
      );
      final cartProvider = CartProvider()
        ..incrementCatalogItem(item)
        ..incrementCatalogItem(item)
        ..incrementCatalogItem(item);

      await tester.pumpWidget(_wrap(cartProvider));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('В корзину'), findsNothing);
      expect(cartProvider.getCatalogQuantity(item), 4);
    });

    testWidgets('lays out bottle-edit cart rows without exceptions', (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final item = _buildPourItem();
      final cartProvider = CartProvider()
        ..syncItemBottleCounts(
          item,
          const <Map<String, dynamic>>[],
          <int, int>{1: 1, 2: 1},
        );

      await tester.pumpWidget(_wrap(cartProvider));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Изменить'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });
  });
}

Widget _wrap(CartProvider cartProvider) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
      ChangeNotifierProvider<BusinessProvider>(create: (_) => BusinessProvider()),
    ],
    child: const MaterialApp(
      home: CartPage(),
    ),
  );
}

Item _buildPourItem({
  int itemId = 702,
  String name = 'Beer from tap',
}) {
  return Item(
    itemId: itemId,
    name: name,
    price: 1000,
    image: '',
    amount: 8,
    unit: 'л.',
    category: ItemCategory(categoryId: 1, name: 'Beer'),
    options: <ItemOption>[
      ItemOption(
        optionId: 1,
        name: 'Bottle',
        required: 1,
        selection: 'SINGLE',
        optionItems: <ItemOptionItem>[
          ItemOptionItem(
            relationId: 1,
            itemId: 101,
            priceType: 'FIXED',
            itemName: '1 л бутылка',
            price: 50,
            parentItemAmount: 1,
          ),
          ItemOptionItem(
            relationId: 2,
            itemId: 102,
            priceType: 'FIXED',
            itemName: '3 л бутылка',
            price: 180,
            parentItemAmount: 3,
          ),
        ],
      ),
    ],
  );
}
