import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/product/ui/product_page.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/pages/product_detail_page.dart';
import 'package:naliv_delivery/pages/promotion_items_page.dart';
import 'package:naliv_delivery/ui/app_states.dart';
import 'package:naliv_delivery/ui/product_card.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/liked_items_provider.dart';
import 'package:naliv_delivery/utils/liked_storage_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('later-page failure retries the complete scoped campaign',
      (tester) async {
    final pages = <String>[];
    final unexpected = <String>[];
    final client = MockClient((request) async {
      final query = request.url.queryParameters;
      if (request.method != 'GET' ||
          request.url.path != '/api/promotions/44/items' ||
          query['business_id'] != '7' ||
          query['limit'] != '50' ||
          !['1', '2'].contains(query['page'])) {
        unexpected.add('$request');
        throw StateError('Unexpected request: $request');
      }
      pages.add(query['page']!);
      if (pages.length == 2) return http.Response('', 503);
      final id = query['page'] == '1' ? 17 : 18;
      return _response({
        'items': [
          _item(id, id == 17 ? 'Первый товар' : 'Второй товар').toJson()
        ],
        'pagination': {'total_pages': '2'},
      });
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(_app(const PromotionItemsPage(
        promotionId: 44,
        businessId: 7,
      )));
      expect(find.byType(AppLoading), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(AppErrorState), findsOneWidget);
      expect(find.byType(ProductCard), findsNothing);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Первый товар'), findsOneWidget);
      expect(find.text('Второй товар'), findsOneWidget);
      expect(pages, ['1', '2', '1', '2']);
      expect(unexpected, isEmpty);
    }, () => client);
  });

  testWidgets('a newer business cannot be overwritten by an older response',
      (tester) async {
    final oldResponse = Completer<http.Response>();
    final requested = <String>[];
    final unexpected = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(_app(const PromotionItemsPage(
        promotionId: 44,
        businessId: 7,
      )));
      await tester.pump();
      await tester.pumpWidget(_app(const PromotionItemsPage(
        promotionId: 44,
        businessId: 8,
      )));
      await tester.pumpAndSettle();
      expect(find.text('Новый магазин'), findsOneWidget);
      oldResponse.complete(_response({
        'items': [_item(17, 'Старый магазин').toJson()],
      }));
      await tester.pumpAndSettle();
      expect(find.text('Новый магазин'), findsOneWidget);
      expect(find.text('Старый магазин'), findsNothing);
      expect(requested, ['7', '8']);
      expect(unexpected, isEmpty);
    },
        () => MockClient((request) async {
              final business = request.url.queryParameters['business_id'];
              if (request.method != 'GET' ||
                  request.url.path != '/api/promotions/44/items' ||
                  !['7', '8'].contains(business)) {
                unexpected.add('$request');
                throw StateError('Unexpected request: $request');
              }
              requested.add(business!);
              if (business == '7') return oldResponse.future;
              return _response({
                'items': [_item(18, 'Новый магазин').toJson()]
              });
            }));
  });

  testWidgets(
      'prefetched products stay visible and fractional stock is bounded',
      (tester) async {
    final cart = CartProvider();
    final weight = Item(
      itemId: 17,
      name: 'Весовой товар',
      price: 1000,
      unit: 'кг',
      amount: 0.75,
      stepQuantity: 0.25,
    );
    final unknown = Item(itemId: 18, name: 'Без остатка в ответе', price: 1500);
    final unavailable = _item(19, 'Недоступный товар', amount: 0);
    final unexpected = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(_app(
        PromotionItemsPage(
          promotionId: 44,
          businessId: 7,
          initialItems: [weight, unknown, unavailable],
        ),
        cart: cart,
      ));
      expect(find.text('Без остатка в ответе'), findsOneWidget);
      expect(find.text('Недоступный товар'), findsOneWidget);
      final first = find.byKey(const ValueKey('promotion-product-0'));
      for (var index = 0; index < 4; index++) {
        await Scrollable.ensureVisible(
          tester.element(
              _step(first, index == 0 ? 'Добавить' : 'Увеличить количество')),
          alignment: 0.5,
        );
        await tester.tap(
            _step(first, index == 0 ? 'Добавить' : 'Увеличить количество'));
        await tester.pumpAndSettle();
      }
      expect(cart.getCatalogQuantity(weight), 0.75);
      expect(find.byType(ProductPage), findsNothing);
      expect(find.byType(ProductDetailPage), findsNothing);
      await Scrollable.ensureVisible(
          tester.element(_step(first, 'Уменьшить количество')),
          alignment: 0.5);
      await tester.tap(_step(first, 'Уменьшить количество'));
      await tester.pumpAndSettle();
      expect(cart.getCatalogQuantity(weight), 0.5);
      final third = find.byKey(const ValueKey('promotion-product-2'));
      await tester.ensureVisible(third);
      await tester.tap(_step(third, 'Добавить'));
      await tester.pumpAndSettle();
      expect(cart.getCatalogQuantity(unavailable), 0);
      expect(unexpected, isEmpty);
    },
        () => MockClient((request) async {
              unexpected.add('$request');
              throw StateError('Unexpected request: $request');
            }));
  });

  testWidgets('likes persist only after success and stay business-scoped',
      (tester) async {
    SharedPreferences.setMockInitialValues({'auth_token': 'mock-token'});
    final liked = LikedItemsProvider();
    final unexpected = <String>[];
    var toggles = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(_app(
        PromotionItemsPage(
          promotionId: 44,
          businessId: 7,
          initialItems: [_item(17, 'Товар')],
        ),
        liked: liked,
      ));
      final heart = find.byKey(const ValueKey('promotion-like-0'));
      await tester.tap(heart);
      await tester.pumpAndSettle();
      expect(liked.isLiked(7, 17), isFalse);
      expect(await LikedStorageService.getLikedIds(businessId: 7), isEmpty);
      await tester.tap(heart);
      await tester.pumpAndSettle();
      expect(liked.isLiked(7, 17), isTrue);
      expect(liked.isLiked(8, 17), isFalse);
      expect(await LikedStorageService.getLikedIds(businessId: 7), {17});
      expect(await LikedStorageService.getLikedIds(businessId: 8), isEmpty);
      expect(toggles, 2);
      expect(unexpected, isEmpty);
    },
        () => MockClient((request) async {
              if (request.method != 'POST' ||
                  request.url.path != '/api/users/liked-items/toggle' ||
                  request.headers['Authorization'] != 'Bearer mock-token' ||
                  jsonDecode(request.body)['item_id'] != 17) {
                unexpected.add('$request');
                throw StateError('Unexpected request: $request');
              }
              toggles++;
              if (toggles == 1) return http.Response('', 503);
              return _response({'is_liked': true});
            }));
  });

  testWidgets('simple and option products open their supported detail routes',
      (tester) async {
    final simple = _item(17, 'Обычный товар');
    final option = Item(
      itemId: 18,
      name: 'Товар с выбором',
      price: 1500,
      amount: 10,
      unit: 'шт',
      options: [
        ItemOption(
          optionId: 1,
          name: 'Упаковка',
          required: 1,
          selection: 'SINGLE',
          optionItems: [
            ItemOptionItem(
              relationId: 11,
              itemId: 101,
              priceType: 'ADD',
              itemName: 'Подарочная упаковка',
              price: 100,
              parentItemAmount: 1,
            ),
          ],
        ),
      ],
    );
    final unexpected = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(_app(PromotionItemsPage(
        promotionId: 44,
        businessId: 7,
        initialItems: [simple, option],
      )));
      await tester.tap(find.text('Обычный товар'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductPage), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Товар с выбором'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductDetailPage), findsOneWidget);
      expect(unexpected, isEmpty);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              unexpected.add('$request');
              throw StateError('Unexpected request: $request');
            }));
  });
}

Finder _step(Finder product, String label) => find.descendant(
      of: product,
      matching: find.byWidgetPredicate(
        (widget) => widget is StepTap && widget.label == label,
      ),
    );

Item _item(int id, String name, {double amount = 10}) => Item(
      itemId: id,
      name: name,
      price: 1000,
      amount: amount,
      unit: 'шт',
    );

http.Response _response(Map<String, Object?> data) => http.Response(
      jsonEncode({'success': true, 'data': data}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Widget _app(
  Widget home, {
  CartProvider? cart,
  LikedItemsProvider? liked,
  double textScale = 1,
  bool dark = true,
}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: cart ?? CartProvider()),
        ChangeNotifierProvider.value(value: liked ?? LikedItemsProvider()),
        ChangeNotifierProvider(create: (_) => BusinessProvider()),
      ],
      child: MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 48, bottom: 34),
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          );
        },
        home: home,
      ),
    );
