import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/core/product_view.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/catalog/ui/category_products_page.dart';
import 'package:naliv_delivery/features/catalog/ui/supercategory_page.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('catalog landing follows the measured 375px frame',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => CartProvider(),
            child: MaterialApp(
              theme: AppTheme.dark(),
              home: SupercategoryPage(
                supercategoryId: 1,
                businessId: 1,
                title: 'Слабоалкогольные напитки',
                onSearch: () {},
                onCart: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();
      },
      () => _catalogClient,
    );

    Rect rect(String key) => tester.getRect(find.byKey(ValueKey(key)));

    expect(rect('catalog-chip-strip'), const Rect.fromLTWH(0, 103, 375, 29));
    expect(
      rect('catalog-featured-panel'),
      const Rect.fromLTWH(16, 154, 359, 245),
    );
    expect(
      rect('catalog-featured-product-0'),
      const Rect.fromLTWH(176, 170, 110, 213),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('all-products grid preserves Figma card bounds and pitch',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CartProvider(),
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: CategoryProductsPage(
            categoryId: 10,
            title: 'Белое',
            businessId: 1,
            initialItems: _products,
            onSearch: () {},
            onCart: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    Rect product(int index) =>
        tester.getRect(find.byKey(ValueKey('category-product-$index')));

    expect(product(0), const Rect.fromLTWH(16, 103, 110, 240));
    expect(product(1), const Rect.fromLTWH(132, 103, 110, 240));
    expect(product(2), const Rect.fromLTWH(248, 103, 110, 240));
    expect(product(3), const Rect.fromLTWH(16, 349, 110, 240));
    expect(tester.takeException(), isNull);
  });
}

MockClient get _catalogClient => MockClient((request) async {
      if (request.url.path.endsWith('/categories/supercategories')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'supercategories': [
                {
                  'supercategory_id': 1,
                  'name': 'Слабоалкогольные напитки',
                  'categories': [
                    {
                      'category_id': 2,
                      'name': 'Вино',
                      'subcategories': [
                        {'category_id': 10, 'name': 'Аперитив'},
                        {'category_id': 11, 'name': 'Белое'},
                      ],
                    },
                  ],
                },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path.contains('/categories/') &&
          request.url.path.endsWith('/items')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'items': [_itemJson(100), _itemJson(101), _itemJson(102)]
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('{}', 404);
    });

Map<String, dynamic> _itemJson(int id) => {
      'item_id': id,
      'name': 'Aperol, Аперитив, Италия, 0,5 л',
      'price': 13170,
      'amount': 20,
      'measure': 'шт.',
      'category': {'category_id': 10, 'name': 'Аперитив'},
    };

List<ProductView> get _products => [
      for (var id = 1; id <= 6; id++)
        ProductView.fromItem(
          Item(
            itemId: id,
            name: 'Aperol, Аперитив, Италия, 0,5 л',
            price: 13170,
            image: '',
            amount: 20,
            unit: 'шт.',
            category: ItemCategory(categoryId: 10, name: 'Белое'),
          ),
        ),
    ];
