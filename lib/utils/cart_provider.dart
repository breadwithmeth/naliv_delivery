import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import 'package:naliv_delivery/models/cart_item.dart';
import 'package:naliv_delivery/model/item.dart' as item_model;

import 'smart_cart.dart';

/// Провайдер управления корзиной
class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

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

  List<CartDisplayGroup> get displayGroups =>
      CartDisplayGroup.groupItems(_items);

  int get displayItemCount => displayGroups.length;

  /// Добавить товар. Возвращает false, если обязательные опции не выбраны
  bool addItem(CartItem newItem) {
    final normalizedItem = _normalizeItem(newItem);
    final added = _addItemInternal(normalizedItem);
    if (!added) {
      return false;
    }
    _mergeExactDuplicates();
    _persistAndNotify();
    return true;
  }

  bool _addItemInternal(CartItem newItem) {
    for (final variant in newItem.selectedVariants) {
      // Проверяем обязательные опции, если есть
      final int req = variant['required'] as int? ?? 0;
      if (req == 1) {
        // Получаем id варианта: сначала из 'variant_id', потом из вложенного 'variant.relation_id'
        int vid = variant['variant_id'] as int? ?? 0;
        if (vid == 0 && variant['variant'] is Map) {
          vid = (variant['variant']['relation_id'] as int?) ?? 0;
        }
        if (vid == 0) return false;
      }
    }

    final index = _items.indexWhere(
      (item) =>
          item.itemId == newItem.itemId &&
          const DeepCollectionEquality()
              .equals(item.selectedVariants, newItem.selectedVariants),
    );
    if (index >= 0) {
      _items[index].updateQuantity(_items[index].quantity + newItem.quantity);
    } else {
      _items.add(newItem);
    }
    return true;
  }

  /// Удалить товар(ы) по ID и (необязательно) вариантам
  void removeItem(int itemId, [List<Map<String, dynamic>>? variants]) {
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
    _items.clear();
    _persistAndNotify();
  }

  /// Обновить количество товара, удалит при <=0
  void updateQuantity(int itemId, double newQuantity,
      [List<Map<String, dynamic>>? variants]) {
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
    if (item.quantity <= 0) _items.remove(item);
    return true;
  }

  /// Общая сумма корзины с учетом скидок
  double getTotalPrice() =>
      displayGroups.fold(0.0, (sum, item) => sum + item.totalPrice);

  /// Сохранить корзину
  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'cart_items',
      jsonEncode(_items.map((e) => e.toJson()).toList()),
    );
  }

  /// Загрузить корзину
  Future<void> loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('cart_items');
    if (jsonString != null) {
      final decoded = jsonDecode(jsonString) as List<dynamic>;
      _items
        ..clear()
        ..addAll(decoded.map((e) =>
            _normalizeItem(CartItem.fromJson(e as Map<String, dynamic>))));
      _mergeExactDuplicates();
      notifyListeners();
    }
  }

  /// Получить все варианты товара в корзине по ID
  List<CartItem> getItemVariants(int itemId) {
    return _items.where((item) => item.itemId == itemId).toList();
  }

  /// Общее количество товара в корзине по ID (учитывает все варианты)
  double getTotalQuantityForItem(int itemId) {
    return getItemVariants(itemId)
        .fold(0.0, (sum, item) => sum + item.quantity);
  }

  /// Обновление количества с учетом выбранных вариантов
  void updateQuantityWithVariants(
      int itemId, List<Map<String, dynamic>> variants, double newQuantity) {
    updateQuantity(itemId, newQuantity, variants);
  }

  double getCatalogQuantity(item_model.Item item) {
    final selection = SmartCartSelection(item);
    final group = displayGroups
        .firstWhereOrNull((entry) => entry.key == selection.defaultDisplayKey);
    return group?.totalQuantity ?? 0.0;
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

  void updateDisplayGroupBottleCounts(
      CartDisplayGroup group, Map<int, int> bottleCounts) {
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

  void _adjustItemGroupQuantity(
    item_model.Item item, {
    required int direction,
  }) {
    final selection = SmartCartSelection(item);
    final key = selection.defaultDisplayKey;
    final currentGroup =
        displayGroups.firstWhereOrNull((entry) => entry.key == key);
    final currentQuantity = currentGroup?.totalQuantity ?? 0.0;
    final step = selection.defaultStepQuantity;
    final nextQuantity =
        selection.clampQuantity(currentQuantity + (step * direction));

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
    final snapshot = group.itemSnapshot;
    if (snapshot == null) {
      _adjustLegacyExistingGroup(group, direction: direction);
      return;
    }

    final selection = SmartCartSelection(snapshot);
    final step = selection.usesPourFlow ? 1.0 : selection.defaultStepQuantity;
    final nextQuantity =
        selection.clampQuantity(group.totalQuantity + (step * direction));

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

  double _legacyItemStep(CartItem item) {
    for (final variant in item.selectedVariants) {
      final variantStep = SmartCartSelection.variantParentItemAmount(variant);
      if (variantStep != null && variantStep > 0) {
        return variantStep;
      }
    }

    if (item.stepQuantity > 0) {
      return item.stepQuantity;
    }

    return 1.0;
  }

  void _syncSelectionGroup(
    SmartCartSelection selection,
    List<Map<String, dynamic>> baseVariants,
    double targetQuantity,
  ) {
    final normalizedBaseVariants =
        SmartCartSelection.normalizeVariantMaps(baseVariants);
    final displayKey = selection.displayKeyForVariants(normalizedBaseVariants);
    final matching = _items
        .where((item) =>
            CartDisplayGroup.displayKeyForCartItem(item) == displayKey)
        .toList(growable: false);

    if (selection.usesPourFlow) {
      _syncPourFlowGroup(
          selection, normalizedBaseVariants, matching, targetQuantity);
      return;
    }

    final clampedTarget = selection.clampQuantity(targetQuantity);
    if (clampedTarget <= 0) {
      for (final item in matching) {
        _removeItemInternal(item.itemId, item.selectedVariants);
      }
      _persistAndNotify();
      return;
    }

    if (matching.isEmpty) {
      if (normalizedBaseVariants.isEmpty) {
        _addItemInternal(
          CartItem(
            itemId: selection.item.itemId,
            name: selection.item.name,
            price: selection.item.price,
            quantity: clampedTarget,
            stepQuantity: selection.item.effectiveStepQuantity,
            image: selection.item.image,
            itemType: null,
            packagingType: null,
            selectedVariants: const <Map<String, dynamic>>[],
            promotions: (selection.item.promotions ??
                    const <item_model.ItemPromotion>[])
                .map((promotion) => promotion.toJson())
                .toList(growable: false),
            itemData: selection.item.toJson(),
            maxAmount: selection.item.amount?.toDouble(),
          ),
        );
      } else {
        addItemWithOptions(
          selection.item.itemId,
          selection.item.name,
          selection.item.image ?? '',
          selection.item.price,
          clampedTarget,
          normalizedBaseVariants,
          (selection.item.promotions ?? const <item_model.ItemPromotion>[])
              .map((promotion) => promotion.toJson())
              .toList(growable: false),
          null,
          null,
          selection.item.toJson(),
        );
        return;
      }
      _persistAndNotify();
      return;
    }

    final primary = matching.first;
    _updateQuantityInternal(
        primary.itemId, clampedTarget, primary.selectedVariants);
    for (final duplicate in matching.skip(1)) {
      _removeItemInternal(duplicate.itemId, duplicate.selectedVariants);
    }
    _mergeExactDuplicates();
    _persistAndNotify();
  }

  void _syncPourFlowGroup(
    SmartCartSelection selection,
    List<Map<String, dynamic>> baseVariants,
    List<CartItem> matching,
    double targetQuantity,
  ) {
    final clampedTarget = selection.clampQuantity(targetQuantity);
    final bottleCounts = clampedTarget <= 0
        ? const <int, int>{}
        : selection.autoBottleBreakdown(clampedTarget);
    final existingByBottle = <int, List<CartItem>>{};

    for (final item in matching) {
      final bottleVariant =
          item.selectedVariants.firstWhereOrNull(selection.isBottleVariant);
      final bottleId = bottleVariant == null
          ? null
          : SmartCartSelection.variantRelationId(bottleVariant);
      if (bottleId == null) {
        continue;
      }
      existingByBottle.putIfAbsent(bottleId, () => <CartItem>[]).add(item);
    }

    for (final bottle in selection.filteredBottles) {
      final bottleId = bottle.relationId;
      final desiredCount = bottleCounts[bottleId] ?? 0;
      final desiredQuantity = selection
          .clampQuantity(selection.volumeForBottle(bottle) * desiredCount);
      final existing = existingByBottle[bottleId] ?? const <CartItem>[];

      if (desiredQuantity <= 0) {
        for (final item in existing) {
          _removeItemInternal(item.itemId, item.selectedVariants);
        }
        continue;
      }

      if (existing.isEmpty) {
        _addItemInternal(
          CartItem(
            itemId: selection.item.itemId,
            name: selection.item.name,
            price: selection.item.price,
            quantity: desiredQuantity,
            stepQuantity: selection.volumeForBottle(bottle),
            image: selection.item.image,
            itemType: null,
            packagingType: null,
            selectedVariants: selection.buildVariantMaps(
                bottle: bottle, baseVariants: baseVariants),
            promotions: (selection.item.promotions ??
                    const <item_model.ItemPromotion>[])
                .map((promotion) => promotion.toJson())
                .toList(growable: false),
            itemData: selection.item.toJson(),
            maxAmount: selection.item.amount?.toDouble(),
          ),
        );
        continue;
      }

      final primary = existing.first;
      _updateQuantityInternal(
          primary.itemId, desiredQuantity, primary.selectedVariants);
      for (final duplicate in existing.skip(1)) {
        _removeItemInternal(duplicate.itemId, duplicate.selectedVariants);
      }
    }

    final targetBottleIds = bottleCounts.keys.toSet();
    for (final entry in existingByBottle.entries) {
      if (!targetBottleIds.contains(entry.key)) {
        for (final item in entry.value) {
          _removeItemInternal(item.itemId, item.selectedVariants);
        }
      }
    }

    _mergeExactDuplicates();
    _persistAndNotify();
  }

  void _syncPourFlowBottleCounts(
    SmartCartSelection selection,
    List<Map<String, dynamic>> baseVariants,
    Map<int, int> bottleCounts,
  ) {
    final normalizedBaseVariants =
        SmartCartSelection.normalizeVariantMaps(baseVariants);
    final displayKey = selection.displayKeyForVariants(normalizedBaseVariants);
    final matching = _items
        .where((item) =>
            CartDisplayGroup.displayKeyForCartItem(item) == displayKey)
        .toList(growable: false);
    final existingByBottle = <int, List<CartItem>>{};

    for (final item in matching) {
      final bottleVariant =
          item.selectedVariants.firstWhereOrNull(selection.isBottleVariant);
      final bottleId = bottleVariant == null
          ? null
          : SmartCartSelection.variantRelationId(bottleVariant);
      if (bottleId == null) {
        continue;
      }
      existingByBottle.putIfAbsent(bottleId, () => <CartItem>[]).add(item);
    }

    var totalLiters = 0.0;
    for (final bottle in selection.filteredBottles) {
      final rawCount = bottleCounts[bottle.relationId] ?? 0;
      final count = rawCount < 0 ? 0 : rawCount;
      totalLiters += selection.volumeForBottle(bottle) * count;
    }

    if (selection.maxAmount.isFinite &&
        totalLiters > selection.maxAmount + 0.001) {
      return;
    }

    for (final bottle in selection.filteredBottles) {
      final bottleId = bottle.relationId;
      final rawCount = bottleCounts[bottleId] ?? 0;
      final desiredCount = rawCount < 0 ? 0 : rawCount;
      final desiredQuantity = selection
          .clampQuantity(selection.volumeForBottle(bottle) * desiredCount);
      final existing = existingByBottle[bottleId] ?? const <CartItem>[];

      if (desiredQuantity <= 0) {
        for (final item in existing) {
          _removeItemInternal(item.itemId, item.selectedVariants);
        }
        continue;
      }

      if (existing.isEmpty) {
        _addItemInternal(
          CartItem(
            itemId: selection.item.itemId,
            name: selection.item.name,
            price: selection.item.price,
            quantity: desiredQuantity,
            stepQuantity: selection.volumeForBottle(bottle),
            image: selection.item.image,
            itemType: null,
            packagingType: null,
            selectedVariants: selection.buildVariantMaps(
                bottle: bottle, baseVariants: normalizedBaseVariants),
            promotions: (selection.item.promotions ??
                    const <item_model.ItemPromotion>[])
                .map((promotion) => promotion.toJson())
                .toList(growable: false),
            itemData: selection.item.toJson(),
            maxAmount: selection.item.amount?.toDouble(),
          ),
        );
        continue;
      }

      final primary = existing.first;
      _updateQuantityInternal(
          primary.itemId, desiredQuantity, primary.selectedVariants);
      for (final duplicate in existing.skip(1)) {
        _removeItemInternal(duplicate.itemId, duplicate.selectedVariants);
      }
    }

    _mergeExactDuplicates();
    _persistAndNotify();
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
    // Используем переданные мапы вариантов и акций
    final variantMaps = SmartCartSelection.normalizeVariantMaps(
        List<Map<String, dynamic>>.from(selectedVariants));
    final promoMaps = List<Map<String, dynamic>>.from(promotions);
    // Определяем шаг изменения из parent_item_amount или stepQuantity
    double step = variantMaps.isNotEmpty &&
            variantMaps.first['parent_item_amount'] != null
        ? (variantMaps.first['parent_item_amount'] as num).toDouble()
        : quantity;
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
    );
    return addItem(newItem);
  }

  CartItem _normalizeItem(CartItem item) {
    return item.copyWith(
      selectedVariants:
          SmartCartSelection.normalizeVariantMaps(item.selectedVariants),
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

      existing.updateQuantity(existing.quantity + item.quantity);
      if (existing.itemData == null && item.itemData != null) {
        merged[key] = existing.copyWith(itemData: item.itemData);
      }
    }

    _items
      ..clear()
      ..addAll(merged.values);
  }

  void _persistAndNotify() {
    _saveCart();
    notifyListeners();
  }
}
