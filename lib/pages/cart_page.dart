import 'package:flutter/material.dart';
import 'package:gradusy24/models/cart_item.dart';
import 'package:gradusy24/pages/bonus_info_page.dart';
import 'package:gradusy24/pages/checkout_page.dart';
import 'package:gradusy24/pages/login_page.dart';
import 'package:gradusy24/shared/app_theme.dart';
import 'package:gradusy24/utils/api.dart';
import 'package:gradusy24/utils/business_provider.dart';
import 'package:gradusy24/utils/bonus_rules.dart';
import 'package:gradusy24/utils/responsive.dart';
import 'package:provider/provider.dart';
import '../utils/cart_provider.dart';

class CartPage extends StatelessWidget {
  static const routeName = '/cart';

  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final businessProvider = Provider.of<BusinessProvider>(context);
    final items = cartProvider.items;
    final total = cartProvider.getTotalPrice();
    final earnedBonuses = BonusRules.calculateEarnedBonusesForCartItems(items);

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
          children: [
            Text('Корзина', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.sp)),
            if (businessProvider.selectedBusinessName != null)
              Text(
                businessProvider.selectedBusiness != null
                    ? '${businessProvider.selectedBusiness!["name"]} — ${businessProvider.selectedBusiness!["address"]}'
                    : 'Выберите магазин',
                style: TextStyle(color: AppColors.textMute, fontSize: 11.sp, fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ),
      bottomNavigationBar: items.isNotEmpty ? _bottomBar(context, total, earnedBonuses) : null,
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: items.isEmpty ? _buildEmptyState() : _buildList(context, cartProvider, items, total, earnedBonuses),
          ),
        ],
      ),
    );
  }

  // ── Filled state ──────────────────────────────────────────────────

  Widget _buildList(BuildContext context, CartProvider cartProvider, List<CartItem> items, double total, int earnedBonuses) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.s, 4.s, 16.s, 100.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(color: Colors.white.withValues(alpha: 0.05), height: 20.s),
            _cartItemRow(context, cartProvider, items[i]),
          ],
          _thinDivider(),
          _summaryRow('Товары', _money(total)),
          if (earnedBonuses > 0) ...[
            SizedBox(height: 6.s),
            _summaryRow('Бонусы за заказ', '+$earnedBonuses ₸', valueColor: Colors.greenAccent),
          ],
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 20.s),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Итого', style: TextStyle(color: AppColors.text, fontSize: 16.sp, fontWeight: FontWeight.w800)),
              Text(_money(total), style: TextStyle(color: AppColors.orange, fontSize: 18.sp, fontWeight: FontWeight.w900)),
            ],
          ),
          if (earnedBonuses > 0) ...[
            SizedBox(height: 10.s),
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BonusInfoPage())),
              child: Row(
                children: [
                  Icon(Icons.stars_rounded, color: AppColors.orange, size: 14.s),
                  SizedBox(width: 6.s),
                  Text('Как работают бонусы →', style: TextStyle(color: AppColors.orange, fontSize: 12.sp, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, color: AppColors.textMute, size: 52),
          SizedBox(height: 12),
          Text('Ваша корзина пуста', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ── Cart item (flat row) ──────────────────────────────────────────

  Widget _cartItemRow(BuildContext context, CartProvider cartProvider, CartItem item) {
    final double? maxAmount = item.maxAmount;
    final bool canIncrease = maxAmount == null || item.quantity < maxAmount;
    final bool canDecrease = item.quantity > 0;
    final double freeQty = _freeAmount(item);
    final bool hasFree = freeQty > 0;
    final double rawTotal = item.subtotalBeforePromotions;
    final bool hasSavings = item.totalPrice < rawTotal - 0.001;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _itemThumb(item),
        SizedBox(width: 10.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.text, fontSize: 14.sp, fontWeight: FontWeight.w800)),
              SizedBox(height: 4.s),
              if (hasSavings) ...[
                Row(
                  children: [
                    Text(_money(rawTotal),
                        style: TextStyle(
                            color: AppColors.textMute.withValues(alpha: 0.5),
                            fontSize: 11.sp,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: AppColors.textMute.withValues(alpha: 0.5))),
                    SizedBox(width: 6.s),
                    Text(_money(item.totalPrice), style: TextStyle(color: AppColors.orange, fontSize: 13.sp, fontWeight: FontWeight.w800)),
                  ],
                ),
                if (hasFree) ...[
                  SizedBox(height: 2.s),
                  Text('+ ${_formatQty(freeQty)} в подарок', style: TextStyle(color: AppColors.orange, fontSize: 11.sp, fontWeight: FontWeight.w600)),
                ],
              ] else
                Text(_money(item.totalPrice), style: TextStyle(color: AppColors.orange, fontSize: 13.sp, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        SizedBox(width: 8.s),
        _quantityControls(
          value: _formatQty(item.quantity),
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
        ),
      ],
    );
  }

  Widget _itemThumb(CartItem item) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10.s),
      child: SizedBox(
        width: 44.s,
        height: 44.s,
        child: item.image != null && item.image!.isNotEmpty
            ? Image.network(item.image!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(Icons.inventory_2_outlined, color: AppColors.textMute.withValues(alpha: 0.6), size: 22.s))
            : Icon(Icons.inventory_2_outlined, color: AppColors.textMute.withValues(alpha: 0.6), size: 22.s),
      ),
    );
  }

  // ── Quantity controls (lighter capsule) ───────────────────────────

  Widget _quantityControls({
    required String value,
    required VoidCallback? onDecrement,
    required VoidCallback? onIncrement,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _qtyBtn(Icons.remove, onDecrement, false),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.s),
          child: Text(value, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 13.sp)),
        ),
        _qtyBtn(Icons.add, onIncrement, true),
      ],
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback? onPressed, bool filled) {
    final Color bg = filled ? AppColors.orange : AppColors.card;
    final Color fg = filled ? Colors.black : AppColors.text;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 28.s,
        height: 28.s,
        decoration: BoxDecoration(
          color: onPressed == null ? bg.withValues(alpha: 0.4) : bg,
          borderRadius: BorderRadius.circular(10.s),
        ),
        child: Icon(icon, size: 15.s, color: fg.withValues(alpha: onPressed == null ? 0.4 : 1)),
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────

  Widget _thinDivider() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14.s),
      child: Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
    );
  }

  Widget _summaryRow(String label, String value, {Color valueColor = AppColors.text}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textMute, fontSize: 12.sp)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 13.sp, fontWeight: FontWeight.w700)),
      ],
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────

  Widget _bottomBar(BuildContext context, double total, int earnedBonuses) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.s, 10.s, 16.s, 10.s),
      decoration: BoxDecoration(
        color: AppColors.bgDeep,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_money(total), style: TextStyle(color: AppColors.text, fontSize: 20.sp, fontWeight: FontWeight.w900)),
                if (earnedBonuses > 0)
                  Text('+$earnedBonuses ₸ бонусов', style: TextStyle(color: AppColors.textMute, fontSize: 11.sp, fontWeight: FontWeight.w600)),
              ],
            ),
            SizedBox(width: 14.s),
            Expanded(
              child: _primaryButton(
                context: context,
                label: 'Оформить',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton({required BuildContext context, required String label}) {
    return GestureDetector(
      onTap: () async {
        final loggedIn = await ApiService.isUserLoggedIn();
        if (!context.mounted) return;
        if (loggedIn) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutPage()));
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
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
            Icon(Icons.arrow_forward, color: Colors.white, size: 16.s),
            SizedBox(width: 9.s),
            Text(label, style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  // ── Utils ─────────────────────────────────────────────────────────

  static String _formatQty(double qty) {
    return (qty - qty.roundToDouble()).abs() < 0.001 ? qty.toStringAsFixed(0) : qty.toStringAsFixed(2);
  }

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

  static String _money(double value) => '${value.toStringAsFixed(0)} ₸';
}
