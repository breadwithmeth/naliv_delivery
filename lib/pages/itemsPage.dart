import 'package:flutter/material.dart';

class ItemsPage extends StatefulWidget {
  const ItemsPage(
      {super.key,
      required this.items,
      required this.selectedCategory,
      required this.categories});
  final Map<String, dynamic> items;
  final int selectedCategory;
  final List categories;

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  List<Widget> _categories = [];
  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    _setCategories();
  }

  _setCategories() {
    for (var i = 0; i < widget.categories.length; i++) {
      _categories.add(
        Container(
          margin: EdgeInsets.only(left: 5, right: 5),
          child: Text(
            widget.categories[i]["name"],
            style: TextStyle(
                color:
                    widget.selectedCategory == i ? Colors.black : Colors.grey),
          ),
        ),
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: widget.categories.length,
        itemBuilder: (context, index) {
          return Container(
              child: NestedScrollView(
                  physics: NeverScrollableScrollPhysics(),
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverOverlapAbsorber(
                          handle:
                              NestedScrollView.sliverOverlapAbsorberHandleFor(
                                  context),
                          sliver: SliverAppBar(
                            pinned: true,
                            expandedHeight: 200.0,
                            flexibleSpace: FlexibleSpaceBar(
                              title: Text('Demo'),
                            ),
                          ))
                    ];
                  },
                  body: SafeArea(
                      child: SingleChildScrollView(
                    physics: ClampingScrollPhysics(),
                    primary: false,
                    child: ListView.builder(
                      // physics: NeverScrollableScrollPhysics(),
                      primary: false,
                      shrinkWrap: true,
                      itemCount: widget.categories.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: EdgeInsets.only(left: 5, right: 5),
                          child: Text(
                            widget.categories[index]["name"],
                            style: TextStyle(
                                fontSize: 233,
                                color: widget.selectedCategory == index
                                    ? Colors.black
                                    : Colors.grey),
                          ),
                        );
                      },
                    ),
                  ))));
        },
      ),
    );
  }
}
