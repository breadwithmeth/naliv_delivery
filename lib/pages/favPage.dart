import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/cartPage.dart';
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
  final Duration animDuration = const Duration(milliseconds: 125);
  List items = [];

  Future<void> _getItems() async {
    List _items = await getLiked();
    // List<Widget> itemsWidget = [];

    // for (var element in items) {
    // void updateDataAmount(String newDataAmount, int index) {
    //   setState(() {
    //     element["amount"] = newDataAmount;
    //   });
    // }

    //   itemsWidget.add(GestureDetector(
    //     behavior: HitTestBehavior.opaque,
    //     key: Key(element["item_id"]),
    //     child: ItemCardMedium(
    //       item_id: element["item_id"],
    //       element: element,
    //       category_id: "",
    //       category_name: "",
    //       scroll: 0,
    //     ),
    //     onTap: () {
    //       Navigator.push(
    //         context,
    //         MaterialPageRoute(
    //           builder: (context) => ProductPage(
    //             item: element,
    //             index: items.indexOf(element),
    //             returnDataAmount: updateDataAmount,
    //           ),
    //         ),
    //       ).then((value) {
    //         print("===================OFFSET===================");

    //         // updateItemCard(itemsWidget
    //         //     .indexWhere((_gd) => _gd.key == Key(element["item_id"])));
    //         // print("индекс");

    //         // print(itemsWidget
    //         //     .indexWhere((_gd) => _gd.key == Key(element["item_id"])));
    //         // print("индекс");
    //         // setState(() {
    //         //   // itemsWidget[itemsWidget.indexWhere(
    //         //   //         (_gd) => _gd.key == Key(element["item_id"]))] =
    //         //   //     GestureDetector();
    //         // });
    //       });
    //     },
    //   ));
    // }
    setState(() {
      items = _items;
    });
  }

  void _setAnimationController() {
    animController = BottomSheet.createAnimationController(this);

    animController.duration = animDuration;
    animController.reverseDuration = const Duration(milliseconds: 450);
    animController.drive(CurveTween(curve: Curves.bounceInOut));
  }

  void updateDataAmount(String newDataAmount, int index) {
    setState(() {
      items[index]["amount"] = newDataAmount;
    });
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
      floatingActionButton: SizedBox(
        width: 65,
        height: 65,
        child: FloatingActionButton(
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10))),
          child: Icon(
            Icons.shopping_basket_rounded,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) {
                  return const CartPage();
                },
              ),
            );
          },
        ),
      ),
      appBar: AppBar(
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Избранное",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      body: items.isNotEmpty
          ? ListView.builder(
              primary: false,
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                // final item = items[index];
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  key: Key(items[index]["item_id"]),
                  child: Column(
                    children: [
                      ItemCardMedium(
                        item_id: items[index]["item_id"],
                        element: items[index],
                        category_id: "",
                        category_name: "",
                        scroll: 0,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(),
                      ),
                    ],
                  ),
                  onTap: () {
                    showModalBottomSheet(
                      transitionAnimationController: animController,
                      context: context,
                      clipBehavior: Clip.antiAlias,
                      useSafeArea: true,
                      isScrollControlled: true,
                      builder: (context) {
                        return ProductPage(
                          item: items[index],
                          index: index,
                          returnDataAmount: updateDataAmount,
                        );
                      },
                    );
                  },
                );
              },
            )
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.8,
                    child: Text(
                      "Вы пока ничего не добавили в избранное",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
