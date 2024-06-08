import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../globals.dart' as globals;
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/homePage.dart';
import 'package:naliv_delivery/pages/preLoadDataPage.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key, required this.business});

  final Map<dynamic, dynamic> business;

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;
    

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.symmetric(horizontal: 30 * globals.scaleParam),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(),
          onPressed: () {
            Navigator.pushAndRemoveUntil(context, CupertinoPageRoute(
              builder: (context) {
                // return HomePage(
                //   business: widget.business,
                // );
                return PreLoadDataPage();
              },
            ), (Route<dynamic> route) => false);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  "Вернуться на главную",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 36 * globals.scaleParam,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: Text("Ваш заказ"),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 500 * globals.scaleParam,
              child: Text(
                "Ваш заказ был успешно добавлен и находится в обработке",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontSize: 38 * globals.scaleParam,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
