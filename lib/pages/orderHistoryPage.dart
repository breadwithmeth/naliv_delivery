import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/orderInfoPage.dart';
import 'package:naliv_delivery/pages/webViewCardPayPage.dart';
import '../globals.dart' as globals;
import 'package:naliv_delivery/misc/api.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  List _orders = [];
  Future<List<dynamic>> _getOrders() async {
    List<dynamic> orders = await getOrders();
    print(orders);
    setState(() {
      _orders = orders.reversed.toList();
    });
    return orders;
  }

  String getLocalTime(String dateTime) {
    DateFormat format = DateFormat("yyyy-MM-dd HH:mm:ss");

    DateTime parsedData = format.parse(dateTime);

    return format.format(parsedData);
  }

  String getOrderStatusFormat(String string) {
    if (string == "66") {
      return "Заказ ожидает оплаты";
    } else if (string == "0") {
      return "Заказ отправлен в магазин";
    } else if (string == "1") {
      return "Заказ ожидает сборки";
    } else if (string == "2") {
      return "Заказ собран";
    } else if (string == "3") {
      return "Заказ забрал курьер";
    } else if (string == "4") {
      return "Заказ доставлен";
    } else {
      return "Неизвестный статус";
    }
  }

  Color getOrderColorStatusFormat(String string) {
    if (string == "66") {
      return Colors.red;
    } else if (string == "0") {
      return Colors.yellow;
    } else if (string == "1") {
      return Colors.orange;
    } else if (string == "2") {
      return Colors.green;
    } else if (string == "3") {
      return Colors.blue;
    } else {
      return Colors.white;
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
        floatingActionButton: FloatingActionButton(
            onPressed: () {},
            child: IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: Icon(
                  Icons.close,
                  color: Colors.white,
                ))),
        body: SafeArea(
            child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: kToolbarHeight * 1,
              ),
            ),
            SliverList.builder(
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    showBottomSheet(
                      constraints: BoxConstraints(
                          minHeight: double.infinity,
                          maxHeight: double.infinity),
                      context: context,
                      builder: (context) {
                        return OrderInfoPage(
                          orderId: _orders[index]["order_id"].toString(),
                          clientDeliveryInfo: {
                            "a_name": _orders[index]["a_name"],
                            "a_address": _orders[index]["a_address"]
                          },
                        );
                      },
                    );
                  },
                  child: Card(
                      clipBehavior: Clip.antiAlias,
                      color: Color(0xFF121212),
                      child: Column(
                        children: [
                          Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: getOrderColorStatusFormat(
                                        _orders[index]["order_status"]),
                                    width: 10,
                                  ),
                                ),
                              ),
                              padding: EdgeInsets.all(10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              "#${_orders[index]['order_uuid']}",
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              _orders[index]['b_name']
                                                  .toString(),
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 20,
                                                  color: Colors.white),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              _orders[index]['b_address']
                                                  .toString(),
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.white),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Flexible(
                                      child: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(getOrderStatusFormat(
                                          _orders[index]["order_status"])),
                                      _orders[index]["order_status"] == "66"
                                          ? TextButton(
                                              onPressed: () {
                                                getPaymentPageForUnpaidOrder(
                                                        _orders[index]
                                                            ["order_id"])
                                                    .then((v) {
                                                  Navigator.push(
                                                    context,
                                                    CupertinoPageRoute(
                                                      builder: (context) =>
                                                          WebViewCardPayPage(
                                                        htmlString: v["data"],
                                                      ),
                                                    ),
                                                  );
                                                });
                                              },
                                              child: Container(
                                                padding: EdgeInsets.all(5),
                                                decoration: BoxDecoration(
                                                    // color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.all(
                                                            Radius.circular(
                                                                5))),
                                                child: Text(
                                                  "Оплатить",
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.redAccent),
                                                ),
                                              ))
                                          : Container(),
                                    ],
                                  ))
                                ],
                              )),
                        ],
                      )),
                );
              },
            ),
          ],
        )));
  }
}
