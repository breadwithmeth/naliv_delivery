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
    return DraggableScrollableSheet(
      builder: (context, scrollController) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 15, horizontal: 5),
          decoration: BoxDecoration(
              color: Color(0xFF121212),
              borderRadius: BorderRadius.all(Radius.circular(30))),
          child: Scaffold(
            backgroundColor: Color(0xFF121212),
            floatingActionButton: GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) {
                      return PreLoadOrderPage(
                        business: widget.business,
                      );
                    },
                  ));
                },
                child: Container(
                    decoration: BoxDecoration(
                        color: Colors.deepOrange,
                        borderRadius: BorderRadius.all(Radius.circular(15))),
                    padding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                    margin: EdgeInsets.symmetric(vertical: 5, horizontal: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Продолжить",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ))),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerFloat,
            body: ListView(
              controller: scrollController,
              shrinkWrap: true,
              primary: false,
              children: [
                // Text(items.toString()),
                Container(
                  padding: EdgeInsets.all(15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Корзина",
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            formatPrice(sum.toInt()),
                            style: GoogleFonts.inter(
                                fontSize: 25, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      deliveryPrice == 0
                          ? Container()
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "Доставка и сервис",
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  formatPrice(deliveryPrice),
                                  style: GoogleFonts.inter(
                                      fontSize: 25,
                                      fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                    ],
                  ),
                ),
                ListView.builder(
                  primary: false,
                  shrinkWrap: true,
                  itemCount: items.length,
                  physics: NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    return index.runtimeType == int
                        ? ListTile(
                            dense: false,
                            title: Text(
                              items[index]["name"] ?? "",
                              style: TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              items[index]["option_name"] ?? "",
                              style: TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                    onPressed: () {
                                      if (items[index]["parent_amount"] ==
                                          null) {
                                        updateAmount(
                                            items[index]["amount"] -
                                                items[index]["quantity"],
                                            index,
                                            items[index]["item_id"]);
                                      } else {
                                        updateAmount(
                                            items[index]["amount"] -
                                                (items[index]["quantity"] *
                                                    items[index]
                                                        ["parent_amount"]!),
                                            index,
                                            items[index]["item_id"]);
                                      }
                                    },
                                    icon: Icon(
                                      Icons.remove,
                                      color: Colors.grey.shade300,
                                    )),
                                Text(
                                  formatQuantity(items[index]["amount"], "ед"),
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                                IconButton(
                                    onPressed: () {
                                      print(items[index]);
                                      if (items[index]["parent_amount"] ==
                                          null) {
                                        updateAmount(
                                            items[index]["amount"] +
                                                items[index]["quantity"],
                                            index,
                                            items[index]["item_id"]);
                                      } else {
                                        updateAmount(
                                            items[index]["amount"] +
                                                (items[index]["quantity"] *
                                                    items[index]
                                                        ["parent_amount"]!),
                                            index,
                                            items[index]["item_id"]);
                                      }
                                    },
                                    icon: Icon(
                                      Icons.add,
                                      color: Colors.white,
                                    )),
                              ],
                            ))
                        : Container();
                  },
                ),
                SizedBox(
                  height: 500,
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
