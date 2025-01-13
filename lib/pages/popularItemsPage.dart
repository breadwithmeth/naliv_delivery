import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/shared/itemCards.dart';

class PopularItemsPage extends StatefulWidget {
  const PopularItemsPage({super.key, required this.business});
  final Map<dynamic, dynamic> business;

  @override
  State<PopularItemsPage> createState() => _PopularItemsPageState();
}

class _PopularItemsPageState extends State<PopularItemsPage> {
  List _items = [];
  void updateDataAmount(List newCart, int index) {
    _items[index]["cart"] = newCart;
  }

  Future<void> _getItems() async {
    await getItemsPopular(
      widget.business["business_id"],
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
      backgroundColor: Color(0xFF121212),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.black,
            surfaceTintColor: Colors.black,
            floating: false,
            pinned: true,
            centerTitle: false,
            title: Text("Популярные товары"),
          ),
          SliverList.builder(
            itemCount: _items.length,
            itemBuilder: (context, index) {
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
        ],
      ),
    );
  }
}
