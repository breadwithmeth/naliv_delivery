import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/productPage.dart';
import '../globals.dart' as globals;
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/shared/likeButton.dart';
import 'package:extended_image/extended_image.dart';

class ItemCard extends StatefulWidget {
  const ItemCard(
      {super.key,
      required this.itemId,
      required this.element,
      required this.categoryName,
      required this.categoryId,
      required this.scroll,
      required this.business_id});
  final Map<String, dynamic> element;
  final String categoryName;

  final String itemId;

  final String categoryId;
  final double scroll;
  final String business_id;
  final int chack = 1;
  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  Map<String, dynamic> element = {};
  List<InlineSpan> propertiesWidget = [];
  late int chack;
  bool isNumPickerActive = false;

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
    Map<String, dynamic>? element =
        await getItem(widget.element["item_id"], widget.business_id);
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
                // cacheManager: CacheManager(Config(
                //   "itemImage ${element["item_id"].toString()}",
                //   stalePeriod: Duration(days: 7),
                //   //one week cache period
                // )),
                imageBuilder: (context, imageProvider) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        fit: FlexFit.tight,
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(5)),
                            color: Colors.green,
                          ),
                          child: Image(
                            image: imageProvider,
                            fit: BoxFit.fitHeight,
                          ),
                        ),
                      ),
                    ],
                  );
                },
                errorWidget: (context, url, error) {
                  return Container(
                    alignment: Alignment.center,
                    // width: MediaQuery.of(context).size.width * 0.2,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SizedBox(
                          width: constraints.maxWidth * 0.5,
                          child: Image.asset(
                            'assets/category_icons/no_image_ico.png',
                            opacity: AlwaysStoppedAnimation(0.5),
                          ),
                        );
                      },
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
                          fontSize: 40 * globals.scaleParam,
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
                              globals.formatCost(element['price'] ?? ""),
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
                                      globals.formatCost(
                                          element["prev_price"] ?? 0),
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
  const ItemCardMedium(
      {super.key,
      required this.itemId,
      required this.element,
      required this.categoryName,
      required this.categoryId,
      required this.scroll,
      required this.business,
      required this.index,
      this.categoryPageUpdateData});
  final Map<String, dynamic> element;
  final String categoryName;

  final String itemId;

  final String categoryId;
  final double scroll;
  final Map<dynamic, dynamic> business;
  final int index;
  final chack = 1;
  final Function(String, int)? categoryPageUpdateData;
  @override
  State<ItemCardMedium> createState() => _ItemCardMediumState();
}

