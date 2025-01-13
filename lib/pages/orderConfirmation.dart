import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:naliv_delivery/pages/webViewCardPayPage.dart';
import '../globals.dart' as globals;
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/orderPage.dart';
import 'package:naliv_delivery/shared/itemCards.dart';
import 'package:flutter_timer_countdown/flutter_timer_countdown.dart';

// import 'createOrder.dart';

class OrderConfirmation extends StatefulWidget {
  const OrderConfirmation({
    super.key,
    required this.delivery,
    required this.address,
    required this.items,
    required this.business,
    this.card_id,
  });
  final bool delivery;
  final Map? address;
  final List items;
  final Map<dynamic, dynamic> business;
  final int? card_id;
  @override
  State<OrderConfirmation> createState() => _OrderConfirmationState();
}

// IMPORTANT: 400 - wrong stock
// IMPORTANT: 406 - wrong order

class _OrderConfirmationState extends State<OrderConfirmation> {
  double _w = 0;

  late Timer timer;
  bool? isOrderCorrect = false;
  String htmlString = "";
  List<dynamic> wrongPositions = [];
  List<dynamic> wrongItems = [];
  int currentSeconds = 0;

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
        _w = MediaQuery.sizeOf(context).width * 0.88;
      });
    });
    timer = Timer(const Duration(seconds: 10, milliseconds: 0), () {
      // Navigator.push(
      //   context,
      //   MaterialPageRoute(
      //     builder: (context) {
      //       return WebViewCardPayPage();
      //     },
      //   ),
      // );
      // return;
      setState(() {
        currentSeconds = timer.tick;
      });
      Future.delayed(const Duration(milliseconds: 0)).then((value) async {
        print("Creating order...!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
        await createOrder(widget.business["business_id"], null,
                widget.delivery ? 1 : 0, widget.card_id)
            .then((value) {
          if (value["status"] == true) {
            setState(() {
              isOrderCorrect = true;
              htmlString = value["data"];
            });
            print("Order was created successfully");
            // NICE! Congratulations, you did well!
          } else if (value["status"] == false) {
            setState(() {
              isOrderCorrect = false;
              wrongPositions = value["data"];
            });
            print("Order was not created. Return code 400, wrong stock amount");
            // DO SOMETHING, SO THAT USER CAN FIX AMOUNT IN CART?
          } else if (value["status"] == null) {
            setState(() {
              isOrderCorrect = null;
            });
            print(
                "Order was not created. Return code 406, wrong order, or no token");
            // DO SOMETHING, SO THAT USER CAN FIX ORDER IN CART?
          }
        }).then((value) {
          if (isOrderCorrect == true) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => WebViewCardPayPage(
                  htmlString: htmlString,
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
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Остатки изменились",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontVariations: <FontVariation>[
                              FontVariation('wght', 600)
                            ],
                            fontSize: 28 * globals.scaleParam,
                          ),
                        ),
                      ],
                    ),
                    titleTextStyle: TextStyle(
                      fontSize: 16,
                      fontVariations: <FontVariation>[
                        FontVariation('wght', 600)
                      ],
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
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSecondary,
                                            fontVariations: <FontVariation>[
                                              FontVariation('wght', 600)
                                            ],
                                            fontSize: 28 * globals.scaleParam,
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
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondary,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 28 * globals.scaleParam,
                                          ),
                                        ),
                                      ),
                                      Flexible(
                                        child: Text(
                                          "В наличии: ${double.parse(wrongItems[index]['in_stock'].toString()).toStringAsFixed(0)}",
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondary,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 28 * globals.scaleParam,
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
                                color: Theme.of(context).colorScheme.onSurface,
                                fontVariations: <FontVariation>[
                                  FontVariation('wght', 600)
                                ],
                                fontSize: 28 * globals.scaleParam,
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
                                color: Theme.of(context).colorScheme.onSurface,
                                fontVariations: <FontVariation>[
                                  FontVariation('wght', 600)
                                ],
                                fontSize: 28 * globals.scaleParam,
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
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Произошла ошибка",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                            fontSize: 30 * globals.scaleParam,
                          ),
                        ),
                      ],
                    ),
                    titleTextStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondary,
                      fontVariations: <FontVariation>[
                        FontVariation('wght', 600)
                      ],
                      fontSize: 32 * globals.scaleParam,
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
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontVariations: <FontVariation>[
                                    FontVariation('wght', 600)
                                  ],
                                  fontSize: 28 * globals.scaleParam,
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
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                                fontSize: 28 * globals.scaleParam,
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
    if (timer.isActive) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.symmetric(horizontal: 30 * globals.scaleParam),
        child: Row(
          children: [
            MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height
                ? Flexible(
                    flex: 2,
                    fit: FlexFit.tight,
                    child: SizedBox(),
                  )
                : SizedBox(),
            Flexible(
              fit: FlexFit.tight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                ),
                onPressed: () {
                  timer.cancel();
                  Navigator.pop(context);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      fit: FlexFit.tight,
                      child: Text(
                        "Отменить",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontVariations: <FontVariation>[
                            FontVariation('wght', 800)
                          ],
                          fontSize: 42 * globals.scaleParam,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ListView(
              physics: RangeMaintainingScrollPhysics(),
              children: [
                Container(
                  height: 250 * globals.scaleParam,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(
                      Radius.circular(15),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          "Убедитесь в правильности заказа",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontVariations: <FontVariation>[
                              FontVariation('wght', 600)
                            ],
                            height: 2,
                            fontSize: 42 * globals.scaleParam,
                          ),
                        ),
                      ),
                      TimerCountdown(
                        format: CountDownTimerFormat.secondsOnly,
                        secondsDescription: "",
                        timeTextStyle: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 42 * globals.scaleParam,
                        ),
                        endTime: DateTime.now().add(
                          Duration(
                            seconds: 10,
                          ),
                        ),
                        onEnd: () {
                          print("Timer finished");
                        },
                      ),
                      // Stack(
                      //   children: [
                      //     Container(
                      //       height: 100 * globals.scaleParam,
                      //       decoration: BoxDecoration(
                      //         color: Colors.black,
                      //         borderRadius: BorderRadius.all(
                      //           Radius.circular(15),
                      //         ),
                      //       ),
                      //     ),
                      //     Container(
                      //       height: 100 * globals.scaleParam,
                      //       width: MediaQuery.sizeOf(context).width * 0.88,
                      //       decoration: BoxDecoration(
                      //         color: Colors.green,
                      //         borderRadius: BorderRadius.all(
                      //           Radius.circular(15),
                      //         ),
                      //       ),
                      //     ),
                      //   ],
                      // ),
                    ],
                  ),
                ),
                Container(
                  height: 150 * globals.scaleParam,
                  // alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    // border: Border.all(
                    //   width: 2,
                    //   color: Color.fromARGB(255, 245, 245, 245),
                    // ),
                    color: Color(0xFF121212),
                    borderRadius: const BorderRadius.all(
                      Radius.circular(15),
                    ),
                  ),
                  margin: EdgeInsets.symmetric(
                    horizontal: 20 * globals.scaleParam,
                    vertical: 5 * globals.scaleParam,
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: 20 * globals.scaleParam,
                    horizontal: 35 * globals.scaleParam,
                  ),
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
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontVariations: <FontVariation>[
                                    FontVariation('wght', 600)
                                  ],
                                  fontSize: 32 * globals.scaleParam,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: Row(
                          children: [
                            Flexible(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: 50 * globals.scaleParam,
                                ),
                                child: Text(
                                  widget.delivery
                                      ? widget.address!["address"] ?? ""
                                      : widget.business["address"],
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    fontVariations: <FontVariation>[
                                      FontVariation('wght', 600)
                                    ],
                                    fontSize: 32 * globals.scaleParam,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 150 * globals.scaleParam,
                  decoration: BoxDecoration(
                    // border: Border.all(
                    //   width: 2,
                    //   color: Color.fromARGB(255, 245, 245, 245),
                    // ),
                    color: Color(0xFF121212),
                    borderRadius: const BorderRadius.all(
                      Radius.circular(15),
                    ),
                  ),
                  margin: EdgeInsets.symmetric(
                      horizontal: 20 * globals.scaleParam,
                      vertical: 5 * globals.scaleParam),
                  padding: EdgeInsets.symmetric(
                    vertical: 20 * globals.scaleParam,
                    horizontal: 30 * globals.scaleParam,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Flexible(
                          //   child: Padding(
                          //     padding: EdgeInsets.only(
                          //       left: 50 * globals.scaleParam,
                          //     ),
                          //     child: Text(
                          //       "Сумма к оплате: ${globals.formatCost(widget.finalSum.toString()).toString()} ₸",
                          //       textAlign: TextAlign.center,
                          //       style: TextStyle(
                          //         color:
                          //             Theme.of(context).colorScheme.onSurface,
                          //         fontVariations: <FontVariation>[
                          //           FontVariation('wght', 600)
                          //         ],
                          //         fontSize: 32 * globals.scaleParam,
                          //       ),
                          //     ),
                          //   ),
                          // ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  height: MediaQuery.sizeOf(context).height * 0.42,
                  decoration: BoxDecoration(
                    // border: Border.all(
                    //   width: 2,
                    //   // color: Color.fromARGB(255, 245, 245, 245),
                    //   color: Colors.black,
                    // ),
                    color: Color(0xFF121212),
                    borderRadius: const BorderRadius.all(
                      Radius.circular(15),
                    ),
                  ),
                  margin: EdgeInsets.symmetric(
                    horizontal: 20 * globals.scaleParam,
                    vertical: 5 * globals.scaleParam,
                  ),
                  padding: EdgeInsets.all(15 * globals.scaleParam),
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
                            itemId: item["name"],
                            categoryId: "",
                            categoryName: "",
                            scroll: 0,
                            business_id: widget.business["business_id"],
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
                Container(
                  padding: EdgeInsets.only(top: 15 * globals.scaleParam),
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: constraints.maxWidth * 0.955,
                    // height: 130 * globals.scaleParam,
                    margin:
                        EdgeInsets.symmetric(vertical: 20 * globals.scaleParam),
                    padding: EdgeInsets.symmetric(
                        horizontal: 20 * globals.scaleParam),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(15)),
                      // color: Color.fromARGB(255, 245, 245, 245),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                " * курьер выдаст заказ 21+ только при подтверждении возраста.",
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  color: Color.fromARGB(255, 190, 190, 190),
                                  fontVariations: <FontVariation>[
                                    FontVariation('wght', 500)
                                  ],
                                  fontSize: 26 * globals.scaleParam,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                " ** продолжая заказ вы подтверждаете, что ознакомлены с условиями возврата.",
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  color: Color.fromARGB(255, 190, 190, 190),
                                  fontVariations: <FontVariation>[
                                    FontVariation('wght', 500)
                                  ],
                                  fontSize: 26 * globals.scaleParam,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: constraints.maxHeight * 0.3,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
