import 'package:flutter/material.dart';
import 'dart:async';
import 'package:naliv_delivery/pages/orderPage.dart';
import 'package:flutter/cupertino.dart';

class ActiveOrderButton extends StatefulWidget {
  const ActiveOrderButton({super.key, required this.business});

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
  //     const Icon(Icons.pending_actions_rounded),
  //   ],
  //   "preparing": [
  //     "собирается в магазине",
  //     const Icon(Icons.restaurant_rounded),
  //   ],
  //   "gathering": [
  //     "забирает курьер",
  //     const Icon(Icons.drive_eta_rounded),
  //   ],
  //   "in_delivery": [
  //     "в пути к вам",
  //     const Icon(Icons.delivery_dining_rounded),
  //   ],
  //   "ready": [
  //     "готов к выдаче",
  //     const Icon(Icons.shopping_bag_rounded),
  //   ],
  //   "completed": [
  //     "завершен",
  //     const Icon(Icons.check_circle_outline_rounded),
  //   ],
  // };

  late Timer _timer;
  // TODO: REMOVE LATER
  int index = 0;
  List<List<dynamic>> testOrderStatuses = [
    [
      "в обработке",
      const Icon(Icons.pending_actions_rounded),
    ],
    [
      "собирается в магазине",
      const Icon(Icons.restaurant_rounded),
    ],
    [
      "забирает курьер",
      const Icon(Icons.drive_eta_rounded),
    ],
    [
      "в пути к вам",
      const Icon(Icons.delivery_dining_rounded),
    ],
    [
      "готов к выдаче",
      const Icon(Icons.shopping_bag_rounded),
    ],
    [
      "завершен",
      const Icon(Icons.check_circle_outline_rounded),
    ],
  ];

  late List<dynamic> orderCurrentStatus;

  @override
  void initState() {
    super.initState();
    orderCurrentStatus = testOrderStatuses[index];
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
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
    // TODO: implement dispose
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15),
      ),
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) {
          return OrderPage(
            business: widget.business,
          );
        }));
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        child: Padding(
          key: UniqueKey(),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: Text(
                    "Заказ ${orderCurrentStatus[0]}",
                    style: TextStyle(
                      fontSize: 14,
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
