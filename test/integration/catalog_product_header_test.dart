import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/core/product_view.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/catalog/ui/category_products_page.dart';
import 'package:naliv_delivery/features/product/product_navigation.dart';
import 'package:naliv_delivery/features/product/ui/product_page.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/ui/product_card.dart';
import 'package:naliv_delivery/ui/product_row.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/liked_items_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/configuration_items.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('only kitchen cards fill the rounded artwork slot',
      (tester) async {
    final dish = ProductView.fromItem(_photoItem(categoryId: 237));
    final bottle = ProductView.fromItem(_photoItem(categoryId: 58));
    const dishKey = ValueKey('dish-card');
    const bottleKey = ValueKey('bottle-card');
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductCard.fromView(dish, key: dishKey),
            ProductCard.fromView(bottle, key: bottleKey),
          ],
        ),
      ),
    ));

    final dishCard = find.byKey(dishKey);
    final bottleCard = find.byKey(bottleKey);
    final dishPhoto =
        find.descendant(of: dishCard, matching: find.byType(Image));
    final bottlePhoto =
        find.descendant(of: bottleCard, matching: find.byType(Image));
    expect(tester.widget<Image>(dishPhoto).fit, BoxFit.cover);
    expect(tester.widget<Image>(bottlePhoto).fit, BoxFit.contain);
    expect(tester.getSize(dishCard), tester.getSize(bottleCard));
    expect(
      tester.getRect(dishPhoto),
      tester.getRect(dishCard).topLeft.translate(4, 4) & const Size(120, 132),
    );
    expect(
      tester.getRect(bottlePhoto),
      tester.getRect(bottleCard).topLeft.translate(10, 10) &
          const Size(108, 120),
    );
    final roundedSlot =
        find.ancestor(of: dishPhoto, matching: find.byType(ClipRRect));
    expect(tester.getRect(roundedSlot.first), tester.getRect(dishPhoto));

    expect(tester.takeException(), isNull);
  });

  testWidgets('browse rows crop dishes but keep other artwork proportional',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: Column(
          children: [
            ProductRow.fromView(
                ProductView.fromItem(_photoItem(categoryId: 237))),
            ProductRow.fromView(
                ProductView.fromItem(_photoItem(categoryId: 58))),
            ProductRow.fromView(
              ProductView.fromItem(_photoItem(categoryId: 237).copyWith(image: '')),
              key: const ValueKey('missing-dish-photo'),
            ),
          ],
        ),
      ),
    ));
    final photos = find.byType(Image);
    expect(photos, findsNWidgets(2));
    expect(tester.widget<Image>(photos.at(0)).fit, BoxFit.cover);
    expect(tester.widget<Image>(photos.at(1)).fit, BoxFit.contain);
    expect(tester.getSize(photos.at(0)), tester.getSize(photos.at(1)));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('missing-dish-photo')),
        matching: find.byIcon(Icons.image_outlined),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final configurable in [false, true]) {
    testWidgets(
        '${configurable ? 'configurable' : 'simple'} detail fills the hero '
        'only for kitchen products', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cart = CartProvider();
      addTearDown(cart.dispose);
      await cart.bindBusiness(11);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: cart),
          ChangeNotifierProvider(create: (_) => LikedItemsProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  for (final (id, label) in [(237, 'Dish'), (58, 'Bottle')])
                    TextButton(
                      onPressed: () {
                        final item = _photoItem(categoryId: id);
                        final source = configurable
                            ? item.copyWith(options: fixtureOptionItem().options)
                            : item;
                        openProduct(context, ProductView.fromItem(source),
                            businessId: 11);
                      },
                      child: Text(label),
                    ),
                ],
              ),
            ),
          ),
        ),
      ));

      for (final label in ['Dish', 'Bottle']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        final photo = find.byType(Image);
        final hero = find.ancestor(of: photo, matching: find.byType(ClipRRect));
        expect(tester.getSize(hero.first), const Size(375, 320));
        final cover = label == 'Dish';
        expect(tester.widget<Image>(photo).fit,
            cover ? BoxFit.cover : BoxFit.contain);
        final heroRect = tester.getRect(hero.first);
        final horizontalInset = configurable ? 48.0 : 32.0;
        expect(
          tester.getRect(photo),
          cover
              ? heroRect
              : Rect.fromLTRB(
                  heroRect.left + horizontalInset,
                  heroRect.top + 88,
                  heroRect.right - horizontalInset,
                  heroRect.bottom - 16,
                ),
        );
        await tester.tap(find.byTooltip(
            configurable ? 'Назад без сохранения' : 'Назад'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets(
        'category header frosts only once the grid scrolls under it '
        '($theme)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 480));
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
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: CategoryProductsPage(
              categoryId: 10,
              title: 'Белое',
              businessId: 1,
              initialItems: _products,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      bool frosted() =>
          find.byKey(const ValueKey('header-scrim')).evaluate().isNotEmpty;

      final grid = find.byKey(const ValueKey('category-products-grid'));
      final bar = find.byTooltip('Назад');
      expect(frosted(), isFalse);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('category-product-0'))).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(bar).dy),
        reason: 'the first row must not start under the header',
      );

      await tester.drag(grid, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(frosted(), isTrue);

      await tester.drag(grid, const Offset(0, 3000));
      await tester.pumpAndSettle();
      expect(frosted(), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'product header shows the title only after the hero scrolls '
        'away ($theme)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cart = CartProvider();
      await cart.bindBusiness(1);
      final view = _products.first;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: cart),
            ChangeNotifierProvider(create: (_) => LikedItemsProvider()),
          ],
          child: MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: ProductPage(view: view, businessId: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('backdrop')), findsNothing);
      expect(find.text(view.title), findsOneWidget);
      expect(find.byTooltip('Назад'), findsOneWidget);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('backdrop')), findsOneWidget);
      // The name stays on screen in the header while the page's own title
      // has scrolled behind it.
      expect(find.text(view.title), findsNWidgets(2));
      expect(find.byTooltip('Назад'), findsOneWidget);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 3000),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('backdrop')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

Item _photoItem({required int categoryId}) => Item(
      itemId: categoryId,
      name: 'Новинка',
      price: 1000,
      businessId: 11,
      categoryId: categoryId,
      image: 'https://images.invalid/$categoryId.png',
      unit: 'шт.',
      amount: 10,
    );

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
