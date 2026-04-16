import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pages/cart_page.dart';
import '../utils/cart_provider.dart';
import '../utils/responsive.dart';

class CartFloatingButton extends StatelessWidget {
  const CartFloatingButton({Key? key}) : super(key: key);

  static const Color _orange = Color(0xFFF6A10C);

  void _openCart(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.9,
        child: const CartPage(),
      ),
    );
  }

  String _money(double v) {
    return v == v.roundToDouble() ? '${v.toInt()} ₸' : '${v.toStringAsFixed(0)} ₸';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        final itemCount = cart.displayItemCount;
        final total = cart.getTotalPrice();

        if (itemCount == 0) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => _openCart(context),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 10.s),
            decoration: BoxDecoration(
              color: _orange,
              borderRadius: BorderRadius.circular(16.s),
              boxShadow: [
                BoxShadow(
                  color: _orange.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Badge with count
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 7.s, vertical: 2.s),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8.s),
                  ),
                  child: Text(
                    '$itemCount',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(width: 8.s),
                Icon(Icons.shopping_cart_rounded, size: 18.s, color: Colors.black),
                SizedBox(width: 8.s),
                Text(
                  _money(total),
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
