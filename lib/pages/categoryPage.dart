import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/cartPage.dart';
import 'package:naliv_delivery/pages/productPage.dart';
import 'package:naliv_delivery/pages/searchPage.dart';
import 'package:naliv_delivery/shared/itemCards.dart';
import 'package:shimmer/shimmer.dart';

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
  final Duration animDuration = const Duration(milliseconds: 125);
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

  bool isItemsLoadng = false;

  Future<void> _getItems() async {
    print("==================");
    setState(() {
      isItemsLoadng = true;
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
      isItemsLoadng = false;
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
        return const Placeholder();
        break;
      case 2:
        return const Placeholder();
        break;
      default:
        throw Exception("Category view mode out of range");
    }
  }

  Icon _getCategoriesIconWithLayout() {
    switch (_categoryViewMode) {
      case 0:
        return const Icon(
          Icons.view_list_rounded,
          color: Colors.black,
          key: Key('0'),
        );
        break;
      case 1:
        return const Icon(
          Icons.grid_view_rounded,
          color: Colors.black,
          key: Key('1'),
        );
        break;
      case 2:
        return const Icon(
          Icons.square_rounded,
          color: Colors.black,
          key: Key('2'),
        );
        break;
      default:
        throw Exception("Category view mode out of range");
    }
  }

  // void _cacheItemsImages() {
  //   print(
  //       "PRECACHED ITEMS ___(${itemsL.length}) ________________________________");
  //   for (Map item in itemsL) {
  //     if (item["photo"] != null) {
  //       if (item["photo"].toString().isNotEmpty) {
  //         precacheImage(
  //             NetworkImage('https://naliv.kz/img/${item["photo"]}'), context);
  //       }
  //     }
  //   }
  // }

  @override
  void initState() {
    print(widget.category_id);

    // TODO: implement initState
    super.initState();
    _getItems();
    // _getItems().then((value) {
    //   _cacheItemsImages();
    // });

    _getFilters();
    _sc = ScrollController();
    _sc.addListener(_scrollListener);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: SizedBox(
        width: 65,
        height: 65,
        child: FloatingActionButton(
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(3))),
          child: Icon(
            Icons.shopping_basket_rounded,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) {
                  return const CartPage();
                },
              ),
            );
          },
        ),
      ),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 120,
        titleSpacing: 0,
        title: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    flex: 1,
                    child: Builder(
                      builder: (context) {
                        return IconButton(
                          onPressed: () {
                            Navigator.maybePop(context);
                          },
                          icon: const Icon(Icons.arrow_back_rounded),
                        );
                      },
                    ),
                  ),
                  Flexible(
                    flex: 5,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) {
                            return const SearchPage();
                          },
                        ));
                      },
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.white.withOpacity(0)),
                      child: Container(
                        decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.1),
                            borderRadius:
                                const BorderRadius.all(Radius.circular(3))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Spacer(
                              flex: 3,
                            ),
                            const Text(
                              "Найти",
                              style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black),
                            ),
                            // Expanded(
                            //   flex: 2,
                            //   child: Image.network(
                            //     logourl,
                            //     fit: BoxFit.contain,
                            //     frameBuilder: (BuildContext context, Widget child,
                            //         int? frame, bool? wasSynchronouslyLoaded) {
                            //       return Padding(
                            //         padding: const EdgeInsets.all(8.0),
                            //         child: child,
                            //       );
                            //     },
                            //     loadingBuilder: (BuildContext context, Widget child,
                            //         ImageChunkEvent? loadingProgress) {
                            //       return Center(child: child);
                            //     },
                            //   ),
                            // ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              child: const Icon(
                                Icons.search,
                                color: Colors.black,
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
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 25),
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
                          backgroundColor: Colors.white.withOpacity(0.9),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              color: Colors.transparent,
                            ),
                            clipBehavior: Clip.hardEdge,
                            height: MediaQuery.of(context).size.height * 0.7,
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                              child: Container(
                                color: Colors.transparent,
                                height:
                                    MediaQuery.of(context).size.height * 0.7,
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          const Text(
                                            "Фильтры",
                                            style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 22,
                                                fontWeight: FontWeight.w700),
                                          ),
                                          IconButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                              },
                                              icon: const Icon(Icons.close))
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: propertyWidget,
                                      ),
                                      Container(
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.8,
                                        margin: const EdgeInsets.symmetric(
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
                                                  fontWeight: FontWeight.w700),
                                            ),
                                            Wrap(
                                                spacing: 5,
                                                children: brandsWidget)
                                          ],
                                        ),
                                      ),
                                      Container(
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.8,
                                        margin: const EdgeInsets.symmetric(
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
                                                  fontWeight: FontWeight.w700),
                                            ),
                                            Wrap(
                                                spacing: 5,
                                                children: manufacturersWidget)
                                          ],
                                        ),
                                      ),
                                      Container(
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.8,
                                        margin: const EdgeInsets.symmetric(
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
                                                  fontWeight: FontWeight.w700),
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
                                              padding: const EdgeInsets.all(5),
                                              child: const Text("Подтвердить"),
                                            )
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Expanded(
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
                      duration: animDuration,
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
      body: _getCategoriesWithLayoutMode(),
      // ListView(
      //   controller: _sc,
      //   children: itemsWidget,
      // ),
    );
  }

  ListView _listViewCategories() {
    if (isItemsLoadng) {
      return ListView.builder(
          itemCount: 3,
          itemBuilder: (context, index) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height * 0.28,
                  //padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(3)),
                    color: Colors.white,
                  ),
                  child: Shimmer.fromColors(
                    baseColor: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withOpacity(0.05),
                    highlightColor: Theme.of(context).colorScheme.secondary,
                    child: Row(
                      children: [
                        Flexible(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Container(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Flexible(
                          flex: 3,
                          child: Column(
                            children: [
                              Flexible(
                                child: Container(
                                  color: Colors.white,
                                ),
                              ),
                              Flexible(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  child: Container(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Flexible(
                                child: Container(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            );
          });
    } else {
      return ListView.builder(
        controller: _sc,
        itemCount: itemsL.length,
        itemBuilder: (context, index) => GestureDetector(
          key: Key(itemsL[index]["item_id"]),
          onTap: () {
            showModalBottomSheet(
              context: context,
              clipBehavior: Clip.antiAlias,
              useSafeArea: true,
              isScrollControlled: true,
              builder: (context) {
                return ProductPage(item_id: itemsL[index]["item_id"]);
              },
            );
          },
          child: Column(
            children: [
              ItemCardMedium(
                item_id: itemsL[index]["item_id"],
                element: itemsL[index],
                category_id: widget.category_id,
                category_name: widget.category_name!,
                scroll: 0,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
        ),
        // onTap: () {
        //   Navigator.push(
        //     context,
        //     MaterialPageRoute(
        //         builder: (context) => ProductPage(
        //               item_id: itemsL[index]["item_id"],
        //               returnWidget: CategoryPage(
        //                 category_id: widget.category_id,
        //                 category_name: widget.category_name,
        //                 scroll: widget.scroll,
        //               ),
        //             )),
        //   ).then((value) {
        //     print("===================OFFSET===================");
        //     double currentsc = _sc.offset;
        //     print(currentsc);
        //     _getItems();
        //     _sc.animateTo(20,
        //         duration: const Duration(microseconds: 300),
        //         curve: Curves.bounceIn);
        //     // updateItemCard(itemsWidget
        //     //     .indexWhere((_gd) => _gd.key == Key(element["item_id"])));
        //     // print("индекс");

        //     // print(itemsWidget
        //     //     .indexWhere((_gd) => _gd.key == Key(element["item_id"])));
        //     // print("индекс");
        //     // setState(() {
        //     //   // itemsWidget[itemsWidget.indexWhere(
        //     //   //         (_gd) => _gd.key == Key(element["item_id"]))] =
        //     //   //     GestureDetector();
        //     // });
        //   });
        // },
      );
    }
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
