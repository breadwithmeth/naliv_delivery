import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/cart/ui/cart_page.dart';
import 'package:naliv_delivery/model/cart_item.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/pages/product_detail_page.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/haptic_calls.dart';
import '../support/preferences_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('keeps display order stable when regrouping an existing item', () async {
    final first = _pourItem();
    final second = Item(
        itemId: 802,
        name: 'Чипсы',
        price: 500,
        amount: 10,
        quantity: 1,
        unit: 'шт.');
    final cart = CartProvider();
    addTearDown(cart.dispose);
    expect(await cart.bindBusiness(1), isTrue);
    cart
      ..syncItemBottleCounts(first, [], {1: 1})
      ..incrementCatalogItem(second);
    expect(
        cart.displayGroups.map((group) => group.itemId).toList(), [801, 802]);
    cart.syncItemBottleCounts(first, [], {2: 1});
    expect(
        cart.displayGroups.map((group) => group.itemId).toList(), [801, 802]);
  });

  testWidgets(
      'cart quantity controls mutate quantity without entering the editor',
      (tester) async {
    final item = Item(
        itemId: 703,
        name: 'Тоник',
        price: 700,
        amount: 4,
        quantity: 1,
        unit: 'шт.');
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await cart.bindBusiness(1);
    cart.syncItemSelectionQuantity(item, [], 3);
    final semantics = tester.ensureSemantics();
    try {
      await _mount(tester, cart);
      await tester.tap(find.bySemanticsLabel('Добавить одну штуку'));
      await tester.pumpAndSettle();
      expect(cart.getCatalogQuantity(item), 4);
      expect(cart.getTotalPrice(), 2800);
      expect(find.byType(ProductDetailPage), findsNothing);
      await tester.tap(find.bySemanticsLabel('Убрать одну штуку'));
      await tester.pumpAndSettle();
      expect(cart.getCatalogQuantity(item), 3);
      expect(cart.getTotalPrice(), 2100);
      expect(find.byType(ProductDetailPage), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
      'the final fraction deletes and restores instantly with Reduce Motion',
      (tester) async {
    final item = Item(
        itemId: 704,
        name: 'Сыр',
        price: 5000,
        amount: 2,
        quantity: 0.25,
        stepQuantity: 0.25,
        unit: 'кг.');
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await cart.bindBusiness(1);
    cart.syncItemSelectionQuantity(item, [], 0.5);
    final semantics = tester.ensureSemantics();
    try {
      await _mount(tester, cart, disableAnimations: true);
      await tester.tap(find.bySemanticsLabel('Убрать одну штуку'));
      await tester.pumpAndSettle();
      expect(cart.activeDisplayGroups.single.totalQuantity, 0.25);
      expect(cart.getTotalPrice(), 1250);
      expect(find.bySemanticsLabel('Убрать одну штуку'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Удалить товар'));
      await tester.pump();
      expect(cart.items, isEmpty);
      expect(cart.hasActiveItems, isFalse);
      expect(find.text('Сыр'), findsNothing);
      final undo = find.byKey(const ValueKey('cart-undo'));
      expect(undo.hitTestable(), findsOneWidget);
      await tester.tap(undo);
      await tester.pump();
      expect(undo, findsNothing);
      expect(find.bySemanticsLabel('Удалить товар'), findsOneWidget);
      expect(cart.activeDisplayGroups.single.totalQuantity, 0.25);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('rapid fractional taps obey stock without throttling edits',
      (tester) async {
    enableQuantityClicks(tester);
    final calls = recordHapticCalls(tester);
    final item = Item(
      itemId: 707,
      name: 'Ореховая смесь',
      price: 4000,
      amount: 0.75,
      quantity: 0.25,
      stepQuantity: 0.25,
      unit: 'кг.',
    );
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await cart.bindBusiness(1);
    expect(cart.syncItemSelectionQuantity(item, [], 0.25), isTrue);
    await _mount(tester, cart);

    final plus = find.bySemanticsLabel('Добавить одну штуку');
    await tester.tap(plus);
    await tester.tap(plus);
    await tester.pump();
    expect(cart.activeDisplayGroups.single.totalQuantity, 0.75);
    expect(cart.getTotalPrice(), 3000);
    expect(calls, [selectionClick]);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(tester.getCenter(plus));
    expect(cart.activeDisplayGroups.single.totalQuantity, 0.75);
    expect(calls, [selectionClick]);

    await tester.tap(find.bySemanticsLabel('Убрать одну штуку'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(cart.activeDisplayGroups.single.totalQuantity, 0.5);
    expect(calls, [selectionClick, selectionClick]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a long configured row swaps in place with only one live state',
      (tester) async {
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await cart.bindBusiness(1);
    final item = _pourItem().copyWith(
      name: 'Разливное пиво выдержанное нефильтрованное с ароматным хмелем',
    );
    const flavor = {
      'relation_id': 41,
      'item_id': 141,
      'item_name': 'Можжевельник',
      'price_type': 'FIXED',
      'price': 0,
      'required': 0,
    };
    for (var i = 8101; i <= 8110; i++) {
      if (i == 8105) {
        expect(cart.syncItemBottleCounts(item, [flavor], {1: 1, 2: 1}), isTrue);
      } else {
        expect(cart.syncItemSelectionQuantity(_unitItem(i, 'Товар $i'), [], 2),
            isTrue);
      }
    }
    final group = cart.displayGroups.singleWhere((group) => group.itemId == 801);
    await _mount(tester, cart, size: const Size(320, 812), textScale: 2);
    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('cart-scroll')),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    final row = find.byKey(ValueKey('cart-open-${group.key}'));
    await tester.scrollUntilVisible(row, 160, scrollable: scrollable);
    final remove = find.bySemanticsLabel('Удалить товар');
    await Scrollable.ensureVisible(tester.element(remove), alignment: .4);
    await tester.pumpAndSettle();
    final offset = position.pixels;
    expect(offset, greaterThan(0));

    final next = cart.displayGroups.singleWhere((g) => g.itemId == 8106);
    final nextTitle = find.byKey(ValueKey('cart-open-${next.key}'));
    final nextTop = tester.getTopLeft(nextTitle).dy;
    final undo = find.byKey(const ValueKey('cart-undo'));
    final bottles = find.byKey(ValueKey('cart-bottles-${group.key}'));
    await tester.tap(remove);
    await tester.pump();
    expect(cart.displayGroups.any((group) => group.itemId == 801), isFalse);
    expect(position.pixels, offset);
    expect(tester.getTopLeft(nextTitle).dy, nextTop);
    expect(bottles, findsOneWidget, reason: 'the active row is still fading');
    expect(bottles.hitTestable(), findsNothing);
    expect(remove, findsNothing);
    expect(undo.hitTestable(), findsOneWidget);
    expect(find.bySemanticsLabel('Вернуть'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 32));
    await tester.tap(undo);
    await tester.pump();
    expect(undo, findsOneWidget, reason: 'the removed row is still fading');
    expect(undo.hitTestable(), findsNothing);
    expect(find.bySemanticsLabel('Вернуть'), findsNothing);
    expect(remove.hitTestable(), findsOneWidget);
    expect(position.pixels, offset);
    expect(tester.getTopLeft(nextTitle).dy, nextTop);
    final restored = cart.displayGroups[4];
    expect(restored.key, group.key);
    expect(restored.totalQuantity, 3);
    expect(restored.bottleCounts, {1: 1, 2: 1});
    expect(restored.baseVariants.single['relation_id'], 41);

    await tester.pump(const Duration(milliseconds: 180));
    expect(undo, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recommendations use the same accepted-add and step feedback',
      (tester) async {
    enableQuantityClicks(tester);
    final calls = recordHapticCalls(tester);
    final anchor = _unitItem(708, 'Тоник').copyWith(
      category: ItemCategory(categoryId: 10, name: 'Напитки'),
    );
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await cart.bindBusiness(1);
    expect(cart.syncItemSelectionQuantity(anchor, [], 1), isTrue);
    final unexpected = <String>[];
    final client = MockClient((request) async {
      if (request.method != 'GET' ||
          request.url.path != '/api/categories/10/items' ||
          request.url.queryParameters['business_id'] != '1') {
        unexpected.add('$request');
        throw StateError('Unexpected $request');
      }
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'items': [
              {
                'item_id': 709,
                'name': 'Лимонад',
                'price': 500,
                'amount': 2,
                'measure': 'шт.',
                'category': {'category_id': 10, 'name': 'Напитки'},
              },
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    addTearDown(client.close);
    addTearDown(() => expect(unexpected, isEmpty));

    await http.runWithClient(() async {
      await _mount(tester, cart, size: const Size(375, 1000), businessId: 1);
      Finder control(String label) => find.descendant(
        of: find.byKey(const ValueKey('cart-recommendation-strip')),
        matching: find.bySemanticsLabel(label),
      );
      expect(calls, isEmpty);
      await tester.tap(control('Добавить'));
      await tester.pumpAndSettle();
      expect(cart.getTotalQuantityForItem(709), 1);
      expect(calls, [lightImpact]);

      final plus = control('Увеличить количество');
      await tester.tap(plus);
      await tester.pumpAndSettle();
      expect(cart.getTotalQuantityForItem(709), 2);
      expect(calls, [lightImpact, selectionClick]);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(plus);
      expect(cart.getTotalQuantityForItem(709), 2);
      expect(calls, [lightImpact, selectionClick]);

      await tester.tap(control('Уменьшить количество'));
      await tester.pumpAndSettle();
      expect(cart.getTotalQuantityForItem(709), 1);
      expect(calls, [lightImpact, selectionClick, selectionClick]);
      await tester.pumpWidget(const SizedBox());
    }, () => client);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('legacy kitchen cart rows use the same title through undo',
      (tester) async {
    final cart = CartProvider();
    addTearDown(cart.dispose);
    expect(await cart.bindBusiness(11), isTrue);
    const rawName = 'Кухня — бургер BBQ';
    expect(
      cart.addItem(CartItem(
        itemId: 705,
        name: rawName,
        price: 1500,
        quantity: 1,
        stepQuantity: 1,
        itemType: 'Кухня',
        selectedVariants: const [],
        promotions: const [],
      )),
      isTrue,
    );
    final originalKey = cart.displayGroups.single.key;

    await _mount(tester, cart);
    expect(find.text('Бургер BBQ'), findsOneWidget);
    expect(find.text('Кухня'), findsNothing);
    expect(find.text(rawName), findsNothing);

    await tester.tap(find.bySemanticsLabel('Удалить товар'));
    await tester.pumpAndSettle();
    expect(
        find.text('Удалено · Бургер BBQ', findRichText: true), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cart-undo')));
    await tester.pumpAndSettle();
    expect(find.text('Бургер BBQ'), findsOneWidget);
    expect(cart.displayGroups.single.key, originalKey);
    expect(cart.items.single.name, rawName);
    expect(cart.items.single.itemType, 'Кухня');
    expect(tester.takeException(), isNull);
  });

  testWidgets('only the last removed row stays, and «Вернуть» restores it',
      (tester) async {
    enableQuantityClicks(tester);
    final calls = recordHapticCalls(tester);
    final first = _unitItem(711, 'Тоник');
    final second = _unitItem(712, 'Чипсы');
    final third = _unitItem(713, 'Орешки');
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await cart.bindBusiness(1);
    cart
      ..syncItemSelectionQuantity(first, [], 1)
      ..syncItemSelectionQuantity(second, [], 1)
      ..syncItemSelectionQuantity(third, [], 2);
    final semantics = tester.ensureSemantics();
    try {
      await _mount(tester, cart);
      final deletes = find.bySemanticsLabel('Удалить товар');
      await tester.tap(deletes.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Вернуть'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Удалить товар').first);
      await tester.pump();
      // The earlier removal is gone for good; one placeholder at a time.
      expect(find.text('Вернуть'), findsOneWidget);
      expect(find.bySemanticsLabel('Вернуть'), findsOneWidget);
      expect(calls, [selectionClick, selectionClick]);
      expect(cart.items.map((row) => row.itemId), [713]);
      await tester.pump(const Duration(milliseconds: 100));
      expect(calls, [selectionClick, selectionClick]);
      await tester.tap(find.text('Вернуть'));
      await tester.pumpAndSettle();
      expect(find.text('Вернуть'), findsNothing);
      expect(cart.items.map((row) => row.itemId).toSet(), {712, 713});
      expect(cart.displayGroups.map((group) => group.itemId), [712, 713]);
      expect(calls, [selectionClick, selectionClick, selectionClick]);
    } finally {
      semantics.dispose();
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('rejected undo keeps the removed row and emits no feedback',
      (tester) async {
    enableQuantityClicks(tester);
    final calls = recordHapticCalls(tester);
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await cart.bindBusiness(1);
    final item = _unitItem(714, 'Компот');
    expect(cart.syncItemSelectionQuantity(item, [], 1), isTrue);
    await _mount(tester, cart);
    final undo = find.byKey(const ValueKey('cart-undo'));
    await tester.tap(find.bySemanticsLabel('Удалить товар'));
    await tester.pumpAndSettle();
    expect(await cart.ensureSaved(), isTrue);
    expect(calls, [selectionClick]);
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('cart_items')!;
    expect(await prefs.setString('cart_items', '{unread'), isTrue);
    expect(await cart.retryLoad(), isFalse);
    // The last painted button can receive a tap before the error frame.
    await tester.tap(undo);
    expect(cart.items, isEmpty);
    expect(calls, [selectionClick]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cart-load-error')), findsOneWidget);

    expect(await prefs.setString('cart_items', saved), isTrue);
    expect(await cart.retryLoad(), isTrue);
    await tester.pumpAndSettle();
    expect(undo.hitTestable(), findsOneWidget);
    await tester.tap(undo);
    await tester.pumpAndSettle();
    expect(cart.getCatalogQuantity(item), 1);
    expect(undo, findsNothing);
    expect(calls, [selectionClick, selectionClick]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('cart restore error follows external recovery and local retry',
      (tester) async {
    OnboardingPreferences({'cart_items': '{unread'}).install();
    final cart = CartProvider();
    addTearDown(cart.dispose);
    final unexpected = <String>[];
    final client = MockClient((request) async {
      unexpected.add('${request.method} ${request.url}');
      throw StateError('Cart restore fixture must not access the network');
    });
    addTearDown(client.close);
    addTearDown(() => expect(unexpected, isEmpty));
    await http.runWithClient(() async {
      await _mount(tester, cart);
      expect(find.byKey(const ValueKey('cart-load-error')), findsOneWidget);
      expect(find.byKey(const ValueKey('cart-total-bar')), findsNothing);
      expect(cart.saveStatus.value, CartSaveStatus.restoreFailed);
      final row = CartItem(
        itemId: 8501,
        name: 'Восстановленный товар',
        price: 100,
        quantity: 1,
        stepQuantity: 1,
        selectedVariants: const [],
        promotions: const [],
      );
      final repaired = jsonEncode({
        'business_id': 7,
        'items': [row.toJson()],
      });
      final prefs = await SharedPreferences.getInstance();
      expect(await prefs.setString('cart_items', repaired), isTrue);
      expect(await cart.retryLoad(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cart-load-error')), findsNothing);
      expect(find.text('Восстановленный товар'), findsOneWidget);
      expect(find.byKey(const ValueKey('cart-total-bar')), findsOneWidget);

      expect(await prefs.setString('cart_items', '{still-unread'), isTrue);
      expect(await cart.retryLoad(), isFalse);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cart-load-error')), findsOneWidget);
      expect(cart.items.single.quantity, 1);
      expect(find.byKey(const ValueKey('cart-total-bar')), findsNothing);
      expect(await prefs.setString('cart_items', repaired), isTrue);
      await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('cart-load-error')),
        matching: find.text('Повторить'),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cart-load-error')), findsNothing);
      expect(find.text('Восстановленный товар'), findsOneWidget);
      expect(cart.saveStatus.value, CartSaveStatus.saved);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }, () => client);
  });
}

Future<void> _mount(
  WidgetTester tester,
  CartProvider cart, {
  Size size = const Size(375, 812),
  double textScale = 1,
  bool disableAnimations = false,
  int? businessId,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ChangeNotifierProvider<CartProvider>.value(
    value: cart,
    child: MaterialApp(
      theme: AppTheme.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: child!,
      ),
      home: CartPage(businessId: businessId),
    ),
  ));
  await tester.pumpAndSettle();
}

Item _unitItem(int id, String name) => Item(
      itemId: id,
      name: name,
      price: 500,
      amount: 10,
      quantity: 1,
      unit: 'шт.',
    );

Item _pourItem() => Item(
      itemId: 801,
      name: 'Разливное пиво',
      price: 1000,
      amount: 8,
      unit: 'л.',
      options: [
        ItemOption(
            optionId: 1,
            name: 'Тара',
            required: 1,
            selection: 'SINGLE',
            optionItems: [
              ItemOptionItem(
                  relationId: 1,
                  itemId: 101,
                  priceType: 'FIXED',
                  itemName: 'Бутылка 1 л',
                  price: 50,
                  parentItemAmount: 1),
              ItemOptionItem(
                  relationId: 2,
                  itemId: 102,
                  priceType: 'FIXED',
                  itemName: 'Бутылка 2 л',
                  price: 120,
                  parentItemAmount: 2),
            ])
      ],
    );
