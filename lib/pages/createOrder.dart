import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../globals.dart' as globals;
import 'package:flutter/widgets.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:naliv_delivery/main.dart';
import 'package:naliv_delivery/pages/addressesPage.dart';
import 'package:naliv_delivery/pages/createAddressPage.dart';
import 'package:naliv_delivery/pages/orderConfirmation.dart';
import 'package:naliv_delivery/pages/pickAddressPage.dart';
import 'package:naliv_delivery/shared/itemCards.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

import '../misc/api.dart';

class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage(
      {super.key,
      required this.business,
      required this.finalSum,
      required this.user,
      required this.items,
      required this.deliveryInfo,
      this.client = const {}});

  final Map<dynamic, dynamic> business;
  final int finalSum;
  final Map user;
  final List items;
  final Map deliveryInfo;
  final Map<dynamic, dynamic> client;

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  bool delivery = true;
  String cartInfo = "";
  // Widget? currentAddressWidget;
  List<Widget> addressesWidget = [];
  Map currentAddress = {};
  List addresses = [];

  bool isAddressesLoading = true;
  bool isCartLoading = true;

  List<Map<dynamic, dynamic>> wrongAmountitems = [];

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

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    Future.delayed(Duration(microseconds: 0), () async {
      // SWITCH BETWEEN getAddresses and getClientAddresses depending on Client/Operator mode
      await _getAddresses();
      // await _getClientAddresses();
    }).whenComplete(() => isCartLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Заказ"),
      ),
      body: ListView(
        children: [
          SizedBox(
            height: 10 * globals.scaleParam,
          ),
          Container(
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.all(Radius.circular(10))),
            margin: EdgeInsets.symmetric(
                horizontal: 20 * globals.scaleParam,
                vertical: 10 * globals.scaleParam),
            padding: EdgeInsets.all(10 * globals.scaleParam),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: [
                Flexible(
                  flex: 1,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        delivery = true;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                          color: delivery ? Colors.white : Colors.grey.shade100,
                          borderRadius: BorderRadius.all(Radius.circular(10))),
                      padding: EdgeInsets.all(20 * globals.scaleParam),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.delivery_dining,
                            color:
                                delivery ? Colors.black : Colors.grey.shade400,
                          ),
                          SizedBox(
                            width: 10 * globals.scaleParam,
                          ),
                          Text(
                            "Доставка",
                            style: TextStyle(
                              color: delivery
                                  ? Colors.black
                                  : Colors.grey.shade400,
                              fontWeight: FontWeight.w700,
                              fontSize: 32 * globals.scaleParam,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                Flexible(
                  flex: 1,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        delivery = false;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                          color: delivery ? Colors.grey.shade100 : Colors.white,
                          borderRadius: BorderRadius.all(Radius.circular(10))),
                      padding: EdgeInsets.all(20 * globals.scaleParam),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.store,
                            color:
                                delivery ? Colors.grey.shade400 : Colors.black,
                          ),
                          SizedBox(
                            width: 10 * globals.scaleParam,
                          ),
                          Text(
                            "Самовывоз",
                            style: TextStyle(
                              color: delivery
                                  ? Colors.grey.shade400
                                  : Colors.black,
                              fontWeight: FontWeight.w700,
                              fontSize: 32 * globals.scaleParam,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: MediaQuery.sizeOf(context).height < 700 * globals.scaleParam
                ? 300 * globals.scaleParam
                : 650 * globals.scaleParam,
            decoration: BoxDecoration(
                border: Border.all(
                  width: 2,
                  color: Colors.grey.shade100,
                ),
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(10))),
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
                      itemId: item["item_id"],
                      categoryId: "",
                      categoryName: "",
                      scroll: 0,
                    ),
                    widget.items.length - 1 != index
                        ? Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 32 * globals.scaleParam,
                              vertical: 10 * globals.scaleParam,
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
          isAddressesLoading
              ? Shimmer.fromColors(
                  baseColor:
                      Theme.of(context).colorScheme.secondary.withOpacity(0.05),
                  highlightColor: Theme.of(context).colorScheme.secondary,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 20 * globals.scaleParam),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                        color: Colors.white,
                      ),
                      width: double.infinity,
                      height: 100 * globals.scaleParam,
                    ),
                  ),
                )
              : delivery
                  ? Container(
                      padding: EdgeInsets.symmetric(
                          vertical: 20 * globals.scaleParam),
                      decoration: BoxDecoration(
                          border: Border.all(
                            width: 2,
                            color: Colors.grey.shade100,
                          ),
                          color: Colors.white,
                          borderRadius: BorderRadius.all(Radius.circular(10))),
                      margin: EdgeInsets.symmetric(
                          horizontal: 20 * globals.scaleParam),
                      // This should be null only if widget.user doesn't have any addresses, else there will be widget.user address
                      // child: currentAddressWidget ??
                      child: currentAddress.isNotEmpty
                          ? GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Flexible(
                                    flex: 4,
                                    fit: FlexFit.tight,
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                "Ваш адрес: ${currentAddress["name"]}",
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
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                currentAddress["address"],
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
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Flexible(
                                    child: Icon(
                                      Icons.add_box_rounded,
                                      size: 50 * globals.scaleParam,
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
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
                                  _getClientAddresses();
                                  print(_getAddresses());
                                });
                              },
                            )
                          : TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PickAddressPage(
                                      client: widget.user,
                                      business: widget.business,
                                      isFromCreateOrder: true,
                                    ),
                                  ),
                                ).then((value) {
                                  _getClientAddresses();
                                  print(_getAddresses());
                                });
                              },
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Text(
                                    "Добавьте адрес доставки",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 32 * globals.scaleParam,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary,
                                    ),
                                  ),
                                  Icon(
                                    Icons.add_box_rounded,
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                    size: 50 * globals.scaleParam,
                                  ),
                                ],
                              ),
                            ),
                    )
                  : Container(
                      padding: EdgeInsets.symmetric(
                          vertical: 20 * globals.scaleParam),
                      decoration: BoxDecoration(
                          border: Border.all(
                            width: 2,
                            color: Colors.grey.shade100,
                          ),
                          color: Colors.white,
                          borderRadius: BorderRadius.all(Radius.circular(10))),
                      margin: EdgeInsets.symmetric(
                          horizontal: 20 * globals.scaleParam),
                      // This should be null only if widget.user doesn't have any addresses, else there will be widget.user address
                      // child: currentAddressWidget ??
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Flexible(
                                flex: 4,
                                fit: FlexFit.tight,
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            "Самовывозом: ${widget.business["name"]}",
                                            style: TextStyle(
                                              fontSize: 32 * globals.scaleParam,
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            widget.business["address"],
                                            style: TextStyle(
                                              fontSize: 32 * globals.scaleParam,
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Flexible(
                                child: Icon(
                                  Icons.add_box_rounded,
                                  size: 50 * globals.scaleParam,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
          delivery
              ? Container(
                  decoration: BoxDecoration(
                      border: Border.all(
                        width: 2,
                        color: Colors.grey.shade100,
                      ),
                      color: Colors.white,
                      borderRadius: BorderRadius.all(Radius.circular(10))),
                  margin: EdgeInsets.symmetric(
                      horizontal: 20 * globals.scaleParam,
                      vertical: 10 * globals.scaleParam),
                  padding: EdgeInsets.all(30 * globals.scaleParam),
                  child: Row(
                    children: [
                      Flexible(
                        flex: 2,
                        fit: FlexFit.tight,
                        child: Text(
                          "Доставка:",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 32 * globals.scaleParam,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                        ),
                      ),
                      Flexible(
                        flex: 2,
                        fit: FlexFit.tight,
                        child: Text(
                          "${widget.deliveryInfo["distance"]} м",
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 32 * globals.scaleParam,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                        ),
                      ),
                      Flexible(
                        fit: FlexFit.tight,
                        child: Text(
                          "-",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 32 * globals.scaleParam,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                        ),
                      ),
                      Flexible(
                        flex: 2,
                        fit: FlexFit.tight,
                        child: Text(
                          "${widget.deliveryInfo["price"]} ₸",
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 32 * globals.scaleParam,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : SizedBox(),
          Container(
            decoration: BoxDecoration(
                border: Border.all(
                  width: 2,
                  color: Colors.grey.shade100,
                ),
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(10))),
            margin: EdgeInsets.symmetric(horizontal: 20 * globals.scaleParam),
            padding: EdgeInsets.all(30 * globals.scaleParam),
            child: Column(
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.user.isEmpty
                            ? "Счёт на каспи:"
                            : widget.client.isEmpty
                                ? "Счёт на каспи: ${widget.user["login"].toString()}" //! TODO: CHANGE IF NOT KASPI BUT CASH
                                : "Счёт на каспи: ${widget.client["login"].toString()}",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 32 * globals.scaleParam,
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                      ),
                    )
                  ],
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        "Сумма к оплате: ${globals.formatCost(widget.finalSum.toString()).toString()} ₸",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 32 * globals.scaleParam,
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
                border: Border.all(
                  width: 2,
                  color: Colors.grey.shade100,
                ),
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(10))),
            margin: EdgeInsets.symmetric(
                horizontal: 20 * globals.scaleParam,
                vertical: 10 * globals.scaleParam),
            padding: EdgeInsets.all(30 * globals.scaleParam),
            child: ElevatedButton(
              onPressed:
                  isCartLoading || isAddressesLoading || currentAddress.isEmpty
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
                                finalSum: widget.finalSum,
                              ),
                            ),
                          );
                        },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Text(
                    "Подтвердить заказ",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 32 * globals.scaleParam,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
