import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:dynamic_tabbar/dynamic_tabbar.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class CategoriesPage2 extends StatefulWidget {
  const CategoriesPage2(
      {super.key, required this.categories, required this.business});
  final List categories;
  final Map business;

  @override
  State<CategoriesPage2> createState() => _CategoriesPage2State();
}

class _CategoriesPage2State extends State<CategoriesPage2>
    with TickerProviderStateMixin {
  var _scrollController;
  late TabController _tabController;
  @override
  void initState() {
    _scrollController = ScrollController();
    _tabController = TabController(vsync: this, length: 2);
    super.initState();
  }

  _pageView() {
    return ListView.builder(
      itemCount: 20,
      itemBuilder: (BuildContext context, int index) {
        return Card(
          child: Container(
            padding: EdgeInsets.all(16.0),
            child: Text('List Item $index'),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverSafeArea(
              sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                    child: Container(
                  alignment: Alignment.center,
                  // width: 200,
                  height: 70,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    primary: false,
                    shrinkWrap: true,
                    itemCount: widget.categories.length,
                    itemBuilder: (context, index) {
                      return Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(20)),
                              border: Border.all(color: Colors.grey.shade700)),
                          margin: EdgeInsets.all(10),
                          padding: EdgeInsets.all(10),
                          child: FittedBox(
                            fit: BoxFit.fitHeight,
                            child: Text(
                              widget.categories[index]['name'],
                              textScaler: TextScaler.linear(1),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ));
                    },
                  ),
                ))
              ],
            ),
          ))
        ],
      ),
    );
  }
}

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  late TabController _categoryTabController;
  final List<dynamic> _tabInfoList = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:SuperListView.builder(
  itemCount: 1000,
  itemBuilder: (context, index) {
    return ListTile(title: Text('Item $index'));
  },
)
    );
  }
}
