import 'package:naliv_delivery/misc/api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

// Типизированная модель корзины
typedef CartModel = Map<String, dynamic>;
typedef CartItemModel = Map<String, dynamic>;
typedef CartOptionModel = Map<String, dynamic>;

class DatabaseManager {
  static const String _cartsKey = 'carts';
  static const String _cartItemsKey = 'cart_items';
  static const String _cartItemOptionsKey = 'cart_items_options';

  // Статусы корзины
  static const int cartStatusActive = 0;
  static const int cartStatusCompleted = 1;

  static final DatabaseManager _instance = DatabaseManager._internal();

  factory DatabaseManager() => _instance;

  DatabaseManager._internal();

  final StreamController<Map?> _cartStreamController =
      StreamController<Map?>.broadcast();

  Stream<Map?> get cartUpdates => _cartStreamController.stream;

  Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  Future<List<dynamic>> _getStorageList(String key) async {
    final prefs = await _prefs;
    return jsonDecode(prefs.getString(key) ?? '[]');
  }

  Future<void> _saveStorageList(String key, List<dynamic> data) async {
    final prefs = await _prefs;
    await prefs.setString(key, jsonEncode(data));
  }

  Future<int> getCartId(int businessId) async {
    final List<dynamic> cartList = await _getStorageList(_cartsKey);
    final cart = cartList.firstWhere(
      (cart) =>
          cart['status'] == cartStatusActive &&
          cart['business_id'] == businessId,
      orElse: () => null,
    );

    if (cart == null) {
      final newCart = {
        "id": cartList.length + 1,
        "business_id": businessId,
        "status": cartStatusActive,
      };
      cartList.add(newCart);
      await _saveStorageList(_cartsKey, cartList);
      return newCart['id'] as int;
    }
    return cart['id'];
  }

  Future<Map<String, dynamic>?> addToCart(
    int businessId,
    int itemId,
    double amount,
    double inStock,
    int price,
    String name,
    double quantity,
    String? img, {
    List<Map>? options,
  }) async {
    final cartId = await getCartId(businessId);
    final List<dynamic> cartItemList = await _getStorageList(_cartItemsKey);

    int cartItemId = await _getOrCreateCartItem(
      cartItemList,
      cartId,
      itemId,
      amount,
      inStock,
      price,
      name,
      quantity,
      img,
      options,
    );

    await _saveStorageList(_cartItemsKey, cartItemList);

    if (options != null && options.isNotEmpty) {
      await _saveCartItemOptions(cartId, cartItemId, options);
    }

    _cartStreamController.add({"item_id": itemId});
    return cartItemList.firstWhere((item) => item['id'] == cartItemId);
  }

  Future<int> _getOrCreateCartItem(
    List<dynamic> cartItemList,
    int cartId,
    int itemId,
    double amount,
    double inStock,
    int price,
    String name,
    double quantity,
    String? img,
    List<Map>? options,
  ) async {
    final existingItem = cartItemList.firstWhere(
      (item) => item['item_id'] == itemId && item['cart_id'] == cartId,
      orElse: () => null,
    );

    if (existingItem != null) {
      existingItem['amount'] = amount;
      return existingItem['id'];
    }

    final newItemId = cartItemList.length + 1;
    cartItemList.add({
      "id": newItemId,
      "item_id": itemId,
      "amount": amount,
      "cart_id": cartId,
      "in_stock": inStock,
      "price": price,
      "name": name,
      "img": img ?? "",
      "quantity": quantity,
      "parent_amount": options?.isNotEmpty == true
          ? options!.first["parent_item_amount"]
          : null,
    });

    return newItemId;
  }

  Future<void> _saveCartItemOptions(
    int cartId,
    int cartItemId,
    List<Map> options,
  ) async {
    final List<dynamic> cartItemOptionList =
        await _getStorageList(_cartItemOptionsKey);

    for (var option in options) {
      cartItemOptionList.add({
        "cart_item_id": cartItemId,
        "option_item_relation_id": option["relation_id"],
        "cart_id": cartId,
        "parent_amount": option["parent_item_amount"],
        "option_name": option["name"],
        "price": option["price"],
      });
    }

    await _saveStorageList(_cartItemOptionsKey, cartItemOptionList);
  }

  Future<Map<String, dynamic>?> getCartItemByItemId(
      int businessId, int itemId) async {
    final prefs = await _prefs;
    final cartId = await getCartId(businessId);

    final cartItems = prefs.getString('cart_items') ?? '[]';
    final List<dynamic> cartItemList = jsonDecode(cartItems);

    final cartItem = cartItemList.firstWhere(
      (item) => item['item_id'] == itemId && item['cart_id'] == cartId,
      orElse: () => null,
    );

    if (cartItem != null) {
      return cartItem;
    }
    return null;
  }

