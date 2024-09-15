import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/cartPage.dart';
import 'package:naliv_delivery/shared/bottomBar.dart';
import '../globals.dart' as globals;
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/searchPage.dart';
import 'package:naliv_delivery/shared/cartButton.dart';
import 'package:naliv_delivery/shared/itemCards.dart';
import 'package:provider/provider.dart';

class CategoryNotifier extends ChangeNotifier {
  // A list that tracks whether a particular page needs refreshing
  //! HARDCODED CAPPED AT 100 PAGES. I hope we will never have that many pages
  List<bool> _needsRefresh = List.generate(
    100,
    (index) {
      return false;
    },
  );

  bool getNeedsRefresh(int index) {
    return _needsRefresh[index];
  }

  void triggerRefresh(int index) {
    _needsRefresh[index] = true;
    notifyListeners();
  }

  void resetRefresh(int index) {
    _needsRefresh[index] = false;
  }
}

class CategoryPage extends StatefulWidget {
  const CategoryPage(
      {super.key,
      required this.categoryId,
      required this.categoryName,
      required this.categories,
      required this.business,
      required this.user});
  final String categoryId;
  final String categoryName;
  final List<dynamic> categories;
  final Map<dynamic, dynamic> business;
  final Map user;
  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  @override
  Widget build(BuildContext context) {
    Size _size = MediaQuery.sizeOf(context);
    return ChangeNotifierProvider(
      create: (_) => CategoryNotifier(),
      child: ParentCategoryPage(
        business: widget.business,
        categories: widget.categories,
        categoryId: widget.categoryId,
        categoryName: widget.categoryName,
        user: widget.user,
        size: _size,
      ),
    );
  }
}

class ParentCategoryPage extends StatefulWidget {
  const ParentCategoryPage(
      {super.key,
      required this.categoryId,
      required this.categoryName,
      required this.categories,
      required this.business,
      required this.user,
      required this.size});
  final String categoryId;
  final String categoryName;
  final List<dynamic> categories;
  final Map<dynamic, dynamic> business;
  final Map user;
  final Size size;

  @override
  State<ParentCategoryPage> createState() => _ParentCategoryPageState();
}

