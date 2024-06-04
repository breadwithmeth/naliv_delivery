import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/cartPage.dart';
import 'package:naliv_delivery/pages/productPage.dart';
import 'package:naliv_delivery/pages/searchPage.dart';
import 'package:naliv_delivery/shared/cartButton.dart';
import 'package:naliv_delivery/shared/itemCards.dart';
import 'package:shimmer/shimmer.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage(
      {super.key,
      required this.categoryId,
      required this.categoryName,
      required this.categories,
      required this.business});
  final String categoryId;
  final String categoryName;
  final List<dynamic> categories;
  final Map<dynamic, dynamic> business;
  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int initialIndexTabbar = 0;
  List<Map<String, dynamic>> categoriesWidgetList = [];

  void toggleDrawer() async {
    if (_scaffoldKey.currentState!.isEndDrawerOpen) {
      _scaffoldKey.currentState!.closeEndDrawer();
    } else {
      _scaffoldKey.currentState!.openEndDrawer();
    }
  }

  void getCategoriesWidgetList() {
    for (int i = 0; i < widget.categories.length; i++) {
      if (widget.categories[i]["category_id"] == widget.categoryId) {
        initialIndexTabbar = i;
      }
      categoriesWidgetList.add({
        "widget": Text(
          widget.categories[i]["name"],
        ),
        "category_id": widget.categories[i]["category_id"]
      });
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getCategoriesWidgetList();
  }

  @override
  Widget build(BuildContext context) {
    double screenSize = MediaQuery.of(context).size.width;

    return DefaultTabController(
      initialIndex: initialIndexTabbar,
      length: widget.categories.length,
      child: Scaffold(
        key: _scaffoldKey,
        floatingActionButton: CartButton(
          business: widget.business,
        ),
        appBar: AppBar(
          bottom: TabBar(
            tabAlignment: TabAlignment.start,
            physics: const BouncingScrollPhysics(),
            labelPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            labelStyle: TextStyle(
              fontSize: 32 * (screenSize / 720),
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onBackground,
            ),
            unselectedLabelColor:
                Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
            isScrollable: true,
            tabs:
                categoriesWidgetList.map((e) => e["widget"] as Widget).toList(),
          ),
          actions: [
            Builder(builder: (context) => const SizedBox()),
          ], // Important: removes endDrawer button form appbar
          automaticallyImplyLeading: false,
          // toolbarHeight: 90,
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          Navigator.maybePop(context);
                        },
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                    Flexible(
                      flex: 4,
                      fit: FlexFit.tight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) {
                              return SearchPage(
                                category_id: widget.categoryId,
                                business: widget.business,
                              );
                            },
                          ));
                        },
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.white.withOpacity(0)),
                        child: Container(
                          decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.1),
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(10))),
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
                                  color: Colors.black,
                                ),
                              ),
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
                // Row(
                //   mainAxisSize: MainAxisSize.max,
                //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //   children: [
                //     Flexible(
                //       flex: 4,
                //       child: Text(
                //         widget.category_name,
                //         style: const TextStyle(
                //           fontWeight: FontWeight.w700,
                //           fontSize: 20,
                //           color: Colors.black,
                //         ),
                //       ),
                //     ),
                //     Flexible(
                //       flex: 2,
                //       child: Row(
                //         mainAxisAlignment: MainAxisAlignment.end,
                //         children: [
                //           Flexible(
                //             child: IconButton(
                //               padding: EdgeInsets.zero,
                //               onPressed: () {
                //                 // TODO: Make sort by price (expencive first or cheap first, something like that)
                //               },
                //               icon: const Icon(Icons.swap_vert_rounded),
                //             ),
                //           ),
                //           Flexible(
                //             child: IconButton(
                //               padding: EdgeInsets.zero,
                //               onPressed: () {
                //                 toggleDrawer();
                //               },
                //               icon: const Icon(Icons.filter_list_rounded),
                //             ),
                //           ),
                //         ],
                //       ),
                //     ),
                //   ],
                // )
              ],
            ),
          ),
        ),
        endDrawer: Drawer(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          "Фильтры",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            toggleDrawer();
                          },
                          icon: const Icon(Icons.close),
                        )
                      ],
                    ),
                    const SizedBox(
                      height: 15,
                    ),
                    // Column(
                    //   crossAxisAlignment:
                    //       CrossAxisAlignment.start,
                    //   children: propertyWidget,
                    // ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 15),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(10),
                        ),
                      ),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Бренды",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 32 * (screenSize / 720),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              //!!!!!!!!!!!!!!!!!!
                              // Wrap(
                              //   spacing: 5,
                              //   children: brandsWidget,
                              // )
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 15,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 15),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(10),
                        ),
                      ),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Производители",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 32 * (screenSize / 720),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              //!!!!!!!!!!!!!!!!!!
                              // Wrap(
                              //   spacing: 5,
                              //   children: brandsWidget,
                              // )
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 15,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 15),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(10),
                        ),
                      ),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Страны",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 32 * (screenSize / 720),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              //!!!!!!!!!!!!!!!!!!
                              // Wrap(
                              //   spacing: 5,
                              //   children: brandsWidget,
                              // )
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    ElevatedButton(
                      onPressed: () {
                        //!!!!! _applyFilters();
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            child: Text(
                              "Применить",
                              style: TextStyle(
                                fontSize: 32 * (screenSize / 720),
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
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
        body: TabBarView(
          children: [
            for (int j = 0; j < widget.categories.length; j++)
              CategoryPageList(
                categoryId: categoriesWidgetList[j]["category_id"],
                business: widget.business,
              )
          ],
        ),
      ),
    );
  }
}

