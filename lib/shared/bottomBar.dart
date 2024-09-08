import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:naliv_delivery/misc/api.dart';
import '../globals.dart' as globals;

class BottomBar extends StatefulWidget {
  const BottomBar({super.key});

  @override
  State<BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<BottomBar> with SingleTickerProviderStateMixin {
  bool get _isOnDesktopAndWeb {
    if (kIsWeb) {
      return true;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  List orders = [];

  String formatActiveOrderString(int orderCount) {
    if (orderCount % 100 >= 11 && orderCount % 100 <= 19) {
      return '$orderCount активных заказов';
    } else if (orderCount % 10 == 1) {
      return '$orderCount активный заказ';
    } else if (orderCount % 10 >= 2 && orderCount % 10 <= 4) {
      return '$orderCount активных заказа';
    } else {
      return '$orderCount активных заказов';
    }
  }

  Future<void> _getActiveOrders() async {
    List? _orders = await getActiveOrders();
    setState(() {
      orders = _orders!;
    });
  }

  late Timer periodicTimer;
  final DraggableScrollableController _dsController = DraggableScrollableController();

  double _sheetPosition = 0.1;
  final double _dragSensitivity = 600;
  double _cs = 50;
  double _tlr = 0;
  bool isExpanded = false;
  @override
  void initState() {
    super.initState();

    periodicTimer = Timer.periodic(
      const Duration(seconds: 10),
      (timer) {
        _getActiveOrders();
      },
    );

    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _cs = MediaQuery.of(context).size.width * 0.7;
          _tlr = MediaQuery.of(context).size.width * 0.7;
        });
        _getActiveOrders();
        _dsController.addListener(() {
          setState(() {
            if (_dsController.size > 0.12) {
              _cs = MediaQuery.of(context).size.width * 1;
              _tlr = 0;
              isExpanded = true;
            } else {
              _cs = MediaQuery.of(context).size.width * 0.7;
              _tlr = MediaQuery.of(context).size.width * 0.7;
              isExpanded = false;
            }
          });
        });

        // _dsController.animateTo(0.2,
        //     duration: Durations.medium1, curve: Curves.bounceIn);
      });
      // _dsController.animateTo(0.1,
      //     duration: Durations.medium1, curve: Curves.bounceIn);
    }
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _dsController.dispose();
    periodicTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _dsController,
      minChildSize: 0.1,
      maxChildSize: 1,
      initialChildSize: _dsController.isAttached ? _sheetPosition : 0.1,
      snap: true,
      expand: false,
      builder: (context, scrollController) {
        return orders.length == 0
            ? Container()
            : Container(
                clipBehavior: Clip.antiAliasWithSaveLayer,
                decoration: BoxDecoration(
                  color: isExpanded ? Colors.white : Colors.transparent,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return CustomScrollView(
                      controller: scrollController,
                      slivers: [
                        SliverToBoxAdapter(
                          child: AnimatedContainer(
                            duration: Durations.short1,
                            color: Colors.transparent,
                            width: double.infinity,
                            height: isExpanded ? 1 : constraints.minHeight,
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: Durations.short1,
                                  decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.all(Radius.circular(30))),
                                  // width: isExpanded
                                  //     ? MediaQuery.of(context).size.width * 1
                                  //     : MediaQuery.of(context).size.width * 0.7,
                                  child: GestureDetector(
                                    onTap: () {
                                      _dsController.animateTo(1, duration: Duration(microseconds: 10), curve: Curves.bounceIn);
                                    },
                                    child: Container(
                                      color: Colors.transparent,
                                      alignment: isExpanded ? Alignment.topLeft : Alignment.centerLeft,
                                      height: isExpanded ? constraints.smallest.height : constraints.minHeight,
                                      child: orders.length >= 1
                                          ? Container(
                                              margin: EdgeInsets.all(15 * globals.scaleParam),
                                              padding: EdgeInsets.only(
                                                  top: 45 * globals.scaleParam,
                                                  bottom: 45 * globals.scaleParam,
                                                  left: 60 * globals.scaleParam,
                                                  right: 60 * globals.scaleParam),
                                              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.all(Radius.circular(500))),
                                              child: Text(
                                                // formatActiveOrderString(
                                                //     orders.length),
                                                orders.length.toString(),
                                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 36 * globals.scaleParam),
                                              ),
                                            )
                                          : Container(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // SliverToBoxAdapter(
                        //   child: Center(
                        //     child: Container(
                        //       decoration: BoxDecoration(
                        //         color: Theme.of(context).hintColor,
                        //         borderRadius: const BorderRadius.all(Radius.circular(10)),
                        //       ),
                        //       height: 10,
                        //       width: 10,
                        //       margin: const EdgeInsets.symmetric(vertical: 10),
                        //     ),
                        //   ),
                        // ),
                        // LayoutBuilder(
                        //   builder: (context, constraints) {
                        //     print(constraints);
                        //     return Container();
                        //   },
                        // ),
                        SliverToBoxAdapter(
                          child: Container(
                            margin: EdgeInsets.only(top: 60 * globals.scaleParam),
                            padding: EdgeInsets.all(40 * globals.scaleParam),
                            width: double.infinity,
                            height: 1000,
                            color: Colors.white,
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      formatActiveOrderString(orders.length),
                                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 48 * globals.scaleParam),
                                    ),
                                    IconButton(
                                        onPressed: () {
                                          _dsController.animateTo(_sheetPosition, duration: Durations.short1, curve: Curves.bounceOut);
                                        },
                                        icon: Icon(Icons.close))
                                  ],
                                ),
                                ListView.builder(
                                  primary: false,
                                  shrinkWrap: true,
                                  itemCount: orders.length,
                                  itemBuilder: (context, index) {
                                    return OrderListTile(order: orders[index]);
                                  },
                                )
                              ],
                            ),
                          ),
                        )
                      ],
                    );
                  },
                ));
      },
    );
  }
}

