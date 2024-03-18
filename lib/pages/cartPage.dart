import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/createOrder.dart';
import 'package:naliv_delivery/pages/orderPage.dart';
import 'package:naliv_delivery/pages/productPage.dart';
import 'package:naliv_delivery/shared/itemCards.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage>
    with SingleTickerProviderStateMixin {
  late List items = [];
  late Map<String, dynamic> cartInfo = {};
  late AnimationController animController;

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
    _setAnimationController();
    _getCart();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: ElevatedButton(
        style: ButtonStyle(
          backgroundColor:
              MaterialStatePropertyAll(Theme.of(context).colorScheme.secondary),
          shape: const MaterialStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(10),
              ),
            ),
          ),
          elevation: const MaterialStatePropertyAll(0.0),
        ),
        onPressed: (() {
          Navigator.push(
            context,
            MaterialPageRoute(builder: ((context) {
              return const CreateOrderPage();
            })),
          );
        }),
        child: const Text("Оформить заказ"),
      ),
      appBar: AppBar(),
      body: items.isNotEmpty
          ? ListView.builder(
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
                  child: GestureDetector(
                    key: Key(items[index]["item_id"]),
                    child: ItemCardMinimized(
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
                  ),
                );
              },
            )
          : Container(
              alignment: Alignment.center,
              width: MediaQuery.of(context).size.width,
              child: const Text("Ваша корзина пуста"),
            ),
    );
  }
}