class Item {
  final Map<String, dynamic> data;

  Item(this.data);
}

class CategoryPageList extends StatefulWidget {
  const CategoryPageList(
      {super.key, required this.categoryId, required this.business});

  final String categoryId;
  final Map<dynamic, dynamic> business;
  @override
  State<CategoryPageList> createState() => _CategoryPageListState();
}

class _CategoryPageListState extends State<CategoryPageList>
    with
        AutomaticKeepAliveClientMixin<CategoryPageList>,
        SingleTickerProviderStateMixin<CategoryPageList> {
  @override
  bool get wantKeepAlive => true;

  late bool _isLastPage;
  late int _pageNumber;
  late bool _error;
  late bool _loading;
  final int _numberOfPostsPerRequest = 30;
  late List<Item> _items;
  final int _nextPageTrigger = 3;
  late final TabController _controller;

  void updateDataAmount(String newDataAmount, int index) {
    setState(() {
      _items[index].data["amount"] = newDataAmount;
    });
  }

  Future<void> _getItems() async {
    try {
      //! TODO: SEND SEARCH PARAMETER TO API
      List? responseList = await getItemsMain(
          _pageNumber, widget.business["business_id"], "", widget.categoryId);
      if (responseList != null) {
        List<Item> itemList = responseList.map((data) => Item(data)).toList();

        setState(() {
          _isLastPage = itemList.length < _numberOfPostsPerRequest;
          _loading = false;
          _pageNumber = _pageNumber + 1;
          _items.addAll(itemList);
        });
        if (itemList.isEmpty) {
          setState(() {
            _isLastPage = true;
          });
        }
      }
    } catch (e) {
      print("error --> $e");
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Widget buildPostsView() {
    if (_items.isEmpty) {
      if (_loading) {
        return const Center(
            child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(),
        ));
      } else if (_error) {
        return Center(child: errorDialog(size: 20));
      }
    }
    return Column(
      children: [
        // TabBar.secondary(
        //   controller: _controller,
        //   tabs: [
        //     Padding(
        //       padding: const EdgeInsets.symmetric(vertical: 8),
        //       child: Text(
        //         "Бутылка",
        //         style: TextStyle(
        //           fontSize: 14,
        //           fontWeight: FontWeight.w500,
        //           color: Colors.black,
        //         ),
        //       ),
        //     ),
        //     Padding(
        //       padding: const EdgeInsets.symmetric(vertical: 8),
        //       child: Text(
        //         "Жестянка",
        //         style: TextStyle(
        //           fontSize: 14,
        //           fontWeight: FontWeight.w500,
        //           color: Colors.black,
        //         ),
        //       ),
        //     ),
        //     // Tab(text: 'Бутылка'),
        //     // Tab(text: 'Жестянная банка'),
        //   ],
        // ),
        Expanded(
          child: ListView.builder(
            itemCount: _items.length + (_isLastPage ? 0 : 1),
            itemBuilder: (context, index) {
              if ((index == _items.length - _nextPageTrigger) &&
                  (!_isLastPage)) {
                _getItems();
              }
              if (index == _items.length) {
                if (_error) {
                  return Center(child: errorDialog(size: 15));
                } else {
                  return const Center(
                      child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  ));
                }
              }
              final Item item = _items[index];
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                key: Key(item.data["item_id"]),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    clipBehavior: Clip.antiAlias,
                    useSafeArea: true,
                    isScrollControlled: true,
                    builder: (context) {
                      return ProductPage(
                        item: item.data,
                        index: index,
                        returnDataAmount: updateDataAmount,
                        business: widget.business,
                      );
                    },
                  );
                },
                child: Column(
                  children: [
                    ItemCardMedium(
                      item_id: item.data["item_id"],
                      element: item.data,
                      category_id: "",
                      category_name: "",
                      scroll: 0,
                    ),
                    _items.length != index
                        ? const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 5,
                            ),
                            child: Divider(
                              height: 0,
                            ),
                          )
                        : Container(),
                    if ((index ==
                            (_items.length + (_isLastPage ? 0 : 1) - 1)) &&
                        (_isLastPage))
                      const SizedBox(
                        height: 95,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget errorDialog({required double size}) {
    return SizedBox(
      height: 180,
      width: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Произошла ошибка при загрузке позиций.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _loading = true;
                _error = false;
                _getItems();
              });
            },
            child: const Text(
              "Перезагрузить",
              style: TextStyle(fontSize: 20, color: Colors.purpleAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 2, vsync: this);
    _pageNumber = 0;
    _items = [];
    _isLastPage = false;
    _loading = true;
    _error = false;
    _getItems();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return buildPostsView();
  }
}
