import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/item.dart' as ItemModel;
import '../utils/cart_provider.dart';
import '../models/cart_item.dart';
import '../widgets/item_options_dialog.dart';
import 'package:naliv_delivery/shared/app_theme.dart';

class ProductDetailPage extends StatelessWidget {
  final ItemModel.Item item;

  const ProductDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.text,
        title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.hasImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 1.3,
                        child: Image.network(
                          item.image!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.cardDark,
                            child: const Icon(Icons.image_not_supported, color: AppColors.textMute),
                          ),
                        ),
                      ),
                    ),
                  if (item.hasImage) const SizedBox(height: 20),
                  Text(item.name, style: const TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Text('${item.price.toStringAsFixed(2)} ₸',
                      style: const TextStyle(color: AppColors.orange, fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  if (item.code != null && item.code!.isNotEmpty) ...[
                    Text('Код товара: ${item.code}', style: TextStyle(color: AppColors.textMute, fontSize: 13)),
                    const SizedBox(height: 16),
                  ],
                  if (item.description != null && item.description!.isNotEmpty) ...[
                    Text(item.description!, style: const TextStyle(color: AppColors.text, fontSize: 14, height: 1.4)),
                    const SizedBox(height: 16),
                  ],
                  if (item.effectiveStepQuantity != 1.0) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: AppDecorations.card(radius: 12, color: AppColors.cardDark, shadow: false),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Товар продается с шагом ${item.effectiveStepQuantity} ${item.effectiveStepQuantity < 1 ? "кг" : "шт"}',
                              style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (item.hasPromotions) ...[
                    const Text('Акции', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    ...item.promotions!.map(
                      (p) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: AppDecorations.card(radius: 12, color: AppColors.cardDark, shadow: false),
                        child: Text(
                          p.name,
                          style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, -4)),
          ],
        ),
        child: Consumer<CartProvider>(
          builder: (context, cartProvider, child) {
            final totalQuantity = cartProvider.getTotalQuantityForItem(item.itemId);
            final isInCart = totalQuantity > 0;
            final double? maxAmount = item.amount?.toDouble();
            final bool canIncrease = maxAmount == null || totalQuantity < maxAmount;

            if (isInCart) {
              return Row(
                children: [
                  _squareButton(
                    icon: Icons.remove,
                    onPressed: () {
                      final variants = cartProvider.getItemVariants(item.itemId);
                      if (variants.isNotEmpty) {
                        final firstVariant = variants.first;
                        double step = firstVariant.stepQuantity;
                        for (var v in firstVariant.selectedVariants) {
                          if (v.containsKey('parent_item_amount')) {
                            step = (v['parent_item_amount'] as num).toDouble();
                            break;
                          }
                        }
                        cartProvider.updateQuantityWithVariants(
                          item.itemId,
                          firstVariant.selectedVariants,
                          (firstVariant.quantity - step).clamp(0, double.infinity),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.orange, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '${item.effectiveStepQuantity == 1.0 ? totalQuantity.toStringAsFixed(0) : totalQuantity.toStringAsFixed(2)} ${item.effectiveStepQuantity < 1 ? "кг" : "шт"}',
                          style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _squareButton(
                    icon: item.hasOptions ? Icons.settings : Icons.add,
                    onPressed: canIncrease
                        ? () {
                            if (item.hasOptions) {
                              showDialog(context: context, builder: (context) => ItemOptionsDialog(item: item));
                            } else {
                              final variants = cartProvider.getItemVariants(item.itemId);
                              if (variants.isNotEmpty) {
                                final firstVariant = variants.first;
                                double step = firstVariant.stepQuantity;
                                for (var v in firstVariant.selectedVariants) {
                                  if (v.containsKey('parent_item_amount')) {
                                    step = (v['parent_item_amount'] as num).toDouble();
                                    break;
                                  }
                                }
                                final target = firstVariant.quantity + step;
                                final newValue = maxAmount != null && target > maxAmount ? maxAmount : target;
                                cartProvider.updateQuantityWithVariants(
                                  item.itemId,
                                  firstVariant.selectedVariants,
                                  newValue,
                                );
                              }
                            }
                          }
                        : null,
                  ),
                ],
              );
            } else {
              return SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (maxAmount != null && maxAmount <= 0)
                      ? null
                      : () {
                          if (item.hasOptions) {
                            showDialog(context: context, builder: (context) => ItemOptionsDialog(item: item));
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
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: Icon(item.hasOptions ? Icons.tune : Icons.add_shopping_cart, size: 24),
                  label: Text(
                    item.hasOptions ? 'Выбрать опции' : 'Добавить в корзину',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _squareButton({required IconData icon, required VoidCallback? onPressed}) {
    return SizedBox(
      width: 48,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.black,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Icon(icon, size: 22),
      ),
    );
  }
}
