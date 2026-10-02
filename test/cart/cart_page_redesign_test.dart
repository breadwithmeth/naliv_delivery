import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/cart/ui/cart_page.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/models/cart_item.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/bottling_surface_items.dart';

void main() {
  setUpAll(_loadDesignFont);

  testWidgets('gift litres stay visible when paid bottle quantity changes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final cart = CartProvider();
    addTearDown(cart.dispose);
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
    expect(find.descendant(of: row, matching: find.text('4')), findsOneWidget);
    expect(cart.activeDisplayGroups.single.totalQuantity, 3);
    await tester.tap(
        find.descendant(of: row, matching: find.byIcon(Icons.add_rounded)));
    await tester.pump();
    expect(find.descendant(of: row, matching: find.text('5')), findsOneWidget);
    expect(cart.activeDisplayGroups.single.totalQuantity, 4);
    expect(cart.activeDisplayGroups.single.totalOrderQuantity, 5);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('narrow large-text cart keeps names, totals and checkout usable',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(320, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cart = _filledCart();
    var checkedOut = false;
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: cart,
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.6),
            ),
            child: child!,
          ),
          home: CartPage(
            businessId: 1,
            onCheckout: () => checkedOut = true,
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }, () => _recommendationsClient);
    final checkout = find.byKey(const ValueKey('cart-checkout-button'));
    final total = find.text('105\u00A0360 ₸');
    expect(tester.getRect(total).overlaps(tester.getRect(checkout)), isFalse);
    final firstRow = find.byKey(const ValueKey('cart-row-0'));
    final name = find.descendant(
      of: firstRow,
      matching: find.text('Aperol, Аперитив, Италия'),
    );
    expect(tester.getSize(name).width, greaterThan(100));
    await tester.tap(checkout);
    expect(checkedOut, isTrue);
    expect(cart.getTotalPrice(), 105360);
    expect(tester.takeException(), isNull);
  });
}

CartProvider _filledCart() {
  final cart = CartProvider();
  for (final (id, quantity) in [(1, 1.0), (2, 6.0), (3, 1.0)]) {
    final source = Item(
      itemId: id,
      name: 'Aperol, Аперитив, Италия, 0,5 л',
      price: 13170,
      image: '',
      amount: 20,
      unit: 'шт.',
      category: ItemCategory(categoryId: 10, name: 'Аперитив'),
    );
    cart.addItem(
      CartItem(
        itemId: id,
        name: source.name,
        price: source.price,
        quantity: quantity,
        stepQuantity: 1,
        image: source.image,
        selectedVariants: const [],
        promotions: const [],
        itemData: source.toJson(),
      ),
    );
  }
  return cart;
}

MockClient get _recommendationsClient => MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/categories/10/items' &&
          request.url.queryParameters['business_id'] == '1') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'items': [
                for (var id = 100; id < 103; id++)
                  {
                    'item_id': id,
                    'name': 'Aperol, Аперитив, Италия, 0,5 л',
                    'price': 13170,
                    'amount': 20,
                    'measure': 'шт.',
                    'category': {'category_id': 10, 'name': 'Аперитив'},
                  },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      throw StateError(
          'Unexpected cart fixture request: ${request.method} ${request.url}');
    });

Future<void> _loadDesignFont() async {
  final bytes =
      File('assets/fonts/TikTokSans/TikTokSans-Variable.ttf').readAsBytesSync();
  final loader = FontLoader('TikTokSans');
  loader.addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
  await loader.load();
}
