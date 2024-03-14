import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:naliv_delivery/bottomMenu.dart';
import 'package:naliv_delivery/misc/api.dart';
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

  int _categoryViewMode = 0;

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
    List items1;
    if (selectedFilters.isEmpty) {
      // _items = await getItems(category_id: widget.category_id, page: page);
      // _items = await getItems(page: page, category_id: widget.category_id);
      items1 = await getItems(widget.category_id, page);
    } else {
      items1 =
          await getItems(widget.category_id, page, filters: selectedFilters);
    }

    setState(() {
      itemsL.addAll(items1);
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
    Map filters = await getFilters(widget.category_id);
    List properties = filters["properties"];

    List<PropertyItem> propertiesWidget = [];

    List<BrandItem> brandsWidget = [];

    List<ManufacturerItem> manufacturersWidget = [];
    List<CountryItem> countriesWidget = [];

    for (var element in properties) {
      element["propertyItems"] = element["amounts"].split("|");
    }
    filters["properties"] = properties;

    for (var element in properties) {
      element["propertyItems"].forEach((el) {
        propertiesWidget
            .add(PropertyItem(property_id: element["property_id"], value: el));
      });
    }

    filters["brands"].forEach((element) {
      brandsWidget
          .add(BrandItem(brand_id: element["brand_id"], name: element["name"]));
    });

    filters["manufacturers"].forEach((element) {
      manufacturersWidget.add(ManufacturerItem(
          manufacturer_id: element["manufacturer_id"], name: element["name"]));
    });

    filters["countries"].forEach((element) {
      countriesWidget.add(CountryItem(
          country_id: element["country_id"], name: element["name"]));
    });

    setState(() {
      filters = filters;
      properties = properties;
      propertiesWidget = propertiesWidget;
      brandsWidget = brandsWidget;
      countriesWidget = countriesWidget;
      manufacturersWidget = manufacturersWidget;
    });
  }

  void setFilters() {
    print(properties);
    List<Widget> propertyWidget = [];

    for (var element in properties) {
      print(element);
      propertyWidget.add(Container(
        width: MediaQuery.of(context).size.width * 0.8,
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: const BorderRadius.all(Radius.circular(20))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              element["name"],
              style: const TextStyle(
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
    }

    setState(() {
      propertyWidget = propertyWidget;
    });
  }

  void _applyFilters() {
    Map selectedFilters = {};
    Map<String, List> properties = {};
    List manufacturers = [];
    List countries = [];
    List brands = [];

    if (propertiesWidget.isNotEmpty) {
      for (var element in propertiesWidget) {
        if (element.isSelected) {
          if (properties[element.property_id] == null) {
            properties[element.property_id] = [];
          }
          properties[element.property_id]!.add(element.value);
        }
      }
    }

    if (manufacturersWidget.isNotEmpty) {
      for (var element in manufacturersWidget) {
        if (element.isSelected) {
          manufacturers.add((element.manufacturer_id));
        }
      }
    }

    if (brandsWidget.isNotEmpty) {
      for (var element in brandsWidget) {
        if (element.isSelected) {
          brands.add((element.brand_id));
        }
      }
    }

    if (countriesWidget.isNotEmpty) {
      for (var element in countriesWidget) {
        if (element.isSelected) {
          countries.add((element.country_id));
        }
      }
    }

    if (brands.isNotEmpty) {
      selectedFilters["brands"] = brands;
    }

    if (countries.isNotEmpty) {
      selectedFilters["countries"] = countries;
    }

    if (manufacturers.isNotEmpty) {
      selectedFilters["manufacturers"] = manufacturers;
    }

    if (properties.isNotEmpty) {
      selectedFilters["properties"] = properties;
    }
    print(selectedFilters);
    setState(() {
      selectedFilters = selectedFilters;
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
                        offset: const Offset(4, 4),
                        spreadRadius: 5,
                        blurRadius: 5)
                  ]),
              width: 100,
              height: 100,
              padding: const EdgeInsets.all(20),
              child: const CircularProgressIndicator()),
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

  Widget _getCategoriesWithLayoutMode() {
    switch (_categoryViewMode) {
      case 0:
        return _listViewCategories();
        break;
      case 1:
        return Placeholder();
        break;
      case 2:
        return Placeholder();
        break;
      default:
        throw Exception("Category view mode out of range");
    }
  }

  Icon _getCategoriesIconWithLayout() {
    switch (_categoryViewMode) {
      case 0:
        return Icon(
          Icons.view_list_rounded,
          color: Colors.black,
          key: Key('0'),
        );
        break;
      case 1:
        return Icon(
          Icons.grid_view_rounded,
          color: Colors.black,
          key: Key('1'),
        );
        break;
      case 2:
        return Icon(
          Icons.square_rounded,
          color: Colors.black,
          key: Key('2'),
        );
        break;
      default:
        throw Exception("Category view mode out of range");
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
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            scrolledUnderElevation: 0.0,
            backgroundColor: Colors.white,
            toolbarHeight: 120,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: Container(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 15,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (context) {
                                return  BottomMenu(
                                );
                              }));
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.black,
                                ),
                                // Text(
                                //   widget.category_name ?? "",
                                //   style: const TextStyle(
                                //       fontWeight: FontWeight.w700,
                                //       fontSize: 20,
                                //       color: Colors.black),
                                // )
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 6,
                          child: TextFormField(
                            scrollPadding: const EdgeInsets.all(0),
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
                            style: const TextStyle(fontSize: 20),
                            textAlignVertical: TextAlignVertical.top,
                            decoration: InputDecoration(
                                contentPadding: const EdgeInsets.all(10),
                                suffix: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    GestureDetector(
                                      child: const Icon(Icons.search),
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
                                      child: const Icon(Icons.cancel),
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
                                label: const Row(
                                  children: [
                                    Icon(
                                      Icons.search,
                                      color: gray1,
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(left: 5),
                                      child: Text(
                                        "Найти...",
                                        style: TextStyle(
                                            color: gray1,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    )
                                  ],
                                ),
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.never,
                                border: const OutlineInputBorder(
                                    borderSide: BorderSide.none,
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(30))),
                                focusedBorder: const OutlineInputBorder(
                                    borderSide: BorderSide.none,
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(30))),
                                focusColor: gray1,
                                hoverColor: gray1,
                                fillColor: Colors.grey.shade200,
                                filled: true,
                                isDense: true),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
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
                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 10),
                          child: Text(
                            widget.category_name ?? "",
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                                color: Colors.black),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            print(_sc.position);
                            setFilters();
                            showDialog(
                              useSafeArea: false,
                              barrierColor: Colors.transparent,
                              context: context,
                              builder: (context) => Dialog(
                                  shape: const RoundedRectangleBorder(),
                                  shadowColor: Colors.black38,
                                  backgroundColor:
                                      Colors.white.withOpacity(0.9),
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: const BoxDecoration(
                                      color: Colors.transparent,
                                    ),
                                    clipBehavior: Clip.hardEdge,
                                    height: MediaQuery.of(context).size.height *
                                        0.7,
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                          sigmaX: 5, sigmaY: 5),
                                      child: Container(
                                        color: Colors.transparent,
                                        height:
                                            MediaQuery.of(context).size.height *
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
                                                  CrossAxisAlignment.center,
                                              children: [
                                                const Text(
                                                  "Фильтры",
                                                  style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 22,
                                                      fontWeight:
                                                          FontWeight.w700),
                                                ),
                                                IconButton(
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                    },
                                                    icon:
                                                        const Icon(Icons.close))
                                              ],
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: propertyWidget,
                                            ),
                                            Container(
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.8,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 5),
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius:
                                                      const BorderRadius.all(
                                                          Radius.circular(20))),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    "Бренды",
                                                    style: TextStyle(
                                                        color: Colors.black,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w700),
                                                  ),
                                                  Wrap(
                                                      spacing: 5,
                                                      children: brandsWidget)
                                                ],
                                              ),
                                            ),
                                            Container(
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.8,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 5),
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius:
                                                      const BorderRadius.all(
                                                          Radius.circular(20))),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    "Производители",
                                                    style: TextStyle(
                                                        color: Colors.black,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w700),
                                                  ),
                                                  Wrap(
                                                      spacing: 5,
                                                      children:
                                                          manufacturersWidget)
                                                ],
                                              ),
                                            ),
                                            Container(
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.8,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 5),
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius:
                                                      const BorderRadius.all(
                                                          Radius.circular(20))),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    "Страны",
                                                    style: TextStyle(
                                                        color: Colors.black,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w700),
                                                  ),
                                                  Wrap(
                                                      spacing: 5,
                                                      children: countriesWidget)
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
                                                        const EdgeInsets.all(5),
                                                    child: const Text(
                                                        "Подтвердить"),
                                                  )
                                                ],
                                              ),
                                            )
                                          ],
                                        )),
                                      ),
                                    ),
                                  )),
                            );
                          },
                          child: Expanded(
                            flex: 1,
                            child: Icon(
                              Icons.filter_list_rounded,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: TextButton(
                          onPressed: () => {
                            if (_categoryViewMode != 2)
                              {
                                setState(() {
                                  _categoryViewMode += 1;
                                })
                              }
                            else
                              {
                                setState(() {
                                  _categoryViewMode = 0;
                                })
                              }
                          },
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) {
                              return ScaleTransition(
                                scale: animation,
                                child: child,
                              );
                            },
                            child: _getCategoriesIconWithLayout(),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
          body: _getCategoriesWithLayoutMode(),
          // ListView(
          //   controller: _sc,
          //   children: itemsWidget,
          // )
        ),
        loadingScreen
      ],
    );
  }

  ListView _listViewCategories() {
    return ListView.builder(
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
            double currentsc = _sc.offset;
            print(currentsc);
            _getItems();
            _sc.animateTo(20,
                duration: const Duration(microseconds: 300),
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
    );
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
      _buyButton = BuyButton(element: element!);
    });
  }

  @override
  Widget build(BuildContext context) {
    chack = widget.chack;
    return Container(
      width: MediaQuery.of(context).size.width,
      margin: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          const SizedBox(
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
                      child: const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(),
                      ));
                },
              ),
              const SizedBox(
                width: 10,
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    child: RichText(
                      text: TextSpan(
                          style: const TextStyle(
                              textBaseline: TextBaseline.alphabetic,
                              fontSize: 20,
                              color: Colors.black),
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
                                  ))
                                : const TextSpan()
                          ]),
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  RichText(
                      text: TextSpan(
                          style: const TextStyle(color: Colors.black),
                          children: propertiesWidget)),
                  const SizedBox(
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
                                  style: const TextStyle(
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
                            style: const TextStyle(
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
                  const SizedBox(
                    height: 15,
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        _buyButton,
                        Container(
                          alignment: Alignment.centerRight,
                          width: MediaQuery.of(context).size.width * 0.1,
                          child: LikeButton(
                            is_liked: element["is_liked"],
                            item_id: element["item_id"],
                          ),
                        )
                      ],
                    ),
                  )
                ],
              )
            ],
          ),
          const SizedBox(
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

// class ItemCardTile extends StatefulWidget {
//   const ItemCardTile({super.key});

//   @override
//   State<ItemCardTile> createState() => _ItemCardTileState();
// }

// class _ItemCardTileState extends State<ItemCardTile> {
//   Map<String, dynamic> element = {};
//   List<InlineSpan> propertiesWidget = [];
//   late BuyButton _buyButton;
//   late int chack;
//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//     setState(() {
//       element = widget.element;
//       _buyButton = BuyButton(element: element);
//     });
//     getProperties();
//   }

//   void getProperties() {
//     if (widget.element["properties"] != null) {
//       List<InlineSpan> propertiesT = [];
//       List<String> properties = widget.element["properties"].split(",");
//       print(properties);
//       for (var element in properties) {
//         List temp = element.split(":");
//         propertiesT.add(WidgetSpan(
//             child: Row(
//           children: [
//             Text(
//               temp[1],
//               style: const TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w700,
//                   color: Colors.black),
//             ),
//             Image.asset(
//               "assets/property_icons/${temp[0]}.png",
//               width: 14,
//               height: 14,
//             ),
//             const SizedBox(
//               width: 10,
//             )
//           ],
//         )));
//       }
//       setState(() {
//         propertiesWidget = propertiesT;
//       });
//     }
//   }

//   Future<void> refreshItemCard() async {
//     Map<String, dynamic>? element = await getItem(widget.element["item_id"]);
//     print(element);
//     setState(() {
//       element!["name"] = "123";
//       element = element!;
//       _buyButton = BuyButton(element: element!);
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     chack = widget.chack;
//     return Container(
//       width: MediaQuery.of(context).size.width,
//       margin: const EdgeInsets.all(10),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         mainAxisSize: MainAxisSize.max,
//         children: [
//           const SizedBox(
//             height: 20,
//           ),
//           Row(
//             mainAxisSize: MainAxisSize.max,
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               Image.network(
//                 'https://naliv.kz/img/' + element["photo"],
//                 width: MediaQuery.of(context).size.width * 0.4,
//                 fit: BoxFit.cover,
//                 errorBuilder: (context, error, stackTrace) {
//                   return Container(
//                       alignment: Alignment.center,
//                       width: MediaQuery.of(context).size.width * 0.4,
//                       height: MediaQuery.of(context).size.width * 0.4,
//                       child: const SizedBox(
//                         width: 20,
//                         height: 20,
//                         child: CircularProgressIndicator(),
//                       ));
//                 },
//               ),
//               const SizedBox(
//                 width: 10,
//               ),
//               Column(
//                 mainAxisAlignment: MainAxisAlignment.start,
//                 mainAxisSize: MainAxisSize.max,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   SizedBox(
//                     width: MediaQuery.of(context).size.width * 0.5,
//                     child: RichText(
//                       text: TextSpan(
//                           style: const TextStyle(
//                               textBaseline: TextBaseline.alphabetic,
//                               fontSize: 20,
//                               color: Colors.black),
//                           children: [
//                             TextSpan(text: element["name"]),
//                             element["country"] != null
//                                 ? WidgetSpan(
//                                     child: Container(
//                                     padding: const EdgeInsets.all(5),
//                                     decoration: BoxDecoration(
//                                         color: Colors.grey.shade200,
//                                         borderRadius: const BorderRadius.all(
//                                             Radius.circular(10))),
//                                     child: Text(
//                                       element["country"] ?? "",
//                                       style: const TextStyle(
//                                           color: Colors.black,
//                                           fontWeight: FontWeight.w600),
//                                     ),
//                                   ))
//                                 : const TextSpan()
//                           ]),
//                     ),
//                   ),
//                   const SizedBox(
//                     height: 10,
//                   ),
//                   RichText(
//                       text: TextSpan(
//                           style: const TextStyle(color: Colors.black),
//                           children: propertiesWidget)),
//                   const SizedBox(
//                     height: 10,
//                   ),
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       element["prev_price"] != null
//                           ? Row(
//                               children: [
//                                 Text(
//                                   element['prev_price'] ?? "",
//                                   style: const TextStyle(
//                                       color: Colors.black,
//                                       fontWeight: FontWeight.w500,
//                                       fontSize: 14,
//                                       decoration: TextDecoration.lineThrough),
//                                 ),
//                                 Text(
//                                   "₸",
//                                   style: TextStyle(
//                                       color: Colors.grey.shade600,
//                                       fontWeight: FontWeight.w500,
//                                       fontSize: 14),
//                                 )
//                               ],
//                             )
//                           : Container(),
//                       Row(
//                         children: [
//                           Text(
//                             element['price'] ?? "",
//                             style: const TextStyle(
//                                 color: Colors.black,
//                                 fontWeight: FontWeight.w600,
//                                 fontSize: 24),
//                           ),
//                           Text(
//                             "₸",
//                             style: TextStyle(
//                                 color: Colors.grey.shade600,
//                                 fontWeight: FontWeight.w600,
//                                 fontSize: 24),
//                           )
//                         ],
//                       ),
//                     ],
//                   ),
//                   const SizedBox(
//                     height: 15,
//                   ),
//                   SizedBox(
//                     width: MediaQuery.of(context).size.width * 0.5,
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       mainAxisSize: MainAxisSize.max,
//                       children: [
//                         _buyButton,
//                         Container(
//                           alignment: Alignment.centerRight,
//                           width: MediaQuery.of(context).size.width * 0.1,
//                           child: LikeButton(
//                             is_liked: element["is_liked"],
//                             item_id: element["item_id"],
//                           ),
//                         )
//                       ],
//                     ),
//                   )
//                 ],
//               )
//             ],
//           ),
//           const SizedBox(
//             height: 25,
//           ),
//           Container(
//             height: 1,
//             color: Colors.grey.shade200,
//           )
//         ],
//       ),
//     );
// }

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
            padding: const EdgeInsets.all(5),
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
            padding: const EdgeInsets.all(5),
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
            padding: const EdgeInsets.all(5),
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
            padding: const EdgeInsets.all(5),
            backgroundColor: widget.isSelected ? Colors.black : Colors.grey),
        onPressed: () {
          _select();
        },
        child: Text(widget.name));
  }
}
