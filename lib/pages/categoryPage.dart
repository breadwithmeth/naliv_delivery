import 'dart:io';

import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/productPage.dart';
import 'package:naliv_delivery/shared/buyButton.dart';
import 'package:naliv_delivery/shared/likeButton.dart';

import '../misc/colors.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key, required this.category_id});
  final String category_id;
  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  Widget items = Container();

  Future<void> _getItems() async {
    Map _items = await getItems(widget.category_id);
    List<Widget> _itemsWidget = [];
    _items["items"].forEach((element) {
      _itemsWidget.add(
        ItemCard(element: element),
      );
    });
    setState(() {
      items = ListView(
        children: _itemsWidget,
      );
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getItems();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        top: true,
        child: Scaffold(
            appBar: AppBar(
                elevation: 10,
                toolbarHeight: 120,
                automaticallyImplyLeading: false,
                titleSpacing: 0,
                title: Container(
                  padding: EdgeInsets.all(10),
                  child: Column(
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.arrow_back_ios,
                              color: Colors.black,
                            ),
                            Text(
                              "КАТЕГОРИЯ",
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                  color: Colors.black),
                            )
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 5,
                      ),
                      // Row(
                      //   mainAxisAlignment: MainAxisAlignment.start,
                      //   children: [
                      //     Text(
                      //       "Караганда ",
                      //       style: TextStyle(fontSize: 12, color: gray1),
                      //     ),
                      //     Icon(
                      //       Icons.arrow_forward_ios,
                      //       size: 6,
                      //     ),
                      //     Text(
                      //       " Караганда",
                      //       style: TextStyle(fontSize: 12, color: gray1),
                      //     )
                      //   ],
                      // ),
                      // SizedBox(
                      //   height: 10,
                      // ),
                      Row(
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.65,
                            child: TextFormField(
                              style: TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                  label: Row(
                                    children: [
                                      Icon(
                                        Icons.search,
                                        color: gray1,
                                      ),
                                      Text(
                                        "Поиск",
                                        style: TextStyle(color: gray1),
                                      )
                                    ],
                                  ),
                                  border: OutlineInputBorder(
                                      borderSide: BorderSide.none,
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(30))),
                                  focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide.none,
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(30))),
                                  focusColor: gray1,
                                  hoverColor: gray1,
                                  fillColor: Colors.grey.shade200,
                                  filled: true,
                                  isDense: true),
                            ),
                          ),
                          TextButton(
                              onPressed: () {},
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.settings,
                                    color: Colors.black,
                                  ),
                                  Text(
                                    "Фильтры",
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: Colors.black),
                                  )
                                ],
                              ))
                        ],
                      )
                    ],
                  ),
                )),
            body: items));
  }
}

class ItemCard extends StatefulWidget {
  const ItemCard({super.key, required this.element});
  final Map<String, dynamic> element;
  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  Map<String, dynamic> element = {};
  List<InlineSpan> propertiesWidget = [];

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
      List<InlineSpan> properties_t = [];
      List<String> properties = widget.element["properties"].split(",");
      print(properties);
      properties.forEach((element) {
        List temp = element.split(":");
        properties_t.add(WidgetSpan(child: Row(
          children: [
            Text(temp[1], style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black),),
            Image.asset("assets/property_icons/${temp[0]}.png", width: 14, height: 14,),
            SizedBox(width: 10,)
          ],
        )));
      });
      setState(() {
        propertiesWidget = properties_t;
      });
    }
  }

  Future<void> refreshItemCard() async {
    if (element["item_id"] != null) {
      Map<String, dynamic>? _element = await getItem(widget.element["item_id"]);
      setState(() {
        element = _element!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Container(
        width: MediaQuery.of(context).size.width,
        margin: EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            SizedBox(
              height: 20,
            ),
            Row(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.network(
                  element["photo"],
                  width: MediaQuery.of(context).size.width * 0.4,
                  fit: BoxFit.cover,
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.width * 0.5,
                      child: RichText(
                        text: TextSpan(
                            style: TextStyle(
                                textBaseline: TextBaseline.alphabetic,
                                fontSize: 20,
                                color: Colors.black),
                            children: [
                              TextSpan(text: element["name"]),
                              WidgetSpan(
                                  child: Container(
                                child: Text(
                                  element["country"] ?? "",
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600),
                                ),
                                padding: EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(10))),
                              ))
                            ]),
                      ),
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    RichText(
                    
                    text: TextSpan(
                    style: TextStyle(color: Colors.black),
                    children: propertiesWidget)),
                    SizedBox(
                      height: 10,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        element["prev_price"] != null
                            ? Row(
                                children: [
                                  Text(
                                    element['prev_price'] ?? "",
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                        decoration: TextDecoration.lineThrough),
                                  ),
                                  Text(
                                    "₸",
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14),
                                  )
                                ],
                              )
                            : Container(),
                        Row(
                          children: [
                            Text(
                              element['price'] ?? "",
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 24),
                            ),
                            Text(
                              "₸",
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 24),
                            )
                          ],
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 15,
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width * 0.5,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          BuyButton(element: element),
                          Container(
                            alignment: Alignment.centerRight,
                            child: LikeButton(
                              is_liked: element["is_liked"],
                              item_id: element["item_id"],
                            ),
                            width: MediaQuery.of(context).size.width * 0.1,
                          )
                        ],
                      ),
                    )
                  ],
                )
              ],
            ),
            SizedBox(
              height: 25,
            ),
            Container(
              height: 1,
              color: Colors.grey.shade200,
            )
          ],
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ProductPage(
                    item_id: element["item_id"],
                  )),
        );
      },
    );
  }
}
