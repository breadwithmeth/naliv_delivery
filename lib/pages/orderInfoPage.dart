import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import '../globals.dart' as globals;

class OrderInfoPage extends StatefulWidget {
  const OrderInfoPage({super.key, required this.orderId, required this.clientDeliveryInfo});

  final String orderId;
  final Map clientDeliveryInfo;

  @override
  State<OrderInfoPage> createState() => _OrderInfoPageState();
}

class _OrderInfoPageState extends State<OrderInfoPage> {
  Map order = {};

  String getOrderStatusText(int status) {
    switch (status) {
      case 66:
        return "Ожидает оплаты";
      case 0:
        return "Обрабатывается";
      case 1:
        return "Принят в обработку";
      case 2:
        return "Собирается";
      case 3:
        return "У курьера";
      case 4:
        return "Доставлен";
      default:
        return "Ошибка";
    }
  }

  Color getOrderStatusColor(int status) {
    switch (status) {
      case 66:
        return Colors.red; // Ожидает оплаты
      case 0:
        return Colors.blueGrey; // Обработка
      case 1:
        return Colors.orange; // Получен
      case 2:
        return Colors.lightBlue; // Собирается
      case 3:
        return Colors.blue; // У курьера
      case 4:
        return Colors.green; // Доставлен
      default:
        return Colors.amber; // Ошибка
    }
  }

  bool isOrderLoaded = false;