class OrderListTile extends StatefulWidget {
  const OrderListTile({super.key, required this.order});
  final Map order;

  @override
  State<OrderListTile> createState() => _OrderListTileState();
}

class _OrderListTileState extends State<OrderListTile> {
  bool isExpanded = false;

  Map orderDetails = {};
  List orderItems = [];

  _getOrderDetails(String order_id) async {
    await getOrderDetails(order_id).then((od) {
      if (od.isNotEmpty) {
        setState(() {
          orderDetails = od;
          orderItems = od["items"];
        });
      }
    });
  }

  Widget getOrderStatusFormat(String string) {
    if (string == "66") {
      return Container(
        color: Colors.red,
        padding: EdgeInsets.all(5 * globals.scaleParam),
        child: Text("Заказ ожидает оплаты", style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 36 * globals.scaleParam)),
      );
    } else if (string == "0") {
      return Container(
        color: Colors.yellow.shade800,
        padding: EdgeInsets.all(5 * globals.scaleParam),
        child:
            Text("Заказ отправлен в магазин", style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 36 * globals.scaleParam)),
      );
    } else if (string == "1") {
      return Container(
        color: Colors.yellow.shade800,
        padding: EdgeInsets.all(5 * globals.scaleParam),
        child: Text("Ожидает сборки", style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 36 * globals.scaleParam)),
      );
    } else if (string == "2") {
      return Container(
        color: Colors.teal.shade700,
        padding: EdgeInsets.all(5 * globals.scaleParam),
        child: Text("Заказ собран", style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 36 * globals.scaleParam)),
      );
    } else if (string == "3") {
      return Container(
        color: Colors.greenAccent.shade700,
        padding: EdgeInsets.all(5 * globals.scaleParam),
        child: Text("Заказ забрал курьер", style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 36 * globals.scaleParam)),
      );
    } else {
      return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey))),
      child: ExpansionTile(
          childrenPadding: EdgeInsets.all(20),
          onExpansionChanged: (value) {
            if (value) {
              _getOrderDetails(widget.order["order_id"]);
            }
          },
          title: Text(
            '#${widget.order["order_uuid"]}',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
          ),
          subtitle: Row(
            children: [
              getOrderStatusFormat(widget.order["order_status"] ?? "99"),
            ],
          ),
          children: [
            orderItems.length == 0
                ? LinearProgressIndicator()
                : ListView.builder(
                    primary: false,
                    shrinkWrap: true,
                    itemCount: orderItems.length,
                    itemBuilder: (context, index) {
                      return Row(
                        children: [
                          Flexible(
                            flex: 4,
                            fit: FlexFit.tight,
                            child: Text(orderItems[index]["name"]),
                          ),
                          Flexible(
                            fit: FlexFit.tight,
                            child: Text(orderItems[index]["amount"]),
                          ),
                        ],
                      );
                    },
                  )
          ]),
    );
    ;
  }
}

class Grabber extends StatelessWidget {
  const Grabber({
    super.key,
    required this.onVerticalDragUpdate,
    required this.isOnDesktopAndWeb,
  });

  final ValueChanged<DragUpdateDetails> onVerticalDragUpdate;
  final bool isOnDesktopAndWeb;

  @override
  Widget build(BuildContext context) {
    if (!isOnDesktopAndWeb) {
      return const SizedBox.shrink();
    }
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onVerticalDragUpdate: onVerticalDragUpdate,
      child: Container(
        width: double.infinity,
        color: colorScheme.onSurface,
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            width: 32.0,
            height: 4.0,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
      ),
    );
  }
}
