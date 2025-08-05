import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/checkout_page.dart';
import 'package:naliv_delivery/pages/login_page.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:provider/provider.dart';
import '../utils/cart_provider.dart';

class CartPage extends StatelessWidget {
  static const routeName = '/cart';

  const CartPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final items = cartProvider.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Корзина'),
      ),
      body: items.isEmpty
          ? const Center(
              child: Text(
                'Ваша корзина пуста',
                style: TextStyle(fontSize: 16),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    if (item.promotions.isNotEmpty) ...[
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: item.promotions.map((promo) {
                                          final type = promo['type'] as String?;
                                          String label = '';
                                          if (type == 'SUBTRACT') {
                                            final base = promo['baseAmount'] ??
                                                promo['base_amount'];
                                            final add = promo['addAmount'] ??
                                                promo['add_amount'];
                                            label = 'Акция: ${base}+${add}';
                                          } else if (type == 'DISCOUNT') {
                                            final disc =
                                                (promo['discount'] as num?)
                                                        ?.toDouble() ??
                                                    0;
                                            label =
                                                'Скидка ${disc.toStringAsFixed(0)}%';
                                          }
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.red.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: Colors.red
                                                      .withOpacity(0.3),
                                                  width: 1),
                                            ),
                                            child: Text(
                                              label,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.red,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                      const SizedBox(height: 6),
                                    ],
                                    if (item.selectedVariants.isNotEmpty)
                                      Text(
                                        'Опции: ${item.selectedVariants.length}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    Text(
                                      '${item.price.toStringAsFixed(0)} ₸ за ${item.stepQuantity}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      'Всего: ${item.totalPrice.toStringAsFixed(0)} ₸',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    onPressed: () {
                                      // Вычисляем шаг изменения количества: parent_item_amount или stepQuantity
                                      double step = item.stepQuantity;
                                      for (var v in item.selectedVariants) {
                                        if (v.containsKey(
                                            'parent_item_amount')) {
                                          step =
                                              (v['parent_item_amount'] as num)
                                                  .toDouble();
                                          break;
                                        }
                                      }
                                      cartProvider.updateQuantityWithVariants(
                                        item.itemId,
                                        item.selectedVariants,
                                        item.quantity - step,
                                      );
                                    },
                                  ),
                                  Text(
                                    item.quantity.toStringAsFixed(2),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () {
                                      // Вычисляем шаг изменения количества: parent_item_amount или stepQuantity
                                      double step = item.stepQuantity;
                                      for (var v in item.selectedVariants) {
                                        if (v.containsKey(
                                            'parent_item_amount')) {
                                          step =
                                              (v['parent_item_amount'] as num)
                                                  .toDouble();
                                          break;
                                        }
                                      }
                                      cartProvider.updateQuantityWithVariants(
                                        item.itemId,
                                        item.selectedVariants,
                                        item.quantity + step,
                                      );
                                    },
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  cartProvider.removeItem(
                                    item.itemId,
                                    item.selectedVariants,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Сумма товаров:',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${cartProvider.getTotalPrice().toStringAsFixed(0)} ₸',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '* Стоимость доставки будет рассчитана на следующем шаге',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                      ),
                      onPressed: () async {
                        // Проверка авторизации перед оформлением
                        final loggedIn = await ApiService.isUserLoggedIn();
                        if (loggedIn) {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CheckoutPage(),
                              ));
                        } else {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginPage(),
                              ));
                        }
                      },
                      child: const Text('Оформить заказ'),
                    ),
                  ),
                ),
                SizedBox(height: 32),
              ],
            ),
    );
  }
}
