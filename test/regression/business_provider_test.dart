import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:naliv_delivery/model/cart_item.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';

import '../support/preferences_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => SharedPreferences.setMockInitialValues({}));

  test(
      'rejected store change preserves persisted selection and published state',
      () async {
    final store = OnboardingPreferences({
      'selected_business': jsonEncode({'id': 1, 'name': 'Первый магазин'}),
    })
      ..install();
    final provider = BusinessProvider();
    await provider.loadSavedBusiness();
    final observedIds = <int?>[];
    provider.addListener(() => observedIds.add(provider.selectedBusinessId));
    store.rejectedKeys.add('selected_business');
    expect(
        await provider.setSelectedBusiness({'id': 2, 'name': 'Другой магазин'}),
        isFalse);
    expect(provider.selectedBusinessId, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString('selected_business')!)['id'], 1);
    expect(observedIds, isEmpty);
    provider.dispose();
  });

  test(
      'concurrent choices publish in persisted order and leave the last store selected',
      () async {
    final held = Completer<bool>();
    OnboardingPreferences()
      ..heldKey = 'selected_business'
      ..heldWrite = held
      ..install();
    final provider = BusinessProvider();
    final observedIds = <int?>[];
    provider.addListener(() => observedIds.add(provider.selectedBusinessId));
    final first = provider.setSelectedBusiness({'id': 1, 'name': 'Первый'});
    final second = provider.setSelectedBusiness({'id': 2, 'name': 'Второй'});
    await Future<void>.delayed(Duration.zero);
    expect(provider.selectedBusiness, isNull);
    held.complete(true);
    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(observedIds, [1, 2]);
    expect(provider.selectedBusinessId, 2);
    final prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString('selected_business')!)['id'], 2);
    provider.dispose();
  });

  test('same-store metadata refresh persists without replacing cart ownership',
      () async {
    OnboardingPreferences({
      'selected_business': jsonEncode({
        'id': 1,
        'name': 'Исходное название',
        'address': 'Исходный адрес',
      }),
      'cart_items': jsonEncode({
        'business_id': 1,
        'items': [
          CartItem(
            itemId: 51,
            name: 'Товар',
            price: 120,
            quantity: 2,
            stepQuantity: 1,
            selectedVariants: const [],
            promotions: const [],
          ).toJson(),
        ],
      }),
    }).install();
    final provider = BusinessProvider();
    final cart = CartProvider();
    addTearDown(provider.dispose);
    addTearDown(cart.dispose);
    await provider.loadSavedBusiness();
    await cart.ensureLoaded();
    final rows = jsonEncode(cart.toJsonForOrder());
    var contentNotifications = 0;
    cart.addListener(() => contentNotifications++);

    expect(
        await provider.setSelectedBusiness({
          'business_id': ' 01 ',
          'name': 'Актуальное название',
          'address': 'Актуальный адрес',
        }),
        isTrue);
    expect(cart.businessId, 1);
    expect(jsonEncode(cart.toJsonForOrder()), rows);
    expect(contentNotifications, 0);
    final restarted = BusinessProvider();
    addTearDown(restarted.dispose);
    await restarted.loadSavedBusiness();
    for (final selection in [provider, restarted]) {
      expect(selection.selectedBusinessId, 1);
      expect(selection.selectedBusinessName, 'Актуальное название');
      expect(selection.selectedBusiness!['address'], 'Актуальный адрес');
    }
  });

  test(
      'rejected same-store metadata refresh retains persisted and visible data',
      () async {
    final original = jsonEncode({'id': 1, 'name': 'Исходное название'});
    final store = OnboardingPreferences({'selected_business': original})
      ..install();
    final provider = BusinessProvider();
    addTearDown(provider.dispose);
    await provider.loadSavedBusiness();
    var notifications = 0;
    provider.addListener(() => notifications++);
    store.rejectedKeys.add('selected_business');

    final saved = await provider
        .setSelectedBusiness({'id': '01', 'name': 'Актуальное название'});
    expect(provider.selectedBusinessId, 1);
    expect(provider.selectedBusinessName, 'Исходное название');
    expect(notifications, 0);
    expect(
        (await SharedPreferences.getInstance()).getString('selected_business'),
        original);
    expect(saved, isFalse);
  });

  test('persisted cart store survives reload and rejected explicit discard',
      () async {
    final store = OnboardingPreferences()..install();
    final cart = CartProvider();
    expect(await cart.bindBusiness(1), isTrue);
    cart.addItem(CartItem(
      itemId: 91,
      name: 'Весовой товар',
      price: 1000,
      quantity: 0.75,
      stepQuantity: 0.25,
      selectedVariants: [
        {
          'variant_id': 920,
          'price': 25,
          'parent_item_amount': 1,
          'price_type': 'ADD',
        },
      ],
      promotions: [],
    ));
    await cart.loadCart();
    final originalRows = jsonEncode(cart.toJsonForOrder());
    final prefs = await SharedPreferences.getInstance();
    final persisted = prefs.getString('cart_items');
    store.rejectedKeys.add('cart_items');
    expect(await cart.discardForBusiness(2), isFalse);
    expect(cart.businessId, 1);
    expect(jsonEncode(cart.toJsonForOrder()), originalRows);
    expect(cart.getTotalPrice(), 768.75);
    await prefs.reload();
    expect(prefs.getString('cart_items'), persisted);
    final restored = CartProvider();
    await restored.ensureLoaded();
    expect(restored.businessId, 1);
    expect(jsonEncode(restored.toJsonForOrder()), originalRows);
    store.rejectedKeys.clear();
    expect(await cart.discardForBusiness(2), isTrue);
    expect(cart.hasActiveItems, isFalse);
    final changed = CartProvider();
    await changed.ensureLoaded();
    expect(changed.businessId, 2);
    expect(changed.hasActiveItems, isFalse);
    cart.dispose();
    restored.dispose();
    changed.dispose();
  });

  test(
      'unknown legacy cart remains readable removable and never binds a default',
      () async {
    final row = CartItem(
      itemId: 71,
      name: 'Старая позиция',
      price: 500,
      quantity: 2,
      stepQuantity: 1,
      selectedVariants: [],
      promotions: [],
    );
    final original = jsonEncode([row.toJson()]);
    SharedPreferences.setMockInitialValues({
      'cart_items': original,
      'selected_business': jsonEncode({'id': 2, 'name': 'Другой магазин'}),
    });
    final cart = CartProvider();
    await cart.ensureLoaded();
    expect(cart.businessId, isNull);
    expect(cart.hasUnresolvedBusiness, isTrue);
    expect(cart.getTotalPrice(), 1000);
    expect(await cart.bindBusiness(2), isFalse);
    expect((await SharedPreferences.getInstance()).getString('cart_items'),
        original);
    cart.updateQuantity(71, 1);
    expect(cart.getTotalQuantityForItem(71), 1);
    cart.removeItem(71);
    expect(cart.hasActiveItems, isFalse);
    expect(await cart.bindBusiness(2), isTrue);
    expect(cart.businessId, 2);
    cart.dispose();
  });

  test('invalid or rejected replacement cannot partially overwrite a cart',
      () async {
    final store = OnboardingPreferences()..install();
    final cart = CartProvider();
    await cart.bindBusiness(1);
    cart.addItem(CartItem(
      itemId: 1,
      name: 'Исходный товар',
      price: 120,
      quantity: 2,
      stepQuantity: 1,
      selectedVariants: [],
      promotions: [],
    ));
    await cart.loadCart();
    final original = jsonEncode(cart.toJsonForOrder());
    CartItem replacement(double quantity) => CartItem(
          itemId: 2,
          name: 'Другой товар',
          price: 100,
          quantity: quantity,
          stepQuantity: 1,
          selectedVariants: [],
          promotions: [],
        );
    expect(await cart.replaceForBusiness(2, [replacement(0.5)]), isFalse);
    expect(jsonEncode(cart.toJsonForOrder()), original);
    store.rejectedKeys.add('cart_items');
    expect(await cart.replaceForBusiness(2, [replacement(1)]), isFalse);
    expect(cart.businessId, 1);
    expect(jsonEncode(cart.toJsonForOrder()), original);
    expect(cart.getTotalPrice(), 240);
    cart.dispose();
  });
}
