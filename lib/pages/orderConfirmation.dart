import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:naliv_delivery/pages/preLoadDataPage2.dart';
import 'package:naliv_delivery/shared/openMainPageButton.dart';
import '../globals.dart' as globals;
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/orderPage.dart';
// import 'package:naliv_delivery/shared/itemCards.dart';
import 'package:flutter/cupertino.dart';

// import 'createOrder.dart';

class OrderConfirmation extends StatefulWidget {
  const OrderConfirmation({
    super.key,
    required this.delivery,
    required this.address,
    required this.items,
    required this.business,
    this.card_id,
    required this.useBonuses,
  });
  final bool delivery;
  final Map? address;
  final List items;
  final Map<dynamic, dynamic> business;
  final int? card_id;
  final bool useBonuses;
  @override
  State<OrderConfirmation> createState() => _OrderConfirmationState();
}

// IMPORTANT: 400 - wrong stock
// IMPORTANT: 406 - wrong order

class _OrderConfirmationState extends State<OrderConfirmation> {
  double _w = 0;

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

  _createOrder() async {
    await createOrder2(widget.business["business_id"], null,
            widget.delivery ? 1 : 0, widget.card_id, widget.useBonuses)
        .then((value) {
      if (value["status"] == "insufficent funds") {
        showDialog(
          barrierDismissible: false,
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(
                "Нехватает средств",
              ),
              content: Text("Вернитесь на главный экран для повторной оплаты"),
              actions: [OpenMainPage()],
            );
          },
        );
      } else if (value["code"].toString() == "0") {
        showDialog(
          barrierDismissible: false,
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(
                "Платеж принят в обработку",
              ),
              content:
                  Text("Вернитесь на главный экран для отслеживания заказа"),
              actions: [OpenMainPage()],
            );
          },
        );
      } else if (value["status"] == "unknown") {
        showDialog(
          barrierDismissible: false,
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(
                "Ожидаем подтверждение платежа от банка",
              ),
              content: Text(
                  "Вернитесь на главный экран для просмотра статуса оплаты"),
              actions: [OpenMainPage()],
            );
          },
        );
      }
      return value;
    });
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF121212),
        surfaceTintColor: Color(0xFF121212),
      ),
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
                  _createOrder();
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      fit: FlexFit.tight,
                      child: Text(
                        "Продолжить",
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
                SizedBox(
                  height: 20 * globals.scaleParam,
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 40 * globals.scaleParam, vertical: 20),
                  child: Text("Убедитесь в правильности заказа"),
                ),
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
                // Container(
                //   height: MediaQuery.sizeOf(context).height * 0.42,
                //   decoration: BoxDecoration(
                //     // border: Border.all(
                //     //   width: 2,
                //     //   // color: Color.fromARGB(255, 245, 245, 245),
                //     //   color: Colors.black,
                //     // ),
                //     color: Color(0xFF121212),
                //     borderRadius: const BorderRadius.all(
                //       Radius.circular(15),
                //     ),
                //   ),
                //   margin: EdgeInsets.symmetric(
                //     horizontal: 20 * globals.scaleParam,
                //     vertical: 5 * globals.scaleParam,
                //   ),
                //   padding: EdgeInsets.all(15 * globals.scaleParam),
                //   child: ListView.builder(
                //     primary: false,
                //     shrinkWrap: true,
                //     itemCount: widget.items.length,
                //     itemBuilder: (context, index) {
                //       final item = widget.items[index];

                //       return Column(
                //         children: [
                //           ItemCardNoImage(
                //             element: item,
                //             itemId: item["name"],
                //             categoryId: "",
                //             categoryName: "",
                //             scroll: 0,
                //             business_id: widget.business["business_id"],
                //           ),
                //           widget.items.length - 1 != index
                //               ? Padding(
                //                   padding: EdgeInsets.symmetric(
                //                     horizontal: 32 * globals.scaleParam,
                //                     vertical: 10 * globals.scaleParam,
                //                   ),
                //                   child: const Divider(
                //                     height: 0,
                //                   ),
                //                 )
                //               : Container(),
                //         ],
                //       );
                //     },
                //   ),
                // ),
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
