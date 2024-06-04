import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:naliv_delivery/misc/api.dart';

class PickOnMapPage extends StatefulWidget {
  const PickOnMapPage({super.key, required this.currentPosition});
  final Position currentPosition;
  @override
  State<PickOnMapPage> createState() => _PickOnMapPageState();
}

class _PickOnMapPageState extends State<PickOnMapPage> {
  MapController _mapController = MapController();
  String? _currentAddressName;
  bool isMapSetteled = true;
  Future<void> searchGeoData(double lon, double lat) async {
    await getGeoData(lon.toString() + "," + lat.toString()).then((value) {
      print(value);
      List objects = value?["response"]["GeoObjectCollection"]["featureMember"];

      double lat = double.parse(
          objects.first["GeoObject"]["Point"]["pos"].toString().split(' ')[1]);
      double lon = double.parse(
          objects.first["GeoObject"]["Point"]["pos"].toString().split(' ')[0]);
      setState(() {
        _currentAddressName = objects.first["GeoObject"]["name"];
      });
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {});
    Future.delayed(
      Durations.extralong4,
    ).then((v) {
      _mapController.move(
          LatLng(widget.currentPosition.latitude,
              widget.currentPosition.longitude),
          15);
      searchGeoData(
          widget.currentPosition.longitude, widget.currentPosition.latitude);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(Icons.arrow_back),
          ),
          title: Text("тут будет город")),
      body: Column(
        children: [
          Expanded(
              flex: 4,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      onPointerUp: (event, point) {
                        if (event.down == false) {
                          searchGeoData(_mapController.camera.center.longitude,
                                  _mapController.camera.center.latitude)
                              .then(
                            (value) {
                              setState(() {
                                isMapSetteled = true;
                              });
                            },
                          );
                        }
                      },
                      onPointerDown: (event, point) {
                        setState(() {
                          isMapSetteled = false;
                        });
                      },
                      interactionOptions: InteractionOptions(
                          enableMultiFingerGestureRace: true),
                      initialCenter: LatLng(0, 0),
                      initialZoom: 9.2,
                    ),
                    children: [
                      TileLayer(
                        // tileBuilder: _darkModeTileBuilder,
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        // urlTemplate:
                        //     'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                        tileProvider: CancellableNetworkTileProvider(),
                      ),
                      // MarkerLayer(markers: [
                      //   Marker(point: _selectedAddress, child: FlutterLogo())
                      // ]),
                      // MarkerLayer(markers: _markers),
                      MarkerLayer(markers: [
                        Marker(
                          point: LatLng(widget.currentPosition.latitude,
                              widget.currentPosition.longitude),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // AnimatedCurrentPosition(),
                              Icon(
                                Icons.circle,
                                color: Colors.deepOrangeAccent,
                                shadows: [
                                  BoxShadow(
                                      color: Colors.orange,
                                      blurRadius: 10,
                                      spreadRadius: 100)
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Marker(
                        //     width: 200,
                        //     height: 200,
                        //     alignment: Alignment.center,
                        //     point: LatLng(widget.currentPosition.latitude,
                        //         widget.currentPosition.longitude),
                        //     child: )
                      ]),
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution(
                            'OpenStreetMap contributors',
                            // onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Center(
                    child: Container(
                      child: Icon(Icons.circle_outlined),
                    ),
                  ),
                ],
              )),
          Expanded(
              flex: 2,
              child: Container(
                  padding: EdgeInsets.all(20),
                  child: !isMapSetteled
                      ? Center(
                          child: CircularProgressIndicator.adaptive(),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Spacer(),
                            Row(
                              children: [
                                Flexible(
                                    child: Text(
                                  "Выберите адрес доставки",
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 24),
                                )),
                              ],
                            ),
                            SizedBox(
                              height: 20,
                            ),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    "Ваш адрес",
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                                decoration: BoxDecoration(
                                    border: Border(
                                        bottom: BorderSide(
                                            color: Colors.grey.shade400))),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _currentAddressName ?? "",
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                            color: Colors.black),
                                      ),
                                    ),
                                    IconButton(
                                        onPressed: () {
                                          showDialog(
                                            barrierColor: Colors.white70,
                                            context: context,
                                            builder: (context) {
                                              return Dialog(
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  shape:
                                                      RoundedRectangleBorder(),
                                                  child: Container(
                                                    color: Colors.transparent,
                                                    padding: EdgeInsets.all(10),
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .end,
                                                          mainAxisSize:
                                                              MainAxisSize.max,
                                                          children: [
                                                            IconButton(
                                                                onPressed: () {
                                                                  Navigator.pop(
                                                                      context);
                                                                },
                                                                icon: Icon(Icons
                                                                    .close))
                                                          ],
                                                        ),
                                                        Flexible(
                                                            child: TextField(
                                                          decoration: InputDecoration(
                                                              border:
                                                                  OutlineInputBorder(),
                                                              labelText:
                                                                  "Введите адрес"),
                                                        )),
                                                        SizedBox(
                                                          height: 20,
                                                        ),
                                                        Flexible(
                                                            child:
                                                                GestureDetector(
                                                                    onTap:
                                                                        () {},
                                                                    child:
                                                                        Container(
                                                                      padding:
                                                                          EdgeInsets.all(
                                                                              15),
                                                                      decoration: BoxDecoration(
                                                                          color: Colors
                                                                              .deepOrangeAccent,
                                                                          borderRadius:
                                                                              BorderRadius.all(Radius.circular(5))),
                                                                      child:
                                                                          Row(
                                                                        children: [
                                                                          Text(
                                                                            "Поиск",
                                                                            style:
                                                                                TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                                                                          )
                                                                        ],
                                                                      ),
                                                                    ))),
                                                      ],
                                                    ),
                                                  ));
                                            },
                                          );
                                        },
                                        icon: Icon(
                                          Icons.search,
                                          color: Colors.deepOrangeAccent,
                                        ))
                                  ],
                                )),
                            Spacer(),
                            Flexible(
                              flex: 2,
                              child: GestureDetector(
                                  onTap: () {},
                                  child: Container(
                                    padding: EdgeInsets.all(15),
                                    decoration: BoxDecoration(
                                        color: Colors.deepOrangeAccent,
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(5))),
                                    child: Row(
                                      children: [
                                        Text(
                                          "Продолжить",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900),
                                        )
                                      ],
                                    ),
                                  )),
                            ),
                            Spacer()
                          ],
                        )))
        ],
      ),
    );
  }
}

