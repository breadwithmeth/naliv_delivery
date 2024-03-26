import 'dart:async';

import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/orderConfirmation.dart';
import 'package:naliv_delivery/shared/itemCards.dart';

import '../misc/api.dart';

class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage({super.key});

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  bool delivery = true;
  List items = [];
  Map<String, dynamic> cartInfo = {};
  Widget? currentAddressWidget;
  List<Widget> addressesWidget = [];
  Map? currentAddress;

  Future<void> _getCart() async {
    List cart = await getCart();
    print(cart);

    Map<String, dynamic>? cartInfo = await getCartInfo();

    setState(() {
      items = cart;
      cartInfo = cartInfo!;
    });
  }

  Future<void> _getAddresses() async {
    Map? currentAddress;
    List<Widget> addressesWidget = [];
    List addresseses = await getAddresses();
    for (var element in addresseses) {
      addressesWidget.add(Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade200),
                backgroundColor: element["is_selected"] == "1"
                    ? Colors.grey.shade200
                    : Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 5)),
            onPressed: () {
              selectAddress(element["address_id"]);
              Timer(const Duration(microseconds: 300), () {
                _getAddresses();
              });

              Navigator.pop(context);
            },
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(
                  element["address"],
                  style: const TextStyle(color: Colors.black),
                )
              ],
            )),
      ));
      if (element["is_selected"] == "1") {
        setState(() {
          currentAddress = element;
          currentAddressWidget = GestureDetector(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(element["address"]),
                const Icon(Icons.arrow_forward_ios)
              ],
            ),
            onTap: () {
              _getAddressPickDialog();
            },
          );
        });
      }
    }

    setState(() {
      addressesWidget = addressesWidget;
    });
  }

  void _getAddressPickDialog() {
    showDialog(
      useSafeArea: false,
      context: context,
      builder: (context) {
        return AlertDialog(
            insetPadding: const EdgeInsets.all(0),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.7,
              height: MediaQuery.of(context).size.height * 0.4,
              child: SingleChildScrollView(
                child: Column(
                  children: addressesWidget,
                ),
              ),
            ));
      },
    );
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getCart();
    _getAddresses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          const SizedBox(
            height: 5,
          ),
          Container(
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.all(Radius.circular(10))),
            margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
            padding: const EdgeInsets.all(5),
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
                                const BorderRadius.all(Radius.circular(10))),
                        padding: const EdgeInsets.all(10),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.delivery_dining,
                              color: delivery
                                  ? Colors.black
                                  : Colors.grey.shade400,
                            ),
                            const SizedBox(
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
                                const BorderRadius.all(Radius.circular(10))),
                        padding: const EdgeInsets.all(10),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.store,
                              color: delivery
                                  ? Colors.grey.shade400
                                  : Colors.black,
                            ),
                            const SizedBox(
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
                      ),
                    )),
              ],
            ),
          ),
          Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
                border: Border.all(
                  width: 2,
                  color: Colors.grey.shade100,
                ),
                color: Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(10))),
            margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
            padding: const EdgeInsets.all(5),
            child: ListView.builder(
              primary: false,
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];

                return ItemCardMedium(
                  element: item,
                  item_id: item["item_id"],
                  category_id: "",
                  category_name: "",
                  scroll: 0,
                );
              },
            ),
          ),
          delivery
              ? Container(
                  decoration: BoxDecoration(
                      border: Border.all(
                        width: 2,
                        color: Colors.grey.shade100,
                      ),
                      color: Colors.white,
                      borderRadius:
                          const BorderRadius.all(Radius.circular(10))),
                  margin:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    children: [currentAddressWidget ?? Container()],
                  ),
                )
              : Container(),
          Container(
              decoration: BoxDecoration(
                  border: Border.all(
                    width: 2,
                    color: Colors.grey.shade100,
                  ),
                  color: Colors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(10))),
              margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
              padding: const EdgeInsets.all(15),
              child: const Text("Здесь мы расчитываем стоймость доставки")),
          Container(
              decoration: BoxDecoration(
                  border: Border.all(
                    width: 2,
                    color: Colors.grey.shade100,
                  ),
                  color: Colors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(10))),
              margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
              padding: const EdgeInsets.all(15),
              child: const Text("а здесь эквайринг")),
          Container(
            decoration: BoxDecoration(
                border: Border.all(
                  width: 2,
                  color: Colors.grey.shade100,
                ),
                color: Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(10))),
            margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
            padding: const EdgeInsets.all(15),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderConfirmation(
                        delivery: delivery,
                        items: items,
                        address: currentAddress,
                      ),
                    ));
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [Text("Подтвердить заказ")],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
