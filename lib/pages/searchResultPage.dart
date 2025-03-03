import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/cartPage.dart';
import 'package:naliv_delivery/shared/ItemCard2.dart';
import 'package:naliv_delivery/shared/bottomBar.dart';
// import 'package:naliv_delivery/shared/itemCards.dart';
import 'package:flutter/cupertino.dart';

class SearchResultPage extends StatefulWidget {
  const SearchResultPage(
      {super.key, required this.business, required this.search});
  final Map<dynamic, dynamic> business;
  final String search;
  @override
  State<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage> {
  List _items = [];
  void updateDataAmount(List newCart, int index) {
    _items[index]["cart"] = newCart;
  }

  Future<void> _getItems() async {
    await getItemsSearch(
      widget.business["business_id"],
      widget.search,
    ).then((value) {
      setState(() {
        _items = value["items"];
      });
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // floatingActionButton: Column(
      //   mainAxisAlignment: MainAxisAlignment.end,
      //   crossAxisAlignment: CrossAxisAlignment.end,
      //   children: [
      //     Padding(
      //       padding: EdgeInsets.all(10),
      //       child: FloatingActionButton(
      //         backgroundColor: Colors.deepOrange,
      //         foregroundColor: Colors.white,
      //         onPressed: () {
      //           Navigator.push(
      //             context,
      //             CupertinoPageRoute(
      //               builder: (context) {
      //                 return PreLoadCartPage(
      //                   business: widget.business,
      //                 );
      //               },
      //             ),
      //           );
      //         },
      //         child: Icon(Icons.shopping_cart_checkout),
      //       ),
      //     ),
      //     // context.mounted ? BottomBar() : Container(),
      //   ],
      // ),
      backgroundColor: Color(0xFF121212),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.black,
            surfaceTintColor: Colors.black,
            floating: false,
            pinned: true,
            centerTitle: false,
            title: Text("Результаты поиска"),
          ),
          _items.length == 0
              ? SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text("Ничего не найдено"),
                    ),
                  ),
                )
              : SliverToBoxAdapter(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        childAspectRatio: 8 / 12,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        crossAxisCount: 2),
                    primary: false,
                    shrinkWrap: true,
                    itemCount: _items.length,
                    itemBuilder: (context, index2) {
                      final Map<String, dynamic> item = _items[index2];

                      return ItemCard2(
                        item: item,
                        business: widget.business,
                      );
                    },
                  ),
                )
        ],
      ),
    );
  }
}
