import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../globals.dart' as globals;
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/shared/likeButton.dart';
import 'package:intl/intl.dart';

class ItemCard extends StatefulWidget {
  ItemCard(
      {super.key,
      required this.item_id,
      required this.element,
      required this.category_name,
      required this.category_id,
      required this.scroll});
  final Map<String, dynamic> element;
  final String category_name;

  final String item_id;

  final String category_id;
  final double scroll;
  int chack = 1;
  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  Map<String, dynamic> element = {};
  List<InlineSpan> propertiesWidget = [];
  late int chack;
  bool isNumPickerActive = false;

  String formatCost(String costString) {
    int cost = int.parse(costString);
    return NumberFormat("###,###", "en_US").format(cost).replaceAll(',', ' ');
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    setState(() {
      element = widget.element;
    });
    getProperties();
  }

  void getProperties() {
    if (widget.element["properties"] != null) {
      List<InlineSpan> propertiesT = [];
      List<String> properties = widget.element["properties"].split(",");
      print(properties);
      for (var element in properties) {
        List temp = element.split(":");
        propertiesT.add(WidgetSpan(
            child: Row(
          children: [
            Text(
              temp[1],
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black),
            ),
            Image.asset(
              "assets/property_icons/${temp[0]}.png",
              width: 14,
              height: 14,
            ),
            SizedBox(
              width: 10,
            )
          ],
        )));
      }
      setState(() {
        propertiesWidget = propertiesT;
      });
    }
  }

  Future<void> refreshItemCard() async {
    Map<String, dynamic>? element = await getItem(widget.element["item_id"]);
    print(element);
    setState(() {
      element!["name"] = "123";
      element = element!;
    });
  }

  @override
  Widget build(BuildContext context) {
    chack = widget.chack;
    return Container(
      // margin:  EdgeInsets.all(10),
      width: (MediaQuery.of(context).size.width * 2) *
          (MediaQuery.sizeOf(context).width / 720),
      height: (MediaQuery.of(context).size.height * 0.56) *
          (MediaQuery.sizeOf(context).width / 720),
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          Flexible(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedNetworkImage(
                imageUrl: element["thumb"],
                width: double.infinity,
                // width: MediaQuery.of(context).size.width * 0.2,
                // height: MediaQuery.of(context).size.width * 0.7,
                fit: BoxFit.fitHeight,
                cacheManager: CacheManager(Config(
                  "itemImage ${element["item_id"].toString()}",
                  stalePeriod: Duration(days: 7),
                  //one week cache period
                )),
                placeholder: (context, url) {
                  return Container(
                    alignment: Alignment.center,
                    color: Colors.white,
                    // width: MediaQuery.of(context).size.width * 0.2,
                    child: CircularProgressIndicator(),
                  );
                },
                errorWidget: (context, url, error) {
                  return Container(
                    alignment: Alignment.center,
                    // width: MediaQuery.of(context).size.width * 0.2,
                    child: Text(
                      "Нет изображения",
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
          ),
          Flexible(
            flex: 5,
            fit: FlexFit.tight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: RichText(
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: TextStyle(
                          textBaseline: TextBaseline.alphabetic,
                          fontSize:
                              40 * (MediaQuery.sizeOf(context).width / 720),
                          color: Colors.black,
                        ),
                        children: [
                          TextSpan(text: element["name"]),
                          element["country"] != null
                              ? WidgetSpan(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 2, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(3),
                                      ),
                                    ),
                                    child: Text(
                                      element["country"] ?? "",
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                              : TextSpan()
                        ],
                      ),
                    ),
                  ),
                  Flexible(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              formatCost(element['price'] ?? ""),
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 56 *
                                      (MediaQuery.sizeOf(context).width / 720)),
                            ),
                            Text(
                              "₸",
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 56 *
                                      (MediaQuery.sizeOf(context).width / 720)),
                            )
                          ],
                        ),
                        element["prev_price"] != null
                            ? Padding(
                                padding: EdgeInsets.only(left: 5),
                                child: Row(
                                  children: [
                                    Text(
                                      formatCost(element["prev_price"] ?? 0),
                                      style: TextStyle(
                                          decoration:
                                              TextDecoration.lineThrough,
                                          decorationColor: Colors.grey.shade500,
                                          decorationThickness: 1.85,
                                          color: Colors.grey.shade500,
                                          fontSize: 28 *
                                              (MediaQuery.sizeOf(context)
                                                      .width /
                                                  720),
                                          fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      "₸",
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 28 *
                                              (MediaQuery.sizeOf(context)
                                                      .width /
                                                  720)),
                                    )
                                  ],
                                ),
                              )
                            : Container(),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        // Flexible(
                        //   child: GestureDetector(
                        //     onLongPress: (() {
                        //       setState(() {
                        //         isNumPickerActive = true;
                        //       });
                        //     }),
                        //     onLongPressUp: (() {
                        //       setState(() {
                        //         isNumPickerActive = false;
                        //       });
                        //     }),
                        //     child: Stack(
                        //       children: [
                        //         _buyButton,
                        //         isNumPickerActive
                        //             ?  NumberPicker(amount: 50)
                        //             : Container(),
                        //       ],
                        //     ),
                        //   ),
                        // ),
                        Flexible(
                          child: LikeButton(
                            is_liked: element["is_liked"],
                            item_id: element["item_id"],
                          ),
                        ),
                      ],
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

