import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:naliv_delivery/main.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/pickAddressPage.dart';

class PickOnMapPage extends StatefulWidget {
  const PickOnMapPage(
      {super.key,
      required this.currentPosition,
      required this.cities,
      this.isFromCreateOrder = false});
  final Position currentPosition;
  final List cities;
  final bool isFromCreateOrder;
  @override
  State<PickOnMapPage> createState() => _PickOnMapPageState();
}

class _PickOnMapPageState extends State<PickOnMapPage> {
  TextEditingController _searchAddress = TextEditingController();
  MapController _mapController = MapController();
  String? _currentAddressName;
  bool isMapSetteled = false;

  String _currentCity = "";
  String _currentCityId = "";
  double _lat = 0;
  double _lon = 0;
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
        _lat = lat;
        _lon = lon;
      });
    });
  }

  Future<void> searchGeoDataByString(String search) async {
    await getGeoData(_currentCity + " " + search).then((value) {
      print(value);
      List objects = value?["response"]["GeoObjectCollection"]["featureMember"];

      double lat = double.parse(
          objects.first["GeoObject"]["Point"]["pos"].toString().split(' ')[1]);
      double lon = double.parse(
          objects.first["GeoObject"]["Point"]["pos"].toString().split(' ')[0]);
      _mapController.move(LatLng(lat, lon), 20);
      setState(() {
        _currentAddressName = objects.first["GeoObject"]["name"];
        _lat = lat;
        _lon = lon;
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
          isMapSetteled = true;
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
        title: TextButton(
            onPressed: () {
              showDialog(
                barrierColor: Colors.white70,
                context: context,
                builder: (context) {
                  return Dialog(
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Container(
                          alignment: Alignment.center,
                          color: Colors.transparent,
                          padding: EdgeInsets.all(10),
                          child: ListView.builder(
                            primary: false,
                            itemCount: widget.cities.length,
                            itemBuilder: (context, index) {
                              return TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _currentCity =
                                          widget.cities[index]["name"];
                                      _currentCityId =
                                          widget.cities[index]["city_id"];
                                    });
                                    _mapController.move(
                                        LatLng(
                                            (double.parse(widget.cities[index]
                                                        ["x1"]) +
                                                    double.parse(widget
                                                        .cities[index]["x2"])) /
                                                2,
                                            (double.parse(widget.cities[index]
                                                        ["y1"]) +
                                                    double.parse(widget
                                                        .cities[index]["y1"])) /
                                                2),
                                        10);
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                      padding: EdgeInsets.all(10),
                                      child: Row(
                                        children: [
                                          Text(
                                            widget.cities[index]["name"],
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 24),
                                          )
                                        ],
                                      )));
                            },
                          ),
                        ),
                      ));
                },
              );
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(
                  _currentCity,
                  style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 24),
                ),
                Icon(Icons.arrow_drop_down)
              ],
            )),
      ),
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
                              flex: 1,
                              child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (context) {
                                        return CreateAddressPage(
                                          lat: _lat,
                                          lon: _lon,
                                          addressName: _currentAddressName!,
                                          city_id: _currentCityId,
                                          isFromCreateOrder: true,
                                        );
                                      },
                                    ));
                                  },
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
  const AnimatedCurrentPosition({super.key, required this.isFromCreateOrder});

  final bool isFromCreateOrder;

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
      required this.addressName,
      required this.city_id,
      required this.isFromCreateOrder});
  final double lat;
  final double lon;
  final String addressName;
  final String city_id;
  final bool isFromCreateOrder;
  @override
  State<CreateAddressPage> createState() => _CreateAddressPageState();
}

class _CreateAddressPageState extends State<CreateAddressPage> {
  TextEditingController floor = TextEditingController();
  TextEditingController house = TextEditingController();
  TextEditingController entrance = TextEditingController();
  TextEditingController other = TextEditingController();
  TextEditingController name = TextEditingController();
  Future<void> _createAddress() async {
    await createAddress({
      "lat": widget.lat,
      "lon": widget.lon,
      "address": "${widget.addressName}",
      "name": name.text,
      "apartment": house.text,
      "entrance": entrance.text,
      "floor": floor.text,
      "other": other.text,
      "city_id": widget.city_id
    }).then((value) {
      if (value == true) {
        // Navigator.pushReplacement(
        //     context, MaterialPageRoute(builder: (context) => HomePage()));
        if (widget.isFromCreateOrder) {
          Navigator.pop(context);
          Navigator.pop(context);
        } else {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
            builder: (context) {
              return Main();
            },
          ), (route) => false);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
          padding: const EdgeInsets.all(20),
          width: MediaQuery.of(context).size.width,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Flexible(
                    flex: 7,
                    child: TextField(
                      maxLength: 250,
                      buildCounter: (context,
                          {required currentLength,
                          required isFocused,
                          required maxLength}) {
                        return null;
                      },
                      decoration: InputDecoration(
                          labelText: "Название",
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: const OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.black, width: 10),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)))),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 20),
                      controller: name,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 10,
              ),
              Row(
                children: [
                  Flexible(
                    flex: 7,
                    child: TextField(
                      decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          border: const OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.black, width: 10),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)))),
                      readOnly: true,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 20),
                      controller:
                          TextEditingController(text: widget.addressName),
                    ),
                  ),
                  const Spacer(
                    flex: 1,
                  ),
                ],
              ),
              const SizedBox(
                height: 10,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    flex: 5,
                    child: TextField(
                      controller: house,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: "Квартира/Офис",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Colors.black, width: 10),
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    flex: 5,
                    child: TextField(
                      controller: entrance,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: "Подъезд/Вход",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Colors.black, width: 10),
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    flex: 3,
                    child: TextField(
                      controller: floor,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: "Этаж",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Colors.black, width: 10),
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 10,
              ),
              Row(
                children: [
                  Flexible(
                      child: TextField(
                    maxLength: 500,
                    buildCounter: (context,
                        {required currentLength,
                        required isFocused,
                        required maxLength}) {
                      if (isFocused) {
                        return Text(
                          '$currentLength/$maxLength',
                          semanticsLabel: 'character count',
                        );
                      } else {
                        return null;
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: "Комментарий",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black, width: 10),
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                    ),
                    controller: other,
                  ))
                ],
              ),
              Row(
                children: [
                  Text(widget.lat.toString()),
                  const SizedBox(
                    width: 10,
                  ),
                  Text(widget.lon.toString())
                ],
              ),
              const SizedBox(
                height: 20,
              ),
              GestureDetector(
                  onTap: () {
                    _createAddress().whenComplete(() {
                      // widget.isFromCreateOrder
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                        color: Colors.deepOrangeAccent,
                        borderRadius: BorderRadius.all(Radius.circular(5))),
                    child: Row(
                      children: [
                        Text(
                          "Продолжить",
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w900),
                        )
                      ],
                    ),
                  ))
            ],
          )),
    );
  }
}
