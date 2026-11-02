import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/model/cart_item.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/smart_cart.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('exact catalogue re-add adopts the latest price and snapshot on reload',
      () async {
    final cart = CartProvider();
    addTearDown(cart.dispose);
    expect(cart.addItem(_row(_item(price: 100, stock: 10))), isTrue);
    expect(cart.addItem(_row(_item(price: 120, stock: 2))), isTrue);
    await cart.loadCart();

    final restarted = CartProvider();
    addTearDown(restarted.dispose);
    await restarted.ensureLoaded();
    for (final provider in [cart, restarted]) {
      expect(provider.items, hasLength(1));
      expect(provider.getTotalQuantityForItem(8201), 2);
      expect(provider.getTotalPrice(), 240);
      expect(provider.items.single.price, 120);
      expect(provider.items.single.snapshotItem!.price, 120);
      expect(provider.activeDisplayGroups.single.maxAmount, 2);
    }
  });

  test('exact catalogue re-add applies fresh stock to subsequent increments',
      () async {
    final cart = CartProvider();
    addTearDown(cart.dispose);
    expect(cart.addItem(_row(_item(price: 100, stock: 10))), isTrue);
    expect(cart.addItem(_row(_item(price: 100, stock: 2))), isTrue);
    await cart.loadCart();

    final restarted = CartProvider();
    addTearDown(restarted.dispose);
    await restarted.ensureLoaded();
    for (final provider in [cart, restarted]) {
      provider.incrementDisplayGroup(provider.activeDisplayGroups.single);
      expect(provider.getTotalQuantityForItem(8201), 2);
      expect(provider.activeDisplayGroups.single.maxAmount, 2);
    }
    await cart.loadCart();
    await restarted.loadCart();
  });

  test('fresh base price and promotion replace the same catalogue row together',
      () async {
    final cart = CartProvider();
    addTearDown(cart.dispose);
    expect(cart.addItem(_row(_item(price: 100, stock: 10))), isTrue);
    final current = _item(price: 120, stock: 2, discount: 10);
    expect(cart.addItem(_row(current)), isTrue);
    expect(cart.getTotalQuantityForItem(8201), 2);
    expect(cart.activeDisplayGroups.single.freeQuantity, 0);
    expect(cart.getTotalPrice(), 216);
    await cart.loadCart();
  });

  for (final tariff in ['ADD', 'REPLACE']) {
    test(
        'catalogue re-add refreshes $tariff metadata without splitting identity',
        () async {
      final cart = CartProvider();
      addTearDown(cart.dispose);
      final oldItem = _item(
        price: 100,
        stock: 10,
        tariff: tariff,
        optionPrice: tariff == 'ADD' ? 10 : 130,
      );
      final current = _item(
        price: 120,
        stock: 2,
        tariff: tariff,
        optionPrice: tariff == 'ADD' ? 25 : 170,
      );
      expect(cart.addItem(_row(oldItem)), isTrue);
      final originalKey = cart.activeDisplayGroups.single.key;
      expect(cart.addItem(_row(current)), isTrue);
      await cart.loadCart();

      final restarted = CartProvider();
      addTearDown(restarted.dispose);
      await restarted.ensureLoaded();
      for (final provider in [cart, restarted]) {
        expect(provider.items, hasLength(1));
        expect(provider.activeDisplayGroups.single.key, originalKey);
        expect(provider.getTotalQuantityForItem(8201), 2);
        expect(provider.getTotalPrice(), tariff == 'ADD' ? 290 : 340);
        expect(provider.items.single.selectedVariants.single['price'],
            tariff == 'ADD' ? 25 : 170);
        expect(provider.activeDisplayGroups.single.maxAmount, 2);
      }
    });
  }
}

Item _item({
  required double price,
  required double stock,
  double? discount,
  String? tariff,
  double optionPrice = 0,
}) =>
    Item(
      itemId: 8201,
      name: 'Лимонад',
      price: price,
      amount: stock,
      unit: 'шт',
      stepQuantity: 1,
      options: tariff == null
          ? null
          : [
              ItemOption(
                optionId: 82,
                name: 'Вкус',
                required: 1,
                selection: 'SINGLE',
                optionItems: [
                  ItemOptionItem(
                    relationId: 821,
                    itemId: 822,
                    itemName: 'Лимон',
                    priceType: tariff,
                    price: optionPrice,
                    parentItemAmount: 1,
                  ),
                ],
              ),
            ],
      promotions: discount == null
          ? null
          : [
              ItemPromotion(
                promotionId: 823,
                name: 'Скидка',
                discountType: 'PERCENT',
                discountValue: discount,
              ),
            ],
    );

CartItem _row(Item item) => CartItem(
      itemId: item.itemId,
      name: item.name,
      price: item.price,
      quantity: 1,
      stepQuantity: 1,
      selectedVariants: SmartCartSelection(item).defaultNonBottleVariants,
      promotions: [
        for (final promotion in item.promotions ?? <ItemPromotion>[])
          promotion.toJson()
      ],
      itemData: item.toJson(),
      maxAmount: item.amount,
    );
