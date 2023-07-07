import 'package:flutter/material.dart';

import '../misc/api.dart';
import '../shared/buyButton.dart';
import '../shared/likeButton.dart';

class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage({super.key});

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  bool delivery = true;
  List items = [];
  Map<String, dynamic> cartInfo = {};

  Future<void> _getCart() async {
    List _cart = await getCart();
    print(_cart);

    Map<String, dynamic>? _cartInfo = await getCartInfo();

    setState(() {
      items = _cart;
      cartInfo = _cartInfo!;
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getCart();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: [
          SizedBox(
            height: 5,
          ),
          Container(
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.all(Radius.circular(10))),
            margin: EdgeInsets.symmetric(horizontal: 30, vertical: 5),
            padding: EdgeInsets.all(5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: [
                Flexible(
                    flex: 1,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          delivery = true;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                            color:
                                delivery ? Colors.white : Colors.grey.shade100,
                            borderRadius:
                                BorderRadius.all(Radius.circular(10))),
                        padding: EdgeInsets.all(10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.delivery_dining,
                              color: delivery
                                  ? Colors.black
                                  : Colors.grey.shade400,
                            ),
                            SizedBox(
                              width: 5,
                            ),
                            Text(
                              "Доставка",
                              style: TextStyle(
                                  color: delivery
                                      ? Colors.black
                                      : Colors.grey.shade400,
                                  fontWeight: FontWeight.w700),
                            )
                          ],
                        ),
                        alignment: Alignment.center,
                      ),
                    )),
                Flexible(
                    flex: 1,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          delivery = false;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                            color:
                                delivery ? Colors.grey.shade100 : Colors.white,
                            borderRadius:
                                BorderRadius.all(Radius.circular(10))),
                        padding: EdgeInsets.all(10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.store,
                              color: delivery
                                  ? Colors.grey.shade400
                                  : Colors.black,
                            ),
                            SizedBox(
                              width: 5,
                            ),
                            Text(
                              "Самовывоз",
                              style: TextStyle(
                                  color: delivery
                                      ? Colors.grey.shade400
                                      : Colors.black,
                                  fontWeight: FontWeight.w700),
                            )
                          ],
                        ),
                        alignment: Alignment.center,
                      ),
                    )),
              ],
            ),
          ),
          Container(
              padding: EdgeInsets.all(10),
              child: ListView.builder(
                  primary: false,
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];

                    return ItemCard(element: item);
                  })),
        ],
      ),
    );
  }
}

class ItemCard extends StatefulWidget {
  const ItemCard({super.key, required this.element});
  final Map<String, dynamic> element;
  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  Map<String, dynamic> element = {};
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    setState(() {
      element = widget.element;
    });
  }

  Future<void> refreshItemCard() async {
    if (element["item_id"] != null) {
      Map<String, dynamic>? _element = await getItem(widget.element["item_id"]);
      setState(() {
        element = _element!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.all(10),
        child:
            Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              width: MediaQuery.of(context).size.width * 0.4,
                              child: Text(
                                element["name"],
                                style: TextStyle(
                                    textBaseline: TextBaseline.alphabetic,
                                    fontSize: 16,
                                    color: Colors.black),
                              )),
                          // LikeButton(
                          //   item_id: element["item_id"],
                          //   is_liked: element["is_liked"],
                          // ),
                          Container(
                              width: MediaQuery.of(context).size.width * 0.4,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    element['price'] ?? "",
                                  ),
                                  Text(
                                    " x ",
                                  ),
                                  Text(
                                    element['amount'] ?? "",
                                  ),
                                  Text(
                                    element['price'] ?? "",
                                  ),
                                  Text()
                                ],
                              ))
                          // Row(
                          //   children: [
                          //     Text(
                          //       element['price'] ?? "",
                          //       style: TextStyle(
                          //           color: Colors.black,
                          //           fontWeight: FontWeight.w600,
                          //           fontSize: 24),
                          //     ),
                          //     Text(
                          //       "₸",
                          //       style: TextStyle(
                          //           color: Colors.grey.shade600,
                          //           fontWeight: FontWeight.w600,
                          //           fontSize: 24),
                          //     ),
                          //     Text(
                          //       " x ",
                          //       style: TextStyle(
                          //           color: Colors.grey.shade600,
                          //           fontWeight: FontWeight.w600,
                          //           fontSize: 24),
                          //     ),
                          //     Text(
                          //       element['amount'],
                          //       style: TextStyle(
                          //           color: Colors.grey.shade600,
                          //           fontWeight: FontWeight.w600,
                          //           fontSize: 24),
                          //     )
                          //   ],
                          // ),
                        ],
                      ),
           
      ),
      onTap: () {
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(
        //       builder: (context) => ProductPage(
        //             item_id: element["item_id"],
        //           )),
        // );
      },
    );
  }
}
