import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/createOrder.dart';
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

  String formatCost(String costString) {
    int cost = int.parse(costString);
    return NumberFormat("###,###", "en_US").format(cost).replaceAll(',', ' ');
  }

  Future<void> _getCart() async {
    Map<String, dynamic> cart = await getCart();
    print(cart);

    // Map<String, dynamic>? cartInfo = await getCartInfo();
    print(cartInfo);

    setState(() {
      items = cart["cart"];
      cartInfo = cart;
      sum = cart["sum"];
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
      setState(() {
        localSum = int.parse(sum);
        isCartLoading = false;
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
                          confirmDismiss: (direction) {
                            return _deleteFromCart(item["item_id"]);
                          },
                          onDismissed: ((direction) {
                            Map<String, dynamic> dissmisedItem =
                                items.firstWhere((element) =>
                                    element["item_id"] == item["item_id"]);
                            setState(() {
                              localSum -= int.parse(dissmisedItem["price"]) *
                                  int.parse(dissmisedItem["amount"]);
                            });
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
                                  );
                                },
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Divider(
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(
                  height: 100,
                ),
                Divider(
                  color: Theme.of(context).colorScheme.secondary,
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Flexible(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
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
                              padding: const EdgeInsets.only(right: 20),
                              child: Divider(
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                            const Padding(
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
                              padding: const EdgeInsets.only(right: 20),
                              child: Divider(
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                            const Padding(
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
                            Divider(
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                            Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 5),
                                  child: Text(
                                    formatCost(localSum
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
                            Divider(
                              color: Theme.of(context).colorScheme.secondary,
                            ),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: ((context) {
                            return const CreateOrderPage();
                          }),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Оформить заказ",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                        Flexible(
                          fit: FlexFit.tight,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Flexible(
                                fit: FlexFit.tight,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 5),
                                  child: Text(
                                    formatCost(localSum
                                        .toString()), // TODO: HERE IS SUM OF CART
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 22,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  "₸",
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : Container(
              alignment: Alignment.center,
              width: MediaQuery.of(context).size.width,
              child: const Text("Ваша корзина пуста"),
            ),
    );
  }
}
