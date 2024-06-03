import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/cartPage.dart';
import 'package:naliv_delivery/shared/likeButton.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

class ProductPage extends StatefulWidget {
  const ProductPage(
      {super.key,
      required this.item,
      required this.index,
      required this.returnDataAmount,
      this.openedFromCart = false});
  final Map<String, dynamic> item;
  final int index;
  final Function(String, int) returnDataAmount;
  final bool openedFromCart;
  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  Widget _image = Container();
  late Map<String, dynamic> item = widget.item;
  List<Widget> groupItems = [];
  List<TableRow> properties = [];

  List<Widget> propertiesWidget = [];

  int currentTab = 0;
  String? amount;
  List<String> TabText = ["", "", ""];
  bool isDescriptionLoaded = false;

  Future<void> _getItem() async {
    await getItem(widget.item["item_id"]).then((value) {
      print(value);
      if (value.isNotEmpty) {
        if (value["description"] != null) {
          setState(() {
            TabText[0] = value["description"];

            isDescriptionLoaded = true;
          });
        }
      }
    });

    // List<Widget> groupItems = [];
    // List<TableRow> properties = [];
    // List<Widget> propertiesT = [];

    // if (item["group"] != null) {
    //   List temp = item["group"];
    //   for (var element in temp) {
    //     print(element);
    //     groupItems.add(
    //       GestureDetector(
    //         onTap: () {
    //           Navigator.pushReplacement(
    //             context,
    //             MaterialPageRoute(
    //               builder: (context) {
    //                 return ProductPage(item: element,);
    //               },
    //             ),
    //           );
    //         },
    //         child: Container(
    //           alignment: Alignment.center,
    //           padding:
    //               const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
    //           margin: const EdgeInsets.all(5),
    //           decoration: BoxDecoration(
    //               color: Colors.grey.shade400,
    //               borderRadius: const BorderRadius.all(Radius.circular(5))),
    //           child: Text(
    //             element["amount"],
    //             style: const TextStyle(
    //                 color: Colors.white, fontWeight: FontWeight.w700),
    //           ),
    //         ),
    //       ),
    //     );
    //   }
    // }

    //   if (item["properties"] != null) {
    //     List temp = item["properties"];

    //     for (var element in temp) {
    //       propertiesT.add(
    //         Container(
    //           padding: const EdgeInsets.all(5),
    //           child: Row(
    //             mainAxisSize: MainAxisSize.min,
    //             children: [
    //               Text(
    //                 element["amount"],
    //                 style: const TextStyle(
    //                     fontSize: 14,
    //                     fontWeight: FontWeight.w700,
    //                     color: Colors.black),
    //               ),
    //               Image.asset(
    //                 "assets/property_icons/${element["icon"]}.png",
    //                 width: 14,
    //                 height: 14,
    //               ),
    //               const SizedBox(
    //                 width: 10,
    //               )
    //             ],
    //           ),
    //         ),
    //       );
    //     }

    //     if (item["country"] != null) {
    //       propertiesT.add(
    //         Container(
    //           padding: const EdgeInsets.all(5),
    //           child: Row(
    //             mainAxisSize: MainAxisSize.min,
    //             children: [
    //               Text(
    //                 item["country"],
    //                 style: const TextStyle(
    //                     fontSize: 14,
    //                     fontWeight: FontWeight.w700,
    //                     color: Colors.black),
    //               ),
    //               Image.asset(
    //                 "assets/property_icons/litr.png",
    //                 width: 14,
    //                 height: 14,
    //               ),
    //               const SizedBox(
    //                 width: 10,
    //               )
    //             ],
    //           ),
    //         ),
    //       );
    //     }

    //     for (var element in temp) {
    //       properties.add(
    //         TableRow(
    //           children: [
    //             TableCell(
    //               child: Container(
    //                 padding: const EdgeInsets.all(5),
    //                 child: Text(
    //                   element["name"],
    //                   style: const TextStyle(color: Colors.black, fontSize: 14),
    //                 ),
    //               ),
    //             ),
    //             TableCell(
    //               child: Container(
    //                 padding: const EdgeInsets.all(5),
    //                 child: Text(
    //                   element["amount"] + element["unit"],
    //                   style: const TextStyle(color: Colors.black, fontSize: 14),
    //                 ),
    //               ),
    //             )
    //           ],
    //         ),
    //       );
    //     }
    //   }
    //   properties.addAll(
    //     [
    //       TableRow(
    //         children: [
    //           TableCell(
    //             child: Container(
    //               padding: const EdgeInsets.all(5),
    //               child: const Text(
    //                 "Страна",
    //                 style: TextStyle(color: Colors.black, fontSize: 14),
    //               ),
    //             ),
    //           ),
    //           TableCell(
    //             child: Container(
    //               padding: const EdgeInsets.all(5),
    //               child: Text(
    //                 item["country"] ?? "",
    //                 style: const TextStyle(color: Colors.black, fontSize: 14),
    //               ),
    //             ),
    //           )
    //         ],
    //       ),
    //       TableRow(
    //         children: [
    //           TableCell(
    //             child: Container(
    //               padding: const EdgeInsets.all(5),
    //               child: const Text(
    //                 "Брэнд",
    //                 style: TextStyle(color: Colors.black, fontSize: 14),
    //               ),
    //             ),
    //           ),
    //           TableCell(
    //             child: Container(
    //               padding: const EdgeInsets.all(5),
    //               child: Text(
    //                 item["b_name"] ?? "",
    //                 style: const TextStyle(color: Colors.black, fontSize: 14),
    //               ),
    //             ),
    //           )
    //         ],
    //       ),
    //       TableRow(
    //         children: [
    //           TableCell(
    //             child: Container(
    //               padding: const EdgeInsets.all(5),
    //               child: const Text(
    //                 "Производитель",
    //                 style: TextStyle(color: Colors.black, fontSize: 14),
    //               ),
    //             ),
    //           ),
    //           TableCell(
    //             child: Container(
    //               padding: const EdgeInsets.all(5),
    //               child: Text(
    //                 item["m_name"] ?? "",
    //                 style: const TextStyle(color: Colors.black, fontSize: 14),
    //               ),
    //             ),
    //           )
    //         ],
    //       ),
    //     ],
    //   );

    //   setState(
    //     () {
    //       amount = item["amount"];
    //       properties = properties;
    //       TabText = [
    //         item["description"] ?? "",
    //         item["b_desc"] ?? "",
    //         item["m_desc"] ?? ""
    //       ];
    //       groupItems = groupItems;

    //       propertiesWidget = propertiesT;
    //     },
    //   );
    //   setState(() {
    //     if (item.isNotEmpty) {
    //       _image = CachedNetworkImage(
    //         fit: BoxFit.fitHeight,
    //         cacheManager: CacheManager(Config(
    //           "itemImage",
    //           stalePeriod: const Duration(days: 7),
    //           //one week cache period
    //         )),
    //         imageUrl: 'https://naliv.kz/img/${item["photo"]}',
    //         placeholder: ((context, url) {
    //           return const CircularProgressIndicator();
    //         }),
    //         errorWidget: ((context, url, error) {
    //           return const Text("Нет изображения");
    //         }),
    //       );
    //       // _image = Image.network(
    //       //   'https://naliv.kz/img/${item["photo"]}',
    //       //   fit: BoxFit.cover,
    //       //   // width: MediaQuery.of(context).size.width * 0.8,
    //       // );
    //     }
    //   });
  }

