import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naliv_delivery/globals.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/misc/databaseapi.dart';
import 'package:naliv_delivery/pages/createOrderPage2.dart';
import 'package:naliv_delivery/pages/preLoadOrderPage.dart';
import 'package:naliv_delivery/shared/changeAmountButton.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key, required this.business, required this.user});
  final Map<dynamic, dynamic> business;
  final Map user;
  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  DatabaseManager dbm = DatabaseManager();
  List items = [];
  double sum = 0;
  int deliveryPrice = 0;
  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  updateAmount(double newAmount, int index, int item_id) async {
    await dbm
        .updateAmount(
            int.parse(widget.business["business_id"]), item_id, newAmount)
        .then((v) {
      print(v);
      setState(() {
        items[index] = v;
      });
    });
    // if (widget.refreshCart != null) {
    //   widget.refreshCart!();
    // }
  }

  _getDeliveryPrice() async {
    await getDeliveyPrice(widget.business["business_id"]).then((v) {
      setState(() {
        deliveryPrice = int.parse(v["price"]);
      });
    });
  }

  getCartSum() async {
    await dbm.getCartTotal(int.parse(widget.business["business_id"])).then((v) {
      setState(() {
        sum = v;
      });
    });
  }

  getCartItems() async {
    print("checl");
    await dbm
        .getAllItemsInCart(int.parse(widget.business["business_id"]))
        .then((v) {
      print(v);
      List _items = [];
      v.forEach((e) {
        _items.add(Map.from(e));
      });
      setState(() {
        items.clear();
        items = _items;
        ;
      });
    });
  }

  Function? update() {
    // getCartItems();
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getCartItems();
    getCartSum();
    _getDeliveryPrice();
    dbm.cartUpdates.listen((onData) {
      getCartItems();
      getCartSum();
      if (onData != null) {
        //
      }
    });
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Корзина'),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            // Список товаров
            CustomScrollView(
              physics: BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Сумма заказа',
                              style: TextStyle(
                                color: CupertinoColors.secondaryLabel,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              formatPrice(sum.toInt()),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        if (deliveryPrice > 0)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Доставка и сервис',
                                style: TextStyle(
                                  color: CupertinoColors.secondaryLabel,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                formatPrice(deliveryPrice),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Column(
                      children: [
                        Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      items[index]["name"] ?? "",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (items[index]["option_name"] != null)
                                      Text(
                                        items[index]["option_name"],
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: CupertinoColors.secondaryLabel,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      if (items[index]["parent_amount"] ==
                                          null) {
                                        updateAmount(
                                          items[index]["amount"] -
                                              items[index]["quantity"],
                                          index,
                                          items[index]["item_id"],
                                        );
                                      } else {
                                        updateAmount(
                                          items[index]["amount"] -
                                              (items[index]["quantity"] *
                                                  items[index]
                                                      ["parent_amount"]!),
                                          index,
                                          items[index]["item_id"],
                                        );
                                      }
                                    },
                                    child:
                                        Icon(CupertinoIcons.minus_circle_fill),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    formatQuantity(
                                        double.parse(
                                            items[index]["amount"].toString()),
                                        "ед"),
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      if (items[index]["parent_amount"] ==
                                          null) {
                                        updateAmount(
                                          items[index]["amount"] +
                                              items[index]["quantity"],
                                          index,
                                          items[index]["item_id"],
                                        );
                                      } else {
                                        updateAmount(
                                          items[index]["amount"] +
                                              (items[index]["quantity"] *
                                                  items[index]
                                                      ["parent_amount"]!),
                                          index,
                                          items[index]["item_id"],
                                        );
                                      }
                                    },
                                    child:
                                        Icon(CupertinoIcons.plus_circle_fill),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1),
                      ],
                    ),
                    childCount: items.length,
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),

            // Кнопка оформления заказа
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.activeOrange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) => PreLoadOrderPage(
                          business: widget.business,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'Оформить заказ',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
