import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:naliv_delivery/misc/api.dart';
import '../globals.dart' as globals;

class ActiveOrdersButton extends StatefulWidget {
  const ActiveOrdersButton({super.key});

  @override
  State<ActiveOrdersButton> createState() => _ActiveOrdersButtonState();
}

class _ActiveOrdersButtonState extends State<ActiveOrdersButton> {
  List orders = [];

  Future<void> _getActiveOrders() async {
    List? _orders = await getActiveOrders();
    setState(() {
      orders = _orders!;
    });
  }

  late Timer periodicTimer;
  final DraggableScrollableController _dsController =
      DraggableScrollableController();

  bool isExpanded = false;
  @override
  void initState() {
    super.initState();

    periodicTimer = Timer.periodic(
      const Duration(seconds: 10),
      (timer) {
        _getActiveOrders();
      },
    );
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _dsController.dispose();
    periodicTimer.cancel();
    super.dispose();
  }

  Widget orderStatusWidget(Map order, String order_status, Color color) {
    return Container(
      color: color,
      padding: EdgeInsets.all(5 * globals.scaleParam),
      child: Text(order_status,
          style: TextStyle(
              fontFamily: "Raleway",
              fontVariations: <FontVariation>[FontVariation('wght', 600)],
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontSize: 36 * globals.scaleParam)),
    );
  }

  Widget getOrderStatusFormat(Map order) {
    if (order["order_status"] == "66") {
      return orderStatusWidget(order, "Заказ ожидает оплаты", Colors.redAccent);
    } else if (order["order_status"] == "0") {
      return orderStatusWidget(
        order,
        "Ждем когда человек увидит ваш заказ",
        Color(0xFFEE7203),
      );
    } else if (order["order_status"] == "1") {
      return orderStatusWidget(order, "Ваш заказ собирают", Colors.greenAccent);
    } else if (order["order_status"] == "2") {
      return orderStatusWidget(
          order, "Ваш заказ собран и ожидает курьера", Colors.greenAccent);
    } else if (order["order_status"] == "3") {
      return orderStatusWidget(order, "Ваш заказ забрал курьер", Colors.green);
      ;
    } else {
      return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: ListView.builder(
        primary: false,
        shrinkWrap: true,
        itemCount: orders.length,
        itemBuilder: (context, index) {
          return Container(
            clipBehavior: Clip.antiAliasWithSaveLayer,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Container(
              padding: EdgeInsets.all(10),
              child: getOrderStatusFormat(orders[index]),
            ),
          );
        },
      ),
    );
  }
}
