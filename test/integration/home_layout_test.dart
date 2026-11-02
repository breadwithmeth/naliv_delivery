import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/home/home_view_data.dart';
import 'package:naliv_delivery/features/home/ui/home_page.dart';
import 'package:naliv_delivery/ui/app_cart_button.dart';
import 'package:naliv_delivery/ui/liquid_glass_dock.dart';

const _fill = Color(0xFFF16800);

// Live supercategory names (see home_data_source.dart): two of them contain a word
// wider than a 98 px column at 14 px.
const _categories = [
  HomeCategory(id: 1, title: 'Слабоалкогольные напитки', fill: _fill),
  HomeCategory(id: 2, title: 'Еда и закуски', fill: _fill),
  HomeCategory(id: 3, title: 'Крепкие напитки', fill: _fill),
  HomeCategory(id: 4, title: 'Безалкогольные напитки', fill: _fill),
  HomeCategory(id: 5, title: 'Табачная продукция', fill: _fill),
  HomeCategory(id: 6, title: 'Аксессуары', fill: _fill),
];

Future<void> _pumpHome(
  WidgetTester tester, {
  required Size size,
  double textScale = 1,
  int cartItems = 0,
  num? cartTotal,
  VoidCallback? onCallCenter,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: const EdgeInsets.only(top: 48, bottom: 34),
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: HomePage(
      data: const HomeViewData(
        storeName: 'Градусы24 — Бухар Жырау 70',
        storeAddress: 'Караганда, проспект Нуркена Абдирова, 17/2',
        banners: [],
        promoCard: null,
        categories: _categories,
      ),
      cartItemCount: cartItems,
      cartTotal: cartTotal,
      onCallCenter: onCallCenter,
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(LiquidGlassDock.warmUp);

  group('cart dock', () {
    testWidgets('stays a compact capsule, filled or empty', (tester) async {
      for (final (items, total) in [(0, null), (3, 45300)]) {
        await _pumpHome(tester,
            size: const Size(375, 812), cartItems: items, cartTotal: total);
        final dock = tester.getRect(find.byType(AppCartButton));
        // The dock once took 124 px plus margins (a fifth of the screen).
        expect(dock.height, inInclusiveRange(48, 812 * 0.1),
            reason: 'dock with $items items is ${dock.height} px tall');
        expect(dock.width, lessThanOrEqualTo(375 - 32));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('never covers the end of the page', (tester) async {
      // Large text makes the filled dock tallest; even an unusually large total
      // must leave the last content reachable above it.
      for (final (size, scale, items, total) in [
        (const Size(375, 812), 1.0, 0, null),
        (const Size(375, 812), 1.0, 3, 45300),
        (const Size(320, 640), 2.0, 12, 123456789),
      ]) {
        await _pumpHome(tester,
            size: size, textScale: scale, cartItems: items, cartTotal: total);
        final scrollable = tester.state<ScrollableState>(find
            .descendant(
                of: find.byType(SingleChildScrollView),
                matching: find.byType(Scrollable))
            .first);
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
        await tester.pump();
        final last =
            tester.getRect(find.byKey(const ValueKey('home-bonus-card')));
        final dock = tester.getRect(find.byType(AppCartButton));
        expect(last.bottom, lessThanOrEqualTo(dock.top),
            reason: 'at ${size.width} px, x$scale text, $items items');
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('header', () {
    testWidgets('keeps support reachable without a broken label',
        (tester) async {
      for (final width in [320.0, 360.0, 375.0]) {
        for (final scale in [1.0, 2.0]) {
          var calls = 0;
          await _pumpHome(tester,
              size: Size(width, 812),
              textScale: scale,
              onCallCenter: () => calls++);
          // The label is dropped when it cannot share the row with four 44 px
          // actions; squeezed in, it used to wrap mid-word at 360 px.
          final label = find.text('Поддержка');
          if (label.evaluate().isNotEmpty) {
            expect(tester.getSize(label).height, lessThan(12 * scale * 1.5),
                reason: 'label wraps at $width px, x$scale text');
          }
          await tester.tap(find.byTooltip('Поддержка'));
          expect(calls, 1, reason: 'support tap at $width px, x$scale text');
          expect(tester.takeException(), isNull,
              reason: 'header overflows at $width px, x$scale text');
        }
      }
    });
  });

  group('categories', () {
    testWidgets('keep three columns and whole words on a 360 px phone',
        (tester) async {
      await _pumpHome(tester, size: const Size(360, 812));
      final tiles = find
          .descendant(
              of: find.byKey(const ValueKey('home-category-grid')),
              matching: find.byType(InkWell))
          .evaluate()
          .map((element) => tester.getRect(find.byWidget(element.widget)))
          .toList();
      expect(tiles.length, 6);
      // The grid used to drop to two 152 px columns below 375 px.
      expect(tiles[2].top, tiles[0].top);
      expect(tiles[3].top, greaterThan(tiles[0].top));

      for (final (index, word) in [
        (0, 'Слабоалкогольные'),
        (3, 'Безалкогольные'),
      ]) {
        final caption = find.text(word);
        expect(caption, findsOneWidget);
        final rect = tester.getRect(caption);
        // One line: a word that cannot fit scales down rather than breaking.
        expect(rect.height, lessThan(14 * 1.5));
        // And it stays inside its tile plus the gutter allowance, clear of neighbours.
        expect(rect.left, greaterThanOrEqualTo(tiles[index].left - 8.5));
        expect(rect.right, lessThanOrEqualTo(tiles[index].right + 8.5));
      }
      expect(tester.takeException(), isNull);
    });
  });
}
