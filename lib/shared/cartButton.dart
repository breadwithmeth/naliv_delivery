import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:naliv_delivery/misc/databaseapi.dart';
import 'package:naliv_delivery/pages/cartPage.dart';
import '../globals.dart' as globals;
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
  DatabaseManager dbm = DatabaseManager();
  List items = [];
  double sum = 0;

  @override
  void initState() {
    super.initState();
    getCartItems();
    getCartSum();
    dbm.cartUpdates.listen((onData) {
      getCartItems();
      getCartSum();
    });
  }

  getCartSum() async {
    await dbm.getCartTotal(int.parse(widget.business["business_id"])).then((v) {
      setState(() => sum = v);
    });
  }

  getCartItems() async {
    await dbm
        .getAllItemsInCart(int.parse(widget.business["business_id"]))
        .then((v) {
      setState(() => items = v);
    });
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      alignment: Alignment.bottomCenter,
      firstChild: Container(),
      secondChild: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: CupertinoColors.activeOrange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                showCupertinoModalBottomSheet(
                  context: context,
                  backgroundColor:
                      CupertinoColors.systemBackground.withOpacity(0),
                  expand: true,
                  enableDrag: true,
                  builder: (context) => CartPage(
                    business: widget.business,
                    user: widget.user,
                  ),
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.shopping_cart,
                        color: CupertinoColors.white,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Корзина',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    globals.formatPrice(sum.toInt()),
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      crossFadeState:
          items.isEmpty ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      duration: Duration(milliseconds: 300),
    );
  }
}
