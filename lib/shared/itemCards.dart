import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  final String business_id;
  final String categoryId;
  final String categoryName;
  final int chack = 1;
  final Map<String, dynamic> element;
  final String itemId;
  final double scroll;

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  late int chack;
  Map<String, dynamic> element = {};
  bool isNumPickerActive = false;
  List<InlineSpan> propertiesWidget = [];

  @override
  void initState() {
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
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black),
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
    Map<String, dynamic>? element = await getItem(widget.element["item_id"], widget.business_id);
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
      width: (MediaQuery.of(context).size.width * 2) * (MediaQuery.sizeOf(context).width / 720),
      height: (MediaQuery.of(context).size.height * 0.56) * (MediaQuery.sizeOf(context).width / 720),
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
                                    padding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
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
                              globals.formatCost((element['price'] ?? "0").toString()),
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                                fontSize: 56 * (MediaQuery.sizeOf(context).width / 720),
                              ),
                            ),
                            Text(
                              "₸",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w900,
                                fontSize: 56 * (MediaQuery.sizeOf(context).width / 720),
                              ),
                            )
                          ],
                        ),
                        element["prev_price"] != null
                            ? Padding(
                                padding: EdgeInsets.only(left: 5),
                                child: Row(
                                  children: [
                                    Text(
                                      globals.formatCost(element["prev_price"] ?? 0),
                                      style: TextStyle(
                                          decoration: TextDecoration.lineThrough,
                                          decorationColor: Colors.grey.shade500,
                                          decorationThickness: 1.85,
                                          color: Colors.grey.shade500,
                                          fontSize: 28 * (MediaQuery.sizeOf(context).width / 720),
                                          fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      "₸",
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 28 * (MediaQuery.sizeOf(context).width / 720)),
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

// class ItemCardMedium extends StatefulWidget {
//   const ItemCardMedium(
//       {super.key,
//       required this.itemId,
//       required this.element,
//       required this.categoryName,
//       required this.categoryId,
//       required this.scroll,
//       required this.business,
//       required this.index,
//       this.categoryPageUpdateData});

//   final Function(String, int)? categoryPageUpdateData;
//   final Map<dynamic, dynamic> business;
//   final String categoryId;
//   final String categoryName;
//   final chack = 1;
//   final Map<String, dynamic> element;
//   final int index;
//   final int itemId;
//   final double scroll;

//   @override
//   State<ItemCardMedium> createState() => _ItemCardMediumState();
// }

// class _ItemCardMediumState extends State<ItemCardMedium> with SingleTickerProviderStateMixin<ItemCardMedium> {
//   int amountInCart = 0;
//   bool canButtonsBeUsed = true;
//   late int chack;
//   Map<String, dynamic> element = {};
//   int previousAmount = 0;
//   List<InlineSpan> propertiesWidget = [];

//   late AnimationController _controller;
//   Timer? _debounce;
//   late Animation<Offset> _offsetAnimation;

//   @override
//   void dispose() {
//     // Trigger the debounce action immediately if the timer is active
//     if (widget.categoryPageUpdateData != null) {
//       widget.categoryPageUpdateData!(amountInCart.toString(), widget.index);
//     }
//     if (_debounce?.isActive ?? false) {
//       _debounce?.cancel();
//       _updateItemCountServerCall();
//     }
//     super.dispose();
//   }

//   @override
//   void initState() {
//
//     super.initState();
//     setState(() {
//       element = widget.element;
//       amountInCart = int.parse(element["amount"] ?? "0");
//       previousAmount = amountInCart;
//     });
//     // getProperties();
//     _controller = AnimationController(
//       duration: const Duration(milliseconds: 150),
//       vsync: this,
//     );

//     _offsetAnimation = Tween<Offset>(
//       begin: Offset(0.70, 0),
//       end: Offset(-0.1, 0),
//     ).animate(
//       CurvedAnimation(
//         parent: _controller,
//         curve: Curves.easeOut,
//       ),
//     );

//     if (amountInCart > 0) {
//       _controller.forward();
//     }
//     // _offsetAnimationReverse = Tween<Offset>(
//     //   begin: Offset(0, 0),
//     //   end: Offset(1, 0),
//     // ).animate(CurvedAnimation(
//     //   parent: _controller,
//     //   curve: Curves.linear,
//     // ));
//   }

//   void updateCurrentItem(int amount, [int index = 0]) {
//     if (amountInCart == 0 && amount != 0) {
//       _controller.forward();
//     } else if (amount == 0) {
//       _controller.reverse();
//     }
//     print("AMOUNT IS $amount");
//     setState(() {
//       amountInCart = amount;
//     });
//   }

//   Future<void> refreshItemCard() async {
//     Map<String, dynamic>? element = await getItem(widget.element["item_id"], widget.business["business_id"]);
//     print(element);
//     setState(() {
//       element!["name"] = "123";
//       element = element!;
//     });
//   }

//   void getProperties() {
//     if (widget.element["properties"] != null) {
//       List<InlineSpan> propertiesT = [];
//       List<String> properties = widget.element["properties"].split(",");
//       print(properties);
//       for (var element in properties) {
//         List temp = element.split(":");
//         propertiesT.add(
//           WidgetSpan(
//             child: Row(
//               children: [
//                 Text(
//                   temp[1],
//                   style: TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.w700,
//                     color: Colors.black,
//                   ),
//                 ),
//                 Image.asset(
//                   "assets/property_icons/${temp[0]}.png",
//                   width: 14,
//                   height: 14,
//                 ),
//                 SizedBox(
//                   width: 10,
//                 )
//               ],
//             ),
//           ),
//         );
//       }
//       setState(() {
//         propertiesWidget = propertiesT;
//       });
//     }
//   }

//   // late Animation<Offset> _offsetAnimationReverse;

//   void _updateItemCountServerCall() {
//     changeCartItem(element["item_id"], amountInCart, widget.business["business_id"]).then((value) {
//       if (value == null) {
//         if (0 != amountInCart) {
//           _updateItemCountServerCall();
//         } else {
//           setState(() {
//             amountInCart = 0;
//             previousAmount = amountInCart;
//           });
//         }
//       } else {
//         if (int.parse(value) != amountInCart) {
//           _updateItemCountServerCall();
//         } else {
//           setState(() {
//             amountInCart = int.parse(value);
//             previousAmount = amountInCart;
//           });
//         }
//       }
//       // if (widget.updateCategoryPageInfo != null) {
//       //   widget.updateCategoryPageInfo!(
//       //       amountInCart.toString(), widget.index);
//       // }
//       if (widget.categoryPageUpdateData != null) {
//         widget.categoryPageUpdateData!(amountInCart.toString(), widget.index);
//       }
//       print(value);
//     });
//   }

//   void _updateItemCount() {
//     // Cancel the previous timer if it exists
//     if (_debounce?.isActive ?? false) _debounce!.cancel();

//     // Start a new timer
//     _debounce = Timer(Duration(milliseconds: 750), () {
//       // Call your server update function here
//       _updateItemCountServerCall();
//     });
//   }

//   void _decrementAmountInCart() {
//     if (amountInCart > 0) {
//       setState(() {
//         amountInCart--;
//       });
//       _updateItemCount();
//     }
//   }

//   void _incrementAmountInCart() {
//     if (amountInCart + 1 <= double.parse(element["in_stock"]).truncate()) {
//       setState(() {
//         amountInCart++;
//       });
//       _updateItemCount();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     chack = widget.chack;
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 5 * globals.scaleParam),
//       width: double.infinity,
//       height: 300 * globals.scaleParam,
//       child: Stack(
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//             mainAxisSize: MainAxisSize.max,
//             children: [
//               Flexible(
//                 flex: 2,
//                 fit: FlexFit.tight,
//                 child: GestureDetector(
//                   behavior: HitTestBehavior.opaque,
//                   key: Key(widget.element["item_id"].toString()),
//                   onTap: () {
//                     showModalBottomSheet(
//                       context: context,
//                       clipBehavior: Clip.antiAlias,
//                       useSafeArea: true,
//                       showDragHandle: false,
//                       isScrollControlled: true,
//                       builder: (context) {
//                         widget.element["amount"] = amountInCart.toString();
//                         return ProductPage(
//                           item: widget.element,
//                           index: widget.index,
//                           returnDataAmount: updateCurrentItem,
//                           business: widget.business,
//                         );
//                       },
//                     );
//                   },
//                   // как будто бы картинки быстрее грузятся, я хз я не тестил чисто на глаз посмотрел
//                   // ну и кэш чистится
//                   // это я тоже не тестил
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Flexible(
//                         fit: FlexFit.tight,
//                         child: Container(
//                           clipBehavior: Clip.antiAlias,
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.all(Radius.circular(5)),
//                             color: Colors.white,
//                           ),
//                           child: ExtendedImage.network(
//                             element["img"],
//                             fit: BoxFit.fitHeight,
//                             clearMemoryCacheWhenDispose: true,
//                             enableMemoryCache: true,
//                             enableLoadState: false,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                   //   fit: BoxFit.cover,
//                   // cacheManager: CacheManager(
//                   //   Config(
//                   //     "itemImage ${element["item_id"].toString()}",
//                   //     stalePeriod: Duration(days: 700),
//                   //   ),
//                   // ),
//                   // imageBuilder: (context, imageProvider) {
//                   // return Column(
//                   //   mainAxisAlignment: MainAxisAlignment.center,
//                   //   children: [
//                   //     Flexible(
//                   //       fit: FlexFit.tight,
//                   //       child: Container(
//                   //         clipBehavior: Clip.antiAlias,
//                   //         decoration: BoxDecoration(
//                   //           borderRadius:
//                   //               BorderRadius.all(Radius.circular(5)),
//                   //           color: Colors.white,
//                   //         ),
//                   //         child: Image(
//                   //           image: imageProvider,
//                   //           fit: BoxFit.fitHeight,
//                   //         ),
//                   //       ),
//                   //     ),
//                   //   ],
//                   // );
//                   // },
//                   // errorWidget: (context, url, error) {
//                   //   return LayoutBuilder(
//                   //     builder: (context, constraints) {
//                   //       return FractionallySizedBox(
//                   //         heightFactor: 1,
//                   //         widthFactor: 2 / 4,
//                   //         child: Image.asset(
//                   //           'assets/category_icons/no_image_ico.png',
//                   //           opacity: AlwaysStoppedAnimation(0.5),
//                   //         ),
//                   //       );
//                   //     },
//                   //   );
//                   // },
//                 ),
//               ),
//               Flexible(
//                 flex: 5,
//                 fit: FlexFit.tight,
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   mainAxisSize: MainAxisSize.max,
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Flexible(
//                       flex: 2,
//                       fit: FlexFit.tight,
//                       child: GestureDetector(
//                         behavior: HitTestBehavior.opaque,
//                         key: Key(widget.element["item_id"].toString()),
//                         onTap: () {
//                           showModalBottomSheet(
//                             context: context,
//                             clipBehavior: Clip.antiAlias,
//                             useSafeArea: true,
//                             isScrollControlled: true,
//                             showDragHandle: false,
//                             builder: (context) {
//                               widget.element["amount"] = amountInCart.toString();
//                               return ProductPage(
//                                 item: widget.element,
//                                 index: widget.index,
//                                 returnDataAmount: updateCurrentItem,
//                                 business: widget.business,
//                               );
//                             },
//                           );
//                         },
//                         child: Padding(
//                           padding: EdgeInsets.symmetric(
//                             horizontal: 15 * globals.scaleParam,
//                             // vertical: 5 * globals.scaleParam,
//                           ),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Flexible(
//                                 flex: 2,
//                                 fit: FlexFit.tight,
//                                 child: Row(
//                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                   children: [
//                                     Flexible(
//                                       flex: 5,
//                                       fit: FlexFit.tight,
//                                       child: Container(
//                                         color: Theme.of(context)
//                                             .colorScheme
//                                             .surface, // Чтобы текст не обрезало сверху, потому что без цвета, он сжимается до краёв текста
//                                         child: RichText(
//                                           maxLines: 2,
//                                           overflow: TextOverflow.ellipsis,
//                                           text: TextSpan(
//                                             style: TextStyle(
//                                               textBaseline: TextBaseline.alphabetic,
//                                               color: Colors.black,
//                                               fontWeight: FontWeight.w500,
//                                               fontSize: 30 * globals.scaleParam,
//                                               height: 2.5 * globals.scaleParam,
//                                             ),
//                                             children: [
//                                               TextSpan(
//                                                 text: element["name"],
//                                               ),
//                                               element["country"] != null
//                                                   ? WidgetSpan(
//                                                       child: Container(
//                                                         padding: EdgeInsets.symmetric(
//                                                           horizontal: 4 * globals.scaleParam,
//                                                           // vertical: 2 *
//                                                           // globals.scaleParam,
//                                                         ),
//                                                         decoration: BoxDecoration(
//                                                           color: Colors.grey.shade200,
//                                                           borderRadius: BorderRadius.all(
//                                                             Radius.circular(10),
//                                                           ),
//                                                         ),
//                                                         child: Text(
//                                                           element["country"] ?? "",
//                                                           style: TextStyle(
//                                                             color: Colors.black,
//                                                             fontWeight: FontWeight.w600,
//                                                             fontSize: 26 * globals.scaleParam,
//                                                           ),
//                                                         ),
//                                                       ),
//                                                     )
//                                                   : TextSpan()
//                                             ],
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                               Flexible(
//                                 fit: FlexFit.tight,
//                                 child: Text(
//                                   "В наличии ${element["in_stock"].toString()} шт",
//                                   style: TextStyle(
//                                     color: Theme.of(context).colorScheme.secondary,
//                                     fontSize: 28 * globals.scaleParam,
//                                     fontWeight: FontWeight.w500,
//                                   ),
//                                 ),
//                               ),
//                               Flexible(
//                                 fit: FlexFit.tight,
//                                 child: Row(
//                                   children: [
//                                     Flexible(
//                                       child: Text(
//                                         globals.formatCost((element['price'] ?? "").toString()),
//                                         style: TextStyle(
//                                           color: Colors.black,
//                                           fontWeight: FontWeight.w600,
//                                           fontSize: 36 * globals.scaleParam,
//                                         ),
//                                       ),
//                                     ),
//                                     Flexible(
//                                       child: Text(
//                                         "₸",
//                                         textAlign: TextAlign.start,
//                                         style: TextStyle(
//                                           color: Colors.grey.shade600,
//                                           fontWeight: FontWeight.w700,
//                                           fontSize: 36 * globals.scaleParam,
//                                         ),
//                                       ),
//                                     )
//                                   ],
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                     Flexible(
//                       fit: FlexFit.tight,
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.start,
//                         crossAxisAlignment: CrossAxisAlignment.end,
//                         children: [
//                           Flexible(
//                             flex: 5,
//                             child: Column(
//                               mainAxisAlignment: MainAxisAlignment.end,
//                               children: [
//                                 Flexible(
//                                   fit: FlexFit.tight,
//                                   child: Stack(
//                                     children: [
//                                       LayoutBuilder(
//                                         builder: (context, constraints) {
//                                           return Row(
//                                             children: [
//                                               Container(
//                                                 width: constraints.maxWidth * 0.85,
//                                                 alignment: Alignment.centerLeft,
//                                                 child: ClipRect(
//                                                   clipBehavior: Clip.antiAlias,
//                                                   child: OverflowBox(
//                                                     maxWidth: constraints.maxWidth,
//                                                     child: SlideTransition(
//                                                       position: _offsetAnimation,
//                                                       child: Row(
//                                                         children: [
//                                                           Flexible(
//                                                               fit: FlexFit.tight,
//                                                               child: widget.element["option"] == 1
//                                                                   ? IconButton(
//                                                                       highlightColor: canButtonsBeUsed ? Colors.transparent : Colors.transparent,
//                                                                       padding: EdgeInsets.all(0),
//                                                                       onPressed: canButtonsBeUsed
//                                                                           ? () {
//                                                                               _incrementAmountInCart();
//                                                                               setState(() {
//                                                                                 canButtonsBeUsed = false;
//                                                                               });
//                                                                               _controller.forward();
//                                                                               Timer(
//                                                                                 Duration(milliseconds: 100),
//                                                                                 () {
//                                                                                   setState(() {
//                                                                                     canButtonsBeUsed = true;
//                                                                                   });
//                                                                                 },
//                                                                               );
//                                                                             }
//                                                                           : null,
//                                                                       icon: Container(
//                                                                         padding: EdgeInsets.all(5 * globals.scaleParam),
//                                                                         decoration: BoxDecoration(
//                                                                           borderRadius: BorderRadius.all(
//                                                                             Radius.circular(100),
//                                                                           ),
//                                                                           color: Colors.white,
//                                                                           boxShadow: [
//                                                                             BoxShadow(
//                                                                               color: Color.fromARGB(255, 180, 180, 180),
//                                                                               spreadRadius: 0,
//                                                                               blurRadius: 1,
//                                                                               offset: Offset(0.2, 0.9),
//                                                                             ),
//                                                                           ],
//                                                                         ),
//                                                                         child: Icon(
//                                                                           Icons.add_rounded,
//                                                                           color: Theme.of(context).colorScheme.onSurface,
//                                                                         ),
//                                                                       ),
//                                                                     )
//                                                                   : Container()),
//                                                           Flexible(
//                                                             fit: FlexFit.tight,
//                                                             child: IconButton(
//                                                               padding: EdgeInsets.all(0),
//                                                               onPressed: canButtonsBeUsed
//                                                                   ? () {
//                                                                       _decrementAmountInCart();
//                                                                       if (amountInCart <= 0) {
//                                                                         setState(() {
//                                                                           canButtonsBeUsed = false;
//                                                                         });
//                                                                         _controller.reverse();
//                                                                         Timer(
//                                                                           Duration(milliseconds: 100),
//                                                                           () {
//                                                                             setState(() {
//                                                                               canButtonsBeUsed = true;
//                                                                             });
//                                                                           },
//                                                                         );
//                                                                       }
//                                                                     }
//                                                                   : null,
//                                                               icon: Container(
//                                                                 decoration: BoxDecoration(
//                                                                   border: Border.all(
//                                                                     color: amountInCart > 0
//                                                                         ? Theme.of(context).colorScheme.onSurface
//                                                                         : Theme.of(context).colorScheme.secondary,
//                                                                   ),
//                                                                   borderRadius: BorderRadius.circular(6),
//                                                                 ),
//                                                                 child: Icon(
//                                                                   Icons.remove_rounded,
//                                                                   color: amountInCart > 0
//                                                                       ? Theme.of(context).colorScheme.onSurface
//                                                                       : Theme.of(context).colorScheme.secondary,
//                                                                 ),
//                                                               ),
//                                                             ),
//                                                           ),
//                                                           Flexible(
//                                                             flex: 2,
//                                                             fit: FlexFit.tight,
//                                                             child: Row(
//                                                               mainAxisAlignment: MainAxisAlignment.center,
//                                                               children: [
//                                                                 Flexible(
//                                                                   child: Text(
//                                                                     "${amountInCart.toString()} шт", //"${globals.formatCost((cacheAmount * int.parse(item["price"])).toString())} ₸",
//                                                                     textHeightBehavior: TextHeightBehavior(
//                                                                       applyHeightToFirstAscent: false,
//                                                                     ),
//                                                                     textAlign: TextAlign.center,
//                                                                     style: TextStyle(
//                                                                       fontWeight: FontWeight.w700,
//                                                                       fontSize: 36 * globals.scaleParam,
//                                                                       color: amountInCart != 0
//                                                                           ? Theme.of(context).colorScheme.onSurface
//                                                                           : Colors.grey.shade600,
//                                                                     ),
//                                                                   ),
//                                                                 ),
//                                                               ],
//                                                             ),
//                                                           ),
//                                                           Flexible(
//                                                             fit: FlexFit.tight,
//                                                             child: IconButton(
//                                                               padding: EdgeInsets.all(0),
//                                                               onPressed: canButtonsBeUsed
//                                                                   ? () {
//                                                                       _incrementAmountInCart();
//                                                                     }
//                                                                   : null,
//                                                               icon: Container(
//                                                                 decoration: BoxDecoration(
//                                                                   border: Border.all(
//                                                                     color: amountInCart < element["in_stock"]
//                                                                         ? Theme.of(context).colorScheme.onSurface
//                                                                         : Theme.of(context).colorScheme.secondary,
//                                                                   ),
//                                                                   borderRadius: BorderRadius.circular(6),
//                                                                 ),
//                                                                 child: Icon(
//                                                                   Icons.add_rounded,
//                                                                   color: amountInCart < element["in_stock"]
//                                                                       ? Theme.of(context).colorScheme.onSurface
//                                                                       : Theme.of(context).colorScheme.secondary,
//                                                                 ),
//                                                               ),
//                                                             ),
//                                                           ),
//                                                         ],
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                               ),
//                                             ],
//                                           );
//                                         },
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                           Flexible(
//                             fit: FlexFit.tight,
//                             child: Column(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 Flexible(
//                                   fit: FlexFit.tight,
//                                   child: LikeButton(
//                                     is_liked: element["is_liked"],
//                                     item_id: element["item_id"],
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }

class ItemCardMinimal extends StatefulWidget {
  const ItemCardMinimal(
      {super.key,
      required this.element,
      required this.categoryName,
      required this.categoryId,
      required this.scroll,
      required this.index,
      required this.business,
      this.updateExternalInfo});

  final Function(int, int)? updateExternalInfo; // Update CartPage sum!!!!
  final Map business;
  final String categoryId;
  final String categoryName;
  final int chack = 1;
  final Map<String, dynamic> element;
  final int index;
  final double scroll;

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
  late int chack;
  Map<String, dynamic> element = {};
  List<InlineSpan> propertiesWidget = [];

  @override
  void initState() {
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
    return Container(
      clipBehavior: Clip.antiAliasWithSaveLayer,
      margin: EdgeInsets.only(
        bottom: 10 * globals.scaleParam,
        left: 15 * globals.scaleParam,
      ),
      padding: EdgeInsets.all(2 * globals.scaleParam),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(
          Radius.circular(30 * globals.scaleParam),
        ),
        color: Colors.white,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Flexible(
              //   flex: 3,
              //   fit: FlexFit.tight,
              //   child: Padding(
              //     padding: EdgeInsets.only(right: 5 * globals.scaleParam),
              //     child: Text(
              //       "${element["amount_b"]} x",
              //       textAlign: TextAlign.end,
              //       style: TextStyle(
              //         fontSize: 34 * globals.scaleParam,
              //         fontWeight: FontWeight.w900,
              //       ),
              //     ),
              //   ),
              // ),
              Spacer(),
              Flexible(
                flex: MediaQuery.of(context).size.aspectRatio > 1 ? 2 : 3,
                fit: FlexFit.tight,
                child: element["thumb"] != null
                    ? ExtendedImage.network(
                        element["thumb"],
                        fit: BoxFit.contain,
                      )
                    : SizedBox(),
              ),
              Expanded(
                flex: 17,
                child: Padding(
                  padding: EdgeInsets.only(left: 20 * globals.scaleParam),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 150 * globals.scaleParam,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Padding(
                              padding: EdgeInsets.all(5 * globals.scaleParam),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    flex: 12,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      mainAxisSize: MainAxisSize.max,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Flexible(
                                          flex: 2,
                                          fit: FlexFit.tight,
                                          child: Padding(
                                            padding: EdgeInsets.all(1 * globals.scaleParam),
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
                                                      fontFamily: "Raleway",
                                                      fontVariations: <FontVariation>[FontVariation('wght', 600)],
                                                      fontSize: 32 * globals.scaleParam,
                                                      height: 3 * globals.scaleParam,
                                                    ),
                                                  ),
                                                  element["country"] != null
                                                      ? WidgetSpan(
                                                          child: Container(
                                                            padding: EdgeInsets.symmetric(
                                                                horizontal: 4 * globals.scaleParam, vertical: 2 * globals.scaleParam),
                                                            decoration: BoxDecoration(
                                                              color: Colors.grey.shade200,
                                                              borderRadius: BorderRadius.all(
                                                                Radius.circular(10),
                                                              ),
                                                            ),
                                                            child: Text(
                                                              element["country"] ?? "",
                                                              style: TextStyle(
                                                                fontFamily: "Raleway",
                                                                fontVariations: <FontVariation>[FontVariation('wght', 600)],
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
                                                  "${globals.formatCost(element["price"].toString())} ₸ за 1 ${element["unit"]}",
                                                  style: TextStyle(
                                                    fontFamily: "Raleway",
                                                    color: Colors.grey,
                                                    fontVariations: <FontVariation>[FontVariation('wght', 600)],
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
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      element["selected_options"] != null
                          ? Padding(
                              padding: EdgeInsets.only(top: 10 * globals.scaleParam, bottom: 20 * globals.scaleParam),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ListView.builder(
                                      primary: false,
                                      physics: NeverScrollableScrollPhysics(),
                                      shrinkWrap: true,
                                      itemCount: element["selected_options"].length,
                                      itemBuilder: (context, index) {
                                        // List _selected_options = [];
                                        // if (cart[index]["selected_options"] != null) {
                                        //   _selected_options = cart[index]["selected_options"];
                                        //   // return SizedBox();
                                        // } else if (options.isEmpty) {
                                        //   _selected_options = [
                                        //     {"name": cart[index]["name"]}
                                        //   ];
                                        // }

                                        return Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 20 * globals.scaleParam,
                                            vertical: 5 * globals.scaleParam,
                                          ),
                                          decoration: BoxDecoration(
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Colors.black12,
                                                  blurRadius: 3,
                                                  offset: Offset(2, 2),
                                                ),
                                              ],
                                              color: Colors.white,
                                              borderRadius: BorderRadius.all(
                                                Radius.circular(20 * globals.scaleParam),
                                              )
                                              // border: Border(
                                              //     top: BorderSide(color: Colors.black12))
                                              ),
                                          margin: EdgeInsets.only(
                                            top: 5 * globals.scaleParam,
                                            bottom: 5 * globals.scaleParam,
                                            right: 20 * globals.scaleParam,
                                          ),
                                          child: Row(
                                            children: [
                                              Flexible(
                                                flex: 2,
                                                fit: FlexFit.tight,
                                                child: Text(
                                                  element["selected_options"][index]["price"] != 0 &&
                                                          element["selected_options"][index]["price"] != null
                                                      ? "${element["selected_options"][index]["price"]} ₸"
                                                      : "",
                                                  textAlign: TextAlign.start,
                                                  style: TextStyle(
                                                    fontSize: 32 * globals.scaleParam,
                                                    fontVariations: <FontVariation>[FontVariation('wght', 600)],
                                                    height: 2.5 * globals.scaleParam,
                                                  ),
                                                ),
                                              ),
                                              // element["selected_options"][index]["price"] != 0 && element["selected_options"][index]["price"] != null
                                              //     ? Flexible(
                                              //         fit: FlexFit.tight,
                                              //         child: Text(
                                              //           "${element["selected_options"][index]["price"]}₸",
                                              //           style: TextStyle(
                                              //             fontWeight: FontWeight.w900,
                                              //           ),
                                              //         ),
                                              //       )
                                              //     : SizedBox(),
                                              Flexible(
                                                flex: 8,
                                                fit: FlexFit.tight,
                                                child: Text(
                                                  "${element["selected_options"][index]["name"]}",
                                                  style: TextStyle(
                                                    fontSize: 32 * globals.scaleParam,
                                                    fontVariations: <FontVariation>[FontVariation('wght', 600)],
                                                    height: 3 * globals.scaleParam,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : SizedBox(),

                      // Expanded(
                      //   child: element["selected_options"].isEmpty
                      //       ? Container(
                      //           height: 50,
                      //           color: Colors.green,
                      //         )
                      //       : Container(
                      //           height: 50,
                      //           color: Colors.red,
                      //         ),
                      // ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Container(
            height: 80 * globals.scaleParam,
            margin: EdgeInsets.only(top: 10 * globals.scaleParam),
            padding: EdgeInsets.symmetric(horizontal: 10 * globals.scaleParam),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
              // borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Spacer(
                  flex: 2,
                ),
                Flexible(
                  flex: 10,
                  fit: FlexFit.tight,
                  child: Row(
                    children: [
                      Flexible(
                        flex: 2,
                        child: Text(
                          "Сумма: ${globals.formatCost(((element['price'] * (element["amount"] - (element["promotions"] != null ? double.parse((element["amount"] / (element["promotions"][0]["add_amount"] + element["promotions"][0]["base_amount"])).toString()).truncate() : 0))) + (element["selected_options"] != null ? ((element["selected_options"][0]["price"] * element["amount"]) / element["selected_options"][0]["parent_item_amount"]) : 0)).toString())} ₸",
                          style: TextStyle(
                            fontFamily: "Raleway",
                            fontVariations: <FontVariation>[FontVariation('wght', 700)],
                            fontSize: 32 * globals.scaleParam,
                          ),
                        ),
                      ),
                      element["promotions"] != null
                          ? Flexible(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8 * globals.scaleParam),
                                child: Text(
                                  "${globals.formatCost(((element['price'] * element["amount"]) + (element["selected_options"] != null ? ((element["selected_options"][0]["price"] * element["amount"]) / element["selected_options"][0]["parent_item_amount"]) : 0)).toString())} ₸",
                                  style: TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: Colors.grey,
                                    fontFamily: "Raleway",
                                    color: Colors.grey,
                                    fontVariations: <FontVariation>[FontVariation('wght', 600)],
                                    fontSize: 28 * globals.scaleParam,
                                  ),
                                ),
                              ),
                            )
                          : SizedBox(),
                    ],
                  ),
                ),
                Flexible(
                  flex: 7,
                  fit: FlexFit.tight,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8 * globals.scaleParam),
                    child: Text(
                      "${element["amount"]} ${element["unit"]}",
                      style: TextStyle(
                        color: Colors.black,
                        fontVariations: <FontVariation>[FontVariation('wght', 600)],
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

class ItemCardNoImage extends StatefulWidget {
  const ItemCardNoImage(
      {super.key,
      required this.itemId,
      required this.element,
      required this.categoryName,
      required this.categoryId,
      required this.business_id,
      required this.scroll});

  final String business_id;
  final String categoryId;
  final String categoryName;
  final int chack = 1;
  final Map<String, dynamic> element;
  final String itemId;
  final double scroll;

  @override
  State<ItemCardNoImage> createState() => _ItemCardNoImageState();
}

class _ItemCardNoImageState extends State<ItemCardNoImage> {
  late int chack;
  Map<String, dynamic> element = {};
  List<InlineSpan> propertiesWidget = [];

  @override
  void initState() {
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
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black),
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
    Map<String, dynamic>? element = await getItem(widget.element["item_id"], widget.business_id);
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
                          color: Theme.of(context).colorScheme.onSurface,
                          fontVariations: <FontVariation>[FontVariation('wght', 600)],
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
                              color: Theme.of(context).colorScheme.onSurface,
                              fontVariations: <FontVariation>[FontVariation('wght', 600)],
                              fontSize: 30 * globals.scaleParam,
                            ),
                          ),
                          element["country"] != null
                              ? WidgetSpan(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 4 * globals.scaleParam, vertical: 2 * globals.scaleParam),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      element["country"] ?? "",
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.w500,
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
                          "${globals.formatCost(element["price"].toString())} ₸ за ${element["unit"]}",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                            fontVariations: <FontVariation>[FontVariation('wght', 600)],
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
                      text: "${globals.formatCost((element['price'] * element['amount']).toString())} ₸",
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

// class ItemCardSquare extends StatefulWidget {
//   const ItemCardSquare(
//       {super.key,
//       required this.itemId,
//       required this.element,
//       required this.categoryName,
//       required this.categoryId,
//       required this.scroll,
//       required this.business,
//       required this.index,
//       this.categoryPageUpdateData,
//       required this.constraints});

//   final Function(String, int)? categoryPageUpdateData;
//   final Map<dynamic, dynamic> business;
//   final String categoryId;
//   final String categoryName;
//   final chack = 1;
//   final BoxConstraints constraints;
//   final Map<String, dynamic> element;
//   final int index;
//   final String itemId;
//   final double scroll;

//   @override
//   State<ItemCardSquare> createState() => _ItemCardSquareState();
// }

// class _ItemCardSquareState extends State<ItemCardSquare> with SingleTickerProviderStateMixin<ItemCardSquare> {
//   int amountInCart = 0;
//   bool canButtonsBeUsed = true;
//   late int chack;
//   Map<String, dynamic> element = {};
//   bool hideButtons = true;
//   int previousAmount = 0;
//   List<InlineSpan> propertiesWidget = [];

//   late AnimationController _controller;
//   Timer? _debounce;
//   Timer? _hideButtonsTimer;
//   late Animation<Offset> _offsetAnimation;

//   @override
//   void dispose() {
//     // Trigger the debounce action immediately if the timer is active
//     if (widget.categoryPageUpdateData != null) {
//       widget.categoryPageUpdateData!(amountInCart.toString(), widget.index);
//     }
//     if (_debounce?.isActive ?? false) {
//       _debounce?.cancel();
//       _updateItemCountServerCall();
//     }
//     super.dispose();
//   }

//   @override
//   void initState() {
//
//     super.initState();
//     setState(() {
//       element = widget.element;
//       amountInCart = int.parse(element["amount"] ?? "0");
//       previousAmount = amountInCart;
//     });
//     // getProperties();
//     _controller = AnimationController(
//       duration: const Duration(milliseconds: 150),
//       vsync: this,
//     );

//     _offsetAnimation = Tween<Offset>(
//       begin: Offset(0.70, 0),
//       end: Offset(-0.1, 0),
//     ).animate(
//       CurvedAnimation(
//         parent: _controller,
//         curve: Curves.easeOut,
//       ),
//     );

//     if (amountInCart > 0) {
//       _controller.forward();
//     }
//     // _offsetAnimationReverse = Tween<Offset>(
//     //   begin: Offset(0, 0),
//     //   end: Offset(1, 0),
//     // ).animate(CurvedAnimation(
//     //   parent: _controller,
//     //   curve: Curves.linear,
//     // ));
//   }

//   void updateCurrentItem(int amount, [int index = 0]) {
//     if (amountInCart == 0 && amount != 0) {
//       _controller.forward();
//     } else if (amount == 0) {
//       _controller.reverse();
//     }
//     print("AMOUNT IS $amount");
//     setState(() {
//       amountInCart = amount;
//     });
//   }

//   Future<void> refreshItemCard() async {
//     Map<String, dynamic>? element = await getItem(widget.element["item_id"], widget.business["business_id"]);
//     print(element);
//     setState(() {
//       element!["name"] = "123";
//       element = element!;
//     });
//   }

//   void getProperties() {
//     if (widget.element["properties"] != null) {
//       List<InlineSpan> propertiesT = [];
//       List<String> properties = widget.element["properties"].split(",");
//       print(properties);
//       for (var element in properties) {
//         List temp = element.split(":");
//         propertiesT.add(
//           WidgetSpan(
//             child: Row(
//               children: [
//                 Text(
//                   temp[1],
//                   style: TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.w700,
//                     color: Colors.black,
//                   ),
//                 ),
//                 Image.asset(
//                   "assets/property_icons/${temp[0]}.png",
//                   width: 14,
//                   height: 14,
//                 ),
//                 SizedBox(
//                   width: 10,
//                 )
//               ],
//             ),
//           ),
//         );
//       }
//       setState(() {
//         propertiesWidget = propertiesT;
//       });
//     }
//   }

//   // late Animation<Offset> _offsetAnimationReverse;

//   void _hideButtonsAfterTime() {
//     // Cancel the previous timer if it exists
//     if (_hideButtonsTimer?.isActive ?? false) _hideButtonsTimer!.cancel();

//     // Start a new timer
//     _hideButtonsTimer = Timer(Duration(milliseconds: 3000), () {
//       setState(() {
//         hideButtons = true;
//       });
//     });
//   }

//   void _updateItemCountServerCall() {
//     changeCartItem(element["item_id"], amountInCart, widget.business["business_id"]).then((value) {
//       if (value == null) {
//         if (0 != amountInCart) {
//           _updateItemCountServerCall();
//         } else {
//           setState(() {
//             amountInCart = 0;
//             previousAmount = amountInCart;
//           });
//         }
//       } else {
//         if (int.parse(value) != amountInCart) {
//           _updateItemCountServerCall();
//         } else {
//           setState(() {
//             amountInCart = int.parse(value);
//             previousAmount = amountInCart;
//           });
//         }
//       }
//       // if (widget.updateCategoryPageInfo != null) {
//       //   widget.updateCategoryPageInfo!(
//       //       amountInCart.toString(), widget.index);
//       // }
//       if (widget.categoryPageUpdateData != null) {
//         widget.categoryPageUpdateData!(amountInCart.toString(), widget.index);
//       }
//       print(value);
//     });
//   }

//   void _updateItemCount() {
//     // Cancel the previous timer if it exists
//     if (_debounce?.isActive ?? false) _debounce!.cancel();

//     // Start a new timer
//     _debounce = Timer(Duration(milliseconds: 750), () {
//       // Call your server update function here
//       _updateItemCountServerCall();
//     });
//   }

//   void _decrementAmountInCart() {
//     if (amountInCart > 0) {
//       setState(() {
//         amountInCart--;
//       });
//       _updateItemCount();
//     }
//   }

//   void _incrementAmountInCart() {
//     if (amountInCart + 1 <= double.parse(element["in_stock"]).truncate()) {
//       setState(() {
//         amountInCart++;
//       });
//       _updateItemCount();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     chack = widget.chack;
//     return Container(
//       // padding: EdgeInsets.all(15 * globals.scaleParam),
//       margin: EdgeInsets.all(10 * globals.scaleParam),
//       height: widget.constraints.minHeight,
//       width: widget.constraints.maxWidth,
//       clipBehavior: Clip.antiAliasWithSaveLayer,
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.all(Radius.circular(20)),
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(blurRadius: 5, offset: Offset(5, 5), color: Colors.grey.withOpacity(0.1)),
//           BoxShadow(blurRadius: 4, offset: Offset(-5, -5), color: Colors.blueGrey.withOpacity(0.1))
//         ],
//       ),
//       // Stack for the gesture detector in the end of the code
//       child: Stack(
//         children: [
//           Column(
//             children: [
//               Flexible(
//                 flex: 2,
//                 // Plus button stack
//                 child: Stack(
//                   alignment: Alignment.topRight,
//                   children: [
//                     Container(
//                       width: widget.constraints.minWidth,
//                       child: ExtendedImage.network(
//                         element["img"],
//                         height: double.infinity,
//                         clearMemoryCacheWhenDispose: true,
//                         enableMemoryCache: true,
//                         enableLoadState: false,
//                         fit: BoxFit.contain,
//                       ),
//                     ),
//                     Container(
//                       decoration: BoxDecoration(
//                         borderRadius: BorderRadius.only(
//                           bottomRight: Radius.circular(9 * globals.scaleParam),
//                           topLeft: Radius.circular(9 * globals.scaleParam),
//                           bottomLeft: Radius.elliptical(
//                             60 * globals.scaleParam,
//                             60 * globals.scaleParam,
//                           ),
//                         ),
//                         color: amountInCart > 0 ? Colors.amberAccent.shade100 : Colors.blueGrey.shade100,
//                         boxShadow: [
//                           // BoxShadow(
//                           //   color: Colors.blueGrey.shade100,
//                           //   blurRadius: 5,
//                           // )
//                         ],
//                       ),
//                       child: AnimatedCrossFade(
//                         alignment: Alignment.topRight,
//                         duration: Durations.medium1,
//                         crossFadeState: amountInCart == 0 || (amountInCart > 0 && hideButtons) ? CrossFadeState.showFirst : CrossFadeState.showSecond,
//                         firstChild: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           mainAxisAlignment: MainAxisAlignment.end,
//                           children: [
//                             int.parse(widget.element["option"]) == 1
//                                 ? Flexible(
//                                     child: SizedBox(
//                                       height: widget.constraints.maxHeight * 0.2,
//                                       child: AspectRatio(
//                                         aspectRatio: 1,
//                                         child: IconButton(
//                                           style: IconButton.styleFrom(
//                                             alignment: Alignment.center,
//                                             // padding: EdgeInsets.all(0),
//                                             // backgroundColor: amountInCart > 0
//                                             //     ? Colors.amberAccent.shade200
//                                             //     : Colors.transparent,
//                                           ),
//                                           highlightColor: canButtonsBeUsed ? Colors.transparent : Colors.transparent,
//                                           padding: EdgeInsets.all(0),
//                                           onPressed: canButtonsBeUsed
//                                               ? () {
//                                                   if (hideButtons && amountInCart > 0) {
//                                                     setState(() {
//                                                       hideButtons = false;
//                                                     });
//                                                     _hideButtonsAfterTime();
//                                                     return;
//                                                   } else if (hideButtons && amountInCart == 0) {
//                                                     setState(() {
//                                                       hideButtons = false;
//                                                     });
//                                                     _hideButtonsAfterTime();
//                                                   } else {
//                                                     _hideButtonsAfterTime();
//                                                   }
//                                                   _incrementAmountInCart();
//                                                   setState(() {
//                                                     canButtonsBeUsed = false;
//                                                   });
//                                                   _controller.forward();
//                                                   Timer(
//                                                     Duration(milliseconds: 350),
//                                                     () {
//                                                       setState(() {
//                                                         canButtonsBeUsed = true;
//                                                       });
//                                                     },
//                                                   );
//                                                 }
//                                               : null,
//                                           icon: Container(
//                                             // alignment: Alignment.center,
//                                             // padding: EdgeInsets.all(
//                                             //     5 * globals.scaleParam),
//                                             decoration: BoxDecoration(
//                                               borderRadius: BorderRadius.only(
//                                                 bottomLeft: Radius.circular(100),
//                                               ),
//                                               // color: Colors.white,
//                                             ),
//                                             child: amountInCart == 0
//                                                 ? Icon(
//                                                     Icons.add_rounded,
//                                                     color: Theme.of(context).colorScheme.onSurface,
//                                                   )
//                                                 : Text(
//                                                     amountInCart.toString(),
//                                                     style: TextStyle(
//                                                       fontWeight: FontWeight.w700,
//                                                       fontSize: 48 * globals.scaleParam,
//                                                       color: Theme.of(context).colorScheme.onSurface,
//                                                     ),
//                                                   ),
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                   )
//                                 : Container()
//                           ],
//                         ),
//                         secondChild: SizedBox(
//                           width: widget.constraints.maxWidth * 0.7,
//                           height: widget.constraints.maxHeight * 0.2,
//                           child: Row(
//                             children: [
//                               Flexible(
//                                 flex: 2,
//                                 fit: FlexFit.tight,
//                                 child: LayoutBuilder(
//                                   builder: (context, constraints) {
//                                     return SizedBox(
//                                       width: constraints.maxWidth,
//                                       height: constraints.maxHeight,
//                                       child: IconButton(
//                                         padding: EdgeInsets.all(0),
//                                         onPressed: canButtonsBeUsed
//                                             ? () {
//                                                 _hideButtonsAfterTime();
//                                                 _decrementAmountInCart();
//                                                 if (amountInCart <= 0) {
//                                                   setState(() {
//                                                     canButtonsBeUsed = false;
//                                                   });
//                                                   _controller.reverse();
//                                                   Timer(
//                                                     Duration(milliseconds: 350),
//                                                     () {
//                                                       setState(() {
//                                                         canButtonsBeUsed = true;
//                                                       });
//                                                     },
//                                                   );
//                                                 }
//                                               }
//                                             : null,
//                                         icon: Container(
//                                           child: Icon(
//                                             Icons.remove_rounded,
//                                             color:
//                                                 amountInCart > 0 ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.secondary,
//                                           ),
//                                         ),
//                                       ),
//                                     );
//                                   },
//                                 ),
//                               ),
//                               Flexible(
//                                 flex: 3,
//                                 fit: FlexFit.tight,
//                                 child: Row(
//                                   mainAxisAlignment: MainAxisAlignment.center,
//                                   children: [
//                                     Flexible(
//                                       child: Text(
//                                         "${amountInCart.toString()} шт", //"${globals.formatCost((cacheAmount * int.parse(item["price"])).toString())} ₸",
//                                         textHeightBehavior: TextHeightBehavior(
//                                           applyHeightToFirstAscent: false,
//                                         ),
//                                         textAlign: TextAlign.center,
//                                         style: TextStyle(
//                                           fontWeight: FontWeight.w700,
//                                           fontSize: 36 * globals.scaleParam,
//                                           color: amountInCart != 0 ? Theme.of(context).colorScheme.onSurface : Colors.grey.shade600,
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                               Flexible(
//                                 flex: 2,
//                                 fit: FlexFit.tight,
//                                 child: LayoutBuilder(
//                                   builder: (context, constraints) {
//                                     return SizedBox(
//                                       width: constraints.maxWidth,
//                                       height: constraints.maxHeight,
//                                       child: IconButton(
//                                         padding: EdgeInsets.all(0),
//                                         onPressed: canButtonsBeUsed
//                                             ? () {
//                                                 _incrementAmountInCart();
//                                                 _hideButtonsAfterTime();
//                                               }
//                                             : null,
//                                         icon: Container(
//                                           child: Icon(
//                                             Icons.add_rounded,
//                                             color: amountInCart < double.parse(element["in_stock"]).truncate()
//                                                 ? Theme.of(context).colorScheme.onSurface
//                                                 : Theme.of(context).colorScheme.secondary,
//                                           ),
//                                         ),
//                                       ),
//                                     );
//                                   },
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     )
//                   ],
//                 ),
//               ),
//               Flexible(
//                 flex: 2,
//                 fit: FlexFit.tight,
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   mainAxisSize: MainAxisSize.max,
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Flexible(
//                       flex: 2,
//                       fit: FlexFit.tight,
//                       child: Padding(
//                         padding: EdgeInsets.symmetric(
//                           horizontal: 15 * globals.scaleParam,
//                           vertical: 5 * globals.scaleParam,
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Flexible(
//                               flex: 2,
//                               fit: FlexFit.tight,
//                               child: Row(
//                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                 children: [
//                                   Flexible(
//                                     flex: 5,
//                                     fit: FlexFit.tight,
//                                     child: Container(
//                                       alignment: Alignment.topLeft,
//                                       color: Theme.of(context)
//                                           .colorScheme
//                                           .surface, // Чтобы текст не обрезало сверху, потому что без цвета, он сжимается до краёв текста
//                                       child: RichText(
//                                         maxLines: 2,
//                                         overflow: TextOverflow.ellipsis,
//                                         text: TextSpan(
//                                           style: TextStyle(
//                                             textBaseline: TextBaseline.alphabetic,
//                                             color: Colors.black,
//                                             fontWeight: FontWeight.w500,
//                                             fontSize: 32 * globals.scaleParam,
//                                             height: 3 * globals.scaleParam,
//                                           ),
//                                           children: [
//                                             TextSpan(
//                                               text: element["name"],
//                                             ),
//                                             element["country"] != null
//                                                 ? WidgetSpan(
//                                                     child: Container(
//                                                       padding: EdgeInsets.symmetric(
//                                                         horizontal: 4 * globals.scaleParam,
//                                                         // vertical: 2 *
//                                                         // globals.scaleParam,
//                                                       ),
//                                                       decoration: BoxDecoration(
//                                                         color: Colors.grey.shade200,
//                                                         borderRadius: BorderRadius.all(
//                                                           Radius.circular(10),
//                                                         ),
//                                                       ),
//                                                       child: Text(
//                                                         element["country"] ?? "",
//                                                         style: TextStyle(
//                                                           color: Colors.black,
//                                                           fontWeight: FontWeight.w600,
//                                                           fontSize: 26 * globals.scaleParam,
//                                                         ),
//                                                       ),
//                                                     ),
//                                                   )
//                                                 : TextSpan()
//                                           ],
//                                         ),
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             Flexible(
//                               fit: FlexFit.tight,
//                               child: Padding(
//                                 padding: EdgeInsets.only(
//                                   left: 10 * globals.scaleParam,
//                                   bottom: 10 * globals.scaleParam,
//                                 ),
//                                 child: Text(
//                                   "В наличии ${double.parse(element["in_stock"] ?? "0").truncate().toString()} шт",
//                                   style: TextStyle(
//                                     color: Theme.of(context).colorScheme.secondary,
//                                     fontSize: 30 * globals.scaleParam,
//                                     fontWeight: FontWeight.w500,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                     Flexible(
//                         child: Padding(
//                       padding: EdgeInsets.only(
//                         left: 25 * globals.scaleParam,
//                         bottom: 15 * globals.scaleParam,
//                       ),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.start,
//                         crossAxisAlignment: CrossAxisAlignment.end,
//                         children: [
//                           Text(
//                             globals.formatCost(element['price'] ?? ""),
//                             style: TextStyle(
//                               color: Colors.black,
//                               fontWeight: FontWeight.w900,
//                               fontSize: 38 * globals.scaleParam,
//                             ),
//                           ),
//                           Text(
//                             "₸",
//                             textAlign: TextAlign.start,
//                             style: TextStyle(
//                               color: Colors.grey.shade600,
//                               fontWeight: FontWeight.w700,
//                               fontSize: 38 * globals.scaleParam,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ))
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           // THIS IS WHERE ACTUAL GESTURE DETECTOR IS
//           // It has height that will not contact with plus button in the ItemCard, so user will never open ProductPage when he adds item in cart
//           Container(
//             width: widget.constraints.maxWidth,
//             height: widget.constraints.maxHeight,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Flexible(
//                   child: GestureDetector(
//                     behavior: HitTestBehavior.opaque,
//                     onTap: () {
//                       showModalBottomSheet(
//                         context: context,
//                         clipBehavior: Clip.antiAlias,
//                         useSafeArea: true,
//                         isScrollControlled: true,
//                         showDragHandle: false,
//                         builder: (context) {
//                           widget.element["amount"] = amountInCart.toString();
//                           return ProductPage(
//                             item: widget.element,
//                             index: widget.index,
//                             returnDataAmount: updateCurrentItem,
//                             business: widget.business,
//                           );
//                         },
//                       );
//                     },
//                     child: Container(
//                       width: amountInCart == 0 && canButtonsBeUsed ? widget.constraints.maxWidth * 0.63 : widget.constraints.maxWidth * 0.05,
//                       height: widget.constraints.maxHeight * 0.23,
//                       // color: Colors.red.withOpacity(0.5),
//                     ),
//                   ),
//                 ),
//                 Expanded(
//                   flex: 3,
//                   child: GestureDetector(
//                     behavior: HitTestBehavior.opaque,
//                     onTap: () {
//                       showModalBottomSheet(
//                         context: context,
//                         clipBehavior: Clip.antiAlias,
//                         useSafeArea: true,
//                         isScrollControlled: true,
//                         showDragHandle: false,
//                         builder: (context) {
//                           widget.element["amount"] = amountInCart.toString();
//                           return ProductPage(
//                             item: widget.element,
//                             index: widget.index,
//                             returnDataAmount: updateCurrentItem,
//                             business: widget.business,
//                           );
//                         },
//                       );
//                     },
//                     child: Container(
//                         // color: Colors.amber.withOpacity(0.5),
//                         ),
//                   ),
//                 ),
//               ],
//             ),
//           )
//         ],
//       ),
//     );
//   }
// }

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

  final Function(List, int)? categoryPageUpdateData;
  final Map<dynamic, dynamic> business;
  final String categoryId;
  final String categoryName;
  final chack = 1;
  final Map<String, dynamic> element;
  final int index;
  final int itemId;
  final double scroll;

  @override
  State<ItemCardListTile> createState() => _ItemCardListTileState();
}

class _ItemCardListTileState extends State<ItemCardListTile> with SingleTickerProviderStateMixin<ItemCardListTile> {
  double amountInCart = 0;
  bool canButtonsBeUsed = true;
  List cart = [];
  late int chack;
  Map<String, dynamic> element = {};
  bool hideButtons = true;
  List options = [];
  double previousAmount = 0;
  List<InlineSpan> propertiesWidget = [];

  Timer? _debounce;
  Timer? _hideButtonsTimer;
  late Animation<Offset> _offsetAnimation;

  List promotions = [];

  void updateCurrentItem(List cartNewItem) {
    if (options.isEmpty) {
      if (cartNewItem[0].isEmpty) {
        cart = [];
        amountInCart = 0;
      } else {
        cart = cartNewItem;
        cart[0]["name"] = element["name"];
        amountInCart = double.parse(cart[0]["amount"].toString()).roundToDouble();
      }
      setState(() {
        cart;
        element["cart"] = cart;
      });
    } else {
      setState(() {
        cart = cartNewItem;
        element["cart"] = cart;
      });
    }
    // print("UPDATING CART IN ItemCardListTile (TWSP)");

    // if ((cart.isEmpty && cartNewItem.isEmpty) || (cart.isNotEmpty && cartNewItem.isEmpty)) {
    //   print("Something gone wrong with update of ItemCardListView cart (TWSP)");
    //   return;
    // }

    // int indexLocalCart = cart.indexWhere((element) => element["relation_id"] == cartNewItem["relation_id"]);

    // // Negative 1 only if no such item in cart found
    // if (indexLocalCart == -1) {
    //   if (cartNewItem["amount"] != 0) {
    //     setState(() {
    //       cart.add(cartNewItem);
    //     });
    //   }
    // } else {
    //   if (cartNewItem["amount"] == 0) {
    //     setState(() {
    //       cart.removeAt(indexLocalCart);
    //     });
    //   } else {
    //     setState(() {
    //       cart[indexLocalCart]["amount"] = cartNewItem["amount"];
    //     });
    //   }
    // }
    // ! INSTEAD OF CALLING TO THE BACKEND WE WILL SIMPLY ADD NEW ITEM TO CART
    // ! THIS IS BECAUSE getItem DOESN'T RETURN CART!!!!!!!!!
    // await getItem(widget.element["item_id"], widget.business["business_id"])
    //     .then((value) {
    //   print(value);
    //   if (value.isNotEmpty) {
    //     setState(() {
    //       // options = value["item_options"] ?? [];
    //       // cart = value["cart"] ?? [];
    //     });
    //   }
    // });
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

  void _updateItemAmountServerCall() {
    changeCartItem(element["item_id"], amountInCart, widget.business["business_id"]).then((value) {
      if (value == null) {
        // changeCartItem should only return null when facing token error or network error, otherwise it will be List
        print("IT'S SEEMS THERE IS AN ERROR WHILE GETTING CART IN itemCardListTile _updateItemAmountServerCall()! (TWSP)");
        return;
      }
      if (options.isEmpty) {
        print("SET AMOUNT IN ITEM CARD (TWSP)");
        if (value.isEmpty) {
          setState(() {
            cart = [];
          });
        }
        if (value.firstWhere(
              (el) => el["item_id"] == element["item_id"],
              orElse: () => null,
            ) ==
            null) {
          setState(() {
            cart = [];
          });
        }
        // If there is no cart list in element, create one and add new item (value)
        else if (value.isNotEmpty && cart.isEmpty) {
          cart = [value.firstWhere((el) => el["item_id"] == element["item_id"])];
          cart[0]["name"] = element["name"];
          setState(() {
            cart;
          });
        } else {
          cart[0]["amount"] = value.firstWhere((el) => el["item_id"] == element["item_id"])["amount"];
          cart[0]["name"] = element["name"];
          setState(() {
            cart;
          });
        }
        widget.categoryPageUpdateData!(cart, widget.index);
      }
      print(value);
      print(cart);
    });
  }

  void _updateItemAmount() {
    // Cancel the previous timer if it exists
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Start a new timer
    _debounce = Timer(Duration(milliseconds: 750), () {
      // Call your server update function here
      _updateItemAmountServerCall();
    });
  }

  void _decrementAmountInCart() {
    if (amountInCart > 0) {
      setState(() {
        amountInCart--;
      });
      _updateItemAmount();
    }
  }

  void _incrementAmountInCart() {
    if (amountInCart + 1 <= element["in_stock"].truncate()) {
      setState(() {
        amountInCart++;
      });
      _updateItemAmount();
    }
  }

  List<Widget> _getCartOptions(List itemOptions) {
    List<Widget> selectedOptions = [];
    if (itemOptions.isNotEmpty) {
      print("OPTIONS TEST");
    }
    for (Map itemOption in itemOptions) {
      if (itemOption["name"] != null) {
        selectedOptions.add(Text(
          itemOption["name"],
          style: TextStyle(
            fontFamily: "Raleway",
            color: Theme.of(context).colorScheme.onSurface,
            fontVariations: <FontVariation>[FontVariation('wght', 600)],
            fontSize: 28 * globals.scaleParam,
          ),
        ));
      }
    }
    return selectedOptions;
  }

  Map<String, dynamic> _getElementWithSelectedItemsByIndex(int index) {
    Map<String, dynamic> cartItemElement = Map<String, dynamic>.from(element);

    void resetSelectedOptions(Map<dynamic, dynamic> option) {
      if (option["selection"] == "SINGLE") {
        option["selected_relation_id"] = null;
      } else {
        option["selected_relation_id"] = [];
      }
    }

    void updateSelectedOptions(Map<dynamic, dynamic> cartOption, Map<dynamic, dynamic> option) {
      for (Map optionData in option["options"]) {
        if (optionData["relation_id"] == cartOption["relation_id"]) {
          if (option["selection"] == "SINGLE") {
            option["selected_relation_id"] = optionData["relation_id"];
          } else {
            option["selected_relation_id"]?.add(optionData["relation_id"]);
          }
        }
      }
    }

    void processOptions() {
      if (cartItemElement["options"] != null) {
        for (Map option in cartItemElement["options"]) {
          resetSelectedOptions(option);
        }

        for (Map cartOption in cartItemElement["cart"][index]["selected_options"]) {
          for (Map option in cartItemElement["options"]) {
            updateSelectedOptions(cartOption, option);
          }
        }
      }
    }

    void processCart() {
      if (cartItemElement["cart"] != null && cartItemElement["cart"].isNotEmpty) {
        cartItemElement["amount"] = cartItemElement["cart"][index]["amount"];
      } else {
        cartItemElement["cart"] = [
          {"amount": amountInCart, "name": cartItemElement["name"]}
        ];
        cartItemElement["amount"] = amountInCart;
      }
    }

    processOptions();
    processCart();

    return cartItemElement;
  }

  void showModalProductPageWithClearedState() {
    // Map<String, dynamic> newElement = Map<String, dynamic>.from(element);
    // newElement["amount"] = 0;
    // newElement["cart"] = [];
    showModalBottomSheet(
      context: context,
      clipBehavior: Clip.antiAlias,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (context) {
        // widget.element["amount"] = amountInCart.toString();
        return ProductPage(
            item: element, index: widget.index, returnDataAmount: updateCurrentItem, business: widget.business, promotions: promotions);
      },
    );
  }

  @override
  void initState() {
    print(widget.element["cart"]);

    super.initState();
    if (widget.element["cart"] != null) {
      print("CART FROM ITEM ${widget.element["cart"]}");
    }
    if (widget.element["options"] != null) {
      print("OPTIONS FROM ITEM ${widget.element["options"]}");
    }
    setState(() {
      element = widget.element;
      promotions = widget.element["promotions"] ?? [];
      // amountInCart = int.parse(element["amount"] ?? "0");
      options = widget.element["options"] ?? [];
      if (widget.element["cart"] != null) {
        if (widget.element["cart"].isNotEmpty) {
          cart = widget.element["cart"];
          amountInCart = element["cart"][0]["amount"] ?? 0;
          if (options.isEmpty) {
            element["cart"][0]["name"] = element["name"];
          }
          previousAmount = amountInCart;
        }
      } else {
        cart = [];
        amountInCart = 0;
        previousAmount = amountInCart;
      }
    });
  }

  @override
  void dispose() {
    // if (widget.categoryPageUpdateData != null) {
    //   widget.categoryPageUpdateData!(amountInCart.toString(), widget.index);
    // }
    // Triggers the debounce action immediately if the timer is active
    if (_debounce?.isActive ?? false) {
      _debounce?.cancel();
      _updateItemAmountServerCall();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAliasWithSaveLayer,
      margin: EdgeInsets.symmetric(
        vertical: 10 * globals.scaleParam,
        horizontal: 15 * globals.scaleParam,
      ),
      // padding: EdgeInsets.only(bottom: 10 * globals.scaleParam),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(
          Radius.circular(30 * globals.scaleParam),
        ),
        color: Colors.white,
      ),
      child: Stack(
        children: [
          Column(
            children: [
              SizedBox(
                height: 350 * globals.scaleParam,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Padding(
                      padding: EdgeInsets.all(5 * globals.scaleParam),
                      child: Row(
                        children: [
                          Flexible(
                              flex: 6,
                              fit: FlexFit.tight,
                              child: Stack(
                                children: [
                                  SizedBox(
                                    height: constraints.maxHeight,
                                    child: Container(
                                      alignment: Alignment.center,
                                      clipBehavior: Clip.antiAlias,
                                      decoration: BoxDecoration(
                                        // color: Colors.red,
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(30 * globals.scaleParam),
                                        ),
                                      ),
                                      child: element["img"] != null
                                          ? ExtendedImage.network(
                                              element["img"],
                                              height: constraints.maxHeight,
                                              width: double.infinity,
                                              // height: double.infinity,

                                              clearMemoryCacheWhenDispose: true,
                                              enableMemoryCache: true,
                                              enableLoadState: false,
                                              fit: BoxFit.contain,
                                            )
                                          : ExtendedImage.asset(
                                              "assets/category_items/no_image_ico.png",
                                              // height: double.infinity,

                                              clearMemoryCacheWhenDispose: true,
                                              enableMemoryCache: true,
                                              enableLoadState: false,
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                  ),
                                ],
                              )),
                          Expanded(
                            flex: 15,
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: 20 * globals.scaleParam,
                                right: 10 * globals.scaleParam,
                                top: 12 * globals.scaleParam,
                                // bottom: 10 * globals.scaleParam,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Flexible(
                                    flex: 6,
                                    fit: FlexFit.tight,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Flexible(
                                          fit: FlexFit.tight,
                                          child: Container(
                                            alignment: Alignment.topLeft,
                                            child: Row(
                                              children: [
                                                Flexible(
                                                  fit: FlexFit.tight,
                                                  child: Text(
                                                    element["name"],
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 2,
                                                    style: TextStyle(
                                                        fontFamily: "Raleway",
                                                        fontVariations: <FontVariation>[FontVariation('wght', 600)],
                                                        fontSize: 38 * globals.scaleParam,
                                                        fontWeight: FontWeight.w500,
                                                        height: 1,
                                                        letterSpacing: 0),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Spacer(),

                                  // Flexible(
                                  //   flex: 3,
                                  //   fit: FlexFit.tight,
                                  //   child: Text(
                                  //     element["description"],
                                  //     maxLines: 2,
                                  //     overflow: TextOverflow.ellipsis,
                                  //     style: TextStyle(
                                  //       color: Colors.grey,
                                  //       fontWeight: FontWeight.w500,
                                  //       fontSize: 21 * globals.scaleParam,
                                  //       height: 1,
                                  //     ),
                                  //   ),
                                  // ),

                                  // Flexible(
                                  //   flex: 4,
                                  //   fit: FlexFit.tight,
                                  //   child: Text(
                                  //     element["code"],
                                  //     maxLines: 1,
                                  //     overflow: TextOverflow.ellipsis,
                                  //     style: TextStyle(
                                  //       color: Colors.amber.shade800,
                                  //       fontWeight: FontWeight.w600,
                                  //       fontSize: 32 * globals.scaleParam,
                                  //       height: 1,
                                  //     ),
                                  //   ),
                                  // ),
                                  // Flexible(
                                  //   flex: 4,
                                  //   fit: FlexFit.tight,
                                  //   child: Row(
                                  //     mainAxisAlignment: MainAxisAlignment.end,
                                  //     mainAxisSize: MainAxisSize.min,
                                  //     children: [
                                  //       Flexible(
                                  //         child: Text(
                                  //           // Automatically sets units of choice
                                  //           widget.element["unit"] != "шт"
                                  //               ? "В наличии: ${(element['in_stock'] ?? "")} ${widget.element["unit"]}"
                                  //               : element["quantity"] != 1
                                  //                   ? "В наличии: ${element["in_stock"]} кг"
                                  //                   : "В наличии: ${(element["in_stock"]).round()} ${widget.element["unit"]}",
                                  //           style: TextStyle(
                                  //             color: Colors.grey,
                                  //             fontWeight: FontWeight.w500,
                                  //             fontSize: 28 * globals.scaleParam,
                                  //           ),
                                  //         ),
                                  //       ),
                                  //     ],
                                  //   ),
                                  // ),
                                  Flexible(
                                    flex: 5,
                                    fit: FlexFit.tight,
                                    child: promotions.isEmpty
                                        ? Container()
                                        : ListView.builder(
                                            primary: false,
                                            shrinkWrap: true,
                                            itemCount: promotions.length,
                                            itemBuilder: (context, index) {
                                              return Row(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  Container(
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                        borderRadius: BorderRadius.all(Radius.circular(10 * globals.scaleParam)),
                                                        gradient: LinearGradient(
                                                          begin: Alignment.topRight,
                                                          end: Alignment.bottomLeft,
                                                          colors: [
                                                            Colors.purpleAccent,
                                                            Color(0xFFFFC837),
                                                          ],
                                                        )),
                                                    padding: EdgeInsets.all(10 * globals.scaleParam),
                                                    margin: EdgeInsets.all(3 * globals.scaleParam),
                                                    child: Text(promotions[index]["name"],
                                                        style: TextStyle(
                                                            fontWeight: FontWeight.w700, color: Colors.white, fontSize: 24 * globals.scaleParam)),
                                                  )
                                                ],
                                              );
                                            },
                                          ),
                                  ),
                                  Flexible(
                                    flex: 5,
                                    fit: FlexFit.tight,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            globals.formatCost((element['price'] ?? "").toString()),
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 40 * globals.scaleParam,
                                              fontVariations: <FontVariation>[FontVariation('wght', 600)],
                                            ),
                                          ),
                                        ),
                                        Flexible(
                                          child: Text(
                                            "₸",
                                            textAlign: TextAlign.start,
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 40 * globals.scaleParam,
                                              fontVariations: <FontVariation>[FontVariation('wght', 600)],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Flexible(
                                    flex: 9,
                                    fit: FlexFit.tight,
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        right: 30 * globals.scaleParam,
                                        bottom: 10 * globals.scaleParam,
                                      ),
                                      child: AnimatedCrossFade(
                                        alignment: Alignment.topRight,
                                        duration: Durations.medium1,
                                        crossFadeState: amountInCart == 0 || (amountInCart > 0 && hideButtons) || options.isNotEmpty
                                            ? CrossFadeState.showFirst
                                            : CrossFadeState.showSecond,
                                        firstChild: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Flexible(
                                              flex: 2,
                                              fit: FlexFit.tight,
                                              child: SizedBox(),
                                            ),
                                            options.isEmpty && element["quantity"] == 1
                                                ? Flexible(
                                                    fit: FlexFit.tight,
                                                    child: IconButton(
                                                        style: IconButton.styleFrom(
                                                          alignment: Alignment.center,
                                                          // padding: EdgeInsets.all(0),
                                                          // backgroundColor: amountInCart > 0
                                                          // ? Colors.amberAccent.shade200
                                                          //     : Colors.transparent,
                                                          // backgroundColor: Colors.amber,
                                                        ),
                                                        highlightColor: canButtonsBeUsed ? Colors.transparent : Colors.transparent,
                                                        padding: EdgeInsets.zero,
                                                        onPressed: canButtonsBeUsed
                                                            ? () {
                                                                if (hideButtons && amountInCart > 0) {
                                                                  setState(() {
                                                                    hideButtons = false;
                                                                  });
                                                                  _hideButtonsAfterTime();
                                                                  return;
                                                                } else if (hideButtons && amountInCart == 0) {
                                                                  setState(() {
                                                                    hideButtons = false;
                                                                  });
                                                                  _hideButtonsAfterTime();
                                                                } else {
                                                                  _hideButtonsAfterTime();
                                                                }
                                                                _incrementAmountInCart();
                                                                setState(
                                                                  () {
                                                                    canButtonsBeUsed = false;
                                                                  },
                                                                );
                                                                Timer(
                                                                  Duration(milliseconds: 250),
                                                                  () {
                                                                    setState(() {
                                                                      canButtonsBeUsed = true;
                                                                    });
                                                                  },
                                                                );
                                                              }
                                                            : () {},
                                                        icon: Icon(
                                                          cart.isEmpty ? Icons.add_rounded : Icons.edit,
                                                          color: Theme.of(context).colorScheme.onSurface,
                                                          size: cart.isEmpty ? 70 * globals.scaleParam : 60 * globals.scaleParam,
                                                        )),
                                                  )
                                                : Flexible(
                                                    fit: FlexFit.tight,
                                                    child: IconButton(
                                                      padding: EdgeInsets.zero,
                                                      style: IconButton.styleFrom(
                                                          // backgroundColor: Colors.red,
                                                          ),
                                                      onPressed: () {
                                                        showModalProductPageWithClearedState();
                                                        // showModalBottomSheet(
                                                        //   context: context,
                                                        //   clipBehavior: Clip.antiAlias,
                                                        //   useSafeArea: true,
                                                        //   isScrollControlled: true,
                                                        //   showDragHandle: false,
                                                        //   builder: (context) {
                                                        //     // widget.element["amount"] = amountInCart.toString();
                                                        //     return ProductPage(
                                                        //       item: element,
                                                        //       index: widget.index,
                                                        //       returnDataAmount: updateCurrentItem,
                                                        //       business: widget.business,
                                                        //     );
                                                        //   },
                                                        // );
                                                      },
                                                      icon: Icon(
                                                        Icons.edit_note_rounded,
                                                        color: Theme.of(context).colorScheme.onSurface,
                                                        size: 80 * globals.scaleParam,
                                                      ),
                                                    ),
                                                  ),
                                          ],
                                        ),
                                        secondChild: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Flexible(
                                              fit: FlexFit.tight,
                                              child: IconButton(
                                                padding: EdgeInsets.zero,
                                                onPressed: canButtonsBeUsed
                                                    ? () {
                                                        _hideButtonsAfterTime();
                                                        _decrementAmountInCart();
                                                        if (amountInCart <= 0) {
                                                          setState(() {
                                                            canButtonsBeUsed = false;
                                                          });
                                                          Timer(
                                                            Duration(milliseconds: 250),
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
                                                        ? Theme.of(context).colorScheme.onSurface
                                                        : Theme.of(context).colorScheme.secondary,
                                                    size: 70 * globals.scaleParam,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Flexible(
                                              fit: FlexFit.tight,
                                              child: Text(
                                                "${amountInCart.ceil() > amountInCart ? amountInCart.toString() : amountInCart.round()} ${widget.element["unit"]}", //"${globals.formatCost((cacheAmount * int.parse(item["price"])).toString())} ₸",
                                                textHeightBehavior: TextHeightBehavior(
                                                  applyHeightToFirstAscent: false,
                                                ),
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontVariations: <FontVariation>[FontVariation('wght', 600)],
                                                  fontSize: 36 * globals.scaleParam,
                                                  color: amountInCart != 0 ? Theme.of(context).colorScheme.onSurface : Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                            Flexible(
                                              fit: FlexFit.tight,
                                              child: IconButton(
                                                padding: EdgeInsets.zero,
                                                onPressed: canButtonsBeUsed
                                                    ? () {
                                                        _incrementAmountInCart();
                                                        _hideButtonsAfterTime();
                                                      }
                                                    : null,
                                                icon: Container(
                                                  child: Icon(
                                                    Icons.add_rounded,
                                                    color: amountInCart < element["in_stock"].truncate()
                                                        ? Theme.of(context).colorScheme.onSurface
                                                        : Theme.of(context).colorScheme.secondary,
                                                    size: 70 * globals.scaleParam,
                                                  ),
                                                ),
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
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  showModalProductPageWithClearedState();
                },
                child: Container(
                  // color: Colors.amber,
                  height: 210 * globals.scaleParam,
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  showModalProductPageWithClearedState();
                },
                child: Container(
                  // color: Colors.red,
                  width: hideButtons == true ? MediaQuery.sizeOf(context).width * 0.75 : MediaQuery.sizeOf(context).width * 0.35,
                  height: 135 * globals.scaleParam,
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: Duration(milliseconds: 350),
            curve: Curves.easeOut,
            child: cart.isNotEmpty
                ? Column(
                    children: [
                      SizedBox(
                        height: 350 * globals.scaleParam,
                      ),
                      ListView.builder(
                        primary: false,
                        physics: NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: cart.length,
                        itemBuilder: (context, index) {
                          List selected_options = [];
                          if (cart[index]["selected_options"] != null) {
                            selected_options = cart[index]["selected_options"];
                            // return SizedBox();
                          } else if (options.isEmpty) {
                            selected_options = [
                              {"name": cart[index]["name"]}
                            ];
                          }

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                clipBehavior: Clip.antiAlias,
                                useSafeArea: true,
                                isScrollControlled: true,
                                showDragHandle: false,
                                builder: (context) {
                                  // widget.element["amount"] = amountInCart.toString();

                                  // cartItemElement["options"] = element["cart"]["index"]
                                  return ProductPage(
                                    item: _getElementWithSelectedItemsByIndex(index),
                                    index: widget.index,
                                    returnDataAmount: updateCurrentItem,
                                    business: widget.business,
                                    dontClearOptions: true,
                                    cartItemId: index,
                                    promotions: promotions,
                                  );
                                },
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 20 * globals.scaleParam),
                              decoration: BoxDecoration(
                                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(2, 2))],
                                  color: Colors.white,
                                  borderRadius: BorderRadius.all(Radius.circular(20 * globals.scaleParam))
                                  // border: Border(
                                  //     top: BorderSide(color: Colors.black12))
                                  ),
                              margin: EdgeInsets.symmetric(vertical: 5, horizontal: 20 * globals.scaleParam),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Flexible(
                                    flex: 2,
                                    fit: FlexFit.tight,
                                    child: Text(
                                      "${cart[index]["amount"].ceil() > cart[index]["amount"] ? cart[index]["amount"] : cart[index]["amount"].round()} x",
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontVariations: <FontVariation>[FontVariation('wght', 600)],
                                        fontSize: 42 * globals.scaleParam,
                                      ),
                                    ),
                                  ),
                                  Spacer(),
                                  Expanded(
                                    flex: 10,
                                    child: Wrap(
                                      spacing: 10,
                                      children: _getCartOptions(selected_options),
                                    ),
                                  ),
                                  Flexible(
                                    flex: 2,
                                    fit: FlexFit.tight,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: Icon(Icons.delete_forever_rounded),
                                      onPressed: () {
                                        showModalBottomSheet(
                                          backgroundColor: Theme.of(context).colorScheme.surface,
                                          context: context,
                                          builder: (context) {
                                            return SizedBox(
                                              // decoration: BoxDecoration(
                                              //   color: Theme.of(context).colorScheme.surface,
                                              //   borderRadius: BorderRadius.all(Radius.circular(20)),
                                              // ),
                                              width: MediaQuery.sizeOf(context).width,
                                              height: MediaQuery.sizeOf(context).height * 0.35,
                                              child: Padding(
                                                padding: EdgeInsets.symmetric(vertical: 35 * globals.scaleParam),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Flexible(
                                                      fit: FlexFit.tight,
                                                      child: LayoutBuilder(builder: (context, constraints) {
                                                        return SizedBox(
                                                          width: constraints.maxWidth * 0.85,
                                                          child: Center(
                                                            child: Text(
                                                              "Убрать товар из корзины?",
                                                              textAlign: TextAlign.center,
                                                              style: TextStyle(
                                                                color: Theme.of(context).colorScheme.onSurface,
                                                                fontVariations: <FontVariation>[FontVariation('wght', 600)],
                                                                fontSize: 52 * globals.scaleParam,
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      }),
                                                    ),
                                                    Flexible(
                                                      flex: 2,
                                                      fit: FlexFit.tight,
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                        children: [
                                                          Flexible(
                                                            fit: FlexFit.tight,
                                                            child: Padding(
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
                                                                      onPressed: () async {
                                                                        await changeCartItem(element["item_id"], 0, widget.business["business_id"],
                                                                                options: _getElementWithSelectedItemsByIndex(index)["options"] ?? [])
                                                                            .then(
                                                                          (value) {
                                                                            List newCart = [];
                                                                            if (value != null) {
                                                                              if (options.isEmpty) {
                                                                                setState(() {
                                                                                  newCart = [
                                                                                    value.firstWhere(
                                                                                      (el) => el["item_id"] == element["item_id"],
                                                                                      orElse: () => [],
                                                                                    )
                                                                                  ];
                                                                                });
                                                                              } else {
                                                                                setState(() {
                                                                                  newCart = value
                                                                                      .where((el) => el["item_id"] == element["item_id"])
                                                                                      .toList();
                                                                                });
                                                                                print("asdasd");
                                                                              }
                                                                              updateCurrentItem(newCart);
                                                                            }
                                                                            Navigator.pop(context);
                                                                          },
                                                                        );
                                                                      },
                                                                      child: Text(
                                                                        "Подтвердить",
                                                                        style: TextStyle(
                                                                          color: Theme.of(context).colorScheme.onPrimary,
                                                                          fontVariations: <FontVariation>[FontVariation('wght', 600)],
                                                                          fontSize: 42 * globals.scaleParam,
                                                                        ),
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
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  )
                : Column(
                    children: [
                      SizedBox(
                        height: 350 * globals.scaleParam,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
