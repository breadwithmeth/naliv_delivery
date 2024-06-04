import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/cartPage.dart';
import 'package:flutter/cupertino.dart';

class CartButton extends StatefulWidget {
  const CartButton({super.key, required this.businessId});

  final String businessId;

  @override
  State<CartButton> createState() => _CartButtonState();
}

class _CartButtonState extends State<CartButton> {
  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      width: 160 * (screenWidth / 720),
      height: 160 * (screenWidth / 720),
      child: FloatingActionButton(
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10))),
        child: Icon(
          Icons.shopping_basket_rounded,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) {
                return CartPage(
                  businessId: widget.businessId,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
