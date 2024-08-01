import 'dart:async';

import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/findCreateUserPage.dart';
import '../globals.dart' as globals;
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/createOrder.dart';
import 'package:naliv_delivery/shared/itemCards.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key, required this.business, required this.user});

  final Map<dynamic, dynamic> business;
  final Map user;

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage>
    with SingleTickerProviderStateMixin {
  late List items = [];
  int itemsAmount = 0;
  late Map<String, dynamic> cartInfo = {};
  late AnimationController animController;
  final Duration animDuration = Duration(milliseconds: 250);

  Map<String, dynamic> client = {};
  int localSum = 0;
  int localDiscount = 0;
  int distance = 0;
  int bonusSum = 0;
  int price = 0;
  bool isCartLoading = true;
  bool dismissingItem = false;

  // int userBonusPoints = 50000;
  // int maxBonusPointsToSpend = 0;

  // int bonusPercent = 10;

  // void changeBonusPercent(int amount) {
  //   setState(() {
  //     maxBonusPointsToSpend = (localSum * 0.3).round();
  //   });
  //   if (0 <= amount && amount <= 30) {
  //     switch (amount) {
  //       case 0:
  //         setState(() {
  //           bonusPercent = amount;
  //           bonusSum = localSum * 0;
  //         });
  //         break;
  //       case 10:
  //         if ((localSum * 0.1).round() > userBonusPoints) {
  //           setState(() {
  //             bonusPercent = 0;
  //           });
  //           changeBonusPercent(0);
  //         } else {
  //           setState(() {
  //             bonusPercent = amount;
  //             bonusSum = (localSum * 0.1).round();
  //           });
  //         }
  //         break;
  //       case 20:
  //         if ((localSum * 0.2).round() > userBonusPoints) {
  //           setState(() {
  //             bonusPercent = 10;
  //           });
  //           changeBonusPercent(10);
  //         } else {
  //           setState(() {
  //             bonusPercent = amount;
  //             bonusSum = (localSum * 0.2).round();
  //           });
  //         }
  //         break;
  //       case 30:
  //         if ((localSum * 0.3).round() > userBonusPoints) {
  //           setState(() {
  //             bonusPercent = 20;
  //           });
  //           changeBonusPercent(20);
  //         } else {
  //           setState(() {
  //             bonusPercent = amount;
  //             bonusSum = (localSum * 0.3).round();
  //           });
  //         }
  //         break;
  //       default:
  //         print("No, bonus percent can only be [0, 10, 20, 30]");
  //         break;
  //     }
  //   }
  // }

  Future<void> _getCart() async {
    Map<String, dynamic> cart = await getCart(widget.business["business_id"]);
    print(cart);

    // Map<String, dynamic>? cartInfo = await getCartInfo();
    print(cartInfo);

    // if (cart["sum"] == null || cart["cart"]) {
    //   return;
    // }

    setState(() {
      items = cart["cart"] ?? [];
      itemsAmount = 0;
      localSum = int.parse(cart["sum"] ?? "0");
      distance = double.parse((cart["distance"] ?? 0).toString()).round();
      price = (price / 100).round() * 100;
      isCartLoading = false;
      itemsAmount;
    });

    double dist = distance / 1000;
    dist = (dist * 2).round() / 2;
    if (dist <= 1.5) {
      price = 700;
    } else {
      if (dist < 5) {
        price = ((dist - 1.5) * 300 + 700).toInt();
      } else {
        price = ((dist - 1.5) * 250 + 700).toInt();
      }
    }

    for (dynamic item in items) {
      itemsAmount += int.parse(item["amount"]);
    }
    setState(() {
      itemsAmount;
      price = (price / 100).round() * 100;
    });
  }

  Future<bool> _deleteFromCart(String itemId) async {
    bool? result = await deleteFromCart(itemId);
    result ??= false;

    print(result);
    return Future(() => result!);
  }

  void _setAnimationController() {
    animController = BottomSheet.createAnimationController(this);

    animController.duration = animDuration;
    animController.reverseDuration = animDuration;
    animController.drive(CurveTween(curve: Curves.easeIn));
  }

  void updateDataAmount(int index, int newDataAmount) {
    if (newDataAmount == 0) {
      items.removeAt(index);
    } else {
      items[index]["amount"] = newDataAmount.toString();
    }
    setState(() {
      items;
    });
    localSum = 0;
    itemsAmount = 0;
    for (dynamic item in items) {
      localSum += (int.parse(item["price"]) * int.parse(item["amount"]));
      itemsAmount += int.parse(item["amount"]);
    }
    // if ((localSum * (bonusPercent / 100)).round() >
    //     userBonusPoints) {
    //   print(
    //       "NOT ENOUGH BONUS POINTS, NEED (${(localSum * (bonusPercent / 100)).round()}), HAVE ($userBonusPoints)");
    // } else {
    //   print(
    //       "ENOUGH BONUSES, NEED (${(localSum * (bonusPercent / 100)).round()}), HAVE ($userBonusPoints)");
    // }
    // changeBonusPercent(bonusPercent);
    setState(() {
      localSum;
      itemsAmount;
    });
  }

  void updatePrices(int indexUpdatePrice) {
    items.removeAt(indexUpdatePrice);
    setState(() {
      items;
    });
    localSum = 0;
    itemsAmount = 0;
    if (items.isNotEmpty) {
      for (dynamic item in items) {
        localSum += (int.parse(item["price"]) * int.parse(item["amount"]));
        itemsAmount += int.parse(item["amount"]);
      }
    } else {
      setState(() {
        localSum = 0;
      });
    }
    setState(() {
      localSum;
      itemsAmount;
    });
  }

  // bool isCartLoading = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _setAnimationController();

    _getCart();
    // Future.delayed( Duration(milliseconds: 0), () async {
    //   setState(() {
    //     isCartLoading = true;
    //   });
    //   await _getCart();
    //   if (mounted) {
    //     setState(() {
    //       localSum = int.parse(sum);
    //       for (dynamic item in items) {
    //         if (item["previous_price"] != null) {
    //           localDiscount += int.parse(item["price"]) -
    //               int.parse(item["previous_price"] ?? "0");
    //         }
    //       }
    //       isCartLoading = false;
    //     });
    //   }
    //   await getUser().then((value) {
    //     if (value != null && mounted) {
    //       setState(() {
    //         client = value;
    //       });
    //     }
    //   });
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20 * globals.scaleParam),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  Flexible(
                    flex: 7,
                    fit: FlexFit.tight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                "Корзина",
                                style: TextStyle(
                                    fontSize: 40 * globals.scaleParam),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                "${widget.business["name"]} ${widget.business["address"]}",
                                maxLines: 1,
                                style: TextStyle(
                                    fontSize: 32 * globals.scaleParam),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: items.isNotEmpty || isCartLoading
          ? Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 30 * globals.scaleParam),
              child: Row(
                children: [
                  MediaQuery.sizeOf(context).width >
                          MediaQuery.sizeOf(context).height
                      ? Flexible(
                          flex: 2,
                          fit: FlexFit.tight,
                          child: SizedBox(),
                        )
                      : SizedBox(),
                  Flexible(
                    fit: FlexFit.tight,
                    child: ElevatedButton(
                      onPressed: items.isNotEmpty && !dismissingItem
                          ? () {
                              // ! TODO: UNCOMMENT FOR PRODUCTION
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) {
                                    return CreateOrderPage(
                                      business: widget.business,
                                      finalSum: localSum,
                                      items: items,
                                      itemsAmount: itemsAmount,
                                      user: widget.user,
                                      deliveryInfo: Map.from(
                                        {"distance": distance, "price": price},
                                      ),
                                    );
                                  },
                                ),
                              );
                            }
                          : null,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            flex: 2,
                            fit: FlexFit.tight,
                            child: Text(
                              "Оформить заказ",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 42 * globals.scaleParam,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                          Flexible(
                            fit: FlexFit.tight,
                            child: Text(
                              "${globals.formatCost(localSum.toString())} ₸",
                              textAlign: TextAlign.justify,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 44 * globals.scaleParam,
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
            )
          // ? Padding(
          //     padding:
          //         EdgeInsets.symmetric(horizontal: 30 * globals.scaleParam),
          //     child: ElevatedButton(
          // onPressed: items.isNotEmpty && !dismissingItem
          //     ? () {
          //         // Navigator.push(
          //         //   context,
          //         //   MaterialPageRoute(
          //         //     builder: (context) {
          //         //       return FindCreateUserPage(
          //         //         business: widget.business,
          //         //       );
          //         //     },
          //         //   ),
          //         // );
          //         Navigator.push(
          //           context,
          //           MaterialPageRoute(
          //             builder: (context) {
          //               return CreateOrderPage(
          //                 business: widget.business,
          //                 finalSum: localSum,
          //                 items: items,
          //                 itemsAmount: itemsAmount,
          //                 user: widget.user,
          //                 deliveryInfo: Map.from(
          //                   {"distance": distance, "price": price},
          //                 ),
          //               );
          //             },
          //           ),
          //         );
          //       }
          //     : null,
          // child: Row(
          //   mainAxisAlignment: MainAxisAlignment.center,
          //   crossAxisAlignment: CrossAxisAlignment.center,
          //   children: [
          //     Flexible(
          //       flex: 2,
          //       fit: FlexFit.tight,
          //       child: Text(
          //         "Оформить заказ",
          //         style: TextStyle(
          //           fontWeight: FontWeight.w900,
          //           fontSize: 42 * globals.scaleParam,
          //           color: Theme.of(context).colorScheme.onPrimary,
          //         ),
          //       ),
          //     ),
          //     Flexible(
          //       fit: FlexFit.tight,
          //       child: Text(
          //         "${globals.formatCost(localSum.toString())} ₸",
          //         textAlign: TextAlign.justify,
          //         style: TextStyle(
          //           fontWeight: FontWeight.w900,
          //           fontSize: 44 * globals.scaleParam,
          //           color: Theme.of(context).colorScheme.onPrimary,
          //         ),
          //       ),
          //     ),
          //   ],
          // ),
          //     ),
          //   )
          : SizedBox(),
      body: isCartLoading == false
          ? items.isEmpty
              ? Center(
                  child: Text(
                    "Ваша корзина пуста",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 44 * globals.scaleParam,
                      color: Colors.black38,
                    ),
                  ),
                )
              : ListView(
                  children: [
                    ListView.builder(
                      primary: false,
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        items[index];
                        return Column(
                          children: [
                            Dismissible(
                              // Each Dismissible must contain a Key. Keys allow Flutter to
                              // uniquely identify widgets.
                              key: Key(items[index]["item_id"]),
                              confirmDismiss: (direction) async {
                                setState(() {
                                  dismissingItem = true;
                                });
                                bool result = await _deleteFromCart(
                                    items[index]["item_id"]);

                                if (result) {
                                  updatePrices(index);
                                }

                                setState(() {
                                  dismissingItem = false;
                                });
                                return result;
                              },
                              onDismissed: ((direction) {
                                print(MediaQuery.of(context).size.height *
                                    ((4 - items.length) / 10));
                              }),
                              // Provide a function that tells the app
                              // what to do after an item has been swiped away.

                              // Show a red background as the item is swiped away.
                              background: SizedBox(
                                width: 200 * globals.scaleParam,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: MediaQuery.of(context).size.width *
                                          0.7,
                                      alignment: Alignment.center,
                                      padding: EdgeInsets.only(right: 10),
                                      color: Colors.grey.shade100,
                                    ),
                                    Container(
                                      width: MediaQuery.of(context).size.width *
                                          0.3,
                                      alignment: Alignment.center,
                                      padding: EdgeInsets.only(right: 10),
                                      color: Colors.grey.shade100,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.delete),
                                          Text("Удалить")
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                              child: Column(
                                children: [
                                  index == 0
                                      ? SizedBox(
                                          height: 20 * globals.scaleParam,
                                        )
                                      : SizedBox(),
                                  ItemCardMinimal(
                                    itemId: items[index]["item_id"],
                                    element: items[index],
                                    updateExternalInfo: updateDataAmount,
                                    business: widget.business,
                                    index: index,
                                    categoryId: "",
                                    categoryName: "",
                                    scroll: 0,
                                  ),
                                  items.length - 1 != index
                                      ? Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal:
                                                  16 * globals.scaleParam),
                                          child: Divider(),
                                        )
                                      : Container(),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    // Makes buy button stay in the same place imitating other cards in listView
                    Column(
                      children: [
                        SizedBox(
                          width: MediaQuery.of(context).size.width,
                          height: items.length < 4
                              ? (165 * globals.scaleParam) * (4 - items.length)
                              : 0,
                        ),
                        Divider(
                          color: Colors.transparent,
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 40 * globals.scaleParam,
                    ),
                    Divider(),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 45 * globals.scaleParam,
                        vertical: 20 * globals.scaleParam,
                      ),
                      child: Row(
                        children: [
                          Text(
                            "Не забудьте также",
                            style: TextStyle(
                              fontSize: 48 * globals.scaleParam,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 400 * globals.scaleParam,
                      child: ListView.builder(
                        // itemExtent: MediaQuery.sizeOf(context).width * globals.scaleParam,
                        scrollDirection: Axis.horizontal,
                        itemCount: 10,
                        itemBuilder: (context, index) {
                          return AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              margin: EdgeInsets.all(20 * globals.scaleParam),
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(10)),
                                color: Colors.black12,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return Column(
                                    children: [
                                      Flexible(
                                        flex: 20,
                                        fit: FlexFit.tight,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                "Сигареты/Закуски",
                                                style: TextStyle(
                                                  fontSize:
                                                      36 * globals.scaleParam,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Flexible(
                                        flex: 7,
                                        fit: FlexFit.tight,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black87,
                                          ),
                                          child: Row(
                                            children: [
                                              Flexible(
                                                fit: FlexFit.tight,
                                                child: Text(
                                                  "0 тг",
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize:
                                                        36 * globals.scaleParam,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              Flexible(
                                                fit: FlexFit.tight,
                                                child: IconButton(
                                                  onPressed: () {},
                                                  icon: Icon(
                                                    Icons.add_rounded,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      height: 250 * globals.scaleParam,
                    ),
                  ],
                )
          : LinearProgressIndicator(),
      // body: FutureBuilder(
      //   future: _getCart(),
      //   builder: (context, snapshot) {
      //     if (snapshot.hasData) {
      //       if (snapshot.data!["cart"].isEmpty) {
      //         return Center(
      //           child: Text(
      //             "Ваша корзина пуста",
      //             style: TextStyle(
      //                 fontSize: 40 * globals.scaleParam, color: Colors.grey),
      //           ),
      //         );
      //       } else {
      //         if (buyButtonState != null) {
      //           WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      //             buyButtonState!(() {});
      //           });
      //         }
      //         localSum = int.parse(snapshot.data!["sum"]);
      //         items = snapshot.data!["cart"];
      //         print(items);
      //         localSum = snapshot.data!["sum"];
      //         int distance = double.parse(snapshot.data!["distance"]).round();
      // double dist = distance / 1000;
      // dist = (dist * 2).round() / 2;
      // if (dist <= 1.5) {
      //   price = 700;
      // } else {
      //   if (dist < 5) {
      //     price = ((dist - 1.5) * 300 + 700).toInt();
      //   } else {
      //     price = ((dist - 1.5) * 250 + 700).toInt();
      //   }
      // }
      // price = (price / 100).round() * 100;
      // return ListView(
      //   children: [
      //     ListView.builder(
      //       primary: false,
      //       shrinkWrap: true,
      //       itemCount: items.length,
      //       itemBuilder: (context, index) {
      //         items[index];
      //         return Column(
      //           children: [
      //             Dismissible(
      //               // Each Dismissible must contain a Key. Keys allow Flutter to
      //               // uniquely identify widgets.
      //               key: Key(items[index]["item_id"]),
      //               confirmDismiss: (direction) async {
      //                 bool result = await _deleteFromCart(
      //                     items[index]["item_id"]);

      //                 if (result) {
      //                   updatePrices(index);
      //                 }

      //                 return result;
      //               },
      //               onDismissed: ((direction) {
      //                 print(MediaQuery.of(context).size.height *
      //                     ((4 - items.length) / 10));
      //               }),
      //               // Provide a function that tells the app
      //               // what to do after an item has been swiped away.

      //               // Show a red background as the item is swiped away.
      //               background: SizedBox(
      //                 width: 200 * globals.scaleParam,
      //                 child: Row(
      //                   mainAxisAlignment: MainAxisAlignment.end,
      //                   crossAxisAlignment: CrossAxisAlignment.center,
      //                   mainAxisSize: MainAxisSize.min,
      //                   children: [
      //                     Container(
      //                       width:
      //                           MediaQuery.of(context).size.width * 0.7,
      //                       alignment: Alignment.center,
      //                       padding: EdgeInsets.only(right: 10),
      //                       color: Colors.grey.shade100,
      //                     ),
      //                     Container(
      //                       width:
      //                           MediaQuery.of(context).size.width * 0.3,
      //                       alignment: Alignment.center,
      //                       padding: EdgeInsets.only(right: 10),
      //                       color: Colors.grey.shade100,
      //                       child: Column(
      //                         mainAxisAlignment:
      //                             MainAxisAlignment.center,
      //                         children: [
      //                           Icon(Icons.delete),
      //                           Text("Удалить")
      //                         ],
      //                       ),
      //                     )
      //                   ],
      //                 ),
      //               ),
      //               child: Column(
      //                 children: [
      //                   index == 0
      //                       ? SizedBox(
      //                           height: 20 * globals.scaleParam,
      //                         )
      //                       : SizedBox(),
      //                   ItemCardMinimal(
      //                     itemId: items[index]["item_id"],
      //                     element: items[index],
      //                     updateExternalInfo: updateDataAmount,
      //                     business: widget.business,
      //                     index: index,
      //                     categoryId: "",
      //                     categoryName: "",
      //                     scroll: 0,
      //                   ),
      //                   items.length - 1 != index
      //                       ? Padding(
      //                           padding: EdgeInsets.symmetric(
      //                               horizontal:
      //                                   16 * globals.scaleParam),
      //                           child: Divider(),
      //                         )
      //                       : Container(),
      //                 ],
      //               ),
      //             ),
      //           ],
      //         );
      //       },
      //     ),
      //     // Makes buy button stay in the same place imitating other cards in listView
      //     Column(
      //       children: [
      //         SizedBox(
      //           width: MediaQuery.of(context).size.width,
      //           height: items.length < 4
      //               ? (165 * globals.scaleParam) * (4 - items.length)
      //               : 0,
      //         ),
      //         Divider(
      //           color: Colors.transparent,
      //         ),
      //       ],
      //     ),
      //     SizedBox(
      //       height: 40 * globals.scaleParam,
      //     ),
      //     Divider(),
      //     Padding(
      //       padding: EdgeInsets.symmetric(
      //         horizontal: 45 * globals.scaleParam,
      //         vertical: 20 * globals.scaleParam,
      //       ),
      //       child: Row(
      //         children: [
      //           Text(
      //             "Часто заказывают",
      //             style: TextStyle(
      //               fontSize: 48 * globals.scaleParam,
      //               fontWeight: FontWeight.w700,
      //               color: Colors.black,
      //             ),
      //           ),
      //         ],
      //       ),
      //     ),
      //     SizedBox(
      //       width: double.infinity,
      //       height: 400 * globals.scaleParam,
      //       child: ListView.builder(
      //         // itemExtent: MediaQuery.sizeOf(context).width * globals.scaleParam,
      //         scrollDirection: Axis.horizontal,
      //         itemCount: 10,
      //         itemBuilder: (context, index) {
      //           return AspectRatio(
      //             aspectRatio: 1,
      //             child: Container(
      //               margin: EdgeInsets.all(20 * globals.scaleParam),
      //               decoration: BoxDecoration(
      //                 borderRadius:
      //                     BorderRadius.all(Radius.circular(10)),
      //                 color: Colors.black12,
      //               ),
      //               clipBehavior: Clip.antiAlias,
      //               child: LayoutBuilder(
      //                 builder: (context, constraints) {
      //                   return Column(
      //                     children: [
      //                       Flexible(
      //                         flex: 20,
      //                         fit: FlexFit.tight,
      //                         child: Row(
      //                           mainAxisAlignment:
      //                               MainAxisAlignment.center,
      //                           children: [
      //                             Flexible(
      //                               child: Text(
      //                                 "Сигареты/Закуски",
      //                                 style: TextStyle(
      //                                   fontSize:
      //                                       36 * globals.scaleParam,
      //                                   fontWeight: FontWeight.w700,
      //                                   color: Colors.black,
      //                                 ),
      //                               ),
      //                             ),
      //                           ],
      //                         ),
      //                       ),
      //                       Flexible(
      //                         flex: 7,
      //                         fit: FlexFit.tight,
      //                         child: Container(
      //                           decoration: BoxDecoration(
      //                             color: Colors.black87,
      //                           ),
      //                           child: Row(
      //                             children: [
      //                               Flexible(
      //                                 fit: FlexFit.tight,
      //                                 child: Text(
      //                                   "0 тг",
      //                                   textAlign: TextAlign.center,
      //                                   style: TextStyle(
      //                                     fontSize:
      //                                         36 * globals.scaleParam,
      //                                     fontWeight: FontWeight.w700,
      //                                     color: Colors.white,
      //                                   ),
      //                                 ),
      //                               ),
      //                               Flexible(
      //                                 fit: FlexFit.tight,
      //                                 child: IconButton(
      //                                   onPressed: () {},
      //                                   icon: Icon(
      //                                     Icons.add_rounded,
      //                                     color: Colors.white,
      //                                   ),
      //                                 ),
      //                               ),
      //                             ],
      //                           ),
      //                         ),
      //                       ),
      //                     ],
      //                   );
      //                 },
      //               ),
      //             ),
      //           );
      //         },
      //       ),
      //     ),
      //     SizedBox(
      //       height: 250 * globals.scaleParam,
      //     ),
      //   ],
      // );
      //       }
      //     } else if (snapshot.hasError) {
      //       return Center(
      //         child: SizedBox(
      //           width: 350 * globals.scaleParam,
      //           child: Column(
      //             mainAxisAlignment: MainAxisAlignment.center,
      //             children: [
      //               Flexible(
      //                 child: Text(
      //                   "Произошла ошибка при загрузке корзины.",
      //                   textAlign: TextAlign.center,
      //                   style: TextStyle(
      //                       fontSize: 40 * globals.scaleParam,
      //                       color: Colors.grey),
      //                 ),
      //               ),
      //               Flexible(
      //                 child: ElevatedButton(
      //                   onPressed: () {
      //                     setState(() {});
      //                   },
      //                   child: Text(
      //                     "Повторить",
      //                     textAlign: TextAlign.center,
      //                     style: TextStyle(fontSize: 40 * globals.scaleParam),
      //                   ),
      //                 ),
      //               ),
      //             ],
      //           ),
      //         ),
      //       );
      //     } else {
      //       return LinearProgressIndicator();
      //     }
      //   },
      // ),

      // : Center(
      //     child: Column(
      //       mainAxisSize: MainAxisSize.min,
      //       children: [
      //         SizedBox(
      //           width: MediaQuery.of(context).size.width * 0.8,
      //           child: Text(
      //             "Ваша корзина пуста",
      //             textAlign: TextAlign.center,
      //             style: TextStyle(
      //               color: Theme.of(context).colorScheme.secondary,
      //               fontSize: 16,
      //               fontWeight: FontWeight.w500,
      //             ),
      //           ),
      //         ),
      //       ],
      //     ),
      //   ),
    );
  }
}
