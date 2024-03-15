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

  Future<void> _addToCard() async {
    setState(() {
      isLoading = true;
    });
    String? amount = await addToCart(element["item_id"]).then((value) {
      print(value);
      setState(() {
        element["amount"] = value;
        isLoading = false;
      });
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Stack(
        children: [
          element["amount"] != null
              ? Container(
                  alignment: Alignment.centerLeft,
                  width: MediaQuery.of(context).size.width * 0.3,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(10))),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          padding: const EdgeInsets.all(0),
                          onPressed: !isLoading
                              ? () async {
                                  String? amount =
                                      await removeFromCart(element["item_id"]);
                                  setState(() {
                                    element["amount"] = amount;
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        Text(
                          element["amount"].toString(),
                          style: const TextStyle(color: Colors.black),
                        ),
                        IconButton(
                          padding: const EdgeInsets.all(0),
                          onPressed: !isLoading
                              ? () {
                                  _addToCard();
                                }
                              : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ),
                )
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade400),
                  onPressed: () {
                    _addToCard();
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text(
                        "В корзину",
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: Colors.black),
                      ),
                    ],
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
      ),
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
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
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

  Future<void> _addToCard() async {
    setState(() {
      isLoading = true;
    });
    String? amount = await addToCart(element["item_id"]).then((value) {
      print(value);
      setState(() {
        element["amount"] = value;
        isLoading = false;
      });
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Stack(
        children: [
          element["amount"] != null
              ? Container(
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius:
                          const BorderRadius.all(Radius.circular(15))),
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        flex: 1,
                        child: Container(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: const BorderRadius.all(
                                    Radius.circular(10))),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  padding: const EdgeInsets.all(0),
                                  onPressed: !isLoading
                                      ? () async {
                                          String? amount = await removeFromCart(
                                              element["item_id"]);
                                          setState(() {
                                            element["amount"] = amount;
                                          });
                                        }
                                      : null,
                                  icon: const Icon(Icons.remove),
                                ),
                                Text(
                                  element["amount"].toString(),
                                  style: const TextStyle(color: Colors.black),
                                ),
                                IconButton(
                                  padding: const EdgeInsets.all(0),
                                  onPressed: !isLoading
                                      ? () {
                                          _addToCard();
                                        }
                                      : null,
                                  icon: const Icon(Icons.add),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Flexible(
                        fit: FlexFit.loose,
                        child: Row(
                          children: [
                            element["prev_price"] != null
                                ? Text(
                                    element["prev_price"],
                                    style: const TextStyle(
                                        decoration: TextDecoration.lineThrough),
                                  )
                                : Container(),
                            const SizedBox(
                              width: 5,
                            ),
                            Text(
                              element["price"] ?? "",
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 26,
                                  color: Colors.black),
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                )
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(10),
                      backgroundColor: Colors.grey.shade400),
                  onPressed: () {
                    _addToCard();
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      const Text(
                        "В корзину",
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: Colors.black),
                      ),
                      Row(
                        children: [
                          element["prev_price"] != null
                              ? Text(
                                  element["prev_price"],
                                  style: TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.grey.shade500),
                                )
                              : Container(),
                          const SizedBox(
                            width: 5,
                          ),
                          Text(
                            element["price"] ?? "",
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 26,
                                color: Colors.black),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}
