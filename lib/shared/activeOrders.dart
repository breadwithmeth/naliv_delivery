import 'package:flutter/cupertino.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/orderDetailsSheet.dart';
import 'dart:async';

class ActiveOrdersWidget extends StatefulWidget {
  const ActiveOrdersWidget({Key? key}) : super(key: key);

  @override
  State<ActiveOrdersWidget> createState() => _ActiveOrdersWidgetState();
}

class _ActiveOrdersWidgetState extends State<ActiveOrdersWidget> {
  List<dynamic> activeOrders = [];
  bool isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadActiveOrders();
    // Запускаем таймер для периодического обновления
    _timer = Timer.periodic(Duration(seconds: 5), (timer) {
      _loadActiveOrders();
    });
  }

  @override
  void dispose() {
    // Отменяем таймер при уничтожении виджета
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadActiveOrders() async {
    try {
      final orders = await getActiveOrders();
      setState(() {
        activeOrders = orders ?? [];
        isLoading = false;
      });
      //print(orders.toString());
      //print("=====================================");
    } catch (e) {
      //print('Ошибка при загрузке активных заказов: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CupertinoActivityIndicator());
    }

    if (activeOrders.isEmpty) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Активные заказы",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
              Text(
                "${activeOrders.length}",
                style: TextStyle(
                  fontSize: 15,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: activeOrders.length,
            padding: EdgeInsets.symmetric(horizontal: 16),
            physics: BouncingScrollPhysics(),
            itemBuilder: (context, index) =>
                _buildOrderCard(activeOrders[index]),
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  String _getAnimationAsset(int statusCode) {
    switch (statusCode) {
      case 0:
        return 'assets/gifs/order_sent.gif';
      case 1:
        return 'assets/gifs/order_accepted.gif';
      case 2:
        return 'assets/gifs/courier_pickup.gif';
      case 3:
        return 'assets/gifs/delivery.gif';
      case 4:
        return 'assets/gifs/order_completed.gif';
      case 66:
        return 'assets/gifs/payment_required.gif';
      default:
        return 'assets/gifs/processing.gif';
    }
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final statusInfo = _getStatusInfo(order['order_status']);
    final int statusCode =
        int.tryParse(order['order_status']?.toString() ?? '') ?? -1;

    return GestureDetector(
      onTap: () {
        showCupertinoModalPopup(
          context: context,
          builder: (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
        width: 250,
        margin: EdgeInsets.only(right: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // SizedBox(
            //   height: 40,
            //   width: 40,
            //   child: Image.asset(
            //     _getAnimationAsset(statusCode),
            //     fit: BoxFit.contain,
            //   ),
            // ),
            // SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Заказ №${order['order_id']}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 16,
                      color: CupertinoColors.systemGrey,
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusInfo['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusInfo['text'],
                    style: TextStyle(
                      color: statusInfo['color'],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (order['created_at'] != null) ...[
              Text(
                order['created_at'].toString(),
                style: TextStyle(
                  color: CupertinoColors.systemGrey,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getStatusInfo(dynamic status) {
    int statusCode = int.tryParse(status?.toString() ?? '') ?? -1;

    switch (statusCode) {
      case 0:
        return {
          'text': 'Отправлен продавцу',
          'color': CupertinoColors.activeOrange,
        };
      case 1:
        return {
          'text': 'Принят продавцом',
          'color': CupertinoColors.systemGreen,
        };
      case 2:
        return {
          'text': 'Передан курьеру',
          'color': CupertinoColors.activeBlue,
        };
      case 3:
        return {
          'text': 'Доставляется',
          'color': CupertinoColors.systemIndigo,
        };
      case 4:
        return {
          'text': 'Доставлен',
          'color': CupertinoColors.systemGreen,
        };
      case 66:
        return {
          'text': 'Не оплачен',
          'color': CupertinoColors.systemRed,
        };
      default:
        return {
          'text': 'В обработке',
          'color': CupertinoColors.systemGrey,
        };
    }
  }
}
