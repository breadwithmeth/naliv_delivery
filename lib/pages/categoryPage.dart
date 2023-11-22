import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/bottomMenu.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/addressesPage.dart';
import 'package:naliv_delivery/pages/productPage.dart';
import 'package:naliv_delivery/shared/buyButton.dart';
import 'package:naliv_delivery/shared/likeButton.dart';

import '../misc/colors.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage(
      {super.key,
      required this.category_id,
      required this.category_name,
      required this.scroll});
  final String category_id;
  final String? category_name;
  final double scroll;
  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  Widget items = Container();
  Map filters = {};
  List properties = [];
  List<PropertyItem> propertiesWidget = [];
  List<BrandItem> brandsWidget = [];
  List<ManufacturerItem> manufacturersWidget = [];
  List<CountryItem> countriesWidget = [];

  List<GestureDetector> itemsWidget = [];

  List<Widget> propertyWidget = [];

  ScrollController _sc = ScrollController();

  Map selectedFilters = {};

  TextEditingController search = TextEditingController();

  int page = 0;

  List itemsL = [];

  Widget loadingScreen = Container();

  Future<void> _getItems() async {
    print("==================");
    setState(() {
      items = Container();
    });
    List _items;
    if (selectedFilters.isEmpty) {
      // _items = await getItems(category_id: widget.category_id, page: page);
      // _items = await getItems(page: page, category_id: widget.category_id);
      _items = await getItems(widget.category_id, page);
    } else {
      _items =
          await getItems(widget.category_id, page, filters: selectedFilters);
    }

    setState(() {
      itemsL.addAll(_items);
    });

    setState(() {
      page += 1;
    });

    // List<GestureDetector> _itemsWidget = [];
    // for (var i = 0; i < _items.length; i++) {
    //   Map<String, dynamic> element = _items[i];
    //   // _itemsWidget.add();
    // }
    // _items.forEach((element) {
    //   // _itemsWidget.add(GestureDetector(
    //   //   key: Key(element["item_id"]),
    //   //   child: ItemCard(
    //   //     item_id: element["item_id"],
    //   //     element: element,
    //   //     category_id: widget.category_id,
    //   //     category_name: widget.category_name!,
    //   //     scroll: 0,
    //   //   ),
    //   //   onTap: () {
    //   //     Navigator.push(
    //   //       context,
    //   //       MaterialPageRoute(
    //   //           builder: (context) => ProductPage(
    //   //                 item_id: element["item_id"],
    //   //                 returnWidget: CategoryPage(
    //   //                   category_id: widget.category_id,
    //   //                   category_name: widget.category_name,
    //   //                   scroll: widget.scroll,
    //   //                 ),
    //   //               )),
    //   //     ).then((value) {
    //   //       updateItemCard(itemsWidget.indexWhere(
    //   //                 (_gd) => _gd.key == Key(element["item_id"])));
    //   //       print("индекс");

    //   //       print(itemsWidget
    //   //           .indexWhere((_gd) => _gd.key == Key(element["item_id"])));
    //   //       print("индекс");
    //   //       setState(() {
    //   //         itemsWidget[itemsWidget.indexWhere(
    //   //                 (_gd) => _gd.key == Key(element["item_id"]))] =
    //   //             GestureDetector();
    //   //       });
    //   //     });
    //   //   },
    //   // ));
    // });
    // // List <GestureDetector> tempItems = [];
    // // _itemsWidget.forEach((element) {
    // //     itemsWidget.add(element);
    // //   });
    // setState(() {
    //   itemsWidget.addAll(_itemsWidget);
    //   print(itemsWidget);
    //   // items = ListView(
    //   //   controller: _sc,
    //   //   children: _itemsWidget,
    //   // );
    //   // _sc.animateTo(widget.scroll,
    //   //     duration: Duration(seconds: 1), curve: Curves.bounceIn);
    // });
  }

  Future<void> _getFilters() async {
    Map _filters = await getFilters(widget.category_id);
    List _properties = _filters["properties"];

    List<PropertyItem> _propertiesWidget = [];

    List<BrandItem> _brandsWidget = [];

    List<ManufacturerItem> _manufacturersWidget = [];
    List<CountryItem> _countriesWidget = [];

    _properties.forEach((element) {
      element["propertyItems"] = element["amounts"].split("|");
    });
    _filters["properties"] = _properties;

    _properties.forEach((element) {
      element["propertyItems"].forEach((el) {
        _propertiesWidget
            .add(PropertyItem(property_id: element["property_id"], value: el));
      });
    });

    _filters["brands"].forEach((element) {
      _brandsWidget
          .add(BrandItem(brand_id: element["brand_id"], name: element["name"]));
    });

    _filters["manufacturers"].forEach((element) {
      _manufacturersWidget.add(ManufacturerItem(
          manufacturer_id: element["manufacturer_id"], name: element["name"]));
    });

    _filters["countries"].forEach((element) {
      _countriesWidget.add(CountryItem(
          country_id: element["country_id"], name: element["name"]));
    });

    setState(() {
      filters = _filters;
      properties = _properties;
      propertiesWidget = _propertiesWidget;
      brandsWidget = _brandsWidget;
      countriesWidget = _countriesWidget;
      manufacturersWidget = _manufacturersWidget;
    });
  }

  void setFilters() {
    print(properties);
    List<Widget> _propertyWidget = [];

    properties.forEach((element) {
      print(element);
      _propertyWidget.add(Container(
        width: MediaQuery.of(context).size.width * 0.8,
        margin: EdgeInsets.symmetric(vertical: 5),
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.all(Radius.circular(20))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              element["name"],
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            Wrap(
              spacing: 5,
              children: [
                for (int i = 0; i < propertiesWidget.length; i++) ...[
                  if (propertiesWidget[i].property_id ==
                      element["property_id"]) ...[propertiesWidget[i]]
                ]
              ],
            )
          ],
        ),
      ));
    });

    setState(() {
      propertyWidget = _propertyWidget;
    });
  }

  void _applyFilters() {
    Map _selectedFilters = {};
    Map<String, List> _properties = {};
    List _manufacturers = [];
    List _countries = [];
    List _brands = [];

    if (propertiesWidget.length > 0) {
      propertiesWidget.forEach((element) {
        if (element.isSelected) {
          if (_properties[element.property_id] == null) {
            _properties[element.property_id] = [];
          }
          _properties[element.property_id]!.add(element.value);
        }
      });
    }

    if (manufacturersWidget.length > 0) {
      manufacturersWidget.forEach((element) {
        if (element.isSelected) {
          _manufacturers.add((element.manufacturer_id));
        }
      });
    }

    if (brandsWidget.length > 0) {
      brandsWidget.forEach((element) {
        if (element.isSelected) {
          _brands.add((element.brand_id));
        }
      });
    }

    if (countriesWidget.length > 0) {
      countriesWidget.forEach((element) {
        if (element.isSelected) {
          _countries.add((element.country_id));
        }
      });
    }

    if (_brands.length > 0) {
      _selectedFilters["brands"] = _brands;
    }

    if (_countries.length > 0) {
      _selectedFilters["countries"] = _countries;
      ;
    }

    if (_manufacturers.length > 0) {
      _selectedFilters["manufacturers"] = _manufacturers;
    }

    if (_properties.length > 0) {
      _selectedFilters["properties"] = _properties;
    }
    print(_selectedFilters);
    setState(() {
      selectedFilters = _selectedFilters;
    });

    print(selectedFilters);

    _getItems();
    Navigator.pop(context);
    _getFilters();
  }

  _scrollListener() {
    if (_sc.position.pixels > _sc.position.maxScrollExtent - 10) {
      setState(() {
        loadingScreen = Center(
          child: Container(
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.white.withOpacity(0.5),
                        offset: Offset(4, 4),
                        spreadRadius: 5,
                        blurRadius: 5)
                  ]),
              width: 100,
              height: 100,
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator()),
        );
      });
      print("=========");

      _getItems().then(((value) {
        setState(() {
          loadingScreen = Container();
        });
      }));
    }
  }

  @override
  void initState() {
    print(widget.category_id);

    // TODO: implement initState
    super.initState();
    _getItems();
    _getFilters();
    _sc = ScrollController();
    _sc.addListener(_scrollListener);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        top: true,
        child: Stack(
          children: [
            Scaffold(
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
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (context) {
                                return BottomMenu(
                                  page: 0,
                                );
                              }));
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
                                  widget.category_name ?? "",
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
                                  scrollPadding: EdgeInsets.all(0),
                                  controller: search,
                                  onFieldSubmitted: (search) {
                                    if (search.isNotEmpty) {
                                      print(search);
                                      setState(() {
                                        selectedFilters["search"] = search;
                                      });
                                    }
                                    _getItems();
                                  },
                                  style: TextStyle(fontSize: 20),
                                  textAlignVertical: TextAlignVertical.top,
                                  decoration: InputDecoration(
                                      contentPadding: EdgeInsets.all(10),
                                      suffix: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          GestureDetector(
                                            child: Icon(Icons.search),
                                            onTap: () {
                                              if (search.text.isNotEmpty) {
                                                print(search);
                                                setState(() {
                                                  selectedFilters["search"] =
                                                      search.text;
                                                });
                                              }
                                              _getItems();
                                            },
                                          ),
                                          GestureDetector(
                                            child: Icon(Icons.cancel),
                                            onTap: () {
                                              setState(() {
                                                search.text = "";
                                                selectedFilters = {};
                                              });

                                              _getItems();
                                            },
                                          ),
                                        ],
                                      ),
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
                                      floatingLabelBehavior:
                                          FloatingLabelBehavior.never,
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
                                  onPressed: () {
                                    print(_sc.position);
                                    setFilters();
                                    showDialog(
                                      useSafeArea: false,
                                      barrierColor: Colors.transparent,
                                      context: context,
                                      builder: (context) => Dialog(
                                          shape: RoundedRectangleBorder(),
                                          shadowColor: Colors.black38,
                                          backgroundColor:
                                              Colors.white.withOpacity(0.9),
                                          child: Container(
                                            padding: EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: Colors.transparent,
                                            ),
                                            clipBehavior: Clip.hardEdge,
                                            height: MediaQuery.of(context)
                                                    .size
                                                    .height *
                                                0.7,
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(
                                                  sigmaX: 5, sigmaY: 5),
                                              child: Container(
                                                color: Colors.transparent,
                                                height: MediaQuery.of(context)
                                                        .size
                                                        .height *
                                                    0.7,
                                                child: SingleChildScrollView(
                                                    child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        Text(
                                                          "Фильтры",
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.black,
                                                              fontSize: 22,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700),
                                                        ),
                                                        IconButton(
                                                            onPressed: () {
                                                              Navigator.pop(
                                                                  context);
                                                            },
                                                            icon: Icon(
                                                                Icons.close))
                                                      ],
                                                    ),
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: propertyWidget,
                                                    ),
                                                    Container(
                                                      width:
                                                          MediaQuery.of(context)
                                                                  .size
                                                                  .width *
                                                              0.8,
                                                      margin:
                                                          EdgeInsets.symmetric(
                                                              vertical: 5),
                                                      padding:
                                                          EdgeInsets.all(10),
                                                      decoration: BoxDecoration(
                                                          color: Colors
                                                              .grey.shade100,
                                                          borderRadius:
                                                              BorderRadius.all(
                                                                  Radius
                                                                      .circular(
                                                                          20))),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            "Бренды",
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .black,
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700),
                                                          ),
                                                          Wrap(
                                                              spacing: 5,
                                                              children:
                                                                  brandsWidget)
                                                        ],
                                                      ),
                                                    ),
                                                    Container(
                                                      width:
                                                          MediaQuery.of(context)
                                                                  .size
                                                                  .width *
                                                              0.8,
                                                      margin:
                                                          EdgeInsets.symmetric(
                                                              vertical: 5),
                                                      padding:
                                                          EdgeInsets.all(10),
                                                      decoration: BoxDecoration(
                                                          color: Colors
                                                              .grey.shade100,
                                                          borderRadius:
                                                              BorderRadius.all(
                                                                  Radius
                                                                      .circular(
                                                                          20))),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            "Производители",
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .black,
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700),
                                                          ),
                                                          Wrap(
                                                              spacing: 5,
                                                              children:
                                                                  manufacturersWidget)
                                                        ],
                                                      ),
                                                    ),
                                                    Container(
                                                      width:
                                                          MediaQuery.of(context)
                                                                  .size
                                                                  .width *
                                                              0.8,
                                                      margin:
                                                          EdgeInsets.symmetric(
                                                              vertical: 5),
                                                      padding:
                                                          EdgeInsets.all(10),
                                                      decoration: BoxDecoration(
                                                          color: Colors
                                                              .grey.shade100,
                                                          borderRadius:
                                                              BorderRadius.all(
                                                                  Radius
                                                                      .circular(
                                                                          20))),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            "Страны",
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .black,
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700),
                                                          ),
                                                          Wrap(
                                                              spacing: 5,
                                                              children:
                                                                  countriesWidget)
                                                        ],
                                                      ),
                                                    ),
                                                    ElevatedButton(
                                                        onPressed: () {
                                                          _applyFilters();
                                                        },
                                                        child: Row(
                                                          children: [
                                                            Container(
                                                              padding:
                                                                  EdgeInsets
                                                                      .all(5),
                                                              child: Text(
                                                                  "Подтвердить"),
                                                            )
                                                          ],
                                                        ))
                                                  ],
                                                )),
                                              ),
                                            ),
                                          )),
                                    );
                                  },
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
                body:

                    // ListView(
                    //   controller: _sc,
                    //   children: itemsWidget,
                    // )

                    ListView.builder(
                  controller: _sc,
                  itemCount: itemsL.length,
                  itemBuilder: (context, index) => GestureDetector(
                    key: Key(itemsL[index]["item_id"]),
                    child: ItemCard(
                      item_id: itemsL[index]["item_id"],
                      element: itemsL[index],
                      category_id: widget.category_id,
                      category_name: widget.category_name!,
                      scroll: 0,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ProductPage(
                                  item_id: itemsL[index]["item_id"],
                                  returnWidget: CategoryPage(
                                    category_id: widget.category_id,
                                    category_name: widget.category_name,
                                    scroll: widget.scroll,
                                  ),
                                )),
                      ).then((value) {
                        print("===================OFFSET===================");
                        double _currentsc = _sc.offset;
                        print(_currentsc);
                        _getItems();
                        _sc.animateTo(20,
                            duration: Duration(microseconds: 300),
                            curve: Curves.bounceIn);
                        // updateItemCard(itemsWidget
                        //     .indexWhere((_gd) => _gd.key == Key(element["item_id"])));
                        // print("индекс");

                        // print(itemsWidget
                        //     .indexWhere((_gd) => _gd.key == Key(element["item_id"])));
                        // print("индекс");
                        // setState(() {
                        //   // itemsWidget[itemsWidget.indexWhere(
                        //   //         (_gd) => _gd.key == Key(element["item_id"]))] =
                        //   //     GestureDetector();
                        // });
                      });
                    },
                  ),
                )),
            loadingScreen
          ],
        ));
  }
}

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
  late BuyButton _buyButton;
  late int chack;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    setState(() {
      element = widget.element;
      _buyButton = BuyButton(element: element);
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
        properties_t.add(WidgetSpan(
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
      });
      setState(() {
        propertiesWidget = properties_t;
      });
    }
  }

  Future<void> refreshItemCard() async {
    Map<String, dynamic>? _element = await getItem(widget.element["item_id"]);
    print(_element);
    this.setState(() {
      element["name"] = "123";
      element = _element!;
      _buyButton = BuyButton(element: _element);
    });
  }

  @override
  Widget build(BuildContext context) {
    chack = widget.chack;
    return Container(
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
                'https://naliv.kz/img/' + element["photo"],
                width: MediaQuery.of(context).size.width * 0.4,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                      alignment: Alignment.center,
                      width: MediaQuery.of(context).size.width * 0.4,
                      height: MediaQuery.of(context).size.width * 0.4,
                      child: Container(
                        child: CircularProgressIndicator(),
                        width: 20,
                        height: 20,
                      ));
                },
              ),
              SizedBox(
                width: 10,
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
                            element["country"] != null
                                ? WidgetSpan(
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
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(10))),
                                  ))
                                : TextSpan()
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
                        _buyButton,
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
    );
  }
}

