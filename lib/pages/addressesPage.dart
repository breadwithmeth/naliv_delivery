import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:naliv_delivery/misc/api.dart';

class AddressesPage extends StatefulWidget {
  const AddressesPage(
      {super.key, required this.addresses, required this.isExtended});
  final List addresses;
  final bool isExtended;
  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage>
    with TickerProviderStateMixin {
  // double _sheetPosition = 0.25;

  // Future<void> _showBottomSheet() async {
  //   await showModalBottomSheet<Widget>(
  //     isDismissible: false,
  //     enableDrag: false,
  //     context: context,
  //     builder: (context) {
  //       return GestureDetector(
  //         onTap: () {
  //           print(object)
  //         },
  //         onVerticalDragUpdate: (details) {
  //           print(details);
  //         },
  //         child: Container(
  //           height: 100,
  //         ),
  //       );
  //     },
  //   );
  // }
  double _cHeight = 100;

  bool _isExtended = false;

  void _initcHeight() {
    if (widget.isExtended) {
      setState(() {
        _cHeight = MediaQuery.of(context).size.height * 0.8;
        _isExtended = widget.isExtended;
      });
    } else {
      setState(() {
        _cHeight = MediaQuery.of(context).size.height * 0.2;
        _isExtended = widget.isExtended;
      });
    }
  }

  @override
  void initState() {
    // TODO: implement initState

    super.initState();
    // _showBottomSheet();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _initcHeight();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          surfaceTintColor: Colors.white,
          automaticallyImplyLeading: true,
          title: Column(
            children: [Text("Выбрать адрес")],
          ),
        ),
        // bottomSheet: BottomSheet(
        //   showDragHandle: true,
        //   animationController: BottomSheet.createAnimationController(this),
        //   onClosing: () {},
        //   builder: (context) {
        //     return Container(height: double.infinity,);
        //   },
        // ),
        body: Stack(
          children: [
            Column(
              children: [
                Flexible(
                    child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(51.509364, -0.128928),
                    initialZoom: 9.2,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.app',
                    ),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                          'OpenStreetMap contributors',
                          // onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
                        ),
                      ],
                    ),
                  ],
                )),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Flexible(
                        child: Container(
                          width: double.infinity,
                          margin: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(1),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(50))),
                          // height: 20,
                          // decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))),
                          padding: EdgeInsets.all(10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(30))),
                                width: 50,
                                height: 10,
                              )
                            ],
                          ),
                        ),
                      ),
                      _isExtended
                          ? IconButton(
                              color: Colors.white,
                              style: IconButton.styleFrom(
                                  backgroundColor: Colors.amber),
                              onPressed: () {
                                setState(() {
                                  _cHeight =
                                      MediaQuery.of(context).size.height * 0.2;
                                  _isExtended = false;
                                });
                              },
                              icon: Icon(Icons.close))
                          : Container()
                    ],
                  ),
                  onVerticalDragEnd: (details) {
                    double cHeight = 0;
                    bool isExtended;
                    if (_cHeight > MediaQuery.of(context).size.height * 0.5) {
                      cHeight = MediaQuery.of(context).size.height * 0.8;
                      isExtended = true;
                    } else {
                      cHeight = MediaQuery.of(context).size.height * 0.2;
                      isExtended = false;
                    }
                    setState(() {
                      _cHeight = cHeight;
                      _isExtended = isExtended;
                    });
                  },
                  onVerticalDragUpdate: (details) {
                    double cHeight = MediaQuery.of(context).size.height -
                        details.globalPosition.dy;
                    if (MediaQuery.of(context).size.height -
                            details.globalPosition.dy <
                        50) {
                      cHeight = 50;
                    }
                    if (MediaQuery.of(context).size.height -
                            details.globalPosition.dy >
                        MediaQuery.of(context).size.height * 0.8) {
                      cHeight = MediaQuery.of(context).size.height * 0.8;
                    }
                    setState(() {
                      _cHeight = cHeight;
                    });
                    print(details.globalPosition);
                  },
                ),

                AnimatedContainer(
                    clipBehavior: Clip.antiAlias,
                    curve: Curves.easeInCubic,
                    duration: Duration(milliseconds: 200),
                    height: _cHeight,
                    // clipBehavior: Clip.antiAlias,
                    width: MediaQuery.of(context).size.width,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(30),
                            topRight: Radius.circular(30))),
                    child: _isExtended
                        ? SingleChildScrollView(
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 30,
                                ),
                                ListView.builder(
                                  primary: false,
                                  shrinkWrap: true,
                                  itemCount: widget.addresses.length,
                                  itemBuilder: (context, index) {
                                    return GestureDetector(
                                      onTap: () async {
                                        await selectAddress(widget
                                                .addresses[index]["address_id"])
                                            .then((value) =>
                                                Navigator.pop(context));
                                      },
                                      child: Container(
                                        padding: EdgeInsets.all(20),
                                        margin: EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                            borderRadius: BorderRadius.all(
                                                Radius.circular(10)),
                                            border: Border.all(
                                                color: Colors.grey.shade400),
                                            color: Colors.white),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  widget.addresses[index]
                                                          ["name"] +
                                                      " ",
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.black,
                                                      fontSize: 24),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                Text(
                                                  widget.addresses[index]
                                                      ["address"],
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.black,
                                                      fontSize: 16),
                                                ),
                                                Icon(
                                                  Icons.arrow_forward_ios,
                                                  size: 16,
                                                ),
                                                Text(
                                                  "кв./офис " +
                                                      widget.addresses[index]
                                                          ["apartment"],
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.black,
                                                      fontSize: 16),
                                                ),
                                              ],
                                            ),
                                            SizedBox(
                                              height: 10,
                                            ),
                                            Row(
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      "Этаж: ",
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Colors.black,
                                                          fontSize: 16),
                                                    ),
                                                    Text(
                                                      widget.addresses[index]
                                                          ["floor"],
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Colors.black,
                                                          fontSize: 16),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            SizedBox(
                                              height: 10,
                                            ),
                                            Row(
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      "Вход: ",
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Colors.black,
                                                          fontSize: 16),
                                                    ),
                                                    Text(
                                                      widget.addresses[index]
                                                          ["entrance"],
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Colors.black,
                                                          fontSize: 16),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            )
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                )
                              ],
                            ),
                          )
                        : Container()),
                // Draggable(
                //   dragAnchorStrategy: (draggable, context, position) {
                //   return
                //     Offset(position., position.dy);
                //   },
                //   onDragUpdate: (details) {
                //     print(details);
                //   },
                //   child: Icon(Icons.upcoming),
                //   feedback: Icon(
                //     Icons.circle,
                //     size: 46,
                //   ),
                // ),
              ],
            )
          ],
        ));
  }
}
