import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/productPage.dart';
import 'package:naliv_delivery/shared/itemCards.dart';

import 'package:naliv_delivery/misc/api.dart';

class FavPage extends StatefulWidget {
  const FavPage({super.key});

  @override
  State<FavPage> createState() => _FavPageState();
}

class _FavPageState extends State<FavPage> with SingleTickerProviderStateMixin {
  late AnimationController animController;
  List items = [];

  Future<void> _getItems() async {
    List _items = await getLiked();
    List<Widget> itemsWidget = [];
    for (var element in items) {
      itemsWidget.add(GestureDetector(
        key: Key(element["item_id"]),
        child: ItemCard(
          item_id: element["item_id"],
          element: element,
          category_id: "",
          category_name: "",
          scroll: 0,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ProductPage(item_id: element["item_id"])),
          ).then((value) {
            print("===================OFFSET===================");

            // updateItemCard(itemsWidget
            //     .indexWhere((_gd) => _gd.key == Key(element["item_id"])));
            // print("индекс");

            // print(itemsWidget
            //     .indexWhere((_gd) => _gd.key == Key(element["item_id"])));
            // print("индекс");
            // setState(() {
            //   // itemsWidget[itemsWidget.indexWhere(
            //   //         (_gd) => _gd.key == Key(element["item_id"]))] =
            //   //     GestureDetector();
            // });
          });
        },
      ));
    }
    setState(() {
      items = _items;
    });
  }

  void _setAnimationController() {
    animController = BottomSheet.createAnimationController(this);

    animController.duration = const Duration(milliseconds: 450);
    animController.reverseDuration = const Duration(milliseconds: 450);
    animController.drive(CurveTween(curve: Curves.bounceInOut));
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getItems();
    _setAnimationController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: items.isNotEmpty
          ? ListView.builder(
              primary: false,
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                // final item = items[index];
                return GestureDetector(
                  key: Key(items[index]["item_id"]),
                  child: ItemCard(
                    item_id: items[index]["item_id"],
                    element: items[index],
                    category_id: "",
                    category_name: "",
                    scroll: 0,
                  ),
                  onTap: () {
                    showModalBottomSheet(
                      transitionAnimationController: animController,
                      context: context,
                      clipBehavior: Clip.antiAlias,
                      useSafeArea: true,
                      isScrollControlled: true,
                      builder: (context) {
                        return ProductPage(item_id: items[index]["item_id"]);
                      },
                    );
                  },
                );
              },
            )
          : const Center(
              child: Text(
                "Вы пока не добавили товары в этом магазине",
                style: TextStyle(color: Colors.black),
              ),
            ),
    );
  }
}
