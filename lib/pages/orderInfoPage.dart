import 'dart:io';
// import 'dart:html' as html;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/payForOrderPage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../globals.dart' as globals;

class OrderInfoPage extends StatefulWidget {
  const OrderInfoPage({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderInfoPage> createState() => _OrderInfoPageState();
}

class _OrderInfoPageState extends State<OrderInfoPage> {
  Map order = {};
  double sum = 0;
  @override
  void initState() {
    super.initState();

    getOrders(widget.orderId).then(
      (value) {
        setState(() {
          order = value[0];
          sum = double.parse(order["sum"]);
        });
      },
    );
  }

  whatsapp(String text) async {
    var contact = "+77710131111";
    var androidUrl = "whatsapp://send?phone=$contact&text=$text!";
    var iosUrl = "https://wa.me/$contact?text=${Uri.parse(text)}";
    var url =
        "https://api.whatsapp.com/send/?phone=$contact&text=$text&type=phone_number&app_absent=0";
    try {
      // html.window.open(url, 'whatsapp');
      if (Platform.isIOS) {
        await launchUrl(Uri.parse(iosUrl));
      } else {
        await launchUrl(Uri.parse(androidUrl));
        await launchUrl(Uri.parse(
          url,
        ));

        launch(url);
      }
    } on Exception {
      //  EasyLoading.showError('WhatsApp is not installed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: CustomScrollView(physics: ClampingScrollPhysics(), slivers: [
        SliverPadding(
          padding: EdgeInsets.all(10),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order["b_name"].toString(),
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 36,
                  ),
                ),
                Text(
                  order["b_address"].toString(),
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.all(10),
          sliver: SliverToBoxAdapter(
            child: order["order_status"] == "66"
                ? TextButton(
                    onPressed: () {
                      Navigator.push(context, CupertinoPageRoute(
                        builder: (context) {
                          return PayForOrderPage(
                            order_id: order["order_id"].toString(),
                          );
                        },
                      ));
                    },
                    child: Text("Оплатить"))
                : Container(),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.all(10),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Text(
                  "#${order['order_uuid']}",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
            padding: EdgeInsets.all(10),
            sliver: SliverToBoxAdapter(
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.green.shade700),
                    onPressed: () {
                      whatsapp("Обращаюсь по заказу #${order['order_uuid']}. ");
                    },
                    child: Text("Поддержка")))),
        SliverPadding(
          padding: EdgeInsets.all(10),
          sliver: SliverToBoxAdapter(
              child: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Color(0xFF121212),
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Row(
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: Icon(Icons.location_on),
                        ),
                      ),
                      // Flexible(
                      //   flex: 2,
                      //   child: widget.clientDeliveryInfo["a_address"] != null
                      //       ? Text(
                      //           widget.clientDeliveryInfo["a_address"]
                      //                   .toString() ??
                      //               "",
                      //           style: TextStyle(
                      //             fontWeight: FontWeight.bold,
                      //             fontSize: 14,
                      //           ),
                      //         )
                      //       : Text("Самовывоз"),
                      // )
                    ],
                  ))),
        ),
        SliverPadding(
          padding: EdgeInsets.all(10),
          sliver: SliverList.builder(
            itemCount: order["order_item"]["items"].length ?? 0,
            itemBuilder: (context, index) {
              return Row(
                children: [
                  Flexible(
                    flex: 5,
                    fit: FlexFit.tight,
                    child: Text(
                      order["order_item"]["items"][index]["name"].toString(),
                      maxLines: 2,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  Flexible(
                    fit: FlexFit.tight,
                    child: Text(
                      "х ${double.parse(order["order_item"]["items"][index]["amount"].toString()).toString()}",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.all(10),
          sliver: SliverToBoxAdapter(
            child: Divider(),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.all(10),
          sliver: SliverToBoxAdapter(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Итого:"),
              Text(
                sum.toStringAsFixed(0),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 32),
              ),
            ],
          )),
        ),
      ]),
    );
  }
}
