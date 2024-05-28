import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/createOrder.dart';
import 'package:naliv_delivery/pages/findCreateUserPage.dart';
import 'package:naliv_delivery/pages/productPage.dart';
import 'package:naliv_delivery/shared/itemCards.dart';
import 'package:intl/intl.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage>
    with SingleTickerProviderStateMixin {
  late List items = [];
  late Map<String, dynamic> cartInfo = {};
  late String sum = "0";
  int localSum = 0;
  late AnimationController animController;
  final Duration animDuration = const Duration(milliseconds: 250);
  int localDiscount = 0;
  TextEditingController _promoController = TextEditingController();
  Map<String, dynamic> client = {};

  String formatCost(String costString) {
    int cost = int.parse(costString);
    return NumberFormat("###,###", "en_US").format(cost).replaceAll(',', ' ');
  }

  Future<void> _getCart() async {
    Map<String, dynamic> cart = await getCart();
    print(cart);

    // Map<String, dynamic>? cartInfo = await getCartInfo();
    print(cartInfo);

    // if (cart["sum"] == null || cart["cart"]) {
    //   return;
    // }

    setState(() {
      items = cart["cart"];
      cartInfo = cart;
      sum = cart["sum"] ?? "0";
    });
  }

  Future<bool> _deleteFromCart(String itemId) async {
    bool? result = await deleteFromCart(itemId);
    result ??= false;

    print(result);
    return Future(() => result!);
  }

  void _setAnimationController() {
    animController = BottomSheet.createAnimationController(this);

    animController.duration = animDuration;
    animController.reverseDuration = animDuration;
    animController.drive(CurveTween(curve: Curves.easeIn));
  }

  void updateDataAmount(String newDataAmount, int index) {
    setState(() {
      localSum -=
          int.parse(items[index]["price"]) * int.parse(items[index]["amount"]);
      items[index]["amount"] = newDataAmount;
      localSum +=
          int.parse(items[index]["price"]) * int.parse(items[index]["amount"]);
    });
    if (newDataAmount == "0") {
      items.removeAt(index);
    }
  }

  void updatePrices() {
    localSum = 0;
    localDiscount = 0;
    for (dynamic item in items) {
      localSum += (int.parse(item["price"]) * int.parse(item["amount"]));
      if (item["previous_price"] != null) {
        localDiscount += (int.parse(item["price"]) -
            int.parse(item["previous_price"]) * int.parse(item["amount"]));
      }
    }
    // Just update states, ONLY after cycle are done working
    if (mounted) {
      setState(() {
        localSum = localSum;
        localDiscount = localDiscount;
      });
    }
  }

  bool isCartLoading = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _setAnimationController();
    Future.delayed(const Duration(milliseconds: 0), () async {
      setState(() {
        isCartLoading = true;
      });
      await _getCart();
      if (mounted) {
        setState(() {
          localSum = int.parse(sum);
          for (dynamic item in items) {
            if (item["previous_price"] != null) {
              localDiscount += int.parse(item["price"]) -
                  int.parse(item["previous_price"] ?? "0");
            }
          }
          isCartLoading = false;
        });
      }
      await getUser().then((value) {
        if (value != null && mounted) {
          setState(() {
            client = value;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Корзина",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      body: items.isNotEmpty
          ? ListView(
              children: [
                ListView.builder(
                  primary: false,
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Column(
                      children: [
                        Dismissible(
                          // Each Dismissible must contain a Key. Keys allow Flutter to
                          // uniquely identify widgets.
                          key: Key(item["item_id"]),
                          confirmDismiss: (direction) async {
                            bool result =
                                await _deleteFromCart(item["item_id"]);

                            if (result) {
                              setState(() {
                                items.removeAt(index);
                                updatePrices();
                                // localSum -= int.parse(item["price"]) *
                                //     int.parse(item["amount"]);
                              });
                            }

                            return result;
                          },
                          onDismissed: ((direction) {
                            print(MediaQuery.of(context).size.height *
                                ((4 - items.length) / 10));
                          }),
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
                                  width:
                                      MediaQuery.of(context).size.width * 0.7,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.only(right: 10),
                                  color: Colors.grey.shade100,
                                ),
                                Container(
                                  width:
                                      MediaQuery.of(context).size.width * 0.3,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.only(right: 10),
                                  color: Colors.grey.shade100,
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.delete),
                                      Text("Удалить")
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                          child: Column(
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                key: Key(items[index]["item_id"]),
                                child: ItemCardMinimal(
                                  item_id: items[index]["item_id"],
                                  element: items[index],
                                  category_id: "",
                                  category_name: "",
                                  scroll: 0,
                                ),
                                onTap: () {
                                  showModalBottomSheet(
                                    transitionAnimationController:
                                        animController,
                                    context: context,
                                    clipBehavior: Clip.antiAlias,
                                    useSafeArea: true,
                                    isScrollControlled: true,
                                    builder: (context) {
                                      return ProductPage(
                                        item: items[index],
                                        index: index,
                                        returnDataAmount: updateDataAmount,
                                        openedFromCart: true,
                                      );
                                    },
                                  ).then((value) {
                                    print("object");
                                  });
                                },
                              ),
                              items.length - 1 != index
                                  ? const Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 16),
                                      child: Divider(),
                                    )
                                  : Container(),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                // Makes buy button stay in the same place imitating other cards in listView
                items.isNotEmpty
                    ? Column(
                        children: [
                          SizedBox(
                            width: MediaQuery.of(context).size.width,
                            height: items.length < 4
                                ? (MediaQuery.of(context).size.height * 0.122) *
                                    (4 - items.length)
                                : 0,
                          ),
                          const Divider(
                            color: Colors.transparent,
                          ),
                        ],
                      )
                    : Container(),
                const SizedBox(
                  height: 20,
                ),
                const Divider(),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      const Flexible(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(left: 15),
                              child: Text(
                                "Цена без скидки",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(right: 20),
                              child: Divider(),
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 15),
                              child: Text(
                                "Скидка",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(right: 20),
                              child: Divider(),
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 15),
                              child: Text(
                                "Итого",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 5),
                                  child: Text(
                                    formatCost(localSum
                                        .toString()), // CHANGE THIS TO REPRESENT SUM WITHOUT DISCOUNT
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                const Text(
                                  "₸",
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18),
                                ),
                              ],
                            ),
                            const Divider(),
                            Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 5),
                                  child: Text(
                                    formatCost(localDiscount
                                        .toString()), // CHANGE THIS TO REPRESENT DISCOUNT
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                const Text(
                                  "₸",
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18),
                                ),
                              ],
                            ),
                            const Divider(),
                            Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 5),
                                  child: Text(
                                    formatCost(localSum.toString()),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                const Text(
                                  "₸",
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder: (context) {
                      //       return const CreateOrderPage();
                      //     },
                      //   ),
                      // );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) {
                            return const findCreateUserPage();
                          },
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            "Оформить заказ",
                            textAlign: TextAlign.justify,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.all(0),
                        foregroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(3)),
                        ),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              shape: const RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(3))),
                              backgroundColor:
                                  Theme.of(context).colorScheme.background,
                              surfaceTintColor: Colors.transparent,
                              elevation: 0.0,
                              title: const Text(
                                "Промокод",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                              content: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(
                                    controller: _promoController,
                                    decoration: const InputDecoration(
                                      border: UnderlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 15,
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 15, vertical: 15),
                                    ),
                                    onPressed: () {
                                      print(
                                          "Hell, add promo-codes functional here, lol");
                                    },
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "Подтвердить",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      child: Text(
                        "Есть промокод?",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.8,
                    child: Text(
                      "Ваша корзина пуста",
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
