import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/core/money.dart';
import 'package:naliv_delivery/features/cart/ui/cart_page.dart';
import 'package:naliv_delivery/model/cart_item.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/pages/product_detail_page.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/smart_cart.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/bottling_surface_items.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'required multi selection blocks save and optional single can be cleared',
      (tester) async {
    final item = _optionsItem(amount: 3);
    final cart = await _newCart(tester);
    await _mount(tester, cart, ProductDetailPage(item: item));
    await _tap(tester, 'configuration-option-8-51');
    await _tap(tester, 'configuration-save');
    expect(cart.items, isEmpty);
    await _tap(tester, 'configuration-option-8-52');
    await _tap(tester, 'configuration-option-9-61');
    await _tap(tester, 'configuration-option-9-61');
    await _tap(tester, 'configuration-quantity-plus');
    await _tap(tester, 'configuration-save');
    final group = cart.activeDisplayGroups.single;
    expect(group.baseVariants.map(SmartCartSelection.variantRelationId).toSet(),
        {41, 52});
    expect(group.totalQuantity, 2);
    expect(group.totalPrice, 2100);
  });

  testWidgets(
      'single and multiple options preserve price and relation IDs after reload and edit',
      (tester) async {
    final item = _optionsItem();
    final cart = await _newCart(tester);
    await _mount(tester, cart, ProductDetailPage(item: item));
    await _tap(tester, 'configuration-option-7-42');
    await _tap(tester, 'configuration-option-8-52');
    await _tap(tester, 'configuration-option-9-61');
    await _tap(tester, 'configuration-save');
    final restored = CartProvider();
    await restored.loadCart();
    final group = restored.activeDisplayGroups.single;
    expect(group.baseVariants.map(SmartCartSelection.variantRelationId).toSet(),
        {42, 51, 52, 61});
    expect(group.totalPrice, 1200);
    expect(group.items.single.toJsonForOrder()['options'], [
      {'option_item_relation_id': 42, 'amount': 1},
      {'option_item_relation_id': 51, 'amount': 1},
      {'option_item_relation_id': 52, 'amount': 1},
      {'option_item_relation_id': 61, 'amount': 1},
    ]);
    await _mount(tester, restored, const CartPage());
    await _tap(tester, 'cart-edit-${group.key}');
    for (final key in [
      'configuration-option-7-42',
      'configuration-option-8-51',
      'configuration-option-8-52',
      'configuration-option-9-61',
    ]) {
      expect(tester.widget<CheckboxListTile>(find.byKey(ValueKey(key))).value,
          isTrue);
    }
    await _tap(tester, 'configuration-quantity-plus');
    await _tap(tester, 'configuration-save');
    final edited = restored.activeDisplayGroups.single;
    expect(
        edited.baseVariants.map(SmartCartSelection.variantRelationId).toSet(),
        {42, 51, 52, 61});
    expect(edited.totalQuantity, 2);
    expect(edited.totalPrice, 2400);
  });

  testWidgets(
      'editing one option group restores it and leaves sibling configurations intact',
      (tester) async {
    final item = _optionsItem();
    final sweet = [
      _map(item.options![0].optionItems[1], required: 1),
      _map(item.options![1].optionItems[0], required: 1)
    ];
    final plain = [
      _map(item.options![0].optionItems[0], required: 1),
      _map(item.options![1].optionItems[0], required: 1)
    ];
    final cart = await _newCart(tester);
    cart
      ..syncItemSelectionQuantity(item, plain, 1)
      ..syncItemSelectionQuantity(item, sweet, 2);
    await _mount(tester, cart,
        ProductDetailPage(item: item, initialBaseVariants: sweet));
    expect(
        tester
            .widget<CheckboxListTile>(
                find.byKey(const ValueKey('configuration-option-7-42')))
            .value,
        isTrue);
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('configuration-quantity')))
            .data,
        '2 шт.');
    await _tap(tester, 'configuration-option-9-61');
    await _tap(tester, 'configuration-save');
    expect(
        cart.activeDisplayGroups
            .singleWhere((group) =>
                group.key ==
                SmartCartSelection(item).displayKeyForVariants(plain))
            .totalQuantity,
        1);
    final edited = cart.activeDisplayGroups.singleWhere((group) =>
        group.key != SmartCartSelection(item).displayKeyForVariants(plain));
    expect(edited.totalQuantity, 2);
    expect(
        edited.baseVariants.map(SmartCartSelection.variantRelationId).toSet(),
        {42, 51, 61});
    expect(
        cart.displayGroups.any((group) =>
            group.key == SmartCartSelection(item).displayKeyForVariants(sweet)),
        isFalse);
  });

  testWidgets(
      'editing into a sibling configuration refuses to overwrite either group',
      (tester) async {
    final item = _optionsItem();
    final plain = [
      _map(item.options![0].optionItems[0], required: 1),
      _map(item.options![1].optionItems[0], required: 1)
    ];
    final sweet = [
      _map(item.options![0].optionItems[1], required: 1),
      _map(item.options![1].optionItems[0], required: 1)
    ];
    final cart = await _newCart(tester);
    cart
      ..syncItemSelectionQuantity(item, plain, 1)
      ..syncItemSelectionQuantity(item, sweet, 2);
    final before = cart.items.map((item) => item.toJson()).toList();
    await _mount(tester, cart,
        ProductDetailPage(item: item, initialBaseVariants: sweet));
    await _tap(tester, 'configuration-option-7-41');
    await _tap(tester, 'configuration-save');
    expect(cart.items.map((item) => item.toJson()).toList(), before);
    expect(
        find.byKey(const ValueKey('configuration-feedback')), findsOneWidget);
  });

  testWidgets('pour summary and first bottle remain exposed before buying',
      (tester) async {
    final cart = await _newCart(tester);
    await _mount(
        tester,
        cart,
        Builder(builder: (context) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(top: 48, bottom: 34)),
            child: ProductDetailPage(item: capturedPourSurfaceItem()),
          );
        }));
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpAndSettle();
    final buy = find.byKey(const ValueKey('configuration-save'));
    final summary = find.byKey(
        const ValueKey('configuration-price-breakdown'));
    final firstBottle = find.byKey(
        const ValueKey('configuration-bottle-2710-plus'));
    expect(tester.getBottomRight(summary).dy,
        lessThanOrEqualTo(tester.getTopLeft(buy).dy));
    expect(tester.getBottomRight(firstBottle).dy,
        lessThanOrEqualTo(tester.getTopLeft(buy).dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('3+1 preview cart reopen and stepping retain paid litres only',
      (tester) async {
    final item = syntheticThreePlusOneSurfaceItem(onlyOneLitre: true);
    final cart = await _newCart(tester);
    await _mount(tester, cart, ProductDetailPage(item: item));
    await _tap(tester, 'configuration-bottle-93101-plus');
    await _tap(tester, 'configuration-bottle-93101-plus');
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('configuration-total')))
            .data,
        formatTenge(3400));
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('configuration-volume')))
            .data,
        '4 л');
    await _tap(tester, 'configuration-save');
    expect(cart.getTotalPrice(), 3400);
    expect(cart.toJsonForOrder().single['amount'], 4);
    await _mount(tester, cart, const CartPage());
    await _tap(tester, 'cart-edit-${cart.activeDisplayGroups.single.key}');
    expect(
        tester
            .widget<Text>(
                find.byKey(const ValueKey('configuration-bottle-93101')))
            .data,
        '3');
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('configuration-total')))
            .data,
        formatTenge(3400));
    await _tap(tester, 'configuration-save');
    await tester.tap(find.bySemanticsLabel('Добавить выбранный набор бутылок'));
    await tester.pumpAndSettle();
    final group = cart.activeDisplayGroups.single;
    expect(group.totalQuantity, 4);
    expect(group.freeQuantity, 1);
    expect(group.bottleCounts, {93101: 5});
    expect(group.totalPrice, 4500);
    expect(cart.toJsonForOrder().single['amount'], 5);
  });

  testWidgets('impossible whole gift allocation visibly refuses saving',
      (tester) async {
    final item = _pourItem(onlyTwoLitres: true, promotions: [
      ItemPromotion(
          promotionId: 2,
          name: '2+1',
          discountType: 'SUBTRACT',
          discountValue: 0,
          baseAmount: 2,
          addAmount: 1),
    ]);
    final cart = await _newCart(tester);
    await _mount(tester, cart, ProductDetailPage(item: item));
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('configuration-save')))
            .onPressed,
        isNull);
    expect(
        find.byKey(const ValueKey('configuration-feedback')), findsOneWidget);
    expect(cart.items, isEmpty);
  });

  testWidgets('zero stock never adds a configuration or allocates bottles',
      (tester) async {
    final item = _pourItem(amount: 0);
    final cart = await _newCart(tester);
    await _mount(tester, cart, ProductDetailPage(item: item));
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('configuration-save')))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<IconButton>(
                find.byKey(const ValueKey('configuration-bottle-1-plus')))
            .onPressed,
        isNull);
    expect(cart.items, isEmpty);
  });

  testWidgets(
      'cart cancel discards draft and subsequent save only edits the opened bottle group',
      (tester) async {
    final item = _pourItem(withTaste: true);
    final plain = [_map(item.options![1].optionItems[0], required: 1)];
    final berry = [_map(item.options![1].optionItems[1], required: 1)];
    final cart = await _newCart(tester);
    cart
      ..syncItemBottleCounts(item, plain, {1: 1, 2: 1})
      ..syncItemBottleCounts(item, berry, {2: 1});
    final before = cart.items.map((item) => item.toJson()).toList();
    await _mount(tester, cart, const CartPage());
    await _tap(tester,
        'cart-edit-${SmartCartSelection(item).displayKeyForVariants(plain)}');
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('configuration-bottle-1')))
            .data,
        '1');
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('configuration-bottle-2')))
            .data,
        '1');
    await _tap(tester, 'configuration-bottle-1-minus');
    await _tap(tester, 'configuration-option-7-42');
    await _tap(tester, 'configuration-back');
    expect(cart.items.map((item) => item.toJson()).toList(), before);
    expect(find.byType(CartPage), findsOneWidget);
    await _tap(tester,
        'cart-edit-${SmartCartSelection(item).displayKeyForVariants(plain)}');
    await _tap(tester, 'configuration-bottle-1-minus');
    await _tap(tester, 'configuration-save');
    expect(
        cart.activeDisplayGroups
            .singleWhere((group) =>
                group.key ==
                SmartCartSelection(item).displayKeyForVariants(plain))
            .bottleCounts,
        {2: 1});
    expect(
        cart.activeDisplayGroups
            .singleWhere((group) =>
                group.key ==
                SmartCartSelection(item).displayKeyForVariants(berry))
            .bottleCounts,
        {2: 1});
    expect(cart.getTotalPrice(), 4240);
  });

  testWidgets(
      'cart save and reload restores real labels, selected options and bottle counts',
      (tester) async {
    final item = _pourItem(withTaste: true);
    final plain = [_map(item.options![1].optionItems[0], required: 1)];
    final berry = [_map(item.options![1].optionItems[1], required: 1)];
    final plainKey = SmartCartSelection(item).displayKeyForVariants(plain);
    final berryKey = SmartCartSelection(item).displayKeyForVariants(berry);
    final cart = await _newCart(tester);
    cart
      ..syncItemBottleCounts(item, plain, {1: 1, 2: 2})
      ..syncItemBottleCounts(item, berry, {2: 1});
    await _mount(tester, cart, const CartPage());
    await tester.pumpAndSettle();
    final restored = CartProvider();
    await restored.loadCart();
    final group = restored.activeDisplayGroups
        .singleWhere((group) => group.key == plainKey);
    await _mount(tester, restored, const CartPage());
    await _tap(tester, 'cart-edit-${group.key}');
    expect(find.text('Бутылка 1 л'), findsOneWidget);
    expect(find.text('Бутылка 2 л'), findsOneWidget);
    expect(find.text('Классический'), findsOneWidget);
    expect(
        tester
            .widget<CheckboxListTile>(
                find.byKey(const ValueKey('configuration-option-7-41')))
            .value,
        isTrue);
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('configuration-bottle-1')))
            .data,
        '1');
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('configuration-bottle-2')))
            .data,
        '2');
    await _tap(tester, 'configuration-bottle-1-minus');
    await _tap(tester, 'configuration-save');
    final edited = restored.activeDisplayGroups
        .singleWhere((group) => group.key == plainKey);
    expect(edited.bottleCounts, {2: 2});
    expect(
        edited.baseVariants.map(SmartCartSelection.variantRelationId).toSet(),
        {41});
    expect(
        restored.activeDisplayGroups
            .singleWhere((group) => group.key == berryKey)
            .bottleCounts,
        {2: 1});
    expect(restored.getTotalPrice(), 6360);
  });

  testWidgets(
      'cart stepper repeats exact pour mix and explicitly deletes final batch',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final item = _pourItem(amount: 7, withTaste: true);
      final plain = [_map(item.options![1].optionItems[0], required: 1)];
      final berry = [_map(item.options![1].optionItems[1], required: 1)];
      final cart = await _newCart(tester);
      cart
        ..syncItemBottleCounts(item, plain, {1: 1, 2: 1})
        ..syncItemBottleCounts(item, berry, {1: 1});
      await _mount(tester, cart, const CartPage());
      final plainKey = SmartCartSelection(item).displayKeyForVariants(plain);
      Finder control(String label) => find.descendant(
          of: find.byKey(const ValueKey('cart-row-0')),
          matching: find.bySemanticsLabel(label));
      await tester.ensureVisible(control('Добавить выбранный набор бутылок'));
      await tester.tap(control('Добавить выбранный набор бутылок'));
      await tester.pumpAndSettle();
      expect(
          cart.activeDisplayGroups
              .singleWhere((group) => group.key == plainKey)
              .bottleCounts,
          {1: 2, 2: 2});
      await tester.tap(control('Добавить выбранный набор бутылок'));
      await tester.pumpAndSettle();
      expect(
          cart.activeDisplayGroups
              .singleWhere((group) => group.key == plainKey)
              .bottleCounts,
          {1: 2, 2: 2});
      expect(
          cart.activeDisplayGroups
              .singleWhere((group) => group.key != plainKey)
              .bottleCounts,
          {1: 1});
      await tester.tap(control('Убрать выбранный набор бутылок'));
      await tester.pumpAndSettle();
      expect(
          cart.activeDisplayGroups
              .singleWhere((group) => group.key == plainKey)
              .bottleCounts,
          {1: 1, 2: 1});
      expect(control('Убрать выбранный набор бутылок'), findsNothing);
      await tester.tap(control('Удалить товар'));
      await tester.pumpAndSettle();
      expect(
          cart.activeDisplayGroups.single.baseVariants
              .map(SmartCartSelection.variantRelationId)
              .toSet(),
          {42});
      expect(cart.activeDisplayGroups.single.bottleCounts, {1: 1});
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('fractional replacement preview equals saved cart total',
      (tester) async {
    final capture = jsonDecode(
        File('test/fixtures/public_bottling_catalog.json')
            .readAsStringSync()) as Map;
    final raw = Map<String, dynamic>.from(
        (capture['category_samples'] as List).first['item'] as Map);
    raw.remove('img');
    raw['options'] = [
      {
        'option_id': 579,
        'name': 'Литраж',
        'required': 1,
        'selection': 'SINGLE',
        'variants': [
          {
            'relation_id': 2710,
            'item_id': 1091,
            'item_name': 'Бутылка 1.25 л',
            'parent_item_amount': 1.25,
            'price_type': 'REPLACE',
            'price': 500,
          }
        ],
      }
    ];
    final cart = await _newCart(tester);
    await _mount(tester, cart, ProductDetailPage(item: Item.fromJson(raw)));
    final preview = tester
        .widget<Text>(find.byKey(const ValueKey('configuration-total')))
        .data;
    expect(preview, formatTenge(500));
    await _tap(tester, 'configuration-bottle-2710-plus');
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('configuration-total')))
            .data,
        formatTenge(1000));
    await _tap(tester, 'configuration-save');
    expect(cart.getTotalPrice(), 1000);
    expect(cart.activeDisplayGroups.single.bottleCounts, {2710: 2});
    expect(cart.toJsonForOrder().single['amount'], 2.5);
  });
  testWidgets(
      'persisted withdrawn bottle and its gift can be removed through the editor at zero stock',
      (tester) async {
    final bottle = _option(93, 'Бутылка 3 л', 150, amount: 3);
    final promotion = ItemPromotion(
        promotionId: 93,
        name: '3+3',
        discountType: 'SUBTRACT',
        discountValue: 0,
        baseAmount: 3,
        addAmount: 3);
    final item = Item(
      itemId: 993,
      name: 'Разливной напиток',
      price: 1000,
      amount: 0,
      unit: 'л.',
      options: [
        ItemOption(
            optionId: 93,
            name: 'Тара',
            required: 1,
            selection: 'SINGLE',
            optionItems: [bottle]),
      ],
      promotions: [promotion],
    );
    final savedRow = CartItem(
      itemId: item.itemId,
      name: item.name,
      price: item.price,
      quantity: 3,
      stepQuantity: 3,
      maxAmount: 0,
      selectedVariants: [_map(bottle, required: 1)],
      promotions: [promotion.toJson()],
      giftBottleCounts: const {93: 1},
      itemData: item.toJson(),
    );
    SharedPreferences.setMockInitialValues({
      'cart_items': jsonEncode({
        'business_id': 1,
        'items': [savedRow.toJson()],
      }),
    });
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await cart.loadCart();
    final group = cart.activeDisplayGroups.single;
    expect(group.totalQuantity, 3);
    expect(group.freeQuantity, 3);
    expect(group.bottleCounts, {93: 2});
    expect(group.totalPrice, 3300);
    final before = cart.items.map((row) => row.toJson()).toList();
    final semantics = tester.ensureSemantics();
    try {
      await _mount(tester, cart, const CartPage());
      await tester.tap(find.bySemanticsLabel('Добавить выбранный набор бутылок'));
      await tester.pumpAndSettle();
      expect(cart.items.map((row) => row.toJson()).toList(), before);
      await _tap(tester, 'cart-edit-${group.key}');
      await _tap(tester, 'configuration-bottle-93-plus');
      await _tap(tester, 'configuration-back');
      expect(cart.items.map((row) => row.toJson()).toList(), before);
      await _tap(tester, 'cart-edit-${group.key}');
      await _tap(tester, 'configuration-bottle-93-minus');
      await _tap(tester, 'configuration-save');
      expect(cart.items, isEmpty);
      final reopened = CartProvider();
      addTearDown(reopened.dispose);
      await reopened.loadCart();
      expect(reopened.items, isEmpty);
      expect(reopened.businessId, 1);
    } finally {
      semantics.dispose();
    }
  });
}

