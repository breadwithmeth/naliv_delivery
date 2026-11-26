import 'dart:async';
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
import 'package:naliv_delivery/ui/app_cart_button.dart';
import 'package:naliv_delivery/ui/app_haptics.dart';
import 'package:naliv_delivery/ui/product_card.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/liked_items_provider.dart';
import 'package:naliv_delivery/features/catalog/ui/category_switcher.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:naliv_delivery/features/catalog/catalog_data_source.dart';
import 'package:naliv_delivery/features/catalog/category_merchandising.dart';
import '../support/category_merchandising_fixture.dart';
import '../support/design_surfaces.dart';
import '../support/haptic_calls.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('only explicit complete category promotes active campaigns', () async {
    final ordinary = {..._itemJson(1), 'name': 'Обычный'};
    final promotion = {
      ..._itemJson(2),
      'name': 'Акция',
      'promotions': [
        {
          'detail_id': 20,
          'name': 'Действующая',
          'type': 'DISCOUNT',
          'discount': 10,
          'start_date': '2020-01-01',
          'end_date': '2099-01-01',
        },
      ],
    };
    final expired = {
      ..._itemJson(3),
      'name': 'Истёкшая',
      'promotions': [
        {
          'detail_id': 21,
          'name': 'Истёкшая',
          'type': 'DISCOUNT',
          'discount': 10,
          'end_date': '2020-01-01',
        },
      ],
    };
    final rows = [ordinary, expired, promotion];
    final unknown = <String>[];
    Map<String, Object>? pagination = {'page': 1, 'total_pages': 1, 'total': 3};
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/categories/2/items' &&
          request.url.queryParameters['business_id'] == '1') {
        return _okJson({
          'items': rows,
          if (pagination != null) 'pagination': pagination,
        });
      }
      unknown.add('$request');
      throw StateError('Unexpected $request');
    });
    await http.runWithClient(() async {
      Future<List<int>> ids() async => (await const CatalogDataSource(
            businessId: 1,
          ).itemsPage(2))
              .items
              .map((view) => view.itemId)
              .toList();
      expect(await ids(), [2, 1, 3]);
      for (final metadata in <Map<String, Object>?>[
        null,
        {'page': 1, 'total': 3},
        {'page': 1, 'total_pages': 1, 'total': 4},
        {'page': 1, 'total_pages': 2, 'total': 3},
        {'page': 2, 'total_pages': 2, 'total': 3},
        {'page': 1, 'total_pages': 1.5, 'total': 3},
      ]) {
        pagination = metadata;
        expect(await ids(), [1, 3, 2], reason: '$metadata');
      }
      pagination = {'page': 1, 'total_pages': 1, 'total': 3};
      expect(
        (await const CatalogDataSource(
          businessId: 1,
        ).itemsPage(2, page: 2))
            .items
            .map((view) => view.itemId),
        [1, 3, 2],
      );
    }, () => client);
    expect(unknown, isEmpty);
    client.close();
  });

  test('ranking preserves repeated input cards of one priority SKU', () {
    final rows = CategoryMerchandisingFixture.rows(1);
    final first = ProductView.fromItem(Item.fromJson(rows[0]));
    final duplicate = ProductView.fromItem(Item.fromJson({...rows[0], 'price': 9999}));
    final ordinary = ProductView.fromItem(Item.fromJson(rows[1]));
    expect(rankCompleteCategory([ordinary, first, duplicate], priorityItemIds: [100, 100]),
      [first, duplicate, ordinary]);
  });

  test('model-hidden rows are not promoted by an active campaign', () {
    final rows = CategoryMerchandisingFixture.rows(1);
    final ordinary = ProductView.fromItem(Item.fromJson(rows[1]));
    final hidden = ProductView.fromItem(Item.fromJson({...rows[2], 'visible': -1}));
    expect(rankCompleteCategory([ordinary, hidden]), [ordinary, hidden]);
  });

  test(
    'priorities ignore repeats, foreign, hidden and unavailable IDs without repricing',
    () {
      final items = CategoryMerchandisingFixture.rows(
        1,
      ).map((row) => ProductView.fromItem(Item.fromJson(row))).toList();
      final ranked = rankCompleteCategory(
        items,
        priorityItemIds: CategoryMerchandisingFixture.priorities[1]![2]!,
      );
      expect(ranked.map((view) => view.itemId), [
        104,
        105,
        102,
        100,
        101,
        103,
        106,
        107,
        108,
        109,
        110,
        111,
        112,
        113,
        114,
      ]);
      for (final view in ranked) {
        final original = items.singleWhere(
          (item) => item.itemId == view.itemId,
        );
        expect(identical(view, original), isTrue);
        expect(view.source.price, 1000 + view.itemId);
      }
      expect(
        rankCompleteCategory(
          items,
          priorityItemIds: [99999, 107, 108],
        ).map((view) => view.itemId),
        [
          102,
          105,
          100,
          101,
          103,
          104,
          106,
          107,
          108,
          109,
          110,
          111,
          112,
          113,
          114,
        ],
      );
    },
  );

  for (final store in [1, 2]) {
    testWidgets(
      'store $store priorities reach preview and full grid through adapter',
      (tester) async {
        SharedPreferences.setMockInitialValues(surfaceFixturePreferences);
        SurfaceFixtureClient.resetUnexpectedRequests();
        await tester.binding.setSurfaceSize(const Size(375, 812));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final client = SurfaceFixtureClient();
        await http.runWithClient(() async {
          await tester.pumpWidget(
            DesignSurfaceApp(
              surface: 'merchandising_store_$store',
              brightness: Brightness.light,
            ),
          );
          await tester.pumpAndSettle();
          final expected = store == 1
              ? 'Приоритет категории, Напиток'
              : 'Действующая акция, Напиток';
          expect(
            tester
                .widgetList<ProductCard>(find.byType(ProductCard))
                .first
                .title,
            expected,
          );
          await tester.tap(find.byKey(const ValueKey('catalog-open-2')));
          await tester.pumpAndSettle();
          expect(find.byType(CategoryProductsPage), findsOneWidget);
          expect(
            tester
                .widgetList<ProductCard>(find.byType(ProductCard))
                .first
                .title,
            expected,
          );
          final cart = tester.element(find.byType(CategoryProductsPage)).read<CartProvider>();
          expect(cart.businessId, store);
          final firstAdd = find.descendant(
            of: find.byKey(const ValueKey('category-product-0')),
            matching: find.byWidgetPredicate((widget) => widget is StepTap && widget.label == 'Добавить'),
          );
          await tester.tap(firstAdd);
          await tester.pumpAndSettle();
          expect(cart.getTotalQuantityForItem(store == 1 ? 104 : 102), 1);
          expect(cart.businessId, store);
          await tester.tap(find.byTooltip('Назад'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widgetList<ProductCard>(find.byType(ProductCard))
                .first
                .title,
            expected,
          );
          await tester.tap(find.byType(AppCartButton));
          await tester.pumpAndSettle();
          expect(find.text('Корзина'), findsOneWidget);
          expect(find.text(store == 2
              ? 'Другой тестовый адрес, 20' : 'Тестовый адрес, 16'), findsOneWidget);
          expect(cart.businessId, store);
          expect(SurfaceFixtureClient.unexpectedRequests, isEmpty);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }, () => client);
        client.close();
        SurfaceFixtureClient.resetUnexpectedRequests();
      },
    );
  }

  testWidgets('category card haptics confirm only accepted quantity changes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    enableQuantityClicks(tester);
    final impacts = recordHapticCalls(tester);
    final products = [
      ProductView.fromItem(Item.fromJson({..._itemJson(1), 'amount': 2})),
      ProductView.fromItem(Item.fromJson({..._itemJson(2), 'amount': 0.5})),
      for (var id = 3; id <= 24; id++)
        ProductView.fromItem(Item.fromJson(_itemJson(id))),
    ];
    final cart = CartProvider();
    addTearDown(cart.dispose);
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
            initialItems: products,
          ),
        ),
      ),
    );
    Finder card(int index) => find.byKey(ValueKey('category-product-$index'));
    Finder step(int index, String label) => find.descendant(
          of: card(index),
          matching: find.byWidgetPredicate(
              (widget) => widget is StepTap && widget.label == label),
        );
    final add = step(0, 'Добавить');
    final position = Scrollable.of(tester.element(add)).position;
    await tester.timedDrag(add, const Offset(0, -100),
        const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
    expect(cart.items, isEmpty);
    expect(impacts, isEmpty);
    position.jumpTo(0);
    await tester.pumpAndSettle();

    // The card can be tapped, but the provider rejects a whole unit of
    // packaged stock when only half a unit remains.
    final rejected = step(1, 'Добавить');
    expect(tester.widget<StepTap>(rejected).onTap, isNotNull);
    await tester.tap(rejected);
    await tester.pumpAndSettle();
    expect(cart.getCatalogQuantity(products[1].source), 0);
    expect(impacts, isEmpty);

    final item = products.first.source;
    await tester.tap(add);
    expect(cart.getCatalogQuantity(item), 1);
    await tester.pumpAndSettle();
    expect(impacts, [lightImpact]);

    final increase = step(0, 'Увеличить количество');
    await tester.tap(increase);
    expect(cart.getCatalogQuantity(item), 2);
    await tester.pumpAndSettle();
    await tester.tap(increase);
    expect(cart.getCatalogQuantity(item), 2);
    await tester.pumpAndSettle();
    expect(impacts, [lightImpact, selectionClick]);

    await tester.pump(const Duration(milliseconds: 90));
    await tester.tap(step(0, 'Уменьшить количество'));
    await tester.pumpAndSettle();
    expect(cart.getCatalogQuantity(item), 1);
    expect(impacts, [lightImpact, selectionClick, selectionClick]);
    await tester.pump(const Duration(milliseconds: 90));
    await tester.tap(step(0, 'Удалить из корзины'));
    await tester.pumpAndSettle();
    expect(cart.items, isEmpty);
    expect(impacts, [lightImpact, selectionClick, selectionClick, selectionClick]);

    await tester.tap(add);
    expect(cart.getCatalogQuantity(item), 1);
    await tester.pumpAndSettle();
    expect(impacts, [
      lightImpact,
      selectionClick,
      selectionClick,
      selectionClick,
      lightImpact,
    ]);
    await tester.tapAt(tester.getRect(card(0)).topLeft + const Offset(50, 130));
    await tester.pumpAndSettle();
    expect(find.byType(ProductPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('product add action adds once, then opens the cart',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final channelReply = Completer<Object?>();
    enableQuantityClicks(tester);
    final impacts = recordHapticCalls(tester, reply: () => channelReply.future);
    final cart = CartProvider();
    addTearDown(cart.dispose);
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
    expect(cart.getCatalogQuantity(_products.first.source), 1);
    await tester.pumpAndSettle();
    expect(find.text('В корзине: 1 шт'), findsOneWidget);
    expect(impacts, [lightImpact]);

    // Cart UI and navigation must not wait for the pending platform reply.
    await tester.tap(find.widgetWithText(FilledButton, 'Добавлено'));
    await tester.pumpAndSettle();
    expect(cartOpened, 1);
    expect(cart.getCatalogQuantity(_products.first.source), 1);
    expect(impacts, [lightImpact]);

    channelReply.complete();
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.tap(find.widgetWithText(FilledButton, 'Перейти в корзину'));
    await tester.pumpAndSettle();
    expect(cartOpened, 2);
    expect(cart.getCatalogQuantity(_products.first.source), 1);
    expect(impacts, [lightImpact]);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

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
    },
  );

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
              home: const SupercategoryPage(supercategoryId: 1, businessId: 1),
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
    },
  );

  testWidgets('opening a category keeps every prefetched first-page product',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    enableQuantityClicks(tester);
    final impacts = recordHapticCalls(tester);
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
      final railFirstAdd = find.descendant(
        of: find.byType(ProductCard).first,
        matching: find.byWidgetPredicate(
          (widget) => widget is StepTap && widget.label == 'Добавить',
        ),
      );
      await tester.ensureVisible(railFirstAdd);
      await tester.pumpAndSettle();
      await tester.tap(railFirstAdd);
      await tester.pumpAndSettle();
      expect(cart.getTotalQuantityForItem(100), 1);
      expect(impacts, [lightImpact]);
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
      expect(impacts, [lightImpact, lightImpact]);
      final firstIncrease = find.descendant(
        of: find.byKey(const ValueKey('category-product-0')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is StepTap && widget.label == 'Увеличить количество',
        ),
      );
      await tester.scrollUntilVisible(firstIncrease, -300,
          scrollable: scrollable);
      await Scrollable.ensureVisible(tester.element(firstIncrease),
          alignment: .3);
      await tester.pumpAndSettle();
      await tester.tap(firstIncrease);
      await tester.pumpAndSettle();
      expect(cart.getTotalQuantityForItem(100), 2);
      expect(impacts, [lightImpact, lightImpact, selectionClick]);

      await tester.pump(const Duration(milliseconds: 90));
      await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('category-product-0')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is StepTap && widget.label == 'Уменьшить количество',
        ),
      ));
      expect(cart.getTotalQuantityForItem(100), 1);
      expect(impacts, [lightImpact, lightImpact, selectionClick, selectionClick]);

      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      expect(impacts, [lightImpact, lightImpact, selectionClick, selectionClick]);
      final railRemove = find.descendant(
        of: find.byType(ProductCard).first,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is StepTap && widget.label == 'Удалить из корзины',
        ),
      );
      await tester.ensureVisible(railRemove);
      await tester.pump(const Duration(milliseconds: 90));
      await tester.tap(railRemove);
      expect(cart.getTotalQuantityForItem(100), 0);
      expect(impacts, [
        lightImpact,
        lightImpact,
        selectionClick,
        selectionClick,
        selectionClick,
      ]);
      expect(itemReads, 1);
      expect(tester.takeException(), isNull);
    }, () => client);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'prefetched pagination retries without refetching or losing items',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pages = <String>[];
      final unexpected = <String>[];
      await http.runWithClient(
        () async {
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
          expect(
            find.byKey(const ValueKey('category-product-5')),
            findsOneWidget,
          );
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('category-product-0')),
            -300,
            scrollable: scrollable,
          );
          expect(
            find.byKey(const ValueKey('category-product-0')),
            findsOneWidget,
          );
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
        }),
      );
    },
  );

  testWidgets('category haptics follow accepted selection, not navigation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final clicks = recordHapticCalls(tester);
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
      final firstTab = find.byKey(const ValueKey('category-tab-2'));
      expect(
        tester.widget<CategorySwitcher>(find.byType(CategorySwitcher)).selectedId,
        2,
      );
      expect(clicks, isEmpty);
      await tester.tap(firstTab);
      await tester.pumpAndSettle();
      expect(clicks, isEmpty);
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
      expect(clicks, isEmpty);

      final all = find.byKey(const ValueKey('category-chip-2'));
      final cancelled = await tester.startGesture(tester.getCenter(all));
      await cancelled.cancel();
      await tester.pumpAndSettle();
      expect(_selected(tester, 'category-chip-101'), Tristate.isTrue);
      expect(clicks, isEmpty);

      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(find.text('Разное пиво'), findsOneWidget);
      expect(find.text('Светлый лагер'), findsNothing);
      expect(find.text('Напитки'), findsOneWidget);
      expect(_selected(tester, 'category-chip-2'), Tristate.isTrue);
      expect(clicks, [selectionClick]);

      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(clicks, [selectionClick]);

      // Going back to a list that was already loaded never refetches it.
      await tester.tap(find.byKey(const ValueKey('category-chip-101')));
      await tester.pumpAndSettle();
      expect(find.text('Светлый лагер'), findsOneWidget);
      expect(reads.where((id) => id == '101').length, 1);
      expect(clicks, [selectionClick, selectionClick]);

      await AppHaptics.preference.setEnabled(false);
      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(_selected(tester, 'category-chip-2'), Tristate.isTrue);
      expect(clicks, [selectionClick, selectionClick]);
      await AppHaptics.preference.setEnabled(true);

      // Switching back and forth within one frame still confirms both changes.
      clicks.clear();
      await tester.tap(find.byKey(const ValueKey('category-chip-101')));
      await tester.pump();
      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(_selected(tester, 'category-chip-2'), Tristate.isTrue);
      expect(clicks, [selectionClick, selectionClick]);
      clicks.clear();

      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryProductsPage), findsNothing);

      await tester.tap(find.byKey(const ValueKey('category-tab-3')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('catalog-open-3')).hitTestable(),
        findsOneWidget,
      );
      expect(clicks, [selectionClick]);

      // The sheet lists every parent with its children; the current parent is marked.
      final switchControl = find.byKey(const ValueKey('category-switch-control'));
      await tester.tap(switchControl);
      await tester.pumpAndSettle();
      expect(_selected(tester, 'category-menu-3'), Tristate.isTrue);
      expect(_selected(tester, 'category-menu-2'), Tristate.isFalse);
      expect(find.byKey(const ValueKey('category-menu-101')), findsOneWidget);
      await tester.tap(find.byTooltip('Закрыть категории'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(clicks, [selectionClick]);

      await tester.tap(switchControl);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('category-menu-202')));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryProductsPage), findsOneWidget);
      expect(find.text('Безалкогольный лагер'), findsOneWidget);
      expect(find.text('Безалкогольное пиво'), findsOneWidget);
      expect(clicks, [selectionClick]);

      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      final overview = tester.widget<ListView>(
        find.byKey(const ValueKey('catalog-overview')),
      );
      final position = overview.controller!.position;
      position.jumpTo(position.minScrollExtent);
      await tester.pumpAndSettle();
      expect(
        tester.widget<CategorySwitcher>(find.byType(CategorySwitcher)).selectedId,
        2,
      );
      expect(clicks, [selectionClick]);

      await AppHaptics.preference.setEnabled(false);
      await tester.tap(find.byKey(const ValueKey('category-tab-3')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CategorySwitcher>(find.byType(CategorySwitcher)).selectedId,
        3,
      );
      expect(clicks, [selectionClick]);
      await AppHaptics.preference.setEnabled(true);
      await tester.pumpWidget(const SizedBox.shrink());
      client.close();
      expect(tester.takeException(), isNull);
    }, () => client);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

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
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => CartProvider(),
            child: MaterialApp(
              theme: AppTheme.dark(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
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
        expect(
          find.byKey(const ValueKey('category-product-0')),
          findsOneWidget,
        );
        expect(unexpected, isEmpty);
        expect(tester.takeException(), isNull);
      },
      () => MockClient((request) async {
        unexpected.add('$request');
        throw StateError('Unexpected request: $request');
      }),
    ).whenComplete(semantics.dispose);
  });

  testWidgets('a far parent is reached from the grouped sheet at large text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final clicks = recordHapticCalls(tester);
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
      expect(clicks, isEmpty);
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
      expect(clicks, [selectionClick]);
      await tester.pumpWidget(const SizedBox.shrink());
      client.close();
      expect(tester.takeException(), isNull);
    }, () => client);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
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
