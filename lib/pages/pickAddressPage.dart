import 'package:flutter/material.dart';
import '../globals.dart' as globals;
import 'package:naliv_delivery/main.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/createOrder.dart';
import 'package:naliv_delivery/pages/pickOnMap.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/cupertino.dart';

class PickAddressPage extends StatefulWidget {
  PickAddressPage(
      {super.key,
      required this.client,
      this.isFirstTime = false,
      this.business = const {},
      this.isFromCreateOrder = false,
      this.addresses = const []});
  final Map client;
  final bool isFirstTime;
  final Map<dynamic, dynamic> business;
  final bool isFromCreateOrder;
  final List addresses;
  //  String businessId;
  @override
  State<PickAddressPage> createState() => _PickAddressPageState();
}

class _PickAddressPageState extends State<PickAddressPage> {
  List _cities = [];

  Position? _location;
  Future<List> _getAddresses() async {
    // List addresses = await getUserAddresses(widget.client["user_id"]);
    List addresses = [];
    if (widget.addresses.isEmpty) {
      addresses = await getAddresses();
    } else {
      addresses = widget.addresses;
    }

    return addresses;
  }

  Future<void> _getGeolocation() async {
    await determinePosition(context).then((v) {
      if (this.mounted) {
        setState(() {
          _location = v;
        });
      }
    });
  }

  Future<void> _getCities() async {
    await getCities().then((v) {
      if (this.mounted) {
        setState(() {
          if (v == null) {
            _cities = [];
          } else {
            _cities = v;
          }
        });
      }
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    // _getAddresses();
    _getGeolocation();
    _getCities();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
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
                    // setState(() {});
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
                      height: 500 * globals.scaleParam,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              widget.isFirstTime
                                  ? "Пожалуйста выберите адрес"
                                  : "Здесь пусто",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 40 * globals.scaleParam,
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
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          selectAddressClient(_addresses[index]["address_id"],
                              widget.client["user_id"]);
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
                        child: Container(
                          decoration: BoxDecoration(
                              border: _addresses[index]["is_selected"] == "1"
                                  ? Border(
                                      left: BorderSide(
                                          color: globals.mainColor, width: 10))
                                  : Border()),
                          padding: EdgeInsets.symmetric(
                              horizontal: 50 * globals.scaleParam,
                              vertical: 30 * globals.scaleParam),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    flex: 2,
                                    fit: FlexFit.tight,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _addresses[index]["address"],
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize:
                                                  42 * globals.scaleParam),
                                        ),
                                        Text(
                                          _addresses[index]["city_name"] ?? "",
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize:
                                                  32 * globals.scaleParam),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Flexible(
                                    fit: FlexFit.tight,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            _addresses[index]["name"],
                                            textAlign: TextAlign.end,
                                            style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize:
                                                    32 * globals.scaleParam),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Text(
                                      "Подъезд/Вход: ",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 32 * globals.scaleParam),
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      _addresses[index]["entrance"] ?? "-",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 32 * globals.scaleParam),
                                    ),
                                  )
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Text(
                                      "Этаж: ",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 32 * globals.scaleParam,
                                      ),
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      _addresses[index]["floor"] ?? "-",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 32 * globals.scaleParam,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Text(
                                      "Квартира/Офис: ",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 32 * globals.scaleParam,
                                      ),
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      _addresses[index]["apartment"] ?? "-",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 32 * globals.scaleParam,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _addresses[index]["other"] ?? "-",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 32 * globals.scaleParam,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                        // isThreeLine: true,
                      );
                    },
                  );
                } else if (snapshot.hasError) {
                  return Text(
                    "Error",
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 32 * globals.scaleParam),
                  );
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
