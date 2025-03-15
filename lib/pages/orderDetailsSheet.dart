import 'package:flutter/cupertino.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';

class OrderDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailsSheet({Key? key, required this.order}) : super(key: key);

  @override
  State<OrderDetailsSheet> createState() => _OrderDetailsSheetState();
}

Widget _buildDivider() {
  return Container(
    color: CupertinoColors.systemGrey4,
    height: 1,
  );
}

class _OrderDetailsSheetState extends State<OrderDetailsSheet> {
  Map<String, dynamic>? orderDetails;
  bool isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
    // Запускаем таймер для периодического обновления
    _timer = Timer.periodic(Duration(seconds: 20), (timer) {
      _loadOrderDetails();
    });
  }

  @override
  void dispose() {
    // Отменяем таймер при уничтожении виджета
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrderDetails() async {
    try {
      final details =
          await getOrderDetails2(widget.order['order_id'].toString());
      if (mounted) {
        setState(() {
          orderDetails = details;
          isLoading = false;
        });
      }
    } catch (e) {
      //print('Ошибка при загрузке деталей заказа: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CupertinoActivityIndicator());
    }

    final info = orderDetails?['order_info'];
    if (info == null) {
      return Center(
        child: Text('Не удалось загрузить детали заказа'),
      );
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Заказ №${info['order_id']}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(CupertinoIcons.xmark_circle_fill),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildStatusSection(info['order_status']),
              Container(
                height: 1,
                color: CupertinoColors.systemGrey4,
              ),
              _buildItemsList(info['items']),
              _buildDivider(),
              _buildDeliveryInfo(info),
              if (info['courier'] != null) ...[
                _buildDivider(),
                _buildCourierInfo(info['courier']),
              ],
              _buildDivider(),
              _buildPaymentInfo(info),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection(dynamic status) {
    final statusInfo = _getStatusInfo(status);
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusInfo['color'].withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusInfo['text'],
              style: TextStyle(
                color: statusInfo['color'],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(List<dynamic>? items) {
    if (items == null || items.isEmpty) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Состав заказа',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12),
        ...items
            .map((item) => Container(
                  margin: EdgeInsets.symmetric(vertical: 8),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6.resolveFrom(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item['img'] != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item['img'],
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  width: 60,
                                  height: 60,
                                  color: CupertinoColors.systemGrey5,
                                  child: Icon(
                                    CupertinoIcons.photo,
                                    color: CupertinoColors.systemGrey2,
                                  ),
                                ),
                              ),
                            ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'],
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '${item['amount']} шт. × ${item['price']} ₸',
                                  style: TextStyle(
                                    color: CupertinoColors.systemGrey,
                                    fontSize: 13,
                                  ),
                                ),
                                if (item['applied_promotion'] != null) ...[
                                  SizedBox(height: 8),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.activeOrange
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          CupertinoIcons.tag_fill,
                                          size: 14,
                                          color: CupertinoColors.activeOrange,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          item['applied_promotion']['name'],
                                          style: TextStyle(
                                            color: CupertinoColors.activeOrange,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            '${(item['amount'] * item['price']).toStringAsFixed(0)} ₸',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ))
            .toList(),
      ],
    );
  }

  Widget _buildDeliveryInfo(Map<String, dynamic> info) {
    final address = info['delivery_address'];
    if (address == null) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Адрес доставки',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12),
        Text(address['address']),
        if (address['entrance']?.isNotEmpty ?? false)
          Text('Подъезд: ${address['entrance']}'),
        if (address['floor']?.isNotEmpty ?? false)
          Text('Этаж: ${address['floor']}'),
        if (address['apartment']?.isNotEmpty ?? false)
          Text('Квартира: ${address['apartment']}'),
        if (address['other']?.isNotEmpty ?? false)
          Text('Примечание: ${address['other']}'),
      ],
    );
  }

  Widget _buildCourierInfo(Map<String, dynamic> courier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Курьер',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12),
        if (courier['name'] != null) Text(courier['name']),
        if (courier['location'] != null) ...[
          SizedBox(height: 8),
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.hardEdge,
            child: FlutterMap(
              options: MapOptions(
                center: LatLng(
                  courier['location']['coordinates'][1],
                  courier['location']['coordinates'][0],
                ),
                zoom: 14.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'dev.naliv.delivery',
                ),
                MarkerLayer(
                  markers: [
                    // Маркер курьера
                    Marker(
                      point: LatLng(
                        courier['location']['coordinates'][1],
                        courier['location']['coordinates'][0],
                      ),
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: CupertinoColors.activeBlue.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            CupertinoIcons.car,
                            color: CupertinoColors.activeBlue,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    // Маркер адреса доставки
                    if (orderDetails?['order_info']['delivery_address'] != null)
                      Marker(
                        point: LatLng(
                          double.parse(orderDetails!['order_info']
                                  ['delivery_address']['lat']
                              .toString()),
                          double.parse(orderDetails!['order_info']
                                  ['delivery_address']['lon']
                              .toString()),
                        ),
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemRed.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              CupertinoIcons.location_solid,
                              color: CupertinoColors.systemRed,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentInfo(Map<String, dynamic> info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Оплата',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Способ оплаты'),
            Text(
              info['payment_type'] ?? 'Не указан',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        SizedBox(height: 8),
        // Row(
        //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //   children: [
        //     Text('Статус оплаты'),
        //     Text(
        //       info['payment_status'] == 'paid' ? 'Оплачен' : 'Не оплачен',
        //       style: TextStyle(
        //         color: info['payment_status'] == 'paid'
        //             ? CupertinoColors.systemGreen
        //             : CupertinoColors.systemRed,
        //         fontWeight: FontWeight.w500,
        //       ),
        //     ),
        //   ],
        // ),
      ],
    );
  }
}
