import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import 'package:naliv_delivery/models/cart_item.dart';

/// Провайдер управления корзиной
class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  /// Неподmodifiable список товаров в корзине
  UnmodifiableListView<CartItem> get items => UnmodifiableListView(_items);

  /// Получить товар по ID и (необязательно) вариантам
  CartItem? getItem(int itemId, [List<Map<String, dynamic>>? variants]) {
    if (variants != null) {
      return _items.firstWhereOrNull(
        (item) =>
            item.itemId == itemId &&
            const DeepCollectionEquality()
                .equals(item.selectedVariants, variants),
      );
    }
    return _items.firstWhereOrNull((item) => item.itemId == itemId);
  }

  /// Добавить товар. Возвращает false, если обязательные опции не выбраны
  bool addItem(CartItem newItem) {
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
    _saveCart();
    notifyListeners();
    return true;
  }

  /// Удалить товар(ы) по ID и (необязательно) вариантам
  void removeItem(int itemId, [List<Map<String, dynamic>>? variants]) {
    if (variants != null) {
      _items.removeWhere(
        (item) =>
            item.itemId == itemId &&
            const DeepCollectionEquality()
                .equals(item.selectedVariants, variants),
      );
    } else {
      _items.removeWhere((item) => item.itemId == itemId);
    }
    _saveCart();
    notifyListeners();
  }

  /// Очистить всю корзину
  void clearCart() {
    _items.clear();
    _saveCart();
    notifyListeners();
  }

  /// Обновить количество товара, удалит при <=0
  void updateQuantity(int itemId, double newQuantity,
      [List<Map<String, dynamic>>? variants]) {
    final item = getItem(itemId, variants);
    if (item == null) return;
    item.updateQuantity(newQuantity);
    if (item.quantity <= 0) _items.remove(item);
    _saveCart();
    notifyListeners();
  }

  /// Общая сумма корзины с учетом скидок
  double getTotalPrice() =>
      _items.fold(0.0, (sum, item) => sum + item.totalPrice);

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
        ..addAll(
            decoded.map((e) => CartItem.fromJson(e as Map<String, dynamic>)));
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

  /// Добавление товара с опциями в корзину
  bool addItemWithOptions(
    int itemId,
    String name,
    String img,
    double price,
    double quantity,
    List<Map<String, dynamic>> selectedVariants,
    List<Map<String, dynamic>> promotions,
  ) {
    // Используем переданные мапы вариантов и акций
    final variantMaps = List<Map<String, dynamic>>.from(selectedVariants);
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
      selectedVariants: variantMaps,
      promotions: promoMaps,
    );
    return addItem(newItem);
  }
}
