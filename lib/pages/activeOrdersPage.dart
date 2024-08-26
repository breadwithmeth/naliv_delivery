import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import '../globals.dart' as globals;

class ActiveOrdersPage extends StatefulWidget {
  const ActiveOrdersPage({super.key});

  @override
  State<ActiveOrdersPage> createState() => _ActiveOrdersPageState();
}

class _ActiveOrdersPageState extends State<ActiveOrdersPage> {
  List? activeOrders;

  Future<void> getOrders() async {
    getActiveOrders().then(
      (value) {
        print(value);
        if (value.isNotEmpty) {
          setState(() {
            activeOrders = value;
          });
        } else {
          setState(() {
            activeOrders = [];
          });
        }
      },
    );
  }

  @override
  void initState() {
    super.initState();

    getOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text("Активные заказы"),
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
      body: activeOrders != null
          ? ListView.builder(
              itemCount: activeOrders!.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: EdgeInsets.all(10 * globals.scaleParam),
                  padding: EdgeInsets.symmetric(horizontal: 10 * globals.scaleParam, vertical: 10 * globals.scaleParam),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                    color: Colors.white,
                  ),
                  height: 180 * globals.scaleParam,
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              fit: FlexFit.tight,
                              child: Text(
                                "ID: ${activeOrders![index]["order_uuid"]}",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  // fontFamily: "montserrat",
                                  fontSize: 36 * globals.scaleParam,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            Flexible(
                              fit: FlexFit.tight,
                              child: Text(
                                "Статус: ${activeOrders![index]["order_status"]}",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  // fontFamily: "montserrat",
                                  fontSize: 36 * globals.scaleParam,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        fit: FlexFit.tight,
                        child: Text(
                          "${activeOrders![index]["log_timestamp"]}",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            // fontFamily: "montserrat",
                            fontSize: 36 * globals.scaleParam,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            )
          : Center(
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width * 0.8,
                height: MediaQuery.sizeOf(context).height,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "У вас нет активных заказов",
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
            ),
    );
  }
}