class _ParentCategoryPageState extends State<ParentCategoryPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int initialIndexTabbar = 0;
  List<Map<String, dynamic>> categoriesWidgetList = [];
  late TabController _tabController;

  void toggleDrawer() async {
    if (_scaffoldKey.currentState!.isEndDrawerOpen) {
      _scaffoldKey.currentState!.closeEndDrawer();
    } else {
      _scaffoldKey.currentState!.openEndDrawer();
    }
  }

  void getCategoriesWidgetList(double width) {
    categoriesWidgetList.clear();
    for (int i = 0; i < widget.categories.length; i++) {
      if (widget.categories[i]["category_id"] == widget.categoryId) {
        initialIndexTabbar = i;
      }
      categoriesWidgetList.add({
        "widget": ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: width * 0.6,
          ),
          child: Text(
            widget.categories[i]["name"],
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: "Raleway",
              fontVariations: <FontVariation>[FontVariation('wght', 700)],
            ),
          ),
        ),
        "category_id": widget.categories[i]["category_id"]
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      vsync: this,
      length: widget.categories.length,
      initialIndex: widget.categories.indexWhere(
        (element) => element["category_id"].toString() == widget.categoryId,
      ),
    );
    getCategoriesWidgetList(widget.size.width);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      key: _scaffoldKey,
      floatingActionButtonLocation: FloatingActionButtonLocation.endContained,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 35 * globals.scaleParam),
        child: SizedBox(
          width: 200 * globals.scaleParam,
          height: 165 * globals.scaleParam,
          child: FloatingActionButton(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(15),
              ),
            ),
            child: Icon(
              size: 70 * globals.scaleParam,
              Icons.shopping_basket_rounded,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return CartPage(
                      business: widget.business,
                      user: widget.user,
                    );
                  },
                ),
              ).then(
                (value) {
                  if (value != null) {
                    if (value) {
                      print("REFRESHING");
                      Provider.of<CategoryNotifier>(context, listen: false)
                          .triggerRefresh(_tabController.index);
                    }
                  }
                },
              );
            },
          ),
        ),
      ),
      appBar: AppBar(
        toolbarHeight: 105 * globals.scaleParam,
        bottom: PreferredSize(
          preferredSize:
              Size(MediaQuery.sizeOf(context).width, 85 * globals.scaleParam),
          child: TabBar(
            controller: _tabController,
            tabAlignment: TabAlignment.start,
            physics: const BouncingScrollPhysics(),
            labelPadding: EdgeInsets.symmetric(
                horizontal: 10 * globals.scaleParam,
                vertical: 10 * globals.scaleParam),
            labelStyle: TextStyle(
              fontSize: 38 * globals.scaleParam,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            unselectedLabelColor:
                Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            isScrollable: true,
            tabs:
                categoriesWidgetList.map((e) => e["widget"] as Widget).toList(),
          ),
        ),
        actions: [
          Builder(builder: (context) => const SizedBox()),
        ], // Important: removes endDrawer button form appbar
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20 * globals.scaleParam),
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
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  Flexible(
                    flex: 3,
                    fit: FlexFit.tight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.business["name"],
                          maxLines: 1,
                          style: TextStyle(
                              fontSize: 40 * globals.scaleParam,
                              fontFamily: "MontserratAlternates"),
                        ),
                        Text(
                          widget.business["address"],
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 32 * globals.scaleParam,
                            fontFamily: "Raleway",
                            fontVariations: <FontVariation>[
                              FontVariation('wght', 600)
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    flex: 4,
                    fit: FlexFit.tight,
                    child: TextButton(
                      onPressed: () {
                        // Navigator.push(context, MaterialPageRoute(
                        //   builder: (context) {
                        //     return SearchPage(
                        //       business: widget.business,
                        //     );
                        //   },
                        // ));
                        Navigator.push(
                          context,
                          globals.getPlatformSpecialRoute(
                            SearchPage(
                                business: widget.business,
                                category_id:
                                    categoriesWidgetList[initialIndexTabbar]
                                        ["category_id"]),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.white.withOpacity(0)),
                      child: Container(
                        decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.1),
                            borderRadius:
                                BorderRadius.all(Radius.circular(10))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Spacer(
                              flex: 3,
                            ),
                            Text(
                              "Найти",
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 30 * globals.scaleParam,
                                color: Colors.black,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.all(20 * globals.scaleParam),
                              child: Icon(
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
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (int j = 0; j < widget.categories.length; j++)
            CategoryPageList(
              categoryId: categoriesWidgetList[j]["category_id"].toString(),
              business: widget.business,
              index: j,
              user: widget.user,
            )
        ],
      ),
    );
  }
}

class FilterBar extends StatefulWidget {
  const FilterBar({super.key});

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: Text("Фильтр"),
          automaticallyImplyLeading: false,
          floating: true,
          actions: [TextButton(onPressed: () {}, child: Text("Применить"))],
        ),
      ],
    );
  }
}

class CategoryPageList extends StatefulWidget {
  const CategoryPageList({
    super.key,
    required this.categoryId,
    required this.business,
    required this.index,
    required this.user,
  });

  final String categoryId;
  final Map<dynamic, dynamic> business;
  final int index;
  final Map user;

  @override
  State<CategoryPageList> createState() => _CategoryPageListState();
}

