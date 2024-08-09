import 'package:flutter/material.dart';
import '../globals.dart' as globals;
import 'dart:async';
import 'package:naliv_delivery/pages/orderPage.dart';

class ActiveOrderButton extends StatefulWidget {
  ActiveOrderButton({
    super.key,
    required this.business,
  });

  final Map<dynamic, dynamic> business;

  @override
  State<ActiveOrderButton> createState() => _ActiveOrderButtonState();
}

class _ActiveOrderButtonState extends State<ActiveOrderButton> {
  late Timer orderTimer;
  // Map<String, String> orderStatuses = {
  //   "pending": "в обработке",
  //   "preparing": "собирается в магазине",
  //   "gathering": "ожидает курьера",
  //   "in_delivery": "в пути к вам",
  //   "ready": "готов к выдаче",
  //   "completed": "завершен",
  // };

  // Map<String, List<dynamic>> orderStatuses = {
  //   "pending": [
  //     "в обработке",
  //      Icon(Icons.pending_actions_rounded),
  //   ],
  //   "preparing": [
  //     "собирается в магазине",
  //      Icon(Icons.restaurant_rounded),
  //   ],
  //   "gathering": [
  //     "забирает курьер",
  //      Icon(Icons.drive_eta_rounded),
  //   ],
  //   "in_delivery": [
  //     "в пути к вам",
  //      Icon(Icons.delivery_dining_rounded),
  //   ],
  //   "ready": [
  //     "готов к выдаче",
  //      Icon(Icons.shopping_bag_rounded),
  //   ],
  //   "completed": [
  //     "завершен",
  //      Icon(Icons.check_circle_outline_rounded),
  //   ],
  // };

  late Timer _timer;
  // TODO: REMOVE LATER
  int index = 0;
  List<List<dynamic>> testOrderStatuses = [
    [
      "в обработке",
      Icon(Icons.pending_actions_rounded),
    ],
    [
      "собирается в магазине",
      Icon(Icons.restaurant_rounded),
    ],
    [
      "забирает курьер",
      Icon(Icons.drive_eta_rounded),
    ],
    [
      "в пути к вам",
      Icon(Icons.delivery_dining_rounded),
    ],
    [
      "готов к выдаче",
      Icon(Icons.shopping_bag_rounded),
    ],
    [
      "завершен",
      Icon(Icons.check_circle_outline_rounded),
    ],
  ];

  late List<dynamic> orderCurrentStatus;

  @override
  void initState() {
    super.initState();
    orderCurrentStatus = testOrderStatuses[index];
    _timer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          orderCurrentStatus = testOrderStatuses[index];
        });
        index++;
        if (index == testOrderStatuses.length) {
          index = 0;
        }
      } else {
        _timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 30 * globals.scaleParam),
      ),
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) {
          return OrderPage(
            business: widget.business,
          );
        }));
      },
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 500),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        child: Padding(
          key: UniqueKey(),
          padding: EdgeInsets.symmetric(horizontal: 20 * globals.scaleParam),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                flex: 4,
                child: Padding(
                  padding: EdgeInsets.only(right: 10 * globals.scaleParam),
                  child: Text(
                    "Заказ ${orderCurrentStatus[0]}",
                    style: TextStyle(
                      fontSize: 32 * globals.scaleParam,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
              orderCurrentStatus.length > 1
                  ? Flexible(
                      child: orderCurrentStatus[1],
                    )
                  : Container(),
            ],
          ),
        ),
      ),
    );
  }
}
