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
        title: Text("История заказов"),
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
                              color: Theme.of(context).colorScheme.secondary,
                              fontSize: 42 * globals.scaleParam,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            "Самое время её пополнить!",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontSize: 42 * globals.scaleParam,
                              fontWeight: FontWeight.w600,
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
                            return OrderInfoPage();
                          },
                        ));
                      },
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 15 * globals.scaleParam),
                        child: Column(
                          children: [
                            Container(
                              height: 100 * globals.scaleParam,
                              padding: EdgeInsets.symmetric(horizontal: 25 * globals.scaleParam),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(15),
                                  topRight: Radius.circular(15),
                                ),
                              ),
                              child: LayoutBuilder(builder: (context, constraints) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      flex: 2,
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
                                                color: Colors.white,
                                                fontSize: 40 * globals.scaleParam,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          Flexible(
                                            fit: FlexFit.tight,
                                            child: Text(
                                              snapshot.data![index]["b_address"].toString(),
                                              textAlign: TextAlign.start,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 40 * globals.scaleParam,
                                                fontWeight: FontWeight.w900,
                                                height: 1.1,
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
                                          Flexible(
                                            fit: FlexFit.tight,
                                            child: Text(
                                              snapshot.data![index]["b_name"] != null ? "Доставка" : "Самовывоз",
                                              textAlign: TextAlign.start,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 40 * globals.scaleParam,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          Flexible(
                                            fit: FlexFit.tight,
                                            child: Text(
                                              "${globals.formatCost("14252")} тг",
                                              textAlign: TextAlign.start,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 40 * globals.scaleParam,
                                                fontWeight: FontWeight.w900,
                                                height: 1.1,
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
                              height: 200 * globals.scaleParam,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.all(Radius.circular(15)),
                                color: Colors.white,
                              ),
                              child: LayoutBuilder(builder: (context, constraints) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 20 * globals.scaleParam, vertical: 10 * globals.scaleParam),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Flexible(
                                      //   fit: FlexFit.tight,
                                      //   child: Text(
                                      //     "ID: ${snapshot.data![index]["order_id"].toString()}",
                                      //     textAlign: TextAlign.center,
                                      //     style: TextStyle(
                                      //       color: Theme.of(context).colorScheme.onSurface,
                                      //       fontSize: 32 * globals.scaleParam,
                                      //       fontWeight: FontWeight.w500,
                                      //     ),
                                      //   ),
                                      // ),
                                      Flexible(
                                        flex: 2,
                                        fit: FlexFit.tight,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                snapshot.data![index]["a_name"].toString(),
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                  fontSize: 42 * globals.scaleParam,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            Flexible(
                                              child: Text(
                                                snapshot.data![index]["a_address"].toString(),
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                  fontSize: 42 * globals.scaleParam,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
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
