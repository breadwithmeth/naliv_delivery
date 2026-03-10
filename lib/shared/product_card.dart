import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/item.dart' as ItemModel;
import '../utils/cart_provider.dart';
import '../models/cart_item.dart';
import '../widgets/item_options_dialog.dart';
import '../pages/product_detail_page.dart';
import '../utils/api.dart';
import '../utils/liked_storage_service.dart';
import '../utils/business_provider.dart';
import '../utils/liked_items_provider.dart';
import 'package:naliv_delivery/shared/app_theme.dart';

class ProductCard extends StatefulWidget {
  final ItemModel.Item item;

  const ProductCard({super.key, required this.item});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _likeInProgress = false;
  bool? _isLikedOverride; // локальное переопределение если изменили

  int? _businessId;

  bool get _isLiked => _isLikedOverride ?? false; // локальное состояние

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Получаем текущий бизнес (если есть)
    final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
    final bid = businessProvider.selectedBusinessId;
    if (bid != null && bid != _businessId) {
      _businessId = bid;
      _initLikeState(bid);
    }
  }

  Future<void> _initLikeState(int businessId) async {
    // Сначала пробуем из провайдера
    final likedProvider = Provider.of<LikedItemsProvider>(context, listen: false);
    final providerLiked = likedProvider.isLiked(businessId, widget.item.itemId);
    if (providerLiked) {
      _isLikedOverride = true;
      setState(() {});
      return; // уже знаем
    }
    // Иначе грузим из локального хранилища
    final liked = await LikedStorageService.isLiked(
      businessId: businessId,
      itemId: widget.item.itemId,
    );
    if (mounted) {
      setState(() {
        _isLikedOverride = liked;
      });
      if (liked) {
        likedProvider.updateLike(businessId, widget.item.itemId, true);
      }
    }
  }

  Future<void> _toggleLike() async {
    if (_likeInProgress) return;
    setState(() => _likeInProgress = true);
    try {
      final newValue = await ApiService.toggleLikeItem(widget.item.itemId);
      if (newValue != null) {
        setState(() {
          _isLikedOverride = newValue;
        });
        if (_businessId != null) {
          // Сохраняем в SharedPreferences
          LikedStorageService.setLiked(
            businessId: _businessId!,
            itemId: widget.item.itemId,
            liked: newValue,
          );
          // Обновляем провайдер
          final likedProvider = Provider.of<LikedItemsProvider>(context, listen: false);
          likedProvider.updateLike(_businessId!, widget.item.itemId, newValue);
        }
      }
    } finally {
      if (mounted) setState(() => _likeInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return GestureDetector(
      child: Container(
        decoration: AppDecorations.card(radius: 16),
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
                      color: AppColors.cardDark,
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
                                  color: AppColors.textMute,
                                  size: 48,
                                );
                              },
                            ),
                          )
                        : Icon(
                            Icons.inventory_2_outlined,
                            color: AppColors.textMute,
                            size: 48,
                          ),
                  ),
                ),
                AspectRatio(
                  aspectRatio: 1.0,
                  child: Stack(
                    children: [
                      // Overlay content (promos + options + like)
                      Positioned.fill(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(15)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
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
                                                  color: AppColors.card,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  promo.description ?? promo.name,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.text,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: _toggleLike,
                                    child: AnimatedOpacity(
                                      duration: const Duration(milliseconds: 150),
                                      opacity: _likeInProgress ? 0.5 : 1,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: AppColors.cardDark.withValues(alpha: 0.7),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _isLiked ? Icons.favorite : Icons.favorite_border,
                                          size: 18,
                                          color: _isLiked ? AppColors.orange : AppColors.textMute,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              if (item.hasOptions) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.card,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.tune,
                                        size: 12,
                                        color: AppColors.text,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '+ опции (${item.options!.length})',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.text,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
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
                        color: AppColors.text,
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
                        final totalQuantity = cartProvider.getTotalQuantityForItem(item.itemId);
                        final isInCart = totalQuantity > 0;
                        final num? maxAmount = item.amount;
                        final bool canIncrease = maxAmount == null || totalQuantity < maxAmount.toDouble();

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
                                    final variants = cartProvider.getItemVariants(item.itemId);
                                    if (variants.isNotEmpty) {
                                      final firstVariant = variants.first;
                                      // Вычисляем шаг изменения количества: parent_item_amount или stepQuantity
                                      double step = firstVariant.stepQuantity;
                                      for (var v in firstVariant.selectedVariants) {
                                        if (v.containsKey('parent_item_amount')) {
                                          step = (v['parent_item_amount'] as num).toDouble();
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
                                    backgroundColor: AppColors.orange,
                                    foregroundColor: Colors.black,
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
                                    border: Border.all(color: AppColors.orange),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${item.effectiveStepQuantity == 1.0 ? totalQuantity.toStringAsFixed(0) : totalQuantity.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.orange,
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
                                  onPressed: canIncrease
                                      ? () {
                                          if (item.hasOptions) {
                                            showDialog(
                                              context: context,
                                              builder: (context) => ItemOptionsDialog(item: item),
                                            );
                                          } else {
                                            final variants = cartProvider.getItemVariants(item.itemId);
                                            if (variants.isNotEmpty) {
                                              final firstVariant = variants.first;
                                              double step = firstVariant.stepQuantity; // базовый шаг
                                              for (var v in firstVariant.selectedVariants) {
                                                if (v.containsKey('parent_item_amount')) {
                                                  step = (v['parent_item_amount'] as num).toDouble();
                                                  break;
                                                }
                                              }
                                              // Если после увеличения превысим лимит – ограничим до максимума
                                              final target = firstVariant.quantity + step;
                                              if (maxAmount != null && target > maxAmount.toDouble()) {
                                                // ставим максимум
                                                cartProvider.updateQuantityWithVariants(
                                                  item.itemId,
                                                  firstVariant.selectedVariants,
                                                  maxAmount.toDouble(),
                                                );
                                              } else {
                                                cartProvider.updateQuantityWithVariants(
                                                  item.itemId,
                                                  firstVariant.selectedVariants,
                                                  target,
                                                );
                                              }
                                            }
                                          }
                                        }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: canIncrease ? AppColors.orange : AppColors.cardDark,
                                    foregroundColor: canIncrease ? Colors.black : AppColors.textMute,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(32, 32),
                                  ),
                                  child: Icon(
                                    item.hasOptions ? Icons.settings : Icons.add,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          );
                        } else {
                          // Товар не в корзине - показываем кнопку добавления
                          final bool canAdd = (maxAmount == null || maxAmount.toDouble() > 0);
                          return Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.price.toStringAsFixed(0)} ₸',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.orange,
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 32,
                                width: 32,
                                child: IconButton(
                                  style: IconButton.styleFrom(
                                    backgroundColor: canAdd ? AppColors.orange : AppColors.cardDark,
                                    foregroundColor: canAdd ? Colors.black : AppColors.textMute,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(32, 32),
                                  ),
                                  onPressed: canAdd
                                      ? () {
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
                                              maxAmount: item.amount?.toDouble(),
                                            );
                                            cartProvider.addItem(newCartItem);
                                          }
                                        }
                                      : null,
                                  icon: Icon(
                                    item.hasOptions ? Icons.tune : Icons.add_shopping_cart,
                                    size: 14,
                                  ),
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
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(item: item),
          ),
        );
      },
    );
  }
}
