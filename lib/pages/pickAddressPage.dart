import 'package:flutter/material.dart';
import 'package:naliv_delivery/main.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/createOrder.dart';
import 'package:naliv_delivery/pages/pickOnMap.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/cupertino.dart';

class PickAddressPage extends StatefulWidget {
  const PickAddressPage({
    super.key,
    required this.client,
    this.isFirstTime = false,
    this.business = const {},
    this.isFromCreateOrder = false,
  });
  final Map client;
  final bool isFirstTime;
  final Map<dynamic, dynamic> business;
  final bool isFromCreateOrder;
  //  String businessId;
  @override
  State<PickAddressPage> createState() => _PickAddressPageState();
}

class _PickAddressPageState extends State<PickAddressPage> {
  List _cities = [];

  Position? _location;
  Future<List> _getAddresses() async {
    // List addresses = await getUserAddresses(widget.client["user_id"]);
    List addresses = await getAddresses();

    return addresses;
  }

  Future<void> _getGeolocation() async {
    await determinePosition(context).then((v) {
      setState(() {
        _location = v;
      });
    });
  }

  Future<void> _getCities() async {
    await getCities().then((v) {
      setState(() {
        _cities = v;
      });
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getAddresses();
    _getGeolocation();
    _getCities();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Адреса"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_location == null) {
            print("LOCATION WAS NULL, SO GETGEOLOCATION IS STARTED");
            _getGeolocation().whenComplete(() {
              Navigator.push(context, CupertinoPageRoute(
                builder: (context) {
                  return PickOnMapPage(
                    currentPosition: _location!,
                    cities: _cities,
                    isFromCreateOrder: true,
                  );
                },
              )).whenComplete(() {
                _getCities().then((value) {
                  _getAddresses().whenComplete(() {
                  setState(() {});
                });
                });
              });
            });
          } else {
            Navigator.push(context, CupertinoPageRoute(
              builder: (context) {
                return PickOnMapPage(
                  currentPosition: _location!,
                  cities: _cities,
                  isFromCreateOrder: true,
                );
              },
            )).whenComplete(() {
              _getAddresses().whenComplete(() {
                setState(() {});
              });
            });
          }
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
                    return Container(
                      height: MediaQuery.of(context).size.height * 0.8,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              widget.isFirstTime
                                  ? "Добавьте ваш адрес для начала"
                                  : "Здесь пусто",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                                fontFamily: "montserrat",
                              ),
                            ),
                          ),
                        ],
                      ),
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
                              widget.isFromCreateOrder
                                  ? Navigator.pop(context)
                                  : Navigator.pushAndRemoveUntil(context,
                                      CupertinoPageRoute(
                                      builder: (context) {
                                        return Main(
                                            // business: widget.business,
                                            // client: widget.client,
                                            // customAddress: _addresses[index],
                                            );
                                      },
                                    ), (Route<dynamic> route) => false);
                            },
                          );
                        },
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 35, vertical: 5),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _addresses[index]["address"],
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 18),
                            ),
                            Text(
                              _addresses[index]["city_name"] ?? "",
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ],
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
