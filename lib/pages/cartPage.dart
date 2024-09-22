import 'dart:async';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

class _CartPageState extends State<CartPage> with SingleTickerProviderStateMixin {
  late List items = [];
  double itemsAmount = 0;
  late Map<String, dynamic> cartInfo = {};
  late List recommendedItems = [];
  late AnimationController animController;
  final Duration animDuration = Duration(milliseconds: 250);

  Map<String, dynamic> client = {};
  int localSum = 0;
  int localDiscount = 0;
  int distance = 0;
  int bonusSum = 0;
  int price = 0;
  int taxes = 0;
  bool isCartLoading = true;
  bool dismissingItem = false;

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
      localSum = double.parse((cart["sum"] ?? 0.0).toString()).round();
      // distance = double.parse((cart["distance"] ?? 0.0).toString()).round();
      // price = (price / 100).round() * 100;
      price = double.parse((cart["delivery"] ?? 0.0).toString()).round();
      taxes = double.parse((cart["taxes"] ?? 0.0).toString()).round();
      isCartLoading = false;
      itemsAmount;
    });

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

    // for (dynamic item in items) {
    //   itemsAmount += double.parse(item["amount"].toString()).round();
    // }
    // setState(() {
    //   itemsAmount;
    //   price = (price / 100).round() * 100;
    // });
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
      itemsAmount += double.parse(item["amount"].toString());
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
        if (item["selected_options"] != null) {
          //! LOCATE AND CALCULATE PARENT_ITEM_AMOUNT FIRST!!!!!!
          for (Map selectedOption in item["selected_options"]) {
            if (selectedOption["parent_item_amount"] != 1 || item["selected_options"].last == selectedOption) {
              localSum += double.parse((item["price"] *
                          selectedOption["parent_item_amount"] *
                          (item["amount_b"] -
                              (item["promotions"] != null
                                  ? double.parse((item["amount_b"] / (item["promotions"][0]["add_amount"] + item["promotions"][0]["base_amount"]))
                                          .toString())
                                      .truncate()
                                  : 0)))
                      .toString())
                  .round();
              break;
            }
          }
          //! ONLY THEN CALCULATE ADDITIONAL COST OF THE BOTTLES AND ETC. WITHOUT PARENT_ITEM_AMOUNT
          for (Map selectedOption in item["selected_options"]) {
            localSum += double.parse(((selectedOption["price"] * item["amount_b"])).toString()).round();
          }
          itemsAmount += double.parse(item["amount_b"].toString());
        } else {
          localSum += double.parse((item["price"] *
                      (item["amount"] -
                          (item["promotions"] != null
                              ? double.parse(
                                      (item["amount"] / (item["promotions"][0]["add_amount"] + item["promotions"][0]["base_amount"])).toString())
                                  .truncate()
                              : 0)))
                  .toString())
              .round();
          itemsAmount += double.parse(item["amount"].toString());
        }
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

  Future<void> _getRecommendedSectionsItems() async {
    try {
      Map? responseList = await getItemsMain(0, widget.business["business_id"], "", "20");
      if (responseList != null) {
        List<dynamic> itemList = responseList["items"];
        // List<dynamic> itemList = responseList.map((data) => Item(data)).toList();

        if (mounted) {
          setState(() {
            recommendedItems.addAll(itemList.map((e) => e));
          });
        }
      }
    } catch (e) {
      print("error --> $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _setAnimationController();

    _getCart();
    _getRecommendedSectionsItems();
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
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          print("IT DIDN'T POPPED");
          Navigator.pop(context, true);
        } else {
          print("WELL DAMN. IT POPPED");
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        // appBar: AppBar(
        //   automaticallyImplyLeading: false,
        //   titleSpacing: 0,
        //   title: Padding(
        //     padding: EdgeInsets.symmetric(horizontal: 20 * globals.scaleParam),
        //     child: Column(
        //       mainAxisAlignment: MainAxisAlignment.start,
        //       crossAxisAlignment: CrossAxisAlignment.center,
        //       children: [
        //         Row(
        //           mainAxisSize: MainAxisSize.max,
        //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //           children: [
        //             Flexible(
        //               child: IconButton(
        //                 padding: EdgeInsets.zero,
        //                 onPressed: () {
        //                   Navigator.pop(context, true);
        //                 },
        //                 icon: Icon(Icons.arrow_back_rounded),
        //               ),
        //             ),
        //             Flexible(
        //               flex: 7,
        //               fit: FlexFit.tight,
        //               child: Column(
        //                 crossAxisAlignment: CrossAxisAlignment.center,
        //                 mainAxisAlignment: MainAxisAlignment.center,
        //                 children: [
        //                   Row(
        //                     mainAxisAlignment: MainAxisAlignment.center,
        //                     children: [
        //                       Flexible(
        //                         child: Text(
        //                           "Корзина",
        //                           style: TextStyle(
        //                               fontSize: 40 * globals.scaleParam),
        //                         ),
        //                       ),
        //                     ],
        //                   ),
        //                   // Row(
        //                   //   children: [
        //                   //     Flexible(
        //                   //       child: Text(
        //                   //         "${widget.business["name"]} ${widget.business["address"]}",
        //                   //         maxLines: 1,
        //                   //         style: TextStyle(fontSize: 32 * globals.scaleParam),
        //                   //       ),
        //                   //     ),
        //                   //   ],
        //                   // ),
        //                 ],
        //               ),
        //             ),
        //             Spacer()
        //           ],
        //         ),
        //       ],
        //     ),
        //   ),
        // ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: items.isNotEmpty || isCartLoading
            ? Padding(
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
                                        // itemsAmount: itemsAmount,
                                        user: widget.user,
                                        deliveryInfo: Map.from(
                                          {"distance": distance, "price": price, "taxes": taxes},
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
                                  color: Colors.white,
                                  fontVariations: <FontVariation>[FontVariation('wght', 800)],
                                  fontSize: 42 * globals.scaleParam,
                                ),
                              ),
                            ),
                            Flexible(
                              fit: FlexFit.tight,
                              child: Text(
                                "${globals.formatCost(localSum.toString())} ₸",
                                textAlign: TextAlign.justify,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontVariations: <FontVariation>[FontVariation('wght', 800)],
                                  fontSize: 44 * globals.scaleParam,
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
            : Padding(
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
                        onPressed: () {
                          Navigator.maybePop(context);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              fit: FlexFit.tight,
                              child: Text(
                                "За покупками!",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
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
                      Padding(
                          padding: EdgeInsets.only(left: 1 * globals.scaleParam, top: 15 * globals.scaleParam),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              IconButton(
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  Navigator.pop(context, true);
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
                                    children: [Text("Ваша корзина", style: Theme.of(context).textTheme.displayLarge)],
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${widget.business["name"]} ${widget.business["address"]}",
                                        style: TextStyle(
                                            fontFamily: "Raleway",
                                            fontVariations: <FontVariation>[FontVariation('wght', 600)],
                                            fontSize: 30 * globals.scaleParam),
                                      )
                                    ],
                                  ),
                                ],
                              )
                            ],
                          )),
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
                                key: Key(items[index]["item_id"].toString()),
                                confirmDismiss: (direction) async {
                                  setState(() {
                                    dismissingItem = true;
                                  });
                                  bool result = await _deleteFromCart(items[index]["item_id"].toString());

                                  if (result) {
                                    updatePrices(index);
                                  }

                                  setState(() {
                                    dismissingItem = false;
                                  });
                                  return result;
                                },
                                onDismissed: ((direction) {
                                  print(MediaQuery.of(context).size.height * ((4 - items.length) / 10));
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
                                        width: MediaQuery.of(context).size.width * 0.7,
                                        alignment: Alignment.center,
                                        padding: EdgeInsets.only(right: 10),
                                        color: Color.fromARGB(255, 228, 209, 209),
                                      ),
                                      Container(
                                        width: MediaQuery.of(context).size.width * 0.3,
                                        alignment: Alignment.center,
                                        padding: EdgeInsets.only(right: 10),
                                        color: Color.fromARGB(255, 228, 209, 209),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [Icon(Icons.delete), Text("Удалить")],
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    index == 0
                                        ? SizedBox(
                                            height: 5 * globals.scaleParam,
                                          )
                                        : SizedBox(),
                                    ItemCardMinimal(
                                      element: items[index],
                                      updateExternalInfo: updateDataAmount,
                                      business: widget.business,
                                      index: index,
                                      categoryId: "",
                                      categoryName: "",
                                      scroll: 0,
                                    ),
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
                            height: items.length < 4 ? (165 * globals.scaleParam) * (4 - items.length) : 0,
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
                      //!! ONLY FOR DEV RN
                      // Padding(
                      //   padding: EdgeInsets.symmetric(
                      //     horizontal: 45 * globals.scaleParam,
                      //     vertical: 20 * globals.scaleParam,
                      //   ),
                      //   child: Row(
                      //     children: [
                      //       Text(
                      //         "Не забудьте также",
                      //         style: TextStyle(
                      //           fontSize: 48 * globals.scaleParam,
                      //           fontWeight: FontWeight.w700,
                      //           color: Colors.black,
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                      // SizedBox(
                      //   width: double.infinity,
                      //   height: 400 * globals.scaleParam,
                      //   child: ListView.builder(
                      //     // itemExtent: MediaQuery.sizeOf(context).width * globals.scaleParam,
                      //     scrollDirection: Axis.horizontal,
                      //     itemCount: recommendedItems.isNotEmpty ? recommendedItems.length : 10,
                      //     itemBuilder: (context, index) {
                      //       return AspectRatio(
                      //         aspectRatio: 1,
                      //         child: Container(
                      //           margin: EdgeInsets.all(20 * globals.scaleParam),
                      //           decoration: BoxDecoration(
                      //             borderRadius: BorderRadius.all(Radius.circular(10)),
                      //             color: Colors.white,
                      //           ),
                      //           clipBehavior: Clip.antiAlias,
                      //           child: LayoutBuilder(
                      //             builder: (context, constraints) {
                      //               return Column(
                      //                 children: [
                      //                   Flexible(
                      //                     flex: 20,
                      //                     fit: FlexFit.tight,
                      //                     child: Padding(
                      //                       padding: EdgeInsets.symmetric(vertical: 5 * globals.scaleParam),
                      //                       child: recommendedItems.isNotEmpty
                      //                           ? Column(
                      //                               mainAxisAlignment: MainAxisAlignment.center,
                      //                               children: [
                      //                                 Flexible(
                      //                                     flex: 5, fit: FlexFit.tight, child: ExtendedImage.network(recommendedItems[index]["img"])),
                      //                                 Flexible(
                      //                                   fit: FlexFit.tight,
                      //                                   child: Text(
                      //                                     recommendedItems[index]["name"],
                      //                                     maxLines: 1,
                      //                                     overflow: TextOverflow.ellipsis,
                      //                                     textAlign: TextAlign.center,
                      //                                     style: TextStyle(
                      //                                       fontSize: 24 * globals.scaleParam,
                      //                                       fontWeight: FontWeight.w700,
                      //                                       color: Colors.black,
                      //                                     ),
                      //                                   ),
                      //                                 ),
                      //                               ],
                      //                             )
                      //                           : SizedBox(),
                      //                     ),
                      //                   ),
                      //                   Flexible(
                      //                     flex: 7,
                      //                     fit: FlexFit.tight,
                      //                     child: Container(
                      //                       decoration: BoxDecoration(
                      //                         color: Colors.black87,
                      //                       ),
                      //                       child: Row(
                      //                         children: [
                      //                           Flexible(
                      //                             fit: FlexFit.tight,
                      //                             child: Text(
                      //                               recommendedItems.isNotEmpty ? "${recommendedItems[index]["price"]} ₸" : "0 ₸",
                      //                               textAlign: TextAlign.center,
                      //                               style: TextStyle(
                      //                                 fontSize: 36 * globals.scaleParam,
                      //                                 fontWeight: FontWeight.w700,
                      //                                 color: Colors.white,
                      //                               ),
                      //                             ),
                      //                           ),
                      //                           Flexible(
                      //                             fit: FlexFit.tight,
                      //                             child: IconButton(
                      //                               onPressed: () {},
                      //                               icon: Icon(
                      //                                 Icons.add_rounded,
                      //                                 color: Colors.white,
                      //                               ),
                      //                             ),
                      //                           ),
                      //                         ],
                      //                       ),
                      //                     ),
                      //                   ),
                      //                 ],
                      //               );
                      //             },
                      //           ),
                      //         ),
                      //       );
                      //     },
                      //   ),
                      // ),
                      SizedBox(
                        height: 250 * globals.scaleParam,
                      ),
                    ],
                  )
            : LinearProgressIndicator(),
      ),
    );
  }
}
