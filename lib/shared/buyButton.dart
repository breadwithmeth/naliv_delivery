import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../misc/api.dart';

class BuyButton extends StatefulWidget {
  const BuyButton({super.key, required this.element});
  final Map<String, dynamic> element;

  @override
  State<BuyButton> createState() => _BuyButtonState();
}

class _BuyButtonState extends State<BuyButton> {
  Map element = {};
  bool isLoading = true;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    refreshItemCard();
    setState(() {
      element = widget.element;
      isLoading = false;
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

  Future<String?> _removeFromCart() async {
    setState(() {
      isLoading = true;
    });
    String? amount = await removeFromCart(element["item_id"]).then(
      (value) {
        print(value);
        return value;
      },
    ).onError(
      (error, stackTrace) {
        throw Exception("buyButton _removeFromCart failed");
      },
    );
    setState(() {
      element["amount"] = amount;
      isLoading = false;
    });
    return null;
  }

  Future<String?> _addToCart() async {
    setState(() {
      isLoading = true;
    });
    String? amount = await addToCart(element["item_id"]).then(
      (value) {
        print(value);
        return value;
      },
    ).onError(
      (error, stackTrace) {
        throw Exception("buyButton _addToCart failed");
      },
    );
    setState(() {
      element["amount"] = amount;
      isLoading = false;
    });
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: [
        element["amount"] != null
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
                          onPressed: !isLoading
                              ? () async {
                                  await _removeFromCart();
                                }
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          element["amount"].toString(),
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
                          onPressed: !isLoading
                              ? () async {
                                  await _addToCart();
                                }
                              : null,
                          icon: const Icon(Icons.add),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Flexible(
                child: ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: MaterialStatePropertyAll(
                        Theme.of(context).colorScheme.secondary),
                    shape: const MaterialStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(
                          Radius.circular(10),
                        ),
                      ),
                    ),
                    elevation: const MaterialStatePropertyAll(0.0),
                  ),
                  onPressed: () async {
                    await _addToCart();
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
  bool isLoading = true;

  Future<void> refreshItemCard() async {
    if (element["item_id"] != null) {
      Map<String, dynamic>? element = await getItem(widget.element["item_id"]);
      setState(() {
        element = element!;
      });
    }
  }

  Future<String?> _removeFromCart() async {
    setState(() {
      isLoading = true;
    });
    String? amount = await removeFromCart(element["item_id"]).then(
      (value) {
        print(value);
        return value;
      },
    ).onError(
      (error, stackTrace) {
        throw Exception("buyButton _removeFromCart failed");
      },
    );
    setState(() {
      element["amount"] = amount;
      isLoading = false;
    });
    return null;
  }

  Future<String?> _addToCart() async {
    setState(() {
      isLoading = true;
    });
    String? amount = await addToCart(element["item_id"]).then(
      (value) {
        print(value);
        return value;
      },
    ).onError(
      (error, stackTrace) {
        throw Exception("buyButton _addToCart failed");
      },
    );
    setState(() {
      element["amount"] = amount;
      isLoading = false;
    });
    return null;
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    setState(() {
      element = widget.element;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        element["amount"] != null
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
                                onPressed: !isLoading
                                    ? () async {
                                        await _removeFromCart();
                                      }
                                    : null,
                                icon: const Icon(
                                  Icons.remove_rounded,
                                  color: Colors.black,
                                  grade: 2.5,
                                ),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                element["amount"].toString(),
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
                                onPressed: !isLoading
                                    ? () async {
                                        await _addToCart();
                                      }
                                    : null,
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
                style: ButtonStyle(
                  backgroundColor: MaterialStatePropertyAll(
                      Theme.of(context).colorScheme.secondary),
                  shape: const MaterialStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(10),
                      ),
                    ),
                  ),
                  elevation: const MaterialStatePropertyAll(0.0),
                ),
                onPressed: !isLoading
                    ? () {
                        _addToCart();
                      }
                    : null,
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
