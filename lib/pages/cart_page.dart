import 'package:flutter/material.dart';
import 'package:naliv_delivery/models/cart_item.dart';
import 'package:naliv_delivery/pages/checkout_page.dart';
import 'package:naliv_delivery/pages/login_page.dart';
import 'package:naliv_delivery/shared/app_theme.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:naliv_delivery/utils/responsive.dart';
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
                style: TextStyle(color: AppColors.textMute, fontSize: 11.sp, fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ),
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(14.s, 0, 14.s, 18.s),
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
            padding: EdgeInsets.symmetric(vertical: 10.s),
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(height: 12.s),
            itemBuilder: (context, index) => _cartItemTile(context, cartProvider, items[index]),
          ),
        ),
        SizedBox(height: 16.s),
        _summaryCard(total: total, deliveryFee: deliveryFee, etaLabel: etaLabel),
        SizedBox(height: 16.s),
        _checkoutButton(context),
        SizedBox(height: 12.s),
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

  /// Format quantity: show whole numbers without decimals
  static String _formatQty(double qty) {
    return (qty - qty.roundToDouble()).abs() < 0.001 ? qty.toStringAsFixed(0) : qty.toStringAsFixed(2);
  }

  /// Detect SUBTRACT promo and calculate free amount
  static double _freeAmount(CartItem item) {
    for (final promo in item.promotions) {
      final type = (promo['type'] as String?) ?? (promo['discount_type'] as String?);
      if (type == 'SUBTRACT') {
        final base = ((promo['baseAmount'] as num?) ?? (promo['base_amount'] as num?) ?? 0).toInt();
        final add = ((promo['addAmount'] as num?) ?? (promo['add_amount'] as num?) ?? 0).toInt();
        final groupSize = base + add;
        if (groupSize > 0 && base > 0 && item.quantity >= groupSize) {
          final count = item.quantity ~/ groupSize;
          return (count * add).toDouble();
        }
      }
    }
    return 0;
  }

  Widget _cartItemTile(BuildContext context, CartProvider cartProvider, CartItem item) {
    final double? maxAmount = item.maxAmount;
    final bool canIncrease = maxAmount == null || item.quantity < maxAmount;
    final bool canDecrease = item.quantity > 0;
    final double freeQty = _freeAmount(item);
    final bool hasFreeBonus = freeQty > 0;
    final double rawTotal = item.price * item.quantity;
    final double actualTotal = item.totalPrice;

    return Container(
      padding: EdgeInsets.all(10.s),
      decoration: BoxDecoration(
        color: AppColors.cardDark.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16.s),
        border: Border.all(color: hasFreeBonus ? AppColors.orange.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          _itemThumb(item),
          SizedBox(width: 10.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.text, fontSize: 14.sp, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 5.s),
                if (hasFreeBonus) ...[
                  // Show strikethrough raw price + actual price
                  Row(
                    children: [
                      Text(
                        _money(rawTotal),
                        style: TextStyle(
                          color: AppColors.textMute.withValues(alpha: 0.5),
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: AppColors.textMute.withValues(alpha: 0.5),
                        ),
                      ),
                      SizedBox(width: 6.s),
                      Text(
                        _money(actualTotal),
                        style: TextStyle(color: AppColors.orange, fontSize: 13.sp, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  SizedBox(height: 3.s),
                  // Free bonus badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.s, vertical: 2.s),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6.s),
                    ),
                    child: Text(
                      '${_formatQty(freeQty)} л в подарок 🎁',
                      style: TextStyle(color: AppColors.orange, fontSize: 10.sp, fontWeight: FontWeight.w700),
                    ),
                  ),
                ] else ...[
                  Text(
                    _money(actualTotal),
                    style: TextStyle(color: AppColors.orange, fontSize: 12.sp, fontWeight: FontWeight.w700),
                  ),
                ],
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
            value: _formatQty(item.quantity),
          ),
        ],
      ),
    );
  }

  Widget _itemThumb(CartItem item) {
    return Container(
      width: 52.s,
      height: 52.s,
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
      padding: EdgeInsets.symmetric(horizontal: 9.s, vertical: 7.s),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(26.s),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _quantityButton(icon: Icons.remove, onPressed: onDecrement, filled: false),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.s),
            child: Text(value, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 13.sp)),
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
      borderRadius: BorderRadius.circular(16.s),
      child: Container(
        width: 30.s,
        height: 30.s,
        decoration: BoxDecoration(
          color: onPressed == null ? bg.withValues(alpha: 0.5) : bg,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Icon(icon, size: 16.s, color: fg.withValues(alpha: onPressed == null ? 0.5 : 1)),
      ),
    );
  }

  Widget _summaryCard({required double total, required double deliveryFee, required String etaLabel}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.s),
      decoration: BoxDecoration(
        color: AppColors.cardDark.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18.s),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.32), blurRadius: 20, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: AppColors.orange, size: 20.s),
              SizedBox(width: 7.s),
              Text('Детали заказа', style: TextStyle(color: AppColors.text, fontSize: 15.sp, fontWeight: FontWeight.w800)),
            ],
          ),
          SizedBox(height: 12.s),
          _summaryRow('Сумма товаров', _money(total)),
          SizedBox(height: 9.s),
          _summaryRow('Доставка', deliveryFee > 0 ? _money(deliveryFee) : '—'),
          SizedBox(height: 9.s),
          _etaRow('Время доставки', etaLabel),
          SizedBox(height: 14.s),
          Divider(color: Colors.white.withValues(alpha: 0.07)),
          SizedBox(height: 10.s),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ИТОГО', style: TextStyle(color: AppColors.text, fontSize: 15.sp, fontWeight: FontWeight.w800)),
              Text(_money(total + deliveryFee), style: TextStyle(color: AppColors.orange, fontSize: 18.sp, fontWeight: FontWeight.w900)),
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
        Text(label, style: TextStyle(color: AppColors.textMute, fontSize: 12.sp)),
        Text(value, style: TextStyle(color: AppColors.text, fontSize: 13.sp, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _etaRow(String label, String eta) {
    return Row(
      children: [
        Icon(Icons.access_time, color: AppColors.textMute, size: 16.s),
        SizedBox(width: 7.s),
        Expanded(child: Text(label, style: TextStyle(color: AppColors.textMute, fontSize: 12.sp))),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 9.s, vertical: 5.s),
          decoration: AppDecorations.pill(color: AppColors.orange.withValues(alpha: 0.15)),
          child: Text(eta, style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w800, fontSize: 11.sp)),
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
        padding: EdgeInsets.symmetric(vertical: 14.s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(23.s),
          gradient: const LinearGradient(colors: [Color(0xFF8B1F1E), AppColors.red]),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 10)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.credit_card, color: Colors.white, size: 16.s),
            SizedBox(width: 9.s),
            Text('Оформить заказ', style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w800)),
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
