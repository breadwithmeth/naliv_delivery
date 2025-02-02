import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naliv_delivery/globals.dart';
import 'package:naliv_delivery/misc/databaseapi.dart';

class Changeamountbutton extends StatefulWidget {
  Changeamountbutton(
      {super.key,
      required this.item,
      required this.business,
      this.refreshCart});
  final Map item;
  final Map business;
  Function? refreshCart;
  @override
  State<Changeamountbutton> createState() => _ChangeamountbuttonState();
}

class _ChangeamountbuttonState extends State<Changeamountbutton> {
  List? options = null;

  Map<String, dynamic>? cartItem = null;
  double currentAmount = 0;
  DatabaseManager dbm = DatabaseManager();

  double? parentItemAmoint = null;
  double quantity = 1;

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  updateOptions() {
    setState(() {
      quantity = widget.item["quantity"];
    });

    if (widget.item["options"] != null) {
      setState(() {
        options = widget.item["options"];
      });
    }
  }

  getCurrentAmount() async {
    await dbm
        .getCartItemByItemId(
            int.parse(widget.business["business_id"]), widget.item["item_id"])
        .then((v) {
      setState(() {
        if (v == null) {
          currentAmount = 0;
          parentItemAmoint = null;
        } else {
          currentAmount = v["amount"];
          parentItemAmoint = v["parent_amount"];
        }
        cartItem = v;
      });
    });
  }

  updateAmount(double newAmount) async {
    await dbm
        .updateAmount(int.parse(widget.business["business_id"]),
            widget.item["item_id"], newAmount)
        .then((v) {
      print(v);
      setState(() {
        if (v == null) {
          currentAmount = 0;
          parentItemAmoint = null;
        } else {
          currentAmount = v["amount"];
          parentItemAmoint = v["parent_amount"];
        }
        cartItem = v;
      });
    });
    if (widget.refreshCart != null) {
      widget.refreshCart!();
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    updateOptions();
    getCurrentAmount();
    dbm.cartUpdates.listen((onData) {
      if (onData != null) {
        if (onData!["item_id"] == widget.item["item_id"]) {
          print(onData);
          getCurrentAmount();
        }
      }
    });
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
            onPressed: () {
              if (parentItemAmoint == null) {
                updateAmount(currentAmount - quantity);
              } else {
                updateAmount(currentAmount - (quantity * parentItemAmoint!));
              }
            },
            icon: Icon(
              Icons.remove,
              color: Colors.grey.shade300,
            )),
        Text(
          formatQuantity(currentAmount, "ед"),
          style: GoogleFonts.roboto(fontWeight: FontWeight.w900),
        ),
        IconButton(
            onPressed: () {
              if (parentItemAmoint == null) {
                updateAmount(currentAmount + quantity);
              } else {
                updateAmount(currentAmount + (quantity * parentItemAmoint!));
              }
            },
            icon: Icon(
              Icons.add,
              color: Colors.white,
            )),
      ],
    );
  }
}
