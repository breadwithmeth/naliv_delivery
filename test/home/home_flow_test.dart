import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/core/theme_controller.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/catalog/ui/supercategory_page.dart';
import 'package:naliv_delivery/features/home/home_screen.dart';
import 'package:naliv_delivery/features/search/ui/search_page.dart';
import 'package:naliv_delivery/features/profile/ui/profile_page.dart';
import 'package:naliv_delivery/pages/promotion_items_page.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/models/cart_item.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/liked_items_provider.dart';
import 'package:naliv_delivery/ui/app_icon.dart';
import 'package:naliv_delivery/widgets/authentication_wrapper.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/design_surfaces.dart';

void main() {
  testWidgets('home chooses a store and scopes subsequent catalog requests',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final business = BusinessProvider();
    final requests = <Uri>[];
    final cart = CartProvider();
    await http.runWithClient(() async {
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: cart),
          ChangeNotifierProvider.value(value: business),
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ChangeNotifierProvider(create: (_) => LikedItemsProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const AuthenticationWrapper(),
        ),
      ));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const ValueKey('home-store-card')), findsOneWidget);
      // The account icon is the profile route, not the navigation drawer.
      await tester.tap(find.byWidgetPredicate(
        (widget) => widget is AppIcon && widget.asset == AppIcons.user,
      ));
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePage), findsOneWidget);
      expect(find.text('Профиль'), findsOneWidget);
      expect(find.byType(Drawer), findsNothing);
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-store-card')), findsOneWidget);
      expect(find.byType(ProfilePage), findsNothing);

      final item = Item(
        itemId: 17,
        name: 'Товар',
        price: 1000,
        image: '',
        amount: 10,
        unit: 'шт.',
        category: ItemCategory(categoryId: 10, name: 'Напитки'),
      );
      cart.addItem(CartItem(
        itemId: 17,
        name: item.name,
        price: item.price,
        quantity: 1,
        stepQuantity: 1,
        image: '',
        selectedVariants: const [],
        promotions: const [],
        itemData: item.toJson(),
      ));

      await tester.tap(find.byKey(const ValueKey('home-store-card')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-store-2')), findsOneWidget);
      expect(find.text('Астана  1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-store-2')));
      await tester.pumpAndSettle();
      expect(find.text('Сменить магазин?'), findsOneWidget);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(business.selectedBusinessId, isNot(2));
      expect(cart.hasActiveItems, isTrue);

      await tester.tap(find.byKey(const ValueKey('home-store-card')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-store-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сменить магазин').last);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(cart.hasActiveItems, isFalse);
      expect(business.selectedBusinessId, 2);
      expect(
          requests
              .where((uri) => uri.path.endsWith('/promotions/active'))
              .last
              .queryParameters['business_id'],
          '2');
      expect(find.text('Второй магазин'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('home-search-field')));
      await tester.pumpAndSettle();
      expect(find.byType(SearchPage), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('home-promo-card')));
      await tester.pumpAndSettle();
      expect(find.byType(SupercategoryPage), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('home-banner-0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PromotionItemsPage), findsOneWidget,
          reason: 'Requests: $requests');
      expect(
          requests
              .lastWhere((uri) => uri.path.endsWith('/promotions/44/items'))
              .queryParameters['business_id'],
          '2');
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              requests.add(request.url);
              final path = request.url.path;
              Map<String, dynamic> data;
              if (path.endsWith('/businesses')) {
                data = {
                  'businesses': [
                    {
                      'id': 1,
                      'name': 'Первый магазин',
                      'address': 'Улица 1',
                      'city_id': 2,
                    },
                    {
                      'id': 2,
                      'name': 'Второй магазин',
                      'address': 'Улица 2',
                      'city_id': 3,
                    },
                  ],
                };
              } else if (path.endsWith('/users/cities')) {
                data = {
                  'cities': [
                    {'city_id': 2, 'name': 'Караганда'},
                    {'city_id': 3, 'name': 'Астана'},
                  ],
                };
              } else if (path.endsWith('/categories/supercategories')) {
                data = {
                  'supercategories': [
                    {
                      'supercategory_id': 100,
                      'name': 'Кухня',
                      'priority': 100,
                      'categories': <Object>[],
                    },
                    {
                      'supercategory_id': 10,
                      'name': 'Напитки',
                      'priority': 10,
                      'categories': <Object>[],
                    },
                  ],
                };
              } else if (path.endsWith('/promotions/active')) {
                data = {
                  'promotions': [
                    {'marketing_promotion_id': 44, 'name': 'Акции', 'cover': ''}
                  ],
                };
              } else if (path.endsWith('/promotions/44/items')) {
                data = {
                  'items': [
                    {
                      'item_id': 44,
                      'name': 'Напиток',
                      'price': 1200,
                      'amount': 5,
                      'measure': 'шт.',
                      'category': {'category_id': 10, 'name': 'Напитки'}
                    }
                  ],
                };
              } else if (path.contains('/categories/') &&
                  path.endsWith('/items')) {
                data = {'items': <Object>[]};
              } else {
                return http.Response('{}', 404);
              }
              return http.Response(
                  jsonEncode({'success': true, 'data': data}), 200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });
  testWidgets('invalid cached user does not prevent profile refresh navigation',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({
        ...surfaceFixturePreferences,
        'intro_slides_seen': true,
        'onboarding_completed': true,
        'selected_business_id': 1,
        'selected_address': jsonEncode({
          'address': 'Тестовый адрес, 16',
          'lat': 49.8047,
          'lon': 73.1094,
        }),
        'selected_business': jsonEncode({
          'id': 1,
          'name': 'Тестовый магазин',
          'address': 'Тестовый адрес, 16',
        }),
      });
      SurfaceFixtureClient.resetUnexpectedRequests();
      var accountReads = 0;
      final fixture = SurfaceFixtureClient();
      final client = MockClient((request) async {
        if (request.method != 'GET') {
          throw StateError(
              'Unexpected mutation: ${request.method} ${request.url}');
        }
        if (request.url.path == '/api/auth/full-info' && accountReads++ == 0) {
          return http.Response(
              jsonEncode({
                'success': true,
                'data': {'addresses': [], 'cards': []},
              }),
              200);
        }
        return fixture.get(request.url, headers: request.headers);
      });
      await http.runWithClient(() async {
        final theme = ThemeController();
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: theme),
            ChangeNotifierProvider(create: (_) => CartProvider()),
            ChangeNotifierProvider(create: (_) => LikedItemsProvider()),
            ChangeNotifierProvider(create: (_) => BusinessProvider()),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const AuthenticationWrapper(),
          ),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.byWidgetPredicate(
          (widget) => widget is AppIcon && widget.asset == AppIcons.logo,
        ));
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(ProfilePage), findsNothing);
        await tester.tap(find.byWidgetPredicate(
          (widget) => widget is AppIcon && widget.asset == AppIcons.user,
        ));
        await tester.pumpAndSettle();
        expect(find.byType(ProfilePage), findsOneWidget);
        expect(find.text('Айжан · фикстура'), findsOneWidget);
        expect(SurfaceFixtureClient.unexpectedRequests, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
      client.close();
      fixture.close();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
