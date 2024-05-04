import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/homePage.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("ЭТА СТРАНИЦА ЕЩЁ В РАЗРАБОТКЕ..."),
            Text("Здесь будет информация об уже активном заказе"),
            Text("Ваш заказ типо в пути"),
            IconButton(onPressed: () {
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder:(context) {
                return
                HomePage();
              },), (route) => false);
            }, icon: Icon(Icons.close))
          ],
        ),
      ),
    );
  }
}
