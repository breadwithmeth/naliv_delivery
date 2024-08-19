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
                    return Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            color: Colors.white,
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 20 * globals.scaleParam, vertical: 10 * globals.scaleParam),
                          child: Row(
                            children: [
                              Flexible(
                                fit: FlexFit.tight,
                                child: Text(
                                  "ID: ${snapshot.data![index]["order_id"].toString()}",
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
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
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontSize: 32 * globals.scaleParam,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      snapshot.data![index]["b_address"].toString(),
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
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
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontSize: 32 * globals.scaleParam,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      snapshot.data![index]["a_address"].toString(),
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
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
