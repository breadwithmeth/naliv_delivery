import 'package:flutter/material.dart';
import '../globals.dart' as globals;
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
    return SizedBox(
      width:
          MediaQuery.of(context).size.width < MediaQuery.of(context).size.height
              ? MediaQuery.of(context).size.width * 0.25
              : MediaQuery.of(context).size.height * 0.25,
      height:
          MediaQuery.of(context).size.width < MediaQuery.of(context).size.height
              ? MediaQuery.of(context).size.width * 0.25
              : MediaQuery.of(context).size.height * 0.25,
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
