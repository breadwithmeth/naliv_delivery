import 'dart:ui';

import 'package:flutter/material.dart';
import '../globals.dart' as globals;
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:naliv_delivery/main.dart';
import 'package:naliv_delivery/misc/api.dart';

class PickOnMapPage extends StatefulWidget {
  const PickOnMapPage({super.key, required this.currentPosition, required this.cities, this.isFromCreateOrder = false});
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
  String styleUrl = "https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png";
  String apiKey = "YOUR-API-KEY";
  String _currentCity = "";

  double _lat = 0;
  double _lon = 0;

  List foundAddresses = [];
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
        });
        print("========================================================");
      } else {
        print("+++++++++++++++++++++++++++++++++++++++++++");
      }
    });
  }

  Future<void> searchGeoData(double lon, double lat) async {
    await getGeoDataByCoord(lat, lon).then((value) {
      // print(value);
      List objects = value;

      // double lat = double.parse(
      //     objects.first["address_name"]["Point"]["pos"].toString().split(' ')[1]);
      // double lon = double.parse(
      //     objects.first["GeoObject"]["Point"]["pos"].toString().split(' ')[0]);
      setState(() {
        _currentAddressName = objects.first["address_name"];
        _lat = lat;
        _lon = lon;
      });
    });
  }

  Future<void> searchGeoDataByString(String search) async {
    print(search);
    await getGeoData(_currentCity + " " + search).then((value) {
      // print(value["result"]["items"]);
      // List? _fa = value["result"]["items"];
      print(value);
      setState(() {
        foundAddresses = [];
        foundAddresses = value;
      });
      // List objects = value?["result"]["items"];
      // double lat = objects.first["point"]["lat"];
      // double lon = objects.first["point"]["lon"];
      // _mapController.move(LatLng(lat, lon), 20);

      // List objects = value?["response"]["GeoObjectCollection"]["featureMember"];

      // double lat = double.parse(
      //     objects.first["GeoObject"]["Point"]["pos"].toString().split(' ')[1]);
      // double lon = double.parse(
      //     objects.first["GeoObject"]["Point"]["pos"].toString().split(' ')[0]);
      // _mapController.move(LatLng(lat, lon), 20);
      // setState(() {
      //   _currentAddressName = objects.first["address_name"];
      //   _lat = lat;
      //   _lon = lon;
      // });
    });
  }

  @override
  void initState() {
    super.initState();
    setCurrentCity();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {});
    Future.delayed(
      Durations.extralong4,
    ).then((v) {
      _mapController.move(LatLng(widget.currentPosition.latitude, widget.currentPosition.longitude), 15);
      searchGeoData(widget.currentPosition.longitude, widget.currentPosition.latitude).then((v) {
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
      resizeToAvoidBottomInset: true,
      // resizeToAvoidBottomPadding: true,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // TextButton(
            //   style: ElevatedButton.styleFrom(
            //     foregroundColor: Colors.black,
            //     shape: RoundedRectangleBorder(
            //       borderRadius: BorderRadius.all(Radius.circular(15)),
            //     ),
            //     padding: EdgeInsets.symmetric(
            //         horizontal: 25 * globals.scaleParam,
            //         vertical: 25 * globals.scaleParam),
            //     minimumSize: Size(0, 0),
            //   ),
            //   onPressed: () {
            //     Navigator.pop(context);
            //   },
            //   child: Icon(
            //     Icons.arrow_back_rounded,
            //     size: 48 * globals.scaleParam,
            //   ),
            // ),
            TextButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(15)),
                ),
                padding: EdgeInsets.symmetric(horizontal: 15 * globals.scaleParam, vertical: 15 * globals.scaleParam),
              ),
              onPressed: () {
                showDialog(
                  barrierColor: Colors.white70,
                  context: context,
                  builder: (context) {
                    return Dialog(
                      backgroundColor: Colors.transparent,
                      shape: const RoundedRectangleBorder(),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Container(
                          alignment: Alignment.center,
                          color: Colors.transparent,
                          padding: EdgeInsets.all(20 * globals.scaleParam),
                          child: ListView.builder(
                            primary: false,
                            itemCount: widget.cities.length,
                            itemBuilder: (context, index) {
                              return TextButton(
                                onPressed: () {
                                  setState(() {
                                    _currentCity = widget.cities[index]["name"];
                                  });
                                  _mapController.move(
                                      LatLng((double.parse(widget.cities[index]["x1"]) + double.parse(widget.cities[index]["x2"])) / 2,
                                          (double.parse(widget.cities[index]["y1"]) + double.parse(widget.cities[index]["y1"])) / 2),
                                      10);
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  padding: EdgeInsets.all(10 * globals.scaleParam),
                                  child: Row(
                                    children: [
                                      Text(
                                        widget.cities[index]["name"],
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 48 * globals.scaleParam,
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentCity.isEmpty ? "Выберите город" : _currentCity,
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 38 * globals.scaleParam,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 48 * globals.scaleParam,
                  )
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Flexible(
              flex: 15,
              fit: FlexFit.loose,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      maxZoom: 17,
                      onPointerUp: (event, point) {
                        if (event.down == false) {
                          searchGeoData(_mapController.camera.center.longitude, _mapController.camera.center.latitude).then(
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
                      interactionOptions: const InteractionOptions(
                          enableMultiFingerGestureRace: true),
                      initialCenter: const LatLng(0, 0),
                      initialZoom: 9.2,
                    ),
                    children: [
                      TileLayer(
                        // tileBuilder: _darkModeTileBuilder,
                        urlTemplate:
                            'https://tile3.maps.2gis.com/tiles?x={x}&y={y}&z={z}',

                        // urlTemplate:
                        //     'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                          point: LatLng(widget.currentPosition.latitude, widget.currentPosition.longitude),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // AnimatedCurrentPosition(),
                              Icon(
                                Icons.circle,
                                color: globals.mainColor,
                                shadows: [BoxShadow(color: Colors.orange, blurRadius: 10, spreadRadius: 200 * globals.scaleParam)],
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
                      const RichAttributionWidget(
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
                      child: Icon(
                        Icons.circle_outlined,
                        size: 58 * globals.scaleParam,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              flex: MediaQuery.sizeOf(context).height > 400 ? 9 : 12,
              fit: FlexFit.tight,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 30 * globals.scaleParam, vertical: 20 * globals.scaleParam),
                child: !isMapSetteled
                    ? const Center(
                        child: CircularProgressIndicator.adaptive(),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            flex: 10,
                            fit: FlexFit.tight,
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 5 * globals.scaleParam),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Flexible(
                                    fit: FlexFit.tight,
                                    child: Row(
                                      children: [
                                        Flexible(
                                          fit: FlexFit.tight,
                                          child: Text(
                                            "Текущий адрес",
                                            maxLines: 1,
                                            style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize:
                                                    42 * globals.scaleParam,
                                                height: 2 * globals.scaleParam,
                                                color: Colors.grey),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Flexible(
                                      child: Row(
                                    children: [
                                      Text(
                                        _currentAddressName ?? "Нет адреса",
                                        textAlign: TextAlign.start,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 42 * globals.scaleParam,
                                        ),
                                      )
                                    ],
                                  )),
                                  Flexible(
                                    fit: FlexFit.tight,
                                    child: Row(
                                      children: [
                                        Flexible(
                                          fit: FlexFit.tight,
                                          child: Text(
                                            "Поиск",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 24 * globals.scaleParam,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Flexible(
                                    flex: 2,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          flex: 3,
                                          fit: FlexFit.tight,
                                          child: TextField(
                                            controller: _searchAddress,
                                            onSubmitted: (value) {
                                              searchGeoDataByString(
                                                      _searchAddress.text)
                                                  .then((v) {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    print(
                                                        foundAddresses.length);
                                                    return AlertDialog(
                                                        backgroundColor:
                                                            Colors.white,
                                                        title: const Text(
                                                            "Выберите адрес"),
                                                        content: Container(
                                                            width: MediaQuery.of(
                                                                        context)
                                                                    .size
                                                                    .width *
                                                                0.8,
                                                            height: MediaQuery.of(
                                                                        context)
                                                                    .size
                                                                    .height *
                                                                0.4,
                                                            child:
                                                                SingleChildScrollView(
                                                              child: Column(
                                                                children: [
                                                                  ListView
                                                                      .builder(
                                                                    itemCount:
                                                                        foundAddresses
                                                                            .length,
                                                                    primary:
                                                                        false,
                                                                    shrinkWrap:
                                                                        true,
                                                                    itemBuilder:
                                                                        (context,
                                                                            index) {
                                                                      return Material(
                                                                        color: Colors
                                                                            .white,
                                                                        shadowColor:
                                                                            Colors.black12,
                                                                        borderRadius:
                                                                            BorderRadius.all(Radius.circular(15)),
                                                                        elevation:
                                                                            10,
                                                                        child:
                                                                            ListTile(
                                                                          tileColor:
                                                                              Colors.white,
                                                                          onTap:
                                                                              () {
                                                                            showModalBottomSheet(
                                                                              backgroundColor: Colors.white,
                                                                              barrierColor: Colors.black45,
                                                                              isScrollControlled: true,
                                                                              context: context,
                                                                              useSafeArea: true,
                                                                              builder: (context) {
                                                                                return CreateAddressPage(
                                                                                  lat: foundAddresses[index]["point"]["lat"],
                                                                                  lon: foundAddresses[index]["point"]["lon"],
                                                                                  addressName: foundAddresses[index]["name"]!,
                                                                                  isFromCreateOrder: true,
                                                                                );
                                                                              },
                                                                            );
                                                                          },
                                                                          title:
                                                                              Text(foundAddresses[index]["name"]),
                                                                          titleTextStyle: TextStyle(
                                                                              fontWeight: FontWeight.w700,
                                                                              color: Colors.black),
                                                                          subtitle:
                                                                              Wrap(
                                                                            spacing:
                                                                                5,
                                                                            children: [
                                                                              for (var v in foundAddresses[index]["adm_div"])
                                                                                Text(v["name"])
                                                                            ],
                                                                          ),
                                                                        ),
                                                                      );
                                                                    },
                                                                  )
                                                                ],
                                                              ),
                                                            )));
                                                  },
                                                );
                                              });
                                            },
                                            maxLines: 1,
                                            textAlign: TextAlign.start,
                                            textAlignVertical:
                                                TextAlignVertical.center,
                                            decoration: InputDecoration(
                                              hintText: "Поиск",
                                              suffixIcon: Icon(Icons.search),
                                              fillColor:
                                                  Colors.blueGrey.shade50,
                                              filled: true,
                                              border: InputBorder.none,
                                              errorBorder: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              disabledBorder: InputBorder.none,
                                            ),
                                          ),
                                          // Text(
                                          //   style: TextStyle(
                                          //       fontWeight: FontWeight.w700,
                                          //       fontSize:
                                          //           32 * globals.scaleParam,
                                          //       color: Colors.black),
                                          // ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Flexible(
                            flex: 3,
                            fit: FlexFit.tight,
                            child: GestureDetector(
                              onTap: () {
                                showModalBottomSheet(
                                  backgroundColor: Colors.white,
                                  barrierColor: Colors.black45,
                                  isScrollControlled: true,
                                  context: context,
                                  useSafeArea: true,
                                  builder: (context) {
                                    return CreateAddressPage(
                                      lat: _lat,
                                      lon: _lon,
                                      addressName: _currentAddressName!,
                                      isFromCreateOrder: true,
                                    );
                                  },
                                );
                              },
                              child: Container(
                                padding: EdgeInsets.only(
                                    left: 15 * globals.scaleParam,
                                    right: 15 * globals.scaleParam,
                                    bottom: 15 * globals.scaleParam),
                                decoration: BoxDecoration(
                                    color: globals.mainColor,
                                    borderRadius: const BorderRadius.all(
                                        Radius.circular(5))),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Продолжить",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 32 * globals.scaleParam,
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            SizedBox(
              height: 50 * globals.scaleParam,
            ),
          ],
        ),
      ),
    );
  }
}

class AnimatedCurrentPosition extends StatefulWidget {
  AnimatedCurrentPosition({super.key, required this.isFromCreateOrder});

  final bool isFromCreateOrder;

  @override
  State<AnimatedCurrentPosition> createState() => _AnimatedCurrentPositionState();
}

class _AnimatedCurrentPositionState extends State<AnimatedCurrentPosition> with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      duration: const Duration(seconds: 5),
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
                borderRadius: const BorderRadius.all(Radius.circular(100))),
            child: Container(
              // clipBehavior: Clip.antiAlias,
              height: 100,
              width: 100,
              // color: Colors.red,
              decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(color: Colors.blue.shade800),
                  borderRadius: const BorderRadius.all(Radius.circular(100))),
            ),
          ),
        ),
        child: const Icon(
          Icons.circle,
          size: 48,
        ),
      ),
    );
  }
}

class CreateAddressPage extends StatefulWidget {
  const CreateAddressPage({super.key, required this.lat, required this.lon, required this.addressName, required this.isFromCreateOrder});
  final double lat;
  final double lon;
  final String addressName;
  final bool isFromCreateOrder;
  @override
  State<CreateAddressPage> createState() => _CreateAddressPageState();
}

class _CreateAddressPageState extends State<CreateAddressPage> {
  TextEditingController floor = TextEditingController();
  TextEditingController house = TextEditingController();
  TextEditingController entrance = TextEditingController();
  TextEditingController other = TextEditingController();
  TextEditingController name = TextEditingController(text: "Мой первый адрес");
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
    }).then((value) {
      if (widget.isFromCreateOrder) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
          builder: (context) {
            return const Main();
          },
        ), (route) => false);
      } else {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
          builder: (context) {
            return const Main();
          },
        ), (route) => false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 20, bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20),
      child: Container(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              children: [
                Flexible(
                    child: Text(
                  widget.addressName,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.black),
                )),
              ],
            ),
            const Divider(
              thickness: 1,
            ),
            Flexible(
              child: TextField(
                maxLength: 250,
                buildCounter: (context, {required currentLength, required isFocused, required maxLength}) {
                  return null;
                },
                decoration: InputDecoration(
                  labelText: "Название",
                  filled: true,
                  fillColor: Colors.white,
                  border: const UnderlineInputBorder(),
                  labelStyle: TextStyle(fontSize: 38 * globals.scaleParam),
                ),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 38 * globals.scaleParam,
                ),
                controller: name,
              ),
            ),
            // TextField(
            //   decoration: InputDecoration(
            //     filled: true,
            //     fillColor: Colors.grey.shade200,
            //     border: OutlineInputBorder(
            //       borderSide: BorderSide(color: Colors.black, width: 10),
            //       borderRadius: BorderRadius.all(Radius.circular(10)),
            //     ),
            //     labelStyle: TextStyle(fontSize: 38 * globals.scaleParam),
            //   ),
            //   readOnly: true,
            //   style: TextStyle(
            //     fontWeight: FontWeight.w700,
            //     fontSize: 38 * globals.scaleParam,
            //   ),
            //   controller: TextEditingController(text: widget.addressName),
            // ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: house,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: "Квартира/Офис",
                      filled: true,
                      fillColor: Colors.white,
                      border: const UnderlineInputBorder(),
                      labelStyle: TextStyle(fontSize: 32 * globals.scaleParam),
                    ),
                    style: TextStyle(fontSize: 32 * globals.scaleParam),
                  ),
                ),
                Flexible(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: entrance,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: "Подъезд/Вход",
                      filled: true,
                      fillColor: Colors.white,
                      border: const UnderlineInputBorder(),
                      labelStyle: TextStyle(fontSize: 32 * globals.scaleParam),
                    ),
                    style: TextStyle(fontSize: 32 * globals.scaleParam),
                  ),
                ),
                Flexible(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: floor,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: "Этаж",
                      filled: true,
                      fillColor: Colors.white,
                      border: const UnderlineInputBorder(),
                      labelStyle: TextStyle(fontSize: 32 * globals.scaleParam),
                    ),
                    style: TextStyle(fontSize: 32 * globals.scaleParam),
                  ),
                )
              ],
            ),
            TextField(
              maxLength: 500,
              buildCounter: (context, {required currentLength, required isFocused, required maxLength}) {
                if (isFocused) {
                  return Text(
                    '$currentLength/$maxLength',
                    semanticsLabel: 'character count',
                    style: TextStyle(fontSize: 32 * globals.scaleParam),
                  );
                } else {
                  return null;
                }
              },
              decoration: InputDecoration(
                labelText: "Комментарий",
                filled: true,
                fillColor: Colors.white,
                border: const UnderlineInputBorder(),
                labelStyle: TextStyle(fontSize: 38 * globals.scaleParam),
              ),
              style: TextStyle(fontSize: 38 * globals.scaleParam),
              controller: other,
            ),
            Row(
              children: [
                Text(widget.lat.toString()),
                SizedBox(
                  width: 20 * globals.scaleParam,
                ),
                Text(widget.lon.toString())
              ],
            ),
            GestureDetector(
              onTap: () {
                _createAddress().whenComplete(() {
                  // widget.isFromCreateOrder
                });
              },
              child: Container(
                padding: EdgeInsets.all(30 * globals.scaleParam),
                margin: const EdgeInsets.only(bottom: 30),
                decoration: BoxDecoration(
                  color: globals.mainColor,
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Продолжить",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 48 * globals.scaleParam,
                      ),
                    )
                  ],
                ),
              ),
            ),

            SizedBox(
              height: 50 * globals.scaleParam,
            ),
          ],
        ),
      ),
    );
  }
}
