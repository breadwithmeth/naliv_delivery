import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../globals.dart' as globals;
import 'package:flutter/widgets.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/orderPage.dart';
import 'package:naliv_delivery/shared/itemCards.dart';
import 'package:intl/intl.dart';

// import 'createOrder.dart';

class OrderConfirmation extends StatefulWidget {
  const OrderConfirmation({
    super.key,
    required this.delivery,
    required this.address,
    required this.items,
    required this.cartInfo,
    required this.business,
    this.user = const {},
  });
  final bool delivery;
  final Map? address;
  final List items;
  final String cartInfo;
  final Map<dynamic, dynamic> business;
  final Map<dynamic, dynamic> user;
  @override
  State<OrderConfirmation> createState() => _OrderConfirmationState();
}

// IMPORTANT: 400 - wrong stock
// IMPORTANT: 406 - wrong order

class _OrderConfirmationState extends State<OrderConfirmation> {
  double _w = 0;

  late Timer timer;
  bool? isOrderCorrect = false;
  List<dynamic> wrongPositions = [];
  List<dynamic> wrongItems = [];

  String formatCost(String costString) {
    int cost = int.parse(costString);
    return NumberFormat("###,###", "en_US").format(cost).replaceAll(',', ' ');
  }

  void composeWrongItemsList() {
    if (!wrongPositions.isEmpty) {
      for (int i = 0; i < widget.items.length; i++) {
        if (widget.items[i]["item_id"] == wrongPositions[i]["item_id"]) {
          wrongItems.add(widget.items[i]);
        }
      }
    }
  }

