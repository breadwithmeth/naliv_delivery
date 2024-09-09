import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';

class OrderInfoPage extends StatefulWidget {
  const OrderInfoPage({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderInfoPage> createState() => _OrderInfoPageState();
}

class _OrderInfoPageState extends State<OrderInfoPage> {
  Map order = {};

  @override
  void initState() {
    super.initState();

    getOrders(widget.orderId).then(
      (value) {
        setState(() {
          order = value[0];
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Заказ ${widget.orderId}"),
      ),
      body: Center(
        child: Text(order.toString()),
      ),
    );
  }
}