class PropertyItem extends StatefulWidget {
  PropertyItem({super.key, required this.property_id, required this.value});
  String property_id;
  String value;
  bool isSelected = false;
  @override
  State<PropertyItem> createState() => _PropertyItemState();
}

class _PropertyItemState extends State<PropertyItem> {
  late String value;
  late String property_id;
  bool _isSelected = false;
  void _select() {
    if (widget.isSelected == true && _isSelected == true) {
      widget.isSelected = false;
      setState(() {
        _isSelected = false;
      });
    } else if (widget.isSelected == false && _isSelected == false) {
      widget.isSelected = true;
      setState(() {
        _isSelected = true;
      });
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    setState(() {
      value = widget.value;
      property_id = widget.property_id;
    });
    print(value);
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
        style: ElevatedButton.styleFrom(
            padding: EdgeInsets.all(5),
            backgroundColor: widget.isSelected ? Colors.black : Colors.grey),
        onPressed: () {
          _select();
        },
        child: Text(widget.value));
  }
}

class BrandItem extends StatefulWidget {
  BrandItem({super.key, required this.brand_id, required this.name});
  String brand_id;
  String name;
  bool isSelected = false;

  @override
  State<BrandItem> createState() => _BrandItemState();
}

class _BrandItemState extends State<BrandItem> {
  bool _isSelected = false;
  late String name;
  late String brand_id;
  void _select() {
    if (widget.isSelected == true && _isSelected == true) {
      widget.isSelected = false;
      setState(() {
        _isSelected = false;
      });
    } else if (widget.isSelected == false && _isSelected == false) {
      widget.isSelected = true;
      setState(() {
        _isSelected = true;
      });
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    setState(() {
      name = widget.name;
      brand_id = widget.brand_id;
    });
    print(name);
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
        style: ElevatedButton.styleFrom(
            padding: EdgeInsets.all(5),
            backgroundColor: widget.isSelected ? Colors.black : Colors.grey),
        onPressed: () {
          _select();
        },
        child: Text(widget.name));
  }
}