  Future<Map<String, dynamic>?> updateAmount(
      int businessId, int itemId, double newAmount) async {
    final prefs = await _prefs;
    final cartId = await getCartId(businessId);

    final cartItems = prefs.getString('cart_items') ?? '[]';
    final List<dynamic> cartItemList = jsonDecode(cartItems);

    final cartItem = cartItemList.firstWhere(
      (item) => item['item_id'] == itemId && item['cart_id'] == cartId,
      orElse: () => null,
    );

    if (cartItem != null) {
      final int inStock = (cartItem['in_stock'] as num).toInt();

      if (newAmount <= 0) {
        cartItemList.remove(cartItem);
        prefs.setString('cart_items', jsonEncode(cartItemList));
        _cartStreamController.add({"item_id": itemId});
        return null;
      } else {
        final updatedAmount = newAmount > inStock ? inStock : newAmount;
        cartItem['amount'] = updatedAmount;
        prefs.setString('cart_items', jsonEncode(cartItemList));
        _cartStreamController.add({"item_id": itemId});
        return cartItem;
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllItemsInCart(int businessId) async {
    final prefs = await _prefs;
    final cartId = await getCartId(businessId);

    final cartItems = prefs.getString('cart_items') ?? '[]';
    final List<dynamic> cartItemList = jsonDecode(cartItems);

    final cartItemOptions = prefs.getString('cart_items_options') ?? '[]';
    final List<dynamic> cartItemOptionList = jsonDecode(cartItemOptions);

    final List<Map<String, dynamic>> result = [];

    for (var cartItem in cartItemList) {
      if (cartItem['cart_id'] == cartId) {
        final options = cartItemOptionList
            .where((option) => option['cart_item_id'] == cartItem['id'])
            .toList();
        result.add({
          ...cartItem,
          'options': options,
        });
      }
    }

    return result;
  }

  Future<double> getCartTotal(int businessId) async {
    final prefs = await _prefs;
    final cartId = await getCartId(businessId);
    double total = 0;

    final cartItems = prefs.getString('cart_items') ?? '[]';
    final List<dynamic> cartItemList = jsonDecode(cartItems);

    final cartItemOptions = prefs.getString('cart_items_options') ?? '[]';
    final List<dynamic> cartItemOptionList = jsonDecode(cartItemOptions);

    for (var cartItem in cartItemList) {
      if (cartItem['cart_id'] == cartId) {
        final amount = (cartItem['amount'] as num).toDouble();
        final price = (cartItem['price'] as num).toDouble();
        final options = cartItemOptionList
            .where((option) => option['cart_item_id'] == cartItem['id'])
            .toList();

        double optionTotal = 0;
        for (var option in options) {
          final optionPrice = (option['price'] as num).toDouble();
          final parentAmount = (option['parent_amount'] as num).toDouble();
          final optionCount = parentAmount > 0 ? amount / parentAmount : 0;
          optionTotal += optionCount * optionPrice;
        }

        total += price * amount + optionTotal;
      }
    }

    return total;
  }

  Future<void> updateCartStatusByBusinessId(int businessId) async {
    final prefs = await _prefs;

    final carts = prefs.getString('carts') ?? '[]';
    final List<dynamic> cartList = jsonDecode(carts);

    final cart = cartList.firstWhere(
      (cart) => cart['business_id'] == businessId && cart['status'] == 0,
      orElse: () => null,
    );

    if (cart != null) {
      cart['status'] = 1;
      prefs.setString('carts', jsonEncode(cartList));
      _cartStreamController.add(null);
    }
  }

  Future<void> clearCart(int businessId) async {
    final cartId = await getCartId(businessId);

    // Удаляем элементы корзины и их опции
    await Future.wait([
      _removeCartItems(cartId),
      _removeCartItemOptions(cartId),
      _updateCartStatus(cartId),
    ]);

    _cartStreamController.add(null);
  }

  Future<void> _removeCartItems(int cartId) async {
    final List<dynamic> items = await _getStorageList(_cartItemsKey);
    items.removeWhere((item) => item['cart_id'] == cartId);
    await _saveStorageList(_cartItemsKey, items);
  }

  Future<void> _removeCartItemOptions(int cartId) async {
    final List<dynamic> options = await _getStorageList(_cartItemOptionsKey);
    options.removeWhere((option) => option['cart_id'] == cartId);
    await _saveStorageList(_cartItemOptionsKey, options);
  }

  Future<void> _updateCartStatus(int cartId) async {
    final List<dynamic> carts = await _getStorageList(_cartsKey);
    final cart = carts.firstWhere(
      (cart) => cart['id'] == cartId,
      orElse: () => null,
    );
    if (cart != null) {
      cart['status'] = cartStatusCompleted;
      await _saveStorageList(_cartsKey, carts);
    }
  }

  void dispose() {
    _cartStreamController.close();
  }
}
