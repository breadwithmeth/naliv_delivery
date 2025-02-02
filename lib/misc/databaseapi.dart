import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';

class DatabaseManager {
  static final DatabaseManager _instance = DatabaseManager._internal();

  factory DatabaseManager() => _instance;

  DatabaseManager._internal();

  Database? _database;
  final StreamController<Map?> _cartStreamController =
      StreamController<Map?>.broadcast();

  Stream<Map?> get cartUpdates => _cartStreamController.stream;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'naliv.db');

    return await openDatabase(
      path,
      version: 2,
      onOpen: (db) async {
        await _createTablesIfNotExists(db);
      },
      onCreate: (db, version) async {
        await _createTablesIfNotExists(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE cart_items ADD COLUMN quantity DOUBLE DEFAULT 1');
        }
      },
    );
  }

  Future<void> _createTablesIfNotExists(Database db) async {
    await db.execute(
      '''CREATE TABLE IF NOT EXISTS
      cart_items(id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, item_id INTEGER, amount DOUBLE, cart_id INTEGER, in_stock INTEGER, price INTEGER, name TEXT, img TEXT, quantity DOUBLE DEFAULT 1)''',
    );
    await db.execute(
      '''CREATE TABLE IF NOT EXISTS
      cart_items_options(id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, cart_item_id INTEGER UNIQUE, option_item_relation_id INTEGER, cart_id INTEGER, parent_amount DOUBLE, option_name TEXT, price INTEGER)''',
    );
    await db.execute(
      '''CREATE TABLE IF NOT EXISTS
      carts(id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, business_id INTEGER, status INTEGER)''',
    );
  }

  Future<int> getCartId(int businessId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT * FROM carts WHERE status = 0 AND business_id = ?',
      [businessId.toString()],
    );

    if (rows.isEmpty) {
      await db.insert(
          'carts', {"business_id": businessId.toString(), "status": "0"});
      final newRows = await db.rawQuery(
        'SELECT * FROM carts WHERE status = 0 AND business_id = ?',
        [businessId.toString()],
      );
      return int.parse(newRows.first["id"].toString());
    } else {
      return int.parse(rows.first["id"].toString());
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
    final db = await database;
    final cartId = await getCartId(businessId);

    final rows = await db.rawQuery(
      'SELECT * FROM cart_items WHERE item_id = ? AND cart_id = ?',
      [itemId, cartId],
    );

    int? cartItemId;

    if (rows.isEmpty) {
      cartItemId = await db.insert('cart_items', {
        "item_id": itemId,
        "amount": amount,
        "cart_id": cartId,
        "in_stock": inStock,
        "price": price,
        "name": name,
        "img": img ?? "",
        "quantity": quantity
      });
    } else {
      final cartItem = rows.first;
      cartItemId = cartItem["id"] as int;
      await db.update(
        'cart_items',
        {'amount': amount},
        where: 'id = ?',
        whereArgs: [cartItemId],
      );
    }

    if (options != null && options.isNotEmpty) {
      for (var option in options) {
        await db.insert('cart_items_options', {
          "cart_item_id": cartItemId,
          "option_item_relation_id": option["relation_id"],
          "cart_id": cartId,
          "parent_amount": option["parent_item_amount"],
          "option_name": option["name"],
          "price": option["price"],
        });
      }
    }

    final updatedRow = await db.rawQuery(
      'SELECT cart_items.*, cart_items_options.parent_amount FROM cart_items LEFT JOIN cart_items_options ON cart_items_options.cart_item_id = cart_items.id  WHERE cart_items.id = ?',
      [cartItemId],
    );

    _cartStreamController
        .add({"item_id": itemId}); // Notify listeners of cart changes
    return updatedRow.isNotEmpty ? updatedRow.first : null;
  }

  Future<Map<String, dynamic>?> getCartItemByItemId(
      int businessId, int itemId) async {
    final db = await database;
    final cartId = await getCartId(businessId);

    final rows = await db.rawQuery(
      'SELECT cart_items.*, cart_items_options.parent_amount FROM cart_items LEFT JOIN cart_items_options ON cart_items_options.cart_item_id = cart_items.id  WHERE cart_items.item_id = ? AND cart_items.cart_id = ?',
      [itemId, cartId],
    );

    if (rows.isNotEmpty) {
      return rows.first;
    }
    return null;
  }

  Future<Map<String, dynamic>?> updateAmount(
      int businessId, int itemId, double newAmount) async {
    final db = await database;
    final cartId = await getCartId(businessId);

    final rows = await db.rawQuery(
      'SELECT * FROM cart_items WHERE item_id = ? AND cart_id = ?',
      [itemId, cartId],
    );

    if (rows.isNotEmpty) {
      final cartItem = rows.first;
      final int inStock = double.parse(cartItem['in_stock'].toString()).toInt();

      if (newAmount <= 0) {
        await db.delete(
          'cart_items',
          where: 'id = ?',
          whereArgs: [cartItem['id']],
        );
        _cartStreamController.add(
            {"item_id": itemId}); //         return null; // Item was removed
      } else {
        final updatedAmount = newAmount > inStock ? inStock : newAmount;
        await db.update(
          'cart_items',
          {'amount': updatedAmount},
          where: 'id = ?',
          whereArgs: [cartItem['id']],
        );

        final updatedRow = await db.rawQuery(
          'SELECT cart_items.*, cart_items_options.parent_amount FROM cart_items LEFT JOIN cart_items_options ON cart_items_options.cart_item_id = cart_items.id  WHERE cart_items.id = ?',
          [cartItem['id']],
        );

        _cartStreamController
            .add({"item_id": itemId}); // Notify listeners of cart changes
        return updatedRow.first;
      }
    }
    return null; // No matching item found
  }

  Future<List<Map<String, dynamic>>> getAllItemsInCart(int businessId) async {
    final db = await database;
    final cartId = await getCartId(businessId);

    final rows = await db.rawQuery(
      '''SELECT cart_items.*, cart_items_options.parent_amount, cart_items_options.option_name, cart_items_options.option_item_relation_id
       FROM cart_items
       LEFT JOIN cart_items_options ON cart_items_options.cart_item_id = cart_items.id
       WHERE cart_items.cart_id = ?''',
      [cartId],
    );

    return rows;
  }

  Future<double> getCartTotal(int businessId) async {
    final db = await database;
    final cartId = await getCartId(businessId);

    // Получаем все товары в корзине с их количеством и ценой
    final rows = await db.rawQuery(
      '''SELECT cart_items.amount, cart_items.price, cart_items_options.price AS option_price, cart_items_options.parent_amount
       FROM cart_items
       LEFT JOIN cart_items_options ON cart_items_options.cart_item_id = cart_items.id
       WHERE cart_items.cart_id = ?''',
      [cartId],
    );

    double total = 0.0;

    // Суммируем стоимость всех товаров с их опциями
    for (var row in rows) {
      final amount = row['amount'] as double;
      final price = row['price'] as int;
      final optionPrice =
          row['option_price'] as int? ?? 0; // Цена опции, если она есть
      final parentAmount = row['parent_amount'] as double? ??
          1; // parent_amount, если он есть, по умолчанию 1

      // Количество опций для данного товара
      final optionCount = amount / parentAmount;

      // Добавляем стоимость товара и его опций
      // total += (price + optionPrice) * optionCount;
      total += price * amount + optionCount * optionPrice;
    }

    return total;
  }


  Future<void> updateCartStatusByBusinessId(int businessId) async {
  final db = await database;

  // Обновляем статус корзины на 1 для указанного business_id
  final updatedCount = await db.update(
    'carts',
    {'status': 1},
    where: 'business_id = ? AND status = 0',
    whereArgs: [businessId],
  );

  if (updatedCount > 0) {
    // Уведомляем слушателей об изменении корзины
    _cartStreamController.add(null);
  }
}


  void dispose() {
    _cartStreamController.close();
  }
}
