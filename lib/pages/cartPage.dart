import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../globals.dart' as globals;
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
  const CartPage({super.key, required this.business, required this.user});

  final Map<dynamic, dynamic> business;
  final Map user;

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage>
    with SingleTickerProviderStateMixin {
  late List items = [];
  late Map<String, dynamic> cartInfo = {};
  late String sum = "0";
  int localNotFutureBuilderSum = 0;
  late AnimationController animController;
  final Duration animDuration = Duration(milliseconds: 250);
  int localDiscount = 0;
  TextEditingController _promoController = TextEditingController();
  Map<String, dynamic> client = {};
  int distance = 0;
  int bonusSum = 0;

  int price = 0;
  int userBonusPoints = 5000;

  int bonusPercent = 0;

  void changeBonusPercent(int amount) {
    if (0 <= amount && amount <= 30) {
      switch (amount) {
        case 0:
          setState(() {
            bonusPercent = amount;
            bonusSum = (localNotFutureBuilderSum + price) * 0;
          });
          break;
        case 10:
          if (((localNotFutureBuilderSum + price) * 0.1).round() >
              userBonusPoints) {
            return;
          }
          setState(() {
            bonusPercent = amount;
            bonusSum = ((localNotFutureBuilderSum + price) * 0.1).round();
          });
          break;
        case 20:
          if (((localNotFutureBuilderSum + price) * 0.2).round() >
              userBonusPoints) {
            return;
          }
          setState(() {
            bonusPercent = amount;
            bonusSum = ((localNotFutureBuilderSum + price) * 0.2).round();
          });
          break;
        case 30:
          if (((localNotFutureBuilderSum + price) * 0.3).round() >
              userBonusPoints) {
            return;
          }
          setState(() {
            bonusPercent = amount;
            bonusSum = ((localNotFutureBuilderSum + price) * 0.3).round();
          });
          break;
        default:
          print("No, bonus percent can only be [0, 10, 20, 30]");
          break;
      }
    }
  }

  Future<Map<String, dynamic>> _getCart() async {
    Map<String, dynamic> cart = await getCart(widget.business["business_id"]);
    print(cart);

    // Map<String, dynamic>? cartInfo = await getCartInfo();
    print(cartInfo);

    // if (cart["sum"] == null || cart["cart"]) {
    //   return;
    // }

    // setState(() {
    //   items = cart["cart"];
    //   cartInfo = cart;
    //   sum = cart["sum"] ?? "0";
    // });

    return cart;
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

  void updateDataAmount(int newDataAmount, [int index = 0]) {
    setState(() {
      localNotFutureBuilderSum -=
          int.parse(items[index]["price"]) * int.parse(items[index]["amount"]);
      items[index]["amount"] = newDataAmount;
      localNotFutureBuilderSum +=
          int.parse(items[index]["price"]) * int.parse(items[index]["amount"]);
    });
    if (newDataAmount == 0) {
      items.removeAt(index);
    }
  }

  List updatePrices(String localNotFutureBuilderSum, int localDiscount) {
    for (dynamic item in items) {
      localNotFutureBuilderSum +=
          (int.parse(item["price"]) * int.parse(item["amount"])).toString();
      if (item["previous_price"] != null) {
        localDiscount += (int.parse(item["price"]) -
            int.parse(item["previous_price"]) * int.parse(item["amount"]));
      }
    }
    return [localNotFutureBuilderSum, localDiscount];
  }

  // bool isCartLoading = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _setAnimationController();
    // Future.delayed( Duration(milliseconds: 0), () async {
    //   setState(() {
    //     isCartLoading = true;
    //   });
    //   await _getCart();
    //   if (mounted) {
    //     setState(() {
    //       localSum = int.parse(sum);
    //       for (dynamic item in items) {
    //         if (item["previous_price"] != null) {
    //           localDiscount += int.parse(item["price"]) -
    //               int.parse(item["previous_price"] ?? "0");
    //         }
    //       }
    //       isCartLoading = false;
    //     });
    //   }
    //   await getUser().then((value) {
    //     if (value != null && mounted) {
    //       setState(() {
    //         client = value;
    //       });
    //     }
    //   });
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
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
      body: FutureBuilder(
        future: _getCart(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            if (snapshot.data!["cart"].isEmpty) {
              return Center(
                child: Text(
                  "Ваша корзина пуста",
                  style: TextStyle(
                      fontSize: 40 * globals.scaleParam, color: Colors.grey),
                ),
              );
            } else {
              List items = snapshot.data!["cart"];
              print(items);
              String localSum = snapshot.data!["sum"];
              localNotFutureBuilderSum = int.parse(snapshot.data!["sum"]);
              int distance = int.parse(snapshot.data!["distance"].toString());
              double dist = distance / 1000;
              dist = (dist * 2).round() / 2;
              if (dist <= 1.5) {
                price = 700;
              } else {
                if (dist < 5) {
                  price = ((dist - 1.5) * 300 + 700).toInt();
                } else {
                  price = ((dist - 1.5) * 250 + 700).toInt();
                }
              }
              price = (price / 100).round() * 100;
              return ListView(
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
                                List updatedData =
                                    updatePrices(localSum, localDiscount);
                                setState(() {
                                  items.removeAt(index);
                                  localSum = updatedData[0];
                                  localNotFutureBuilderSum =
                                      int.parse(updatedData[0]);
                                  localDiscount = updatedData[1];
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
                              width: 200 * globals.scaleParam,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width:
                                        MediaQuery.of(context).size.width * 0.7,
                                    alignment: Alignment.center,
                                    padding: EdgeInsets.only(right: 10),
                                    color: Colors.grey.shade100,
                                  ),
                                  Container(
                                    width:
                                        MediaQuery.of(context).size.width * 0.3,
                                    alignment: Alignment.center,
                                    padding: EdgeInsets.only(right: 10),
                                    color: Colors.grey.shade100,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                index == 0
                                    ? SizedBox(
                                        height: 20 * globals.scaleParam,
                                      )
                                    : SizedBox(),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  key: Key(items[index]["item_id"]),
                                  child: ItemCardMinimal(
                                    itemId: items[index]["item_id"],
                                    element: items[index],
                                    categoryId: "",
                                    categoryName: "",
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
                                          business: widget.business,
                                          openedFromCart: true,
                                        );
                                      },
                                    ).then((value) {
                                      print("object");
                                    });
                                  },
                                ),
                                items.length - 1 != index
                                    ? Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal:
                                                16 * globals.scaleParam),
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
                  Column(
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: items.length < 4
                            ? (125 * globals.scaleParam) * (4 - items.length)
                            : 0,
                      ),
                      Divider(
                        color: Colors.transparent,
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 40 * globals.scaleParam,
                  ),
                  Divider(),
                  SizedBox(
                    height: 450 * globals.scaleParam,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 40 * globals.scaleParam,
                          vertical: 40 * globals.scaleParam),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Flexible(
                            fit: FlexFit.tight,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 20 * globals.scaleParam),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Flexible(
                                        flex: 10,
                                        fit: FlexFit.tight,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 4),
                                              child: Text(
                                                "Цена без скидки",
                                                textAlign: TextAlign.start,
                                                style: TextStyle(
                                                  fontSize:
                                                      32 * globals.scaleParam,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                            Divider(
                                              height: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Flexible(
                                        flex: 4,
                                        fit: FlexFit.tight,
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                              left: 40 * globals.scaleParam),
                                          child: Text(
                                            "${globals.formatCost(localSum.toString())} ₸", // CHANGE THIS TO REPRESENT SUM WITHOUT DISCOUNT
                                            style: TextStyle(
                                              fontSize: 32 * globals.scaleParam,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Flexible(
                            fit: FlexFit.tight,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 20 * globals.scaleParam),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Flexible(
                                        flex: 10,
                                        fit: FlexFit.tight,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 4),
                                              child: Text(
                                                "Скидка",
                                                textAlign: TextAlign.start,
                                                style: TextStyle(
                                                  fontSize:
                                                      32 * globals.scaleParam,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                            Divider(
                                              height: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Flexible(
                                        flex: 4,
                                        fit: FlexFit.tight,
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                              left: 40 * globals.scaleParam),
                                          child: Text(
                                            "${globals.formatCost(localDiscount.toString())} ₸", // CHANGE THIS TO REPRESENT DISCOUNT
                                            style: TextStyle(
                                              fontSize: 32 * globals.scaleParam,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Flexible(
                            fit: FlexFit.tight,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 20 * globals.scaleParam),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Flexible(
                                        flex: 10,
                                        fit: FlexFit.tight,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 4),
                                              child: Text(
                                                "Доставка",
                                                textAlign: TextAlign.start,
                                                style: TextStyle(
                                                  fontSize:
                                                      32 * globals.scaleParam,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                            Divider(
                                              height: 1,
                                            ),
                                          ],
                                        ),
                                      ), //TODO: перенести расчет цены доставки на бэк
                                      Flexible(
                                        flex: 4,
                                        fit: FlexFit.tight,
                                        child: Row(
                                          children: [
                                            Padding(
                                              padding: EdgeInsets.only(
                                                  left:
                                                      40 * globals.scaleParam),
                                              child: Text(
                                                "${globals.formatCost(price.toString())} ₸",
                                                style: TextStyle(
                                                  fontSize:
                                                      32 * globals.scaleParam,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Flexible(
                            fit: FlexFit.tight,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 20 * globals.scaleParam),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    fit: FlexFit.tight,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Flexible(
                                          flex: 10,
                                          fit: FlexFit.tight,
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 4),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Flexible(
                                                      fit: FlexFit.tight,
                                                      child: Text(
                                                        "Бонусами",
                                                        textAlign:
                                                            TextAlign.start,
                                                        style: TextStyle(
                                                          fontSize: 32 *
                                                              globals
                                                                  .scaleParam,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Divider(
                                                height: 1,
                                              ),
                                            ],
                                          ),
                                        ), //TODO: перенести расчет цены доставки на бэк
                                        Flexible(
                                          flex: 4,
                                          fit: FlexFit.tight,
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal:
                                                  10 * globals.scaleParam,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                Flexible(
                                                  fit: FlexFit.tight,
                                                  child: Padding(
                                                    padding: EdgeInsets.only(
                                                        left: 9 *
                                                            globals.scaleParam),
                                                    child: ElevatedButton(
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                          horizontal: 5 *
                                                              globals
                                                                  .scaleParam,
                                                        ),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.all(
                                                            Radius.circular(8),
                                                          ),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Flexible(
                                                            child: Text(
                                                              "${globals.formatCost(bonusSum.toString())} ₸",
                                                              style: TextStyle(
                                                                fontSize: 34 *
                                                                    globals
                                                                        .scaleParam,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      onPressed: () {
                                                        showAdaptiveDialog(
                                                          context: context,
                                                          builder: (context) {
                                                            return StatefulBuilder(
                                                              builder:
                                                                  (BuildContext
                                                                          context,
                                                                      setState) {
                                                                return AlertDialog(
                                                                  title: Row(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .center,
                                                                    children: [
                                                                      Flexible(
                                                                        child:
                                                                            Text(
                                                                          "Сколько оплатить бонусами?",
                                                                          textAlign:
                                                                              TextAlign.center,
                                                                          style:
                                                                              TextStyle(
                                                                            fontSize:
                                                                                48 * globals.scaleParam,
                                                                            fontWeight:
                                                                                FontWeight.w700,
                                                                            color:
                                                                                Colors.black,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  content:
                                                                      Column(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    children: [
                                                                      Row(
                                                                        children: [
                                                                          Text(
                                                                            "Ваши бонусы: ${userBonusPoints.toString()}",
                                                                            style:
                                                                                TextStyle(
                                                                              fontSize: 38 * globals.scaleParam,
                                                                              fontWeight: FontWeight.w500,
                                                                              color: Colors.black,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  actions: [
                                                                    Column(
                                                                      children: [
                                                                        Row(
                                                                          mainAxisAlignment:
                                                                              MainAxisAlignment.spaceEvenly,
                                                                          children: [
                                                                            Flexible(
                                                                              child: Container(
                                                                                decoration: bonusPercent == 0
                                                                                    ? BoxDecoration(
                                                                                        borderRadius: BorderRadius.all(Radius.circular(10)),
                                                                                        color: Colors.black12,
                                                                                      )
                                                                                    : null,
                                                                                child: TextButton(
                                                                                  onPressed: () {
                                                                                    setState(
                                                                                      () {},
                                                                                    );
                                                                                    changeBonusPercent(0);
                                                                                  },
                                                                                  child: Text(
                                                                                    "0%",
                                                                                    style: TextStyle(
                                                                                      fontSize: 36 * globals.scaleParam,
                                                                                      fontWeight: FontWeight.w700,
                                                                                      color: Colors.black,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            Flexible(
                                                                              child: Container(
                                                                                decoration: bonusPercent == 10
                                                                                    ? BoxDecoration(
                                                                                        borderRadius: BorderRadius.all(Radius.circular(10)),
                                                                                        color: Colors.black12,
                                                                                      )
                                                                                    : null,
                                                                                child: TextButton(
                                                                                  onPressed: () {
                                                                                    setState(
                                                                                      () {},
                                                                                    );
                                                                                    changeBonusPercent(10);
                                                                                  },
                                                                                  child: Text(
                                                                                    "10%",
                                                                                    style: TextStyle(
                                                                                      fontSize: 36 * globals.scaleParam,
                                                                                      fontWeight: FontWeight.w700,
                                                                                      color: Colors.black,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            Flexible(
                                                                              child: Container(
                                                                                decoration: bonusPercent == 20
                                                                                    ? BoxDecoration(
                                                                                        borderRadius: BorderRadius.all(Radius.circular(10)),
                                                                                        color: Colors.black12,
                                                                                      )
                                                                                    : null,
                                                                                child: TextButton(
                                                                                  onPressed: () {
                                                                                    setState(
                                                                                      () {},
                                                                                    );
                                                                                    changeBonusPercent(20);
                                                                                  },
                                                                                  child: Text(
                                                                                    "20%",
                                                                                    style: TextStyle(
                                                                                      fontSize: 36 * globals.scaleParam,
                                                                                      fontWeight: FontWeight.w700,
                                                                                      color: Colors.black,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            Flexible(
                                                                              child: Container(
                                                                                decoration: bonusPercent == 30
                                                                                    ? BoxDecoration(
                                                                                        borderRadius: BorderRadius.all(Radius.circular(10)),
                                                                                        color: Colors.black12,
                                                                                      )
                                                                                    : null,
                                                                                child: TextButton(
                                                                                  onPressed: () {
                                                                                    setState(
                                                                                      () {},
                                                                                    );
                                                                                    changeBonusPercent(30);
                                                                                  },
                                                                                  child: Text(
                                                                                    "30%",
                                                                                    style: TextStyle(
                                                                                      fontSize: 36 * globals.scaleParam,
                                                                                      fontWeight: FontWeight.w700,
                                                                                      color: Colors.black,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                        Padding(
                                                                          padding:
                                                                              EdgeInsets.only(top: 20 * globals.scaleParam),
                                                                          child:
                                                                              Row(
                                                                            mainAxisAlignment:
                                                                                MainAxisAlignment.spaceBetween,
                                                                            children: [
                                                                              IconButton(
                                                                                onPressed: () {
                                                                                  Navigator.pop(context);
                                                                                },
                                                                                icon: Container(
                                                                                  padding: EdgeInsets.all(35 * globals.scaleParam),
                                                                                  decoration: BoxDecoration(
                                                                                    color: Colors.red,
                                                                                    borderRadius: BorderRadius.all(Radius.circular(100)),
                                                                                  ),
                                                                                  child: Icon(
                                                                                    Icons.close_rounded,
                                                                                    color: Colors.white,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              IconButton(
                                                                                onPressed: () {
                                                                                  Navigator.pop(context);
                                                                                },
                                                                                icon: Container(
                                                                                  padding: EdgeInsets.all(35 * globals.scaleParam),
                                                                                  decoration: BoxDecoration(
                                                                                    color: Colors.green,
                                                                                    borderRadius: BorderRadius.all(Radius.circular(100)),
                                                                                  ),
                                                                                  child: Icon(
                                                                                    Icons.check_rounded,
                                                                                    color: Colors.white,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    )
                                                                  ],
                                                                );
                                                              },
                                                            );
                                                          },
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ],
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
                          Flexible(
                            fit: FlexFit.tight,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 20 * globals.scaleParam,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Flexible(
                                    flex: 10,
                                    fit: FlexFit.tight,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(left: 4),
                                          child: Text(
                                            "Итого",
                                            textAlign: TextAlign.start,
                                            style: TextStyle(
                                              fontSize: 32 * globals.scaleParam,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                        Divider(
                                          height: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Flexible(
                                    flex: 4,
                                    fit: FlexFit.tight,
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                          left: 40 * globals.scaleParam),
                                      child: Text(
                                        "${globals.formatCost((int.parse(localSum) + price).toString())} ₸",
                                        style: TextStyle(
                                          fontSize: 32 * globals.scaleParam,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 20 * globals.scaleParam,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 30 * globals.scaleParam),
                    child: ElevatedButton(
                      onPressed: () {
                        // Navigator.push(
                        //   context,
                        //   MaterialPageRoute(
                        //     builder: (context) {
                        //       return FindCreateUserPage(
                        //         business: widget.business,
                        //       );
                        //     },
                        //   ),
                        // );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) {
                              return CreateOrderPage(
                                business: widget.business,
                                finalSum: (int.parse(localSum) + price),
                                items: items,
                                user: widget.user,
                                deliveryInfo: Map.from(
                                  {"distance": distance, "price": price},
                                ),
                              );
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
                                fontSize: 36 * globals.scaleParam,
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
                          padding: EdgeInsets.all(0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(10),
                            ),
                          ),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(10),
                                  ),
                                ),
                                backgroundColor:
                                    Theme.of(context).colorScheme.background,
                                surfaceTintColor: Colors.transparent,
                                elevation: 0.0,
                                title: Text(
                                  "Промокод",
                                  style: TextStyle(
                                    fontSize: 48 * globals.scaleParam,
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
                                      decoration: InputDecoration(
                                        border: UnderlineInputBorder(),
                                      ),
                                    ),
                                    SizedBox(
                                      height: 30 * globals.scaleParam,
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 30 * globals.scaleParam,
                                            vertical: 30 * globals.scaleParam),
                                      ),
                                      onPressed: () {
                                        print(
                                            "Добавить функционал промо-кодов");
                                      },
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "Подтвердить",
                                            style: TextStyle(
                                              fontSize: 36 * globals.scaleParam,
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
                            fontSize: 28 * globals.scaleParam,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }
          } else if (snapshot.hasError) {
            return Center(
              child: SizedBox(
                width: 350 * globals.scaleParam,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        "Произошла ошибка при загрузке корзины.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 40 * globals.scaleParam,
                            color: Colors.grey),
                      ),
                    ),
                    Flexible(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {});
                        },
                        child: Text(
                          "Повторить",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 40 * globals.scaleParam),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            return LinearProgressIndicator();
          }
        },
      ),
      // : Center(
      //     child: Column(
      //       mainAxisSize: MainAxisSize.min,
      //       children: [
      //         SizedBox(
      //           width: MediaQuery.of(context).size.width * 0.8,
      //           child: Text(
      //             "Ваша корзина пуста",
      //             textAlign: TextAlign.center,
      //             style: TextStyle(
      //               color: Theme.of(context).colorScheme.secondary,
      //               fontSize: 16,
      //               fontWeight: FontWeight.w500,
      //             ),
      //           ),
      //         ),
      //       ],
      //     ),
      //   ),
    );
  }
}
