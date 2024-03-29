import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/shared/likeButton.dart';

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
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black),
            ),
            Image.asset(
              "assets/property_icons/${temp[0]}.png",
              width: 14,
              height: 14,
            ),
            const SizedBox(
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
      // margin: const EdgeInsets.all(10),
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height * 0.28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          Flexible(
            flex: 3,
            child: CachedNetworkImage(
              imageUrl: element["thumb"],
              width: double.infinity,
              // width: MediaQuery.of(context).size.width * 0.2,
              // height: MediaQuery.of(context).size.width * 0.7,
              fit: BoxFit.fitHeight,
              cacheManager: CacheManager(Config(
                "itemImage",
                stalePeriod: const Duration(days: 7),
                //one week cache period
              )),
              placeholder: (context, url) {
                return Container(
                  alignment: Alignment.center,
                  color: Colors.white,
                  // width: MediaQuery.of(context).size.width * 0.2,
                  child: const CircularProgressIndicator(),
                );
              },
              errorWidget: (context, url, error) {
                return Container(
                  alignment: Alignment.center,
                  // width: MediaQuery.of(context).size.width * 0.2,
                  child: const Expanded(
                    child: Text(
                      "Нет изображения",
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ),
          Flexible(
            flex: 5,
            fit: FlexFit.tight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
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
                        style: const TextStyle(
                          textBaseline: TextBaseline.alphabetic,
                          fontSize: 20,
                          color: Colors.black,
                        ),
                        children: [
                          TextSpan(text: element["name"]),
                          element["country"] != null
                              ? WidgetSpan(
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(10))),
                                    child: Text(
                                      element["country"] ?? "",
                                      style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                )
                              : const TextSpan()
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
                              element['price'] ?? "",
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 28),
                            ),
                            Text(
                              "₸",
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 28),
                            )
                          ],
                        ),
                        element["prev_price"] != null
                            ? Padding(
                                padding: const EdgeInsets.only(left: 5),
                                child: Row(
                                  children: [
                                    Text(
                                      element["prev_price"],
                                      style: TextStyle(
                                          decoration:
                                              TextDecoration.lineThrough,
                                          decorationColor: Colors.grey.shade500,
                                          decorationThickness: 1.85,
                                          color: Colors.grey.shade500,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      "₸",
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14),
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
                        //             ? const NumberPicker(amount: 50)
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
      required this.scroll});
  final Map<String, dynamic> element;
  final String category_name;

  final String item_id;

  final String category_id;
  final double scroll;
  int chack = 1;
  @override
  State<ItemCardMedium> createState() => _ItemCardMediumState();
}

class _ItemCardMediumState extends State<ItemCardMedium> {
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
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black),
            ),
            Image.asset(
              "assets/property_icons/${temp[0]}.png",
              width: 14,
              height: 14,
            ),
            const SizedBox(
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
      // margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height * 0.2,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          Flexible(
            flex: 2,
            child: CachedNetworkImage(
              height: double.infinity,
              imageUrl: element["thumb"],
              // width: MediaQuery.of(context).size.width * 0.2,
              // height: MediaQuery.of(context).size.width * 0.7,
              fit: BoxFit.cover,
              cacheManager: CacheManager(Config(
                "itemImage",
                stalePeriod: const Duration(days: 700),
                //one week cache period
              )),
              placeholder: (context, url) {
                return Container(
                  alignment: Alignment.center,
                  color: Colors.white,
                  // width: MediaQuery.of(context).size.width * 0.2,
                  child: const CircularProgressIndicator(),
                );
              },
              errorWidget: (context, url, error) {
                return Container(
                  alignment: Alignment.center,
                  // width: MediaQuery.of(context).size.width * 0.2,
                  child: const Expanded(
                    child: Text(
                      "Нет изображения",
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ),
          Flexible(
            flex: 5,
            fit: FlexFit.tight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              flex: 5,
                              child: RichText(
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  style: const TextStyle(
                                    textBaseline: TextBaseline.alphabetic,
                                    fontSize: 14,
                                    color: Colors.black,
                                  ),
                                  children: [
                                    TextSpan(text: element["name"]),
                                    element["country"] != null
                                        ? WidgetSpan(
                                            child: Container(
                                              padding: const EdgeInsets.all(5),
                                              decoration: BoxDecoration(
                                                  color: Colors.grey.shade200,
                                                  borderRadius:
                                                      const BorderRadius.all(
                                                          Radius.circular(10))),
                                              child: Text(
                                                element["country"] ?? "",
                                                style: const TextStyle(
                                                    color: Colors.black,
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                            ),
                                          )
                                        : const TextSpan()
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text("${element["in_stock"] ?? "0"} шт в наличии"),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          flex: 5,
                          child: Column(
                            children: [
                              element["prev_price"] != null
                                  ? Row(
                                      children: [
                                        Text(
                                          element["prev_price"],
                                          style: TextStyle(
                                              decoration:
                                                  TextDecoration.lineThrough,
                                              decorationColor:
                                                  Colors.grey.shade500,
                                              decorationThickness: 1.85,
                                              color: Colors.grey.shade500,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500),
                                        ),
                                        Text(
                                          "₸",
                                          style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12),
                                        )
                                      ],
                                    )
                                  : Container(),
                              Row(
                                children: [
                                  Text(
                                    element['price'] ?? "",
                                    style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16),
                                  ),
                                  Text(
                                    "₸",
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16),
                                  )
                                ],
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              LikeButton(
                                is_liked: element["is_liked"],
                                item_id: element["item_id"],
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
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black),
            ),
            Image.asset(
              "assets/property_icons/${temp[0]}.png",
              width: 14,
              height: 14,
            ),
            const SizedBox(
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
      // margin: const EdgeInsets.all(10),
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height * 0.1,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          Flexible(
            flex: 2,
            child: CachedNetworkImage(
              imageUrl: element["thumb"],
              width: double.infinity,
              // width: MediaQuery.of(context).size.width * 0.2,
              // height: MediaQuery.of(context).size.width * 0.7,
              fit: BoxFit.fitHeight,
              cacheManager: CacheManager(Config(
                "itemImage",
                stalePeriod: const Duration(days: 7),
                //one week cache period
              )),
              placeholder: (context, url) {
                return Container(
                  alignment: Alignment.center,
                  color: Colors.white,
                  // width: MediaQuery.of(context).size.width * 0.2,
                  child: const CircularProgressIndicator(),
                );
              },
              errorWidget: (context, url, error) {
                return Container(
                  alignment: Alignment.center,
                  // width: MediaQuery.of(context).size.width * 0.2,
                  child: const Expanded(
                    child: Text(
                      "Нет изображения",
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ),
          Flexible(
            flex: 5,
            fit: FlexFit.tight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: RichText(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: const TextStyle(
                          textBaseline: TextBaseline.alphabetic,
                          fontSize: 14,
                          color: Colors.black,
                        ),
                        children: [
                          TextSpan(text: element["name"]),
                          element["country"] != null
                              ? WidgetSpan(
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(10))),
                                    child: Text(
                                      element["country"] ?? "",
                                      style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                )
                              : const TextSpan()
                        ],
                      ),
                    ),
                  ),
                  Flexible(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              element['price'] ?? "",
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16),
                            ),
                            Text(
                              "₸",
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16),
                            ),
                            element["prev_price"] != null
                                ? Padding(
                                    padding: const EdgeInsets.only(left: 5),
                                    child: Row(
                                      children: [
                                        Text(
                                          element["prev_price"],
                                          style: TextStyle(
                                              decoration:
                                                  TextDecoration.lineThrough,
                                              decorationColor:
                                                  Colors.grey.shade500,
                                              decorationThickness: 1.85,
                                              color: Colors.grey.shade500,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500),
                                        ),
                                        Text(
                                          "₸",
                                          style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12),
                                        )
                                      ],
                                    ),
                                  )
                                : Container(),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                "x",
                                style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16),
                              ),
                            ),
                            Text(
                              element["amount"],
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16),
                            ),
                          ],
                        ),
                        Flexible(
                          flex: 1,
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
