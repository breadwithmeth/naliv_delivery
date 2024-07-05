import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:naliv_delivery/pages/webViewCardPayPage.dart';
import '../globals.dart' as globals;
import 'package:flutter/widgets.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:naliv_delivery/main.dart';
import 'package:naliv_delivery/pages/addressesPage.dart';
import 'package:naliv_delivery/pages/createAddressPage.dart';
import 'package:naliv_delivery/pages/orderConfirmation.dart';
import 'package:naliv_delivery/pages/pickAddressPage.dart';
import 'package:naliv_delivery/shared/itemCards.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

import '../misc/api.dart';

class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage(
      {super.key,
      required this.business,
      required this.finalSum,
      required this.user,
      required this.items,
      required this.deliveryInfo,
      required this.itemsAmount,
      this.client = const {}});

  final Map<dynamic, dynamic> business;
  final int finalSum;
  final Map user;
  final List items;
  final int itemsAmount;
  final Map deliveryInfo;
  final Map<dynamic, dynamic> client;

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage>
    with SingleTickerProviderStateMixin {
  bool delivery = true;
  String cartInfo = "";
  // Widget? currentAddressWidget;
  List<Widget> addressesWidget = [];
  Map currentAddress = {};
  List addresses = [];

  bool isAddressesLoading = true;
  bool isCartLoading = true;

  List<Map<dynamic, dynamic>> wrongAmountitems = [];

  late AnimationController _controller;
  late Animation<Offset> _deliveryChooseAnim;

  // Future<void> _getCart() async {
  //   // List cart = await getCart();
  //   // print(cart);

  //   Map<String, dynamic> cart = await getCart(widget.business["business_id"]);
  //   // Map<String, dynamic>? cartInfoFromAPI = await getCartInfo();

  //   setState(() {
  //     // widget.items = cart;
  //     widget.items = cart["cart"];
  //     cartInfo = cart["sum"];
  //   });
  // }

  Future<void> _getClientAddresses() async {
    setState(() {
      isAddressesLoading = true;
    });
    List<Widget> addressesWidget = [];
    await getAddresses().then((value) {
      setState(() {
        addresses = value;
      });
    });
    if (addresses.isEmpty) {
      setState(() {
        isAddressesLoading = false;
      });
      return;
    }
    for (var element in addresses) {
      addressesWidget.add(Container(
        margin: EdgeInsets.symmetric(vertical: 5),
        child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade200),
                backgroundColor: element["is_selected"] == "1"
                    ? Colors.grey.shade200
                    : Colors.white,
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 5)),
            onPressed: () {
              selectAddress(element["address_id"]);
              Timer(Duration(microseconds: 300), () {
                _getAddresses();
              });

              Navigator.pop(context);
            },
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(
                  element["address"],
                  style: TextStyle(color: Colors.black),
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
          //        Icon(Icons.arrow_forward_ios)
          //     ],
          //   ),
          //   onTap: () {
          //     _getAddressPickDialog();
          //   },
          // );
        });
      }
    }
    if (currentAddress.isEmpty) {
      setState(() {
        isAddressesLoading = false;
      });
    }

    setState(() {
      addressesWidget = addressesWidget;
    });
  }

  Future<void> _getAddresses() async {
    setState(() {
      isAddressesLoading = true;
    });
    List<Widget> addressesWidget = [];
    addresses = await getAddresses();
    if (addresses.isEmpty) {
      setState(() {
        isAddressesLoading = false;
      });
      return;
    }
    for (var element in addresses) {
      addressesWidget.add(Container(
        margin: EdgeInsets.symmetric(vertical: 5),
        child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade200),
                backgroundColor: element["is_selected"] == "1"
                    ? Colors.grey.shade200
                    : Colors.white,
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 5)),
            onPressed: () {
              selectAddress(element["address_id"]);
              Timer(Duration(microseconds: 300), () {
                _getAddresses();
              });

              Navigator.pop(context);
            },
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(
                  element["address"],
                  style: TextStyle(color: Colors.black),
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
          //        Icon(Icons.arrow_forward_ios)
          //     ],
          //   ),
          //   onTap: () {
          //     _getAddressPickDialog();
          //   },
          // );
        });
      }
    }
    if (currentAddress.isEmpty) {
      setState(() {
        isAddressesLoading = false;
      });
    }

    setState(() {
      addressesWidget = addressesWidget;
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _deliveryChooseAnim = Tween<Offset>(
      begin: Offset(0, 0),
      end: Offset(1.035, 0),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    Future.delayed(Duration(microseconds: 0), () async {
      // SWITCH BETWEEN getAddresses and getClientAddresses depending on Client/Operator mode
      await _getAddresses();
      // await _getClientAddresses();
    }).whenComplete(() => isCartLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.symmetric(horizontal: 30 * globals.scaleParam),
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OrderConfirmation(
                  delivery: delivery,
                  items: widget.items,
                  address: currentAddress,
                  cartInfo: cartInfo,
                  business: widget.business,
                  user: widget.user,
                  finalSum: widget.finalSum,
                ),
              ),
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                fit: FlexFit.tight,
                child: Text(
                  "Подтвердить заказ",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 42 * globals.scaleParam,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // floatingActionButton: ElevatedButton(
      //   onPressed: isCartLoading || isAddressesLoading || currentAddress.isEmpty
      //       ? null
      //       : () {
      //           Navigator.push(
      //             context,
      //             MaterialPageRoute(
      //               builder: (context) => OrderConfirmation(
      //                 delivery: delivery,
      //                 items: widget.items,
      //                 address: currentAddress,
      //                 cartInfo: cartInfo,
      //                 business: widget.business,
      //                 user: widget.user,
      //                 finalSum: widget.finalSum,
      //               ),
      //             ),
      //           );
      //         },
      //   child: Row(
      //     mainAxisAlignment: MainAxisAlignment.center,
      //     mainAxisSize: MainAxisSize.max,
      //     children: [
      //       Text(
      //         "Подтвердить заказ",
      //         style: TextStyle(
      //           fontWeight: FontWeight.w900,
      //           fontSize: 32 * globals.scaleParam,
      //           color: Theme.of(context).colorScheme.onPrimary,
      //         ),
      //       ),
      //     ],
      //   ),
      // ),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20 * globals.scaleParam),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  Flexible(
                    flex: 7,
                    fit: FlexFit.tight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                "Заказ",
                                style: TextStyle(
                                    fontSize: 40 * globals.scaleParam),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                "${widget.business["name"]} ${widget.business["address"]}",
                                maxLines: 1,
                                style: TextStyle(
                                    fontSize: 32 * globals.scaleParam),
                              ),
                            ),
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
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              // LayoutBuilder(
              //   builder: (context, constraints) {
              //     return Container(
              //       alignment: Alignment.topCenter,
              //       child: Column(
              //         children: [
              //           // SizedBox(
              //           //   height: constraints.maxHeight * 0.085,
              //           // ),
              //           Container(
              //             width: constraints.maxWidth,
              //             height: constraints.maxHeight * 0.48,
              //             decoration: BoxDecoration(
              //               color: Colors.black12,
              //               borderRadius: BorderRadius.only(
              //                 bottomLeft: Radius.circular(15),
              //                 bottomRight: Radius.circular(15),
              //               ),
              //             ),
              //           ),
              //         ],
              //       ),
              //     );
              //   },
              // ),
              // Container(
              //   decoration: BoxDecoration(
              //     color: Colors.amber,
              //     borderRadius: BorderRadius.all(Radius.circular(10)),
              //   ),
              //   margin: EdgeInsets.symmetric(
              //       horizontal: 20 * globals.scaleParam,
              //       vertical: 10 * globals.scaleParam),
              //   padding: EdgeInsets.all(10 * globals.scaleParam),
              //   child: LayoutBuilder(
              //     builder: (context, constraints) {
              //       return Stack(
              //         children: [
              //           Row(
              //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //             mainAxisSize: MainAxisSize.max,
              //             children: [
              //               Flexible(
              //                 fit: FlexFit.tight,
              //                 child: GestureDetector(
              //                   onTap: () {
              //                     setState(() {
              //                       delivery = true;
              //                     });
              //                   },
              //                   child: Container(
              //                     decoration: BoxDecoration(
              //                       borderRadius:
              //                           BorderRadius.all(Radius.circular(10)),
              //                       border: Border.all(
              //                         color: Colors.transparent,
              //                       ),
              //                     ),
              //                     padding:
              //                         EdgeInsets.all(20 * globals.scaleParam),
              //                     alignment: Alignment.center,
              //                     child: Row(
              //                       mainAxisAlignment: MainAxisAlignment.center,
              //                       children: [
              //                         Icon(
              //                           Icons.delivery_dining,
              //                         ),
              //                         SizedBox(
              //                           width: 10 * globals.scaleParam,
              //                         ),
              //                         Text(
              //                           "Доставка",
              //                           style: TextStyle(
              //                             fontWeight: FontWeight.w700,
              //                             fontSize: 32 * globals.scaleParam,
              //                           ),
              //                         )
              //                       ],
              //                     ),
              //                   ),
              //                 ),
              //               ),
              //               Flexible(
              //                 fit: FlexFit.tight,
              //                 child: GestureDetector(
              //                   onTap: () {
              //                     setState(() {
              //                       delivery = false;
              //                     });
              //                   },
              //                   child: Container(
              //                     decoration: BoxDecoration(
              //                       borderRadius:
              //                           BorderRadius.all(Radius.circular(10)),
              //                       border: Border.all(
              //                         color: Colors.transparent,
              //                       ),
              //                     ),
              //                     padding:
              //                         EdgeInsets.all(20 * globals.scaleParam),
              //                     alignment: Alignment.center,
              //                     child: Row(
              //                       mainAxisAlignment: MainAxisAlignment.center,
              //                       children: [
              //                         Icon(
              //                           Icons.store,
              //                         ),
              //                         SizedBox(
              //                           width: 10 * globals.scaleParam,
              //                         ),
              //                         Text(
              //                           "Самовывоз",
              //                           style: TextStyle(
              //                             fontWeight: FontWeight.w700,
              //                             fontSize: 32 * globals.scaleParam,
              //                           ),
              //                         )
              //                       ],
              //                     ),
              //                   ),
              //                 ),
              //               ),
              //             ],
              //           ),
              //           Row(
              //             children: [
              //               Flexible(
              //                 fit: FlexFit.tight,
              //                 child: LayoutBuilder(
              //                     builder: (context, constraints) {
              //                   return Container(
              //                     width: constraints.maxWidth,
              //                     color: Colors.black,
              //                   );
              //                 }),
              //               ),
              //               Flexible(
              //                 fit: FlexFit.tight,
              //                 child: SizedBox(),
              //               ),
              //             ],
              //           ),
              //         ],
              //       );
              //     },
              //   ),
              // ),
              Container(
                alignment: Alignment.topCenter,
                child: Container(
                  width: constraints.maxWidth * 0.98,
                  height: 760 * globals.scaleParam,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                    color: Colors.black,
                  ),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            height: 100 * globals.scaleParam,
                            margin: EdgeInsets.symmetric(
                              horizontal: 15 * globals.scaleParam,
                              vertical: 20 * globals.scaleParam,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.all(
                                Radius.circular(10),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color.fromARGB(255, 51, 51, 51),
                                  spreadRadius: -3,
                                ),
                              ],
                              // color: const Color.fromARGB(255, 51, 51, 51),
                            ),
                            child: Row(
                              children: [
                                Flexible(
                                  flex: 30,
                                  fit: FlexFit.tight,
                                  child: GestureDetector(
                                    onTap: () {
                                      _controller.reverse();
                                      setState(() {
                                        delivery = true;
                                      });
                                    },
                                    child: Container(
                                      alignment: Alignment.center,
                                      height: double.infinity,
                                      padding: EdgeInsets.all(
                                          15 * globals.scaleParam),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(10),
                                        ),
                                        // color: Colors.white24,
                                      ),
                                      child: Text(
                                        "Доставка",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 38 * globals.scaleParam,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Spacer(),
                                Flexible(
                                  flex: 30,
                                  fit: FlexFit.tight,
                                  child: GestureDetector(
                                    onTap: () {
                                      _controller.forward();
                                      setState(() {
                                        delivery = false;
                                      });
                                    },
                                    child: Container(
                                      alignment: Alignment.center,
                                      height: double.infinity,
                                      padding: EdgeInsets.all(
                                        15 * globals.scaleParam,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(10),
                                        ),
                                        // color: Colors.white24,
                                      ),
                                      child: Text(
                                        "Самовывоз",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 38 * globals.scaleParam,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 100 * globals.scaleParam,
                            margin: EdgeInsets.symmetric(
                              horizontal: 15 * globals.scaleParam,
                              vertical: 20 * globals.scaleParam,
                            ),
                            child: Row(
                              children: [
                                Flexible(
                                  flex: 30,
                                  fit: FlexFit.tight,
                                  child: SlideTransition(
                                    position: _deliveryChooseAnim,
                                    child: Container(
                                      alignment: Alignment.center,
                                      height: double.infinity,
                                      padding: EdgeInsets.all(
                                        15 * globals.scaleParam,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(10),
                                        ),
                                        color: Colors.white,
                                      ),
                                      child: AnimatedSwitcher(
                                          duration: Duration(milliseconds: 300),
                                          transitionBuilder:
                                              (child, animation) {
                                            return FadeTransition(
                                              opacity: animation,
                                              child: child,
                                            );
                                          },
                                          child: Text(
                                            delivery ? "Доставка" : "Самовывоз",
                                            key: ValueKey<bool>(delivery),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 38 * globals.scaleParam,
                                              fontWeight: FontWeight.w600,
                                              // shadows: [
                                              //   Shadow(
                                              //     color: Colors.grey.shade200,
                                              //     blurRadius: 5,
                                              //   ),
                                              // ],
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                          )),
                                    ),
                                  ),
                                ),
                                Spacer(),
                                Flexible(
                                  flex: 30,
                                  fit: FlexFit.tight,
                                  child: SizedBox(),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                      Container(
                        height: 520 * globals.scaleParam,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.all(Radius.circular(10))),
                        margin: EdgeInsets.symmetric(
                          horizontal: 15 * globals.scaleParam,
                        ),
                        padding: EdgeInsets.all(10 * globals.scaleParam),
                        child: ListView.builder(
                          primary: false,
                          shrinkWrap: true,
                          itemCount: widget.items.length,
                          itemBuilder: (context, index) {
                            final item = widget.items[index];

                            return Column(
                              children: [
                                ItemCardNoImage(
                                  element: item,
                                  itemId: item["item_id"],
                                  categoryId: "",
                                  categoryName: "",
                                  scroll: 0,
                                ),
                                widget.items.length - 1 != index
                                    ? Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 32 * globals.scaleParam,
                                          vertical: 10 * globals.scaleParam,
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
                      Container(
                        height: 100 * globals.scaleParam,
                        margin: EdgeInsets.symmetric(
                          horizontal: 15 * globals.scaleParam,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 15 * globals.scaleParam,
                        ),
                        child: Row(
                          children: [
                            Flexible(
                              fit: FlexFit.tight,
                              child: Text(
                                "x ${widget.itemsAmount}",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 38 * globals.scaleParam,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Flexible(
                              flex: 5,
                              fit: FlexFit.tight,
                              child: Text(
                                "В заказе",
                                style: TextStyle(
                                  fontSize: 38 * globals.scaleParam,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Flexible(
                              flex: 2,
                              fit: FlexFit.tight,
                              child: Text(
                                "${globals.formatCost(widget.finalSum.toString()).toString()} ₸",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 38 * globals.scaleParam,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding:
                    EdgeInsets.symmetric(vertical: 20 * globals.scaleParam),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                margin:
                    EdgeInsets.symmetric(horizontal: 20 * globals.scaleParam),
                // This should be null only if widget.user doesn't have any addresses, else there will be widget.user address
                // child: currentAddressWidget ??
                child: currentAddress.isNotEmpty
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Flexible(
                              flex: 4,
                              fit: FlexFit.tight,
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          "Ваш адрес: ${currentAddress["name"]}",
                                          style: TextStyle(
                                            fontSize: 32 * globals.scaleParam,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          currentAddress["address"],
                                          style: TextStyle(
                                            fontSize: 32 * globals.scaleParam,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Flexible(
                              child: Icon(
                                Icons.add_box_rounded,
                                size: 50 * globals.scaleParam,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) {
                                return PickAddressPage(
                                  client: widget.user,
                                  business: widget.business,
                                  isFromCreateOrder: true,
                                );
                              },
                            ),
                          ).then((value) {
                            _getClientAddresses();
                            print(_getAddresses());
                          });
                        },
                      )
                    : TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PickAddressPage(
                                client: widget.user,
                                business: widget.business,
                                isFromCreateOrder: true,
                              ),
                            ),
                          ).then((value) {
                            _getClientAddresses();
                            print(_getAddresses());
                          });
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text(
                              "Добавьте адрес доставки",
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 32 * globals.scaleParam,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                            Icon(
                              Icons.add_box_rounded,
                              color: Theme.of(context).colorScheme.secondary,
                              size: 50 * globals.scaleParam,
                            ),
                          ],
                        ),
                      ),
              ),
              Container(
                height: constraints.maxHeight,
                alignment: Alignment.bottomCenter,
                child: Column(
                  children: [
                    SizedBox(
                      height: 10 * globals.scaleParam,
                    ),
                    isAddressesLoading
                        ? Shimmer.fromColors(
                            baseColor: Theme.of(context)
                                .colorScheme
                                .secondary
                                .withOpacity(0.05),
                            highlightColor:
                                Theme.of(context).colorScheme.secondary,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 20 * globals.scaleParam),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(10)),
                                  color: Colors.white,
                                ),
                                width: double.infinity,
                                height: 100 * globals.scaleParam,
                              ),
                            ),
                          )
                        : delivery
                            ? SizedBox()
                            : Container(
                                padding: EdgeInsets.symmetric(
                                    vertical: 20 * globals.scaleParam),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(10))),
                                margin: EdgeInsets.symmetric(
                                    horizontal: 20 * globals.scaleParam),
                                // This should be null only if widget.user doesn't have any addresses, else there will be widget.user address
                                // child: currentAddressWidget ??
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Flexible(
                                          flex: 4,
                                          fit: FlexFit.tight,
                                          child: Column(
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      "Самовывозом: ${widget.business["name"]}",
                                                      style: TextStyle(
                                                        fontSize: 32 *
                                                            globals.scaleParam,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      widget
                                                          .business["address"],
                                                      style: TextStyle(
                                                        fontSize: 32 *
                                                            globals.scaleParam,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Flexible(
                                          child: Icon(
                                            Icons.add_box_rounded,
                                            size: 50 * globals.scaleParam,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                    delivery
                        ? Container(
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(10))),
                            margin: EdgeInsets.symmetric(
                                horizontal: 20 * globals.scaleParam,
                                vertical: 10 * globals.scaleParam),
                            padding: EdgeInsets.all(30 * globals.scaleParam),
                            child: Row(
                              children: [
                                Flexible(
                                  flex: 2,
                                  fit: FlexFit.tight,
                                  child: Text(
                                    "Доставка:",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 32 * globals.scaleParam,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                ),
                                Flexible(
                                  flex: 2,
                                  fit: FlexFit.tight,
                                  child: Text(
                                    "${widget.deliveryInfo["distance"]} м",
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 32 * globals.scaleParam,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                ),
                                Flexible(
                                  fit: FlexFit.tight,
                                  child: Text(
                                    "-",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 32 * globals.scaleParam,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                ),
                                Flexible(
                                  flex: 2,
                                  fit: FlexFit.tight,
                                  child: Text(
                                    "${widget.deliveryInfo["price"]} ₸",
                                    textAlign: TextAlign.start,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 32 * globals.scaleParam,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : SizedBox(),
                    Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.all(Radius.circular(10))),
                      margin: EdgeInsets.symmetric(
                          horizontal: 20 * globals.scaleParam),
                      padding: EdgeInsets.all(30 * globals.scaleParam),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            onTap: () {
                              showAdaptiveDialog(
                                context: context,
                                builder: (context) {
                                  return StatefulBuilder(
                                    builder: (BuildContext context, setState) {
                                      return AlertDialog(
                                        title: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                "Способ оплаты",
                                                style: TextStyle(
                                                  fontSize:
                                                      48 * globals.scaleParam,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        // content: Column(
                                        //   mainAxisSize: MainAxisSize.min,
                                        //   children: [
                                        //     Row(
                                        //       children: [],
                                        //     ),
                                        //   ],
                                        // ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                globals.getPlatformSpecialRoute(
                                                  const WebViewCardPayPage(),
                                                ),
                                              );
                                            },
                                            child: Container(
                                              padding: EdgeInsets.all(
                                                  20 * globals.scaleParam),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(10),
                                                ),
                                                color: Colors.black12,
                                              ),
                                              child: Row(
                                                children: [
                                                  Flexible(
                                                      flex: 4,
                                                      fit: FlexFit.tight,
                                                      child: Text("Картой")),
                                                  Flexible(
                                                    flex: 2,
                                                    fit: FlexFit.tight,
                                                    child: Icon(Icons
                                                        .credit_card_rounded),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {},
                                            child: Container(
                                              padding: EdgeInsets.all(
                                                  20 * globals.scaleParam),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(10),
                                                ),
                                                color: Colors.black12,
                                              ),
                                              child: Row(
                                                children: [
                                                  Flexible(
                                                      flex: 4,
                                                      fit: FlexFit.tight,
                                                      child: Text(
                                                          "Счёт на каспи")),
                                                  Flexible(
                                                    flex: 2,
                                                    fit: FlexFit.tight,
                                                    child: Icon(Icons
                                                        .smartphone_rounded),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                            child: Container(
                                              padding: EdgeInsets.all(
                                                  20 * globals.scaleParam),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(10),
                                                ),
                                                color: Colors.black12,
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Flexible(
                                                    fit: FlexFit.tight,
                                                    child: Text(
                                                      "Назад",
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              );
                            },
                            child: Column(
                              children: [
                                Text(
                                  widget.user.isEmpty
                                      ? "Счёт на каспи:"
                                      : widget.client.isEmpty
                                          ? "Счёт на каспи: ${widget.user["login"].toString()}" //! TODO: CHANGE IF NOT KASPI BUT CASH
                                          : "Счёт на каспи: ${widget.client["login"].toString()}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 32 * globals.scaleParam,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  "Сумма к оплате: ${globals.formatCost((widget.finalSum + widget.deliveryInfo["price"]).toString()).toString()} ₸",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 32 * globals.scaleParam,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
