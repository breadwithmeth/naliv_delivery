import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:dynamic_tabbar/dynamic_tabbar.dart';
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
      required this.subcategories});
  final Map<dynamic, dynamic> business;
  final String? categoryId;
  final Map category;
  final List subcategories;
  final List items;
  @override
  State<CategoryPage2> createState() => _CategoryPage2State();
}

class _CategoryPage2State extends State<CategoryPage2>
    with TickerProviderStateMixin {
  final List<GlobalObjectKey> keyList =
      List.generate(100, (index) => GlobalObjectKey(index));
  late TabController _tabController;
  int currentIndex = 0;
  late TabController _categoryTabController;
  final List<dynamic> _tabInfoList = [];
  double currentOffset = 0;
  GlobalKey second = GlobalKey();
  double appbarheight = 120;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    setState(() {
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
    return Scaffold(
      appBar: AppBar(
        title: Searchwidget(business: widget.business),
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.black,
        bottom: TabBar(
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
            ]),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list_rounded),
            onPressed: () {
              Navigator.pushNamed(context, "/cart");
            },
          )
        ],
      ),
      backgroundColor: Colors.black,
      body: ScrollablePositionedList.builder(
        shrinkWrap: true,
        physics: ClampingScrollPhysics(),
        itemCount: widget.subcategories.length,
        itemBuilder: (context, index) {
          List subitems = widget.items.where((element) {
            return element["category_id"] ==
                widget.subcategories[index]["category_id"];
          }).toList();
          void updateDataAmount(List newCart, int index) {
            subitems[index]["cart"] = newCart;
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
                          if (info.visibleFraction == 1) {
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
                          final Map<String, dynamic> item = subitems[index2];

                          return ItemCardListTile(
                            itemId: item["item_id"],
                            element: item,
                            categoryId: "",
                            categoryName: "",
                            scroll: 0,
                            business: widget.business,
                            index: index2,
                            categoryPageUpdateData: updateDataAmount,
                          );
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
      ),
    );
  }
}
