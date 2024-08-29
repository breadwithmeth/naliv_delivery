import 'package:flutter/material.dart';

class OrderInfoPage extends StatefulWidget {
  const OrderInfoPage({super.key});

  @override
  State<OrderInfoPage> createState() => _OrderInfoPageState();
}

class _OrderInfoPageState extends State<OrderInfoPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Заказ"),
      ),
      body: Placeholder(),
    );
  }
}
