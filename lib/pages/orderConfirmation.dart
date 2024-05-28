import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
    required this.user,
    required this.selectedBusiness,
  });
  final bool delivery;
  final Map? address;
  final List items;
  final Map<String, dynamic> cartInfo;
  final Map<dynamic, dynamic>? user;
  final Map<String, dynamic>? selectedBusiness;
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
    for (int i = 0; i < widget.items.length; i++) {
      if (widget.items[i]["item_id"] == wrongPositions[i]["item_id"]) {
        wrongItems.add(widget.items[i]);
      }
    }
  }

  @override
  void initState() {
    print(widget.selectedBusiness);
    // TODO: implement initState
    super.initState();
    Timer(const Duration(seconds: 1), () {
      setState(() {
        _w = 300;
      });
    });
    timer = Timer(const Duration(seconds: 6), () {
      Future.delayed(const Duration(milliseconds: 0)).then((value) async {
        print("Creating order...!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
        await createOrder().then((value) {
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
              MaterialPageRoute(
                builder: (context) => const OrderPage(),
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
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.7,
                        height: MediaQuery.of(context).size.height * 0.4,
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
                                            fontSize: 14,
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
                                            fontSize: 14,
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
                                            fontSize: 14,
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
                          padding: const EdgeInsets.symmetric(vertical: 5),
                        ),
                        onPressed: () {
                          //! TODO: CHANGE AMOUNT IN CART ACCORDINGLY TO REAL AMOUNT LEFT
                          Navigator.pop(context);
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Применить изменения",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          backgroundColor:
                              Theme.of(context).colorScheme.secondary,
                        ),
                        onPressed: () {
                          //! TODO: CHANGE AMOUNT IN CART ACCORDINGLY TO REAL AMOUNT LEFT
                          Navigator.pop(context);
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Изменить самостоятельно",
                              style: TextStyle(
                                fontSize: 14,
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
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSecondary,
                    ),
                    content: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.7,
                        height: MediaQuery.of(context).size.height * 0.4,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                "Повторите попытку позже, пожалуйста",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
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
                          padding: const EdgeInsets.symmetric(vertical: 5),
                        ),
                        onPressed: () {
                          //! TODO: CHANGE AMOUNT IN CART ACCORDINGLY TO REAL AMOUNT LEFT
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Принять",
                              style: TextStyle(
                                fontSize: 14,
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
  void dispose() {
    super.dispose();
    timer.cancel();
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
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                        ),
                      ),
                      Stack(
                        children: [
                          Container(
                            width: 300,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.black, width: 1),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(seconds: 5),
                            width: _w,
                            height: 10,
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
                  margin:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
                  padding: const EdgeInsets.all(5),
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
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 5,
                                  ),
                                  child: Divider(
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
                  margin: const EdgeInsets.symmetric(horizontal: 30),
                  padding: const EdgeInsets.all(15),
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
                                  fontSize: 16,
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
                                      : widget.selectedBusiness!["address"] ??
                                          "",
                                  style: TextStyle(
                                    fontSize: 16,
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
                  margin: const EdgeInsets.symmetric(horizontal: 30),
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    children: [
                      Flexible(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.user == null
                                    ? "Счёт на каспи:"
                                    : "Счёт на каспи: ${widget.user!["login"].toString()}",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
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
                                  ? "Сумма к оплате: ${widget.cartInfo["sum"].toString()} ₸"
                                  : "Сумма к оплате: 0 ₸",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
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
                  margin: const EdgeInsets.symmetric(horizontal: 30),
                  padding: const EdgeInsets.all(15),
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
                            fontSize: 18,
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