class CountryItem extends StatefulWidget {
  CountryItem({super.key, required this.country_id, required this.name});
  String country_id;
  String name;
  bool isSelected = false;

  @override
  State<CountryItem> createState() => _CountryItemState();
}

class _CountryItemState extends State<CountryItem> {
  bool _isSelected = false;
  late String name;
  late String country_id;
  void _select() {
    if (widget.isSelected == true && _isSelected == true) {
      widget.isSelected = false;
      setState(() {
        _isSelected = false;
      });
      print("Здесь он развен");
    } else if (widget.isSelected == false && _isSelected == false) {
      widget.isSelected = true;
      setState(() {
        _isSelected = true;
      });
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    setState(() {
      name = widget.name;
      country_id = widget.country_id;
    });
    print(name);
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
        style: ElevatedButton.styleFrom(
            padding: EdgeInsets.all(5),
            backgroundColor: widget.isSelected ? Colors.black : Colors.grey),
        onPressed: () {
          _select();
        },
        child: Text(widget.name));
  }
}

class ManufacturerItem extends StatefulWidget {
  ManufacturerItem(
      {super.key, required this.manufacturer_id, required this.name});
  String manufacturer_id;
  String name;
  bool isSelected = false;

  @override
  State<ManufacturerItem> createState() => _ManufacturerItemState();
}

class _ManufacturerItemState extends State<ManufacturerItem> {
  bool _isSelected = false;
  late String name;
  late String manufacturer_id;
  void _select() {
    if (widget.isSelected == true && _isSelected == true) {
      widget.isSelected = false;
      setState(() {
        _isSelected = false;
      });
    } else if (widget.isSelected == false && _isSelected == false) {
      widget.isSelected = true;
      setState(() {
        _isSelected = true;
      });
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    setState(() {
      name = widget.name;
      manufacturer_id = widget.manufacturer_id;
    });
    print(name);
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
        style: ElevatedButton.styleFrom(
            padding: EdgeInsets.all(5),
            backgroundColor: widget.isSelected ? Colors.black : Colors.grey),
        onPressed: () {
          _select();
        },
        child: Text(widget.name));
  }
}