Future<CartProvider> _newCart(WidgetTester tester) async {
  final cart = CartProvider();
  addTearDown(cart.dispose);
  expect(await cart.bindBusiness(1), isTrue);
  return cart;
}

Future<void> _mount(
    WidgetTester tester, CartProvider cart, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<CartProvider>.value(value: cart),
      ChangeNotifierProvider<BusinessProvider>(
          create: (_) => BusinessProvider()),
    ],
    child: MaterialApp(theme: AppTheme.dark(), home: child),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

ItemOptionItem _option(int id, String name, double price,
        {double amount = 0}) =>
    ItemOptionItem(
      relationId: id,
      itemId: 1000 + id,
      priceType: 'ADD',
      itemName: name,
      price: price,
      parentItemAmount: amount,
    );

Item _optionsItem({double amount = 10}) => Item(
      itemId: 502,
      name: 'Лимонад',
      description: 'Свежий лимонад с выбранными дополнениями.',
      price: 900,
      amount: amount,
      quantity: 1,
      unit: 'шт.',
      options: [
        ItemOption(
            optionId: 7,
            name: 'Сахар',
            required: 1,
            selection: 'SINGLE',
            optionItems: [
              _option(41, 'Без сахара', 0),
              _option(42, 'С сахаром', 0)
            ]),
        ItemOption(
            optionId: 8,
            name: 'Добавки',
            required: 1,
            selection: 'MULTIPLE',
            optionItems: [_option(51, 'Мята', 100), _option(52, 'Лайм', 150)]),
        ItemOption(
            optionId: 9,
            name: 'Упаковка',
            required: 0,
            selection: 'SINGLE',
            optionItems: [_option(61, 'Подарочная упаковка', 50)]),
      ],
    );

