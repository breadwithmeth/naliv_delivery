import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  getCartSum() async {
    await dbm.getCartTotal(int.parse(widget.business["business_id"])).then((v) {
      setState(() {
        sum = v;
      });
    });
  }

  getCartItems() async {
    await dbm
        .getAllItemsInCart(int.parse(widget.business["business_id"]))
        .then((v) {
      print(v);
      setState(() {
        items = v;
      });
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getCartItems();
    getCartSum();
    dbm.cartUpdates.listen((onData) {
      getCartItems();
      getCartSum();
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
        secondChild: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(15))),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFEE7203),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(
                  "Открыть корзину",
                  style: GoogleFonts.roboto(
                      color: Colors.white, fontWeight: FontWeight.w900),
                ),
                Text(
                  globals.formatPrice(sum.toInt()),
                  style:GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 24),
                )
              ],
            ),
            onPressed: () {
              showModalBottomSheet(
                useSafeArea: true,
                showDragHandle: false,
                enableDrag: false,
                isScrollControlled: true,
                context: context,
                builder: (context) {
                  return CartPage(business: widget.business, user: widget.user);
                },
              );
              // Navigator.push(
              //   context,
              //   CupertinoPageRoute(
              //     builder: (context) {
              //       return PreLoadCartPage(business: widget.business);
              //     },
              //   ),
              // );
            },
          ),
        ),
        crossFadeState: items.length == 0
            ? CrossFadeState.showFirst
            : CrossFadeState.showSecond,
        duration: Durations.long1);
  }
}
