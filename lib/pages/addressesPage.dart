import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class AddressesPage extends StatefulWidget {
  const AddressesPage({super.key});

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
    setState(() {
      _cHeight = MediaQuery.of(context).size.height * 0.2;
    });
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
          automaticallyImplyLeading: true,
          title: Column(
            children: [Text("Выбрать город")],
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

                  child: Column(
                    children: [
                      
                    ],
                  ),
                ),
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
