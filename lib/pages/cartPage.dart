import 'dart:async';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:naliv_delivery/pages/preLoadDataPage.dart';
import 'package:naliv_delivery/pages/preLoadOrderPage.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../globals.dart' as globals;
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/createOrder.dart';
import 'package:naliv_delivery/shared/itemCards.dart';

class CartPage extends StatefulWidget {
  const CartPage(
      {super.key,
      required this.business,
      required this.items,
      required this.sum,
      required this.delivery,
      required this.tax});

  final Map<dynamic, dynamic> business;
  final List items;
  final int sum;
  final int delivery;
  final int tax;

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage>
    with SingleTickerProviderStateMixin {
  double itemsAmount = 0;
  late Map<String, dynamic> cartInfo = {};
  late List recommendedItems = [];
  late AnimationController animController;
  final Duration animDuration = Duration(milliseconds: 250);
  int sum = 0;
  Map<String, dynamic> client = {};
  List _items = [];
  bool isLoading = false;
  Map cart = {};
  void updateDataAmount(List newCart, int index) {
    _getItems();
    _items[index]["cart"] = newCart;
  }

  Future<void> _getItems() async {
    setState(() {
      _items = widget.items;
      sum = widget.sum;
    });
  }

  _getCart() {
    getCart(widget.business["business_id"]).then((value) {
      setState(() {
        cart = value;
        _items = value["cart"] ?? [];
        sum = double.parse((value["sum"] ?? 0.0).toString()).round();
      });
    });
  }

  @override
  void initState() {
    _getItems();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            automaticallyImplyLeading: false,
            leading: IconButton(
                onPressed: () {
                  Navigator.pop(context, true);
                },
                icon: Icon(Icons.arrow_back_ios)),
            backgroundColor: Colors.black,
            surfaceTintColor: Colors.black,
            floating: false,
            pinned: true,
            centerTitle: false,
            title: Text("Корзина",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          // SliverToBoxAdapter(
          //   child: Text(cart.toString()),
          // ),
          _items.length == 0
              ? SliverFillRemaining(
                  child: Center(
                    child: Text("Похоже здесь ничего нет"),
                  ),
                )
              : SliverList.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final Map<String, dynamic> item = _items[index];

                    return item["amount_b"] <= 0
                        ? Container()
                        : Container(
                            margin: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.black),
                            child: GestureDetector(
                              // onTap: () {
                              //   showMaterialModalBottomSheet(
                              //     context: context,
                              //     builder: (context) => StatefulBuilder(
                              //       builder: (context, setState) {
                              //         double amount =
                              //             item["amount_b"].runtimeType == int
                              //                 ? item["amount_b"].toDouble()
                              //                 : item["amount_b"];
                              //         return Container(
                              //           height: 300,
                              //           color: Color(0xFF121212),
                              //           child: Row(
                              //             children: [
                              //               IconButton(
                              //                   onPressed: () {
                              //                     setState(() {
                              //                       amount--;
                              //                     });
                              //                   },
                              //                   icon: Icon(Icons.add)),
                              //               Text(amount.toString()),
                              //             ],
                              //           ),
                              //         );
                              //       },
                              //     ),
                              //   );
                              // },
                              child: Container(
                                padding: EdgeInsets.all(10),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                        flex: 2,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            Text(
                                              item["name"],
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12),
                                            ),
                                            item["selected_options"] == null
                                                ? Container()
                                                : ListView.builder(
                                                    primary: false,
                                                    shrinkWrap: true,
                                                    itemCount:
                                                        item["selected_options"]
                                                            .length,
                                                    itemBuilder:
                                                        (context, index2) {
                                                      Map option = item[
                                                              "selected_options"]
                                                          [index2];
                                                      return Text(
                                                          option["name"]);
                                                    },
                                                  ),
                                          ],
                                        )),
                                    Flexible(
                                        flex: 2,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            color: Color(0xFF121212),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              IconButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      isLoading = true;
                                                    });
                                                    try {
                                                      changeCartItemByCartItemId(
                                                        item["cart_item_id"],
                                                        (item["amount_b"] -
                                                                item[
                                                                    "quantity"])
                                                            .toDouble(),
                                                        widget.business[
                                                            "business_id"],
                                                      ).then((v) {
                                                        if (v["result"]) {
                                                          if (v["amount"] ==
                                                              null) {
                                                            _getCart();
                                                          }
                                                          print("succes");
                                                          if (v["amount"] ==
                                                              null) {
                                                            _getCart();
                                                          } else {
                                                            setState(() {
                                                              item["amount_b"] =
                                                                  double.parse(v[
                                                                      "amount"]);
                                                              isLoading = false;
                                                            });
                                                          }

                                                          _getCart();
                                                        } else {
                                                          _getCart();

                                                          print("error");
                                                        }
                                                      });
                                                    } catch (e) {
                                                      _getCart();
                                                    }
                                                  },
                                                  icon: Icon(Icons.remove)),
                                              Text(
                                                item["amount_b"].toString(),
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              IconButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      isLoading = true;
                                                    });
                                                    try {
                                                      changeCartItemByCartItemId(
                                                        item["cart_item_id"],
                                                        (item["amount_b"] +
                                                                item[
                                                                    "quantity"])
                                                            .toDouble(),
                                                        widget.business[
                                                            "business_id"],
                                                      ).then((v) {
                                                        if (v["result"]) {
                                                          if (v["amount"] ==
                                                              null) {
                                                            _getCart();
                                                          }
                                                          print("succes");

                                                          if (v["amount"] ==
                                                              null) {
                                                            _getCart();
                                                          } else {
                                                            setState(() {
                                                              item["amount_b"] =
                                                                  double.parse(v[
                                                                      "amount"]);
                                                              isLoading = false;
                                                            });
                                                          }

                                                          _getCart();
                                                        } else {
                                                          _getCart();

                                                          print("error");
                                                        }
                                                      });
                                                    } catch (e) {
                                                      _getCart();
                                                    }
                                                  },
                                                  icon: Icon(Icons.add)),
                                            ],
                                          ),
                                        ))
                                  ],
                                ),
                              ),
                            ));
                  },
                ),
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Итого",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    sum.toString() + "₸",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  )
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
              child: Container(
            padding: EdgeInsets.all(10),
            child: ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) {
                              return PreLoadOrderPage(
                                business: widget.business,
                              );
                            },
                          ),
                        );
                      },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Продолжить",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                  ],
                )),
          ))
        ],
      ),
    );
  }
}
