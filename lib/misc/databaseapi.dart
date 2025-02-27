import 'package:naliv_delivery/misc/api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

class DatabaseManager {
  static final DatabaseManager _instance = DatabaseManager._internal();

  factory DatabaseManager() => _instance;

  DatabaseManager._internal();

  final StreamController<Map?> _cartStreamController =
      StreamController<Map?>.broadcast();

  Stream<Map?> get cartUpdates => _cartStreamController.stream;

  Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  Future<int> getCartId(int businessId) async {
    final prefs = await _prefs;
    final carts = prefs.getString('carts') ?? '[]';
    final List<dynamic> cartList = jsonDecode(carts);

    final cart = cartList.firstWhere(
      (cart) => cart['status'] == 0 && cart['business_id'] == businessId,
      orElse: () => null,
    );

    if (cart == null) {
      final newCart = {
        "id": cartList.length + 1,
        "business_id": businessId,
        "status": 0,
      };
      cartList.add(newCart);
      prefs.setString('carts', jsonEncode(cartList));
      return newCart['id']!;
    } else {
      return cart['id'];
    }
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
    final prefs = await _prefs;
    final cartId = await getCartId(businessId);

    final cartItems = prefs.getString('cart_items') ?? '[]';
    final List<dynamic> cartItemList = jsonDecode(cartItems);

    final cartItem = cartItemList.firstWhere(
      (item) => item['item_id'] == itemId && item['cart_id'] == cartId,
      orElse: () => null,
    );

    int? cartItemId;

    if (cartItem == null) {
      cartItemId = cartItemList.length + 1;
      final newItem = {
        "id": cartItemId,
        "item_id": itemId,
        "amount": amount,
        "cart_id": cartId,
        "in_stock": inStock,
        "price": price,
        "name": name,
        "img": img ?? "",
        "quantity": quantity,
        "parent_amount": options != null && options.isNotEmpty
            ? options.first["parent_item_amount"]
            : null,
      };
      cartItemList.add(newItem);
    } else {
      cartItemId = cartItem['id'];
      cartItem['amount'] = amount;
    }

    prefs.setString('cart_items', jsonEncode(cartItemList));

    if (options != null && options.isNotEmpty) {
      final cartItemOptions = prefs.getString('cart_items_options') ?? '[]';
      final List<dynamic> cartItemOptionList = jsonDecode(cartItemOptions);

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

      prefs.setString('cart_items_options', jsonEncode(cartItemOptionList));
    }

    _cartStreamController.add({"item_id": itemId});
    return cartItemList.firstWhere((item) => item['id'] == cartItemId);
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

  void dispose() {
    _cartStreamController.close();
  }
}
