import 'package:flutter/material.dart';
import '../pages/cart_page.dart';

class CartFloatingButton extends StatelessWidget {
  const CartFloatingButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      tooltip: 'Корзина',
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: const Icon(Icons.shopping_cart),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (ctx) => SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.9,
            child: CartPage(),
          ),
        );
      },
    );
  }
}
