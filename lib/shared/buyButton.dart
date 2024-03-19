import 'package:flutter/material.dart';
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
    return Stack(
      children: [
        cacheAmount != 0
            ? Container(
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: const BorderRadius.all(Radius.circular(10))),
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Container(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius:
                                const BorderRadius.all(Radius.circular(10))),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: IconButton(
                                padding: const EdgeInsets.all(0),
                                onPressed: () {
                                  _removeFromCart();
                                },
                                icon: const Icon(
                                  Icons.remove_rounded,
                                  color: Colors.black,
                                  grade: 2.5,
                                ),
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
                                icon: const Icon(
                                  Icons.add_rounded,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                                    decorationColor: Colors.grey.shade500,
                                    decorationThickness: 1.85,
                                    color: Colors.grey.shade500,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500),
                              )
                            : Container(),
                        Padding(
                          padding: const EdgeInsets.only(left: 7, right: 5),
                          child: Text(
                            element["price"] ?? "",
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 26,
                                color: Colors.black),
                          ),
                        ),
                        Text(
                          "₸",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w900,
                            fontSize: 30,
                          ),
                        )
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
                style: ElevatedButton.styleFrom(
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(10),
                    ),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  disabledBackgroundColor:
                      Theme.of(context).colorScheme.secondary.withOpacity(0.8),
                ),
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
                      const Text(
                        "В корзину",
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: Colors.black),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          element["prev_price"] != null
                              ? Text(
                                  element["prev_price"],
                                  style: TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      decorationColor: Colors.grey.shade500,
                                      decorationThickness: 1.85,
                                      color: Colors.grey.shade500,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500),
                                )
                              : Container(),
                          Padding(
                            padding: const EdgeInsets.only(left: 7, right: 5),
                            child: Text(
                              element["price"] ?? "",
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 26,
                                  color: Colors.black),
                            ),
                          ),
                          Text(
                            "₸",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w900,
                              fontSize: 30,
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ],
    );
  }
}
