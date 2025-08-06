import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/item.dart' as ItemModel;
import '../utils/cart_provider.dart';
import '../models/cart_item.dart';
import '../widgets/item_options_dialog.dart';

class ProductDetailPage extends StatelessWidget {
  final ItemModel.Item item;

  const ProductDetailPage({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Изображение товара
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: item.image != null && item.image!.isNotEmpty
                  ? Image.network(
                      item.image!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            Icons.inventory_2_outlined,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            size: 80,
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 80,
                      ),
                    ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Название товара
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Цена
                  Text(
                    '${item.price.toStringAsFixed(0)} ₸',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Акции (если есть)
                  if (item.hasPromotions) ...[
                    const Text(
                      'Акции и предложения',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: item.promotions!.map((promo) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            promo.description ?? promo.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Опции (если есть)
                  if (item.hasOptions) ...[
                    const Text(
                      'Доступные опции',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.tune,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Доступно ${item.options!.length} ${item.options!.length == 1 ? "опция" : "опций"}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Описание товара (если есть)
                  if (item.description != null &&
                      item.description!.isNotEmpty) ...[
                    const Text(
                      'Описание',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.description!,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Код товара (если есть)
                  if (item.code != null && item.code!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.qr_code,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Код товара: ${item.code}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Информация о stepQuantity
                  if (item.effectiveStepQuantity != 1.0) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Товар продается с шагом ${item.effectiveStepQuantity} ${item.effectiveStepQuantity < 1 ? "кг" : "шт"}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ] else
                    const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Consumer<CartProvider>(
          builder: (context, cartProvider, child) {
            final totalQuantity =
                cartProvider.getTotalQuantityForItem(item.itemId);
            final isInCart = totalQuantity > 0;

            if (isInCart) {
              // Товар в корзине - показываем управление количеством
              return Row(
                children: [
                  // Кнопка уменьшения
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        final variants =
                            cartProvider.getItemVariants(item.itemId);
                        if (variants.isNotEmpty) {
                          final firstVariant = variants.first;
                          double step = firstVariant.stepQuantity;
                          for (var v in firstVariant.selectedVariants) {
                            if (v.containsKey('parent_item_amount')) {
                              step =
                                  (v['parent_item_amount'] as num).toDouble();
                              break;
                            }
                          }
                          cartProvider.updateQuantityWithVariants(
                            item.itemId,
                            firstVariant.selectedVariants,
                            firstVariant.quantity - step,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Icon(Icons.remove, size: 24),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Количество
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${item.effectiveStepQuantity == 1.0 ? totalQuantity.toStringAsFixed(0) : totalQuantity.toStringAsFixed(2)} ${item.effectiveStepQuantity < 1 ? "кг" : "шт"}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Кнопка увеличения/настройки
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        if (item.hasOptions) {
                          showDialog(
                            context: context,
                            builder: (context) => ItemOptionsDialog(item: item),
                          );
                        } else {
                          final variants =
                              cartProvider.getItemVariants(item.itemId);
                          if (variants.isNotEmpty) {
                            final firstVariant = variants.first;
                            double step = firstVariant.stepQuantity;
                            for (var v in firstVariant.selectedVariants) {
                              if (v.containsKey('parent_item_amount')) {
                                step =
                                    (v['parent_item_amount'] as num).toDouble();
                                break;
                              }
                            }
                            cartProvider.updateQuantityWithVariants(
                              item.itemId,
                              firstVariant.selectedVariants,
                              firstVariant.quantity + step,
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Icon(
                        item.hasOptions ? Icons.settings : Icons.add,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              );
            } else {
              // Товар не в корзине - показываем кнопку добавления
              return SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (item.hasOptions) {
                      showDialog(
                        context: context,
                        builder: (context) => ItemOptionsDialog(item: item),
                      );
                    } else {
                      final stepQuantity = item.effectiveStepQuantity;
                      final newCartItem = CartItem(
                        itemId: item.itemId,
                        name: item.name,
                        price: item.price,
                        quantity: stepQuantity,
                        stepQuantity: stepQuantity,
                        selectedVariants: [],
                        promotions: [],
                      );
                      cartProvider.addItem(newCartItem);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: Icon(
                    item.hasOptions ? Icons.tune : Icons.add_shopping_cart,
                    size: 24,
                  ),
                  label: Text(
                    item.hasOptions ? 'Выбрать опции' : 'Добавить в корзину',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