class _CategoryPageListState extends State<CategoryPageList>
    with SingleTickerProviderStateMixin<CategoryPageList> {
  late bool _isLastPage;
  late int _pageNumber;
  late bool _error;
  late bool _loading;
  final int _numberOfPostsPerRequest = 30;
  late List<Map<String, dynamic>> _items;
  final int _nextPageTrigger = 3;
  List children_categories = [];
  void updateDataAmount(List newCart, int index) {
    _items[index]["cart"] = newCart;
  }

  Future<void> _getItems() async {
    try {
      Map? responseList = await getItemsMain(
          _pageNumber, widget.business["business_id"], "", widget.categoryId);
      if (responseList != null) {
        List<dynamic> itemList = responseList["items"];
        // List<dynamic> itemList = responseList.map((data) => Item(data)).toList();

        setState(() {
          children_categories = responseList["c_children"] ?? [];

          _isLastPage = itemList.length < _numberOfPostsPerRequest;
          _loading = false;
          _pageNumber = _pageNumber + 1;
          _items.addAll(itemList.map((e) => e));
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
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _pageNumber = 0;
    _items = [];
    _isLastPage = false;
    _loading = true;
    _error = false;
    _getItems();
  }

  @override
  Widget build(BuildContext context) {
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
    return Consumer<CategoryNotifier>(
      builder: (context, notifier, child) {
        // Check if this category needs to be refreshed
        if (notifier.getNeedsRefresh(widget.index)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _pageNumber = 0;
              _items = [];
              _isLastPage = false;
              _loading = true;
              _error = false;
              _getItems();
            });
            // Reset the refresh state
            notifier.resetRefresh(widget.index);
          });
        }
        return Stack(
          children: [
            Container(
              color: Colors.grey.shade100,
            ),
            CustomScrollView(
              slivers: [
                children_categories.isNotEmpty
                    ? SliverAppBar(
                        shadowColor: Colors.transparent,
                        backgroundColor: Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        floating: true,
                        toolbarHeight: globals.scaleParam * 130,
                        automaticallyImplyLeading: false,
                        titleSpacing: 0,
                        // actions: [
                        //   IconButton(onPressed: () {}, icon: Icon(Icons.sort))
                        // ],
                        title: LayoutBuilder(
                          builder: (context, constraints) {
                            return Container(
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(
                                          30 * globals.scaleParam),
                                      bottomRight: Radius.circular(
                                          30 * globals.scaleParam))),
                              alignment: Alignment.bottomLeft,
                              height: globals.scaleParam * 130,
                              padding: EdgeInsets.symmetric(
                                  vertical: 15 * globals.scaleParam),
                              width: constraints.maxWidth,
                              child: ListView.builder(
                                primary: false,
                                shrinkWrap: true,
                                itemCount: children_categories.length,
                                scrollDirection: Axis.horizontal,
                                itemBuilder: (context, index) {
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => CategoryPage(
                                            categoryId:
                                                children_categories[index]
                                                        ["category_id"]
                                                    .toString(),
                                            categoryName:
                                                children_categories[index]
                                                    ["name"],
                                            categories: children_categories,
                                            business: widget.business,
                                            user: widget.user,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      height: globals.scaleParam * 20,
                                      decoration: BoxDecoration(
                                          color: Colors.white,
                                          boxShadow: [
                                            BoxShadow(
                                                color: Colors.grey.shade200,
                                                blurRadius: 3)
                                          ],
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(
                                                  45 * globals.scaleParam))),
                                      alignment: Alignment.center,
                                      padding: EdgeInsets.symmetric(
                                          vertical: 5 * globals.scaleParam,
                                          horizontal: 25 * globals.scaleParam),
                                      margin: EdgeInsets.all(
                                          10 * globals.scaleParam),
                                      child: Text(
                                        children_categories[index]["name"],
                                        style: TextStyle(
                                          fontFamily: "Raleway",
                                          fontVariations: <FontVariation>[
                                            FontVariation('wght', 600)
                                          ],
                                          fontSize: globals.scaleParam * 30,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ))
                    : SliverToBoxAdapter(),
                _items.length > 1
                    ? SliverList.builder(
                        addAutomaticKeepAlives: false,
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
                                ),
                              );
                            }
                          }
                          final Map<String, dynamic> item = _items[index];
                          return ItemCardListTile(
                            itemId: item["item_id"],
                            element: item,
                            categoryId: "",
                            categoryName: "",
                            scroll: 0,
                            business: widget.business,
                            index: index,
                            categoryPageUpdateData: updateDataAmount,
                          );
                        },
                      )
                    : SliverToBoxAdapter(
                        child: Container(
                          height: MediaQuery.sizeOf(context).height * 0.8,
                          alignment: Alignment.center,
                          child: Text(
                            "Категория пуста",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 52 * globals.scaleParam,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200 * globals.scaleParam,
                  ),
                )
              ],
            ),
          ],
        );
      },
    );
  }
}
