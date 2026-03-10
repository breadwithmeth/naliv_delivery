import 'package:flutter/material.dart';
import 'package:naliv_delivery/models/cart_item.dart';
import 'package:naliv_delivery/pages/checkout_page.dart';
import 'package:naliv_delivery/pages/login_page.dart';
import 'package:naliv_delivery/shared/app_theme.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:provider/provider.dart';
import '../utils/cart_provider.dart';

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
        centerTitle: true,
        foregroundColor: AppColors.text,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: items.isEmpty ? _buildEmptyState() : _buildFilled(context, cartProvider, items),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilled(BuildContext context, CartProvider cartProvider, List<CartItem> items) {
    final total = cartProvider.getTotalPrice();
    const double deliveryFee = 0; // нет данных для доставки, показываем заглушку
    const String etaLabel = '~30 мин';

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) => _cartItemTile(context, cartProvider, items[index]),
          ),
        ),
        const SizedBox(height: 18),
        _summaryCard(total: total, deliveryFee: deliveryFee, etaLabel: etaLabel),
        const SizedBox(height: 18),
        _checkoutButton(context),
        const SizedBox(height: 14),
        _footerBadge(),
      ],
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

  Widget _cartItemTile(BuildContext context, CartProvider cartProvider, CartItem item) {
    final double? maxAmount = item.maxAmount;
    final bool canIncrease = maxAmount == null || item.quantity < maxAmount;
    final bool canDecrease = item.quantity > 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardDark.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          _itemThumb(item),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  '${item.price.toStringAsFixed(0)} ₸',
                  style: const TextStyle(color: AppColors.orange, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _quantityCapsule(
            onDecrement: canDecrease
                ? () {
                    double step = item.stepQuantity;
                    for (var v in item.selectedVariants) {
                      if (v.containsKey('parent_item_amount')) {
                        step = (v['parent_item_amount'] as num).toDouble();
                        break;
                      }
                    }
                    cartProvider.updateQuantityWithVariants(item.itemId, item.selectedVariants, item.quantity - step);
                  }
                : null,
            onIncrement: canIncrease
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
                    cartProvider.updateQuantityWithVariants(item.itemId, item.selectedVariants, newValue);
                  }
                : null,
            value: item.quantity.toStringAsFixed(item.stepQuantity == 1 ? 0 : 2),
          ),
        ],
      ),
    );
  }

  Widget _itemThumb(CartItem item) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ClipOval(
        child: item.image != null && item.image!.isNotEmpty
            ? Image.network(
                item.image!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(Icons.inventory_2_outlined, color: AppColors.textMute.withValues(alpha: 0.8)),
              )
            : Icon(Icons.inventory_2_outlined, color: AppColors.textMute.withValues(alpha: 0.8)),
      ),
    );
  }

  Widget _quantityCapsule({required VoidCallback? onDecrement, required VoidCallback? onIncrement, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _quantityButton(icon: Icons.remove, onPressed: onDecrement, filled: false),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(value, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
          ),
          _quantityButton(icon: Icons.add, onPressed: onIncrement, filled: true),
        ],
      ),
    );
  }

  Widget _quantityButton({required IconData icon, required VoidCallback? onPressed, required bool filled}) {
    final Color bg = filled ? AppColors.orange : AppColors.bgDeep;
    final Color fg = filled ? Colors.black : AppColors.text;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: onPressed == null ? bg.withValues(alpha: 0.5) : bg,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Icon(icon, size: 18, color: fg.withValues(alpha: onPressed == null ? 0.5 : 1)),
      ),
    );
  }

  Widget _summaryCard({required double total, required double deliveryFee, required String etaLabel}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.32), blurRadius: 20, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.receipt_long, color: AppColors.orange),
              SizedBox(width: 8),
              Text('Детали заказа', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          _summaryRow('Сумма товаров', _money(total)),
          const SizedBox(height: 10),
          _summaryRow('Доставка', deliveryFee > 0 ? _money(deliveryFee) : '—'),
          const SizedBox(height: 10),
          _etaRow('Время доставки', etaLabel),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.07)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ИТОГО', style: TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w800)),
              Text(_money(total + deliveryFee), style: const TextStyle(color: AppColors.orange, fontSize: 20, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMute, fontSize: 13)),
        Text(value, style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _etaRow(String label, String eta) {
    return Row(
      children: [
        const Icon(Icons.access_time, color: AppColors.textMute, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(color: AppColors.textMute, fontSize: 13))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: AppDecorations.pill(color: AppColors.orange.withValues(alpha: 0.15)),
          child: Text(eta, style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w800, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _checkoutButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final loggedIn = await ApiService.isUserLoggedIn();
        if (loggedIn) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const CheckoutPage()));
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage()));
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(colors: [Color(0xFF8B1F1E), AppColors.red]),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 10)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.credit_card, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('Оформить заказ', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _footerBadge() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        SizedBox(height: 4),
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.transparent,
          child: CircleAvatar(
            radius: 22,
            backgroundColor: Colors.black,
            child: Text('24', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w800)),
          ),
        ),
        SizedBox(height: 10),
        Text('ВСЕГДА В ВАШЕМ КРУГУ', style: TextStyle(color: AppColors.orange, fontSize: 11, fontWeight: FontWeight.w800)),
        SizedBox(height: 4),
        Text('ӘРҚАШАН СІЗДІҢ АРАҢЫЗДА', style: TextStyle(color: AppColors.textMute, fontSize: 10, fontWeight: FontWeight.w700)),
      ],
    );
  }

  static String _money(double value) => '${value.toStringAsFixed(0)} ₸';
}
