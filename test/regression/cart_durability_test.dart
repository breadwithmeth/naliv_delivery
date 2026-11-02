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

  final item = Item(
    itemId: 8101,
    name: 'Тоник',
    price: 100,
    amount: 10,
    unit: 'шт',
    stepQuantity: 1,
  );
  CartItem row(double quantity) => CartItem(
        itemId: item.itemId,
        name: item.name,
        price: item.price,
        quantity: quantity,
        stepQuantity: 1,
        selectedVariants: const [],
        promotions: const [],
        itemData: item.toJson(),
        maxAmount: item.amount,
      );

  final edits =
      <String, ({void Function(CartProvider) apply, double quantity})>{
    'add': (apply: (cart) => expect(cart.addItem(row(1)), isTrue), quantity: 2),
    'quantity': (
      apply: (cart) => cart.updateQuantity(item.itemId, 3),
      quantity: 3
    ),
    'configuration': (
      apply: (cart) =>
          expect(cart.syncItemSelectionQuantity(item, [], 3), isTrue),
      quantity: 3,
    ),
    'remove': (apply: (cart) => cart.removeItem(item.itemId), quantity: 0),
    'clear': (apply: (cart) => cart.clearCart(), quantity: 0),
  };

  for (final entry in edits.entries) {
    test(
        'rejected ordinary ${entry.key} retains the accepted edit for recovery',
        () async {
      final original = jsonEncode({
        'business_id': 7,
        'items': [row(1).toJson()],
      });
      final store = OnboardingPreferences({'cart_items': original})..install();
      final cart = CartProvider();
      addTearDown(cart.dispose);
      await cart.ensureLoaded();
      store.rejectedKeys.add('cart_items');

      entry.value.apply(cart);
      expect(cart.getTotalQuantityForItem(item.itemId), entry.value.quantity);
      await cart.loadCart();
      expect(await cart.ensureSaved(), isFalse);
      expect(cart.saveStatus.value, CartSaveStatus.failed);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cart_items'), original);
      final restarted = CartProvider();
      addTearDown(restarted.dispose);
      await restarted.ensureLoaded();
      expect(restarted.getTotalQuantityForItem(item.itemId), 1);
      expect(
        cart.getTotalQuantityForItem(item.itemId),
        entry.value.quantity,
        reason: 'A failed background save must not silently roll back the '
            'accepted in-memory edit when restoration is requested.',
      );
    });
  }

  test('failed save and explicit retry never broadcast cart content changes',
      () async {
    final store = _ControlledCartPreferences()..install();
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await cart.ensureLoaded();
    final revision = cart.contentRevision;
    var contentChanges = 0;
    final statuses = <CartSaveStatus>[];
    cart.addListener(() => contentChanges++);
    cart.saveStatus.addListener(() => statuses.add(cart.saveStatus.value));

    expect(cart.addItem(row(1)), isTrue);
    expect(cart.contentRevision, revision + 1);
    expect(contentChanges, 1);
    expect(cart.saveStatus.value, CartSaveStatus.pending);
    await Future<void>.delayed(Duration.zero);
    store.releases.single.complete(false);
    expect(await cart.ensureSaved(), isFalse);
    expect(cart.saveStatus.value, CartSaveStatus.failed);
    expect(contentChanges, 1);
    expect(cart.contentRevision, revision + 1);
    expect(await cart.ensureSaved(), isFalse);
    expect(store.releases, hasLength(1),
        reason: 'A durability check must not silently retry a rejected write.');

    final retry = cart.retrySave();
    await Future<void>.delayed(Duration.zero);
    expect(cart.saveStatus.value, CartSaveStatus.pending);
    store.releases.last.complete(true);
    expect(await retry, isTrue);
    expect(cart.saveStatus.value, CartSaveStatus.saved);
    expect(contentChanges, 1);
    expect(cart.contentRevision, revision + 1);
    expect(statuses, [
      CartSaveStatus.pending,
      CartSaveStatus.failed,
      CartSaveStatus.pending,
      CartSaveStatus.saved,
    ]);
    final restarted = CartProvider();
    addTearDown(restarted.dispose);
    await restarted.ensureLoaded();
    expect(restarted.getTotalQuantityForItem(item.itemId), 1);
  });

  test(
      'ensureSaved follows a newer queued revision instead of an older success',
      () async {
    final store = _ControlledCartPreferences()..install();
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await cart.ensureLoaded();
    expect(cart.addItem(row(1)), isTrue);
    await Future<void>.delayed(Duration.zero);
    var settled = false;
    final saved = cart.ensureSaved().then((value) {
      settled = true;
      return value;
    });
    expect(cart.addItem(row(1)), isTrue);
    expect(store.releases, hasLength(1));
    store.releases.first.complete(true);
    await Future<void>.delayed(Duration.zero);
    expect(store.releases, hasLength(2));
    expect(settled, isFalse);
    expect(cart.saveStatus.value, CartSaveStatus.pending);
    store.releases.last.complete(false);
    expect(await saved, isFalse);
    expect(cart.saveStatus.value, CartSaveStatus.failed);
    expect(cart.getTotalQuantityForItem(item.itemId), 2);
    expect(store.quantities, [1.0, 2.0]);
    final restarted = CartProvider();
    addTearDown(restarted.dispose);
    await restarted.ensureLoaded();
    expect(restarted.getTotalQuantityForItem(item.itemId), 1);
  });

  test('a newer successful edit recovers a failed save without a blind retry',
      () async {
    final store = OnboardingPreferences()..install();
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await cart.ensureLoaded();
    store.rejectedKeys.add('cart_items');
    expect(cart.addItem(row(1)), isTrue);
    expect(await cart.ensureSaved(), isFalse);
    store.rejectedKeys.clear();
    expect(cart.addItem(row(1)), isTrue);
    expect(await cart.ensureSaved(), isTrue);
    expect(cart.saveStatus.value, CartSaveStatus.saved);
    final restarted = CartProvider();
    addTearDown(restarted.dispose);
    await restarted.ensureLoaded();
    expect(restarted.getTotalQuantityForItem(item.itemId), 2);
  });

  test('explicit replacement publishes only after its checked write completes',
      () async {
    final store = _ControlledCartPreferences()..install();
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await cart.ensureLoaded();
    final replacement = cart.replaceForBusiness(7, [row(2)]);
    await Future<void>.delayed(Duration.zero);
    expect(cart.items, isEmpty);
    expect(cart.businessId, isNull);
    store.releases.single.complete(false);
    expect(await replacement, isFalse);
    expect(cart.items, isEmpty);
    expect(await cart.ensureSaved(), isTrue);

    final accepted = cart.replaceForBusiness(7, [row(2)]);
    await Future<void>.delayed(Duration.zero);
    expect(cart.items, isEmpty);
    store.releases.last.complete(true);
    expect(await accepted, isTrue);
    expect(cart.businessId, 7);
    expect(cart.getTotalQuantityForItem(item.itemId), 2);
    expect(await cart.ensureSaved(), isTrue);
  });

  test('an older queued rejection cannot mark a newer successful edit failed',
      () async {
    final store = _ControlledCartPreferences()..install();
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await cart.ensureLoaded();
    final statuses = <CartSaveStatus>[];
    cart.saveStatus.addListener(() => statuses.add(cart.saveStatus.value));
    expect(cart.addItem(row(1)), isTrue);
    expect(cart.addItem(row(1)), isTrue);
    await Future<void>.delayed(Duration.zero);
    final saved = cart.ensureSaved();
    store.releases.first.complete(false);
    await Future<void>.delayed(Duration.zero);
    expect(cart.saveStatus.value, CartSaveStatus.pending);
    store.releases.last.complete(true);
    expect(await saved, isTrue);
    expect(statuses, [CartSaveStatus.pending, CartSaveStatus.saved]);
    final restarted = CartProvider();
    addTearDown(restarted.dispose);
    await restarted.ensureLoaded();
    expect(restarted.getTotalQuantityForItem(item.itemId), 2);
  });

  test('throwing ordinary storage becomes a retryable failed save', () async {
    final store = _ThrowingCartPreferences()..install();
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await cart.ensureLoaded();
    expect(cart.addItem(row(1)), isTrue);
    expect(await cart.ensureSaved(), isFalse);
    expect(cart.saveStatus.value, CartSaveStatus.failed);
    expect(cart.getTotalQuantityForItem(item.itemId), 1);
    store.throwWrites = false;
    expect(await cart.retrySave(), isTrue);
    expect(cart.saveStatus.value, CartSaveStatus.saved);
  });
}

class _ControlledCartPreferences extends OnboardingPreferences {
  final releases = <Completer<bool>>[];
  final quantities = <double>[];

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.cart_items') {
      final state = jsonDecode(value as String) as Map;
      final rows = state['items'] as List;
      quantities.add(rows.fold<double>(
          0, (sum, row) => sum + (row['quantity'] as num).toDouble()));
      final release = Completer<bool>();
      releases.add(release);
      if (!await release.future) return false;
    }
    return super.setValue(valueType, key, value);
  }
}

class _ThrowingCartPreferences extends OnboardingPreferences {
  bool throwWrites = true;

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (throwWrites && key == 'flutter.cart_items') {
      return Future<bool>.error(StateError('Fixture cart storage failure'));
    }
    return super.setValue(valueType, key, value);
  }
}
