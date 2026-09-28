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

void main() {
  setUpAll(_loadDesignFont);

  testWidgets('filled cart follows the measured 375px frame', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cart = _filledCart();

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: cart,
            child: MaterialApp(
              theme: AppTheme.dark(),
              home: const CartPage(
                businessId: 1,
                address: 'г. Темиртау, ул. Ленина, 16',
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();
      },
      () => _recommendationsClient,
    );

    Rect rect(String key) => tester.getRect(find.byKey(ValueKey(key)));

    expect(rect('cart-row-0'), const Rect.fromLTWH(16, 95, 343, 60));
    expect(rect('cart-row-1'), const Rect.fromLTWH(16, 159, 343, 60));
    expect(rect('cart-row-2'), const Rect.fromLTWH(16, 223, 343, 60));
    expect(
      rect('cart-recommendation-heading'),
      const Rect.fromLTWH(16, 315, 343, 26),
    );
    expect(
      rect('cart-recommendation-strip'),
      const Rect.fromLTWH(0, 365, 375, 244),
    );
    expect(rect('cart-total-bar'), const Rect.fromLTWH(0, 662, 375, 150));
    expect(
      rect('cart-checkout-button'),
      const Rect.fromLTWH(209, 698, 154, 49),
    );
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
      if (request.url.path.contains('/categories/') &&
          request.url.path.endsWith('/items')) {
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
      return http.Response('{}', 404);
    });

Future<void> _loadDesignFont() async {
  final bytes =
      File('assets/fonts/TikTokSans/TikTokSans-Variable.ttf').readAsBytesSync();
  final loader = FontLoader('TikTokSans');
  loader.addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
  await loader.load();
}
