import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/bottomMenu.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/createOrder.dart';
import 'package:naliv_delivery/pages/productPage.dart';
import 'package:naliv_delivery/shared/buyButton.dart';
import 'package:naliv_delivery/shared/likeButton.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List items = [];
  Map<String, dynamic> cartInfo = {};

  Future<void> _getCart() async {
    List cart = await getCart();
    print(cart);

    Map<String, dynamic>? cartInfo = await getCartInfo();

    setState(() {
      items = cart;
      cartInfo = cartInfo!;
    });
  }

  Future<bool> _deleteFromCart(String itemId) async {
    bool? result = await deleteFromCart(itemId);
    result ??= false;

    print(result);
    return Future(() => result!);
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
      body: Column(children: [
        const SizedBox(
          height: 10,
        ),
        ListView.builder(
          primary: false,
          shrinkWrap: true,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Dismissible(
                // Each Dismissible must contain a Key. Keys allow Flutter to
                // uniquely identify widgets.
                key: Key(item["item_id"]),
                confirmDismiss: (direction) {
                  return _deleteFromCart(item["item_id"]);
                },
                // Provide a function that tells the app
                // what to do after an item has been swiped away.

                // Show a red background as the item is swiped away.
                background: SizedBox(
                  width: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: MediaQuery.of(context).size.width * 0.7,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.only(right: 10),
                        color: Colors.grey.shade100,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.3,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.only(right: 10),
                        color: Colors.grey.shade100,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [Icon(Icons.delete), Text("Удалить")],
                        ),
                      )
                    ],
                  ),
                ),
                child: ItemCard(element: item));
          },
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
          child: TextField(
            decoration: InputDecoration(
                hintText: "Введите промокод",
                fillColor: Colors.grey.shade100,
                filled: true,
                border: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                    borderRadius: BorderRadius.all(Radius.circular(10)))),
          ),
        ),
        Container(
          margin: const EdgeInsets.all(30),
          child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateOrderPage(),
                    ));
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Text("Оформить заказ")],
              )),
        ),
        const SizedBox(
          height: 100,
        )
      ]),
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
      Map<String, dynamic>? element = await getItem(widget.element["item_id"]);
      setState(() {
        element = element!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  alignment: Alignment.center,
                  width: MediaQuery.of(context).size.width * 0.25,
                  child: CachedNetworkImage(
                    fit: BoxFit.fitHeight,
                    imageUrl: 'https://naliv.kz/img${element["photo"]}',
                    placeholder: ((context, url) {
                      return const Expanded(child: CircularProgressIndicator());
                    }),
                    errorWidget: ((context, url, error) {
                      return const Expanded(
                          child: FittedBox(child: Text("Нет изображения")));
                    }),
                  ),
                ),
                // SizedBox(
                // width: MediaQuery.of(context).size.width * 0.25,
                // child: Image.network(
                //   'https://naliv.kz/img/' + element["photo"],
                //   width: MediaQuery.of(context).size.width * 0.25,
                //   fit: BoxFit.fill,
                // ),),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.4,
                            child: RichText(
                              text: TextSpan(
                                  style: const TextStyle(
                                      textBaseline: TextBaseline.alphabetic,
                                      fontSize: 14,
                                      color: Colors.black),
                                  children: [
                                    TextSpan(text: element["name"]),
                                    // WidgetSpan(
                                    //     child: Container(
                                    //   child: Text(
                                    //     element["country"] ?? "",
                                    //     style: TextStyle(
                                    //         color: Colors.black,
                                    //         fontWeight: FontWeight.w600),
                                    //   ),
                                    //   padding: EdgeInsets.all(5),
                                    //   decoration: BoxDecoration(
                                    //       color: Colors.grey.shade200,
                                    //       borderRadius:
                                    //           BorderRadius.all(Radius.circular(10))),
                                    // ))
                                  ]),
                            ),
                          ),
                          LikeButton(
                            item_id: element["item_id"],
                            is_liked: element["is_liked"],
                          )
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  element['prev_price'] ?? "",
                                  style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 15,
                                      decoration: TextDecoration.lineThrough),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      element['price'] ?? "",
                                      style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 24),
                                    ),
                                    Text(
                                      "₸",
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 24),
                                    )
                                  ],
                                ),
                              ],
                            ),
                          ),
                          BuyButton(element: element),
                        ],
                      ),
                    ],
                  ),
                )
              ],
            ),
          ],
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ProductPage(item_id: element["item_id"])),
        );
      },
    );
  }
}
