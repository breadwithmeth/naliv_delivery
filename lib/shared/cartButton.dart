import 'package:flutter/material.dart';
import '../globals.dart' as globals;
import 'package:naliv_delivery/pages/cartPage.dart';
import 'package:flutter/cupertino.dart';

class CartButton extends StatefulWidget {
  const CartButton({
    super.key,
    required this.business,
    required this.user,
  });

  final Map<dynamic, dynamic> business;
  final Map user;

  @override
  State<CartButton> createState() => _CartButtonState();
}

class _CartButtonState extends State<CartButton> {
  @override
  Widget build(BuildContext context) {
    return Container(
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
                  business: widget.business,
                  user: widget.user,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
