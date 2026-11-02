import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import 'package:naliv_delivery/model/cart_item.dart';
import 'package:naliv_delivery/model/item.dart' as item_model;

import 'smart_cart.dart';
import 'promotion_engine.dart';

enum CartSaveStatus { saved, pending, failed, restoreFailed }

/// Провайдер управления корзиной
class CartProvider extends ChangeNotifier {
  static const double _quantityEpsilon = 0.0000001;
  static const _storageKey = 'cart_items';
  int? _businessId;
  bool _loaded = false;
  bool _restoreFailed = false;
  bool _disposed = false;
  Future<void>? _loading;
  Future<void> _pendingPersistence = Future<void>.value();
  final ValueNotifier<CartSaveStatus> _saveStatus =
      ValueNotifier(CartSaveStatus.saved);
  int _savedRevision = 0;
  int _saveAttempt = 0;

  ValueListenable<CartSaveStatus> get saveStatus => _saveStatus;
  int get contentRevision => _revision;

  Future<bool> ensureSaved() async {
    await ensureLoaded();
    while (true) {
      final pending = _pendingPersistence;
      await pending;
      if (identical(pending, _pendingPersistence)) {
        return !_restoreFailed && _loaded && _savedRevision == _revision;
      }
    }
  }

  Future<bool> retrySave() async {
    await ensureLoaded();
    if (_restoreFailed) return false;
    if (_savedRevision != _revision) _saveCart();
    return ensureSaved();
  }

  void _setSaveStatus(CartSaveStatus status) {
    if (!_disposed) _saveStatus.value = status;
  }

  int? get businessId => _businessId;
  bool get hasUnresolvedBusiness => hasActiveItems && _businessId == null;

  Future<void> ensureLoaded() {
    if (_loading != null) return _loading!;
    if (_loaded || _restoreFailed) return Future<void>.value();
    return loadCart();
  }

  bool get _canMutate => !_restoreFailed && _loading == null && !_disposed;

  final List<CartItem> _items = [];
  final Map<String, int> _displayOrderByKey = <String, int>{};
  int _nextDisplayOrder = 0;

  int _revision = 0;
  int _displayGroupsRevision = -1;
  List<CartDisplayGroup> _displayGroups = const [];
  List<CartDisplayGroup> _activeDisplayGroups = const [];
  final Map<String, double> _catalogQuantities = {};

  /// Неподmodifiable список товаров в корзине
  UnmodifiableListView<CartItem> get items => UnmodifiableListView(_items);

  /// Получить товар по ID и (необязательно) вариантам
  CartItem? getItem(int itemId, [List<Map<String, dynamic>>? variants]) {
    final normalizedVariants = variants == null
        ? null
        : SmartCartSelection.normalizeVariantMaps(variants);
    if (variants != null) {
      return _items.firstWhereOrNull(
        (item) =>
            item.itemId == itemId &&
            const DeepCollectionEquality()
                .equals(item.selectedVariants, normalizedVariants),
      );
    }
    return _items.firstWhereOrNull((item) => item.itemId == itemId);
  }

  List<CartDisplayGroup> get displayGroups {
    _ensureDisplayGroups();
    return _displayGroups;
  }

  List<CartDisplayGroup> get activeDisplayGroups {
    _ensureDisplayGroups();
    return _activeDisplayGroups;
  }

  void _ensureDisplayGroups() {
    if (_displayGroupsRevision == _revision) return;
    _cacheDisplayGroups(CartDisplayGroup.groupItems(_items));
  }

  void _cacheDisplayGroups(List<CartDisplayGroup> groups) {
    final activeKeys = groups.map((group) => group.key).toSet();

    _displayOrderByKey.removeWhere((key, _) => !activeKeys.contains(key));

    for (final group in groups) {
      _displayOrderByKey.putIfAbsent(group.key, () => _nextDisplayOrder++);
    }

    groups.sort((left, right) {
      final leftOrder = _displayOrderByKey[left.key] ?? 0;
      final rightOrder = _displayOrderByKey[right.key] ?? 0;
      return leftOrder.compareTo(rightOrder);
    });

    // Membership/order are stable until the next provider mutation. Prices and
    // physical gift allocations remain live calculations on the current rows.
    _displayGroups = List<CartDisplayGroup>.unmodifiable(groups);
    _activeDisplayGroups = List<CartDisplayGroup>.unmodifiable(
        groups.where((group) => group.totalQuantity > _quantityEpsilon));
    _displayGroupsRevision = _revision;
    _catalogQuantities
      ..clear()
      ..addEntries(
          groups.map((group) => MapEntry(group.key, group.totalQuantity)));
  }

  bool get hasActiveItems => activeDisplayGroups.isNotEmpty;

  int get displayItemCount => activeDisplayGroups.length;

