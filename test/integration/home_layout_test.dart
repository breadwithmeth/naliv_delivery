import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/home/home_view_data.dart';
import 'package:naliv_delivery/features/home/ui/home_page.dart';
import 'package:naliv_delivery/ui/app_cart_button.dart';

import '../support/design_surfaces.dart';

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
  VoidCallback? onLiked,
  VoidCallback? onProfile,
  VoidCallback? onBonusHistory,
  VoidCallback? onNotifications,
  VoidCallback? onStore,
  VoidCallback? onSearch,
  num? bonusBalance,
  bool signedIn = true,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
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
        data: HomeViewData(
          storeName: 'Градусы24 — Бухар Жырау 70',
          storeAddress: 'Караганда, проспект Нуркена Абдирова, 17/2',
          signedIn: signedIn,
          bonusBalance: bonusBalance,
          banners: const [],
          promoCard: null,
          categories: _categories,
        ),
        cartItemCount: cartItems,
        cartTotal: cartTotal,
        onCallCenter: onCallCenter,
        onLiked: onLiked,
        onProfile: onProfile,
        onBonusHistory: onBonusHistory,
        onNotifications: onNotifications,
        onStore: onStore,
        onSearch: onSearch,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('$brightness age confirmation fits 320 px and 2x text',
        (tester) async {
      const size = Size(320, 600);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues(surfaceFixturePreferences);
      final client = SurfaceFixtureClient();
      addTearDown(client.close);
      SurfaceFixtureClient.resetUnexpectedRequests();
      await http.runWithClient(() async {
        await tester.pumpWidget(DesignSurfaceApp(
          surface: 'home_age',
          brightness: brightness,
          size: size,
          textScaler: const TextScaler.linear(2),
          viewInsets: const EdgeInsets.only(bottom: 300),
        ));
        await tester.pumpAndSettle();
        final offer = find.widgetWithText(TextButton, 'Договор оферты');
        final confirm = find.widgetWithText(FilledButton, 'Мне есть 21 год');
        await tester.ensureVisible(offer);
        await tester.pumpAndSettle();
        expect(tester.getSize(offer).height, greaterThanOrEqualTo(44));
        expect(offer.hitTestable(), findsOneWidget);
        await tester.ensureVisible(confirm);
        await tester.pumpAndSettle();
        expect(tester.getSize(confirm).height, greaterThanOrEqualTo(44));
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(confirm, findsNothing);
        expect(tester.takeException(), isNull);
        expect(SurfaceFixtureClient.unexpectedRequests, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    });
  }

  group('cart dock', () {
    testWidgets('stays a compact stamp, filled or empty', (tester) async {
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
                of: find.byType(CustomScrollView),
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
    testWidgets(
      'header actions, store and search work at 320 px with 2x text',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          for (final signedIn in [false, true]) {
            final opened = <String>[];
            await _pumpHome(
              tester,
              size: const Size(320, 812),
              textScale: 2,
              signedIn: signedIn,
              onCallCenter: () => opened.add('contacts'),
              onLiked: () => opened.add('favorites'),
              onProfile: () => opened.add('profile'),
              onBonusHistory: () => opened.add('bonuses'),
              onNotifications: () => opened.add('notifications'),
              onStore: () => opened.add('store'),
              onSearch: () => opened.add('search'),
            );

            final header = find.byKey(const ValueKey('home-header'));
            final store = find.byKey(const ValueKey('home-store-card'));
            final search = find.byKey(const ValueKey('home-search-field'));
            expect(
              tester.getRect(header).bottom,
              lessThanOrEqualTo(tester.getRect(store).top),
            );
            expect(
              tester.getRect(store).bottom,
              lessThanOrEqualTo(tester.getRect(search).top),
            );

            final actions = [
              find.bySemanticsLabel('Связаться'),
              find.bySemanticsLabel('Избранные товары'),
              find.bySemanticsLabel('Профиль'),
              find.bySemanticsLabel('Бонусы'),
              find.bySemanticsLabel('Уведомления'),
              store,
              search,
            ];
            for (final action in actions) {
              final bounds = tester.getRect(action);
              expect(bounds.width, greaterThanOrEqualTo(44));
              expect(bounds.height, greaterThanOrEqualTo(44));
              expect(bounds.left, greaterThanOrEqualTo(0));
              expect(bounds.right, lessThanOrEqualTo(320));
              await tester.tap(action);
            }
            expect(opened, [
              'contacts',
              'favorites',
              'profile',
              'bonuses',
              'notifications',
              'store',
              'search',
            ]);
            expect(tester.takeException(), isNull);
          }
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets(
      'header actions never reveal the balance, including a genuine zero',
      (tester) async {
        final header = find.byKey(const ValueKey('home-header'));
        final zero = find.descendant(of: header, matching: find.text('0'));
        final bonuses = find.descendant(
          of: header,
          matching: find.byTooltip('Бонусы'),
        );

        await _pumpHome(tester, size: const Size(375, 812), bonusBalance: 0);
        expect(bonuses, findsOneWidget);
        expect(zero, findsNothing);

        await _pumpHome(
          tester,
          size: const Size(375, 812),
          signedIn: false,
          bonusBalance: 0,
        );
        expect(bonuses, findsOneWidget);
        expect(zero, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'floats over the page and frosts once content scrolls under it',
      (tester) async {
        for (final signedIn in [true, false]) {
          await _pumpHome(
            tester,
            size: const Size(375, 812),
            signedIn: signedIn,
          );
          bool frosted() =>
              find.byKey(const ValueKey('header-scrim')).evaluate().isNotEmpty;

          // At rest it is an ordinary header on the page, and the first block
          // starts below it rather than under it.
          expect(frosted(), isFalse, reason: 'signedIn=$signedIn');
          final brand = find.byKey(const ValueKey('home-brand-mark'));
          expect(tester.getTopLeft(brand).dy, greaterThanOrEqualTo(48));
          final search = find.byKey(const ValueKey('home-search-field'));
          expect(
            tester.getTopLeft(search).dy,
            greaterThan(tester.getBottomLeft(brand).dy),
          );
          final restBrand = tester.getTopLeft(brand);
          final restSearch = tester.getTopLeft(search);

          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -400),
          );
          await tester.pumpAndSettle();
          expect(frosted(), isTrue, reason: 'signedIn=$signedIn');
          // The header stays where it is while the page moves beneath it.
          expect(tester.getTopLeft(brand), restBrand);
          expect(tester.getTopLeft(search).dy, lessThan(restSearch.dy));

          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, 3000),
          );
          await tester.pumpAndSettle();
          expect(frosted(), isFalse);
          expect(tester.takeException(), isNull);
        }
      },
    );
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
