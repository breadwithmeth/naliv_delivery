import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:naliv_delivery/main.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:dynamic_tabbar/dynamic_tabbar.dart';
import 'package:naliv_delivery/pages/cartPage.dart';
import 'package:naliv_delivery/pages/preLoadCartPage.dart';
import 'package:naliv_delivery/pages/preLoadCategoryPage.dart';
import 'package:naliv_delivery/shared/bottomBar.dart';
import 'package:naliv_delivery/shared/itemCards.dart';
import 'package:naliv_delivery/shared/searchWidget.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:expandable_page_view/expandable_page_view.dart';
import 'package:visibility_detector/visibility_detector.dart';

class CategoryPage2 extends StatefulWidget {
  const CategoryPage2(
      {super.key,
      required this.business,
      this.categoryId,
      required this.category,
      required this.items,
      required this.subcategories,
      required this.user,
      required this.priceIncrease});
  final Map<dynamic, dynamic> business;
  final String? categoryId;
  final Map category;
  final List subcategories;
  final List items;
  final bool priceIncrease;

  final Map<String, dynamic> user;

  @override
  State<CategoryPage2> createState() => _CategoryPage2State();
}

class _CategoryPage2State extends State<CategoryPage2>
    with TickerProviderStateMixin, RouteAware {
  final List<GlobalObjectKey> keyList =
      List.generate(100, (index) => GlobalObjectKey(index));
  late TabController _tabController;
  int currentIndex = 0;
  late TabController _categoryTabController;
  final List<dynamic> _tabInfoList = [];
  double currentOffset = 0;
  GlobalKey second = GlobalKey();
  double appbarheight = 120;

  List values = [];
  List properties = [];

  List? searchItems = null;
  List selectedValues = [];

  bool showFilters = false;

  int lowestPrice = 0;
  int highestPrice = 0;

  int rangeLowPrice = 0;
  int rangeHighPrice = 0;

  List items = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
    print("dadasdasasd");
  }

  @override
  void didPopNext() {
    // Covering route was popped off the navigator.
    print("popped");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(context, CupertinoPageRoute(builder: (context) {
        return PreLoadCategoryPage(
          categoryId: widget.categoryId,
          business: widget.business,
          category: widget.category,
          subcategories: widget.subcategories,
          user: widget.user,
        );
      }));
    });
  }

  initPriceRange() {
    int lowestPricet = widget.items[0]["price"];
    int highestPricet = widget.items[0]["price"];
    for (var i in widget.items) {
      if (i["price"] < lowestPricet) {
        lowestPricet = i["price"];
      }
      if (i["price"] > highestPricet) {
        highestPricet = i["price"];
      }
    }

    setState(() {
      lowestPrice = lowestPricet;
      highestPrice = highestPricet;
      rangeLowPrice = lowestPricet;
      rangeHighPrice = highestPricet;
    });
  }

  _getPropertiesForCat() {
    getPropertiesForCategory(widget.categoryId!, widget.business["business_id"])
        .then((value) {
      print(value);
      setState(() {
        values = value!["values"];
        properties = value!["properties"];
      });
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    initPriceRange();
    setState(() {
      items = widget.items;
      _tabController = TabController(
          vsync: this,
          length: widget.subcategories.length,
          initialIndex: currentIndex);
      // _tabController.addListener(() {
      //   _tabController.animateTo(_tabController.index);
      // });
    });

    itemPositionsListener.itemPositions.addListener(() {
      print(currentOffset);
      final positions = itemPositionsListener.itemPositions.value;
      final visibleIndex = positions
          .where((ItemPosition position) => position.itemTrailingEdge > 0)
          .map((ItemPosition position) => position.index)
          .toList();
      if (visibleIndex.isNotEmpty) {
        if (currentIndex != visibleIndex[0]) {
          print(visibleIndex[0]);
          setState(() {
            currentIndex = visibleIndex[0];
          });
          _tabController.animateTo(visibleIndex[0]);
        }
      }
    });
    _getPropertiesForCat();
  }

  final ItemScrollController itemScrollController = ItemScrollController();
  final ScrollOffsetController scrollOffsetController =
      ScrollOffsetController();
  final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();
  final ScrollOffsetListener scrollOffsetListener =
      ScrollOffsetListener.create();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          floatingActionButton: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              searchItems == null
                  ? Container()
                  : Padding(
                      padding: EdgeInsets.all(10),
                      child: FloatingActionButton(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        onPressed: () {
                          setState(() {
                            searchItems = null;
                            selectedValues = [];
                          });
                        },
                        child: Icon(Icons.filter_list_off),
                      ),
                    ),
              Padding(
                padding: EdgeInsets.all(10),
                child: FloatingActionButton(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  onPressed: () {
                    SchedulerBinding.instance.addPostFrameCallback((_) {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) {
                            return PreLoadCartPage(
                              business: widget.business,
                            );
                          },
                        ),
                      );
                    });
                  },
                  child: Icon(Icons.shopping_cart_checkout),
                ),
              ),
              context.mounted ? BottomBar() : Container(),
            ],
          ),
          appBar: AppBar(
            title: Searchwidget(business: widget.business),
            backgroundColor: Colors.black,
            surfaceTintColor: Colors.black,
            bottom: searchItems == null
                ? TabBar(
                    labelColor: Colors.white,
                    indicatorColor: Colors.white,
                    isScrollable: true,
                    controller: _tabController,
                    tabs: [
                        for (var i in widget.subcategories)
                          GestureDetector(
                            onTap: () {
                              itemScrollController.scrollTo(
                                  index: widget.subcategories.indexOf(i),
                                  duration: Durations.medium1);
                            },
                            child: Text(i["name"]),
                          )
                      ])
                : PreferredSize(
                    preferredSize: Size.fromHeight(10), child: Container()),
            actions: [
              IconButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return Dialog.fullscreen(
                          backgroundColor: Colors.black,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      icon: Icon(Icons.close))
                                ],
                              ),
                              ListTile(
                                trailing: Icon(Icons.arrow_upward),
                                title: Text("По возрастанию цены"),
                                onTap: () {
                                  Navigator.pop(context);

                                  Navigator.pushReplacement(context,
                                      CupertinoPageRoute(builder: (context) {
                                    return CategoryPage2(
                                      categoryId: widget.categoryId,
                                      business: widget.business,
                                      category: widget.category,
                                      subcategories: widget.subcategories,
                                      items: widget.items,
                                      user: widget.user,
                                      priceIncrease: true,
                                    );
                                  }));
                                },
                              ),
                              ListTile(
                                trailing: Icon(Icons.arrow_downward),
                                title: Text("По убыванию цены"),
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.pushReplacement(context,
                                      CupertinoPageRoute(builder: (context) {
                                    return CategoryPage2(
                                      categoryId: widget.categoryId,
                                      business: widget.business,
                                      category: widget.category,
                                      subcategories: widget.subcategories,
                                      items: widget.items,
                                      user: widget.user,
                                      priceIncrease: false,
                                    );
                                  }));
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  icon: Icon(Icons.sort)),
              IconButton(
                icon: Icon(Icons.filter_list_rounded),
                onPressed: () {
                  setState(() {
                    showFilters = !showFilters;
                  });
                  // showCupertinoDialog(
                  //   context: context,
                  //   builder: (context) {
                  //     return StatefulBuilder(
                  //       builder: (context, setState) {
                  //         return ;
                  //       },
                  //     );
                  //   },
                  // );
                },
              )
            ],
          ),
          backgroundColor: Colors.black,
          body: searchItems == null
              ? ScrollablePositionedList.builder(
                  shrinkWrap: true,
                  physics: ClampingScrollPhysics(),
                  itemCount: widget.subcategories.length,
                  itemBuilder: (context, index) {
                    List subitems = items.where((element) {
                      return element["category_id"].toString() ==
                          widget.subcategories[index]["category_id"].toString();
                    }).toList();

                    void updateDataAmount(List newCart, int index) {
                      subitems[index]["cart"] = newCart;
                    }

                    if (widget.priceIncrease) {
                      subitems.sort((a, b) {
                        return a["price"].compareTo(b["price"]);
                      });
                    } else {
                      subitems.sort((a, b) {
                        return b["price"].compareTo(a["price"]);
                      });
                    }

                    return subitems.length == 0
                        ? Container()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              VisibilityDetector(
                                key: GlobalKey(),
                                child: Container(
                                  padding: EdgeInsets.all(15),
                                  child: Text(
                                    widget.subcategories[index]["name"],
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                onVisibilityChanged: (info) {
                                  if (currentIndex != index) {
                                    if (info.visibleFraction == 0.5) {
                                      setState(() {
                                        currentIndex = index;
                                      });
                                      _tabController.animateTo(index);
                                    }
                                  }
                                },
                              ),
                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: Color(0xFF121212)),
                                padding: EdgeInsets.all(15),
                                child: ListView.builder(
                                  primary: false,
                                  shrinkWrap: true,
                                  itemCount: subitems.length,
                                  itemBuilder: (context, index2) {
                                    final Map<String, dynamic> item =
                                        subitems[index2];
                                    return rangeLowPrice <= item["price"] &&
                                            item["price"] <= rangeHighPrice
                                        ? (searchItems == null
                                            ? ItemCardListTile(
                                                itemId: item["item_id"],
                                                element: item,
                                                categoryId: "",
                                                categoryName: "",
                                                scroll: 0,
                                                business: widget.business,
                                                index: index2,
                                                categoryPageUpdateData:
                                                    updateDataAmount,
                                              )
                                            : searchItems!.contains(
                                                    item["item_id"].toString())
                                                ? ItemCardListTile(
                                                    itemId: item["item_id"],
                                                    element: item,
                                                    categoryId: "",
                                                    categoryName: "",
                                                    scroll: 0,
                                                    business: widget.business,
                                                    index: index2,
                                                    categoryPageUpdateData:
                                                        updateDataAmount,
                                                  )
                                                : Container())
                                        : Container();
                                  },
                                ),
                              )
                            ],
                          );
                  },
                  itemScrollController: itemScrollController,
                  scrollOffsetController: scrollOffsetController,
                  itemPositionsListener: itemPositionsListener,
                  scrollOffsetListener: scrollOffsetListener,
                )
              : ListView.builder(
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    final Map<String, dynamic> item = widget.items[index];
                    return rangeLowPrice <= item["price"] &&
                            item["price"] <= rangeHighPrice
                        ? (searchItems == null
                            ? ItemCardListTile(
                                itemId: item["item_id"],
                                element: item,
                                categoryId: "",
                                categoryName: "",
                                scroll: 0,
                                business: widget.business,
                                index: index,
                                categoryPageUpdateData:
                                    (List newCart, int index) {
                                  item["cart"] = newCart;
                                },
                              )
                            : searchItems!.contains(item["item_id"].toString())
                                ? ItemCardListTile(
                                    itemId: item["item_id"],
                                    element: item,
                                    categoryId: "",
                                    categoryName: "",
                                    scroll: 0,
                                    business: widget.business,
                                    index: index,
                                    categoryPageUpdateData:
                                        (List newCart, int index) {
                                      item["cart"] = newCart;
                                    },
                                  )
                                : Container())
                        : Container();
                  },
                ),
        ),
        !showFilters
            ? Container()
            : Scaffold(
                appBar: AppBar(
                  backgroundColor: Colors.black,
                  surfaceTintColor: Colors.black,
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          showFilters = false;
                        });
                      },
                    )
                  ],
                ),
                bottomNavigationBar: Container(
                  padding: EdgeInsets.all(10),
                  child: ElevatedButton(
                    onPressed: () {
                      selectedValues.length > 0
                          ? getItemsByPropertiesValues(selectedValues)
                              .then((v) {
                              setState(() {
                                searchItems = v;
                                showFilters = false;
                              });
                            })
                          : setState(() {
                              // searchItems = widget.items;
                              showFilters = false;
                            });
                      // setState(() {
                      //   searchItems = widget.items.where((element) {
                      //     List valuesl = values.where((value) {
                      //       return selectedValues.contains(value["value_id"]);
                      //     }).toList();
                      //     List itemValues = valuesl.where((value) {
                      //       return element["item_id"] == value["item_id"];
                      //     }).toList();
                      //     return itemValues.length == valuesl.length;
                      //   }).toList();
                      //   showFilters = false;
                      // });
                    },
                    child: Text("Применить"),
                  ),
                ),
                body: SingleChildScrollView(
                    // margin: EdgeInsets.only(top: 10, bottom: 1000),
                    child: Column(
                  children: [
                    ElevatedButton(
                        onPressed: () {
                          setState(() {
                            items.sort((a, b) {
                              return a["price"].compareTo(b["price"]);
                            });
                          });
                        },
                        child: Text("Цена")),
                    Divider(
                      color: Colors.white,
                    ),
                    RangeSlider(
                        activeColor: Colors.orange,
                        inactiveColor: Colors.grey,
                        labels: RangeLabels(rangeLowPrice.toString(),
                            rangeHighPrice.toString()),
                        min: lowestPrice.toDouble(),
                        max: highestPrice.toDouble(),
                        values: RangeValues(rangeLowPrice.toDouble(),
                            rangeHighPrice.toDouble()),
                        onChanged: (rv) {
                          setState(() {
                            rangeLowPrice = rv.start.toInt();
                            rangeHighPrice = rv.end.toInt();
                          });
                        }),
                    Text("Цена от: $rangeLowPrice до: $rangeHighPrice"),
                    ListView.builder(
                      primary: false,
                      shrinkWrap: true,
                      itemCount: properties.length,
                      itemBuilder: (context, index) {
                        List valuesl = values.where((value) {
                          return value["property_id"] ==
                              properties[index]["property_id"];
                        }).toList();
                        return valuesl.length == 0
                            ? Container()
                            : Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    border: Border(
                                        bottom: BorderSide(
                                            color: Colors.white, width: 1))),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      properties[index]["name"],
                                      style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Wrap(
                                      direction: Axis.horizontal,
                                      children: [
                                        for (var i in valuesl)
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                if (selectedValues
                                                    .contains(i["value_id"])) {
                                                  selectedValues
                                                      .remove(i["value_id"]);
                                                } else {
                                                  selectedValues
                                                      .add(i["value_id"]);
                                                }
                                              });
                                              print(selectedValues);
                                            },
                                            child: Container(
                                              padding: EdgeInsets.all(10),
                                              margin: EdgeInsets.all(5),
                                              decoration: BoxDecoration(
                                                  color:
                                                      selectedValues.contains(
                                                              i["value_id"])
                                                          ? Colors.white
                                                          : Colors.black,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10)),
                                              child: Text(
                                                i["value"],
                                                style: TextStyle(
                                                    color: valuesl
                                                                .where((val) {
                                                                  return selectedValues
                                                                      .contains(
                                                                          val["value_id"]);
                                                                })
                                                                .toList()
                                                                .length ==
                                                            0
                                                        ? Colors.white
                                                        : Colors.grey.shade900),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    // ListView.builder(
                                    //   primary: false,
                                    //   shrinkWrap: true,
                                    //   itemCount: valuesl.length,
                                    //   itemBuilder: (context, index2) {
                                    //     return Text(valuesl[index2]["value"]);
                                    //   },
                                    // )
                                  ],
                                ),
                              );
                      },
                    ),
                    SizedBox(
                      height: 500,
                    )
                  ],
                )),
              )
      ],
    );
  }
}