  /// Добавить товар. Возвращает false, если обязательные опции не выбраны
  bool addItem(CartItem newItem) {
    if (!_canMutate) return false;
    final normalizedItem = _normalizeItem(newItem);
    final snapshot = normalizedItem.snapshotItem;
    if (!normalizedItem.quantity.isFinite ||
        normalizedItem.quantity < 0 ||
        !normalizedItem.stepQuantity.isFinite ||
        normalizedItem.stepQuantity <= 0 ||
        (snapshot == null &&
            normalizedItem.selectedVariants
                .any(SmartCartSelection.isExplicitWithdrawnBottleVariant))) {
      return false;
    }
    if (snapshot != null) {
      final selection = SmartCartSelection(snapshot);
      if (selection.containerIssue != null ||
          selection.quantityIssue != null ||
          normalizedItem.selectedVariants
              .any(selection.isWithdrawnBottleVariant) ||
          normalizedItem.giftBottleCounts?.entries.any((entry) =>
                  entry.value > 0 &&
                  selection.isWithdrawnBottleRelation(entry.key)) ==
              true) {
        return false;
      }
      final ratio = normalizedItem.quantity / normalizedItem.stepQuantity;
      if ((ratio - ratio.round()).abs() > 0.0000001) return false;
      final key = CartDisplayGroup.displayKeyForCartItem(normalizedItem);
      final current =
          displayGroups.firstWhereOrNull((group) => group.key == key);
      if (!_fitsStock(selection, key,
          (current?.totalQuantity ?? 0) + normalizedItem.quantity)) {
        return false;
      }
    }
    final added = _addItemInternal(normalizedItem, refreshPromotions: true);
    if (!added) {
      return false;
    }
    _mergeExactDuplicates();
    _persistAndNotify();
    return true;
  }

  bool addDisplayGroupItems(Iterable<CartItem> items) {
    if (!_canMutate) return false;
    final rows = items.map(_normalizeItem).toList(growable: false);
    if (rows.isEmpty) return false;
    final groups = CartDisplayGroup.groupItems(rows);
    if (groups.length != 1) return false;
    final group = groups.single;
    final evaluated = group.evaluate();
    final selection = group.selection;
    if (rows.any((row) =>
        !row.quantity.isFinite ||
        row.quantity <= 0 ||
        !row.stepQuantity.isFinite ||
        row.stepQuantity <= 0 ||
        (row.quantity / row.stepQuantity -
                    (row.quantity / row.stepQuantity).round())
                .abs() >
            0.0000001 ||
        !_requiredVariantsSelected(row.selectedVariants))) {
      return false;
    }
    if (evaluated.allocationIssue != null ||
        group.hasWithdrawnBottles ||
        selection?.containerIssue != null ||
        selection?.quantityIssue != null) {
      return false;
    }
    final current =
        displayGroups.firstWhereOrNull((entry) => entry.key == group.key);
    if (selection != null &&
        !_fitsStock(selection, group.key,
            (current?.totalQuantity ?? 0) + evaluated.totalQuantity,
            retainedGiftCounts: group.retainedGiftBottleCounts)) {
      return false;
    }
    if (current != null && group.retainedGiftBottleCounts != null) return false;
    for (final row in rows) {
      _addItemInternal(row);
    }
    _mergeExactDuplicates();
    _persistAndNotify();
    return true;
  }

  bool canReplaceItems(List<CartItem> rows) {
    if (rows.isEmpty) return false;
    final normalized = rows.map(_normalizeItem).toList(growable: false);
    for (final row in normalized) {
      if (!row.quantity.isFinite ||
          row.quantity <= 0 ||
          !row.stepQuantity.isFinite ||
          row.stepQuantity <= 0 ||
          (row.quantity / row.stepQuantity -
                      (row.quantity / row.stepQuantity).round())
                  .abs() >
              0.0000001 ||
          !_requiredVariantsSelected(row.selectedVariants)) {
        return false;
      }
    }
    final reserved = <int, double>{};
    final stock = <int, double>{};
    final evaluation = CartEvaluation(CartDisplayGroup.groupItems(normalized));
    for (final evaluated in evaluation.groups) {
      final group = evaluated.group;
      final selection = group.selection;
      if (group.hasWithdrawnBottles ||
          evaluated.allocationIssue != null ||
          selection?.containerIssue != null ||
          selection?.quantityIssue != null) {
        return false;
      }
      reserved.update(
          group.itemId, (amount) => amount + evaluated.totalOrderQuantity,
          ifAbsent: () => evaluated.totalOrderQuantity);
      final limit = group.maxAmount;
      if (limit != null) {
        final previous = stock[group.itemId];
        if (previous == null || limit < previous) stock[group.itemId] = limit;
      }
    }
    for (final entry in reserved.entries) {
      final available = stock[entry.key];
      if (available != null && entry.value > available + 0.0000001) {
        return false;
      }
    }
    return true;
  }

  bool _requiredVariantsSelected(List<Map<String, dynamic>> variants) {
    for (final variant in variants) {
      if (variant['required'] != 1) continue;
      final relationId = SmartCartSelection.variantRelationId(variant);
      if (relationId == null || relationId == 0) return false;
    }
    return true;
  }

  bool _addItemInternal(CartItem newItem, {bool refreshPromotions = false}) {
    if (!_requiredVariantsSelected(newItem.selectedVariants)) return false;
    final variantKeys = newItem.selectedVariants
        .map(SmartCartSelection.variantStableKey)
        .toList(growable: false);
    final index = _items.indexWhere(
      (item) =>
          item.itemId == newItem.itemId &&
          const ListEquality<String>().equals(
              item.selectedVariants
                  .map(SmartCartSelection.variantStableKey)
                  .toList(growable: false),
              variantKeys),
    );
    if (index >= 0) {
      final existing = _items[index];
      if (refreshPromotions) {
        // A catalogue touch refreshes the complete authoritative row, not just
        // promotions. Historical repeat rows do not replace catalogue metadata.
        _items[index] = newItem.copyWith(
          quantity: existing.quantity + newItem.quantity,
          giftBottleCounts: existing.giftBottleCounts,
        );
      } else {
        existing.quantity += newItem.quantity;
      }
    } else {
      _items.add(newItem);
    }
    return true;
  }