  // @override
  // void initState() {
  //   // TODO: implement initState
  //   super.initState();
  //   // setState(() {
  //   //   element = widget.element;
  //   //   isLoad = false;
  //   // });
  // }

  // // Future<void> refreshItemCard() async {
  // //   if (item["item_id"] != null) {
  // //     Map<String, dynamic>? _element = await getItem(item["item_id"]);
  // //     setState(() {
  // //       item = _element!;
  // //     });
  // //   }
  // // }

  // void _getRecomendations() {}

  // BUTTON VARIABLES/FUNCS START

  int cacheAmount = 0;
  bool isNumPickActive = false;
  bool isAmountChanged = false;
  late int inStock;
  final ScrollController _scrollController = ScrollController();

  Future<bool> _deleteFromCart(String itemId) async {
    bool? result = await deleteFromCart(itemId);
    result ??= false;

    print(result);
    return Future(() => result!);
  }

  Future<String?> _finalizeCartAmount() async {
    if (cacheAmount == 0) {
      _deleteFromCart(widget.item["item_id"]);
      return "0";
    }
    String? finalAmount;
    await changeCartItem(item["item_id"], cacheAmount).then(
      (value) {
        print(value);
        finalAmount = value;
      },
    ).onError(
      (error, stackTrace) {
        throw Exception("buyButton _addToCart failed");
      },
    );
    return finalAmount;
  }

