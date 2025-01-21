import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/cartPage.dart';
import 'package:naliv_delivery/pages/createOrder.dart';
import 'package:naliv_delivery/shared/loadingScreen.dart';

class PreLoadCartPage extends StatefulWidget {
  const PreLoadCartPage({super.key, required this.business});
  final Map<dynamic, dynamic> business;

  @override
  State<PreLoadCartPage> createState() => _PreLoadCartPageState();
}

class _PreLoadCartPageState extends State<PreLoadCartPage> {
  List items = [];
  int localSum = 0;
  int price = 0;
  int taxes = 0;
  Map currentAddress = {};
  List addresses = [];

  Future<void> _getCart() async {
    Map<String, dynamic> cart = await getCart(widget.business["business_id"]);
    print(cart);

    setState(() {
      items = cart["cart"] ?? [];
      localSum = double.parse((cart["sum"] ?? 0.0).toString()).round();

      price = double.parse((cart["delivery"] ?? 0.0).toString()).round();
      taxes = double.parse((cart["taxes"] ?? 0.0).toString()).round();
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getCart().then((v) {
      Navigator.pushReplacement(context, CupertinoPageRoute(
        builder: (context) {
          return CartPage(
              business: widget.business,
              items: items,
              sum: localSum,
              delivery: price,
              tax: taxes);
        },
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          // children: [Text(localSum.toString())],
          children: [LoadingScrenn()],
        ),
      ),
    );
  }
}