  /// Удалить товар(ы) по ID и (необязательно) вариантам
  void removeItem(int itemId, [List<Map<String, dynamic>>? variants]) {
    if (!_canMutate) return;
    _removeItemInternal(itemId, variants);
    _persistAndNotify();
  }

  void _removeItemInternal(int itemId, [List<Map<String, dynamic>>? variants]) {
    final normalizedVariants = variants == null
        ? null
        : SmartCartSelection.normalizeVariantMaps(variants);
    if (variants != null) {
      _items.removeWhere(
        (item) =>
            item.itemId == itemId &&
            const DeepCollectionEquality()
                .equals(item.selectedVariants, normalizedVariants),
      );
    } else {
      _items.removeWhere((item) => item.itemId == itemId);
    }
  }

  /// Очистить всю корзину
  void clearCart() {
    if (!_canMutate) return;
    _items.clear();
    _displayOrderByKey.clear();
    _nextDisplayOrder = 0;
    _persistAndNotify();
  }

  /// Обновить количество товара, удалит при <=0
  void updateQuantity(int itemId, double newQuantity,
      [List<Map<String, dynamic>>? variants]) {
    if (!_canMutate) return;
    final existing = getItem(itemId, variants);
    if (existing == null || !newQuantity.isFinite || newQuantity < 0) return;
    final ratio = newQuantity / existing.stepQuantity;
    if ((ratio - ratio.round()).abs() > 0.0000001) return;
    final key = CartDisplayGroup.displayKeyForCartItem(existing);
    final group = displayGroups.firstWhereOrNull((group) => group.key == key);
    final increasing = newQuantity > existing.quantity + 0.0000001;
    if (increasing && group?.hasWithdrawnBottles == true) return;
    final snapshot = existing.snapshotItem;
    if (snapshot != null && increasing) {
      final selection = SmartCartSelection(snapshot);
      if (selection.containerIssue != null || selection.quantityIssue != null) {
        return;
      }
      final paid =
          (group?.totalQuantity ?? 0) - existing.quantity + newQuantity;
      if (!_fitsStock(selection, key, paid)) return;
    } else if (increasing &&
        existing.maxAmount != null &&
        newQuantity > existing.maxAmount! + 0.0000001) {
      return;
    }
    final updated = _updateQuantityInternal(itemId, newQuantity, variants);
    if (!updated) return;
    _mergeExactDuplicates();
    _persistAndNotify();
  }

  bool _updateQuantityInternal(int itemId, double newQuantity,
      [List<Map<String, dynamic>>? variants]) {
    final item = getItem(itemId, variants);
    if (item == null) return false;
    item.updateQuantity(newQuantity);
    return true;
  }

  CartEvaluation evaluate({DateTime? now}) =>
      CartEvaluation(displayGroups, now: now);

  double getTotalPrice() => evaluate().totalPrice;

  List<Map<String, dynamic>> toJsonForOrder() => evaluate().toJsonForOrder();

  String _serializedState({int? businessId, bool empty = false}) => jsonEncode({
        'business_id': empty ? businessId : (businessId ?? _businessId),
        'items': empty
            ? const <Object>[]
            : _items.map((item) => item.toJson()).toList(growable: false),
      });