class ItemCardMedium extends StatefulWidget {
  ItemCardMedium(
      {super.key,
      required this.item_id,
      required this.element,
      required this.category_name,
      required this.category_id,
      required this.scroll,
      required this.business,
      required this.index,
      this.updateCategoryPageInfo});
  final Map<String, dynamic> element;
  final String category_name;

  final String item_id;

  final String category_id;
  final double scroll;
  final Map<dynamic, dynamic> business;
  final int index;
  final Function(String, int)? updateCategoryPageInfo;
  int chack = 1;
  @override
  State<ItemCardMedium> createState() => _ItemCardMediumState();
}

class _ItemCardMediumState extends State<ItemCardMedium> {
  Map<String, dynamic> element = {};
  List<InlineSpan> propertiesWidget = [];
  int amountInCart = 0;
  int previousAmount = 0;
  bool isItemAmountChanging = false;
  late int chack;
  Timer? _debounce;

  void _updateItemCountServerCall() {
    if (previousAmount == amountInCart) {
      return;
    } else {
      setState(() {
        isItemAmountChanging = true;
      });
      changeCartItem(
              element["item_id"], amountInCart, widget.business["business_id"])
          .then((value) {
        if (value != null) {
          setState(() {
            amountInCart = int.parse(value);
            previousAmount = amountInCart;
          });
          if (widget.updateCategoryPageInfo != null) {
            widget.updateCategoryPageInfo!(
                amountInCart.toString(), widget.index);
          }
          print(value);
        } else {
          print(
              "Something gone wrong, can't add item to cart in ItemCardMedium _updateItemCountServerCall");
        }
        setState(() {
          isItemAmountChanging = false;
        });
      });
    }
  }

  void _updateItemCount() {
    // Cancel the previous timer if it exists
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Start a new timer
    _debounce = Timer(Duration(seconds: 3), () {
      // Call your server update function here
      _updateItemCountServerCall();
    });
  }

  void _decrementAmountInCart() {
    if (amountInCart > 0) {
      setState(() {
        amountInCart--;
      });
      _updateItemCount();
    }
  }

  void _incrementAmountInCart() {
    if (amountInCart + 1 <= double.parse(element["in_stock"]).truncate()) {
      setState(() {
        amountInCart++;
      });
      _updateItemCount();
    }
  }

  String formatCost(String costString) {
    int cost = double.parse(costString).truncate().toInt();
    return NumberFormat("###,###", "en_US").format(cost).replaceAll(',', ' ');
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    setState(() {
      element = widget.element;
      amountInCart = int.parse(element["amount"] ?? "0");
      previousAmount = amountInCart;
    });
    getProperties();
  }

