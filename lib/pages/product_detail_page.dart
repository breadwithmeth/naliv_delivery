import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/item.dart' as ItemModel;
import '../utils/cart_provider.dart';
import '../models/cart_item.dart';
import '../widgets/item_options_dialog.dart';

class ProductDetailPage extends StatelessWidget {
  final ItemModel.Item item;

  const ProductDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Изображение
            if (item.hasImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 1.3,
                  child: Image.network(
                    item.image!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: theme.colorScheme.surfaceVariant,
                      child: Icon(Icons.image_not_supported,
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
            if (item.hasImage) const SizedBox(height: 20),

            // Название
            Text(
              item.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Цена
            Text(
              '${item.price.toStringAsFixed(2)} ₸',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // Код товара
            if (item.code != null && item.code!.isNotEmpty)
              Text(
                'Код товара: ${item.code}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (item.code != null && item.code!.isNotEmpty)
              const SizedBox(height: 16),

            // Описание
            if (item.description != null && item.description!.isNotEmpty) ...[
              Text(
                item.description!,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
            ],

            // Информация о шаге
            if (item.effectiveStepQuantity != 1.0) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Товар продается с шагом ${item.effectiveStepQuantity} ${item.effectiveStepQuantity < 1 ? "кг" : "шт"}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Промоакции
            if (item.hasPromotions) ...[
              Text('Акции', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ...item.promotions!.map(
                (p) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    p.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Заглушка под контент
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Consumer<CartProvider>(
          builder: (context, cartProvider, child) {
            final totalQuantity =
                cartProvider.getTotalQuantityForItem(item.itemId);
            final isInCart = totalQuantity > 0;
            final double? maxAmount = item.amount?.toDouble();
            final bool canIncrease =
                maxAmount == null || totalQuantity < maxAmount;

            if (isInCart) {
              return Row(
                children: [
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
                            (firstVariant.quantity - step)
                                .clamp(0, double.infinity),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Icon(Icons.remove, size: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.primary,
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
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: canIncrease
                          ? () {
                              if (item.hasOptions) {
                                showDialog(
                                  context: context,
                                  builder: (context) =>
                                      ItemOptionsDialog(item: item),
                                );
                              } else {
                                final variants =
                                    cartProvider.getItemVariants(item.itemId);
                                if (variants.isNotEmpty) {
                                  final firstVariant = variants.first;
                                  double step = firstVariant.stepQuantity;
                                  for (var v in firstVariant.selectedVariants) {
                                    if (v.containsKey('parent_item_amount')) {
                                      step = (v['parent_item_amount'] as num)
                                          .toDouble();
                                      break;
                                    }
                                  }
                                  final target = firstVariant.quantity + step;
                                  final newValue =
                                      maxAmount != null && target > maxAmount
                                          ? maxAmount
                                          : target;
                                  cartProvider.updateQuantityWithVariants(
                                    item.itemId,
                                    firstVariant.selectedVariants,
                                    newValue,
                                  );
                                }
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canIncrease
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceVariant,
                        foregroundColor: canIncrease
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant,
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
              return SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: (maxAmount != null && maxAmount <= 0)
                      ? null
                      : () {
                          if (item.hasOptions) {
                            showDialog(
                              context: context,
                              builder: (context) =>
                                  ItemOptionsDialog(item: item),
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
                              maxAmount: maxAmount,
                            );
                            cartProvider.addItem(newCartItem);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
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