  void startTimer() {
    Timer(const Duration(seconds: 1), () {
      setState(() {
        _w = 595 * globals.scaleParam;
      });
    });
    timer = Timer(const Duration(seconds: 6), () {
      Future.delayed(const Duration(milliseconds: 0)).then((value) async {
        print("Creating order...!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
        String user_id = widget.user.isNotEmpty ? widget.user["user_id"] : "";
        await createOrder(widget.business["business_id"], user_id)
            .then((value) {
          if (value["status"] == true) {
            isOrderCorrect = true;
            print("Order was created successfully");
            // NICE! Congratulations, you did well!
          } else if (value["status"] == false) {
            isOrderCorrect = false;
            wrongPositions = value["data"];
            print("Order was not created. Return code 400, wrong stock amount");
            // DO SOMETHING, SO THAT USER CAN FIX AMOUNT IN CART?
          } else if (value["status"] == null) {
            isOrderCorrect = null;
            print(
                "Order was not created. Return code 406, wrong order, or no token");
            // DO SOMETHING, SO THAT USER CAN FIX ORDER IN CART?
          }
        }).then((value) {
          if (isOrderCorrect == true) {
            Navigator.pushReplacement(
              context,
              CupertinoPageRoute(
                builder: (context) => OrderPage(
                  business: widget.business,
                ),
              ),
            );
          } else {
            composeWrongItemsList();
            showDialog(
              context: context,
              builder: (context) {
                if (isOrderCorrect == false) {
                  return AlertDialog(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    title: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Остатки изменились"),
                      ],
                    ),
                    titleTextStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSecondary,
                    ),
                    content: Padding(
                      padding: EdgeInsets.symmetric(
                          vertical: 20 * globals.scaleParam),
                      child: SizedBox(
                        width: 600 * globals.scaleParam,
                        height: 400 * globals.scaleParam,
                        child: ListView.builder(
                          itemCount: wrongItems.length,
                          itemBuilder: (context, index) {
                            return SizedBox(
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          wrongItems[index]["name"].toString(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 28 * globals.scaleParam,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          "В корзине: ${wrongItems[index]['amount'].toString()}",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 28 * globals.scaleParam,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondary,
                                          ),
                                        ),
                                      ),
                                      Flexible(
                                        child: Text(
                                          "В наличии: ${double.parse(wrongItems[index]['in_stock'].toString()).toStringAsFixed(0)}",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 28 * globals.scaleParam,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    actions: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              vertical: 10 * globals.scaleParam),
                        ),
                        onPressed: () {
                          //! TODO: CHANGE AMOUNT IN CART ACCORDINGLY TO REAL AMOUNT LEFT
                          Navigator.pop(context);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Применить изменения",
                              style: TextStyle(
                                fontSize: 28 * globals.scaleParam,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              vertical: 10 * globals.scaleParam),
                          backgroundColor:
                              Theme.of(context).colorScheme.secondary,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Изменить самостоятельно",
                              style: TextStyle(
                                fontSize: 28 * globals.scaleParam,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  return AlertDialog(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    title: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Произошла ошибка"),
                      ],
                    ),
                    titleTextStyle: TextStyle(
                      fontSize: 32 * globals.scaleParam,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSecondary,
                    ),
                    content: Padding(
                      padding: EdgeInsets.symmetric(
                          vertical: 20 * globals.scaleParam),
                      child: SizedBox(
                        width: 600 * globals.scaleParam,
                        height: 400 * globals.scaleParam,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                "Повторите попытку позже, пожалуйста",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28 * globals.scaleParam,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              vertical: 10 * globals.scaleParam),
                        ),
                        onPressed: () {
                          //! TODO: CHANGE AMOUNT IN CART ACCORDINGLY TO REAL AMOUNT LEFT
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Принять",
                              style: TextStyle(
                                fontSize: 28 * globals.scaleParam,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
              },
            );
          }
        });
      });
    });
  }

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                flex: 3,
                fit: FlexFit.tight,
                child: Container(
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          "Убедитесь в правильности заказа",
                          style: TextStyle(
                            fontSize: 32 * globals.scaleParam,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                        ),
                      ),
                      Stack(
                        children: [
                          Container(
                            width: 595 * globals.scaleParam,
                            height: 20 * globals.scaleParam,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                  color: Colors.black,
                                  width: 2 * globals.scaleParam),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(seconds: 5),
                            width: _w,
                            height: 20 * globals.scaleParam,
                            color: Colors.black,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Flexible(
                flex: 15,
                fit: FlexFit.tight,
                child: Container(
                  decoration: BoxDecoration(
                      border: Border.all(
                        width: 2,
                        color: Colors.grey.shade100,
                      ),
                      color: Colors.white,
                      borderRadius:
                          const BorderRadius.all(Radius.circular(10))),
                  margin: EdgeInsets.symmetric(
                      horizontal: 20 * globals.scaleParam,
                      vertical: 10 * globals.scaleParam),
                  padding: EdgeInsets.all(10 * globals.scaleParam),
                  child: ListView.builder(
                    primary: false,
                    shrinkWrap: true,
                    itemCount: widget.items.length,
                    itemBuilder: (context, index) {
                      final item = widget.items[index];

                      return Column(
                        children: [
                          ItemCardNoImage(
                            element: item,
                            item_id: item["item_id"],
                            category_id: "",
                            category_name: "",
                            scroll: 0,
                          ),
                          widget.items.length - 1 != index
                              ? Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 32 * globals.scaleParam,
                                    vertical: 10 * globals.scaleParam,
                                  ),
                                  child: const Divider(
                                    height: 0,
                                  ),
                                )
                              : Container(),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Flexible(
                flex: 3,
                fit: FlexFit.tight,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      width: 2,
                      color: Colors.grey.shade100,
                    ),
                    color: Colors.white,
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  margin: EdgeInsets.symmetric(
                      horizontal: 20 * globals.scaleParam,
                      vertical: 5 * globals.scaleParam),
                  padding: EdgeInsets.all(20 * globals.scaleParam),
                  child: Column(
                    children: [
                      Flexible(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.delivery
                                    ? "Доставка по адресу: "
                                    : "Самовывоз из магазина: ",
                                style: TextStyle(
                                  fontSize: 32 * globals.scaleParam,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onBackground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                                  widget.delivery
                                      ? widget.address!["address"] ?? ""
                                      : widget.business["address"],
                                  style: TextStyle(
                                    fontSize: 32 * globals.scaleParam,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onBackground,
                                  ),
                                ) ??
                                Container(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Flexible(
                flex: 3,
                fit: FlexFit.tight,
                child: Container(
                  decoration: BoxDecoration(
                      border: Border.all(
                        width: 2,
                        color: Colors.grey.shade100,
                      ),
                      color: Colors.white,
                      borderRadius:
                          const BorderRadius.all(Radius.circular(10))),
                  margin: EdgeInsets.symmetric(
                      horizontal: 20 * globals.scaleParam,
                      vertical: 5 * globals.scaleParam),
                  padding: EdgeInsets.all(20 * globals.scaleParam),
                  child: Column(
                    children: [
                      Flexible(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.user == null
                                    ? "Счёт на каспи:"
                                    : "Счёт на каспи: ${widget.user["login"].toString()}",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 32 * globals.scaleParam,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onBackground,
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.cartInfo.isNotEmpty
                                  ? "Сумма к оплате: ${formatCost(widget.cartInfo).toString()} ₸"
                                  : "Сумма к оплате: 0 ₸",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 32 * globals.scaleParam,
                                color:
                                    Theme.of(context).colorScheme.onBackground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Flexible(
                flex: 4,
                fit: FlexFit.tight,
                child: Container(
                  decoration: BoxDecoration(
                      border: Border.all(
                        width: 2,
                        color: Colors.grey.shade100,
                      ),
                      color: Colors.white,
                      borderRadius:
                          const BorderRadius.all(Radius.circular(10))),
                  margin: EdgeInsets.symmetric(
                      horizontal: 20 * globals.scaleParam,
                      vertical: 5 * globals.scaleParam),
                  padding: EdgeInsets.all(15 * globals.scaleParam),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Отменить",
                          style: TextStyle(
                            fontSize: 35 * globals.scaleParam,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
