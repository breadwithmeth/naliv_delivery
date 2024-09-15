import 'dart:async';

import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/webViewCardPayPage.dart';
import '../globals.dart' as globals;

import 'package:naliv_delivery/pages/orderConfirmation.dart';
import 'package:naliv_delivery/pages/pickAddressPage.dart';

import '../misc/api.dart';

enum PaymentType { kaspi, cash, card }

extension PaymentTypeExtension on PaymentType {
  String get description {
    switch (this) {
      case PaymentType.kaspi:
        return 'Счёт на номер каспи';
      case PaymentType.cash:
        return 'Наличными';
      case PaymentType.card:
        return 'Картой';
    }
  }
}

class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage(
      {super.key,
      required this.business,
      required this.finalSum,
      required this.user,
      required this.items,
      required this.deliveryInfo,
      // required this.itemsAmount,
      this.client = const {}});

  final Map<dynamic, dynamic> business;
  final int finalSum;
  final Map user;
  final List items;
  // final double itemsAmount;
  final Map deliveryInfo;
  final Map<dynamic, dynamic> client;

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage>
    with SingleTickerProviderStateMixin {
  bool delivery = true;
  String cartInfo = "";
  // Widget? currentAddressWidget;
  List<Widget> addressesWidget = [];
  Map currentAddress = {};
  List addresses = [];

  bool isAddressesLoading = true;
  bool isCartLoading = true;

  List<Map<dynamic, dynamic>> wrongAmountitems = [];

  late AnimationController _controller;
  late Animation<Offset> _deliveryChooseAnim;
  PaymentType paymentType = PaymentType.card;
  String paymentDescText = "";
  Map _deliveryInfo = {};

  // Future<void> _getCart() async {
  //   // List cart = await getCart();
  //   // print(cart);

  //   Map<String, dynamic> cart = await getCart(widget.business["business_id"]);
  //   // Map<String, dynamic>? cartInfoFromAPI = await getCartInfo();

  //   setState(() {
  //     // widget.items = cart;
  //     widget.items = cart["cart"];
  //     cartInfo = cart["sum"];
  //   });
  // }

  Future<void> _getClientAddresses() async {
    setState(() {
      isAddressesLoading = true;
    });
    List<Widget> addressesWidget = [];
    await getAddresses().then((value) {
      setState(() {
        addresses = value;
      });
    });
    if (addresses.isEmpty) {
      setState(() {
        isAddressesLoading = false;
      });
      return;
    }
    for (var element in addresses) {
      addressesWidget.add(Container(
        margin: EdgeInsets.symmetric(vertical: 5),
        child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade200),
                backgroundColor: element["is_selected"] == "1"
                    ? Colors.grey.shade200
                    : Colors.white,
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 5)),
            onPressed: () {
              selectAddress(element["address_id"]);
              Timer(Duration(microseconds: 300), () {
                _getAddresses();
              });

              Navigator.pop(context);
            },
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(
                  element["address"],
                  style: TextStyle(color: Colors.black),
                )
              ],
            )),
      ));
      if (element["is_selected"] == "1") {
        setState(() {
          currentAddress = element;
          isAddressesLoading = false;
          // currentAddressWidget = GestureDetector(
          //   behavior: HitTestBehavior.opaque,
          //   child: Row(
          //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //     mainAxisSize: MainAxisSize.max,
          //     children: [
          //       Text(element["address"]),
          //        Icon(Icons.arrow_forward_ios)
          //     ],
          //   ),
          //   onTap: () {
          //     _getAddressPickDialog();
          //   },
          // );
        });
      }
    }
    if (currentAddress.isEmpty) {
      setState(() {
        isAddressesLoading = false;
      });
    }

    setState(() {
      addressesWidget = addressesWidget;
    });
  }

  Future<void> _getAddresses() async {
    setState(() {
      isAddressesLoading = true;
    });
    List<Widget> addressesWidget = [];
    addresses = await getAddresses();
    if (addresses.isEmpty) {
      setState(() {
        isAddressesLoading = false;
      });
      return;
    }
    for (var element in addresses) {
      addressesWidget.add(Container(
        margin: EdgeInsets.symmetric(vertical: 5),
        child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade200),
                backgroundColor: element["is_selected"] == "1"
                    ? Colors.grey.shade200
                    : Colors.white,
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 5)),
            onPressed: () {
              selectAddress(element["address_id"]);
              Timer(Duration(microseconds: 300), () {
                _getAddresses();
              });

              Navigator.pop(context);
            },
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(
                  element["address"],
                  style: TextStyle(color: Colors.black),
                )
              ],
            )),
      ));
      if (element["is_selected"] == "1") {
        setState(() {
          currentAddress = element;
          isAddressesLoading = false;
          // currentAddressWidget = GestureDetector(
          //   behavior: HitTestBehavior.opaque,
          //   child: Row(
          //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //     mainAxisSize: MainAxisSize.max,
          //     children: [
          //       Text(element["address"]),
          //        Icon(Icons.arrow_forward_ios)
          //     ],
          //   ),
          //   onTap: () {
          //     _getAddressPickDialog();
          //   },
          // );
        });
      }
    }
    if (currentAddress.isEmpty) {
      setState(() {
        isAddressesLoading = false;
      });
    }

    setState(() {
      addressesWidget = addressesWidget;
    });
  }

  void setPaymentType() {
    switch (paymentType) {
      case PaymentType.kaspi:
        if (delivery) {
          paymentDescText =
              "${globals.formatCost((widget.finalSum + _deliveryInfo["price"]).toString())} ₸   ${widget.user["login"]} ";
        } else {
          paymentDescText =
              "${globals.formatCost((widget.finalSum).toString())} ₸   ${widget.user["login"]} ";
        }
        break;
      case PaymentType.card:
        if (delivery) {
          paymentDescText =
              "${globals.formatCost((widget.finalSum + _deliveryInfo["price"]).toString())} ₸";
        } else {
          paymentDescText =
              "${globals.formatCost((widget.finalSum).toString())} ₸";
        }
        break;
      case PaymentType.cash:
        if (delivery) {
          paymentDescText =
              "${globals.formatCost((widget.finalSum + _deliveryInfo["price"]).toString())} ₸";
        } else {
          paymentDescText =
              "${globals.formatCost((widget.finalSum).toString())} ₸";
        }
        break;
    }
  }

  // ! TODO: SHOULD BE USED TO RECALCULATE PRICE OF DELIVERY ON FLY, WHEN CHANGING DELIVERY ADDRESS.
  // ! Or get price from backend
  // void calculatePriceOfDistance() {
  //   double dist = _deliveryInfo["distance"] / 1000;
  //   dist = (dist * 2).round() / 2;
  //   if (dist <= 1.5) {
  //     _deliveryInfo['price'] = 700;
  //   } else {
  //     if (dist < 5) {
  //       setState(() {
  //         _deliveryInfo['price'] = ((dist - 1.5) * 300 + 700).toInt();
  //       });
  //     } else {
  //       setState(() {
  //         _deliveryInfo['price'] = ((dist - 1.5) * 250 + 700).toInt();
  //       });
  //     }
  //   }
  // }

  // Future<void> _getCartDeliveryPrice() async {
  //   getCart(widget.business["business_id"]).then(
  //     (value) {
  //       if (value.isNotEmpty) {

  //       }
  //     },
  //   );
  //   setState(() {});
  // }

  @override
  void initState() {
    super.initState();
    _deliveryInfo = widget.deliveryInfo;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _deliveryChooseAnim = Tween<Offset>(
      begin: Offset(0, 0),
      end: Offset(1.035, 0),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    Future.delayed(Duration(microseconds: 0), () async {
      // SWITCH BETWEEN getAddresses and getClientAddresses depending on Client/Operator mode
      await _getAddresses();
      // await _getClientAddresses();
    }).whenComplete(() => isCartLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    setPaymentType();
    return Scaffold(
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
                onPressed: isAddressesLoading || isCartLoading
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OrderConfirmation(
                              delivery: delivery,
                              items: widget.items,
                              address: currentAddress,
                              cartInfo: cartInfo,
                              business: widget.business,
                              user: widget.user,
                              finalSum: delivery
                                  ? double.parse(((widget.finalSum - 0) +
                                              _deliveryInfo["price"] +
                                              _deliveryInfo["taxes"])
                                          .toString())
                                      .round()
                                  : double.parse(
                                          ((widget.finalSum - 0)).toString())
                                      .round(),
                              paymentType: paymentType == PaymentType.kaspi
                                  ? "${paymentType.description}: ${widget.user["login"]}"
                                  : paymentType.description,
                            ),
                          ),
                        );
                      },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      fit: FlexFit.tight,
                      child: Text(
                        "Подтвердить заказ",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 42 * globals.scaleParam,
                          color: Theme.of(context).colorScheme.onPrimary,
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
      // floatingActionButton: ElevatedButton(
      //   onPressed: isCartLoading || isAddressesLoading || currentAddress.isEmpty
      //       ? null
      //       : () {
      //           Navigator.push(
      //             context,
      //             MaterialPageRoute(
      //               builder: (context) => OrderConfirmation(
      //                 delivery: delivery,
      //                 items: widget.items,
      //                 address: currentAddress,
      //                 cartInfo: cartInfo,
      //                 business: widget.business,
      //                 user: widget.user,
      //                 finalSum: widget.finalSum,
      //               ),
      //             ),
      //           );
      //         },
      //   child: Row(
      //     mainAxisAlignment: MainAxisAlignment.center,
      //     mainAxisSize: MainAxisSize.max,
      //     children: [
      //       Text(
      //         "Подтвердить заказ",
      //         style: TextStyle(
      //           fontWeight: FontWeight.w900,
      //           fontSize: 32 * globals.scaleParam,
      //           color: Theme.of(context).colorScheme.onPrimary,
      //         ),
      //       ),
      //     ],
      //   ),
      // ),

      body: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            children: [
              Padding(
                  padding: EdgeInsets.only(
                      left: 1 * globals.scaleParam,
                      top: 15 * globals.scaleParam),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.arrow_back_rounded),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                "Заказ",
                                style: TextStyle(
                                    fontFamily: "MontserratAlternates",
                                    fontWeight: FontWeight.w700,
                                    fontSize: 64 * globals.scaleParam),
                              )
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                "${widget.business["name"]} ${widget.business["address"]}",
                                style: TextStyle(
                                    fontFamily: "Raleway",
                                    fontVariations: <FontVariation>[
                                      FontVariation('wght', 600)
                                    ],
                                    fontWeight: FontWeight.w500,
                                    fontSize: 30 * globals.scaleParam),
                              )
                            ],
                          ),
                        ],
                      )
                    ],
                  )),
              Container(
                padding: EdgeInsets.only(top: 15 * globals.scaleParam),
                alignment: Alignment.topCenter,
                child: Container(
                  width: constraints.maxWidth * 0.955,
                  height: 330 * globals.scaleParam,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                    color: Color.fromARGB(255, 245, 245, 245),
                  ),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            height: 100 * globals.scaleParam,
                            margin: EdgeInsets.symmetric(
                              horizontal: 25 * globals.scaleParam,
                              vertical: 20 * globals.scaleParam,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.all(
                                Radius.circular(10),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade300,
                                  spreadRadius: -3,
                                ),
                              ],
                              // color: const Color.fromARGB(255, 51, 51, 51),
                            ),
                            child: Row(
                              children: [
                                Flexible(
                                  flex: 30,
                                  fit: FlexFit.tight,
                                  child: GestureDetector(
                                    onTap: () {
                                      _controller.reverse();
                                      setState(() {
                                        delivery = true;
                                      });
                                    },
                                    child: Container(
                                      alignment: Alignment.center,
                                      height: double.infinity,
                                      padding: EdgeInsets.all(
                                          15 * globals.scaleParam),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(10),
                                        ),
                                        // color: Colors.white24,
                                      ),
                                      child: Text(
                                        "Доставка",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 38 * globals.scaleParam,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Spacer(),
                                Flexible(
                                  flex: 30,
                                  fit: FlexFit.tight,
                                  child: GestureDetector(
                                    onTap: () {
                                      _controller.forward();
                                      setState(() {
                                        delivery = false;
                                      });
                                    },
                                    child: Container(
                                      alignment: Alignment.center,
                                      height: double.infinity,
                                      padding: EdgeInsets.all(
                                        15 * globals.scaleParam,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(10),
                                        ),
                                        // color: Colors.white24,
                                      ),
                                      child: Text(
                                        "Самовывоз",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 38 * globals.scaleParam,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 100 * globals.scaleParam,
                            margin: EdgeInsets.symmetric(
                              horizontal: 25 * globals.scaleParam,
                              vertical: 20 * globals.scaleParam,
                            ),
                            child: Row(
                              children: [
                                Flexible(
                                  flex: 30,
                                  fit: FlexFit.tight,
                                  child: SlideTransition(
                                    position: _deliveryChooseAnim,
                                    child: GestureDetector(
                                      onPanUpdate: (details) {
                                        if (details.delta.dx > 0 &&
                                            !_controller.isAnimating) {
                                          // print("Dragging in +X direction");
                                          _controller.forward();
                                          setState(() {
                                            delivery = false;
                                          });
                                        } else if (details.delta.dx < 0 &&
                                            !_controller.isAnimating) {
                                          // print("Dragging in -X direction");
                                          _controller.reverse();
                                          setState(() {
                                            delivery = true;
                                          });
                                        }
                                      },
                                      child: Container(
                                        alignment: Alignment.center,
                                        height: double.infinity,
                                        padding: EdgeInsets.all(
                                          15 * globals.scaleParam,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(10),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color.fromARGB(
                                                  255, 94, 94, 94),
                                              blurRadius: 10,
                                              spreadRadius: -6,
                                            ),
                                          ],
                                          color: Colors.black,
                                        ),
                                        child: AnimatedSwitcher(
                                            duration:
                                                Duration(milliseconds: 300),
                                            transitionBuilder:
                                                (child, animation) {
                                              return FadeTransition(
                                                opacity: animation,
                                                child: child,
                                              );
                                            },
                                            child: Text(
                                              delivery
                                                  ? "Доставка"
                                                  : "Самовывоз",
                                              key: ValueKey<bool>(delivery),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize:
                                                    38 * globals.scaleParam,
                                                fontWeight: FontWeight.w600,
                                                // shadows: [
                                                //   Shadow(
                                                //     color: Colors.grey.shade200,
                                                //     blurRadius: 5,
                                                //   ),
                                                // ],
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onPrimary,
                                              ),
                                            )),
                                      ),
                                    ),
                                  ),
                                ),
                                Spacer(),
                                Flexible(
                                  flex: 30,
                                  fit: FlexFit.tight,
                                  child: SizedBox(),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                      Container(
                        height: 85 * globals.scaleParam,
                        margin: EdgeInsets.only(
                          top: 35 * globals.scaleParam,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 35 * globals.scaleParam,
                        ),
                        child: delivery
                            ? Row(
                                key: ValueKey<bool>(delivery),
                                children: [
                                  Flexible(
                                    flex: 3,
                                    fit: FlexFit.tight,
                                    child: Text(
                                      "Ваш адрес ",
                                      style: TextStyle(
                                        fontSize: 32 * globals.scaleParam,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ),
                                  Flexible(
                                    flex: 8,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12 * globals.scaleParam,
                                        ),
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        foregroundColor: Colors.grey,
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) {
                                              return PickAddressPage(
                                                client: widget.user,
                                                business: widget.business,
                                                isFromCreateOrder: true,
                                              );
                                            },
                                          ),
                                        ).then((value) {
                                          // _getCartDeliveryPrice();
                                          setState(() {
                                            isCartLoading = true;
                                          });
                                          Timer(
                                            Duration(seconds: 5),
                                            () {
                                              if (isCartLoading) {
                                                isCartLoading = false;
                                              }
                                            },
                                          );
                                          // Check if name hasn't changed, only for visual consistence
                                          String beforeCallAddress =
                                              currentAddress["address"];
                                          _getClientAddresses().whenComplete(
                                            () {
                                              // Call again if previous address was the same
                                              if (currentAddress["address"] ==
                                                  beforeCallAddress) {
                                                _getClientAddresses();
                                              }
                                              getCart(widget
                                                      .business["business_id"])
                                                  .then(
                                                (value) {
                                                  if (value.isNotEmpty) {
                                                    setState(() {
                                                      _deliveryInfo["price"] =
                                                          value["delivery"];
                                                      _deliveryInfo["taxes"] =
                                                          value["taxes"];
                                                    });
                                                    // _deliveryInfo[""] = value[""]
                                                  }
                                                },
                                              );
                                              setState(() {
                                                isCartLoading = false;
                                              });
                                            },
                                          );
                                          print(_getAddresses());
                                        });
                                      },
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Flexible(
                                            flex: 7,
                                            fit: FlexFit.tight,
                                            child: Text(
                                              currentAddress["address"] ??
                                                  "Загружаю...",
                                              style: TextStyle(
                                                fontSize:
                                                    32 * globals.scaleParam,
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                            ),
                                          ),
                                          Flexible(
                                            fit: FlexFit.tight,
                                            child: Icon(
                                              Icons.arrow_drop_down_rounded,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Flexible(
                                    flex: 3,
                                    fit: FlexFit.tight,
                                    child: Text(
                                      "Адрес магазина ",
                                      style: TextStyle(
                                        fontSize: 32 * globals.scaleParam,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ),
                                  Flexible(
                                    flex: 8,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8 * globals.scaleParam,
                                          horizontal: 12 * globals.scaleParam,
                                        ),
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        foregroundColor: Colors.grey,
                                      ),
                                      onPressed: () {
                                        // Navigator.push(
                                        //   context,
                                        //   MaterialPageRoute(
                                        //     builder: (context) {
                                        //       return PickAddressPage(
                                        //         client: widget.user,
                                        //         business: widget.business,
                                        //         isFromCreateOrder: true,
                                        //       );
                                        //     },
                                        //   ),
                                        // ).then((value) {
                                        //   _getClientAddresses();
                                        //   print(_getAddresses());
                                        // });
                                      },
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Flexible(
                                            flex: 7,
                                            fit: FlexFit.tight,
                                            child: Text(
                                              widget.business["address"] ??
                                                  "Загружаю...",
                                              style: TextStyle(
                                                fontSize:
                                                    32 * globals.scaleParam,
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                            ),
                                          ),
                                          Flexible(
                                            fit: FlexFit.tight,
                                            child: Icon(
                                              Icons.arrow_drop_down_rounded,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      // Container(
                      //   padding: EdgeInsets.symmetric(
                      //     horizontal: 35 * globals.scaleParam,
                      //   ),
                      //   // color: Colors.amber,
                      //   height: 85 * globals.scaleParam,
                      //   child: Column(
                      //     children: [
                      //       Flexible(
                      //         child: Row(
                      //           children: [
                      //             Flexible(
                      //               flex: 3,
                      //               fit: FlexFit.tight,
                      //               child: SizedBox(),
                      //             ),
                      //             Flexible(
                      //               flex: 7,
                      //               fit: FlexFit.tight,
                      //               child: Text(
                      //                 delivery ? "${globals.formatCost((_deliveryInfo["price"]).toString())} ₸" : "Без доставки",
                      //                 style: TextStyle(
                      //                   fontSize: 32 * globals.scaleParam,
                      //                   fontWeight: FontWeight.w500,
                      //                   color: Theme.of(context).colorScheme.primary,
                      //                 ),
                      //               ),
                      //             ),
                      //             Flexible(
                      //               fit: FlexFit.tight,
                      //               child: SizedBox(),
                      //             ),
                      //           ],
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.only(top: 15 * globals.scaleParam),
                alignment: Alignment.topCenter,
                child: Container(
                  width: constraints.maxWidth * 0.955,
                  height: 225 * globals.scaleParam,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                    color: Color.fromARGB(255, 245, 245, 245),
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 85 * globals.scaleParam,
                        margin: EdgeInsets.only(
                          top: 35 * globals.scaleParam,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 35 * globals.scaleParam,
                        ),
                        child: Row(
                          children: [
                            Flexible(
                              flex: 3,
                              fit: FlexFit.tight,
                              child: Text(
                                "Оплата ",
                                style: TextStyle(
                                  fontSize: 32 * globals.scaleParam,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            Flexible(
                              flex: 8,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 8 * globals.scaleParam,
                                    horizontal: 12 * globals.scaleParam,
                                  ),
                                  backgroundColor: Colors.transparent,
                                  disabledBackgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.grey,
                                ),
                                onPressed: null,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      flex: 7,
                                      fit: FlexFit.tight,
                                      child: Text(
                                        paymentType.description,
                                        style: TextStyle(
                                          fontSize: 32 * globals.scaleParam,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                    ),
                                    // TODO: CHANGE THIS "INVISIBLE" BUTTON
                                    Flexible(
                                      fit: FlexFit.tight,
                                      child: Icon(
                                        Icons.arrow_drop_down_rounded,
                                        color: Colors.transparent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 35 * globals.scaleParam,
                        ),
                        // color: Colors.amber,
                        height: 85 * globals.scaleParam,
                        child: Column(
                          children: [
                            Flexible(
                              child: Row(
                                children: [
                                  Flexible(
                                    flex: 3,
                                    fit: FlexFit.tight,
                                    child: SizedBox(),
                                  ),
                                  Flexible(
                                    flex: 7,
                                    fit: FlexFit.tight,
                                    child: Text(
                                      paymentDescText,
                                      style: TextStyle(
                                        fontSize: 32 * globals.scaleParam,
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ),
                                  Flexible(
                                    fit: FlexFit.tight,
                                    child: SizedBox(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Padding(
                      //   padding: EdgeInsets.symmetric(
                      //     horizontal: 45 * globals.scaleParam,
                      //   ),
                      //   child: Divider(
                      //     height: 5 * globals.scaleParam,
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.only(top: 15 * globals.scaleParam),
                alignment: Alignment.topCenter,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 35 * globals.scaleParam,
                  ),
                  width: constraints.maxWidth * 0.955,
                  height: 450 * globals.scaleParam,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                    color: Color.fromARGB(255, 245, 245, 245),
                  ),
                  child: Column(
                    children: [
                      Flexible(
                        fit: FlexFit.tight,
                        child: Row(
                          children: [
                            Flexible(
                              fit: FlexFit.tight,
                              child: Text(
                                "Корзина",
                                style: TextStyle(
                                  fontSize: 32 * globals.scaleParam,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            Flexible(
                              fit: FlexFit.tight,
                              child: Text(
                                "${globals.formatCost(widget.finalSum.toString())} ₸",
                                style: TextStyle(
                                  fontSize: 32 * globals.scaleParam,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        fit: FlexFit.tight,
                        child: Row(
                          children: [
                            Flexible(
                              fit: FlexFit.tight,
                              child: Text(
                                "Доставка",
                                style: TextStyle(
                                  fontSize: 32 * globals.scaleParam,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            Flexible(
                              fit: FlexFit.tight,
                              child: Text(
                                delivery
                                    ? "${globals.formatCost(_deliveryInfo["price"].toString())} ₸"
                                    : "0 ₸",
                                style: TextStyle(
                                  fontSize: 32 * globals.scaleParam,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        fit: FlexFit.tight,
                        child: Row(
                          children: [
                            Flexible(
                              fit: FlexFit.tight,
                              child: Text(
                                "Тариф за сервис",
                                style: TextStyle(
                                  fontSize: 32 * globals.scaleParam,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            Flexible(
                              fit: FlexFit.tight,
                              child: Text(
                                delivery
                                    ? "${globals.formatCost(_deliveryInfo["taxes"].toString())} ₸"
                                    : "0 ₸",
                                style: TextStyle(
                                  fontSize: 32 * globals.scaleParam,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Flexible(
                      //   fit: FlexFit.tight,
                      //   child: Row(
                      //     children: [
                      //       Flexible(
                      //         fit: FlexFit.tight,
                      //         child: Text(
                      //           "Бонусы",
                      //           style: TextStyle(
                      //             fontSize: 32 * globals.scaleParam,
                      //             fontWeight: FontWeight.w600,
                      //             color: Theme.of(context).colorScheme.primary,
                      //           ),
                      //         ),
                      //       ),
                      //       Flexible(
                      //         fit: FlexFit.tight,
                      //         child: Text(
                      //           "0 ₸",
                      //           style: TextStyle(
                      //             fontSize: 32 * globals.scaleParam,
                      //             fontWeight: FontWeight.w600,
                      //             color: Theme.of(context).colorScheme.primary,
                      //           ),
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10 * globals.scaleParam,
                        ),
                        child: Divider(
                          height: 5 * globals.scaleParam,
                        ),
                      ),
                      Flexible(
                        fit: FlexFit.tight,
                        child: Row(
                          children: [
                            Flexible(
                              fit: FlexFit.tight,
                              child: Text(
                                "Итого",
                                style: TextStyle(
                                  fontSize: 32 * globals.scaleParam,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            Flexible(
                              fit: FlexFit.tight,
                              child: Text(
                                //! TODO: Add bonuses instead of hardcoded zero!
                                delivery
                                    ? "${globals.formatCost(((widget.finalSum - 0) + _deliveryInfo["price"] + _deliveryInfo["taxes"]).toString())} ₸"
                                    : "${globals.formatCost(((widget.finalSum - 0)).toString())} ₸",
                                style: TextStyle(
                                  fontSize: 32 * globals.scaleParam,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                  padding:
                      EdgeInsets.symmetric(horizontal: 20 * globals.scaleParam),
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
                                // fontFamily: "montserrat",
                                fontSize: 26 * globals.scaleParam,
                                fontWeight: FontWeight.w500,
                                color: Color.fromARGB(255, 190, 190, 190),
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
                                // fontFamily: "montserrat",
                                fontSize: 26 * globals.scaleParam,
                                fontWeight: FontWeight.w500,
                                color: Color.fromARGB(255, 190, 190, 190),
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
    );
  }
}
