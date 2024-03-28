import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/cartPage.dart';
import 'package:numberpicker/numberpicker.dart';
import '../misc/api.dart';

class BuyButton extends StatefulWidget {
  const BuyButton({super.key, required this.element});
  final Map<String, dynamic> element;

  @override
  State<BuyButton> createState() => _BuyButtonState();
}

class _BuyButtonState extends State<BuyButton> {
  Map element = {};
  int cacheAmount = 0;

  Future<void> refreshItemCard() async {
    if (element["item_id"] != null) {
      Map<String, dynamic>? element = await getItem(widget.element["item_id"]);
      setState(() {
        element = element!;
      });
    }
  }

  // TODO: Create changeCartAmount inside api.dart
  // Future<String?> _finalizeCartAmount() async {
  //   String? finalAmount = await changeCartAmount(element["item_id"], cacheAmount).then(
  //     (value) {
  //       print(value);
  //       return value;
  //     },
  //   ).onError(
  //     (error, stackTrace) {
  //       throw Exception("buyButton _addToCart failed");
  //     },
  //   );
  // }

  void _changeCartAmount(int amount) {
    setState(() {
      if (amount >= 0) {
        cacheAmount = amount;
      }
    });
  }

  void _removeFromCart() {
    setState(() {
      if (cacheAmount > 0) {
        cacheAmount--;
      }
    });
  }

