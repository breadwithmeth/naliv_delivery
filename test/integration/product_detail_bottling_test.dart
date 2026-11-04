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
    await _mount(tester, cart, Builder(builder: (context) {
      return MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(padding: const EdgeInsets.only(top: 48, bottom: 34)),
        child: ProductDetailPage(item: capturedPourSurfaceItem()),
      );
    }));
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpAndSettle();
    final buy = find.byKey(const ValueKey('configuration-save'));
    final summary = find.byKey(const ValueKey('configuration-volume'));
    final firstBottle =
        find.byKey(const ValueKey('configuration-bottle-2710-plus'));
    expect(_text(tester, 'configuration-volume'), '1 л · 1 бутылка');
    expect(tester.getBottomRight(summary).dy,
        lessThanOrEqualTo(tester.getTopLeft(buy).dy));
    expect(tester.getBottomRight(firstBottle).dy,
        lessThanOrEqualTo(tester.getTopLeft(buy).dy));
    // One list of bottles: no composition paragraphs.
    expect(find.byKey(const ValueKey('configuration-price-breakdown')),
        findsNothing);
    expect(find.textContaining('Оплачено'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('3+1 selects 4 l and the fourth litre is an optional bonus',
      (tester) async {
    final item = syntheticThreePlusOneSurfaceItem(onlyOneLitre: true);
    final cart = await _newCart(tester);
    await _mount(tester, cart, ProductDetailPage(item: item));
    await _tap(tester, 'configuration-bottle-93101-plus');
    await _tap(tester, 'configuration-bottle-93101-plus');
    expect(_text(tester, 'configuration-volume'), '3 л · 3 бутылки');
    expect(_text(tester, 'configuration-total'), formatTenge(3300));
    expect(find.byKey(const ValueKey('configuration-gift')), findsNothing);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('configuration-bonus')),
            matching: find.text('+1 л в подарок')),
        findsOneWidget);
    await _tap(tester, 'configuration-bonus');
    expect(_text(tester, 'configuration-volume'), '4 л · 4 бутылки');
    expect(_text(tester, 'configuration-bottle-93101'), '4');
    expect(_text(tester, 'configuration-total'), formatTenge(3400));
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('configuration-gift')),
            matching: find.text('1 л в подарок')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('configuration-bonus')), findsNothing);
    expect(_text(tester, 'configuration-hint'), 'До следующего подарка: 4 л');
    await _tap(tester, 'configuration-save');
    expect(cart.getTotalPrice(), 3400);
    expect(cart.toJsonForOrder().single['amount'], 4);
    await _mount(tester, cart, const CartPage());
    await _tap(tester, 'cart-edit-${cart.activeDisplayGroups.single.key}');
    expect(_text(tester, 'configuration-bottle-93101'), '4');
    expect(_text(tester, 'configuration-total'), formatTenge(3400));
    await _tap(tester, 'configuration-save');
    await tester.tap(find.bySemanticsLabel('Добавить выбранный набор бутылок'));
    await tester.pumpAndSettle();
    final group = cart.activeDisplayGroups.single;
    expect(group.totalQuantity, 5);
    expect(group.freeQuantity, 1);
    expect(group.bottleCounts, {93101: 5});
    expect(group.totalPrice, 4500);
    expect(cart.toJsonForOrder().single['amount'], 5);
  });

  testWidgets('3+1 bonus can be declined: three litres stay a paid order',
      (tester) async {
    final item = syntheticThreePlusOneSurfaceItem(onlyOneLitre: true);
    final cart = await _newCart(tester);
    await _mount(tester, cart, ProductDetailPage(item: item));
    await _tap(tester, 'configuration-bottle-93101-plus');
    await _tap(tester, 'configuration-bottle-93101-plus');
    expect(find.byKey(const ValueKey('configuration-bonus')), findsOneWidget);
    await _tap(tester, 'configuration-save');
    final group = cart.activeDisplayGroups.single;
    expect(group.bottleCounts, {93101: 3});
    expect(group.freeQuantity, 0);
    expect(group.totalPrice, 3300);
    expect(cart.toJsonForOrder().single['amount'], 3);
  });

  testWidgets('mixed one and one-and-a-half litre bottles share the 3+1 gift',
      (tester) async {
    final item = syntheticThreePlusOneSurfaceItem();
    final cart = await _newCart(tester);
    await _mount(tester, cart, ProductDetailPage(item: item));
    // The first one-litre bottle is preset; two 1.5 l bottles make it 4 l.
    await _tap(tester, 'configuration-bottle-93103-plus');
    expect(_text(tester, 'configuration-volume'), '2.5 л · 2 бутылки');
    expect(find.byKey(const ValueKey('configuration-bonus')), findsNothing);
    expect(_text(tester, 'configuration-hint'), 'До подарка: 1.5 л');
    await _tap(tester, 'configuration-bottle-93103-plus');
    expect(_text(tester, 'configuration-volume'), '4 л · 3 бутылки');
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('configuration-gift')),
            matching: find.text('1 л в подарок')),
        findsOneWidget);
    expect(_text(tester, 'configuration-total'), formatTenge(3340));
    await _tap(tester, 'configuration-save');
    final group = cart.activeDisplayGroups.single;
    expect(group.bottleCounts, {93101: 1, 93103: 2});
    expect(group.freeQuantity, 1);
    expect(group.totalPrice, 3340);
    expect(cart.toJsonForOrder().map((row) => row['amount']), [1.0, 3.0]);
  });

  testWidgets('the bonus goes into the bottle size picked most',
      (tester) async {
    final item = Item(
      itemId: 1,
      name: 'Разливное пиво',
      price: 1000,
      amount: 12,
      quantity: 1,
      unit: 'л.',
      options: [
        ItemOption(
            optionId: 1,
            name: 'Тара',
            required: 1,
            selection: 'SINGLE',
            optionItems: [
              _option(11, 'Бутылка 1 л ПЭТ', 50, amount: 1),
              _option(12, 'Бутылка 1 л стекло', 80, amount: 1),
            ]),
      ],
      promotions: [_threePlusOne()],
    );
    final cart = await _newCart(tester);
    await _mount(tester, cart, ProductDetailPage(item: item));
    await _tap(tester, 'configuration-bottle-12-plus');
    await _tap(tester, 'configuration-bottle-12-plus');
    expect(_text(tester, 'configuration-bottle-11'), '1');
    expect(_text(tester, 'configuration-bottle-12'), '2');
    await _tap(tester, 'configuration-bonus');
    expect(_text(tester, 'configuration-bottle-11'), '1');
    expect(_text(tester, 'configuration-bottle-12'), '3');
  });

  testWidgets('without stock for the bonus litre only the short hint remains',
      (tester) async {
    final item = _pourItem(amount: 3, promotions: [_threePlusOne()]);
    final cart = await _newCart(tester);
    await _mount(tester, cart, ProductDetailPage(item: item));
    await _tap(tester, 'configuration-bottle-1-plus');
    await _tap(tester, 'configuration-bottle-1-plus');
    expect(_text(tester, 'configuration-volume'), '3 л · 3 бутылки');
    expect(find.byKey(const ValueKey('configuration-bonus')), findsNothing);
    expect(_text(tester, 'configuration-hint'), 'До подарка: 1 л');
    expect(
        tester
            .widget<IconButton>(
                find.byKey(const ValueKey('configuration-bottle-1-plus')))
            .onPressed,
        isNull);
    await _tap(tester, 'configuration-save');
    expect(cart.activeDisplayGroups.single.bottleCounts, {1: 3});
  });

  testWidgets('a gift that is not a whole bottle never blocks saving',
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
    // 2 l: one litre short of the gift and no one-litre bottle to offer.
    expect(find.byKey(const ValueKey('configuration-bonus')), findsNothing);
    expect(_text(tester, 'configuration-hint'), 'До подарка: 1 л');
    await _tap(tester, 'configuration-bottle-2-plus');
    expect(_text(tester, 'configuration-volume'), '4 л · 2 бутылки');
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('configuration-gift')),
            matching: find.text('1 л в подарок')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('configuration-feedback')), findsNothing);
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('configuration-save')))
            .onPressed,
        isNotNull);
    expect(_text(tester, 'configuration-total'), formatTenge(3240));
    await _tap(tester, 'configuration-save');
    expect(cart.getTotalPrice(), 3240); // 3 × 1000 + 2 × 120.
    expect(cart.toJsonForOrder().single['amount'], 4);
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
    // Saved by an earlier build: one paid three-litre bottle plus a retained gift bottle.
    final savedRow = {
      ...CartItem(
        itemId: item.itemId,
        name: item.name,
        price: item.price,
        quantity: 3,
        stepQuantity: 3,
        maxAmount: 0,
        selectedVariants: [_map(bottle, required: 1)],
        promotions: [promotion.toJson()],
        itemData: item.toJson(),
      ).toJson(),
      'giftBottleCounts': {'93': 1},
    };
    SharedPreferences.setMockInitialValues({
      'cart_items': jsonEncode({
        'business_id': 1,
        'items': [savedRow],
      }),
    });
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await cart.loadCart();
    final group = cart.activeDisplayGroups.single;
    expect(group.totalQuantity, 6);
    expect(group.freeQuantity, 3);
    expect(group.bottleCounts, {93: 2});
    expect(group.totalPrice, 3300);
    final before = cart.items.map((row) => row.toJson()).toList();
    final semantics = tester.ensureSemantics();
    try {
      await _mount(tester, cart, const CartPage());
      await tester
          .tap(find.bySemanticsLabel('Добавить выбранный набор бутылок'));
      await tester.pumpAndSettle();
      expect(cart.items.map((row) => row.toJson()).toList(), before);
      await _tap(tester, 'cart-edit-${group.key}');
      await _tap(tester, 'configuration-bottle-93-plus');
      await _tap(tester, 'configuration-back');
      expect(cart.items.map((row) => row.toJson()).toList(), before);
      await _tap(tester, 'cart-edit-${group.key}');
      await _tap(tester, 'configuration-bottle-93-minus');
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

  Item packagedThreePlusOne() => Item(
        itemId: 503,
        name: 'Лимонад',
        price: 900,
        amount: 10,
        quantity: 1,
        unit: 'шт.',
        options: [
          ItemOption(
              optionId: 9,
              name: 'Упаковка',
              required: 0,
              selection: 'SINGLE',
              optionItems: [_option(61, 'Подарочная упаковка', 50)]),
        ],
        promotions: [_threePlusOne()],
      );

  testWidgets(
      'packaged 3+1 states the rule and the distance to the gift as units are added',
      (tester) async {
    final cart = await _newCart(tester);
    await _mount(tester, cart, ProductDetailPage(item: packagedThreePlusOne()));
    expect(find.text('Возьмите 4 шт. — платите за 3 шт.'), findsOneWidget);
    for (final (state, total) in [
      ('До подарка: ещё 3 шт.', 900),
      ('До подарка: ещё 2 шт.', 1800),
      ('Добавьте ещё 1 шт. — это бесплатно', 2700),
      ('Подарок: 1 шт. · напиток 0 ₸', 2700),
      ('Подарок: 1 шт. · напиток 0 ₸', 3600),
    ]) {
      expect(_text(tester, 'configuration-promotion-state'), state);
      expect(_text(tester, 'configuration-total'), formatTenge(total));
      if (total != 3600) await _tap(tester, 'configuration-quantity-plus');
    }
  });

  testWidgets('packaged 3+1 saves exactly the units the customer picked',
      (tester) async {
    final cart = await _newCart(tester);
    await _mount(tester, cart, ProductDetailPage(item: packagedThreePlusOne()));
    await _tap(tester, 'configuration-quantity-plus');
    await _tap(tester, 'configuration-quantity-plus');
    await _tap(tester, 'configuration-save');
    var group = cart.activeDisplayGroups.single;
    expect(group.totalOrderQuantity, 3);
    expect(group.freeQuantity, 0);
    expect(cart.getTotalPrice(), 2700);
    expect(cart.toJsonForOrder().single['amount'], 3);

    expect(
        cart.syncItemSelectionQuantity(packagedThreePlusOne(), [], 4), isTrue);
    group = cart.activeDisplayGroups.single;
    expect(group.totalOrderQuantity, 4);
    expect(group.freeQuantity, 1);
    expect(cart.getTotalPrice(), 2700);
    expect(cart.toJsonForOrder().single['amount'], 4);
  });
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

ItemPromotion _threePlusOne() => ItemPromotion(
    promotionId: 3,
    name: '3+1',
    discountType: 'SUBTRACT',
    discountValue: 0,
    baseAmount: 3,
    addAmount: 1);

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