class AnimatedCurrentPosition extends StatefulWidget {
  const AnimatedCurrentPosition({super.key});

  @override
  State<AnimatedCurrentPosition> createState() =>
      _AnimatedCurrentPositionState();
}

class _AnimatedCurrentPositionState extends State<AnimatedCurrentPosition>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      duration: Duration(seconds: 5),
      vsync: this,
    )
      ..forward()
      ..addListener(() {
        if (controller.isCompleted) {
          controller.repeat();
        }
      });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) => Transform.scale(
          alignment: Alignment.center,
          scale: controller.value * 2,
          // scale: 3,
          child: Container(
            height: 500,
            width: 500,
            // color: Colors.blue,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: Colors.blue.shade500, width: 1),
                borderRadius: BorderRadius.all(Radius.circular(100))),
            child: Container(
              // clipBehavior: Clip.antiAlias,
              height: 100,
              width: 100,
              // color: Colors.red,
              decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(color: Colors.blue.shade800),
                  borderRadius: BorderRadius.all(Radius.circular(100))),
            ),
          ),
        ),
        child: Icon(
          Icons.circle,
          size: 48,
        ),
      ),
    );
  }
}

class SearchAddressPage extends StatefulWidget {
  const SearchAddressPage({super.key});

  @override
  State<SearchAddressPage> createState() => _SearchAddressPageState();
}

class _SearchAddressPageState extends State<SearchAddressPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Placeholder(),
    );
  }
}
