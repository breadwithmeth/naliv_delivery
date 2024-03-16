import 'dart:async';

import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/shared/buyButton.dart';
import 'package:naliv_delivery/shared/likeButton.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProductPage extends StatefulWidget {
  const ProductPage(
      {super.key, required this.item_id, required this.returnWidget});
  final String item_id;
  final Widget returnWidget;
  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  Widget _image = Container();
  Map<String, dynamic> item = {};
  List<Widget> groupItems = [];
  List<TableRow> properties = [];

  late BuyButtonFullWidth _buyButtonFullWidth;

  final ScrollController _sc = ScrollController();

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
                      return ProductPage(
                          item_id: element["item_id"],
                          returnWidget: widget.returnWidget);
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

          _buyButtonFullWidth = BuyButtonFullWidth(element: item);

          if (item.isNotEmpty) {
            _image = CachedNetworkImage(
              fit: BoxFit.fitHeight,
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
        },
      );
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

  Future<void> _addToCard() async {
    // setState(() {
    //   isLoad = true;
    // });
    String? amount1 = await addToCart(widget.item_id).then((value) {
      print(value);
      setState(() {
        amount = value;
      });
      return null;
    });
  }

  void _getRecomendations() {}

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getItem();
  }

  @override
  Widget build(BuildContext context) {
    return _productPage(context);
  }

  Scaffold _productPage(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: GestureDetector(
        child: Container(
          height: 80,
          decoration: const BoxDecoration(
              // color: Colors.grey.shade400,
              borderRadius: BorderRadius.all(Radius.circular(15))),
          margin: const EdgeInsets.all(5),
          padding: const EdgeInsets.all(4),
          width: MediaQuery.of(context).size.width,
          child: item.isNotEmpty ? _buyButtonFullWidth : null,
        ),
      ),
      backgroundColor: const Color(0xAAFAFAFA),
      body: Container(
        color: Colors.white,
        child: ListView(
          controller: _sc,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.width,
              child: Stack(
                children: [
                  Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.only(bottom: 30),
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
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              child: Text(
                item["name"] ?? "",
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.black),
              ),
            ),
            const SizedBox(
              height: 5,
            ),
            Container(
                width: MediaQuery.of(context).size.width,
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                child: Wrap(
                  children: propertiesWidget,
                )),
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
                          bottom: BorderSide(
                              color: Colors.grey.shade200, width: 3))),
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
                  columnWidths: const {
                    0: FlexColumnWidth(),
                    1: FlexColumnWidth()
                  },
                  border: TableBorder(
                      horizontalInside:
                          BorderSide(width: 1, color: Colors.grey.shade400),
                      bottom:
                          BorderSide(width: 1, color: Colors.grey.shade400)),
                  children: properties,
                )),
            Container(
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
            const SizedBox(
              height: 100,
            )
          ],
        ),
      ),
    );
  }
}