  void _removeFromCart() {
    setState(() {
      isAmountChanged = true;
      if (cacheAmount > 0) {
        cacheAmount--;
      }
    });
  }

  void _addToCart() {
    setState(() {
      isAmountChanged = true;
      if (cacheAmount < inStock) {
        cacheAmount++;
      }
    });
  }

  // BUTTON VARIABLES/FUNCS END

  String formatCost(String costString) {
    int cost = double.parse(costString).truncate();
    return NumberFormat("###,###", "en_US").format(cost).replaceAll(',', ' ');
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    setState(() {
      cacheAmount = int.parse(widget.item["amount"] ?? "0");
      if (widget.item["in_stock"] != null) {
        inStock = double.parse(widget.item["in_stock"]).truncate();
      } else {
        inStock = 0;
      }

      bool isImageDownloaded = false;
      _image = CachedNetworkImage(
        fit: BoxFit.fitHeight,
        cacheManager: CacheManager(Config(
          "itemImage",
          stalePeriod: const Duration(days: 7),
          //one week cache period
        )),
        imageUrl: item["img"],
        progressIndicatorBuilder: (context, url, progress) {
          if (progress.progress == 1) isImageDownloaded = true;
          return CircularProgressIndicator(
            value: isImageDownloaded ? 1 : progress.progress,
          );
        },
        // placeholder: ((context, url) {
        //   return const CircularProgressIndicator();
        // }),
        errorWidget: ((context, url, error) {
          return const Text("Нет изображения");
        }),
      );
      Future.delayed(const Duration(milliseconds: 0)).whenComplete(() async {
        await _getItem().then((value) {
          print("DATA RECIEVED!");
        });
      });
    });
  }