  Future<bool> _writeState(String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (await prefs.setString(_storageKey, value)) return true;
      await prefs.reload();
    } catch (error) {
      try {
        await (await SharedPreferences.getInstance()).reload();
      } catch (_) {
        // A rejected write must not be treated as a committed cart.
      }
      debugPrint('Не удалось сохранить корзину: $error');
    }
    return false;
  }

  Future<T> _enqueuePersistence<T>(Future<T> Function() operation) {
    final result = _pendingPersistence.then((_) => operation());
    _pendingPersistence =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<bool> _saveCart() {
    _loaded = true;
    final revision = _revision;
    final attempt = ++_saveAttempt;
    final state = _serializedState();
    _setSaveStatus(CartSaveStatus.pending);
    return _enqueuePersistence(() async {
      final saved = await _writeState(state);
      if (saved) _savedRevision = revision;
      if (attempt == _saveAttempt && revision == _revision) {
        _setSaveStatus(_savedRevision == _revision
            ? CartSaveStatus.saved
            : CartSaveStatus.failed);
      }
      return saved;
    });
  }

  Future<void> loadCart() =>
      _loading ??= _readCart().whenComplete(() => _loading = null);

  Future<bool> retryLoad() async {
    // Unsaved accepted edits need save recovery, never a destructive re-read.
    if (_loaded && _savedRevision != _revision) return false;
    await (_loading ??=
        _readCart(reload: true).whenComplete(() => _loading = null));
    return !_restoreFailed && _loaded;
  }

  Future<void> _readCart({bool reload = false}) async {
    await _pendingPersistence;
    if (_loaded && _savedRevision != _revision) return;
    final revision = _revision;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (reload) await prefs.reload();
      final jsonString = prefs.getString(_storageKey);
      if (_revision != revision || _disposed) return;
      final rows = <CartItem>[];
      int? storedBusinessId;
      if (jsonString != null) {
        final decoded = jsonDecode(jsonString);
        final rawRows = decoded is Map ? decoded['items'] : decoded;
        if (rawRows is! List) {
          throw const FormatException('Неверный формат сохранённой корзины');
        }
        for (final raw in rawRows) {
          rows.add(_normalizeItem(
              CartItem.fromJson(Map<String, dynamic>.from(raw as Map))));
        }
        if (decoded is Map) {
          storedBusinessId = _storeId(decoded['business_id']);
        } else if (rows.isNotEmpty) {
          // Unknown-store legacy rows remain readable, never default-bound.
          final ids = rows.map((row) => row.snapshotItem?.businessId).toSet();
          if (ids.length == 1) storedBusinessId = _storeId(ids.single);
        }
      }
      final changed = jsonString != null ||
          _items.isNotEmpty ||
          _businessId != null ||
          _restoreFailed;
      _businessId = storedBusinessId;
      _displayOrderByKey.clear();
      _nextDisplayOrder = 0;
      _items
        ..clear()
        ..addAll(rows);
      if (changed) _revision++;
      _mergeExactDuplicates();
      _savedRevision = _revision;
      _loaded = true;
      _restoreFailed = false;
      _setSaveStatus(CartSaveStatus.saved);
      if (changed && !_disposed) notifyListeners();
    } catch (error) {
      // Keep both the last published rows and unread persisted bytes intact.
      // No ordinary edit or save retry may overwrite them until explicit recovery.
      _restoreFailed = true;
      _setSaveStatus(CartSaveStatus.restoreFailed);
      debugPrint('Не удалось восстановить корзину: $error');
    }
  }

  Future<bool> bindBusiness(int businessId) async {
    if (businessId <= 0) return false;
    await ensureLoaded();
    if (!_canMutate) return false;
    return _enqueuePersistence(() async {
      if (_businessId == businessId) return true;
      if (hasActiveItems) return false;
      final revision = _revision;
      if (!await _writeState(_serializedState(businessId: businessId))) {
        return false;
      }
      if (_revision != revision) {
        await _writeState(_serializedState());
        return false;
      }
      _businessId = businessId;
      _revision++;
      _savedRevision = _revision;
      _setSaveStatus(CartSaveStatus.saved);
      if (!_disposed) notifyListeners();
      return true;
    });
  }

  Future<bool> discardForBusiness(int? businessId) async {
    if (businessId != null && businessId <= 0) return false;
    await ensureLoaded();
    return _enqueuePersistence(() async {
      if (businessId == null && !_restoreFailed) return false;
      final revision = _revision;
      if (!await _writeState(
          _serializedState(businessId: businessId, empty: true))) {
        return false;
      }
      if (_revision != revision) {
        await _writeState(_serializedState());
        return false;
      }
      _businessId = businessId;
      _items.clear();
      _displayOrderByKey.clear();
      _nextDisplayOrder = 0;
      _revision++;
      _loaded = true;
      _restoreFailed = false;
      _savedRevision = _revision;
      _setSaveStatus(CartSaveStatus.saved);
      if (!_disposed) notifyListeners();
      return true;
    });
  }

  Future<bool> replaceForBusiness(
      int businessId, Iterable<CartItem> replacement) async {
    if (businessId <= 0) return false;
    await ensureLoaded();
    if (!_canMutate) return false;
    final rows = replacement.map(_normalizeItem).toList(growable: false);
    if (!canReplaceItems(rows)) return false;
    return _enqueuePersistence(() async {
      final revision = _revision;
      final state = jsonEncode({
        'business_id': businessId,
        'items': rows.map((row) => row.toJson()).toList(growable: false),
      });
      if (!await _writeState(state)) return false;
      if (_revision != revision) {
        await _writeState(_serializedState());
        return false;
      }
      _businessId = businessId;
      _items
        ..clear()
        ..addAll(rows);
      _displayOrderByKey.clear();
      _nextDisplayOrder = 0;
      _revision++;
      _mergeExactDuplicates();
      _savedRevision = _revision;
      _setSaveStatus(CartSaveStatus.saved);
      if (!_disposed) notifyListeners();
      return true;
    });
  }

  static int? _storeId(Object? value) {
    final id = int.tryParse(value?.toString().trim() ?? '');
    return id != null && id > 0 ? id : null;
  }

  /// Получить все варианты товара в корзине по ID
  List<CartItem> getItemVariants(int itemId) {
    return _items.where((item) => item.itemId == itemId).toList();
  }

  /// Общее количество товара в корзине по ID (учитывает все варианты)
  double getTotalQuantityForItem(int itemId) {
    return _items.fold(
        0.0, (sum, item) => item.itemId == itemId ? sum + item.quantity : sum);
  }

  /// Обновление количества с учетом выбранных вариантов
  void updateQuantityWithVariants(
      int itemId, List<Map<String, dynamic>> variants, double newQuantity) {
    updateQuantity(itemId, newQuantity, variants);
  }

  double getCatalogQuantity(item_model.Item item) =>
      getCatalogQuantityForKey(SmartCartSelection(item).defaultDisplayKey);

  double getCatalogQuantityForKey(String key) {
    _ensureDisplayGroups();
    return _catalogQuantities[key] ?? 0;
  }

  void incrementCatalogItem(item_model.Item item) {
    _adjustItemGroupQuantity(item, direction: 1);
  }

  void decrementCatalogItem(item_model.Item item) {
    _adjustItemGroupQuantity(item, direction: -1);
  }

  void incrementDisplayGroup(CartDisplayGroup group) {
    _adjustExistingGroup(group, direction: 1);
  }

  void decrementDisplayGroup(CartDisplayGroup group) {
    _adjustExistingGroup(group, direction: -1);
  }

  void removeDisplayGroup(CartDisplayGroup group) {
    if (!_canMutate) return;
    final matching = _items
        .where(
            (item) => CartDisplayGroup.displayKeyForCartItem(item) == group.key)
        .toList(growable: false);
    if (matching.isEmpty) {
      return;
    }

    for (final item in matching) {
      _removeItemInternal(item.itemId, item.selectedVariants);
    }
    _mergeExactDuplicates();
    _persistAndNotify();
  }

  void updateDisplayGroupBottleCounts(
      CartDisplayGroup group, Map<int, int> bottleCounts) {
    if (!_canMutate) return;
    final snapshot = group.itemSnapshot;
    if (snapshot == null) {
      return;
    }

    final selection = SmartCartSelection(snapshot);
    if (!selection.usesPourFlow) {
      return;
    }

    _syncPourFlowBottleCounts(selection, group.baseVariants, bottleCounts);
  }

  bool syncItemSelectionQuantity(
    item_model.Item item,
    List<Map<String, dynamic>> baseVariants,
    double targetQuantity, {
    List<Map<String, dynamic>>? previousBaseVariants,
  }) =>
      _canMutate &&
      _syncSelectionGroup(
          SmartCartSelection(item), baseVariants, targetQuantity,
          previousBaseVariants: previousBaseVariants);

  bool syncItemBottleCounts(
    item_model.Item item,
    List<Map<String, dynamic>> baseVariants,
    Map<int, int> bottleCounts, {
    List<Map<String, dynamic>>? previousBaseVariants,
  }) {
    if (!_canMutate) return false;
    final selection = SmartCartSelection(item);
    if (!selection.usesPourFlow) return false;
    return _syncPourFlowBottleCounts(selection, baseVariants, bottleCounts,
        previousBaseVariants: previousBaseVariants);
  }

  void _adjustItemGroupQuantity(
    item_model.Item item, {
    required int direction,
  }) {
    if (!_canMutate) return;
    final selection = SmartCartSelection(item);
    final key = selection.defaultDisplayKey;
    final currentGroup =
        displayGroups.firstWhereOrNull((entry) => entry.key == key);
    if (selection.usesPourFlow &&
        currentGroup != null &&
        currentGroup.totalQuantity > _quantityEpsilon) {
      _adjustExistingGroup(currentGroup, direction: direction);
      return;
    }
    final currentQuantity = currentGroup?.totalQuantity ?? 0.0;
    final step = selection.usesPourFlow
        ? selection.minBottleVolume
        : selection.defaultStepQuantity;
    final nextQuantity = currentQuantity + step * direction;

    if (direction < 0 && currentQuantity <= 0) {
      return;
    }

    _syncSelectionGroup(
        selection, selection.defaultNonBottleVariants, nextQuantity);
  }

  void _adjustExistingGroup(
    CartDisplayGroup group, {
    required int direction,
  }) {
    if (!_canMutate) return;
    final evaluated = group.evaluate();
    if (direction > 0 && !evaluated.canIncrease) return;
    final snapshot = group.itemSnapshot;
    if (snapshot == null) {
      _adjustLegacyExistingGroup(group, direction: direction);
      return;
    }

    final selection = group.selection!;
    if (selection.usesPourFlow) {
      final counts = evaluated.paidBottleCounts;
      var batches = 0;
      for (final count in counts.values) {
        if (count > 0) batches = batches == 0 ? count : batches.gcd(count);
      }
      if (batches == 0) return;
      _syncPourFlowBottleCounts(selection, group.baseVariants, {
        for (final entry in counts.entries)
          entry.key: entry.value ~/ batches * (batches + direction),
      });
      return;
    }
    final step = selection.defaultStepQuantity;
    final nextQuantity = group.totalQuantity + step * direction;

    if (direction < 0 && group.totalQuantity <= 0) {
      return;
    }

    _syncSelectionGroup(selection, group.baseVariants, nextQuantity);
  }

  // Restored legacy carts may miss itemData snapshots, so mutate the raw rows directly.
  void _adjustLegacyExistingGroup(
    CartDisplayGroup group, {
    required int direction,
  }) {
    final matching = _items
        .where(
            (item) => CartDisplayGroup.displayKeyForCartItem(item) == group.key)
        .toList(growable: false);
    if (matching.isEmpty) {
      return;
    }

    final hasBottleLikeVariants = matching.any((item) =>
        item.selectedVariants.any(SmartCartSelection.looksBottleLikeVariant));
    final target = _selectLegacyAdjustmentItem(matching,
        preferSmallestStep: hasBottleLikeVariants);
    if (target == null) {
      return;
    }

    final step = _legacyItemStep(target);
    if (step <= 0) {
      return;
    }

    if (direction < 0) {
      final nextQuantity = target.quantity - step;
      if (nextQuantity <= 0.001) {
        _removeItemInternal(target.itemId, target.selectedVariants);
      } else {
        _updateQuantityInternal(
            target.itemId, nextQuantity, target.selectedVariants);
      }
      _mergeExactDuplicates();
      _persistAndNotify();
      return;
    }

    final maxAmount = group.maxAmount;
    final totalQuantity =
        matching.fold<double>(0.0, (sum, item) => sum + item.quantity);
    if (maxAmount != null && totalQuantity + step > maxAmount + 0.001) {
      return;
    }

    _updateQuantityInternal(
        target.itemId, target.quantity + step, target.selectedVariants);
    _mergeExactDuplicates();
    _persistAndNotify();
  }

  CartItem? _selectLegacyAdjustmentItem(
    List<CartItem> items, {
    required bool preferSmallestStep,
  }) {
    if (items.isEmpty) {
      return null;
    }

    if (!preferSmallestStep) {
      return items.first;
    }

    final sorted = items.toList(growable: false)
      ..sort((left, right) {
        final stepCompare =
            _legacyItemStep(left).compareTo(_legacyItemStep(right));
        if (stepCompare != 0) {
          return stepCompare;
        }
        return left.quantity.compareTo(right.quantity);
      });

    return sorted.firstWhereOrNull((item) => item.quantity > 0) ?? sorted.first;
  }

  double _legacyItemStep(CartItem item) =>
      item.stepQuantity > 0 ? item.stepQuantity : 1.0;

  double _orderQuantity(SmartCartSelection selection, double paid,
          {DateTime? now}) =>
      paid +
      subtractPromotionFreeQuantity(
          paid,
          [
            for (final promotion in selection.item.promotions ??
                const <item_model.ItemPromotion>[])
              promotion.toJson(),
          ],
          now: now);

  bool _fitsStock(SmartCartSelection selection, String key, double paid,
      {String? previousKey, Map<int, int>? retainedGiftCounts}) {
    final evaluation = evaluate();
    final opened = evaluation.groups
        .firstWhereOrNull((entry) => entry.group.key == (previousKey ?? key));
    final orderQuantity = _orderQuantity(selection, paid, now: evaluation.now);
    // Availability constrains fresh demand, never the customer's ability to
    // reduce or remove quantities that were actually restored from persistence.
    if (opened != null &&
        paid <= opened.totalQuantity + 0.0000001 &&
        orderQuantity <= opened.totalOrderQuantity + 0.0000001) {
      return true;
    }
    if (selection.usesPourFlow) {
      try {
        selection.giftBottleBreakdown(paid,
            retainedCounts: retainedGiftCounts, now: evaluation.now);
      } on StateError {
        return false;
      }
    }
    final reserved = evaluation.activeGroups
        .where((entry) =>
            entry.group.itemId == selection.item.itemId &&
            entry.group.key != key &&
            entry.group.key != previousKey)
        .fold<double>(0, (sum, entry) => sum + entry.totalOrderQuantity);
    return reserved + orderQuantity <= selection.maxAmount + 0.0000001;
  }

  void _removePreviousConfiguration(String key, String? previousKey) {
    if (previousKey == null || previousKey == key) return;
    _items.removeWhere(
        (item) => CartDisplayGroup.displayKeyForCartItem(item) == previousKey);
  }

  bool _syncSelectionGroup(
    SmartCartSelection selection,
    List<Map<String, dynamic>> baseVariants,
    double targetQuantity, {
    List<Map<String, dynamic>>? previousBaseVariants,
  }) {
    final variants = SmartCartSelection.normalizeVariantMaps(baseVariants);
    if (!_requiredVariantsSelected(variants)) return false;
    final key = selection.displayKeyForVariants(variants);
    final previousKey = previousBaseVariants == null
        ? null
        : selection.displayKeyForVariants(previousBaseVariants);
    final opened = displayGroups
        .firstWhereOrNull((group) => group.key == (previousKey ?? key));
    final reduction = opened != null &&
        targetQuantity >= 0 &&
        targetQuantity <= opened.totalQuantity + 0.0000001;
    if (!reduction &&
        (selection.containerIssue != null || selection.quantityIssue != null)) {
      return false;
    }
    if (variants.any(selection.isWithdrawnBottleVariant)) return false;
    if (previousKey != null &&
        previousKey != key &&
        displayGroups.any((group) => group.key == key)) {
      return false;
    }
    if (!targetQuantity.isFinite ||
        targetQuantity < 0 ||
        !_fitsStock(selection, key, targetQuantity, previousKey: previousKey)) {
      return false;
    }
    if (selection.usesPourFlow) {
      if (reduction && opened.totalQuantity > 0) {
        final counts = SmartCartSelection.scaledBottleCounts(
            opened.paidBottleCounts, targetQuantity / opened.totalQuantity);
        if (counts != null) {
          return _syncPourFlowBottleCounts(selection, variants, counts,
              previousBaseVariants: previousBaseVariants);
        }
      }
      try {
        return _syncPourFlowBottleCounts(
            selection, variants, selection.autoBottleBreakdown(targetQuantity),
            previousBaseVariants: previousBaseVariants);
      } on StateError {
        return false;
      }
    }
    final step = reduction && selection.quantityIssue != null
        ? opened.items.first.stepQuantity
        : selection.defaultStepQuantity;
    if ((targetQuantity / step - (targetQuantity / step).round()).abs() >
        0.0000001) {
      return false;
    }
    final rows = <CartItem>[
      if (targetQuantity > 0)
        CartItem(
          itemId: selection.item.itemId,
          name: selection.item.name,
          price: selection.item.price,
          quantity: targetQuantity,
          stepQuantity: step,
          image: selection.item.image,
          selectedVariants: variants,
          promotions: [
            for (final promotion in selection.item.promotions ??
                const <item_model.ItemPromotion>[])
              if (promotion.isActive) promotion.toJson(),
          ],
          itemData: selection.item.toJson(),
          maxAmount: selection.item.amount,
        ),
    ];
    return _commitSelectionRows(rows, key, previousKey);
  }

  bool _syncPourFlowBottleCounts(
    SmartCartSelection selection,
    List<Map<String, dynamic>> baseVariants,
    Map<int, int> bottleCounts, {
    List<Map<String, dynamic>>? previousBaseVariants,
  }) {
    if (bottleCounts.entries.any((entry) =>
        entry.value < 0 ||
        !selection.knownBottleRelationIds.contains(entry.key))) {
      return false;
    }
    final variants = SmartCartSelection.normalizeVariantMaps(baseVariants);
    if (!_requiredVariantsSelected(variants)) return false;
    final key = selection.displayKeyForVariants(variants);
    final previousKey = previousBaseVariants == null
        ? null
        : selection.displayKeyForVariants(previousBaseVariants);
    if (previousKey != null &&
        previousKey != key &&
        displayGroups.any((group) => group.key == key)) {
      return false;
    }
    final opened = displayGroups
        .firstWhereOrNull((group) => group.key == (previousKey ?? key));
    final existingCounts = opened?.paidBottleCounts ?? const <int, int>{};
    for (final entry in bottleCounts.entries) {
      if (selection.isWithdrawnBottleRelation(entry.key) &&
          entry.value > (existingCounts[entry.key] ?? 0)) {
        return false;
      }
    }
    final totalLiters = selection.litersForCounts(bottleCounts);
    if (opened == null && selection.containerIssue != null) return false;
    Map<int, int>? retainedGifts;
    final evaluatedOpened = opened?.evaluate();
    if (opened != null &&
        evaluatedOpened!.freeQuantity > 0 &&
        evaluatedOpened.allocationIssue == null) {
      final nextGift =
          _orderQuantity(selection, totalLiters, now: evaluatedOpened.now) -
              totalLiters;
      retainedGifts = SmartCartSelection.scaledBottleCounts(
          evaluatedOpened.giftBottleCounts,
          nextGift / evaluatedOpened.freeQuantity);
      if (retainedGifts != null) {
        try {
          selection.giftBottleBreakdown(totalLiters,
              retainedCounts: retainedGifts);
        } on StateError {
          retainedGifts = null;
        }
      }
    }
    if (retainedGifts?.entries.any((entry) =>
            selection.isWithdrawnBottleRelation(entry.key) &&
            entry.value >
                (opened?.retainedGiftBottleCounts?[entry.key] ?? 0)) ==
        true) {
      return false;
    }
    if (!_fitsStock(selection, key, totalLiters,
        previousKey: previousKey, retainedGiftCounts: retainedGifts)) {
      return false;
    }
    var persistedSelection = selection;
    final oldSelection = opened?.selection;
    if (opened?.hasWithdrawnBottles == true && oldSelection != null) {
      // A withdrawn row cannot be bought again. Its surviving containers keep
      // the historical tariff while catalogue-sourced promotions remain live.
      final oldBottles = oldSelection.bottleVariants.where((bottle) =>
          oldSelection.isWithdrawnBottleRelation(bottle.relationId));
      persistedSelection = SmartCartSelection(selection.item.copyWith(
        price: opened!.price,
        options: [
          for (final option
              in selection.item.options ?? const <item_model.ItemOption>[])
            item_model.ItemOption(
              optionId: option.optionId,
              name: option.name,
              required: option.required,
              selection: option.selection,
              optionItems: [
                for (final variant in option.optionItems)
                  oldBottles.firstWhereOrNull(
                          (old) => old.relationId == variant.relationId) ??
                      variant,
              ],
            ),
        ],
      ));
    }
    final snapshot = persistedSelection.item.toJson();
    final promotions = [
      for (final promotion
          in selection.item.promotions ?? const <item_model.ItemPromotion>[])
        if (promotion.isActive) promotion.toJson(),
    ];
    final rows = <CartItem>[
      // Every container the store recognises, not only the ones this client still offers: a cart
      // that already holds a withdrawn three-litre bottle keeps its litres until the customer
      // removes it.
      for (final bottle in persistedSelection.bottleVariants)
        if ((bottleCounts[bottle.relationId] ?? 0) > 0)
          CartItem(
            itemId: persistedSelection.item.itemId,
            name: persistedSelection.item.name,
            price: persistedSelection.item.price,
            quantity: persistedSelection.volumeForBottle(bottle) *
                bottleCounts[bottle.relationId]!,
            stepQuantity: persistedSelection.volumeForBottle(bottle),
            giftBottleCounts: retainedGifts,
            image: selection.item.image,
            selectedVariants: persistedSelection.buildVariantMaps(
                bottle: bottle, baseVariants: variants),
            promotions: promotions,
            itemData: snapshot,
            maxAmount: selection.item.amount,
          ),
    ];
    return _commitSelectionRows(rows, key, previousKey);
  }

  bool _commitSelectionRows(
      List<CartItem> rows, String key, String? previousKey) {
    // Validate the complete replacement before touching the opened configuration.
    if (rows.any((row) => !_requiredVariantsSelected(row.selectedVariants))) {
      return false;
    }
    if (rows.isNotEmpty &&
        CartDisplayGroup.groupItems(rows)
            .any((group) => group.allocationIssue != null)) {
      return false;
    }
    if (rows.isEmpty) {
      _removePreviousConfiguration(key, previousKey);
      final matching = _items
          .where((item) => CartDisplayGroup.displayKeyForCartItem(item) == key)
          .toList(growable: false);
      _keepDisplayGroupAtZero(matching);
    } else {
      _items.removeWhere((item) {
        final itemKey = CartDisplayGroup.displayKeyForCartItem(item);
        return itemKey == key || itemKey == previousKey;
      });
      _items.addAll(rows);
      _mergeExactDuplicates();
    }
    _persistAndNotify();
    return true;
  }

  void _keepDisplayGroupAtZero(List<CartItem> matching) {
    if (matching.isEmpty) {
      return;
    }

    final primary = matching.first;
    _updateQuantityInternal(primary.itemId, 0, primary.selectedVariants);
    for (final duplicate in matching.skip(1)) {
      _removeItemInternal(duplicate.itemId, duplicate.selectedVariants);
    }
    _mergeExactDuplicates();
  }

  /// Добавление товара с опциями в корзину
  bool addItemWithOptions(
    int itemId,
    String name,
    String img,
    double price,
    double quantity,
    List<Map<String, dynamic>> selectedVariants,
    List<Map<String, dynamic>> promotions,
    String? itemType,
    String? packagingType,
    Map<String, dynamic>? itemData,
  ) {
    if (!_canMutate) return false;
    // Используем переданные мапы вариантов и акций
    final variantMaps = SmartCartSelection.normalizeVariantMaps(
        List<Map<String, dynamic>>.from(selectedVariants));
    final promoMaps = List<Map<String, dynamic>>.from(promotions);
    final snapshot =
        itemData == null ? null : item_model.Item.fromJson(itemData);
    final selection = snapshot == null ? null : SmartCartSelection(snapshot);
    final bottles = selection?.filteredBottles.where((bottle) =>
        variantMaps.any((variant) =>
            SmartCartSelection.variantRelationId(variant) ==
            bottle.relationId));
    final step = bottles?.isNotEmpty == true
        ? selection!.volumeForBottle(bottles!.first)
        : (snapshot?.effectiveStepQuantity ?? 1.0);
    final newItem = CartItem(
      itemId: itemId,
      name: name,
      price: price,
      quantity: quantity,
      stepQuantity: step,
      image: img.isNotEmpty ? img : null,
      itemType: itemType,
      packagingType: packagingType,
      selectedVariants: variantMaps,
      promotions: promoMaps,
      itemData: itemData,
      maxAmount: snapshot?.amount,
    );
    return addItem(newItem);
  }

  CartItem _normalizeItem(CartItem item) {
    final snapshot = item.snapshotItem;
    final selection = snapshot == null ? null : SmartCartSelection(snapshot);
    final variants =
        SmartCartSelection.normalizeVariantMaps(item.selectedVariants);
    final bottle = selection?.bottleVariants.firstWhereOrNull((bottle) =>
        variants.any((variant) =>
            SmartCartSelection.variantRelationId(variant) ==
            bottle.relationId));
    final step = bottle == null
        ? (selection?.quantityIssue == null
            ? snapshot?.effectiveStepQuantity
            : item.stepQuantity)
        : selection!.volumeForBottle(bottle);
    if (bottle != null) {
      for (final variant in variants) {
        if (SmartCartSelection.variantRelationId(variant) ==
            bottle.relationId) {
          variant['parent_item_amount'] = step;
        }
      }
    }
    return item.copyWith(
      selectedVariants: variants,
      stepQuantity: step ?? item.stepQuantity,
    );
  }

  void _mergeExactDuplicates() {
    if (_items.length < 2) {
      return;
    }

    final merged = <String, CartItem>{};
    for (final item in _items) {
      final key =
          '${item.itemId}|${item.selectedVariants.map(SmartCartSelection.variantStableKey).join(';')}';
      final existing = merged[key];
      if (existing == null) {
        merged[key] = item;
        continue;
      }

      existing.quantity += item.quantity;
      if (existing.itemData == null && item.itemData != null) {
        merged[key] = existing.copyWith(itemData: item.itemData);
      }
    }

    _items
      ..clear()
      ..addAll(merged.values);
  }

  void _persistAndNotify() {
    _revision++;
    final groups = CartDisplayGroup.groupItems(_items);
    var repairedGiftAllocation = false;
    // A paid-volume mutation can change the gift threshold. Retained repeat-
    // order capacity is valid only for the unchanged gift volume.
    for (final group in groups) {
      if (group.retainedGiftBottleCounts == null ||
          group.allocationIssue == null) {
        continue;
      }
      for (final item in group.items) {
        final index = _items.indexOf(item);
        _items[index] = item.copyWith(clearGiftBottleCounts: true);
      }
      repairedGiftAllocation = true;
    }
    _cacheDisplayGroups(
        repairedGiftAllocation ? CartDisplayGroup.groupItems(_items) : groups);
    _saveCart();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _saveStatus.dispose();
    super.dispose();
  }
}