  @override
  void dispose() {
    // Trigger the debounce action immediately if the timer is active
    if (_debounce?.isActive ?? false) {
      _debounce?.cancel();
      _updateItemCountServerCall();
    }
    super.dispose();
  }

  void getProperties() {
    if (widget.element["properties"] != null) {
      List<InlineSpan> propertiesT = [];
      List<String> properties = widget.element["properties"].split(",");
      print(properties);
      for (var element in properties) {
        List temp = element.split(":");
        propertiesT.add(
          WidgetSpan(
            child: Row(
              children: [
                Text(
                  temp[1],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                Image.asset(
                  "assets/property_icons/${temp[0]}.png",
                  width: 14,
                  height: 14,
                ),
                SizedBox(
                  width: 10,
                )
              ],
            ),
          ),
        );
      }
      setState(() {
        propertiesWidget = propertiesT;
      });
    }
  }

  Future<void> refreshItemCard() async {
    Map<String, dynamic>? element = await getItem(widget.element["item_id"]);
    print(element);
    setState(() {
      element!["name"] = "123";
      element = element!;
    });
  }

  @override
  Widget build(BuildContext context) {
    chack = widget.chack;
    return Container(
      // margin:  EdgeInsets.all(10),
      padding: EdgeInsets.symmetric(horizontal: 5 * globals.scaleParam),
      // width: (MediaQuery.of(context).size.width * 0.8) * (MediaQuery.sizeOf(context).width / 720),
      width: double.infinity,
      height: 300 * globals.scaleParam,
      child: Stack(
        children: [
          // Image.asset(
          //   'assets/vectors/whiskey/whiskey1.png',
          //   color: Colors.grey.shade300,
          // ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            mainAxisSize: MainAxisSize.max,
            children: [
              Flexible(
                flex: 2,
                fit: FlexFit.tight,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CachedNetworkImage(
                    height: double.infinity,
                    imageUrl: element["thumb"],
                    // width: MediaQuery.of(context).size.width * 0.2,
                    // height: MediaQuery.of(context).size.width * 0.7,
                    fit: BoxFit.cover,
                    cacheManager: CacheManager(
                      Config(
                        "itemImage ${element["item_id"].toString()}",
                        stalePeriod: Duration(days: 700),
                        //one week cache period
                      ),
                    ),
                    placeholder: (context, url) {
                      return Container(
                        alignment: Alignment.center,
                        color: Colors.white,
                        // width: MediaQuery.of(context).size.width * 0.2,
                        child: CircularProgressIndicator(),
                      );
                    },
                    errorWidget: (context, url, error) {
                      return Container(
                        alignment: Alignment.center,
                        // width: MediaQuery.of(context).size.width * 0.2,
                        child: Text(
                          "Нет изображения",
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ),
              ),
              Flexible(
                flex: 5,
                fit: FlexFit.tight,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 15 * globals.scaleParam,
                      vertical: 5 * globals.scaleParam),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        fit: FlexFit.tight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              flex: 2,
                              fit: FlexFit.tight,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    flex: 5,
                                    fit: FlexFit.tight,
                                    child: RichText(
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      text: TextSpan(
                                        style: TextStyle(
                                          textBaseline: TextBaseline.alphabetic,
                                          fontSize: 28 * globals.scaleParam,
                                          color: Colors.black,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: element["name"],
                                            style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize:
                                                    28 * globals.scaleParam),
                                          ),
                                          element["country"] != null
                                              ? WidgetSpan(
                                                  child: Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                      horizontal: 4 *
                                                          globals.scaleParam,
                                                      vertical: 2 *
                                                          globals.scaleParam,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade200,
                                                      borderRadius:
                                                          BorderRadius.all(
                                                        Radius.circular(10),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      element["country"] ?? "",
                                                      style: TextStyle(
                                                        color: Colors.black,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 26 *
                                                            globals.scaleParam,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : TextSpan()
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Flexible(
                              fit: FlexFit.tight,
                              child: Text(
                                "В наличии ${double.parse(element["in_stock"] ?? "0").truncate().toString()} шт.",
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                    fontSize: 28 * globals.scaleParam,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        flex: 2,
                        fit: FlexFit.tight,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible(
                              flex: 5,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Flexible(
                                  //   child: Row(
                                  //     children: [
                                  //       Flexible(
                                  //         child: Text(
                                  //           amountInCart != 0
                                  //               ? "В корзине ${amountInCart.toString()} шт."
                                  //               : "",
                                  //           style: TextStyle(
                                  //               color: Theme.of(context)
                                  //                   .colorScheme
                                  //                   .secondary,
                                  //               fontSize:
                                  //                   28 * (MediaQuery.sizeOf(context).width / 720),
                                  //               fontWeight: FontWeight.w500),
                                  //         ),
                                  //       ),
                                  //     ],
                                  //   ),
                                  // ),
                                  Flexible(
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            formatCost(element['price'] ?? ""),
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 36 * globals.scaleParam,
                                            ),
                                          ),
                                        ),
                                        Flexible(
                                          child: Text(
                                            "₸",
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 36 * globals.scaleParam,
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                  Flexible(
                                    // flex: 2,
                                    fit: FlexFit.tight,
                                    child: Row(
                                      children: [
                                        Flexible(
                                          fit: FlexFit.tight,
                                          child: IconButton(
                                            padding: EdgeInsets.all(0),
                                            onPressed: () {
                                              if (!isItemAmountChanging) {
                                                _decrementAmountInCart();
                                              }
                                            },
                                            icon: Container(
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: amountInCart > 0
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .onBackground
                                                      : Theme.of(context)
                                                          .colorScheme
                                                          .secondary,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Icon(
                                                Icons.remove_rounded,
                                                color: amountInCart > 0
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .onBackground
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .secondary,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Flexible(
                                          flex: 2,
                                          fit: FlexFit.tight,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  "${amountInCart.toString()} шт.", //"${formatCost((cacheAmount * int.parse(item["price"])).toString())} ₸",
                                                  textHeightBehavior:
                                                      TextHeightBehavior(
                                                    applyHeightToFirstAscent:
                                                        false,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize:
                                                        36 * globals.scaleParam,
                                                    color: amountInCart != 0
                                                        ? Theme.of(context)
                                                            .colorScheme
                                                            .onBackground
                                                        : Colors.grey.shade600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Flexible(
                                          fit: FlexFit.tight,
                                          child: IconButton(
                                            padding: EdgeInsets.all(0),
                                            onPressed: () {
                                              if (!isItemAmountChanging) {
                                                _incrementAmountInCart();
                                              }
                                            },
                                            icon: Container(
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: amountInCart <
                                                          double.parse(element[
                                                                  "in_stock"])
                                                              .truncate()
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .onBackground
                                                      : Theme.of(context)
                                                          .colorScheme
                                                          .secondary,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Icon(
                                                Icons.add_rounded,
                                                color: amountInCart <
                                                        double.parse(element[
                                                                "in_stock"])
                                                            .truncate()
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .onBackground
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .secondary,
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
                            Flexible(
                              fit: FlexFit.tight,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    fit: FlexFit.tight,
                                    child: SizedBox(),
                                  ),
                                  Flexible(
                                    fit: FlexFit.tight,
                                    child: LikeButton(
                                      is_liked: element["is_liked"],
                                      item_id: element["item_id"],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Flexible(
                            //   flex: 4,
                            //   child: _buyButton,
                            // ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ItemCardMinimal extends StatefulWidget {
  ItemCardMinimal(
      {super.key,
      required this.item_id,
      required this.element,
      required this.category_name,
      required this.category_id,
      required this.scroll});
  final Map<String, dynamic> element;
  final String category_name;

  final String item_id;

  final String category_id;
  final double scroll;
  int chack = 1;
  @override
  State<ItemCardMinimal> createState() => _ItemCardMinimalState();
}

class _ItemCardMinimalState extends State<ItemCardMinimal> {
  Map<String, dynamic> element = {};
  List<InlineSpan> propertiesWidget = [];
  late int chack;

  String formatCost(String costString) {
    int cost = int.parse(costString);
    return NumberFormat("###,###", "en_US").format(cost).replaceAll(',', ' ');
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    setState(() {
      element = widget.element;
    });
    getProperties();
  }

  void getProperties() {
    if (widget.element["properties"] != null) {
      List<InlineSpan> propertiesT = [];
      List<String> properties = widget.element["properties"].split(",");
      print(properties);
      for (var element in properties) {
        List temp = element.split(":");
        propertiesT.add(WidgetSpan(
            child: Row(
          children: [
            Text(
              temp[1],
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black),
            ),
            Image.asset(
              "assets/property_icons/${temp[0]}.png",
              width: 14,
              height: 14,
            ),
            SizedBox(
              width: 10,
            )
          ],
        )));
      }
      setState(() {
        propertiesWidget = propertiesT;
      });
    }
  }

  Future<void> refreshItemCard() async {
    Map<String, dynamic>? element = await getItem(widget.element["item_id"]);
    print(element);
    setState(() {
      element!["name"] = "123";
      element = element!;
    });
  }

  @override
  Widget build(BuildContext context) {
    chack = widget.chack;
    return Container(
      // margin:  EdgeInsets.all(10),
      width: double.infinity,
      height: 125 * globals.scaleParam,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          Flexible(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedNetworkImage(
                imageUrl: element["thumb"],
                width: double.infinity,
                // width: MediaQuery.of(context).size.width * 0.2,
                // height: MediaQuery.of(context).size.width * 0.7,
                fit: BoxFit.fitHeight,
                cacheManager: CacheManager(
                  Config(
                    "itemImage ${element["item_id"].toString()}",
                    stalePeriod: Duration(days: 7),
                    //one week cache period
                  ),
                ),
                placeholder: (context, url) {
                  return Container(
                    alignment: Alignment.center,
                    color: Colors.white,
                    // width: MediaQuery.of(context).size.width * 0.2,
                    child: CircularProgressIndicator(),
                  );
                },
                errorWidget: (context, url, error) {
                  return Container(
                    alignment: Alignment.center,
                    // width: MediaQuery.of(context).size.width * 0.2,
                    child: Text(
                      "Нет изображения",
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
          ),
          Flexible(
            flex: 5,
            fit: FlexFit.tight,
            child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 30 * globals.scaleParam),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    fit: FlexFit.tight,
                    child: RichText(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: TextStyle(
                          textBaseline: TextBaseline.alphabetic,
                          color: Colors.black,
                        ),
                        children: [
                          TextSpan(
                            text: element["name"],
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 38 * globals.scaleParam,
                            ),
                          ),
                          element["country"] != null
                              ? WidgetSpan(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 4 * globals.scaleParam,
                                        vertical: 2 * globals.scaleParam),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      element["country"] ?? "",
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 32 * globals.scaleParam,
                                      ),
                                    ),
                                  ),
                                )
                              : TextSpan()
                        ],
                      ),
                    ),
                  ),
                  Flexible(
                    fit: FlexFit.tight,
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            "${formatCost(element["price"])} ₸ за шт.",
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withOpacity(0.2),
                              fontWeight: FontWeight.w600,
                              fontSize: 28 * globals.scaleParam,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    fit: FlexFit.tight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          fit: FlexFit.tight,
                          child: Text(
                            "${formatCost((int.parse(element['price']) * int.parse(element["amount"])).toString())} ₸",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                              fontSize: 36 * globals.scaleParam,
                            ),
                          ),
                        ),
                        Flexible(
                          fit: FlexFit.tight,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8 * globals.scaleParam),
                            child: Text(
                              "${element["amount"]} шт.",
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w700,
                                fontSize: 32 * globals.scaleParam,
                              ),
                            ),
                          ),
                        ),
                        // Row(
                        //   children: [
                        //     // element["prev_price"] != null
                        //     //     ? Padding(
                        //     //         padding:  EdgeInsets.only(left: 5),
                        //     //         child: Row(
                        //     //           children: [
                        //     //             Text(
                        //     //               formatCost(element["prev_price"]),
                        //     //               style: TextStyle(
                        //     //                   decoration:
                        //     //                       TextDecoration.lineThrough,
                        //     //                   decorationColor:
                        //     //                       Colors.grey.shade500,
                        //     //                   decorationThickness: 1.85,
                        //     //                   color: Colors.grey.shade500,
                        //     //                   fontSize: 12 * (MediaQuery.sizeOf(context).width / 720),
                        //     //                   fontWeight: FontWeight.w500),
                        //     //             ),
                        //     //             Text(
                        //     //               "₸",
                        //     //               style: TextStyle(
                        //     //                   color: Colors.grey.shade600,
                        //     //                   fontWeight: FontWeight.w700,
                        //     //                   fontSize: 12 * (MediaQuery.sizeOf(context).width / 720)),
                        //     //             )
                        //     //           ],
                        //     //         ),
                        //     //       )
                        //     //     : Container(),
                        //   ],
                        // ),
                        Flexible(
                          child: LikeButton(
                            is_liked: element["is_liked"],
                            item_id: element["item_id"],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Flexible(
                  //   child: Row(
                  //     mainAxisAlignment: MainAxisAlignment.end,
                  //     mainAxisSize: MainAxisSize.max,
                  //     children: [
                  //       // Flexible(
                  //       //   child: _buyButton,
                  //       // ),
                  //       Flexible(
                  //         child: LikeButton(
                  //           is_liked: element["is_liked"],
                  //           item_id: element["item_id"],
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ItemCardNoImage extends StatefulWidget {
  ItemCardNoImage(
      {super.key,
      required this.item_id,
      required this.element,
      required this.category_name,
      required this.category_id,
      required this.scroll});
  final Map<String, dynamic> element;
  final String category_name;

  final String item_id;

  final String category_id;
  final double scroll;
  int chack = 1;
  @override
  State<ItemCardNoImage> createState() => _ItemCardNoImageState();
}

class _ItemCardNoImageState extends State<ItemCardNoImage> {
  Map<String, dynamic> element = {};
  List<InlineSpan> propertiesWidget = [];
  late int chack;

  String formatCost(String costString) {
    int cost = int.parse(costString);
    return NumberFormat("###,###", "en_US").format(cost).replaceAll(',', ' ');
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    setState(() {
      element = widget.element;
    });
    getProperties();
  }

  void getProperties() {
    if (widget.element["properties"] != null) {
      List<InlineSpan> propertiesT = [];
      List<String> properties = widget.element["properties"].split(",");
      print(properties);
      for (var element in properties) {
        List temp = element.split(":");
        propertiesT.add(WidgetSpan(
            child: Row(
          children: [
            Text(
              temp[1],
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black),
            ),
            Image.asset(
              "assets/property_icons/${temp[0]}.png",
              width: 14,
              height: 14,
            ),
            SizedBox(
              width: 10,
            )
          ],
        )));
      }
      setState(() {
        propertiesWidget = propertiesT;
      });
    }
  }

  Future<void> refreshItemCard() async {
    Map<String, dynamic>? element = await getItem(widget.element["item_id"]);
    print(element);
    setState(() {
      element!["name"] = "123";
      element = element!;
    });
  }

  @override
  Widget build(BuildContext context) {
    chack = widget.chack;
    return Container(
      // margin:  EdgeInsets.all(10),
      width: double.infinity,
      height: 100 * globals.scaleParam,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          Flexible(
            fit: FlexFit.tight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Flexible(
                  fit: FlexFit.tight,
                  child: RichText(
                    maxLines: 1,
                    text: TextSpan(
                      text: "x ${element["amount"]}",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 36 * globals.scaleParam,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            flex: 5,
            fit: FlexFit.tight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  fit: FlexFit.tight,
                  child: RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: TextStyle(
                        textBaseline: TextBaseline.alphabetic,
                        color: Colors.black,
                      ),
                      children: [
                        TextSpan(
                          text: element["name"],
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 36 * globals.scaleParam),
                        ),
                        element["country"] != null
                            ? WidgetSpan(
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 4 * globals.scaleParam,
                                      vertical: 2 * globals.scaleParam),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    element["country"] ?? "",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 36 * globals.scaleParam,
                                    ),
                                  ),
                                ),
                              )
                            : TextSpan()
                      ],
                    ),
                  ),
                ),
                Flexible(
                  fit: FlexFit.tight,
                  child: Row(
                    children: [
                      Flexible(
                        fit: FlexFit.tight,
                        child: Text(
                          "${formatCost(element["price"])} ₸ за шт.",
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .secondary
                                .withOpacity(0.2),
                            fontWeight: FontWeight.w600,
                            fontSize: 30 * globals.scaleParam,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Flexible(
                //   child: Row(
                //     mainAxisAlignment: MainAxisAlignment.end,
                //     mainAxisSize: MainAxisSize.max,
                //     children: [
                //       // Flexible(
                //       //   child: _buyButton,
                //       // ),
                //       Flexible(
                //         child: LikeButton(
                //           is_liked: element["is_liked"],
                //           item_id: element["item_id"],
                //         ),
                //       ),
                //     ],
                //   ),
                // ),
              ],
            ),
          ),
          Flexible(
            flex: 2,
            fit: FlexFit.tight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  fit: FlexFit.tight,
                  child: RichText(
                    maxLines: 1,
                    textAlign: TextAlign.end,
                    text: TextSpan(
                      text:
                          "${formatCost((int.parse(element['price']) * int.parse(element['amount'])).toString())} ₸",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 36 * globals.scaleParam,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // child: Row(
          //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //   children: [
          //     Row(
          //       children: [
          //         Text(
          //           "${formatCost(element['price'])} ₸",
          //           style: TextStyle(
          //               color: Colors.black,
          //               fontWeight: FontWeight.w600,
          //               fontSize: 16 * (MediaQuery.sizeOf(context).width / 720)),
          //         ),
          //         // Text(
          //         //   "₸",
          //         //   style: TextStyle(
          //         //       color: Colors.grey.shade600,
          //         //       fontWeight: FontWeight.w700,
          //         //       fontSize: 16 * (MediaQuery.sizeOf(context).width / 720)),
          //         // // ),
          //         // element["prev_price"] != null
          //         //     ? Padding(
          //         //         padding:  EdgeInsets.only(left: 5),
          //         //         child: Row(
          //         //           children: [
          //         //             Text(
          //         //               formatCost(element["prev_price"]),
          //         //               style: TextStyle(
          //         //                   decoration: TextDecoration.lineThrough,
          //         //                   decorationColor: Colors.grey.shade500,
          //         //                   decorationThickness: 1.85,
          //         //                   color: Colors.grey.shade500,
          //         //                   fontSize: 12 * (MediaQuery.sizeOf(context).width / 720),
          //         //                   fontWeight: FontWeight.w500),
          //         //             ),
          //         //             Text(
          //         //               "₸",
          //         //               style: TextStyle(
          //         //                   color: Colors.grey.shade600,
          //         //                   fontWeight: FontWeight.w700,
          //         //                   fontSize: 12 * (MediaQuery.sizeOf(context).width / 720)),
          //         //             )
          //         //           ],
          //         //         ),
          //         //       )
          //         //     : Container(),
          //       ],
          //     ),
          //   ],
          // ),
        ],
      ),
    );
  }
}
