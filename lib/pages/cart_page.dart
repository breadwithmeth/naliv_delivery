import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/checkout_page.dart';
import 'package:naliv_delivery/pages/login_page.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:provider/provider.dart';
import '../utils/cart_provider.dart';
import 'package:naliv_delivery/shared/app_theme.dart';

class CartPage extends StatelessWidget {
  static const routeName = '/cart';

  const CartPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final businessProvider = Provider.of<BusinessProvider>(context);
    final items = cartProvider.items;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.text,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Корзина', style: TextStyle(fontWeight: FontWeight.w800)),
            if (businessProvider.selectedBusinessName != null)
              Text(
                businessProvider.selectedBusiness != null
                    ? '${businessProvider.selectedBusiness!["name"].toString()} — ${businessProvider.selectedBusiness!["address"].toString()}'
                    : 'Выберите магазин',
                style: TextStyle(color: AppColors.textMute, fontSize: 12, fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ),
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
              child: items.isEmpty
                  ? _buildEmptyState()
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final double? maxAmount = item.maxAmount;
                              final bool canIncrease = maxAmount == null || item.quantity < maxAmount;
                              final bool canDecrease = item.quantity > 0;
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.all(14),
                                decoration: AppDecorations.card(),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w800),
                                          ),
                                          if (item.promotions.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: item.promotions.map((promo) {
                                                final type = promo['type'] as String?;
                                                String label = '';
                                                if (type == 'SUBTRACT') {
                                                  final base = promo['baseAmount'] ?? promo['base_amount'];
                                                  final add = promo['addAmount'] ?? promo['add_amount'];
                                                  label = 'Акция: ${base}+${add}';
                                                } else if (type == 'DISCOUNT') {
                                                  final disc = (promo['discount'] as num?)?.toDouble() ?? 0;
                                                  label = 'Скидка ${disc.toStringAsFixed(0)}%';
                                                }
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.red.withValues(alpha: 0.14),
                                                    borderRadius: BorderRadius.circular(10),
                                                    border: Border.all(color: AppColors.red.withValues(alpha: 0.4), width: 1),
                                                  ),
                                                  child: Text(
                                                    label,
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.red),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ],
                                          if (item.selectedVariants.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              'Опции: ${item.selectedVariants.length}',
                                              style: TextStyle(color: AppColors.textMute, fontSize: 12, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                          const SizedBox(height: 6),
                                          Text(
                                            '${item.price.toStringAsFixed(0)} ₸ за ${item.stepQuantity}',
                                            style: TextStyle(color: AppColors.textMute, fontSize: 12),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Всего: ${item.totalPrice.toStringAsFixed(0)} ₸',
                                            style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _quantityButton(
                                              icon: Icons.remove,
                                              onPressed: canDecrease
                                                  ? () {
                                                      double step = item.stepQuantity;
                                                      for (var v in item.selectedVariants) {
                                                        if (v.containsKey('parent_item_amount')) {
                                                          step = (v['parent_item_amount'] as num).toDouble();
                                                          break;
                                                        }
                                                      }
                                                      cartProvider.updateQuantityWithVariants(
                                                        item.itemId,
                                                        item.selectedVariants,
                                                        item.quantity - step,
                                                      );
                                                    }
                                                  : null,
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              child: Text(
                                                item.quantity.toStringAsFixed(2),
                                                style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                            _quantityButton(
                                              icon: Icons.add,
                                              onPressed: canIncrease
                                                  ? () {
                                                      double step = item.stepQuantity;
                                                      for (var v in item.selectedVariants) {
                                                        if (v.containsKey('parent_item_amount')) {
                                                          step = (v['parent_item_amount'] as num).toDouble();
                                                          break;
                                                        }
                                                      }
                                                      final target = item.quantity + step;
                                                      final newValue = maxAmount != null && target > maxAmount ? maxAmount : target;
                                                      cartProvider.updateQuantityWithVariants(
                                                        item.itemId,
                                                        item.selectedVariants,
                                                        newValue,
                                                      );
                                                    }
                                                  : null,
                                            ),
                                          ],
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: AppColors.textMute),
                                          onPressed: () {
                                            cartProvider.removeItem(
                                              item.itemId,
                                              item.selectedVariants,
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: AppDecorations.card(radius: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Сумма товаров', style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800)),
                                  Text(
                                    '${cartProvider.getTotalPrice().toStringAsFixed(0)} ₸',
                                    style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '* Стоимость доставки будет рассчитана на следующем шаге',
                                style: TextStyle(color: AppColors.textMute, fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    backgroundColor: AppColors.orange,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  onPressed: () async {
                                    final loggedIn = await ApiService.isUserLoggedIn();
                                    if (loggedIn) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const CheckoutPage()),
                                      );
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const LoginPage()),
                                      );
                                    }
                                  },
                                  child: const Text('Оформить заказ', style: TextStyle(fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.shopping_cart_outlined, color: AppColors.textMute, size: 52),
          SizedBox(height: 12),
          Text('Ваша корзина пуста', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _quantityButton({required IconData icon, required VoidCallback? onPressed}) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: AppColors.text),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.blue,
        disabledBackgroundColor: AppColors.blue.withValues(alpha: 0.4),
        padding: const EdgeInsets.all(8),
        minimumSize: const Size(36, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
