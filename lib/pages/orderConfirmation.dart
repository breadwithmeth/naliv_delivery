import 'dart:async';

import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/orderPage.dart';
import 'package:naliv_delivery/shared/itemCards.dart';

// import 'createOrder.dart';

class OrderConfirmation extends StatefulWidget {
  const OrderConfirmation(
      {super.key,
      required this.delivery,
      required this.address,
      required this.items});
  final bool delivery;
  final Map? address;
  final List items;
  @override
  State<OrderConfirmation> createState() => _OrderConfirmationState();
}

class _OrderConfirmationState extends State<OrderConfirmation> {
  double _w = 0;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    Timer(const Duration(seconds: 1), () {
      setState(() {
        _w = 300;
      });
    });
    Timer(const Duration(seconds: 6), () {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const OrderPage(),
          ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Убедитесь в правильности заказа"),
            Stack(
              children: [
                Container(
                  width: 300,
                  height: 10,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black, width: 1)),
                ),
                AnimatedContainer(
                  duration: const Duration(seconds: 5),
                  width: _w,
                  height: 10,
                  color: Colors.black,
                ),
              ],
            ),
            Container(
              decoration: BoxDecoration(
                  border: Border.all(
                    width: 2,
                    color: Colors.grey.shade100,
                  ),
                  color: Colors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(10))),
              margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
              padding: const EdgeInsets.all(5),
              child: ListView.builder(
                primary: false,
                shrinkWrap: true,
                itemCount: widget.items.length,
                itemBuilder: (context, index) {
                  final item = widget.items[index];

                  return ItemCardMedium(
                    element: item,
                    item_id: item["item_id"],
                    category_id: "",
                    category_name: "",
                    scroll: 0,
                  );
                },
              ),
            ),
            Text(widget.delivery ? "Доставка" : "Самовывоз"),
            widget.delivery
                ? Container(
                    decoration: BoxDecoration(
                        border: Border.all(
                          width: 2,
                          color: Colors.grey.shade100,
                        ),
                        color: Colors.white,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(10))),
                    margin:
                        const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      children: [
                        Text(widget.address!["address"] ?? "") ?? Container()
                      ],
                    ),
                  )
                : Container(),
          ],
        ),
      ),
    );
  }
}