  void _addToCart() {
    setState(() {
      if (cacheAmount < 1000) {
        cacheAmount++;
      }
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    // refreshItemCard();
    setState(() {
      element = widget.element;
    });
  }

  @override
  void dispose() {
    super.dispose();
    // _finalizeCartAmount.then();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: [
        cacheAmount != 0
            ? Flexible(
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius:
                          const BorderRadius.all(Radius.circular(10))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Flexible(
                        child: IconButton(
                          padding: const EdgeInsets.all(0),
                          onPressed: () {
                            _removeFromCart();
                          },
                          icon: const Icon(Icons.remove),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          cacheAmount.toString(),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Flexible(
                        child: GestureDetector(
                          child: IconButton(
                            padding: const EdgeInsets.all(0),
                            onPressed: () {
                              _addToCart();
                            },
                            icon: const Icon(Icons.add),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Flexible(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(10),
                      ),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    disabledBackgroundColor: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withOpacity(0.5),
                  ),
                  onPressed: () {
                    _addToCart();
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      FittedBox(
                        fit: BoxFit.fitWidth,
                        child: Text(
                          "В корзину",
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        // isLoading
        //     ? Container(
        //         height: 80,
        //         color: Colors.white,
        //         child: GestureDetector(
        //           onTap: () {
        //             refreshItemCard();
        //           },
        //           child: const Row(
        //             mainAxisAlignment: MainAxisAlignment.center,
        //             mainAxisSize: MainAxisSize.max,
        //             children: [CircularProgressIndicator()],
        //           ),
        //         ),
        //       )
        //     : Container()
      ],
    );
  }
}

class BuyButtonFullWidth extends StatefulWidget {
  const BuyButtonFullWidth({super.key, required this.element});
  final Map<String, dynamic> element;

  @override
  State<BuyButtonFullWidth> createState() => _BuyButtonFullWidthState();
}

class _BuyButtonFullWidthState extends State<BuyButtonFullWidth> {
  Map element = {};
  int cacheAmount = 0;
  bool isNumPickActive = false;
  bool isAmountConfirmed = false;

  // TODO: Create changeCartAmount inside api.dart
  Future<String?> _finalizeCartAmount() async {
    String? finalAmount = await addToCart(element["item_id"], cacheAmount).then(
      (value) {
        print(value);
        return value;
      },
    ).onError(
      (error, stackTrace) {
        throw Exception("buyButton _addToCart failed");
      },
    );
  }

  void _removeFromCart() {
    setState(() {
      isAmountConfirmed = false;
      if (cacheAmount > 0) {
        cacheAmount--;
      }
    });
  }

  void _addToCart() {
    setState(() {
      isAmountConfirmed = false;
      if (cacheAmount < 1000) {
        cacheAmount++;
      }
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    // refreshItemCard();
    setState(() {
      element = widget.element;
      if (element["amount"] != null) {
        cacheAmount = int.parse(element["amount"]);
      } else {
        cacheAmount = 0;
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    // if (element["amount"] != null) {
    //   if (cacheAmount < int.parse(element["amount"])) {
    //     _finalizeCartAmount();
    //   }
    // } else if (cacheAmount != 0) {
    //   _finalizeCartAmount();
    // }
  }

  @override
  Widget build(BuildContext context) {
    return cacheAmount != 0
        ? Container(
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: const BorderRadius.all(Radius.circular(3))),
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                GestureDetector(
                  onLongPress: (() {
                    setState(() {
                      isNumPickActive = true;
                    });
                  }),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: IconButton(
                          padding: const EdgeInsets.all(0),
                          onPressed: () {
                            _removeFromCart();
                          },
                          icon: Icon(
                            Icons.remove_rounded,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      isNumPickActive
                          ? Flexible(
                              child: GestureDetector(
                                onTap: (() {
                                  setState(() {
                                    isNumPickActive = false;
                                  });
                                }),
                                child: NumberPicker(
                                  value: cacheAmount,
                                  textStyle: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  selectedTextStyle: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  itemHeight: 25,
                                  itemWidth: 25,
                                  minValue: 0,
                                  maxValue:
                                      20, // TODO: CHANGE IT TO AMOUNT FROM BACK-END
                                  onChanged: (value) => setState(() {
                                    cacheAmount = value;
                                    if (value == 0) {
                                      isNumPickActive = false;
                                    }
                                  }),
                                ),
                              ),
                            )
                          : Flexible(
                              child: Text(
                                cacheAmount.toString(),
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                      Flexible(
                        child: IconButton(
                          padding: const EdgeInsets.all(0),
                          // style: IconButton.styleFrom(
                          //   shape: const RoundedRectangleBorder(
                          //     borderRadius:
                          //         BorderRadius.all(Radius.circular(12)),
                          //   ),
                          //   side: const BorderSide(
                          //     width: 2.6,
                          //     strokeAlign: -7.0,
                          //   ),
                          // ),
                          onPressed: () {
                            _addToCart();
                          },
                          icon: Icon(
                            Icons.add_rounded,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    element["prev_price"] != null
                        ? Text(
                            element["prev_price"],
                            style: TextStyle(
                                decoration: TextDecoration.lineThrough,
                                decorationColor:
                                    Theme.of(context).colorScheme.onPrimary,
                                decorationThickness: 1.85,
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500),
                          )
                        : Container(),
                    Padding(
                      padding: const EdgeInsets.only(left: 7, right: 5),
                      child: Text(
                        element["price"] ?? "",
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 26,
                            color: Theme.of(context).colorScheme.onPrimary),
                      ),
                    ),
                    Text(
                      "₸",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 30,
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(
                          scale: animation,
                          child: child,
                        );
                      },
                      child: !isAmountConfirmed
                          ? IconButton(
                              key: const Key("add_cart"),
                              onPressed: () {
                                _finalizeCartAmount();
                                setState(() {
                                  isAmountConfirmed = true;
                                });
                                // Navigator.push(context,
                                //     MaterialPageRoute(builder: (context) {
                                //   return const CartPage();
                                // }));
                              },
                              icon: Icon(
                                Icons.add_shopping_cart_rounded,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            )
                          : IconButton(
                              key: const Key("go_cart"),
                              onPressed: () {
                                // _finalizeCartAmount();
                                Navigator.push(context,
                                    MaterialPageRoute(builder: (context) {
                                  return const CartPage();
                                }));
                              },
                              icon: Icon(
                                Icons.shopping_cart_checkout_rounded,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                    ),
                  ],
                )
              ],
            ),
          )
        : ElevatedButton(
            // style: ElevatedButton.styleFrom(
            //   padding: const EdgeInsets.all(10),
            //   backgroundColor: Colors.grey.shade400,
            // ),
            onPressed: () {
              _addToCart();
            },
            child: Container(
              decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(10))),
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Text(
                    "В корзину",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      element["prev_price"] != null
                          ? Text(
                              element["prev_price"],
                              style: TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor:
                                      Theme.of(context).colorScheme.onPrimary,
                                  decorationThickness: 1.85,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500),
                            )
                          : Container(),
                      Padding(
                        padding: const EdgeInsets.only(left: 7, right: 5),
                        child: Text(
                          element["price"] ?? "",
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 26,
                              color: Theme.of(context).colorScheme.onPrimary),
                        ),
                      ),
                      Text(
                        "₸",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 30,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
  }
}
