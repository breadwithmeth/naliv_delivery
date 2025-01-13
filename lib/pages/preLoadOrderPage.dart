import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/createOrder.dart';
import 'package:naliv_delivery/shared/loadingScreen.dart';

class PreLoadOrderPage extends StatefulWidget {
  const PreLoadOrderPage({super.key, required this.business});
  final Map<dynamic, dynamic> business;

  @override
  State<PreLoadOrderPage> createState() => _PreLoadOrderPageState();
}

class _PreLoadOrderPageState extends State<PreLoadOrderPage> {
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
      // distance = double.parse((cart["distance"] ?? 0.0).toString()).round();
      // price = (price / 100).round() * 100;
      price = double.parse((cart["delivery"] ?? 0.0).toString()).round();
      taxes = double.parse((cart["taxes"] ?? 0.0).toString()).round();
    });
  }

  Future<void> _getAddresses() async {
    List _addresses = await getAddresses();

    for (var element in _addresses) {
      if (element["is_selected"] == "1") {
        setState(() {
          currentAddress = element;
          print(currentAddress);
        });
      }
    }

    setState(() {
      addresses = _addresses;
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getAddresses().then((v) {
      _getCart().then((v) {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (context) {
            return CreateOrderPage(
                business: widget.business,
                items: items,
                currentAddress: currentAddress,
                addresses: addresses,
                localSum: localSum,
                price: price,
                taxes: taxes);
          },
        ));
      });
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
