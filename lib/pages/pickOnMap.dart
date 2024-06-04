import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/pickAddressPage.dart';

class PickOnMapPage extends StatefulWidget {
  const PickOnMapPage(
      {super.key, required this.currentPosition, required this.cities});
  final Position currentPosition;
  final List cities;
  @override
  State<PickOnMapPage> createState() => _PickOnMapPageState();
}

class _PickOnMapPageState extends State<PickOnMapPage> {
  TextEditingController _searchAddress = TextEditingController();
  MapController _mapController = MapController();
  String? _currentAddressName;
  bool isMapSetteled = true;

  String _currentCity = "";
  String _currentCityId = "";

  void setCurrentCity() {
    widget.cities.forEach((city) {
      print(city);
      print(city["name"]);

      if (double.parse(city["x1"]) < widget.currentPosition.latitude &&
          double.parse(city["x2"]) > widget.currentPosition.latitude &&
          double.parse(city["y1"]) < widget.currentPosition.longitude &&
          double.parse(city["y2"]) > widget.currentPosition.longitude) {
        setState(() {
          _currentCity = city["name"];
          _currentCityId = city["city_id"];
        });
        print("========================================================");
      } else {
        print("+++++++++++++++++++++++++++++++++++++++++++");
      }
    });
  }

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

  Future<void> searchGeoDataByString(String search) async {
    await getGeoData(search).then((value) {
      print(value);
      List objects = value?["response"]["GeoObjectCollection"]["featureMember"];

      double lat = double.parse(
          objects.first["GeoObject"]["Point"]["pos"].toString().split(' ')[1]);
      double lon = double.parse(
          objects.first["GeoObject"]["Point"]["pos"].toString().split(' ')[0]);
      _mapController.move(LatLng(lat, lon), 13);
      setState(() {
        _currentAddressName = objects.first["GeoObject"]["name"];
      });
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    setCurrentCity();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {});
    Future.delayed(
      Durations.extralong4,
    ).then((v) {
      _mapController.move(
          LatLng(widget.currentPosition.latitude,
              widget.currentPosition.longitude),
          15);
      searchGeoData(
              widget.currentPosition.longitude, widget.currentPosition.latitude)
          .then((v) {
        setState(() {
          _searchAddress.text = _currentAddressName ?? "";
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          centerTitle: false,
          leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(Icons.arrow_back),
          ),
          title: TextButton(onPressed: (){}, child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [Text(_currentCity, style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 24),), Icon(Icons.arrow_drop_down)],)),),
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
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              fit: FlexFit.tight,
                              child: Row(
                                children: [
                                  Flexible(
                                      fit: FlexFit.tight,
                                      child: Text(
                                        "Выберите адрес доставки",
                                        style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 24),
                                      )),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 20,
                            ),
                            Row(
                              children: [
                                Flexible(
                                  fit: FlexFit.tight,
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
                                    // border: Border(
                                    //     bottom: BorderSide(
                                    //         color: Colors.grey.shade400))

                                    ),
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
                                          setState(() {
                                            isMapSetteled = false;
                                          });
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
                                                          controller:
                                                              _searchAddress,
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
                                                                    onTap: () {
                                                                      searchGeoDataByString(
                                                                          _searchAddress
                                                                              .text);
                                                                      Navigator.pop(
                                                                          context);
                                                                      setState(
                                                                          () {
                                                                        isMapSetteled =
                                                                            true;
                                                                      });
                                                                    },
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
                            Divider(),
                            Flexible(
                              fit: FlexFit.tight,
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

class CreateAddressPage extends StatefulWidget {
  const CreateAddressPage(
      {super.key,
      required this.lat,
      required this.lon,
      required this.addressName});
  final double lat;
  final double lon;
  final String addressName;

  @override
  State<CreateAddressPage> createState() => _CreateAddressPageState();
}

class _CreateAddressPageState extends State<CreateAddressPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: Column(
          children: [],
        ),
      ),
    );
  }
}