  @override
  void initState() {
    super.initState();

    getOrders(widget.orderId).then(
      (value) {
        setState(() {
          order = value[0];
          isOrderLoaded = true;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          "Заказ ${widget.orderId}",
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.close),
          )
        ],
      ),
      body: order.isNotEmpty
          ? LayoutBuilder(builder: (context, constraints) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      width: constraints.maxWidth,
                      height: 150 * globals.scaleParam,
                      margin: EdgeInsets.all(15 * globals.scaleParam),
                      padding: EdgeInsets.symmetric(vertical: 10 * globals.scaleParam, horizontal: 35 * globals.scaleParam),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(15)),
                        color: Colors.white,
                      ),
                      child: LayoutBuilder(builder: (context, constraints) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              fit: FlexFit.tight,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Flexible(
                                    fit: FlexFit.tight,
                                    child: Text(
                                      order["b_name"].toString(),
                                      textAlign: TextAlign.start,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontVariations: <FontVariation>[FontVariation('wght', 600)],
                                        fontSize: 36 * globals.scaleParam,
                                      ),
                                    ),
                                  ),
                                  Flexible(
                                    fit: FlexFit.tight,
                                    child: Text(
                                      order["b_address"].toString(),
                                      textAlign: TextAlign.start,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontVariations: <FontVariation>[FontVariation('wght', 600)],
                                        fontSize: 36 * globals.scaleParam,
                                        height: 3 * globals.scaleParam,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Flexible(
                              fit: FlexFit.tight,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  widget.clientDeliveryInfo["a_address"] != null
                                      ? Flexible(
                                          child: Text(
                                            widget.clientDeliveryInfo["a_address"].toString(),
                                            textAlign: TextAlign.start,
                                            maxLines: 3,
                                            style: TextStyle(
                                              overflow: TextOverflow.ellipsis,
                                              color: Theme.of(context).colorScheme.onSurface,
                                              fontVariations: <FontVariation>[FontVariation('wght', 600)],
                                              fontSize: 36 * globals.scaleParam,
                                              height: 3 * globals.scaleParam,
                                            ),
                                          ),
                                        )
                                      : Flexible(
                                          child: Text(
                                            "Самовывоз",
                                            textAlign: TextAlign.start,
                                            style: TextStyle(
                                              overflow: TextOverflow.ellipsis,
                                              color: Theme.of(context).colorScheme.onSurface,
                                              fontVariations: <FontVariation>[FontVariation('wght', 600)],
                                              fontSize: 36 * globals.scaleParam,
                                            ),
                                          ),
                                        ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                    Container(
                      width: constraints.maxWidth,
                      height: 120 * globals.scaleParam,
                      margin: EdgeInsets.only(bottom: 0, left: 15 * globals.scaleParam, right: 15 * globals.scaleParam),
                      padding: EdgeInsets.symmetric(vertical: 10 * globals.scaleParam, horizontal: 35 * globals.scaleParam),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(15)),
                        color: Colors.white,
                      ),
                      child: Row(
                        children: [
                          Flexible(
                            fit: FlexFit.tight,
                            child: Text(
                              "Статус:",
                              style: TextStyle(
                                overflow: TextOverflow.ellipsis,
                                color: Theme.of(context).colorScheme.onSurface,
                                fontVariations: <FontVariation>[FontVariation('wght', 600)],
                                fontSize: 34 * globals.scaleParam,
                              ),
                            ),
                          ),
                          Flexible(
                            fit: FlexFit.tight,
                            child: Center(
                              child: Text(
                                getOrderStatusText(int.parse(order["order_status"])),
                                style: TextStyle(
                                  fontVariations: <FontVariation>[FontVariation('wght', 600)],
                                  overflow: TextOverflow.ellipsis,
                                  color: getOrderStatusColor(int.parse(order["order_status"])),
                                  fontSize: 34 * globals.scaleParam,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: constraints.maxWidth,
                      height: 650 * globals.scaleParam,
                      margin: EdgeInsets.all(15 * globals.scaleParam),
                      padding: EdgeInsets.symmetric(vertical: 10 * globals.scaleParam, horizontal: 35 * globals.scaleParam),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(15)),
                        color: Colors.white,
                      ),
                      child: ListView.builder(
                        physics: RangeMaintainingScrollPhysics(),
                        itemCount: order["order_item"]["items"].length ?? 0,
                        itemBuilder: (context, index) {
                          return Container(
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 100 * globals.scaleParam,
                                  child: Row(
                                    children: [
                                      Flexible(
                                        flex: 5,
                                        fit: FlexFit.tight,
                                        child: Text(
                                          order["order_item"]["items"][index]["name"].toString(),
                                          maxLines: 2,
                                          style: TextStyle(
                                            overflow: TextOverflow.ellipsis,
                                            color: Theme.of(context).colorScheme.onSurface,
                                            fontVariations: <FontVariation>[FontVariation('wght', 600)],
                                            fontSize: 32 * globals.scaleParam,
                                          ),
                                        ),
                                      ),
                                      Flexible(
                                        fit: FlexFit.tight,
                                        child: Text(
                                          "х ${double.parse(order["order_item"]["items"][index]["amount"].toString()).round().toString()}",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            overflow: TextOverflow.ellipsis,
                                            color: Theme.of(context).colorScheme.onSurface,
                                            fontVariations: <FontVariation>[FontVariation('wght', 600)],
                                            fontSize: 36 * globals.scaleParam,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Divider(),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // Container(
                    //   width: constraints.maxWidth,
                    //   height: 120 * globals.scaleParam,
                    //   margin: EdgeInsets.only(bottom: 15 * globals.scaleParam, left: 15 * globals.scaleParam, right: 15 * globals.scaleParam),
                    //   padding: EdgeInsets.symmetric(vertical: 10 * globals.scaleParam, horizontal: 35 * globals.scaleParam),
                    //   decoration: BoxDecoration(
                    //     borderRadius: BorderRadius.all(Radius.circular(15)),
                    //     color: Colors.white,
                    //   ),
                    //   child: Row(
                    //     children: [
                    //       Flexible(
                    //         fit: FlexFit.tight,
                    //         child: Text(
                    //           "Получено бонусов",
                    //           style: TextStyle(
                    //             overflow: TextOverflow.ellipsis,
                    //             color: Theme.of(context).colorScheme.onSurface,
                    //             fontVariations: <FontVariation>[FontVariation('wght', 600)],
                    //             fontSize: 34 * globals.scaleParam,
                    //           ),
                    //         ),
                    //       ),
                    //       Flexible(
                    //         fit: FlexFit.tight,
                    //         child: Center(
                    //           child: Text(
                    //             globals.formatCost(double.parse(order["bonus"].toString()).toString()),
                    //             style: TextStyle(
                    //               overflow: TextOverflow.ellipsis,
                    //               color: Theme.of(context).colorScheme.onSurface,
                    //               fontVariations: <FontVariation>[FontVariation('wght', 700)],
                    //               fontSize: 34 * globals.scaleParam,
                    //             ),
                    //           ),
                    //         ),
                    //       ),
                    //     ],
                    //   ),
                    // ),
                    Container(
                      width: constraints.maxWidth,
                      height: 350 * globals.scaleParam,
                      margin: EdgeInsets.symmetric(vertical: 2 * globals.scaleParam, horizontal: 15 * globals.scaleParam),
                      padding: EdgeInsets.symmetric(vertical: 10 * globals.scaleParam, horizontal: 35 * globals.scaleParam),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(15)),
                        color: Colors.white,
                      ),
                      child: Column(
                        children: [
                          Flexible(
                            child: Row(
                              children: [
                                Flexible(
                                  fit: FlexFit.tight,
                                  child: Text(
                                    "Корзина",
                                    style: TextStyle(
                                      overflow: TextOverflow.ellipsis,
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontVariations: <FontVariation>[FontVariation('wght', 600)],
                                      fontSize: 34 * globals.scaleParam,
                                    ),
                                  ),
                                ),
                                Flexible(
                                  fit: FlexFit.tight,
                                  child: Center(
                                    child: Text(
                                      "${globals.formatCost((double.parse(order["sum"].toString()) - (double.parse(order["delivery_price"].toString()))).round().toString())} ₸",
                                      style: TextStyle(
                                        overflow: TextOverflow.ellipsis,
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontVariations: <FontVariation>[FontVariation('wght', 700)],
                                        fontSize: 34 * globals.scaleParam,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: Row(
                              children: [
                                Flexible(
                                  fit: FlexFit.tight,
                                  child: Text(
                                    "Доставка",
                                    style: TextStyle(
                                      overflow: TextOverflow.ellipsis,
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontVariations: <FontVariation>[FontVariation('wght', 600)],
                                      fontSize: 34 * globals.scaleParam,
                                    ),
                                  ),
                                ),
                                Flexible(
                                  fit: FlexFit.tight,
                                  child: Center(
                                    child: Text(
                                      "${globals.formatCost((double.parse(order["sum"].toString()) - (double.parse(order["sum"].toString()) - (double.parse(order["delivery_price"].toString())))).toString())} ₸",
                                      style: TextStyle(
                                        overflow: TextOverflow.ellipsis,
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontVariations: <FontVariation>[FontVariation('wght', 700)],
                                        fontSize: 34 * globals.scaleParam,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(
                            height: 5 * globals.scaleParam,
                          ),
                          Flexible(
                            child: Row(
                              children: [
                                Flexible(
                                  fit: FlexFit.tight,
                                  child: Text(
                                    "Итого",
                                    style: TextStyle(
                                      overflow: TextOverflow.ellipsis,
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontVariations: <FontVariation>[FontVariation('wght', 600)],
                                      fontSize: 34 * globals.scaleParam,
                                    ),
                                  ),
                                ),
                                Flexible(
                                  fit: FlexFit.tight,
                                  child: Center(
                                    child: Text(
                                      "${globals.formatCost(double.parse(order["sum"].toString()).round().toString())} ₸",
                                      style: TextStyle(
                                        overflow: TextOverflow.ellipsis,
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontVariations: <FontVariation>[FontVariation('wght', 700)],
                                        fontSize: 34 * globals.scaleParam,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Center(
                    //   child: Text(order.toString()),
                    // ),
                  ],
                ),
              );
            })
          : !isOrderLoaded
              ? LinearProgressIndicator()
              : Center(
                  child: Text(
                    "Ваша корзина пуста",
                    style: TextStyle(
                      color: Colors.black,
                      fontVariations: <FontVariation>[FontVariation('wght', 800)],
                      fontSize: 44 * globals.scaleParam,
                    ),
                  ),
                ),
    );
  }
}
