import 'dart:async';

import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/categoryPage.dart';
import 'package:naliv_delivery/shared/buyButton.dart';
import 'package:naliv_delivery/shared/likeButton.dart';

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
  Map<String, dynamic>? item = {};
  List<Widget> groupItems = [];
  List<TableRow> properties = [];

  ScrollController _sc = ScrollController();

  List<Widget> propertiesWidget = [];

  int currentTab = 0;
  String? amount = null;
  List<String> TabText = [
    "Виски Ballantine's 12 лет — это бленд 40 отборных солодовых и зерновых дистиллятов, минимальный срок выдержки которых составляет 12 лет. ",
    "Джордж Баллантайн (George Ballantine) – выходец из семьи простых фермеров, начал свою трудовую карьеру в возрасте девятнадцати лет в качестве подсобного рабочего в бакалейной лавке в Эдинбурге. Здесь, в 1827 году, Джордж открывает свой бакалейный магазин, в котором небольшими партиями начинает реализовывать собственный алкоголь. К 1865 году Баллантайну удается открыть еще один магазин в Глазго, куда и переезжает глава семьи, оставив торговлю в Эдинбурге старшему сыну Арчибальду. В это время виски под маркой Ballantine’s продают уже по всей Шотландии, а Джордж возглавляет компанию George Ballantine and Son, престижную репутацию которой в 1895 году подтвердил факт получения ордена Королевы Виктории.",
    "Начиная с 2005 года производством Ballantine занимается компания Pernod Ricard, которая тщательно следит за репутацией бренда, сохраняя рецепты и старинные традиции."
  ];

  Future<void> _getItem() async {
    Map<String, dynamic>? _item = await getItem(widget.item_id);
    print(_item);
    if (_item != null) {
      List<Widget> _groupItems = [];
      List<TableRow> _properties = [];
      List<Widget> properties_t = [];

      if (_item["group"] != null) {
        List temp = _item["group"];
        temp.forEach((element) {
          print(element);
          _groupItems.add(GestureDetector(
            onTap: () {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) {
                return ProductPage(
                    item_id: element["item_id"],
                    returnWidget: widget.returnWidget);
              }));
            },
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              margin: EdgeInsets.all(5),
              decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.all(Radius.circular(5))),
              child: Text(
                element["amount"],
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ));
        });
      }

      if (_item["properties"] != null) {
        List temp = _item["properties"];

        temp.forEach((element) {
          properties_t.add(Container(
              padding: EdgeInsets.all(5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    element["amount"],
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black),
                  ),
                  Image.asset(
                    "assets/property_icons/${element["icon"]}.png",
                    width: 14,
                    height: 14,
                  ),
                  SizedBox(
                    width: 10,
                  )
                ],
              )));
        });

        if (_item["country"] != null) {
          properties_t.add(Container(
              padding: EdgeInsets.all(5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _item["country"],
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black),
                  ),
                  Image.asset(
                    "assets/property_icons/litr.png",
                    width: 14,
                    height: 14,
                  ),
                  SizedBox(
                    width: 10,
                  )
                ],
              )));
        }

        temp.forEach((element) {
          _properties.add(TableRow(children: [
            TableCell(
              child: Container(
                child: Text(
                  element["name"],
                  style: TextStyle(color: Colors.black, fontSize: 14),
                ),
                padding: EdgeInsets.all(5),
              ),
            ),
            TableCell(
              child: Container(
                child: Text(
                  element["amount"] + element["unit"],
                  style: TextStyle(color: Colors.black, fontSize: 14),
                ),
                padding: EdgeInsets.all(5),
              ),
            )
          ]));
        });
      }
      _properties.addAll([
        TableRow(children: [
          TableCell(
            child: Container(
              child: Text(
                "Страна",
                style: TextStyle(color: Colors.black, fontSize: 14),
              ),
              padding: EdgeInsets.all(5),
            ),
          ),
          TableCell(
            child: Container(
              child: Text(
                _item["country"] ?? "",
                style: TextStyle(color: Colors.black, fontSize: 14),
              ),
              padding: EdgeInsets.all(5),
            ),
          )
        ]),
        TableRow(children: [
          TableCell(
            child: Container(
              child: Text(
                "Брэнд",
                style: TextStyle(color: Colors.black, fontSize: 14),
              ),
              padding: EdgeInsets.all(5),
            ),
          ),
          TableCell(
            child: Container(
              child: Text(
                _item["b_name"] ?? "",
                style: TextStyle(color: Colors.black, fontSize: 14),
              ),
              padding: EdgeInsets.all(5),
            ),
          )
        ]),
        TableRow(children: [
          TableCell(
            child: Container(
              child: Text(
                "Производитель",
                style: TextStyle(color: Colors.black, fontSize: 14),
              ),
              padding: EdgeInsets.all(5),
            ),
          ),
          TableCell(
            child: Container(
              child: Text(
                _item["m_name"] ?? "",
                style: TextStyle(color: Colors.black, fontSize: 14),
              ),
              padding: EdgeInsets.all(5),
            ),
          )
        ]),
      ]);

      setState(() {
        item = _item;
        amount = item?["amount"];
        properties = _properties;
        TabText = [
          _item["description"] ?? "",
          _item["b_desc"] ?? "",
          _item["m_desc"] ?? ""
        ];
        groupItems = _groupItems;

        propertiesWidget = properties_t;

        if (item != null) {
          _image = Image.network(
            'https://naliv.kz/img/' + item!["photo"].toString(),
            fit: BoxFit.cover,
            // width: MediaQuery.of(context).size.width * 0.8,
          );
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
  // //     Map<String, dynamic>? _element = await getItem(item!["item_id"]);
  // //     setState(() {
  // //       item = _element!;
  // //     });
  // //   }
  // // }

  Future<void> _addToCard() async {
    // setState(() {
    //   isLoad = true;
    // });
    String? _amount = await addToCart(widget.item_id).then((value) {
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
    Timer(Duration(seconds: 3), () {});
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        top: false,
        child: Scaffold(
          appBar: AppBar(
            toolbarHeight: 0,
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: GestureDetector(
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                  // color: Colors.grey.shade400,
                  borderRadius: BorderRadius.all(Radius.circular(15))),
              margin: EdgeInsets.all(5),
              padding: EdgeInsets.all(4),
              width: MediaQuery.of(context).size.width,
              child: amount != null
                  ? Container(
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.all(Radius.circular(15))),
                      padding: EdgeInsets.all(10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            alignment: Alignment.centerLeft,
                            width: MediaQuery.of(context).size.width * 0.3,
                            child: Container(
                              padding: EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(10))),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    padding: EdgeInsets.all(0),
                                    onPressed: () async {
                                      String? _amount =
                                          await removeFromCart(widget.item_id);
                                      setState(() {
                                        amount = _amount;
                                      });
                                    },
                                    icon: Icon(Icons.remove),
                                  ),
                                  Text(
                                    amount.toString(),
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  IconButton(
                                    padding: EdgeInsets.all(0),
                                    onPressed: () {
                                      _addToCard();
                                    },
                                    icon: Icon(Icons.add),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              item?["prev_price"] != null
                                  ? Text(
                                      item?["prev_price"],
                                      style: TextStyle(
                                          decoration:
                                              TextDecoration.lineThrough),
                                    )
                                  : Container(),
                              SizedBox(
                                width: 5,
                              ),
                              Text(
                                item?["price"] ?? "",
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 26,
                                    color: Colors.black),
                              )
                            ],
                          )
                        ],
                      ),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.all(10),
                          backgroundColor: Colors.grey.shade400),
                      onPressed: () {
                        _addToCard();
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Text(
                            "В корзину",
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                                color: Colors.black),
                          ),
                          Row(
                            children: [
                              item?["prev_price"] != null
                                  ? Text(
                                      item?["prev_price"],
                                      style: TextStyle(
                                          decoration:
                                              TextDecoration.lineThrough,
                                          color: Colors.grey.shade500),
                                    )
                                  : Container(),
                              SizedBox(
                                width: 5,
                              ),
                              Text(
                                item?["price"] ?? "",
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 26,
                                    color: Colors.black),
                              )
                            ],
                          )
                        ],
                      )),
            ),
          ),
          backgroundColor: Color(0xAAFAFAFA),
          body: Container(
            color: Colors.white,
            child: ListView(
              controller: _sc,
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.width,
                  child: Stack(
                    children: [
                      Container(
                        width: double.maxFinite,
                        padding: EdgeInsets.all(40),
                        child: _image,
                      ),
                      Container(
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
                                    Navigator.pushReplacement(context,
                                        MaterialPageRoute(
                                      builder: (context) {
                                        return widget.returnWidget;
                                      },
                                    ));
                                  },
                                  icon: Icon(
                                    Icons.arrow_back_ios,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {},
                                  icon: Icon(Icons.share_outlined),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  "Арт: 1234567",
                                  style: TextStyle(fontSize: 10),
                                ),
                                Container(
                                  child: LikeButton(
                                    item_id: item!["item_id"],
                                    is_liked: item!["is_liked"],
                                  ),
                                  margin: EdgeInsets.all(5),
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
                  child: Row(
                    children: [
                      Container(
                        margin: EdgeInsets.only(right: 10),
                        padding: EdgeInsets.all(5),
                        child: Text(
                          "Новинка",
                          style: TextStyle(color: Colors.black),
                        ),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.all(Radius.circular(5))),
                      ),
                      Container(
                        margin: EdgeInsets.only(right: 10),
                        padding: EdgeInsets.all(5),
                        child: Text(
                          "Новинка",
                          style: TextStyle(color: Colors.black),
                        ),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.all(Radius.circular(5))),
                      ),
                      Container(
                        margin: EdgeInsets.only(right: 10),
                        padding: EdgeInsets.all(5),
                        child: Text(
                          "Новинка",
                          style: TextStyle(color: Colors.black),
                        ),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.all(Radius.circular(5))),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                ),
                Container(
                  child: Text(
                    item!["name"] ?? "",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.black),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                ),
                SizedBox(
                  height: 5,
                ),
                Container(
                    width: MediaQuery.of(context).size.width,
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    child: Wrap(
                      children: propertiesWidget,
                    )),
                item!["group"] != null
                    ? Container(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        height: 50,
                        width: MediaQuery.of(context).size.width,
                        child: ListView(
                            primary: false,
                            shrinkWrap: true,
                            scrollDirection: Axis.horizontal,
                            children: groupItems),
                      )
                    : Container(),
                SizedBox(
                  height: 5,
                ),
                Stack(
                  children: [
                    Container(
                      height: 25,
                      padding: EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                                color: Colors.grey.withOpacity(0.15),
                                offset: Offset(0, -1),
                                blurRadius: 15,
                                spreadRadius: 1)
                          ],
                          border: Border(
                              bottom: BorderSide(
                                  color: Colors.grey.shade200, width: 3))),
                      child: Row(
                        children: [],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        GestureDetector(
                          child: Container(
                            margin: EdgeInsets.only(left: 15),
                            decoration: BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(
                                        width: 3,
                                        color: currentTab == 0
                                            ? Colors.black
                                            : Colors.grey.shade200))),
                            child: Text(
                              "Описание",
                              style:
                                  TextStyle(color: Colors.black, fontSize: 16),
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
                            margin: EdgeInsets.only(left: 15),
                            height: 25,
                            decoration: BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(
                                        width: 3,
                                        color: currentTab == 1
                                            ? Colors.black
                                            : Colors.grey.shade200))),
                            child: Text(
                              "О бренде",
                              style:
                                  TextStyle(color: Colors.black, fontSize: 16),
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
                            margin: EdgeInsets.only(left: 15),
                            height: 25,
                            decoration: BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(
                                        width: 3,
                                        color: currentTab == 2
                                            ? Colors.black
                                            : Colors.grey.shade200))),
                            child: Text(
                              "Производитель",
                              style:
                                  TextStyle(color: Colors.black, fontSize: 16),
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
                  padding: EdgeInsets.all(15),
                  child: Text(TabText[currentTab]),
                ),
                Container(
                    padding: EdgeInsets.all(15),
                    child: Table(
                      columnWidths: {
                        0: FlexColumnWidth(),
                        1: FlexColumnWidth()
                      },
                      border: TableBorder(
                          horizontalInside:
                              BorderSide(width: 1, color: Colors.grey.shade400),
                          bottom: BorderSide(
                              width: 1, color: Colors.grey.shade400)),
                      children: properties,
                    )),
                Container(
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(),
                ),
                SizedBox(
                  height: 100,
                )
              ],
            ),
          ),
        ));
  }
}
