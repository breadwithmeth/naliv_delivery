import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/shared/itemCards.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../globals.dart' as globals;

class StorePage extends StatefulWidget {
  const StorePage({super.key, required this.business});
  final Map business;
  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  bool isLoaded = false;
  Map _store = {};
  List _items = [];
  List _categories = [];
  List _parent_categories = [];
  final ItemScrollController itemScrollController = ItemScrollController();
  final ScrollOffsetController scrollOffsetController =
      ScrollOffsetController();
  final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();
  final ScrollOffsetListener scrollOffsetListener =
      ScrollOffsetListener.create();
  _get() async {
    await getItems2(widget.business["business_id"]).then((store) {
      setState(() {
        _store = store;
        _categories = store["categories"];
      });
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _get();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: EdgeInsets.all(10),
          sliver: SliverToBoxAdapter(
            child: ScrollablePositionedList.builder(
              shrinkWrap: true,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                List items = _categories[index]["items"];
                void updateDataAmount(List newCart, int index) {
                  items[index]["cart"] = newCart;
                }

                return _categories[index]["items"] == null
                    ? Container()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _categories[index]["name"],
                            style: TextStyle(
                                fontSize: 48 * globals.scaleParam,
                                fontVariations: <FontVariation>[
                                  FontVariation('wght', 700)
                                ],
                                color: Colors.black),
                          ),
                          ListView.builder(
                            primary: false,
                            shrinkWrap: true,
                            itemBuilder: (context, index2) {
                              return ListTile(
                                trailing: Image.network(items[index2]["img"]),
                                title: Text(items[index2]["name"]),
                              );
                            },
                            itemCount: items.length,
                          )
                        ],
                      );
              },
              itemScrollController: itemScrollController,
              scrollOffsetController: scrollOffsetController,
              itemPositionsListener: itemPositionsListener,
              scrollOffsetListener: scrollOffsetListener,
            ),
          ),
        )
      ],
    )));
  }
}

// ScrollablePositionedList.builder(
//           itemCount: _parent_categories.length,
//           itemBuilder: (context, index) {
//             return ListTile(
//               title: Text(_parent_categories[index]["name"]),
//             );
//           },
//         )
