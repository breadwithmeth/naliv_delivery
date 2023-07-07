import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../misc/api.dart';

class BuyButton extends StatefulWidget {
  const BuyButton({super.key, required this.element});
  final Map<String, dynamic> element;

  @override
  State<BuyButton> createState() => _BuyButtonState();
}

class _BuyButtonState extends State<BuyButton> {
  Map element = {};
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    setState(() {
      element = widget.element;
    });
  }

  Future<void> refreshItemCard() async {
    if (element["item_id"] != null) {
      Map<String, dynamic>? _element = await getItem(widget.element["item_id"]);
      setState(() {
        element = _element!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Flexible(
        child: element["amount"] != null
            ? Container(
                alignment: Alignment.centerLeft,
                width: MediaQuery.of(context).size.width * 0.3,
                child: Container(
                  padding: EdgeInsets.all(3),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.all(Radius.circular(10))),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        padding: EdgeInsets.all(0),
                        onPressed: () async {
                          String? amount =
                              await removeFromCart(element["item_id"]);
                          setState(() {
                            element["amount"] = amount;
                          });
                        },
                        icon: Icon(Icons.remove),
                      ),
                      Text(
                        element["amount"].toString(),
                        style: TextStyle(color: Colors.black),
                      ),
                      IconButton(
                        padding: EdgeInsets.all(0),
                        onPressed: () async {
                          String? amount = await addToCart(element["item_id"]);
                          setState(() {
                            element["amount"] = amount;
                          });
                        },
                        icon: Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
              )
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade400),
                onPressed: () {
                  addToCart(element["item_id"]);
                  refreshItemCard();
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Text(
                      "В корзину",
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: Colors.black),
                    ),
                  ],
                )));
  }
}
