import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/core/quantity.dart';
import 'package:naliv_delivery/core/product_view.dart';
import 'package:naliv_delivery/model/item.dart' as item_model;
import 'package:naliv_delivery/services/repeat_order_service.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/smart_cart.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('fractional measures retain supported capacity precision', () {
    expect(formatQuantity(0.475, 'л'), '0.475 л');
    expect(formatQuantity(1.25, 'кг'), '1.25 кг');
    expect(formatQuantity(0.001, ''), '0.001');
    expect(formatQuantity(0.00025, 'кг'), '0.00025 кг');
    expect(formatQuantity(0, 'кг'), '0 кг');
  });

  test('typed fractional stock survives selection, persistence, order and repeat',
      () async {
    final response = CategoryItemsResponse.fromJson({
      'success': true,
      'data': {
        'category': {'category_id': 12, 'name': 'Весовые товары'},
        'business': {'business_id': 7, 'name': 'Магазин'},
        'items': [
          {
            'item_id': 700,
            'name': 'Сыр',
            'price': 1000,
            'amount': '0,75',
            'unit': 'кг',
            'quantity': 0.5,
            'step_quantity': 0.25,
            'category': {'category_id': 12, 'name': 'Весовые товары'},
          },
        ],
      },
    });
    final item = item_model.Item.fromCategoryItem(response.data.items.single);
    expect(item.amount, 0.75);
    expect(item.quantity, 0.5);
    expect(item.effectiveStepQuantity, 0.25);
    expect(item.copyWith(name: 'Сыр, фасовка').stepQuantity, 0.25);
    expect(ProductView.fromItem(item).unitPriceLabel, '1\u00a0000 ₸/кг');
    expect(SmartCartSelection(item).usesPourFlow, isFalse);
    final cart = CartProvider();
    expect(await cart.bindBusiness(7), isTrue);
    expect(cart.syncItemSelectionQuantity(item, [], 0.25), isTrue);
    expect(cart.getTotalPrice(), 250);
    expect(cart.syncItemSelectionQuantity(item, [], 0.75), isTrue);
    expect(cart.getTotalPrice(), 750);
    expect(jsonEncode(cart.toJsonForOrder()), contains('"amount":0.75'));
    cart.incrementCatalogItem(item);
    expect(cart.activeDisplayGroups.single.totalQuantity, 0.75);

    expect(await cart.bindBusiness(7), isTrue);
    final prefs = await SharedPreferences.getInstance();
    final persisted = jsonDecode(prefs.getString('cart_items')!) as Map;
    expect((persisted['items'] as List).single['quantity'], 0.75);
    final restored = CartProvider();
    await restored.loadCart();
    expect(restored.activeDisplayGroups.single.itemSnapshot?.amount, 0.75);
    expect(restored.activeDisplayGroups.single.totalQuantity, 0.75);
    expect(restored.items.single.stepQuantity, 0.25);
    expect(restored.getTotalPrice(), 750);
    final repeated = RepeatOrderService.buildCartItemsFromOrder({
      'business_id': 7,
      'items': [
        {
          ...restored.toJsonForOrder().single,
          'name': item.name,
          'price': item.price,
          'item_data': restored.items.single.itemData,
        },
      ],
    });
    expect(repeated.skippedItems, isEmpty);
    final repeatedCart = CartProvider();
    expect(repeatedCart.addDisplayGroupItems(repeated.items), isTrue);
    expect(repeatedCart.activeDisplayGroups.single.totalQuantity, 0.75);
    expect(repeatedCart.getTotalPrice(), 750);
    expect(repeatedCart.toJsonForOrder(), restored.toJsonForOrder());
    restored.decrementCatalogItem(item);
    expect(restored.activeDisplayGroups.single.totalQuantity, 0.5);
  });

  test('package weight never substitutes for an omitted sale step', () {
    final item = item_model.Item(
        itemId: 701, name: 'Сыр', price: 1000, unit: 'кг', quantity: 0.25);
    final cart = CartProvider();
    expect(SmartCartSelection(item).quantityIssue, isNotNull);
    expect(cart.syncItemSelectionQuantity(item, [], 0.25), isFalse);
    expect(cart.items, isEmpty);
  });

  test('fractional paid and gifted demand cannot exceed stock', () {
    final item = item_model.Item.fromJson({
      'item_id': 702,
      'name': 'Сыр',
      'price': 1000,
      'unit': 'кг',
      'step_quantity': 0.25,
      'amount': 2.75,
      'promotions': [
        {'type': 'SUBTRACT', 'base_amount': 2, 'add_amount': 1},
      ],
    });
    final cart = CartProvider();
    expect(cart.syncItemSelectionQuantity(item, [], 1.75), isTrue);
    expect(cart.syncItemSelectionQuantity(item, [], 2), isFalse);
    expect(cart.activeDisplayGroups.single.totalQuantity, 1.75);
    expect(cart.toJsonForOrder().single['amount'], 1.75);
  });
}
