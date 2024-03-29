import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/cartPage.dart';
import 'package:naliv_delivery/shared/likeButton.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:shimmer/shimmer.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key, required this.item_id});
  final String item_id;
  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  Widget _image = Container();
  Map<String, dynamic> item = {};
  List<Widget> groupItems = [];
  List<TableRow> properties = [];

  List<Widget> propertiesWidget = [];

  int currentTab = 0;
  String? amount;
  List<String> TabText = [
    "Виски Ballantine's 12 лет — это бленд 40 отборных солодовых и зерновых дистиллятов, минимальный срок выдержки которых составляет 12 лет. ",
    "Джордж Баллантайн (George Ballantine) – выходец из семьи простых фермеров, начал свою трудовую карьеру в возрасте девятнадцати лет в качестве подсобного рабочего в бакалейной лавке в Эдинбурге. Здесь, в 1827 году, Джордж открывает свой бакалейный магазин, в котором небольшими партиями начинает реализовывать собственный алкоголь. К 1865 году Баллантайну удается открыть еще один магазин в Глазго, куда и переезжает глава семьи, оставив торговлю в Эдинбурге старшему сыну Арчибальду. В это время виски под маркой Ballantine’s продают уже по всей Шотландии, а Джордж возглавляет компанию George Ballantine and Son, престижную репутацию которой в 1895 году подтвердил факт получения ордена Королевы Виктории.",
    "Начиная с 2005 года производством Ballantine занимается компания Pernod Ricard, которая тщательно следит за репутацией бренда, сохраняя рецепты и старинные традиции."
  ];

  Future<void> _getItem() async {
    item = await getItem(widget.item_id);
    print(item);
    if (item.isNotEmpty) {
      List<Widget> groupItems = [];
      List<TableRow> properties = [];
      List<Widget> propertiesT = [];

      if (item["group"] != null) {
        List temp = item["group"];
        for (var element in temp) {
          print(element);
          groupItems.add(
            GestureDetector(
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return ProductPage(item_id: element["item_id"]);
                    },
                  ),
                );
              },
              child: Container(
                alignment: Alignment.center,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                margin: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: const BorderRadius.all(Radius.circular(5))),
                child: Text(
                  element["amount"],
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          );
        }
      }

      if (item["properties"] != null) {
        List temp = item["properties"];

        for (var element in temp) {
          propertiesT.add(
            Container(
              padding: const EdgeInsets.all(5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    element["amount"],
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black),
                  ),
                  Image.asset(
                    "assets/property_icons/${element["icon"]}.png",
                    width: 14,
                    height: 14,
                  ),
                  const SizedBox(
                    width: 10,
                  )
                ],
              ),
            ),
          );
        }

        if (item["country"] != null) {
          propertiesT.add(
            Container(
              padding: const EdgeInsets.all(5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item["country"],
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black),
                  ),
                  Image.asset(
                    "assets/property_icons/litr.png",
                    width: 14,
                    height: 14,
                  ),
                  const SizedBox(
                    width: 10,
                  )
                ],
              ),
            ),
          );
        }

        for (var element in temp) {
          properties.add(
            TableRow(
              children: [
                TableCell(
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    child: Text(
                      element["name"],
                      style: const TextStyle(color: Colors.black, fontSize: 14),
                    ),
                  ),
                ),
                TableCell(
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    child: Text(
                      element["amount"] + element["unit"],
                      style: const TextStyle(color: Colors.black, fontSize: 14),
                    ),
                  ),
                )
              ],
            ),
          );
        }
      }
      properties.addAll(
        [
          TableRow(
            children: [
              TableCell(
                child: Container(
                  padding: const EdgeInsets.all(5),
                  child: const Text(
                    "Страна",
                    style: TextStyle(color: Colors.black, fontSize: 14),
                  ),
                ),
              ),
              TableCell(
                child: Container(
                  padding: const EdgeInsets.all(5),
                  child: Text(
                    item["country"] ?? "",
                    style: const TextStyle(color: Colors.black, fontSize: 14),
                  ),
                ),
              )
            ],
          ),
          TableRow(
            children: [
              TableCell(
                child: Container(
                  padding: const EdgeInsets.all(5),
                  child: const Text(
                    "Брэнд",
                    style: TextStyle(color: Colors.black, fontSize: 14),
                  ),
                ),
              ),
              TableCell(
                child: Container(
                  padding: const EdgeInsets.all(5),
                  child: Text(
                    item["b_name"] ?? "",
                    style: const TextStyle(color: Colors.black, fontSize: 14),
                  ),
                ),
              )
            ],
          ),
          TableRow(
            children: [
              TableCell(
                child: Container(
                  padding: const EdgeInsets.all(5),
                  child: const Text(
                    "Производитель",
                    style: TextStyle(color: Colors.black, fontSize: 14),
                  ),
                ),
              ),
              TableCell(
                child: Container(
                  padding: const EdgeInsets.all(5),
                  child: Text(
                    item["m_name"] ?? "",
                    style: const TextStyle(color: Colors.black, fontSize: 14),
                  ),
                ),
              )
            ],
          ),
        ],
      );

      setState(
        () {
          amount = item["amount"];
          properties = properties;
          TabText = [
            item["description"] ?? "",
            item["b_desc"] ?? "",
            item["m_desc"] ?? ""
          ];
          groupItems = groupItems;

          propertiesWidget = propertiesT;
        },
      );
      setState(() {
        if (item.isNotEmpty) {
          _image = CachedNetworkImage(
            fit: BoxFit.fitHeight,
            cacheManager: CacheManager(Config(
              "itemImage",
              stalePeriod: const Duration(days: 7),
              //one week cache period
            )),
            imageUrl: 'https://naliv.kz/img/${item["photo"]}',
            placeholder: ((context, url) {
              return const Expanded(child: CircularProgressIndicator());
            }),
            errorWidget: ((context, url, error) {
              return const Expanded(child: Text("Нет изображения"));
            }),
          );
          // _image = Image.network(
          //   'https://naliv.kz/img/${item["photo"]}',
          //   fit: BoxFit.cover,
          //   // width: MediaQuery.of(context).size.width * 0.8,
          // );
        }
      });
    }
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
  bool isAmountConfirmed = false;

  Future<String?> _finalizeCartAmount() async {
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
      isAmountConfirmed = false;
      if (cacheAmount > 0) {
        cacheAmount--;
      }
    });
  }

  void _addToCart() {
    setState(() {
      isAmountConfirmed = false;
      if (cacheAmount < 1000) {
        cacheAmount++;
      }
    });
  }

  // BUTTON VARIABLES/FUNCS END

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getItem();
    setState(() {
      if (item["amount"] != null) {
        cacheAmount = int.parse(item["amount"]);
      } else {
        cacheAmount = 0;
      }
    });
  }

  @override
  void dispose() {
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
      floatingActionButton: GestureDetector(
        child: Container(
          height: 80,
          decoration: const BoxDecoration(
              // color: Colors.grey.shade400,
              borderRadius: BorderRadius.all(Radius.circular(10))),
          margin: const EdgeInsets.all(5),
          padding: const EdgeInsets.all(4),
          width: MediaQuery.of(context).size.width,
          child: item.isNotEmpty
              ? cacheAmount != 0
                  ? Container(
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(3))),
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          GestureDetector(
                            onLongPress: (() {
                              setState(() {
                                isNumPickActive = true;
                              });
                            }),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: IconButton(
                                    padding: const EdgeInsets.all(0),
                                    onPressed: () {
                                      _removeFromCart();
                                    },
                                    icon: Icon(
                                      Icons.remove_rounded,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary,
                                    ),
                                  ),
                                ),
                                isNumPickActive
                                    ? Flexible(
                                        child: GestureDetector(
                                          onTap: (() {
                                            setState(() {
                                              isNumPickActive = false;
                                            });
                                          }),
                                          child: NumberPicker(
                                            value: cacheAmount,
                                            textStyle: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onPrimary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            selectedTextStyle: const TextStyle(
                                              color: Colors.blue,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            itemHeight: 25,
                                            itemWidth: 25,
                                            minValue: 0,
                                            maxValue:
                                                20, // TODO: CHANGE IT TO AMOUNT FROM BACK-END
                                            onChanged: (value) => setState(() {
                                              cacheAmount = value;
                                              if (value == 0) {
                                                isNumPickActive = false;
                                              }
                                            }),
                                          ),
                                        ),
                                      )
                                    : Flexible(
                                        child: Text(
                                          cacheAmount.toString(),
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                Flexible(
                                  child: IconButton(
                                    padding: const EdgeInsets.all(0),
                                    // style: IconButton.styleFrom(
                                    //   shape: const RoundedRectangleBorder(
                                    //     borderRadius:
                                    //         BorderRadius.all(Radius.circular(12)),
                                    //   ),
                                    //   side: const BorderSide(
                                    //     width: 2.6,
                                    //     strokeAlign: -7.0,
                                    //   ),
                                    // ),
                                    onPressed: () {
                                      _addToCart();
                                    },
                                    icon: Icon(
                                      Icons.add_rounded,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              item["prev_price"] != null
                                  ? Text(
                                      item["prev_price"],
                                      style: TextStyle(
                                          decoration:
                                              TextDecoration.lineThrough,
                                          decorationColor: Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                          decorationThickness: 1.85,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500),
                                    )
                                  : Container(),
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 7, right: 5),
                                child: Text(
                                  item["price"] ?? "",
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 26,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary),
                                ),
                              ),
                              Text(
                                "₸",
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 30,
                                ),
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (child, animation) {
                                  return ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  );
                                },
                                child: !isAmountConfirmed
                                    ? IconButton(
                                        key: const Key("add_cart"),
                                        onPressed: () {
                                          _finalizeCartAmount();
                                          setState(() {
                                            isAmountConfirmed = true;
                                          });
                                          // Navigator.push(context,
                                          //     MaterialPageRoute(builder: (context) {
                                          //   return const CartPage();
                                          // }));
                                        },
                                        icon: Icon(
                                          Icons.add_shopping_cart_rounded,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                        ),
                                      )
                                    : IconButton(
                                        key: const Key("go_cart"),
                                        onPressed: () {
                                          // _finalizeCartAmount();
                                          Navigator.push(context,
                                              MaterialPageRoute(
                                                  builder: (context) {
                                            return const CartPage();
                                          }));
                                        },
                                        icon: Icon(
                                          Icons.shopping_cart_checkout_rounded,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                        ),
                                      ),
                              ),
                            ],
                          )
                        ],
                      ),
                    )
                  : ElevatedButton(
                      // style: ElevatedButton.styleFrom(
                      //   padding: const EdgeInsets.all(10),
                      //   backgroundColor: Colors.grey.shade400,
                      // ),
                      onPressed: () {
                        _addToCart();
                      },
                      child: Container(
                        decoration: const BoxDecoration(
                            borderRadius:
                                BorderRadius.all(Radius.circular(10))),
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Text(
                              "В корзину",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                item["prev_price"] != null
                                    ? Text(
                                        item["prev_price"],
                                        style: TextStyle(
                                            decoration:
                                                TextDecoration.lineThrough,
                                            decorationColor: Theme.of(context)
                                                .colorScheme
                                                .onPrimary,
                                            decorationThickness: 1.85,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500),
                                      )
                                    : Container(),
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 7, right: 5),
                                  child: Text(
                                    item["price"] ?? "",
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 26,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary),
                                  ),
                                ),
                                Text(
                                  "₸",
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 30,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
              : Shimmer.fromColors(
                  baseColor:
                      Theme.of(context).colorScheme.secondary.withOpacity(0.05),
                  highlightColor: Theme.of(context).colorScheme.secondary,
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    height: 50,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                      color: Colors.white,
                    ),
                    child: null,
                  ),
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
                  child: Expanded(child: _image),
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
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.share_outlined),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
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
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            child: Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: const BorderRadius.all(Radius.circular(5))),
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
                      borderRadius: const BorderRadius.all(Radius.circular(5))),
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
                      borderRadius: const BorderRadius.all(Radius.circular(5))),
                  child: const Text(
                    "Новинка",
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
          item.isNotEmpty
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  child: Text(
                    item["name"] ?? "",
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.black),
                  ),
                )
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
          const SizedBox(
            height: 5,
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
                      children: groupItems),
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
                        bottom:
                            BorderSide(color: Colors.grey.shade200, width: 3))),
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
                                      : Colors.grey.shade200))),
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
                                      : Colors.grey.shade200))),
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
                                      : Colors.grey.shade200))),
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
          Container(
            padding: const EdgeInsets.all(15),
            child: Text(TabText[currentTab]),
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
}
