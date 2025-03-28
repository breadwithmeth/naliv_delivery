import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/settingsPage.dart';
import '../globals.dart' as globals;
import 'package:naliv_delivery/main.dart';
import 'package:naliv_delivery/misc/api.dart';
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
    this.addresses = const [],
    this.fromDrawer = false,
  });
  final Map client;
  final bool isFirstTime;
  final Map<dynamic, dynamic> business;
  final bool isFromCreateOrder;
  final List addresses;
  final bool fromDrawer;
  //  String businessId;
  @override
  State<PickAddressPage> createState() => _PickAddressPageState();
}

class _PickAddressPageState extends State<PickAddressPage> {
  bool alreadyOpenedMap = false;
  bool isAddressesLoading = true;
  List _cities = [];
  Position? _location;
  List _addresses = [];
  Future<List> _getAddresses() async {
    // List addresses = await getUserAddresses(widget.client["user_id"]);
    setState(() {
      isAddressesLoading = true;
    });
    List addresses = [];
    if (widget.addresses.isEmpty) {
      addresses = await getAddresses();
    } else {
      addresses = widget.addresses;
    }
    setState(() {
      _addresses = addresses;
      isAddressesLoading = false;
    });
    return addresses;
  }

  Future<void> _getGeolocation() async {
    await determinePosition(context).then((v) {
      if (mounted) {
        setState(() {
          _location = v;
        });
      }
    });
  }

