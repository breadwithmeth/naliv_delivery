import 'dart:convert';

import 'dart:ui' show Tristate;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/core/product_view.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/catalog/catalog_view_data.dart';
import 'package:naliv_delivery/features/catalog/ui/category_products_page.dart';
import 'package:naliv_delivery/features/catalog/ui/supercategory_page.dart';
import 'package:naliv_delivery/features/product/ui/product_page.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/ui/product_card.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/liked_items_provider.dart';
import 'package:naliv_delivery/features/catalog/ui/category_switcher.dart';
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
    // At the last unit the minus is a delete: the item leaves the cart.
    await tester.tap(step('Удалить из корзины'));
    await tester.pump();
    expect(cart.getCatalogQuantity(_products.first.source), 0);
    expect(cart.items, isEmpty);
    await tester.tapAt(tester.getRect(first).topLeft + const Offset(50, 130));
    await tester.pumpAndSettle();
    expect(find.byType(ProductPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('product add action adds once, then opens the cart',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cart = CartProvider();
    await cart.bindBusiness(1);
    var cartOpened = 0;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: cart),
          ChangeNotifierProvider(create: (_) => LikedItemsProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: ProductPage(
            view: _products.first,
            businessId: 1,
            onCart: () => cartOpened++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'В корзину'));
    await tester.pump();
    expect(cart.getCatalogQuantity(_products.first.source), 1);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // A second press must do something visible: it opens the cart rather than
    // silently re-confirming, and it never adds behind the customer's back.
    await tester.tap(find.widgetWithText(FilledButton, 'Перейти в корзину'));
    await tester.pumpAndSettle();
    expect(cartOpened, 1);
    expect(cart.getCatalogQuantity(_products.first.source), 1);
    expect(find.text('В корзине: 1 шт'), findsOneWidget);
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

  testWidgets('opening a category keeps every prefetched first-page product',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cart = CartProvider();
    await cart.bindBusiness(1);
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
      if (request.url.path == '/api/categories/2/items' &&
          request.url.queryParameters['business_id'] == '1') {
        itemReads++;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'items': [
                for (var id = 100; id < 112; id++)
                  {
                    ..._itemJson(id),
                    if (id != 100) 'name': 'Товар $id',
                  },
              ],
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
          create: (_) => cart,
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
      await tester.tap(find.byKey(const ValueKey('catalog-open-2')));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryProductsPage), findsOneWidget);
      final scrollable = find.descendant(
        of: find.byKey(const ValueKey('category-products-grid')),
        matching: find.byWidgetPredicate((widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down),
      );
      final last = find.byKey(const ValueKey('category-product-11'));
      final lastAdd = find.descendant(
        of: last,
        matching: find.byWidgetPredicate(
          (widget) => widget is StepTap && widget.label == 'Добавить',
        ),
      );
      await tester.scrollUntilVisible(lastAdd, 300, scrollable: scrollable);
      await Scrollable.ensureVisible(tester.element(lastAdd), alignment: .3);
      await tester.pumpAndSettle();
      await tester.tap(lastAdd);
      await tester.pumpAndSettle();
      expect(cart.getTotalQuantityForItem(111), 1);
      final firstAdd = find.descendant(
        of: find.byKey(const ValueKey('category-product-0')),
        matching: find.byWidgetPredicate(
          (widget) => widget is StepTap && widget.label == 'Добавить',
        ),
      );
      await tester.scrollUntilVisible(firstAdd, -300, scrollable: scrollable);
      await Scrollable.ensureVisible(tester.element(firstAdd), alignment: .3);
      await tester.pumpAndSettle();
      await tester.tap(firstAdd);
      await tester.pumpAndSettle();
      expect(cart.getTotalQuantityForItem(100), 1);
      expect(itemReads, 1);
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets(
      'prefetched pagination retries without refetching or losing items',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pages = <String>[];
    final unexpected = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => CartProvider(),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: CategoryProductsPage(
              categoryId: 10,
              title: 'Аперитив',
              businessId: 1,
              initialItems: _products,
              initialHasMore: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scrollable = find.descendant(
        of: find.byKey(const ValueKey('category-products-grid')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Повторить загрузку'),
        300,
        scrollable: scrollable,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Повторить загрузку')),
        alignment: .3,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Повторить загрузку'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('После первой страницы'),
        300,
        scrollable: scrollable,
      );
      expect(find.text('После первой страницы'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('category-product-5')),
        -300,
        scrollable: scrollable,
      );
      expect(find.byKey(const ValueKey('category-product-5')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('category-product-0')),
        -300,
        scrollable: scrollable,
      );
      expect(find.byKey(const ValueKey('category-product-0')), findsOneWidget);
      expect(pages, ['2', '2']);
      expect(unexpected, isEmpty);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              final query = request.url.queryParameters;
              if (request.method != 'GET' ||
                  request.url.path != '/api/categories/10/items' ||
                  query['business_id'] != '1' ||
                  query['page'] != '2') {
                unexpected.add('$request');
                throw StateError('Unexpected request: $request');
              }
              pages.add(query['page']!);
              if (pages.length == 1) return http.Response('', 503);
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': {
                    'items': [
                      {..._itemJson(200), 'name': 'После первой страницы'},
                    ],
                    'pagination': {'page': 2, 'total_pages': 2},
                  },
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }));
  });

  testWidgets('parents hold their children; every level opens its own products',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    final reads = <String>[];
    final client = MockClient((request) async {
      if (request.method != 'GET') {
        throw StateError('Unexpected mutation: $request');
      }
      if (request.url.path == '/api/categories/supercategories') {
        return _okJson({
          'supercategories': [
            {
              'supercategory_id': 1,
              'name': '  Напитки  ',
              'categories': [
                {
                  'category_id': 4,
                  'name': 'Пусто',
                  'subcategories': [
                    {'category_id': 401, 'name': 'Ничего'},
                  ],
                },
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
        });
      }
      final match =
          RegExp(r'^/api/categories/(\d+)/items$').firstMatch(request.url.path);
      if (match == null || request.url.queryParameters['business_id'] != '1') {
        throw StateError('Unexpected request: $request');
      }
      final id = match.group(1)!;
      reads.add(id);
      const names = {
        '2': 'Разное пиво',
        '101': 'Светлый лагер',
        '3': 'Разное безалкогольное',
        '202': 'Безалкогольный лагер',
      };
      return _okJson({
        'items': [
          if (names[id] case final name?)
            {
              'item_id': int.parse(id) * 10,
              'name': name,
              'price': 1000,
              'amount': 10,
              'measure': 'шт.',
            },
        ],
      });
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

      // Navigation names parents only. A parent the store has no products for vanishes.
      expect(find.byKey(const ValueKey('category-tab-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('category-tab-3')), findsOneWidget);
      expect(find.byKey(const ValueKey('category-tab-4')), findsNothing);
      expect(find.byKey(const ValueKey('category-tab-101')), findsNothing);
      expect(find.text('Пусто'), findsNothing);
      // The parent previews its products; its child sits inside the same section.
      expect(find.text('Разное пиво'), findsOneWidget);
      expect(find.byKey(const ValueKey('category-chip-101')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('category-chip-101')));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryProductsPage), findsOneWidget);
      expect(find.text('Светлый лагер'), findsOneWidget);
      // The parent is the context of its child, and the child is the chip selected.
      expect(find.text('Пиво'), findsOneWidget);
      expect(_selected(tester, 'category-chip-101'), Tristate.isTrue);
      expect(_selected(tester, 'category-chip-2'), Tristate.isFalse);

      await tester.tap(find.byKey(const ValueKey('category-chip-2')));
      await tester.pumpAndSettle();
      expect(find.text('Разное пиво'), findsOneWidget);
      expect(find.text('Светлый лагер'), findsNothing);
      expect(find.text('Напитки'), findsOneWidget);
      expect(_selected(tester, 'category-chip-2'), Tristate.isTrue);

      // Going back to a list that was already loaded never refetches it.
      await tester.tap(find.byKey(const ValueKey('category-chip-101')));
      await tester.pumpAndSettle();
      expect(find.text('Светлый лагер'), findsOneWidget);
      expect(reads.where((id) => id == '101').length, 1);

      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryProductsPage), findsNothing);

      await tester.tap(find.byKey(const ValueKey('category-tab-3')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('catalog-open-3')).hitTestable(),
        findsOneWidget,
      );

      // The sheet lists every parent with its children; the current parent is marked.
      await tester.tap(find.byKey(const ValueKey('category-switch-control')));
      await tester.pumpAndSettle();
      expect(_selected(tester, 'category-menu-3'), Tristate.isTrue);
      expect(_selected(tester, 'category-menu-2'), Tristate.isFalse);
      expect(find.byKey(const ValueKey('category-menu-101')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('category-menu-202')));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryProductsPage), findsOneWidget);
      expect(find.text('Безалкогольный лагер'), findsOneWidget);
      expect(find.text('Безалкогольное пиво'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => client).whenComplete(semantics.dispose);
  });

  testWidgets('the child chips reveal a distant selection at large text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    final group = CategoryRef(
      id: 3,
      name: 'Безалкогольное пиво',
      parentName: 'Напитки',
      children: [
        for (var index = 0; index < 40; index++)
          CategoryRef(
            id: 100 + index,
            name: index == 39
                ? 'Светлое с длинным названием категории'
                : 'Категория $index',
            parentId: 3,
            parentName: 'Безалкогольное пиво',
            needsParentContext: index == 39,
          ),
      ],
    );
    final unexpected = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => CartProvider(),
          child: MaterialApp(
            theme: AppTheme.dark(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: CategoryProductsPage(
              categoryId: 139,
              title: 'Светлое',
              businessId: 1,
              group: group,
              initialItems: _products.take(1).toList(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final selected = find.byKey(const ValueKey('category-chip-139'));
      expect(selected.hitTestable(), findsOneWidget);
      expect(_selected(tester, 'category-chip-139'), Tristate.isTrue);
      expect(find.text('Безалкогольное пиво'), findsOneWidget);
      expect(find.byKey(const ValueKey('category-product-0')), findsOneWidget);
      expect(unexpected, isEmpty);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              unexpected.add('$request');
              throw StateError('Unexpected request: $request');
            })).whenComplete(semantics.dispose);
  });

  testWidgets('a far parent is reached from the grouped sheet at large text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = MockClient((request) async {
      if (request.method != 'GET') {
        throw StateError('Unexpected mutation: $request');
      }
      if (request.url.path == '/api/categories/supercategories') {
        return _okJson({
          'supercategories': [
            {
              'supercategory_id': 1,
              'name': 'Крепкий алкоголь',
              'categories': [
                for (var parent = 10; parent < 18; parent++)
                  {
                    'category_id': parent,
                    'name': 'Группа $parent',
                    'subcategories': [
                      for (var child = 1; child <= 3; child++)
                        {
                          'category_id': parent * 10 + child,
                          'name': 'Вид $parent-$child',
                        },
                    ],
                  },
              ],
            },
          ],
        });
      }
      final match =
          RegExp(r'^/api/categories/(\d+)/items$').firstMatch(request.url.path);
      if (match == null || request.url.queryParameters['business_id'] != '1') {
        throw StateError('Unexpected request: $request');
      }
      final id = int.parse(match.group(1)!);
      return _okJson({
        'items': [
          {
            'item_id': id,
            'name': 'Товар $id',
            'price': 1000,
            'amount': 10,
            'measure': 'шт.',
          },
        ],
      });
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => CartProvider(),
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const SupercategoryPage(
              supercategoryId: 1,
              businessId: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('category-switch-control')));
      await tester.pumpAndSettle();
      final last = find.byKey(const ValueKey('category-menu-17'));
      await tester.scrollUntilVisible(
        last,
        200,
        scrollable: find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('catalog-open-17')).hitTestable(),
        findsOneWidget,
      );
      expect(
        tester
            .widget<CategorySwitcher>(find.byType(CategorySwitcher))
            .selectedId,
        17,
      );
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

Tristate _selected(WidgetTester tester, String key) =>
    tester.getSemantics(find.byKey(ValueKey(key))).flagsCollection.isSelected;

http.Response _okJson(Map<String, dynamic> data) => http.Response(
      jsonEncode({'success': true, 'data': data}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
