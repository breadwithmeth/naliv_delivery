import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/core/theme_controller.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/catalog/ui/supercategory_page.dart';
import 'package:naliv_delivery/features/home/age_confirmation_session.dart';
import 'package:naliv_delivery/features/home/home_screen.dart';
import 'package:naliv_delivery/features/search/ui/search_page.dart';
import 'package:naliv_delivery/features/profile/ui/profile_page.dart';
import 'package:naliv_delivery/pages/promotion_items_page.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/model/cart_item.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/liked_items_provider.dart';
import 'package:naliv_delivery/ui/app_icon.dart';
import 'package:naliv_delivery/widgets/authentication_wrapper.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/design_surfaces.dart';
import 'package:naliv_delivery/features/bonuses/ui/bonus_history_page.dart';
import 'package:naliv_delivery/features/notifications/ui/notification_history_page.dart';
import 'package:naliv_delivery/pages/notification_settings_page.dart';
import 'package:naliv_delivery/pages/login_page.dart';

void main() {
  for (final inbox in [false, true]) {
    testWidgets('guest header ${inbox ? "inbox" : "bonuses"} resumes after fixture OTP', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(
      {...surfaceFixturePreferences}..remove('auth_token'),
    );
    SurfaceFixtureClient.resetUnexpectedRequests();
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = SurfaceFixtureClient();
    await http.runWithClient(() async {
      await tester.pumpWidget(
        const DesignSurfaceApp(
          surface: 'active_route',
          brightness: Brightness.dark,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(inbox ? 'Уведомления' : 'Бонусы'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('auth-phone-input')),
        '0000000000',
      );
      await tester.tap(find.byKey(const ValueKey('request-code-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('auth-code-input')),
        '123456',
      );
      await tester.pumpAndSettle();
      if (inbox) {
        expect(find.byType(NotificationHistoryPage), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Настройки уведомлений'));
        await tester.pumpAndSettle();
        expect(find.byType(NotificationSettingsPage), findsOneWidget);
        await tester.tap(find.byTooltip('Назад'));
        await tester.pumpAndSettle();
        expect(find.byType(NotificationHistoryPage), findsOneWidget);
      } else {
        expect(find.byType(BonusHistoryPage), findsOneWidget);
      }
      expect(SurfaceFixtureClient.unexpectedRequests, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    client.close();
  });
  }

  testWidgets('unknown store city never recommends saved onboarding city', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(surfaceFixturePreferences);
    SurfaceFixtureClient.resetUnexpectedRequests();
    final fixture = SurfaceFixtureClient();
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/businesses') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'businesses': [
                {
                  'id': 1,
                  'name': 'Неизвестный город магазина',
                  'address': 'Адрес',
                  'city_id': 999,
                },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      final copy = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..bodyBytes = request.bodyBytes;
      return http.Response.fromStream(await fixture.send(copy));
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
        const DesignSurfaceApp(
          surface: 'active_route',
          brightness: Brightness.light,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Связаться'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Позвонить ·'), findsNothing);
      for (final name in ['Павлодар', 'Караганда', 'Астана', 'Темиртау']) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.text('Написать в чат'), findsOneWidget);
      expect(SurfaceFixtureClient.unexpectedRequests, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
    client.close();
    fixture.close();
  });
  testWidgets('home chooses a store and scopes subsequent catalog requests', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final business = BusinessProvider();
    final requests = <Uri>[];
    final cart = CartProvider();
    await cart.bindBusiness(1);
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
          home: AuthenticationWrapper(
            ageConfirmation: AgeConfirmationSession(),
          ),
        ),
      ));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text('Мне есть 21 год'));
      await tester.pumpAndSettle();
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

        Future<void> expectContact(String city, String phone) async {
          await tester.tap(find.byTooltip('Связаться'));
          await tester.pumpAndSettle();
          expect(find.text('Позвонить · $city'), findsOneWidget);
          expect(find.text(phone), findsOneWidget);
          await tester.tap(find.byTooltip('Закрыть'));
          await tester.pumpAndSettle();
        }

        await expectContact('Караганда', '+77719290005');
        final firstStore = business.selectedBusiness;
        await business.setSelectedBusiness({
          'id': 2, 'name': 'Второй магазин', 'address': 'Улица 2', 'city_id': 3,
        });
        await cart.bindBusiness(2);
        await expectContact('Астана', '+77719291001');
        await business.setSelectedBusiness(firstStore);
        await cart.bindBusiness(1);

        final item = Item(
          itemId: 17,
          name: 'Товар',
          price: 1000,
          image: '',
          amount: 10,
          unit: 'шт.',
          category: ItemCategory(categoryId: 10, name: 'Напитки'),
        );
        cart.addItem(
          CartItem(
            itemId: 17,
            name: item.name,
            price: item.price,
            quantity: 1,
            stepQuantity: 1,
            image: '',
            selectedVariants: const [],
            promotions: const [],
            itemData: item.toJson(),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('home-store-card')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('home-store-2')), findsOneWidget);
        expect(find.text('Астана  1'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('home-store-2')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Отмена'));
        await tester.pumpAndSettle();
        expect(business.selectedBusinessId, isNot(2));
        expect(cart.hasActiveItems, isTrue);
        await expectContact('Караганда', '+77719290005');

        await tester.tap(find.byKey(const ValueKey('home-store-card')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('home-store-2')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('confirm-store-change')));
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
          '2',
        );
        expect(find.text('Второй магазин'), findsWidgets);
        await expectContact('Астана', '+77719291001');
        await tester.tap(find.byKey(const ValueKey('home-search-field')));
        await tester.pumpAndSettle();
        expect(find.byType(SearchPage), findsOneWidget);
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();

      // Store 2 does not sell the kitchen: no promo card, the tiles are the remaining ones.
      expect(find.byKey(const ValueKey('home-promo-card')), findsNothing);
      expect(find.text('Кухня'), findsNothing);
      await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('home-category-grid')),
        matching: find.text('Напитки'),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(SupercategoryPage), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      final rail = find.byKey(const ValueKey('home-banner-carousel'));
      expect(find.text('Акции').hitTestable(), findsOneWidget);
      // The first campaign's predecessor is the last campaign for the new store.
      await tester.drag(rail, const Offset(325, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Выгодный розлив').hitTestable());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PromotionItemsPage), findsOneWidget,
          reason: 'Requests: $requests');
      expect(
          requests
              .lastWhere((uri) => uri.path.endsWith('/promotions/91/items'))
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
                    if (request.url.queryParameters['business_id'] == '2') ...[
                      {'marketing_promotion_id': 44, 'name': 'Акции', 'cover': ''},
                      {
                        'marketing_promotion_id': 91,
                        'name': 'Выгодный розлив',
                        'cover': '',
                      },
                    ] else
                      {'marketing_promotion_id': 21, 'name': 'Акция первого магазина'},
                  ],
                };
              } else if (path.endsWith('/promotions/91/items')) {
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
            home: AuthenticationWrapper(
              ageConfirmation: AgeConfirmationSession()..confirm(),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('home-brand-mark')));
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
