import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/orderInfoPage.dart';
import '../globals.dart' as globals;
import 'package:naliv_delivery/misc/api.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  Future<List<dynamic>> _getOrders() async {
    List<dynamic> orders = await getOrders();
    return orders;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          "История заказов",
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
      body: FutureBuilder(
        future: _getOrders(),
        builder: (context, snapshot) {
          Widget children;
          if (snapshot.hasData) {
            if (snapshot.data!.isEmpty) {
              children = Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: MediaQuery.sizeOf(context).width * 0.8,
                      child: Column(
                        children: [
                          Text(
                            "История заказов пуста",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontVariations: <FontVariation>[FontVariation('wght', 700)],
                              fontSize: 42 * globals.scaleParam,
                            ),
                          ),
                          Text(
                            "Самое время её пополнить!",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontVariations: <FontVariation>[FontVariation('wght', 700)],
                              fontSize: 42 * globals.scaleParam,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            } else {
              children = Padding(
                padding: EdgeInsets.symmetric(horizontal: 20 * globals.scaleParam, vertical: 20 * globals.scaleParam),
                child: ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) {
                            return OrderInfoPage(
                              orderId: snapshot.data![index]["order_id"].toString(),
                              clientDeliveryInfo: {"a_name": snapshot.data![index]["a_name"], "a_address": snapshot.data![index]["a_address"]},
                            );
                          },
                        ));
                      },
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 15 * globals.scaleParam),
                        child: Column(
                          children: [
                            Container(
                              height: 95 * globals.scaleParam,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(15),
                                  topRight: Radius.circular(15),
                                ),
                                color: Colors.black,
                              ),
                              child: LayoutBuilder(builder: (context, constraints) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 20 * globals.scaleParam, vertical: 10 * globals.scaleParam),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        fit: FlexFit.tight,
                                        child: Text(
                                          "№ ${(index + 1).toString()}",
                                          textAlign: TextAlign.start,
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onPrimary,
                                            fontVariations: <FontVariation>[FontVariation('wght', 700)],
                                            fontSize: 39 * globals.scaleParam,
                                          ),
                                        ),
                                      ),
                                      Flexible(
                                        fit: FlexFit.tight,
                                        child: Text(
                                          snapshot.data![index]["log_timestamp"].toString(),
                                          textAlign: TextAlign.start,
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onPrimary,
                                            fontVariations: <FontVariation>[FontVariation('wght', 700)],
                                            fontSize: 36 * globals.scaleParam,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                            Container(
                              height: 120 * globals.scaleParam,
                              padding: EdgeInsets.symmetric(horizontal: 25 * globals.scaleParam),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(15),
                                  bottomRight: Radius.circular(15),
                                ),
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
                                              snapshot.data![index]["b_name"].toString(),
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
                                              snapshot.data![index]["b_address"].toString(),
                                              textAlign: TextAlign.start,
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSurface,
                                                fontVariations: <FontVariation>[FontVariation('wght', 600)],
                                                fontSize: 36 * globals.scaleParam,
                                                height: 2 * globals.scaleParam,
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
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          snapshot.data![index]["a_name"] != null
                                              ? Flexible(
                                                  fit: FlexFit.tight,
                                                  child: Text(
                                                    snapshot.data![index]["a_name"].toString(),
                                                    textAlign: TextAlign.start,
                                                    style: TextStyle(
                                                      overflow: TextOverflow.ellipsis,
                                                      color: Theme.of(context).colorScheme.onSurface,
                                                      fontVariations: <FontVariation>[FontVariation('wght', 600)],
                                                      fontSize: 36 * globals.scaleParam,
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
                                          snapshot.data![index]["a_address"] != null
                                              ? Flexible(
                                                  fit: FlexFit.tight,
                                                  child: Text(
                                                    snapshot.data![index]["a_address"].toString(),
                                                    textAlign: TextAlign.start,
                                                    style: TextStyle(
                                                      overflow: TextOverflow.ellipsis,
                                                      color: Theme.of(context).colorScheme.onSurface,
                                                      fontVariations: <FontVariation>[FontVariation('wght', 600)],
                                                      fontSize: 36 * globals.scaleParam,
                                                      height: 2 * globals.scaleParam,
                                                    ),
                                                  ),
                                                )
                                              : SizedBox(),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            }
          } else {
            children = LinearProgressIndicator();
          }
          return children;
        },
      ),
    );
  }
}
