import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/core/product_view.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/catalog/ui/category_products_page.dart';
import 'package:naliv_delivery/features/product/ui/product_page.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/liked_items_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

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
