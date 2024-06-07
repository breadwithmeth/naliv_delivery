import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/cartPage.dart';
import 'package:flutter/cupertino.dart';

class CartButton extends StatefulWidget {
  const CartButton({super.key, required this.business});

  final Map<dynamic, dynamic> business;

  @override
  State<CartButton> createState() => _CartButtonState();
}

class _CartButtonState extends State<CartButton> {
  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;

    return SizedBox(
      width: 160 * (screenSize.height / 1080) * (screenSize.width / 720) * 2,
      height: 160 * (screenSize.height / 1080) * (screenSize.width / 720) * 2,
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
            CupertinoPageRoute(
              builder: (context) {
                return CartPage(
                  business: widget.business,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
