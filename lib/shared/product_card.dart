import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/item.dart' as ItemModel;
import '../utils/cart_provider.dart';
import '../models/cart_item.dart';
import '../widgets/item_options_dialog.dart';

class ProductCard extends StatelessWidget {
  final ItemModel.Item item;

  const ProductCard({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        // border: Border.all(
        //   color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        //   width: 1,
        // ),
        // boxShadow: [
        //   BoxShadow(
        //     color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
        //     blurRadius: 4,
        //     offset: const Offset(0, 2),
        //   ),
        // ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Квадратное изображение товара
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.0, // Квадратное соотношение
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .shadow
                            .withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.all(Radius.circular(15)),
                  ),
                  child: item.image != null && item.image!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(15)),
                          child: Image.network(
                            item.image!,
                            fit: BoxFit.fitHeight,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.inventory_2_outlined,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                size: 48,
                              );
                            },
                          ),
                        )
                      : Icon(
                          Icons.inventory_2_outlined,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 48,
                        ),
                ),
              ),
              AspectRatio(
                aspectRatio: 1.0, // Квадратное соотношение
                child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      boxShadow: [
                        // BoxShadow(
                        //   color: Theme.of(context)
                        //       .colorScheme
                        //       .shadow
                        //       .withValues(alpha: 0.1),
                        //   blurRadius: 4,
                        //   offset: const Offset(0, 2),
                        // ),
                      ],
                      // color:
                      //     Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: const BorderRadius.all(Radius.circular(15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Акции товара (если есть)
                        if (item.hasPromotions) ...[
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: item.promotions!.map((promo) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainer
                                    // color: Colors.red.withValues(alpha: 0.1),
                                    // borderRadius: BorderRadius.circular(8),
                                    // border: Border.all(
                                    //   color: Colors.red.withValues(alpha: 0.3),
                                    //   width: 1,
                                    // ),
                                    ),
                                child: Text(
                                  promo.description ?? promo.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 6),
                        ],
                        Spacer(),

                        // Опции товара (если есть)
                        if (item.hasOptions) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.tune,
                                  size: 12,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '+ опции (${item.options!.length})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                      ],
                    )),
              ),
            ],
          ),

          // Информация о товаре
          // Используем Flexible вместо Expanded для избежания ошибок ограничения высоты
          Flexible(
            fit: FlexFit.loose,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Название товара
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Описание товара (только если есть и нет акций/опций)
                  // if (item.description != null &&
                  //     item.description!.isNotEmpty &&
                  //     !item.hasPromotions &&
                  //     !item.hasOptions) ...[
                  //   Expanded(
                  //     child: Text(
                  //       item.description!,
                  //       style: TextStyle(
                  //         fontSize: 12,
                  //         color: Theme.of(context).colorScheme.onSurfaceVariant,
                  //       ),
                  //       maxLines: 2,
                  //       overflow: TextOverflow.ellipsis,
                  //     ),
                  //   ),
                  //   const SizedBox(height: 6),
                  // ],

                  // Spacer чтобы цена и кнопка были внизу
                  // if (!item.hasPromotions &&
                  //     !item.hasOptions &&
                  //     (item.description == null || item.description!.isEmpty))
                  //   const Spacer(),

                  // Цена товара

                  const SizedBox(height: 8),

                  Consumer<CartProvider>(
                    builder: (context, cartProvider, child) {
                      final totalQuantity =
                          cartProvider.getTotalQuantityForItem(item.itemId);
                      final isInCart = totalQuantity > 0;

                      if (isInCart) {
                        // Товар в корзине - показываем общее количество и кнопку управления
                        return Row(
                          children: [
                            // Кнопка уменьшения
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: ElevatedButton(
                                onPressed: () {
                                  final variants =
                                      cartProvider.getItemVariants(item.itemId);
                                  if (variants.isNotEmpty) {
                                    final firstVariant = variants.first;
                                    // Вычисляем шаг изменения количества: parent_item_amount или stepQuantity
                                    double step = firstVariant.stepQuantity;
                                    for (var v
                                        in firstVariant.selectedVariants) {
                                      if (v.containsKey('parent_item_amount')) {
                                        step = (v['parent_item_amount'] as num)
                                            .toDouble();
                                        break;
                                      }
                                    }
                                    // Уменьшаем на шаг
                                    cartProvider.updateQuantityWithVariants(
                                      item.itemId,
                                      firstVariant.selectedVariants,
                                      firstVariant.quantity - step,
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  foregroundColor:
                                      Theme.of(context).colorScheme.onPrimary,
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(32, 32),
                                ),
                                child: const Icon(Icons.remove, size: 16),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Показываем общее количество
                            Expanded(
                              child: Container(
                                height: 32,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Center(
                                  child: Text(
                                    '${totalQuantity.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Кнопка увеличения/настройки
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: ElevatedButton(
                                onPressed: () {
                                  if (item.hasOptions) {
                                    // Если есть опции, показываем диалог
                                    showDialog(
                                      context: context,
                                      builder: (context) =>
                                          ItemOptionsDialog(item: item),
                                    );
                                  } else {
                                    // Если нет опций, просто увеличиваем количество
                                    final variants = cartProvider
                                        .getItemVariants(item.itemId);
                                    if (variants.isNotEmpty) {
                                      final firstVariant = variants.first;
                                      // Вычисляем шаг изменения количества: parent_item_amount или stepQuantity
                                      double step = firstVariant.stepQuantity;
                                      for (var v
                                          in firstVariant.selectedVariants) {
                                        if (v.containsKey(
                                            'parent_item_amount')) {
                                          step =
                                              (v['parent_item_amount'] as num)
                                                  .toDouble();
                                          break;
                                        }
                                      }
                                      // Увеличиваем на шаг
                                      cartProvider.updateQuantityWithVariants(
                                        item.itemId,
                                        firstVariant.selectedVariants,
                                        firstVariant.quantity + step,
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  foregroundColor:
                                      Theme.of(context).colorScheme.onPrimary,
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(32, 32),
                                ),
                                child: Icon(
                                    item.hasOptions
                                        ? Icons.settings
                                        : Icons.add,
                                    size: 16),
                              ),
                            ),
                          ],
                        );
                      } else {
                        // Товар не в корзине - показываем кнопку добавления
                        return Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${item.price.toStringAsFixed(0)} ₸',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 32,
                              width: 32,
                              child: IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  foregroundColor:
                                      Theme.of(context).colorScheme.onPrimary,
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(32, 32),
                                ),
                                onPressed: () {
                                  if (item.hasOptions) {
                                    // Если есть опции, показываем диалог выбора
                                    showDialog(
                                      context: context,
                                      builder: (context) =>
                                          ItemOptionsDialog(item: item),
                                    );
                                  } else {
                                    // Если нет опций, добавляем сразу
                                    final newCartItem = CartItem(
                                      itemId: item.itemId,
                                      name: item.name,
                                      price: item.price,
                                      quantity: 1,
                                      stepQuantity: 1,
                                      selectedVariants: [],
                                      promotions: [],
                                    );
                                    cartProvider.addItem(newCartItem);
                                  }
                                },
                                icon: Icon(
                                  item.hasOptions
                                      ? Icons.tune
                                      : Icons.add_shopping_cart,
                                  size: 14,
                                ),
                                // label: Text(
                                //   item.hasOptions ? 'Выбрать' : 'В корзину',
                                //   style: const TextStyle(fontSize: 12),
                                // ),
                                // style: ElevatedButton.styleFrom(
                                //   backgroundColor:
                                //       Theme.of(context).colorScheme.primary,
                                //   foregroundColor:
                                //       Theme.of(context).colorScheme.onPrimary,
                                //   minimumSize: const Size(0, 32),
                                //   padding: const EdgeInsets.symmetric(
                                //     horizontal: 8,
                                //     vertical: 4,
                                //   ),
                                // ),
                              ),
                            )
                          ],
                        );
                      }
                    },
                  ),

                  // Код товара (если есть)
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
