import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:flutter/cupertino.dart';

class CheckCourierPage extends StatefulWidget {
  const CheckCourierPage({super.key, required this.order});
  final Map order;
  @override
  State<CheckCourierPage> createState() => _CheckCourierPageState();
}

class _CheckCourierPageState extends State<CheckCourierPage> {
  MapController _mapController = MapController();
  Map data = {};
  double zoom = 9.2;
  late Timer periodicTimer;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getCourierLocation();
    periodicTimer = Timer.periodic(
      const Duration(seconds: 10),
      (timer) {
        _getCourierLocation();
      },
    );
  }

  _getCourierLocation() async {
    Map? _data = await getCourierLocation(widget.order["order_id"]);
    print(_data);
    if (_data != null) {
      setState(() {
        data = _data;
      });
    } else {
      // Navigator.pushReplacement(context, CupertinoPageRoute(
      //   builder: (context) {
      //     // return PreLoadDataPage();
      //   },
      // ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        // appBar: AppBar(
        //   title: Text('Заказ ${widget.order["order_uuid"]}'),
        // ),
        body: SafeArea(
            top: false,
            child: Container(
                padding: EdgeInsets.all(20),
                child: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      leading: GestureDetector(
                          onTap: () {
                            // Navigator.pushReplacement(
                            //     context,
                            //     CupertinoPageRoute(
                            //         builder: (context) => PreLoadDataPage()));
                          },
                          child: Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(Icons.close))),
                    ),
                    SliverToBoxAdapter(
                      child: Container(
                          clipBehavior: Clip.hardEdge,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Stack(
                            alignment: Alignment.topRight,
                            children: [
                              AspectRatio(
                                aspectRatio: 1,
                                child: FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    initialCameraFit: CameraFit.coordinates(
                                        padding: EdgeInsets.all(20),
                                        coordinates: [
                                          LatLng(data["store"]["lat"],
                                              data["store"]["lon"]),
                                          LatLng(data["user_address"]["lat"],
                                              data["user_address"]["lon"])
                                        ]),
                                    maxZoom: 17,
                                    interactionOptions:
                                        const InteractionOptions(
                                            enableMultiFingerGestureRace: true),
                                    initialZoom: 9.2,
                                  ),
                                  children: [
                                    TileLayer(
                                      // tileBuilder: _darkModeTileBuilder,
                                      urlTemplate:
                                          'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                                      subdomains: [
                                        'tile0',
                                        'tile1',
                                        'tile2',
                                        'tile3'
                                      ],

                                      // urlTemplate:
                                      //     'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      // urlTemplate:
                                      //     'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                                      tileProvider:
                                          CancellableNetworkTileProvider(),
                                    ),
                                    MarkerLayer(markers: [
                                      Marker(
                                          point: LatLng(
                                              data["location"]["coordinates"]
                                                  [1],
                                              data["location"]["coordinates"]
                                                  [0]),
                                          child: Icon(
                                            Icons.delivery_dining,
                                            color: Colors.black,
                                          )),
                                      Marker(
                                          point: LatLng(data["store"]["lat"],
                                              data["store"]["lon"]),
                                          child: Icon(Icons.store,
                                              color: Colors.black)),
                                      Marker(
                                          point: LatLng(
                                              data["user_address"]["lat"],
                                              data["user_address"]["lon"]),
                                          child: Icon(Icons.location_on,
                                              color: Colors.black)),
                                    ]),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.all(5),
                                child: Column(
                                  children: [
                                    IconButton(
                                        color: Colors.grey.shade900,
                                        style: IconButton.styleFrom(
                                            backgroundColor: Colors.white),
                                        onPressed: () {
                                          _mapController.move(
                                              _mapController.camera.center,
                                              _mapController.camera.zoom + 1);
                                        },
                                        icon: Icon(Icons.add)),
                                    IconButton(
                                        color: Colors.grey.shade900,
                                        style: IconButton.styleFrom(
                                            backgroundColor: Colors.white),
                                        onPressed: () {
                                          _mapController.move(
                                              _mapController.camera.center,
                                              _mapController.camera.zoom - 1);
                                        },
                                        icon: Icon(Icons.remove))
                                  ],
                                ),
                              )
                            ],
                          )),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.all(5),
                    ),
                    SliverToBoxAdapter(
                      child: Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.shade200,
                          border: Border.all(color: Colors.white),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white,
                                    ),
                                    onPressed: () {},
                                    icon: Icon(
                                      Icons.store,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                                Flexible(
                                    flex: 3,
                                    fit: FlexFit.tight,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data["store"]["name"],
                                          style: TextStyle(
                                              overflow: TextOverflow.ellipsis,
                                              color: Colors.grey.shade800,
                                              fontWeight: FontWeight.w800,
                                              fontFamily: "Montserrat"),
                                        ),
                                        Text(
                                          data["store"]["address"],
                                          style: TextStyle(
                                              fontSize: 12,
                                              overflow: TextOverflow.ellipsis,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                              fontFamily: "Montserrat"),
                                        ),
                                      ],
                                    ))
                              ],
                            ),
                            Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white,
                                    ),
                                    onPressed: () {},
                                    icon: Icon(
                                      Icons.location_on,
                                    ),
                                  ),
                                ),
                                Flexible(
                                    flex: 3,
                                    fit: FlexFit.tight,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          data["user_address"]["name"],
                                          style: TextStyle(
                                              overflow: TextOverflow.ellipsis,
                                              color: Colors.grey.shade800,
                                              fontWeight: FontWeight.w800,
                                              fontFamily: "Montserrat"),
                                        ),
                                        Text(
                                          data["user_address"]["address"],
                                          style: TextStyle(
                                              fontSize: 12,
                                              overflow: TextOverflow.ellipsis,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                              fontFamily: "Montserrat"),
                                        ),
                                      ],
                                    ))
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(padding: EdgeInsets.all(5)),
                    SliverToBoxAdapter(
                      child: Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          border: Border.all(color: Colors.white),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Flexible(
                                  child: CircleAvatar(
                                    backgroundColor: Colors.white,
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                                Flexible(
                                  flex: 6,
                                  child: Text(
                                    data["courier"]["name"],
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade800,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: "Montserrat"),
                                  ),
                                ),
                                Flexible(
                                    child: IconButton(
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.white,
                                        ),
                                        onPressed: () async {
                                          // final Uri launchUri = Uri(
                                          //   scheme: 'tel',
                                          //   path: data["courier"]
                                          //       ["phone_number"],
                                          // );
                                          // await launchUrl(launchUri);
                                        },
                                        icon: Icon(Icons.call)))
                              ],
                            )
                          ],
                        ),
                      ),
                    )
                  ],
                ))));
  }
}