Item _pourItem(
        {double amount = 12,
        bool onlyTwoLitres = false,
        bool withTaste = false,
        List<ItemPromotion>? promotions}) =>
    Item(
      itemId: 1,
      name: 'Разливное пиво',
      description: 'Напиток с доступной тарой.',
      price: 1000,
      amount: amount,
      quantity: 1,
      unit: 'л.',
      category: ItemCategory(categoryId: 1, name: 'Разливное пиво'),
      options: [
        ItemOption(
            optionId: 1,
            name: 'Тара',
            required: 1,
            selection: 'SINGLE',
            optionItems: [
              if (!onlyTwoLitres) _option(1, 'Бутылка 1 л', 50, amount: 1),
              _option(2, 'Бутылка 2 л', 120, amount: 2),
            ]),
        if (withTaste)
          ItemOption(
              optionId: 7,
              name: 'Вкус',
              required: 1,
              selection: 'SINGLE',
              optionItems: [
                _option(41, 'Классический', 0),
                _option(42, 'Ягодный', 0)
              ]),
      ],
      promotions: promotions,
    );

Map<String, dynamic> _map(ItemOptionItem value, {required int required}) => {
      'variant_id': value.relationId,
      'relation_id': value.relationId,
      'item_id': value.itemId,
      'item_name': value.itemName,
      'price_type': value.priceType,
      'price': value.price,
      'parent_item_amount':
          value.parentItemAmount > 0 ? value.parentItemAmount : 1.0,
      'required': required,
    };