  Future<void> _getCities() async {
    await getCities().then((v) {
      if (mounted) {
        setState(() {
          if (v.isEmpty) {
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
    super.initState();
    // _getAddresses();
    _getGeolocation();
    _getCities();
    _getAddresses().whenComplete(
      () {
        if (_addresses.isEmpty && !isAddressesLoading) {
          Navigator.pushReplacement(context, CupertinoPageRoute(
            builder: (context) {
              return PickOnMapPage(currentPosition: _location, cities: _cities);
            },
          ));
        }
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isFirstTime &&
        _location != null &&
        _cities.isNotEmpty &&
        !alreadyOpenedMap) {
      alreadyOpenedMap = true;
      Future.delayed(
        Duration.zero,
        () {
          Navigator.pushAndRemoveUntil(context, CupertinoPageRoute(
            builder: (context) {
              return PickOnMapPage(
                currentPosition: _location!,
                cities: _cities,
                isFromCreateOrder: true,
              );
            },
          ), (Route<dynamic> route) => false);
          // Navigator.push(context, CupertinoPageRoute(
          //   builder: (context) {
          //     return PickOnMapPage(
          //       currentPosition: _location!,
          //       cities: _cities,
          //       isFromCreateOrder: true,
          //     );
          //   },
          // ));
        },
      );
    }
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: widget.fromDrawer
          ? AppBar(
              backgroundColor: Color(0xFF121212),
              surfaceTintColor: Colors.transparent,
              title: Text(
                "Адреса",
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
            )
          : AppBar(
              backgroundColor: Color(0xFF121212),
              surfaceTintColor: Colors.transparent,
              title: Text(
                "Адреса",
                style: TextStyle(
                  overflow: TextOverflow.ellipsis,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
      floatingActionButton: SizedBox(
        width: 200 * globals.scaleParam,
        height: 165 * globals.scaleParam,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(15)))),
          onPressed: () {
            if (_location == null) {
              //print("LOCATION WAS NULL, SO GETGEOLOCATION IS STARTED");
              _getGeolocation().whenComplete(() {
                _getCities().then((value) {
                  _getAddresses().whenComplete(() {
                    // setState(() {});
                    Navigator.push(context, CupertinoPageRoute(
                      builder: (context) {
                        return PickOnMapPage(
                          currentPosition: _location,
                          cities: _cities,
                          isFromCreateOrder: true,
                        );
                      },
                    )).then((v) {
                      setState(() {
                        List addresses = v;
                        _addresses = addresses;
                      });
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
              )).then((v) {
                setState(() {
                  List<dynamic> addresses = v;
                  _addresses = addresses;
                });
              });
            }
          },
          child: Icon(
            Icons.add,
            color: Colors.white,
          ),
        ),
      ),
      body: _addresses.isEmpty
          ? isAddressesLoading
              ? Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          "Загружаю адреса, пожалуйста подождите",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            fontVariations: <FontVariation>[
                              FontVariation('wght', 800)
                            ],
                            fontSize: 44 * globals.scaleParam,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          "У вас нет адресов",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            fontVariations: <FontVariation>[
                              FontVariation('wght', 800)
                            ],
                            fontSize: 44 * globals.scaleParam,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
          : SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ListView.builder(
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
                              ? Navigator.pop(
                                  context,
                                )
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
                          margin: EdgeInsets.only(
                              right: 20 * globals.scaleParam,
                              top: 20 * globals.scaleParam,
                              bottom: 20 * globals.scaleParam),
                          decoration: BoxDecoration(
                            border: _addresses[index]["is_selected"] == "1"
                                ? Border(
                                    left: BorderSide(
                                        color: globals.mainColor, width: 10),
                                  )
                                : Border(
                                    left: BorderSide(
                                        color: Colors.transparent, width: 10),
                                  ),
                            color: Color(0xFF121212),
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(15),
                              bottomRight: Radius.circular(16),
                            ), //? If set 15 and 15 strange graphic artifact appear on the smoothed corners
                          ),
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
                                          _addresses[index]["city_name"] ?? "",
                                          style: TextStyle(
                                            fontVariations: <FontVariation>[
                                              FontVariation('wght', 600)
                                            ],
                                            fontSize: 44 * globals.scaleParam,
                                            height: 3.2 * globals.scaleParam,
                                          ),
                                        ),
                                        Text(
                                          _addresses[index]["address"],
                                          style: TextStyle(
                                            fontVariations: <FontVariation>[
                                              FontVariation('wght', 400)
                                            ],
                                            fontSize: 42 * globals.scaleParam,
                                            height: 3.2 * globals.scaleParam,
                                          ),
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
                                                fontVariations: <FontVariation>[
                                                  FontVariation('wght', 600)
                                                ],
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
                                          fontVariations: <FontVariation>[
                                            FontVariation('wght', 400)
                                          ],
                                          fontWeight: FontWeight.w500,
                                          fontSize: 32 * globals.scaleParam),
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      _addresses[index]["entrance"] ?? "-",
                                      style: TextStyle(
                                          fontVariations: <FontVariation>[
                                            FontVariation('wght', 400)
                                          ],
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
                                        fontVariations: <FontVariation>[
                                          FontVariation('wght', 400)
                                        ],
                                        fontWeight: FontWeight.w500,
                                        fontSize: 32 * globals.scaleParam,
                                      ),
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      _addresses[index]["floor"] ?? "-",
                                      style: TextStyle(
                                        fontVariations: <FontVariation>[
                                          FontVariation('wght', 400)
                                        ],
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
                                        fontVariations: <FontVariation>[
                                          FontVariation('wght', 400)
                                        ],
                                        fontWeight: FontWeight.w500,
                                        fontSize: 32 * globals.scaleParam,
                                      ),
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      _addresses[index]["apartment"] ?? "-",
                                      style: TextStyle(
                                        fontVariations: <FontVariation>[
                                          FontVariation('wght', 400)
                                        ],
                                        fontWeight: FontWeight.w500,
                                        fontSize: 32 * globals.scaleParam,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                              Padding(
                                padding: EdgeInsets.only(
                                    left: 50 * globals.scaleParam),
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _addresses[index]["other"] ?? "-",
                                        style: TextStyle(
                                          fontVariations: <FontVariation>[
                                            FontVariation('wght', 400)
                                          ],
                                          fontWeight: FontWeight.w500,
                                          fontSize: 32 * globals.scaleParam,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                        // isThreeLine: true,
                      );
                    },
                  ),
                  // FutureBuilder(
                  //   future: _addresses,
                  //   builder: (context, snapshot) {
                  //     if (snapshot.hasData) {
                  //       if (snapshot.data!.isEmpty) {
                  //         return Container(
                  //           height: 500 * globals.scaleParam,
                  //           alignment: Alignment.center,
                  //           child: Row(
                  //             mainAxisAlignment: MainAxisAlignment.center,
                  //             children: [
                  //               Flexible(
                  //                 child: Text(
                  //                   widget.isFirstTime
                  //                       ? "Пожалуйста выберите адрес"
                  //                       : "Здесь пусто",
                  //                   textAlign: TextAlign.center,
                  //                   style: TextStyle(
                  //                     fontSize: 40 * globals.scaleParam,
                  //                     fontWeight: FontWeight.w500,
                  //                     color: Colors.grey,
                  //                     fontFamily: "montserrat",
                  //                   ),
                  //                 ),
                  //               ),
                  //             ],
                  //           ),
                  //         );
                  //       }
                  //       List _addresses = snapshot.data!;
                  //       return ListView.builder(
                  //         primary: false,
                  //         shrinkWrap: true,
                  //         itemCount: _addresses.length,
                  //         itemBuilder: (context, index) {
                  //           return GestureDetector(
                  //             behavior: HitTestBehavior.opaque,
                  //             onTap: () {
                  //               selectAddressClient(_addresses[index]["address_id"],
                  //                   widget.client["user_id"]);
                  //               widget.isFromCreateOrder
                  //                   ? Navigator.pop(context)
                  //                   : Navigator.pushAndRemoveUntil(context,
                  //                       CupertinoPageRoute(
                  //                       builder: (context) {
                  //                         return Main(
                  //                             // business: widget.business,
                  //                             // client: widget.client,
                  //                             // customAddress: _addresses[index],
                  //                             );
                  //                       },
                  //                     ), (Route<dynamic> route) => false);
                  //             },
                  //             child: Container(
                  //               decoration: BoxDecoration(
                  //                   border: _addresses[index]["is_selected"] == "1"
                  //                       ? Border(
                  //                           left: BorderSide(
                  //                               color: globals.mainColor, width: 10))
                  //                       : Border()),
                  //               padding: EdgeInsets.symmetric(
                  //                   horizontal: 50 * globals.scaleParam,
                  //                   vertical: 30 * globals.scaleParam),
                  //               child: Column(
                  //                 crossAxisAlignment: CrossAxisAlignment.start,
                  //                 children: [
                  //                   Row(
                  //                     mainAxisAlignment:
                  //                         MainAxisAlignment.spaceBetween,
                  //                     children: [
                  //                       Flexible(
                  //                         flex: 2,
                  //                         fit: FlexFit.tight,
                  //                         child: Column(
                  //                           crossAxisAlignment:
                  //                               CrossAxisAlignment.start,
                  //                           children: [
                  //                             Text(
                  //                               _addresses[index]["address"],
                  //                               style: TextStyle(
                  //                                   fontWeight: FontWeight.w700,
                  //                                   fontSize:
                  //                                       42 * globals.scaleParam),
                  //                             ),
                  //                             Text(
                  //                               _addresses[index]["city_name"] ?? "",
                  //                               style: TextStyle(
                  //                                   fontWeight: FontWeight.w700,
                  //                                   fontSize:
                  //                                       32 * globals.scaleParam),
                  //                             ),
                  //                           ],
                  //                         ),
                  //                       ),
                  //                       Flexible(
                  //                         fit: FlexFit.tight,
                  //                         child: Row(
                  //                           mainAxisAlignment: MainAxisAlignment.end,
                  //                           children: [
                  //                             Flexible(
                  //                               child: Text(
                  //                                 _addresses[index]["name"],
                  //                                 textAlign: TextAlign.end,
                  //                                 style: TextStyle(
                  //                                     fontWeight: FontWeight.w500,
                  //                                     fontSize:
                  //                                         32 * globals.scaleParam),
                  //                               ),
                  //                             ),
                  //                           ],
                  //                         ),
                  //                       ),
                  //                     ],
                  //                   ),
                  //                   Row(
                  //                     mainAxisSize: MainAxisSize.max,
                  //                     mainAxisAlignment: MainAxisAlignment.start,
                  //                     children: [
                  //                       Flexible(
                  //                         child: Text(
                  //                           "Подъезд/Вход: ",
                  //                           style: TextStyle(
                  //                               fontWeight: FontWeight.w500,
                  //                               fontSize: 32 * globals.scaleParam),
                  //                         ),
                  //                       ),
                  //                       Flexible(
                  //                         child: Text(
                  //                           _addresses[index]["entrance"] ?? "-",
                  //                           style: TextStyle(
                  //                               fontWeight: FontWeight.w500,
                  //                               fontSize: 32 * globals.scaleParam),
                  //                         ),
                  //                       )
                  //                     ],
                  //                   ),
                  //                   Row(
                  //                     mainAxisSize: MainAxisSize.max,
                  //                     mainAxisAlignment: MainAxisAlignment.start,
                  //                     children: [
                  //                       Flexible(
                  //                         child: Text(
                  //                           "Этаж: ",
                  //                           style: TextStyle(
                  //                             fontWeight: FontWeight.w500,
                  //                             fontSize: 32 * globals.scaleParam,
                  //                           ),
                  //                         ),
                  //                       ),
                  //                       Flexible(
                  //                         child: Text(
                  //                           _addresses[index]["floor"] ?? "-",
                  //                           style: TextStyle(
                  //                             fontWeight: FontWeight.w500,
                  //                             fontSize: 32 * globals.scaleParam,
                  //                           ),
                  //                         ),
                  //                       )
                  //                     ],
                  //                   ),
                  //                   Row(
                  //                     mainAxisSize: MainAxisSize.max,
                  //                     mainAxisAlignment: MainAxisAlignment.start,
                  //                     children: [
                  //                       Flexible(
                  //                         child: Text(
                  //                           "Квартира/Офис: ",
                  //                           style: TextStyle(
                  //                             fontWeight: FontWeight.w500,
                  //                             fontSize: 32 * globals.scaleParam,
                  //                           ),
                  //                         ),
                  //                       ),
                  //                       Flexible(
                  //                         child: Text(
                  //                           _addresses[index]["apartment"] ?? "-",
                  //                           style: TextStyle(
                  //                             fontWeight: FontWeight.w500,
                  //                             fontSize: 32 * globals.scaleParam,
                  //                           ),
                  //                         ),
                  //                       )
                  //                     ],
                  //                   ),
                  //                   Row(
                  //                     children: [
                  //                       Flexible(
                  //                         child: Text(
                  //                           _addresses[index]["other"] ?? "-",
                  //                           style: TextStyle(
                  //                             fontWeight: FontWeight.w500,
                  //                             fontSize: 32 * globals.scaleParam,
                  //                           ),
                  //                         ),
                  //                       ),
                  //                     ],
                  //                   )
                  //                 ],
                  //               ),
                  //             ),
                  //             // isThreeLine: true,
                  //           );
                  //         },
                  //       );
                  //     } else if (snapshot.hasError) {
                  //       return Text(
                  //         "Error",
                  //         style: TextStyle(
                  //             fontWeight: FontWeight.w500,
                  //             fontSize: 32 * globals.scaleParam),
                  //       );
                  //     } else {
                  //       return LinearProgressIndicator();
                  //     }
                  //   },
                  // )

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
