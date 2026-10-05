import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/core/product_view.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/catalog/ui/category_products_page.dart';
import 'package:naliv_delivery/features/catalog/ui/supercategory_page.dart';
import 'package:naliv_delivery/features/product/ui/product_page.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/ui/product_card.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/liked_items_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('category card stepper updates the cart, card opens details',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cart = CartProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: cart),
          ChangeNotifierProvider(create: (_) => LikedItemsProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: CategoryProductsPage(
            categoryId: 10,
            title: 'Белое',
            businessId: 1,
            initialItems: _products,
          ),
        ),
      ),
    );
    final first = find.byKey(const ValueKey('category-product-0'));
    Finder step(String label) => find.descendant(
          of: first,
          matching: find.byWidgetPredicate(
              (widget) => widget is StepTap && widget.label == label),
        );
    await tester.tap(step('Добавить'));
    await tester.pump();
    expect(cart.getCatalogQuantity(_products.first.source), 1);
    await tester.tap(step('Уменьшить количество'));
    await tester.pump();
    expect(cart.getCatalogQuantity(_products.first.source), 0);
    await tester.tapAt(tester.getRect(first).topLeft + const Offset(50, 130));
    await tester.pumpAndSettle();
    expect(find.byType(ProductPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'failed leaf request retries; successful empty response stays empty',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var reads = 0;
    final client = MockClient((request) async {
      if (request.method != 'GET' ||
          request.url.path != '/api/categories/10/items' ||
          request.url.queryParameters['business_id'] != '1') {
        throw StateError('Unexpected request: $request');
      }
      reads++;
      if (reads == 1) return http.Response('temporarily unavailable', 503);
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {'items': <Object>[]},
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => CartProvider(),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const CategoryProductsPage(
              categoryId: 10,
              title: 'Белое',
              businessId: 1,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Не удалось загрузить товары'), findsOneWidget);
      await tester.tap(find.text('Повторить'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('В этой категории пока нет товаров'), findsOneWidget);
      expect(reads, 2);
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets(
      'failed catalog landing retries; missing category is not a spinner',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var reads = 0;
    final client = MockClient((request) async {
      if (request.method != 'GET' ||
          request.url.path != '/api/categories/supercategories') {
        throw StateError('Unexpected request: $request');
      }
      reads++;
      if (reads == 1) return http.Response('temporarily unavailable', 503);
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {'supercategories': <Object>[]},
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => CartProvider(),
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const SupercategoryPage(
              supercategoryId: 1,
              businessId: 1,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Не удалось загрузить категорию'), findsOneWidget);
      await tester.tap(find.text('Повторить'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('В этой категории пока нет товаров'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(reads, 2);
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets('featured heading opens its products without another request',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var itemReads = 0;
    final client = MockClient((request) async {
      if (request.method != 'GET' ||
          request.url.scheme != 'https' ||
          request.url.host != 'njt25.naliv.kz') {
        throw StateError('Unexpected request: $request');
      }
      if (request.url.path == '/api/categories/supercategories') {
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
      if (request.url.path == '/api/categories/10/items' &&
          request.url.queryParameters['business_id'] == '1') {
        itemReads++;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'items': [_itemJson(100)]
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      throw StateError('Unexpected request: $request');
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => CartProvider(),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const SupercategoryPage(
              supercategoryId: 1,
              businessId: 1,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(itemReads, 1);
      await tester.tap(find.text('Аперитив').last);
      await tester.pumpAndSettle();
      expect(find.byType(CategoryProductsPage), findsOneWidget);
      expect(itemReads, 1);
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}

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
