import 'dart:convert';

import 'dart:ui' show Tristate;
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
    await cart.bindBusiness(1);
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

  testWidgets('ambiguous leaves open their own products and keep route selection',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    final client = MockClient((request) async {
      if (request.method != 'GET') {
        throw StateError('Unexpected mutation: $request');
      }
      Map<String, dynamic> data;
      if (request.url.path == '/api/categories/supercategories') {
        data = {
          'supercategories': [
            {
              'supercategory_id': 1,
              'name': '  Напитки  ',
              'categories': [
                {
                  'category_id': 2,
                  'name': 'Пиво',
                  'subcategories': [
                    {'category_id': 101, 'name': '  Светлое   '},
                  ],
                },
                {
                  'category_id': 3,
                  'name': ' Безалкогольное  пиво ',
                  'subcategories': [
                    {'category_id': 202, 'name': 'Светлое'},
                  ],
                },
              ],
            },
          ],
        };
      } else if (request.url.path == '/api/categories/101/items' ||
          request.url.path == '/api/categories/202/items') {
        if (request.url.queryParameters['business_id'] != '1') {
          throw StateError('Unexpected store: $request');
        }
        final isAlcoholFree = request.url.path.contains('/202/');
        data = {
          'items': [
            {
              'item_id': isAlcoholFree ? 2002 : 1001,
              'name': isAlcoholFree ? 'Безалкогольный лагер' : 'Светлый лагер',
              'price': 1000,
              'amount': 10,
              'measure': 'шт.',
            },
          ],
        };
      } else {
        throw StateError('Unexpected request: $request');
      }
      return http.Response(
        jsonEncode({'success': true, 'data': data}),
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
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Все категории'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Светлое · Безалкогольное пиво').last);
      await tester.pumpAndSettle();
      expect(find.text('Безалкогольный лагер'), findsOneWidget);
      expect(find.text('Светлый лагер'), findsNothing);
      final strip = find.byKey(const ValueKey('catalog-chip-strip'));
      final selected = find.descendant(
        of: strip,
        matching: find.text('Светлое · Безалкогольное пиво'),
      );
      expect(tester.getSemantics(selected).flagsCollection.isSelected,
          Tristate.isTrue);
      final all = find.descendant(of: strip, matching: find.text('Все'));
      await tester.ensureVisible(all);
      await tester.pumpAndSettle();
      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(find.text('Напитки'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.descendant(
              of: strip,
              matching: find.text('Все'),
            ))
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
    }, () => client).whenComplete(semantics.dispose);
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
