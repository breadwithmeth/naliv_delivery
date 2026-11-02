import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/model/cart_item.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/preferences_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => SharedPreferences.setMockInitialValues({}));

  final invalidStates = <String, String>{
    'malformed JSON': '{not-json',
    'invalid rows container': jsonEncode({'business_id': 7, 'items': {}}),
    'invalid row': jsonEncode({
      'business_id': 7,
      'items': [
        {
          ..._row().toJson(),
          'quantity': 'not-a-quantity',
        },
      ],
    }),
  };

  for (final entry in invalidStates.entries) {
    test(
        '${entry.key} restore reports failure without an escaping future error',
        () async {
      OnboardingPreferences({'cart_items': entry.value}).install();
      final cart = CartProvider();
      addTearDown(cart.dispose);
      await expectLater(cart.loadCart(), completes);
      expect(cart.items, isEmpty);
      expect(cart.saveStatus.value, isNot(CartSaveStatus.saved));
      expect((await SharedPreferences.getInstance()).getString('cart_items'),
          entry.value);
    });

    test(
        '${entry.key} restore blocks synchronous edits without overwriting bytes',
        () async {
      OnboardingPreferences({'cart_items': entry.value}).install();
      final cart = CartProvider();
      addTearDown(cart.dispose);
      try {
        await cart.ensureLoaded();
      } catch (_) {
        // Exercise the existing consumer entrypoint even when old restoration
        // throws; an observed read error must not authorize a fresh overwrite.
      }
      final added = cart.addItem(_row());
      try {
        await cart.loadCart();
      } catch (_) {}
      expect(added, isFalse);
      expect(cart.items, isEmpty);
      expect((await SharedPreferences.getInstance()).getString('cart_items'),
          entry.value);
    });

    test('${entry.key} restore blocks void clear and configuration overwrite',
        () async {
      OnboardingPreferences({'cart_items': entry.value}).install();
      final cart = CartProvider();
      addTearDown(cart.dispose);
      try {
        await cart.ensureLoaded();
      } catch (_) {}
      cart.clearCart();
      final configured = cart.syncItemSelectionQuantity(
          Item(itemId: 8501, name: 'Товар', price: 100, amount: 10, unit: 'шт'),
          [],
          2);
      try {
        await cart.loadCart();
      } catch (_) {}
      expect(configured, isFalse);
      expect(cart.items, isEmpty);
      expect((await SharedPreferences.getInstance()).getString('cart_items'),
          entry.value);
    });
  }

  test('storage read failure reports an observable failure without escaping',
      () async {
    final original = jsonEncode({
      'business_id': 7,
      'items': [_row().toJson()]
    });
    final store = _UnreadableCartPreferences({'cart_items': original})
      ..install();
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await expectLater(cart.loadCart(), completes);
    expect(cart.saveStatus.value, isNot(CartSaveStatus.saved));
    expect(cart.items, isEmpty);
    store.failReads = false;
    expect((await store.getAll())['flutter.cart_items'], original);
  });

  test('storage read failure blocks accepted edits and preserves unread rows',
      () async {
    final original = jsonEncode({
      'business_id': 7,
      'items': [_row().toJson()]
    });
    final store = _UnreadableCartPreferences({'cart_items': original})
      ..install();
    final cart = CartProvider();
    addTearDown(cart.dispose);
    try {
      await cart.ensureLoaded();
    } catch (_) {}
    final accepted = cart.addItem(_row());
    try {
      await cart.loadCart();
    } catch (_) {}
    store.failReads = false;
    expect(accepted, isFalse);
    expect(cart.items, isEmpty);
    expect((await store.getAll())['flutter.cart_items'], original);
  });

  test(
      'restore failure is latched until explicit reload and never save-retried',
      () async {
    const corrupt = '{not-json';
    OnboardingPreferences({'cart_items': corrupt}).install();
    final cart = CartProvider();
    addTearDown(cart.dispose);
    final revision = cart.contentRevision;
    var contentChanges = 0;
    cart.addListener(() => contentChanges++);
    await cart.ensureLoaded();
    expect(cart.saveStatus.value, CartSaveStatus.restoreFailed);
    expect(await cart.ensureSaved(), isFalse);
    expect(await cart.retrySave(), isFalse);
    expect(await cart.bindBusiness(7), isFalse);
    expect(await cart.replaceForBusiness(7, [_row()]), isFalse);
    expect(await cart.retryLoad(), isFalse);
    expect(contentChanges, 0);
    expect(cart.contentRevision, revision);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('cart_items'), corrupt);

    // An external repair does not silently unlock commands or claim a default
    // owner for a valid legacy cart. Explicit reload adopts it without rewriting.
    final legacy = jsonEncode([_row().toJson()]);
    expect(await prefs.setString('cart_items', legacy), isTrue);
    await cart.ensureLoaded();
    expect(cart.saveStatus.value, CartSaveStatus.restoreFailed);
    expect(cart.addItem(_row()), isFalse);
    expect(await cart.retryLoad(), isTrue);
    expect(cart.saveStatus.value, CartSaveStatus.saved);
    expect(cart.items.single.itemId, 8501);
    expect(cart.businessId, isNull);
    expect(cart.hasUnresolvedBusiness, isTrue);
    expect(await cart.bindBusiness(7), isFalse);
    expect(prefs.getString('cart_items'), legacy);
    expect(contentChanges, 1);
  });

  test(
      'read failure retries only explicitly and restores the complete snapshot',
      () async {
    final original = jsonEncode({
      'business_id': 7,
      'items': [_row().toJson()]
    });
    final store = _UnreadableCartPreferences({'cart_items': original})
      ..install();
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await cart.ensureLoaded();
    final reads = store.reads;
    await cart.ensureLoaded();
    expect(await cart.ensureSaved(), isFalse);
    expect(await cart.retrySave(), isFalse);
    expect(store.reads, reads);
    store.failReads = false;
    expect(await cart.retryLoad(), isTrue);
    expect(cart.saveStatus.value, CartSaveStatus.saved);
    expect(cart.businessId, 7);
    expect(cart.items.single.itemId, 8501);
    expect(cart.items.single.quantity, 1);
    expect((await SharedPreferences.getInstance()).getString('cart_items'),
        original);
  });

  test('failed reload retains published rows and blocks every edit family',
      () async {
    OnboardingPreferences({
      'cart_items': jsonEncode({
        'business_id': 7,
        'items': [_row().toJson()]
      }),
    }).install();
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await cart.ensureLoaded();
    final group = cart.displayGroups.single;
    final revision = cart.contentRevision;
    var contentChanges = 0;
    cart.addListener(() => contentChanges++);
    final prefs = await SharedPreferences.getInstance();
    const corrupt = '{unread';
    expect(await prefs.setString('cart_items', corrupt), isTrue);
    expect(await cart.retryLoad(), isFalse);
    expect(cart.saveStatus.value, CartSaveStatus.restoreFailed);
    final item =
        Item(itemId: 8501, name: 'Товар', price: 100, amount: 10, unit: 'шт');
    expect(cart.addItem(_row()), isFalse);
    expect(cart.addDisplayGroupItems([_row()]), isFalse);
    expect(
        cart.addItemWithOptions(
            8501, 'Товар', '', 100, 1, [], [], null, null, null),
        isFalse);
    expect(cart.syncItemSelectionQuantity(item, [], 2), isFalse);
    expect(cart.syncItemBottleCounts(item, [], {}), isFalse);
    cart.updateQuantity(8501, 2);
    cart.updateQuantityWithVariants(8501, [], 2);
    cart.incrementCatalogItem(item);
    cart.decrementCatalogItem(item);
    cart.incrementDisplayGroup(group);
    cart.decrementDisplayGroup(group);
    cart.updateDisplayGroupBottleCounts(group, {});
    cart.removeDisplayGroup(group);
    cart.removeItem(8501);
    cart.clearCart();
    expect(cart.items.single.quantity, 1);
    expect(cart.businessId, 7);
    expect(cart.contentRevision, revision);
    expect(contentChanges, 0);
    expect(await cart.ensureSaved(), isFalse);
    expect(prefs.getString('cart_items'), corrupt);
  });

  test('only a checked explicit discard may replace unread persisted bytes',
      () async {
    const corrupt = '{unread';
    final store = OnboardingPreferences({'cart_items': corrupt})..install();
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await cart.ensureLoaded();
    store.rejectedKeys.add('cart_items');
    expect(await cart.discardForBusiness(7), isFalse);
    expect(cart.saveStatus.value, CartSaveStatus.restoreFailed);
    expect(cart.businessId, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('cart_items'), corrupt);

    store.rejectedKeys.clear();
    expect(await cart.discardForBusiness(7), isTrue);
    expect(cart.saveStatus.value, CartSaveStatus.saved);
    expect(await cart.ensureSaved(), isTrue);
    expect(cart.businessId, 7);
    expect(cart.items, isEmpty);
    expect(jsonDecode(prefs.getString('cart_items')!),
        {'business_id': 7, 'items': []});
    final restarted = CartProvider();
    addTearDown(restarted.dispose);
    await restarted.ensureLoaded();
    expect(restarted.businessId, 7);
    expect(restarted.items, isEmpty);
  });

  test('pending initial read cannot be overwritten by synchronous commands',
      () async {
    final original = jsonEncode({
      'business_id': 7,
      'items': [_row().toJson()]
    });
    final store = _HeldCartPreferences({'cart_items': original})..install();
    final cart = CartProvider();
    addTearDown(cart.dispose);
    final loading = cart.loadCart();
    expect(cart.addItem(_row()), isFalse);
    cart.clearCart();
    store.read.complete({'flutter.cart_items': original});
    await loading;
    expect(cart.businessId, 7);
    expect(cart.items.single.quantity, 1);
    expect(await cart.ensureSaved(), isTrue);
    expect((await SharedPreferences.getInstance()).getString('cart_items'),
        original);
  });
}

CartItem _row() => CartItem(
      itemId: 8501,
      name: 'Товар',
      price: 100,
      quantity: 1,
      stepQuantity: 1,
      selectedVariants: const [],
      promotions: const [],
    );

class _UnreadableCartPreferences extends OnboardingPreferences {
  _UnreadableCartPreferences(super.values);

  bool failReads = true;
  int reads = 0;

  @override
  Future<Map<String, Object>> getAll() {
    reads++;
    if (failReads) {
      return Future<Map<String, Object>>.error(
          StateError('Fixture cart read failure'));
    }
    return super.getAll();
  }
}

class _HeldCartPreferences extends OnboardingPreferences {
  _HeldCartPreferences(super.values);

  final read = Completer<Map<String, Object>>();

  @override
  Future<Map<String, Object>> getAll() => read.future;
}
