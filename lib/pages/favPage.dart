import 'package:flutter/material.dart';
import 'package:naliv_delivery/bottomMenu.dart';
import 'package:naliv_delivery/pages/productPage.dart';

import '../misc/api.dart';
import '../shared/buyButton.dart';
import '../shared/likeButton.dart';
import 'categoryPage.dart';

class FavPage extends StatefulWidget {
  const FavPage({super.key});

  @override
  State<FavPage> createState() => _FavPageState();
}

class _FavPageState extends State<FavPage> {
  List items = [];

  Future<void> _getItems() async {
    List _items = await getLiked();
    List<Widget> _itemsWidget = [];
    _items.forEach((element) {
      _itemsWidget.add(GestureDetector(
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
                builder: (context) => ProductPage(
                      item_id: element["item_id"],
                      returnWidget: BottomMenu(page: 1),
                    )),
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
    });
    setState(() {
      items = _items;
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
    return SingleChildScrollView(
      child: Column(children: [
        SizedBox(
          height: 10,
        ),
        items.isNotEmpty
            ? ListView.builder(
                primary: false,
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ProductPage(
                                  item_id: items[index]["item_id"],
                                  returnWidget: BottomMenu(page: 1),
                                )),
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
                  );
                },
              )
            : Center(
                child: Text(
                  "Вы пока не добавили товары в этом магазине",
                  style: TextStyle(color: Colors.black),
                ),
              ),
        SizedBox(
          height: 100,
        )
      ]),
    );
  }
}

// class ItemCard extends StatefulWidget {
//   const ItemCard({super.key, required this.element});
//   final Map<String, dynamic> element;
//   @override
//   State<ItemCard> createState() => _ItemCardState();
// }

// class _ItemCardState extends State<ItemCard> {
//   Map<String, dynamic> element = {};
//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//     setState(() {
//       element = widget.element;
//     });
//   }

//   Future<void> refreshItemCard() async {
//     if (element["item_id"] != null) {
//       Map<String, dynamic>? _element = await getItem(widget.element["item_id"]);
//       setState(() {
//         element = _element!;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       child: Container(
//         width: MediaQuery.of(context).size.width,
//         margin: EdgeInsets.all(10),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           mainAxisSize: MainAxisSize.max,
//           children: [
//             SizedBox(
//               height: 20,
//             ),
//             Row(
//               mainAxisSize: MainAxisSize.max,
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 Image.network(
//                   element["photo"],
//                   width: MediaQuery.of(context).size.width * 0.4,
//                   fit: BoxFit.cover,
//                 ),
//                 Column(
//                   mainAxisAlignment: MainAxisAlignment.start,
//                   mainAxisSize: MainAxisSize.max,
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Container(
//                       width: MediaQuery.of(context).size.width * 0.5,
//                       child: RichText(
//                         text: TextSpan(
//                             style: TextStyle(
//                                 textBaseline: TextBaseline.alphabetic,
//                                 fontSize: 20,
//                                 color: Colors.black),
//                             children: [
//                               TextSpan(text: element["name"]),
//                               WidgetSpan(
//                                   child: Container(
//                                 child: Text(
//                                   element["country"] ?? "",
//                                   style: TextStyle(
//                                       color: Colors.black,
//                                       fontWeight: FontWeight.w600),
//                                 ),
//                                 padding: EdgeInsets.all(5),
//                                 decoration: BoxDecoration(
//                                     color: Colors.grey.shade200,
//                                     borderRadius:
//                                         BorderRadius.all(Radius.circular(10))),
//                               ))
//                             ]),
//                       ),
//                     ),
//                     SizedBox(
//                       height: 10,
//                     ),
//                     Row(
//                       mainAxisSize: MainAxisSize.max,
//                       children: [
//                         Row(
//                           children: [
//                             Text(
//                               "12",
//                               style: TextStyle(
//                                   fontWeight: FontWeight.w700,
//                                   color: Colors.black,
//                                   fontSize: 16),
//                             ),
//                             Icon(
//                               Icons.percent,
//                               color: Colors.grey.shade600,
//                             )
//                           ],
//                         ),
//                         SizedBox(
//                           width: 5,
//                         ),
//                         Row(
//                           children: [
//                             Text(
//                               "12",
//                               style: TextStyle(
//                                   fontWeight: FontWeight.w700,
//                                   color: Colors.black,
//                                   fontSize: 16),
//                             ),
//                             Icon(
//                               Icons.percent,
//                               color: Colors.grey.shade600,
//                             )
//                           ],
//                         ),
//                         SizedBox(
//                           width: 5,
//                         ),
//                         Row(
//                           children: [
//                             Text(
//                               "12",
//                               style: TextStyle(
//                                   fontWeight: FontWeight.w700,
//                                   color: Colors.black,
//                                   fontSize: 16),
//                             ),
//                             Icon(
//                               Icons.percent,
//                               color: Colors.grey.shade600,
//                             )
//                           ],
//                         )
//                       ],
//                     ),
//                     SizedBox(
//                       height: 10,
//                     ),
//                     Row(
//                       children: [
//                         Text(
//                           element['price'] ?? "",
//                           style: TextStyle(
//                               color: Colors.black,
//                               fontWeight: FontWeight.w600,
//                               fontSize: 24),
//                         ),
//                         Text(
//                           "₸",
//                           style: TextStyle(
//                               color: Colors.grey.shade600,
//                               fontWeight: FontWeight.w600,
//                               fontSize: 24),
//                         )
//                       ],
//                     ),
//                     SizedBox(
//                       height: 15,
//                     ),
//                     Container(
//                       width: MediaQuery.of(context).size.width * 0.5,
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         mainAxisSize: MainAxisSize.max,
//                         children: [
//                           BuyButton(element: element),
//                           Container(
//                             alignment: Alignment.centerRight,
//                             child: LikeButton(
//                               is_liked: element["is_liked"],
//                               item_id: element["item_id"],
//                             ),
//                             width: MediaQuery.of(context).size.width * 0.1,
//                           )
//                         ],
//                       ),
//                     )
//                   ],
//                 )
//               ],
//             ),
//             SizedBox(
//               height: 25,
//             ),
//             Container(
//               height: 1,
//               color: Colors.grey.shade200,
//             )
//           ],
//         ),
//       ),
//       onTap: () {
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//               builder: (context) => ProductPage(
//                     item_id: element["item_id"],
//                     returnWidget: BottomMenu(page: 1),
//                   )),
//         );
//       },
//     );
//   }
// }