  @override
  void dispose() {
    if (isAmountChanged) {
      Future.delayed(const Duration(microseconds: 0), () async {
        await _finalizeCartAmount();
        widget.returnDataAmount(cacheAmount.toString(), widget.index);
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      snap: true,
      expand: false,
      initialChildSize: 1,
      maxChildSize: 1,
      minChildSize: 0.9,
      shouldCloseOnMinExtent: true,
      snapAnimationDuration: const Duration(milliseconds: 150),
      builder: ((context, scrollController) {
        return _productPage(context, scrollController);
      }),
    );
  }

  Scaffold _productPage(
      BuildContext context, ScrollController scrollController) {
    return Scaffold(
      // color: Colors.white,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: item.isNotEmpty
            ? Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      disabledBackgroundColor:
                          Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 20,
                      ),
                    ),
                    onPressed: null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          fit: FlexFit.tight,
                          child: IconButton(
                            padding: const EdgeInsets.all(0),
                            onPressed: () {
                              _removeFromCart();
                            },
                            icon: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.remove_rounded,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                        Flexible(
                          flex: 3,
                          fit: FlexFit.tight,
                          child: Text(
                            cacheAmount == 0
                                ? "${formatCost(item["price"])} ₸"
                                : "${formatCost((cacheAmount * int.parse(item["price"])).toString())} ₸",
                            textHeightBehavior: const TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 26,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                        cacheAmount == 0
                            ? Flexible(
                                flex: 2,
                                fit: FlexFit.tight,
                                child: Text(
                                  "Купить",
                                  textHeightBehavior: const TextHeightBehavior(
                                    applyHeightToFirstAscent: false,
                                  ),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              )
                            : Flexible(
                                flex: 2,
                                fit: FlexFit.tight,
                                child: GestureDetector(
                                  onLongPress: () {
                                    setState(() {
                                      isNumPickActive = true;
                                    });
                                  },
                                  child: Text(
                                    "$cacheAmount шт.",
                                    textHeightBehavior:
                                        const TextHeightBehavior(
                                      applyHeightToFirstAscent: false,
                                    ),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 20,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                        Flexible(
                          fit: FlexFit.tight,
                          child: IconButton(
                            padding: const EdgeInsets.all(0),
                            onPressed: () {
                              _addToCart();
                            },
                            icon: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.add_rounded,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  isNumPickActive
                      ? SizedBox(
                          width: double.infinity,
                          child: Row(
                            children: [
                              const Flexible(
                                flex: 1,
                                fit: FlexFit.tight,
                                child: SizedBox(),
                              ),
                              const Flexible(
                                flex: 3,
                                fit: FlexFit.tight,
                                child: SizedBox(),
                              ),
                              Flexible(
                                flex: 2,
                                fit: FlexFit.tight,
                                child: _numberPicker(context),
                              ),
                              const Flexible(
                                flex: 1,
                                fit: FlexFit.tight,
                                child: SizedBox(),
                              )
                            ],
                          ),
                        )
                      : const SizedBox()
                ],
              )
            : Shimmer.fromColors(
                baseColor:
                    Theme.of(context).colorScheme.secondary.withOpacity(0.05),
                highlightColor: Theme.of(context).colorScheme.secondary,
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  height: 50,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    color: Colors.white,
                  ),
                  child: null,
                ),
              ),
      ),
      body: ListView(
        controller: scrollController,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.width,
            child: Stack(
              children: [
                Container(
                  alignment: Alignment.center,
                  child: Container(
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.all(
                        Radius.circular(10),
                      ),
                    ),
                    clipBehavior: Clip.none,
                    child: _image,
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.width,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            icon: const Icon(
                              Icons.arrow_back_ios,
                            ),
                          ),
                          // IconButton(
                          //   onPressed: () {},
                          //   icon: const Icon(Icons.share_outlined),
                          // ),
                        ],
                      ),
                      // Row(
                      //   mainAxisSize: MainAxisSize.max,
                      //   mainAxisAlignment: MainAxisAlignment.end,
                      //   crossAxisAlignment: CrossAxisAlignment.center,
                      //   children: [
                      //     Container(
                      //       margin: const EdgeInsets.all(5),
                      //       child: item.isNotEmpty
                      //           ? LikeButton(
                      //               item_id: item["item_id"],
                      //               is_liked: item["is_liked"],
                      //             )
                      //           : Container(),
                      //     )
                      //   ],
                      // )
                    ],
                  ),
                )
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(5))),
                      child: const Text(
                        "Новинка",
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(5))),
                      child: const Text(
                        "Новинка",
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(5))),
                      child: const Text(
                        "Новинка",
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.all(5),
                  child: item.isNotEmpty
                      ? LikeButton(
                          item_id: item["item_id"],
                          is_liked: item["is_liked"],
                        )
                      : Container(),
                )
              ],
            ),
          ),
          item.isNotEmpty
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        item["name"] ?? "",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        "${double.parse(item["in_stock"] ?? "0").truncate().toString()} шт. в наличии",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                )
              // TODO: Maybe not even needed anymore, content inside productPage loads immediately because data recieved from categoryPage
              : Shimmer.fromColors(
                  baseColor:
                      Theme.of(context).colorScheme.secondary.withOpacity(0.05),
                  highlightColor: Theme.of(context).colorScheme.secondary,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: 40,
                    color: Colors.white,
                  ),
                ),
          Container(
            width: MediaQuery.of(context).size.width,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            child: Wrap(
              children: propertiesWidget,
            ),
          ),
          item["group"] != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  height: 50,
                  width: MediaQuery.of(context).size.width,
                  child: ListView(
                    primary: false,
                    shrinkWrap: true,
                    scrollDirection: Axis.horizontal,
                    children: groupItems,
                  ),
                )
              : Container(),
          const SizedBox(
            height: 5,
          ),
          Stack(
            children: [
              Container(
                height: 25,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withOpacity(0.15),
                        offset: const Offset(0, -1),
                        blurRadius: 15,
                        spreadRadius: 1)
                  ],
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200, width: 3),
                  ),
                ),
                child: const Row(
                  children: [],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  GestureDetector(
                    child: Container(
                      margin: const EdgeInsets.only(left: 15),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            width: 3,
                            color: currentTab == 0
                                ? Colors.black
                                : Colors.grey.shade200,
                          ),
                        ),
                      ),
                      child: const Text(
                        "Описание",
                        style: TextStyle(color: Colors.black, fontSize: 16),
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        currentTab = 0;
                      });
                    },
                  ),
                  GestureDetector(
                    child: Container(
                      margin: const EdgeInsets.only(left: 15),
                      height: 25,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            width: 3,
                            color: currentTab == 1
                                ? Colors.black
                                : Colors.grey.shade200,
                          ),
                        ),
                      ),
                      child: const Text(
                        "О бренде",
                        style: TextStyle(color: Colors.black, fontSize: 16),
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        currentTab = 1;
                      });
                    },
                  ),
                  GestureDetector(
                    child: Container(
                      margin: const EdgeInsets.only(left: 15),
                      height: 25,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            width: 3,
                            color: currentTab == 2
                                ? Colors.black
                                : Colors.grey.shade200,
                          ),
                        ),
                      ),
                      child: const Text(
                        "Производитель",
                        style: TextStyle(color: Colors.black, fontSize: 16),
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        currentTab = 2;
                      });
                    },
                  ),
                ],
              )
            ],
          ),
          isDescriptionLoaded
              ? Container(
                  padding: const EdgeInsets.all(15),
                  child: Text(TabText[currentTab]),
                )
              : SizedBox(
                  child: SlideTransition(
                    position: AlwaysStoppedAnimation(
                      Offset(0, -1),
                    ),
                    child: const LinearProgressIndicator(),
                  ),
                ),
          Container(
            padding: const EdgeInsets.all(15),
            child: Table(
              columnWidths: const {0: FlexColumnWidth(), 1: FlexColumnWidth()},
              border: TableBorder(
                  horizontalInside:
                      BorderSide(width: 1, color: Colors.grey.shade400),
                  bottom: BorderSide(width: 1, color: Colors.grey.shade400)),
              children: properties,
            ),
          ),
          const SizedBox(
            height: 100,
          )
        ],
      ),
    );
  }

  Container _numberPicker(BuildContext context) {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(
          Radius.circular(10),
        ),
        color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
      ),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: double.parse(item["in_stock"]).truncate() + 2,
        itemExtent: 33.3,
        itemBuilder: (context, index) {
          if (index == 0 ||
              index == double.parse(item["in_stock"]).truncate() + 1) {
            return const SizedBox(
              height: 33.3,
            );
          }
          return GestureDetector(
            onTap: () {
              setState(() {
                cacheAmount = index;
              });
              isNumPickActive = false;
            },
            child: SizedBox(
              height: 33.3,
              child: Text(
                index.toString(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 20,
                  fontWeight:
                      index == cacheAmount ? FontWeight.w900 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
