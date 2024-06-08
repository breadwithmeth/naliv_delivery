import 'package:flutter/material.dart';
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
    Size screenSize = MediaQuery.of(context).size;
    

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "История заказов",
        ),
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
                      width: 500 * globals.scaleParam,
                      child: Column(
                        children: [
                          Text(
                            "История заказов пуста.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontSize: 32 * globals.scaleParam,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            "Самое время её пополнить!",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontSize: 32 * globals.scaleParam,
                              fontWeight: FontWeight.w500,
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
                padding: EdgeInsets.symmetric(
                    horizontal: 20 * globals.scaleParam,
                    vertical: 20 * globals.scaleParam),
                child: ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    return Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            color: Colors.black12,
                          ),
                          padding: EdgeInsets.symmetric(
                              horizontal: 20 * globals.scaleParam,
                              vertical: 10 * globals.scaleParam),
                          child: Row(
                            children: [
                              Flexible(
                                fit: FlexFit.tight,
                                child: Text(
                                  "ID: ${snapshot.data![index]["order_id"].toString()}",
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onBackground,
                                    fontSize: 32 * globals.scaleParam,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Flexible(
                                flex: 3,
                                fit: FlexFit.tight,
                                child: Column(
                                  children: [
                                    Text(
                                      "Откуда:${snapshot.data![index]["b_name"].toString()}",
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onBackground,
                                        fontSize: 32 * globals.scaleParam,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      snapshot.data![index]["b_address"]
                                          .toString(),
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onBackground,
                                        fontSize: 32 * globals.scaleParam,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Flexible(
                                flex: 3,
                                fit: FlexFit.tight,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Куда: ${snapshot.data![index]["a_name"].toString()}",
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onBackground,
                                        fontSize: 32 * globals.scaleParam,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      snapshot.data![index]["a_address"]
                                          .toString(),
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onBackground,
                                        fontSize: 32 * globals.scaleParam,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (index != snapshot.data!.length - 1) Divider(),
                      ],
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