class _ItemCardMediumState extends State<ItemCardMedium>
    with SingleTickerProviderStateMixin<ItemCardMedium> {
  Map<String, dynamic> element = {};
  List<InlineSpan> propertiesWidget = [];
  int amountInCart = 0;
  int previousAmount = 0;
  late int chack;
  Timer? _debounce;

  bool canButtonsBeUsed = true;

  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  // late Animation<Offset> _offsetAnimationReverse;

  void _updateItemCountServerCall() {
    changeCartItem(
            element["item_id"], amountInCart, widget.business["business_id"])
        .then((value) {
      if (value == null) {
        if (0 != amountInCart) {
          _updateItemCountServerCall();
        } else {
          setState(() {
            amountInCart = 0;
            previousAmount = amountInCart;
          });
        }
      } else {
        if (int.parse(value) != amountInCart) {
          _updateItemCountServerCall();
        } else {
          setState(() {
            amountInCart = int.parse(value);
            previousAmount = amountInCart;
          });
        }
      }
      // if (widget.updateCategoryPageInfo != null) {
      //   widget.updateCategoryPageInfo!(
      //       amountInCart.toString(), widget.index);
      // }
      if (widget.categoryPageUpdateData != null) {
        widget.categoryPageUpdateData!(amountInCart.toString(), widget.index);
      }
      print(value);
    });
  }

  void _updateItemCount() {
    // Cancel the previous timer if it exists
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Start a new timer
    _debounce = Timer(Duration(milliseconds: 750), () {
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

  void updateCurrentItem(int amount, [int index = 0]) {
    if (amountInCart == 0 && amount != 0) {
      _controller.forward();
    } else if (amount == 0) {
      _controller.reverse();
    }
    print("AMOUNT IS $amount");
    setState(() {
      amountInCart = amount;
    });
  }

  Future<void> refreshItemCard() async {
    Map<String, dynamic>? element = await getItem(
        widget.element["item_id"], widget.business["business_id"]);
    print(element);
    setState(() {
      element!["name"] = "123";
      element = element!;
    });
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
    // getProperties();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: Offset(0.70, 0),
      end: Offset(-0.1, 0),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    if (amountInCart > 0) {
      _controller.forward();
    }
    // _offsetAnimationReverse = Tween<Offset>(
    //   begin: Offset(0, 0),
    //   end: Offset(1, 0),
    // ).animate(CurvedAnimation(
    //   parent: _controller,
    //   curve: Curves.linear,
    // ));
  }

  @override
  void dispose() {
    // Trigger the debounce action immediately if the timer is active
    if (widget.categoryPageUpdateData != null) {
      widget.categoryPageUpdateData!(amountInCart.toString(), widget.index);
    }
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

  @override
  Widget build(BuildContext context) {
    chack = widget.chack;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5 * globals.scaleParam),
      width: double.infinity,
      height: 300 * globals.scaleParam,
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            mainAxisSize: MainAxisSize.max,
            children: [
              Flexible(
                flex: 2,
                fit: FlexFit.tight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  key: Key(widget.element["item_id"]),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      clipBehavior: Clip.antiAlias,
                      useSafeArea: true,
                      showDragHandle: false,
                      isScrollControlled: true,
                      builder: (context) {
                        widget.element["amount"] = amountInCart.toString();
                        return ProductPage(
                          item: widget.element,
                          index: widget.index,
                          returnDataAmount: updateCurrentItem,
                          business: widget.business,
                        );
                      },
                    );
                  },
                  // как будто бы картинки быстрее грузятся, я хз я не тестил чисто на глаз посмотрел
                  // ну и кэш чистится
                  // это я тоже не тестил
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        fit: FlexFit.tight,
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(5)),
                            color: Colors.white,
                          ),
                          child: ExtendedImage.network(
                            element["img"],
                            fit: BoxFit.fitHeight,
                            clearMemoryCacheWhenDispose: true,
                            enableMemoryCache: true,
                            enableLoadState: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                  //   fit: BoxFit.cover,
                  // cacheManager: CacheManager(
                  //   Config(
                  //     "itemImage ${element["item_id"].toString()}",
                  //     stalePeriod: Duration(days: 700),
                  //   ),
                  // ),
                  // imageBuilder: (context, imageProvider) {
                  // return Column(
                  //   mainAxisAlignment: MainAxisAlignment.center,
                  //   children: [
                  //     Flexible(
                  //       fit: FlexFit.tight,
                  //       child: Container(
                  //         clipBehavior: Clip.antiAlias,
                  //         decoration: BoxDecoration(
                  //           borderRadius:
                  //               BorderRadius.all(Radius.circular(5)),
                  //           color: Colors.white,
                  //         ),
                  //         child: Image(
                  //           image: imageProvider,
                  //           fit: BoxFit.fitHeight,
                  //         ),
                  //       ),
                  //     ),
                  //   ],
                  // );
                  // },
                  // errorWidget: (context, url, error) {
                  //   return LayoutBuilder(
                  //     builder: (context, constraints) {
                  //       return FractionallySizedBox(
                  //         heightFactor: 1,
                  //         widthFactor: 2 / 4,
                  //         child: Image.asset(
                  //           'assets/category_icons/no_image_ico.png',
                  //           opacity: AlwaysStoppedAnimation(0.5),
                  //         ),
                  //       );
                  //     },
                  //   );
                  // },
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
                      flex: 2,
                      fit: FlexFit.tight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        key: Key(widget.element["item_id"]),
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            clipBehavior: Clip.antiAlias,
                            useSafeArea: true,
                            isScrollControlled: true,
                            showDragHandle: false,
                            builder: (context) {
                              widget.element["amount"] =
                                  amountInCart.toString();
                              return ProductPage(
                                item: widget.element,
                                index: widget.index,
                                returnDataAmount: updateCurrentItem,
                                business: widget.business,
                              );
                            },
                          );
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 15 * globals.scaleParam,
                            // vertical: 5 * globals.scaleParam,
                          ),
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
                                      child: Container(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surface, // Чтобы текст не обрезало сверху, потому что без цвета, он сжимается до краёв текста
                                        child: RichText(
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          text: TextSpan(
                                            style: TextStyle(
                                              textBaseline:
                                                  TextBaseline.alphabetic,
                                              color: Colors.black,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 30 * globals.scaleParam,
                                              height: 2.5 * globals.scaleParam,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: element["name"],
                                              ),
                                              element["country"] != null
                                                  ? WidgetSpan(
                                                      child: Container(
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                          horizontal: 4 *
                                                              globals
                                                                  .scaleParam,
                                                          // vertical: 2 *
                                                          // globals.scaleParam,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .grey.shade200,
                                                          borderRadius:
                                                              BorderRadius.all(
                                                            Radius.circular(10),
                                                          ),
                                                        ),
                                                        child: Text(
                                                          element["country"] ??
                                                              "",
                                                          style: TextStyle(
                                                            color: Colors.black,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 26 *
                                                                globals
                                                                    .scaleParam,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                  : TextSpan()
                                            ],
                                          ),
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
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Flexible(
                                fit: FlexFit.tight,
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        globals
                                            .formatCost(element['price'] ?? ""),
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
                                        textAlign: TextAlign.start,
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
                            ],
                          ),
                        ),
                      ),
                    ),
                    Flexible(
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
                                Flexible(
                                  fit: FlexFit.tight,
                                  child: Stack(
                                    children: [
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          return Row(
                                            children: [
                                              Container(
                                                width:
                                                    constraints.maxWidth * 0.85,
                                                alignment: Alignment.centerLeft,
                                                child: ClipRect(
                                                  clipBehavior: Clip.antiAlias,
                                                  child: OverflowBox(
                                                    maxWidth:
                                                        constraints.maxWidth,
                                                    child: SlideTransition(
                                                      position:
                                                          _offsetAnimation,
                                                      child: Row(
                                                        children: [
                                                          Flexible(
                                                              fit:
                                                                  FlexFit.tight,
                                                              child: int.parse(widget
                                                                              .element[
                                                                          "option"]) ==
                                                                      1
                                                                  ? IconButton(
                                                                      highlightColor: canButtonsBeUsed
                                                                          ? Colors
                                                                              .transparent
                                                                          : Colors
                                                                              .transparent,
                                                                      padding:
                                                                          EdgeInsets.all(
                                                                              0),
                                                                      onPressed: canButtonsBeUsed
                                                                          ? () {
                                                                              _incrementAmountInCart();
                                                                              setState(() {
                                                                                canButtonsBeUsed = false;
                                                                              });
                                                                              _controller.forward();
                                                                              Timer(
                                                                                Duration(milliseconds: 100),
                                                                                () {
                                                                                  setState(() {
                                                                                    canButtonsBeUsed = true;
                                                                                  });
                                                                                },
                                                                              );
                                                                            }
                                                                          : null,
                                                                      icon:
                                                                          Container(
                                                                        padding:
                                                                            EdgeInsets.all(5 *
                                                                                globals.scaleParam),
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          borderRadius:
                                                                              BorderRadius.all(
                                                                            Radius.circular(100),
                                                                          ),
                                                                          color:
                                                                              Colors.white,
                                                                          boxShadow: [
                                                                            BoxShadow(
                                                                              color: Color.fromARGB(255, 180, 180, 180),
                                                                              spreadRadius: 0,
                                                                              blurRadius: 1,
                                                                              offset: Offset(0.2, 0.9),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                        child:
                                                                            Icon(
                                                                          Icons
                                                                              .add_rounded,
                                                                          color: Theme.of(context)
                                                                              .colorScheme
                                                                              .onSurface,
                                                                        ),
                                                                      ),
                                                                    )
                                                                  : Container()),
                                                          Flexible(
                                                            fit: FlexFit.tight,
                                                            child: IconButton(
                                                              padding:
                                                                  EdgeInsets
                                                                      .all(0),
                                                              onPressed:
                                                                  canButtonsBeUsed
                                                                      ? () {
                                                                          _decrementAmountInCart();
                                                                          if (amountInCart <=
                                                                              0) {
                                                                            setState(() {
                                                                              canButtonsBeUsed = false;
                                                                            });
                                                                            _controller.reverse();
                                                                            Timer(
                                                                              Duration(milliseconds: 100),
                                                                              () {
                                                                                setState(() {
                                                                                  canButtonsBeUsed = true;
                                                                                });
                                                                              },
                                                                            );
                                                                          }
                                                                        }
                                                                      : null,
                                                              icon: Container(
                                                                decoration:
                                                                    BoxDecoration(
                                                                  border: Border
                                                                      .all(
                                                                    color: amountInCart >
                                                                            0
                                                                        ? Theme.of(context)
                                                                            .colorScheme
                                                                            .onSurface
                                                                        : Theme.of(context)
                                                                            .colorScheme
                                                                            .secondary,
                                                                  ),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              6),
                                                                ),
                                                                child: Icon(
                                                                  Icons
                                                                      .remove_rounded,
                                                                  color: amountInCart >
                                                                          0
                                                                      ? Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurface
                                                                      : Theme.of(
                                                                              context)
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
                                                                  MainAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Flexible(
                                                                  child: Text(
                                                                    "${amountInCart.toString()} шт.", //"${globals.formatCost((cacheAmount * int.parse(item["price"])).toString())} ₸",
                                                                    textHeightBehavior:
                                                                        TextHeightBehavior(
                                                                      applyHeightToFirstAscent:
                                                                          false,
                                                                    ),
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                    style:
                                                                        TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                      fontSize: 36 *
                                                                          globals
                                                                              .scaleParam,
                                                                      color: amountInCart !=
                                                                              0
                                                                          ? Theme.of(context)
                                                                              .colorScheme
                                                                              .onSurface
                                                                          : Colors
                                                                              .grey
                                                                              .shade600,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          Flexible(
                                                            fit: FlexFit.tight,
                                                            child: IconButton(
                                                              padding:
                                                                  EdgeInsets
                                                                      .all(0),
                                                              onPressed:
                                                                  canButtonsBeUsed
                                                                      ? () {
                                                                          _incrementAmountInCart();
                                                                        }
                                                                      : null,
                                                              icon: Container(
                                                                decoration:
                                                                    BoxDecoration(
                                                                  border: Border
                                                                      .all(
                                                                    color: amountInCart <
                                                                            double.parse(element["in_stock"])
                                                                                .truncate()
                                                                        ? Theme.of(context)
                                                                            .colorScheme
                                                                            .onSurface
                                                                        : Theme.of(context)
                                                                            .colorScheme
                                                                            .secondary,
                                                                  ),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              6),
                                                                ),
                                                                child: Icon(
                                                                  Icons
                                                                      .add_rounded,
                                                                  color: amountInCart <
                                                                          double.parse(element["in_stock"])
                                                                              .truncate()
                                                                      ? Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurface
                                                                      : Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .secondary,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
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
                  ],
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
  const ItemCardMinimal(
      {super.key,
      required this.itemId,
      required this.element,
      required this.categoryName,
      required this.categoryId,
      required this.scroll,
      required this.index,
      required this.business,
      this.updateExternalInfo});
  final Map<String, dynamic> element;
  final String categoryName;

  final String itemId;

  final String categoryId;
  final double scroll;
  final int chack = 1;
  final int index;
  final Map business;
  final Function(int, int)? updateExternalInfo; // Update CartPage sum!!!!
  @override
  State<ItemCardMinimal> createState() => _ItemCardMinimalState();
}

// showModalBottomSheet(
//   transitionAnimationController:
//       animController,
//   context: context,
//   clipBehavior: Clip.antiAlias,
//   useSafeArea: true,
//   isScrollControlled: true,
//   builder: (context) {
//     return ProductPage(
//       item: items[index],
//       index: index,
//       returnDataAmount: updateDataAmount,
//       business: widget.business,
//       openedFromCart: true,
//     );
//   },
// ).then((value) {
//   print("object");
// });

class _ItemCardMinimalState extends State<ItemCardMinimal> {
  Map<String, dynamic> element = {};
  List<InlineSpan> propertiesWidget = [];
  late int chack;

  @override
  void initState() {
    // TODO: implement initState
    setState(() {
      element = widget.element;
    });
    super.initState();
    // getProperties();
  }

  // void getProperties() {
  //   if (widget.element["properties"] != null) {
  //     List<InlineSpan> propertiesT = [];
  //     List<String> properties = widget.element["properties"].split(",");
  //     print(properties);
  //     for (var element in properties) {
  //       List temp = element.split(":");
  //       propertiesT.add(WidgetSpan(
  //           child: Row(
  //         children: [
  //           Text(
  //             temp[1],
  //             style: TextStyle(
  //                 fontSize: 14,
  //                 fontWeight: FontWeight.w700,
  //                 color: Colors.black),
  //           ),
  //           Image.asset(
  //             "assets/property_icons/${temp[0]}.png",
  //             width: 14,
  //             height: 14,
  //           ),
  //           SizedBox(
  //             width: 10,
  //           )
  //         ],
  //       )));
  //     }
  //     setState(() {
  //       propertiesWidget = propertiesT;
  //     });
  //   }
  // }

  void updateCurrentItem(int updateNewAmount, int updateNewIndex) {
    setState(() {
      element["amount"] = updateNewAmount.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    chack = widget.chack;
    return Container(
      // margin:  EdgeInsets.all(10),
      padding: EdgeInsets.symmetric(horizontal: 5 * globals.scaleParam),
      width: double.infinity,
      height: 125 * globals.scaleParam,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          showModalBottomSheet(
            context: context,
            clipBehavior: Clip.antiAlias,
            useSafeArea: true,
            showDragHandle: false,
            isScrollControlled: true,
            builder: (context) {
              return ProductPage(
                item: element,
                index: widget.index,
                returnDataAmount: updateCurrentItem,
                cartPageExclusiveCallbackFunc: widget.updateExternalInfo,
                business: widget.business,
                openedFromCart: true,
              );
            },
          ).then((value) {
            print("object");
          });
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          mainAxisSize: MainAxisSize.max,
          children: [
            Flexible(
              flex: 3,
              fit: FlexFit.tight,
              child: CachedNetworkImage(
                imageUrl: element["thumb"],
                // width: MediaQuery.of(context).size.width * 0.2,
                // height: MediaQuery.of(context).size.width * 0.7,
                fit: BoxFit.fitHeight,
                // cacheManager: CacheManager(
                //   Config(
                //     "itemImage ${element["item_id"].toString()}",
                //     stalePeriod: Duration(days: 7),
                //     //one week cache period
                //   ),
                // ),
                imageBuilder: (context, imageProvider) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        fit: FlexFit.tight,
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(5)),
                            color: Colors.white,
                          ),
                          child: Image(
                            image: imageProvider,
                            fit: BoxFit.fitHeight,
                          ),
                        ),
                      ),
                    ],
                  );
                },
                errorWidget: (context, url, error) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return FractionallySizedBox(
                        heightFactor: 1,
                        widthFactor: 2 / 4,
                        child: Image.asset(
                          'assets/category_icons/no_image_ico.png',
                          opacity: AlwaysStoppedAnimation(0.5),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Flexible(
              flex: 12,
              fit: FlexFit.tight,
              child: Padding(
                padding: EdgeInsets.only(right: 10 * globals.scaleParam),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      fit: FlexFit.tight,
                      child: Padding(
                        padding: EdgeInsets.all(1 * globals.scaleParam),
                        child: RichText(
                          maxLines: 1,
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
                                  fontSize: 30 * globals.scaleParam,
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
                                            fontSize: 28 * globals.scaleParam,
                                          ),
                                        ),
                                      ),
                                    )
                                  : TextSpan()
                            ],
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      fit: FlexFit.tight,
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              "${globals.formatCost(element["price"])} ₸ за шт.",
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondary
                                    .withOpacity(0.2),
                                fontWeight: FontWeight.w600,
                                fontSize: 24 * globals.scaleParam,
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
                              "${globals.formatCost((int.parse(element['price']) * int.parse(element["amount"])).toString())} ₸",
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                                fontSize: 32 * globals.scaleParam,
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
                                  fontSize: 28 * globals.scaleParam,
                                ),
                              ),
                            ),
                          ),
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
      ),
    );
  }
}

class ItemCardNoImage extends StatefulWidget {
  const ItemCardNoImage(
      {super.key,
      required this.itemId,
      required this.element,
      required this.categoryName,
      required this.categoryId,
      required this.business_id,
      required this.scroll});
  final Map<String, dynamic> element;
  final String categoryName;

  final String itemId;

  final String categoryId;
  final double scroll;
  final String business_id;
  final int chack = 1;
  @override
  State<ItemCardNoImage> createState() => _ItemCardNoImageState();
}

class _ItemCardNoImageState extends State<ItemCardNoImage> {
  Map<String, dynamic> element = {};
  List<InlineSpan> propertiesWidget = [];
  late int chack;

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
    Map<String, dynamic>? element =
        await getItem(widget.element["item_id"], widget.business_id);
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
      height: 110 * globals.scaleParam,
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
                  child: Container(
                    // color: Theme.of(context).colorScheme.surface,
                    // color: Colors.transparent,
                    padding: EdgeInsets.all(1 * globals.scaleParam),
                    child: RichText(
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        text: "x ${element["amount"]}",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 32 * globals.scaleParam,
                        ),
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
                  flex: 2,
                  fit: FlexFit.tight,
                  child: Container(
                    // color: Theme.of(context).colorScheme.surface,
                    padding: EdgeInsets.all(1 * globals.scaleParam),
                    color: Colors.transparent,
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
                              fontSize: 30 * globals.scaleParam,
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
                                        fontSize: 28 * globals.scaleParam,
                                      ),
                                    ),
                                  ),
                                )
                              : TextSpan()
                        ],
                      ),
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
                          "${globals.formatCost(element["price"])} ₸ за шт.",
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
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      text:
                          "${globals.formatCost((int.parse(element['price']) * int.parse(element['amount'])).toString())} ₸",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
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
    );
  }
}

class ItemCardSquare extends StatefulWidget {
  const ItemCardSquare(
      {super.key,
      required this.itemId,
      required this.element,
      required this.categoryName,
      required this.categoryId,
      required this.scroll,
      required this.business,
      required this.index,
      this.categoryPageUpdateData,
      required this.constraints});
  final Map<String, dynamic> element;
  final String categoryName;
  final BoxConstraints constraints;

  final String itemId;

  final String categoryId;
  final double scroll;
  final Map<dynamic, dynamic> business;
  final int index;
  final chack = 1;
  final Function(String, int)? categoryPageUpdateData;
  @override
  State<ItemCardSquare> createState() => _ItemCardSquareState();
}

class _ItemCardSquareState extends State<ItemCardSquare>
    with SingleTickerProviderStateMixin<ItemCardSquare> {
  Map<String, dynamic> element = {};
  List<InlineSpan> propertiesWidget = [];
  int amountInCart = 0;
  int previousAmount = 0;
  late int chack;
  Timer? _debounce;
  Timer? _hideButtonsTimer;

  bool canButtonsBeUsed = true;
  bool hideButtons = true;

  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  // late Animation<Offset> _offsetAnimationReverse;

  void _hideButtonsAfterTime() {
    // Cancel the previous timer if it exists
    if (_hideButtonsTimer?.isActive ?? false) _hideButtonsTimer!.cancel();

    // Start a new timer
    _hideButtonsTimer = Timer(Duration(milliseconds: 3000), () {
      setState(() {
        hideButtons = true;
      });
    });
  }

  void _updateItemCountServerCall() {
    changeCartItem(
            element["item_id"], amountInCart, widget.business["business_id"])
        .then((value) {
      if (value == null) {
        if (0 != amountInCart) {
          _updateItemCountServerCall();
        } else {
          setState(() {
            amountInCart = 0;
            previousAmount = amountInCart;
          });
        }
      } else {
        if (int.parse(value) != amountInCart) {
          _updateItemCountServerCall();
        } else {
          setState(() {
            amountInCart = int.parse(value);
            previousAmount = amountInCart;
          });
        }
      }
      // if (widget.updateCategoryPageInfo != null) {
      //   widget.updateCategoryPageInfo!(
      //       amountInCart.toString(), widget.index);
      // }
      if (widget.categoryPageUpdateData != null) {
        widget.categoryPageUpdateData!(amountInCart.toString(), widget.index);
      }
      print(value);
    });
  }

  void _updateItemCount() {
    // Cancel the previous timer if it exists
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Start a new timer
    _debounce = Timer(Duration(milliseconds: 750), () {
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

  void updateCurrentItem(int amount, [int index = 0]) {
    if (amountInCart == 0 && amount != 0) {
      _controller.forward();
    } else if (amount == 0) {
      _controller.reverse();
    }
    print("AMOUNT IS $amount");
    setState(() {
      amountInCart = amount;
    });
  }

  Future<void> refreshItemCard() async {
    Map<String, dynamic>? element = await getItem(
        widget.element["item_id"], widget.business["business_id"]);
    print(element);
    setState(() {
      element!["name"] = "123";
      element = element!;
    });
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
    // getProperties();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: Offset(0.70, 0),
      end: Offset(-0.1, 0),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    if (amountInCart > 0) {
      _controller.forward();
    }
    // _offsetAnimationReverse = Tween<Offset>(
    //   begin: Offset(0, 0),
    //   end: Offset(1, 0),
    // ).animate(CurvedAnimation(
    //   parent: _controller,
    //   curve: Curves.linear,
    // ));
  }

  @override
  void dispose() {
    // Trigger the debounce action immediately if the timer is active
    if (widget.categoryPageUpdateData != null) {
      widget.categoryPageUpdateData!(amountInCart.toString(), widget.index);
    }
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

  @override
  Widget build(BuildContext context) {
    chack = widget.chack;
    return Container(
      // padding: EdgeInsets.all(15 * globals.scaleParam),
      margin: EdgeInsets.all(10 * globals.scaleParam),
      height: widget.constraints.minHeight,
      width: widget.constraints.maxWidth,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              blurRadius: 5,
              offset: Offset(5, 5),
              color: Colors.grey.withOpacity(0.1)),
          BoxShadow(
              blurRadius: 4,
              offset: Offset(-5, -5),
              color: Colors.blueGrey.withOpacity(0.1))
        ],
      ),
      // Stack for the gesture detector in the end of the code
      child: Stack(
        children: [
          Column(
            children: [
              Flexible(
                flex: 2,
                // Plus button stack
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      width: widget.constraints.minWidth,
                      child: ExtendedImage.network(
                        element["img"],
                        height: double.infinity,
                        clearMemoryCacheWhenDispose: true,
                        enableMemoryCache: true,
                        enableLoadState: false,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          bottomRight: Radius.circular(9 * globals.scaleParam),
                          topLeft: Radius.circular(9 * globals.scaleParam),
                          bottomLeft: Radius.elliptical(
                            60 * globals.scaleParam,
                            60 * globals.scaleParam,
                          ),
                        ),
                        color: amountInCart > 0
                            ? Colors.amberAccent.shade100
                            : Colors.blueGrey.shade100,
                        boxShadow: [
                          // BoxShadow(
                          //   color: Colors.blueGrey.shade100,
                          //   blurRadius: 5,
                          // )
                        ],
                      ),
                      child: AnimatedCrossFade(
                        alignment: Alignment.topRight,
                        duration: Durations.medium1,
                        crossFadeState: amountInCart == 0 ||
                                (amountInCart > 0 && hideButtons)
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                        firstChild: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            int.parse(widget.element["option"]) == 1
                                ? Flexible(
                                    child: SizedBox(
                                      height:
                                          widget.constraints.maxHeight * 0.2,
                                      child: AspectRatio(
                                        aspectRatio: 1,
                                        child: IconButton(
                                          style: IconButton.styleFrom(
                                            alignment: Alignment.center,
                                            // padding: EdgeInsets.all(0),
                                            // backgroundColor: amountInCart > 0
                                            //     ? Colors.amberAccent.shade200
                                            //     : Colors.transparent,
                                          ),
                                          highlightColor: canButtonsBeUsed
                                              ? Colors.transparent
                                              : Colors.transparent,
                                          padding: EdgeInsets.all(0),
                                          onPressed: canButtonsBeUsed
                                              ? () {
                                                  if (hideButtons &&
                                                      amountInCart > 0) {
                                                    setState(() {
                                                      hideButtons = false;
                                                    });
                                                    _hideButtonsAfterTime();
                                                    return;
                                                  } else if (hideButtons &&
                                                      amountInCart == 0) {
                                                    setState(() {
                                                      hideButtons = false;
                                                    });
                                                    _hideButtonsAfterTime();
                                                  } else {
                                                    _hideButtonsAfterTime();
                                                  }
                                                  _incrementAmountInCart();
                                                  setState(() {
                                                    canButtonsBeUsed = false;
                                                  });
                                                  _controller.forward();
                                                  Timer(
                                                    Duration(milliseconds: 350),
                                                    () {
                                                      setState(() {
                                                        canButtonsBeUsed = true;
                                                      });
                                                    },
                                                  );
                                                }
                                              : null,
                                          icon: Container(
                                            // alignment: Alignment.center,
                                            // padding: EdgeInsets.all(
                                            //     5 * globals.scaleParam),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.only(
                                                bottomLeft:
                                                    Radius.circular(100),
                                              ),
                                              // color: Colors.white,
                                            ),
                                            child: amountInCart == 0
                                                ? Icon(
                                                    Icons.add_rounded,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface,
                                                  )
                                                : Text(
                                                    amountInCart.toString(),
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 48 *
                                                          globals.scaleParam,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurface,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : Container()
                          ],
                        ),
                        secondChild: SizedBox(
                          width: widget.constraints.maxWidth * 0.7,
                          height: widget.constraints.maxHeight * 0.2,
                          child: Row(
                            children: [
                              Flexible(
                                flex: 2,
                                fit: FlexFit.tight,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return SizedBox(
                                      width: constraints.maxWidth,
                                      height: constraints.maxHeight,
                                      child: IconButton(
                                        padding: EdgeInsets.all(0),
                                        onPressed: canButtonsBeUsed
                                            ? () {
                                                _hideButtonsAfterTime();
                                                _decrementAmountInCart();
                                                if (amountInCart <= 0) {
                                                  setState(() {
                                                    canButtonsBeUsed = false;
                                                  });
                                                  _controller.reverse();
                                                  Timer(
                                                    Duration(milliseconds: 350),
                                                    () {
                                                      setState(() {
                                                        canButtonsBeUsed = true;
                                                      });
                                                    },
                                                  );
                                                }
                                              }
                                            : null,
                                        icon: Container(
                                          child: Icon(
                                            Icons.remove_rounded,
                                            color: amountInCart > 0
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .secondary,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Flexible(
                                flex: 3,
                                fit: FlexFit.tight,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        "${amountInCart.toString()} шт.", //"${globals.formatCost((cacheAmount * int.parse(item["price"])).toString())} ₸",
                                        textHeightBehavior: TextHeightBehavior(
                                          applyHeightToFirstAscent: false,
                                        ),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 36 * globals.scaleParam,
                                          color: amountInCart != 0
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Flexible(
                                flex: 2,
                                fit: FlexFit.tight,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return SizedBox(
                                      width: constraints.maxWidth,
                                      height: constraints.maxHeight,
                                      child: IconButton(
                                        padding: EdgeInsets.all(0),
                                        onPressed: canButtonsBeUsed
                                            ? () {
                                                _incrementAmountInCart();
                                                _hideButtonsAfterTime();
                                              }
                                            : null,
                                        icon: Container(
                                          child: Icon(
                                            Icons.add_rounded,
                                            color: amountInCart <
                                                    double.parse(
                                                            element["in_stock"])
                                                        .truncate()
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .secondary,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              Flexible(
                flex: 2,
                fit: FlexFit.tight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      flex: 2,
                      fit: FlexFit.tight,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 15 * globals.scaleParam,
                          vertical: 5 * globals.scaleParam,
                        ),
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
                                    child: Container(
                                      alignment: Alignment.topLeft,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surface, // Чтобы текст не обрезало сверху, потому что без цвета, он сжимается до краёв текста
                                      child: RichText(
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        text: TextSpan(
                                          style: TextStyle(
                                            textBaseline:
                                                TextBaseline.alphabetic,
                                            color: Colors.black,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 32 * globals.scaleParam,
                                            height: 3 * globals.scaleParam,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: element["name"],
                                            ),
                                            element["country"] != null
                                                ? WidgetSpan(
                                                    child: Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                        horizontal: 4 *
                                                            globals.scaleParam,
                                                        // vertical: 2 *
                                                        // globals.scaleParam,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors
                                                            .grey.shade200,
                                                        borderRadius:
                                                            BorderRadius.all(
                                                          Radius.circular(10),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        element["country"] ??
                                                            "",
                                                        style: TextStyle(
                                                          color: Colors.black,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 26 *
                                                              globals
                                                                  .scaleParam,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : TextSpan()
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Flexible(
                              fit: FlexFit.tight,
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: 10 * globals.scaleParam,
                                  bottom: 10 * globals.scaleParam,
                                ),
                                child: Text(
                                  "В наличии ${double.parse(element["in_stock"] ?? "0").truncate().toString()} шт.",
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                    fontSize: 30 * globals.scaleParam,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Flexible(
                        child: Padding(
                      padding: EdgeInsets.only(
                        left: 25 * globals.scaleParam,
                        bottom: 15 * globals.scaleParam,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            globals.formatCost(element['price'] ?? ""),
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 38 * globals.scaleParam,
                            ),
                          ),
                          Text(
                            "₸",
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w700,
                              fontSize: 38 * globals.scaleParam,
                            ),
                          ),
                        ],
                      ),
                    ))
                  ],
                ),
              ),
            ],
          ),
          // THIS IS WHERE ACTUAL GESTURE DETECTOR IS
          // It has height that will not contact with plus button in the ItemCard, so user will never open ProductPage when he adds item in cart
          Container(
            width: widget.constraints.maxWidth,
            height: widget.constraints.maxHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        clipBehavior: Clip.antiAlias,
                        useSafeArea: true,
                        isScrollControlled: true,
                        showDragHandle: false,
                        builder: (context) {
                          widget.element["amount"] = amountInCart.toString();
                          return ProductPage(
                            item: widget.element,
                            index: widget.index,
                            returnDataAmount: updateCurrentItem,
                            business: widget.business,
                          );
                        },
                      );
                    },
                    child: Container(
                      width: amountInCart == 0 && canButtonsBeUsed
                          ? widget.constraints.maxWidth * 0.63
                          : widget.constraints.maxWidth * 0.05,
                      height: widget.constraints.maxHeight * 0.23,
                      // color: Colors.red.withOpacity(0.5),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        clipBehavior: Clip.antiAlias,
                        useSafeArea: true,
                        isScrollControlled: true,
                        showDragHandle: false,
                        builder: (context) {
                          widget.element["amount"] = amountInCart.toString();
                          return ProductPage(
                            item: widget.element,
                            index: widget.index,
                            returnDataAmount: updateCurrentItem,
                            business: widget.business,
                          );
                        },
                      );
                    },
                    child: Container(
                        // color: Colors.amber.withOpacity(0.5),
                        ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class ItemCardListTile extends StatefulWidget {
  const ItemCardListTile(
      {super.key,
      required this.element,
      required this.categoryName,
      required this.itemId,
      required this.categoryId,
      required this.scroll,
      required this.business,
      required this.index,
      this.categoryPageUpdateData});
  final Map<String, dynamic> element;
  final String categoryName;

  final int itemId;

  final String categoryId;
  final double scroll;
  final Map<dynamic, dynamic> business;
  final int index;
  final chack = 1;
  final Function(String, int)? categoryPageUpdateData;
  @override
  State<ItemCardListTile> createState() => _ItemCardListTileState();
}

class _ItemCardListTileState extends State<ItemCardListTile>
    with SingleTickerProviderStateMixin<ItemCardListTile> {
  Map<String, dynamic> element = {};
  List<InlineSpan> propertiesWidget = [];
  int amountInCart = 0;
  int previousAmount = 0;
  late int chack;
  Timer? _debounce;
  Timer? _hideButtonsTimer;

  List options = [];
  List cart = [];

  bool canButtonsBeUsed = true;
  bool hideButtons = true;

  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  // late Animation<Offset> _offsetAnimationReverse;

  void _hideButtonsAfterTime() {
    // Cancel the previous timer if it exists
    if (_hideButtonsTimer?.isActive ?? false) _hideButtonsTimer!.cancel();

    // Start a new timer
    _hideButtonsTimer = Timer(Duration(milliseconds: 3000), () {
      setState(() {
        hideButtons = true;
      });
    });
  }

  void _updateItemCountServerCall() {
    changeCartItem(
            element["item_id"], amountInCart, widget.business["business_id"])
        .then((value) {
      if (value == null) {
        if (0 != amountInCart) {
          _updateItemCountServerCall();
        } else {
          setState(() {
            amountInCart = 0;
            previousAmount = amountInCart;
          });
        }
      } else {
        if (int.parse(value) != amountInCart) {
          _updateItemCountServerCall();
        } else {
          setState(() {
            amountInCart = int.parse(value);
            previousAmount = amountInCart;
          });
        }
      }
      // if (widget.updateCategoryPageInfo != null) {
      //   widget.updateCategoryPageInfo!(
      //       amountInCart.toString(), widget.index);
      // }
      if (widget.categoryPageUpdateData != null) {
        widget.categoryPageUpdateData!(amountInCart.toString(), widget.index);
      }
      print(value);
    });
  }

  void _updateItemCount() {
    // Cancel the previous timer if it exists
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Start a new timer
    _debounce = Timer(Duration(milliseconds: 750), () {
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

  Future<void> updateCurrentItem(int amount, [int index = 0]) async {
    if (amountInCart == 0 && amount != 0) {
      _controller.forward();
    } else if (amount == 0) {
      _controller.reverse();
    }
    print("AMOUNT IS $amount");
    setState(() {
      amountInCart = amount;
    });
    await getItem(widget.element["item_id"], widget.business["business_id"])
        .then((value) {
      print(value);
      if (value.isNotEmpty) {
        setState(() {
          options = json.decode(value["options"]) ?? [];
          cart = json.decode(value["cart"]) ?? [];
        });
      }
    });
  }

  Future<void> refreshItemCard() async {
    Map<String, dynamic>? element = await getItem(
        widget.element["item_id"], widget.business["business_id"]);
    print(element);
    setState(() {
      element!["name"] = "123";
      element = element!;
    });
  }

  @override
  void initState() {
    print(widget.element["cart"]);
    // TODO: implement initState
    super.initState();
    setState(() {
      element = widget.element;
      amountInCart = int.parse(element["amount"] ?? "0");
      previousAmount = amountInCart;
      cart = widget.element["cart"] == null ? [] : widget.element["cart"];
      options =
          widget.element["options"] == null ? [] : widget.element["options"];
    });

    // getProperties();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: Offset(0.70, 0),
      end: Offset(-0.1, 0),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    if (amountInCart > 0) {
      _controller.forward();
    }
    // _offsetAnimationReverse = Tween<Offset>(
    //   begin: Offset(0, 0),
    //   end: Offset(1, 0),
    // ).animate(CurvedAnimation(
    //   parent: _controller,
    //   curve: Curves.linear,
    // ));
  }

  @override
  void dispose() {
    // Trigger the debounce action immediately if the timer is active
    if (widget.categoryPageUpdateData != null) {
      widget.categoryPageUpdateData!(amountInCart.toString(), widget.index);
    }
    if (_debounce?.isActive ?? false) {
      _debounce?.cancel();
      _updateItemCountServerCall();
    }
    super.dispose();
  }

  List<Widget> _getCartOptions(dynamic option_items) {
    List<Widget> selectedOptions = [];
    if (option_items is List) {
      option_items.forEach((option_item) {
        dynamic s_option = options.firstWhere((option) =>
            option["relation_id"].toString() == option_item.toString());
        print("=======================================");
        print(s_option);
        selectedOptions.add(Text(
          s_option["name"],
          style: TextStyle(
              fontSize: 24 * globals.scaleParam, fontWeight: FontWeight.w800),
        ));
      });
    } else {
      dynamic s_option = options.firstWhere((option) =>
          option["relation_id"].toString() == option_items.toString());
      print("=======================================");
      print(s_option);
      selectedOptions.add(Text(
        s_option["name"],
        style: TextStyle(
            fontSize: 24 * globals.scaleParam, fontWeight: FontWeight.w800),
      ));
    }
    return selectedOptions;
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

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 750),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      margin: EdgeInsets.all(10 * globals.scaleParam),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(
          Radius.circular(30 * globals.scaleParam),
        ),
        color: Colors.white,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 300 * globals.scaleParam,
            child: Row(
              children: [
                Flexible(
                  fit: FlexFit.tight,
                  child: GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        clipBehavior: Clip.antiAlias,
                        useSafeArea: true,
                        isScrollControlled: true,
                        showDragHandle: false,
                        builder: (context) {
                          widget.element["amount"] = amountInCart.toString();
                          return ProductPage(
                            item: widget.element,
                            index: widget.index,
                            returnDataAmount: updateCurrentItem,
                            business: widget.business,
                          );
                        },
                      );
                    },
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(
                            Radius.circular(30 * globals.scaleParam),
                          ),
                        ),
                        child: ExtendedImage.network(
                          element["img"] ??
                              "https://upload.wikimedia.org/wikipedia/commons/8/8f/Example_image.svg",
                          height: double.infinity,
                          clearMemoryCacheWhenDispose: true,
                          enableMemoryCache: true,
                          enableLoadState: false,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Container(
                                  alignment: Alignment.topLeft,
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          element["name"],
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                          style: TextStyle(
                                              fontSize: 28 * globals.scaleParam,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      )
                                    ],
                                  )),
                            ),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    globals.formatCost(
                                        (element['price'] ?? "").toString()),
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 38 * globals.scaleParam,
                                    ),
                                  ),
                                  Text(
                                    "₸",
                                    textAlign: TextAlign.start,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 38 * globals.scaleParam,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: AnimatedCrossFade(
                          alignment: Alignment.topRight,
                          duration: Durations.medium1,
                          crossFadeState: amountInCart == 0 ||
                                  (amountInCart > 0 && hideButtons)
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                          firstChild: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              int.parse(widget.element["option"] ?? "0") == 1
                                  ? IconButton(
                                      style: IconButton.styleFrom(
                                        alignment: Alignment.center,
                                        // padding: EdgeInsets.all(0),
                                        // backgroundColor: amountInCart > 0
                                        //     ? Colors.amberAccent.shade200
                                        //     : Colors.transparent,
                                      ),
                                      highlightColor: canButtonsBeUsed
                                          ? Colors.transparent
                                          : Colors.transparent,
                                      padding: EdgeInsets.all(0),
                                      onPressed: canButtonsBeUsed
                                          ? () {
                                              if (hideButtons &&
                                                  amountInCart > 0) {
                                                setState(() {
                                                  hideButtons = false;
                                                });
                                                _hideButtonsAfterTime();
                                                return;
                                              } else if (hideButtons &&
                                                  amountInCart == 0) {
                                                setState(() {
                                                  hideButtons = false;
                                                });
                                                _hideButtonsAfterTime();
                                              } else {
                                                _hideButtonsAfterTime();
                                              }
                                              _incrementAmountInCart();
                                              setState(() {
                                                canButtonsBeUsed = false;
                                              });
                                              _controller.forward();
                                              Timer(
                                                Duration(milliseconds: 350),
                                                () {
                                                  setState(() {
                                                    canButtonsBeUsed = true;
                                                  });
                                                },
                                              );
                                            }
                                          : () {},
                                      icon: amountInCart == 0
                                          ? Icon(
                                              Icons.add_rounded,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                            )
                                          : Text(
                                              amountInCart.toString(),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize:
                                                    48 * globals.scaleParam,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                              ),
                                            ),
                                    )
                                  : IconButton(
                                      onPressed: () {},
                                      icon: Icon(
                                        Icons.add_rounded,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                            ],
                          ),
                          secondChild: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                padding: EdgeInsets.all(0),
                                onPressed: canButtonsBeUsed
                                    ? () {
                                        _hideButtonsAfterTime();
                                        _decrementAmountInCart();
                                        if (amountInCart <= 0) {
                                          setState(() {
                                            canButtonsBeUsed = false;
                                          });
                                          _controller.reverse();
                                          Timer(
                                            Duration(milliseconds: 350),
                                            () {
                                              setState(() {
                                                canButtonsBeUsed = true;
                                              });
                                            },
                                          );
                                        }
                                      }
                                    : null,
                                icon: Container(
                                  child: Icon(
                                    Icons.remove_rounded,
                                    color: amountInCart > 0
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                        : Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                  ),
                                ),
                              ),
                              Text(
                                "${amountInCart.toString()} шт.", //"${globals.formatCost((cacheAmount * int.parse(item["price"])).toString())} ₸",
                                textHeightBehavior: TextHeightBehavior(
                                  applyHeightToFirstAscent: false,
                                ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 36 * globals.scaleParam,
                                  color: amountInCart != 0
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Colors.grey.shade600,
                                ),
                              ),
                              IconButton(
                                padding: EdgeInsets.all(0),
                                onPressed: canButtonsBeUsed
                                    ? () {
                                        _incrementAmountInCart();
                                        _hideButtonsAfterTime();
                                      }
                                    : null,
                                icon: Container(
                                  child: Icon(
                                    Icons.add_rounded,
                                    color: amountInCart <
                                            element["in_stock"].truncate()
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                        : Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
          options.isNotEmpty && cart.isNotEmpty
              ? ListView.builder(
                  primary: false,
                  physics: NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: cart.length,
                  itemBuilder: (context, index) {
                    List _options1 = cart[index]["options"];

                    return Container(
                      padding: EdgeInsets.all(20 * globals.scaleParam),
                      decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black38,
                                blurRadius: 3,
                                offset: Offset(2, 2))
                          ],
                          color: Colors.white,
                          borderRadius: BorderRadius.all(
                              Radius.circular(20 * globals.scaleParam))
                          // border: Border(
                          //     top: BorderSide(color: Colors.black12))
                          ),
                      margin: EdgeInsets.symmetric(
                          vertical: 5, horizontal: 20 * globals.scaleParam),
                      child: Row(
                        children: [
                          Flexible(
                              child: Text(
                            cart[index]["amount"].toString() + "x",
                            style: TextStyle(fontWeight: FontWeight.w900),
                          )),
                          Spacer(),
                          Expanded(
                            flex: 9,
                            child: Column(
                              children: [
                                ListView.builder(
                                  shrinkWrap: true,
                                  primary: false,
                                  //  _getCartOptions([3, 4])
                                  itemCount: _options1.length,
                                  itemBuilder: (context, index2) {
                                    return Wrap(
                                      spacing: 10,
                                      children: _getCartOptions(
                                          _options1[index2]["option_items"]),
                                    );
                                  },
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )
              : const SizedBox(),
        ],
      ),
    );
  }
}
