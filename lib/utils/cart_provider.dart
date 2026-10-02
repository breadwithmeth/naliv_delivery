import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import 'package:naliv_delivery/models/cart_item.dart';
import 'package:naliv_delivery/model/item.dart' as item_model;

import 'smart_cart.dart';
import 'subtract_promotion_math.dart';

/// Провайдер управления корзиной
class CartProvider extends ChangeNotifier {
  static const double _quantityEpsilon = 0.001;

  final List<CartItem> _items = [];
  final Map<String, int> _displayOrderByKey = <String, int>{};
  int _nextDisplayOrder = 0;

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
    final groups = CartDisplayGroup.groupItems(_items);
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

    return groups;
  }

  List<CartDisplayGroup> get activeDisplayGroups => displayGroups
      .where((group) => group.totalQuantity > _quantityEpsilon)
      .toList(growable: false);

  bool get hasActiveItems => activeDisplayGroups.isNotEmpty;

  int get displayItemCount => activeDisplayGroups.length;

  /// Добавить товар. Возвращает false, если обязательные опции не выбраны
  bool addItem(CartItem newItem) {
    final normalizedItem = _normalizeItem(newItem);
    final snapshot = normalizedItem.snapshotItem;
    if (!normalizedItem.quantity.isFinite || normalizedItem.quantity < 0) {
      return false;
    }
    if (snapshot != null) {
      final selection = SmartCartSelection(snapshot);
      if (selection.containerIssue != null) return false;
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
    final added = _addItemInternal(normalizedItem);
    if (!added) {
      return false;
    }
    _mergeExactDuplicates();
    _persistAndNotify();
    return true;
  }

  bool addDisplayGroupItems(Iterable<CartItem> items) {
    final rows = items.map(_normalizeItem).toList(growable: false);
    if (rows.isEmpty) return false;
    final groups = CartDisplayGroup.groupItems(rows);
    if (groups.length != 1) return false;
    final group = groups.single;
    final selection = group.selection;
    if (rows.any((row) =>
        !row.quantity.isFinite ||
        row.quantity <= 0 ||
        (row.quantity / row.stepQuantity -
                    (row.quantity / row.stepQuantity).round())
                .abs() >
            0.0000001 ||
        !_requiredVariantsSelected(row.selectedVariants))) {
      return false;
    }
    if (group.allocationIssue != null) return false;
    final current =
        displayGroups.firstWhereOrNull((entry) => entry.key == group.key);
    if (selection != null &&
        !_fitsStock(selection, group.key,
            (current?.totalQuantity ?? 0) + group.totalQuantity)) {
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

  bool _requiredVariantsSelected(List<Map<String, dynamic>> variants) {
    for (final variant in variants) {
      if (variant['required'] != 1) continue;
      final relationId = SmartCartSelection.variantRelationId(variant);
      if (relationId == null || relationId == 0) return false;
    }
    return true;
  }

  bool _addItemInternal(CartItem newItem) {
    if (!_requiredVariantsSelected(newItem.selectedVariants)) return false;

    final index = _items.indexWhere(
      (item) =>
          item.itemId == newItem.itemId &&
          const DeepCollectionEquality()
              .equals(item.selectedVariants, newItem.selectedVariants),
    );
    if (index >= 0) {
      _items[index].quantity += newItem.quantity;
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
    _displayOrderByKey.clear();
    _nextDisplayOrder = 0;
    _persistAndNotify();
  }

  /// Обновить количество товара, удалит при <=0
  void updateQuantity(int itemId, double newQuantity,
      [List<Map<String, dynamic>>? variants]) {
    final existing = getItem(itemId, variants);
    if (existing == null || !newQuantity.isFinite || newQuantity < 0) return;
    final ratio = newQuantity / existing.stepQuantity;
    if ((ratio - ratio.round()).abs() > 0.0000001) return;
    final snapshot = existing.snapshotItem;
    if (snapshot != null) {
      final key = CartDisplayGroup.displayKeyForCartItem(existing);
      final group = displayGroups.firstWhereOrNull((group) => group.key == key);
      final paid =
          (group?.totalQuantity ?? 0) - existing.quantity + newQuantity;
      if (!_fitsStock(SmartCartSelection(snapshot), key, paid)) return;
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

  /// Общая сумма корзины с учетом скидок
  double getTotalPrice() =>
      displayGroups.fold(0.0, (sum, item) => sum + item.totalPrice);

  List<Map<String, dynamic>> toJsonForOrder() => [
        for (final group in activeDisplayGroups) ...group.toJsonForOrder(),
      ];

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
      _displayOrderByKey.clear();
      _nextDisplayOrder = 0;
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

  void removeDisplayGroup(CartDisplayGroup group) {
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
      _syncSelectionGroup(
          SmartCartSelection(item), baseVariants, targetQuantity,
          previousBaseVariants: previousBaseVariants);

  bool syncItemBottleCounts(
    item_model.Item item,
    List<Map<String, dynamic>> baseVariants,
    Map<int, int> bottleCounts, {
    List<Map<String, dynamic>>? previousBaseVariants,
  }) {
    final selection = SmartCartSelection(item);
    if (!selection.usesPourFlow) return false;
    return _syncPourFlowBottleCounts(selection, baseVariants, bottleCounts,
        previousBaseVariants: previousBaseVariants);
  }

  void _adjustItemGroupQuantity(
    item_model.Item item, {
    required int direction,
  }) {
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
    final snapshot = group.itemSnapshot;
    if (snapshot == null) {
      _adjustLegacyExistingGroup(group, direction: direction);
      return;
    }

    final selection = SmartCartSelection(snapshot);
    if (selection.usesPourFlow) {
      final counts = group.paidBottleCounts;
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

  double _orderQuantity(SmartCartSelection selection, double paid) =>
      paid +
      subtractPromotionFreeQuantity(paid, [
        for (final promotion
            in selection.item.promotions ?? const <item_model.ItemPromotion>[])
          if (promotion.isActive) promotion.toJson(),
      ]);

  bool _fitsStock(SmartCartSelection selection, String key, double paid,
      {String? previousKey}) {
    if (selection.usesPourFlow) {
      try {
        selection.giftBottleBreakdown(paid);
      } on StateError {
        return false;
      }
    }
    final reserved = activeDisplayGroups
        .where((group) =>
            group.itemId == selection.item.itemId &&
            group.key != key &&
            group.key != previousKey)
        .fold<double>(0, (sum, group) => sum + group.totalOrderQuantity);
    return reserved + _orderQuantity(selection, paid) <=
        selection.maxAmount + 0.0000001;
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
    if (selection.containerIssue != null) return false;
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
    if (!targetQuantity.isFinite ||
        targetQuantity < 0 ||
        !_fitsStock(selection, key, targetQuantity, previousKey: previousKey)) {
      return false;
    }
    if (selection.usesPourFlow) {
      try {
        return _syncPourFlowBottleCounts(
            selection, variants, selection.autoBottleBreakdown(targetQuantity),
            previousBaseVariants: previousBaseVariants);
      } on StateError {
        return false;
      }
    }
    final step = selection.defaultStepQuantity;
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
        entry.value < 0 || !selection.bottleRelationIds.contains(entry.key))) {
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
    final totalLiters = selection.filteredBottles.fold<double>(
        0,
        (sum, bottle) =>
            sum +
            selection.volumeForBottle(bottle) *
                (bottleCounts[bottle.relationId] ?? 0));
    if (!_fitsStock(selection, key, totalLiters, previousKey: previousKey)) {
      return false;
    }
    final opened = displayGroups
        .firstWhereOrNull((group) => group.key == (previousKey ?? key));
    Map<int, int>? retainedGifts;
    if (opened != null &&
        opened.freeQuantity > 0 &&
        opened.allocationIssue == null) {
      final currentGifts = opened.selection!.giftBottleBreakdown(
          opened.totalQuantity,
          retainedCounts: opened.retainedGiftBottleCounts);
      final nextGift = _orderQuantity(selection, totalLiters) - totalLiters;
      retainedGifts = SmartCartSelection.scaledBottleCounts(
          currentGifts, nextGift / opened.freeQuantity);
      if (retainedGifts != null) {
        try {
          selection.giftBottleBreakdown(totalLiters,
              retainedCounts: retainedGifts);
        } on StateError {
          retainedGifts = null;
        }
      }
    }
    final snapshot = selection.item.toJson();
    final promotions = [
      for (final promotion
          in selection.item.promotions ?? const <item_model.ItemPromotion>[])
        if (promotion.isActive) promotion.toJson(),
    ];
    final rows = <CartItem>[
      for (final bottle in selection.filteredBottles)
        if ((bottleCounts[bottle.relationId] ?? 0) > 0)
          CartItem(
            itemId: selection.item.itemId,
            name: selection.item.name,
            price: selection.item.price,
            quantity: selection.volumeForBottle(bottle) *
                bottleCounts[bottle.relationId]!,
            stepQuantity: selection.volumeForBottle(bottle),
            giftBottleCounts: retainedGifts,
            image: selection.item.image,
            selectedVariants: selection.buildVariantMaps(
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
    final bottle = selection?.filteredBottles.firstWhereOrNull((bottle) =>
        variants.any((variant) =>
            SmartCartSelection.variantRelationId(variant) ==
            bottle.relationId));
    final step = bottle == null
        ? snapshot?.effectiveStepQuantity
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
    // A paid-volume mutation can change the gift threshold. Retained repeat-
    // order capacity is valid only for the unchanged gift volume.
    for (final group in CartDisplayGroup.groupItems(_items)) {
      if (group.retainedGiftBottleCounts == null ||
          group.allocationIssue == null) {
        continue;
      }
      for (var index = 0; index < _items.length; index++) {
        if (CartDisplayGroup.displayKeyForCartItem(_items[index]) ==
            group.key) {
          _items[index] = _items[index].copyWith(clearGiftBottleCounts: true);
        }
      }
    }
    _saveCart();
    notifyListeners();
  }
}
