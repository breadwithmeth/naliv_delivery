import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/createOrder.dart';
import 'package:naliv_delivery/pages/pickOnMap.dart';

class PickAddressPage extends StatefulWidget {
  const PickAddressPage({super.key, required this.client});
  final Map client;
  @override
  State<PickAddressPage> createState() => _PickAddressPageState();
}

class _PickAddressPageState extends State<PickAddressPage> {
  Future<List> _getAddresses() async {
    List addresses = await getUserAddresses(widget.client["user_id"]);

    return addresses;
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getAddresses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Адреса"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (context) {
              return PickOnMapPage();
            },
          ));
        },
        child: Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FutureBuilder(
              future: _getAddresses(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  if (snapshot.data!.isEmpty) {
                    return Center(
                      child: Text("Здесь пусто"),
                    );
                  }
                  List _addresses = snapshot.data!;
                  return ListView.builder(
                    primary: false,
                    shrinkWrap: true,
                    itemCount: _addresses.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        onTap: () {
                          selectAddressClient(_addresses[index]["address_id"],
                                  widget.client["user_id"])
                              .whenComplete(
                            () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (context) {
                                  return const CreateOrderPage();
                                },
                              ));
                            },
                          );
                        },
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 35, vertical: 5),
                        title: Text(
                          _addresses[index]["address"],
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 18),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text("Подъезд/Вход: "),
                                Text(
                                  _addresses[index]["entrance"] ?? "-",
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                )
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text("Этаж: "),
                                Text(
                                  _addresses[index]["floor"] ?? "-",
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                )
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text("Квартира/Офис: "),
                                Text(
                                  _addresses[index]["apartment"] ?? "-",
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                )
                              ],
                            ),
                            Text(
                              _addresses[index]["other"] ?? "-",
                              style: TextStyle(fontWeight: FontWeight.w500),
                            )
                          ],
                        ),
                        trailing: Text(
                          _addresses[index]["name"],
                        ),
                        isThreeLine: true,
                      );
                    },
                  );
                } else if (snapshot.hasError) {
                  return Text("Error");
                } else {
                  return LinearProgressIndicator();
                }
              },
            )

            // Padding(
            //   padding: EdgeInsets.symmetric(horizontal: 35),
            //   child: ElevatedButton(
            //       onPressed: () {},
            //       child: Row(
            //         children: [
            //           Text(
            //             "Добавить новый адрес",
            //             style: TextStyle(
            //                 fontSize: 20, fontWeight: FontWeight.w500),
            //           )
            //         ],
            //       )),
            // ),
          ],
        ),
      ),
    );
  }
}
