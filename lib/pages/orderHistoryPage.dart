import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/orderDetailsSheet.dart';
import 'package:naliv_delivery/pages/orderInfoPage.dart';
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
    //print(orders);
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

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case "66":
        return {
          'text': "Ожидает оплаты",
          'color': CupertinoColors.systemRed,
        };
      case "0":
        return {
          'text': "Отправлен в магазин",
          'color': CupertinoColors.activeOrange,
        };
      case "1":
        return {
          'text': "Ожидает сборки",
          'color': CupertinoColors.activeOrange,
        };
      case "2":
        return {
          'text': "Собран",
          'color': CupertinoColors.systemGreen,
        };
      case "3":
        return {
          'text': "У курьера",
          'color': CupertinoColors.activeBlue,
        };
      case "4":
        return {
          'text': "Доставлен",
          'color': CupertinoColors.systemGreen,
        };
      default:
        return {
          'text': "Неизвестный статус",
          'color': CupertinoColors.systemGrey,
        };
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
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('История заказов'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: Icon(CupertinoIcons.xmark_circle_fill),
        ),
      ),
      child: ListView.builder(
        padding: EdgeInsets.only(top: 90),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          final statusInfo = _getStatusInfo(order["order_status"]);

          return GestureDetector(
            onTap: () {
              showCupertinoModalPopup(
                context: context,
                builder: (context) => Container(
                  height: MediaQuery.of(context).size.height * 0.7,
                  decoration: BoxDecoration(
                    color:
                        CupertinoColors.systemBackground.resolveFrom(context),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: OrderDetailsSheet(order: order),
                ),
              );
            },
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: CupertinoColors.secondarySystemBackground
                    .resolveFrom(context),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: statusInfo['color'],
                      width: 4,
                    ),
                  ),
                ),
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "#${order['order_uuid']}",
                          style: TextStyle(
                            color: CupertinoColors.systemGrey,
                            fontSize: 13,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusInfo['color'].withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusInfo['text'],
                            style: TextStyle(
                              color: statusInfo['color'],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      order['b_name'].toString(),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      order['b_address'].toString(),
                      style: TextStyle(
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                    if (order["order_status"] == "66") ...[
                      SizedBox(height: 12),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () async {
                          final paymentData =
                              await getPaymentPageForUnpaidOrder(
                            order["order_id"],
                          );
                          // Handle payment...
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Оплатить',
                            style: TextStyle(
                              color: CupertinoColors.systemRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
