import 'dart:async';

import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/addressesPage.dart';
import 'package:naliv_delivery/pages/createAddress.dart';
import 'package:naliv_delivery/pages/orderConfirmation.dart';
import 'package:naliv_delivery/shared/itemCards.dart';
import 'package:shimmer/shimmer.dart';

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
  // Widget? currentAddressWidget;
  List<Widget> addressesWidget = [];
  Map currentAddress = {};
  List addresses = [];

  bool isAddressesLoading = true;

  Future<void> _getCart() async {
    // List cart = await getCart();
    // print(cart);

    Map<String, dynamic> cart = await getCart();
    Map<String, dynamic>? cartInfo = await getCartInfo();

    setState(() {
      // items = cart;
      items = cart["cart"];
      cartInfo = cartInfo!;
    });
  }

  Future<void> _getAddresses() async {
    setState(() {
      isAddressesLoading = true;
    });
    List<Widget> addressesWidget = [];
    addresses = await getAddresses();
    for (var element in addresses) {
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
          isAddressesLoading = false;
          // currentAddressWidget = GestureDetector(
          //   behavior: HitTestBehavior.opaque,
          //   child: Row(
          //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //     mainAxisSize: MainAxisSize.max,
          //     children: [
          //       Text(element["address"]),
          //       const Icon(Icons.arrow_forward_ios)
          //     ],
          //   ),
          //   onTap: () {
          //     _getAddressPickDialog();
          //   },
          // );
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
          title: Text(
            "Ваши адреса",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 24,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(3))),
          insetPadding: const EdgeInsets.all(0),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.7,
            height: MediaQuery.of(context).size.height * 0.4,
            child: ListView.builder(
              itemCount: addresses.length,
              itemBuilder: (context, index) {
                print(addresses);
                return Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        // TODO: ACTUALLY CHANGE ADDRESS HERE
                        print("Change address here");
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Text(
                            "${addresses[index]["name"] != null ? '${addresses[index]["name"]} -' : ""} ${addresses[index]["address"]}",
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 15,
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    Future.delayed(const Duration(microseconds: 0), () async {
      await _getCart();
      await _getAddresses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Заказ"),
      ),
      body: ListView(
        children: [
          const SizedBox(
            height: 5,
          ),
          Container(
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.all(Radius.circular(3))),
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
                          color: delivery ? Colors.white : Colors.grey.shade100,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(3))),
                      padding: const EdgeInsets.all(10),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.delivery_dining,
                            color:
                                delivery ? Colors.black : Colors.grey.shade400,
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
                  ),
                ),
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
                          color: delivery ? Colors.grey.shade100 : Colors.white,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(3))),
                      padding: const EdgeInsets.all(10),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.store,
                            color:
                                delivery ? Colors.grey.shade400 : Colors.black,
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
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: MediaQuery.of(context).size.height * 0.5,
            decoration: BoxDecoration(
                border: Border.all(
                  width: 2,
                  color: Colors.grey.shade100,
                ),
                color: Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(3))),
            margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
            padding: const EdgeInsets.all(5),
            child: ListView.builder(
              primary: false,
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];

                return Column(
                  children: [
                    ItemCardNoImage(
                      element: item,
                      item_id: item["item_id"],
                      category_id: "",
                      category_name: "",
                      scroll: 0,
                    ),
                    items.length - 1 != index
                        ? const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 5,
                            ),
                            child: Divider(
                              height: 0,
                            ),
                          )
                        : Container(),
                  ],
                );
              },
            ),
          ),
          isAddressesLoading
              ? Shimmer.fromColors(
                  baseColor:
                      Theme.of(context).colorScheme.secondary.withOpacity(0.05),
                  highlightColor: Theme.of(context).colorScheme.secondary,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Container(
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(3)),
                        color: Colors.white,
                      ),
                      width: double.infinity,
                      height: 50,
                    ),
                  ),
                )
              : delivery
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                          border: Border.all(
                            width: 2,
                            color: Colors.grey.shade100,
                          ),
                          color: Colors.white,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(3))),
                      margin: const EdgeInsets.symmetric(horizontal: 30),
                      // This should be null only if user doesn't have any addresses, else there will be user address
                      // child: currentAddressWidget ??
                      child: currentAddress.isNotEmpty
                          ? GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Text(
                                    currentAddress["address"],
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                _getAddressPickDialog();
                              },
                            )
                          : TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => AddressesPage(
                                            addresses: addresses,
                                            isExtended: true,
                                          )),
                                ).then((value) => print(_getAddresses()));
                              },
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Text(
                                    "Добавьте адрес доставки",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary,
                                    ),
                                  ),
                                  Icon(
                                    Icons.add_box_rounded,
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                  ),
                                ],
                              ),
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
                borderRadius: const BorderRadius.all(Radius.circular(3))),
            margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
            padding: const EdgeInsets.all(15),
            child: Text(
              "Здесь мы расчитываем стоймость доставки",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
                border: Border.all(
                  width: 2,
                  color: Colors.grey.shade100,
                ),
                color: Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(3))),
            margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
            padding: const EdgeInsets.all(15),
            child: Text(
              "а здесь эквайринг",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
                border: Border.all(
                  width: 2,
                  color: Colors.grey.shade100,
                ),
                color: Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(3))),
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
                  ),
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Text(
                    "Подтвердить заказ",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
