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
  const PickOnMapPage(
      {super.key,
      required this.currentPosition,
      required this.cities,
      this.isFromCreateOrder = false});
  final Position? currentPosition;
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
  String styleUrl =
      "https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png";
  String apiKey = "YOUR-API-KEY";
  String _currentCity = "";
  FocusNode addressFocus = FocusNode();

  double _lat = 0;
  double _lon = 0;

  List foundAddresses = [];
  void setCurrentCity() {
    if (widget.currentPosition != null) {
      widget.cities.forEach((city) {
        print(city);
        print(city["name"]);

        if (double.parse(city["x1"]) < widget.currentPosition!.latitude &&
            double.parse(city["x2"]) > widget.currentPosition!.latitude &&
            double.parse(city["y1"]) < widget.currentPosition!.longitude &&
            double.parse(city["y2"]) > widget.currentPosition!.longitude) {
          setState(() {
            _currentCity = city["name"];
          });
          print("========================================================");
        } else {
          print("+++++++++++++++++++++++++++++++++++++++++++");
        }
      });
    }
    if (_currentCity.isEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(),
            child: ListView.builder(
              shrinkWrap: true,
              primary: false,
              itemCount: widget.cities.length,
              itemBuilder: (context, index) {
                print(index);
                return TextButton(
                  onPressed: () {
                    setState(() {
                      _currentCity = widget.cities[index]["name"];
                    });
                    _mapController.move(
                        LatLng(
                            (double.parse(widget.cities[index]["x1"]) +
                                    double.parse(widget.cities[index]["x2"])) /
                                2,
                            (double.parse(widget.cities[index]["y1"]) +
                                    double.parse(widget.cities[index]["y1"])) /
                                2),
                        10);
                    Navigator.pop(context);
                  },
                  child: Container(
                    color: Colors.white,
                    child: Row(
                      children: [
                        Text(
                          widget.cities[index]["name"],
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 72 * globals.scaleParam,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
    }
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
        _searchAddress.text = objects.first["address_name"] ?? "Нет адреса";
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

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      setCurrentCity();
    });
    Future.delayed(
      Durations.extralong4,
    ).then((v) {
      if (widget.currentPosition != null) {
        _mapController.move(
            LatLng(widget.currentPosition!.latitude,
                widget.currentPosition!.longitude),
            15);
        searchGeoData(widget.currentPosition!.longitude,
                widget.currentPosition!.latitude)
            .then((v) {
          setState(() {
            _searchAddress.text = _currentAddressName ?? "";
            isMapSetteled = true;
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      // resizeToAvoidBottomPadding: true,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.symmetric(horizontal: 30 * globals.scaleParam),
        child: Row(
          children: [
            MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height
                ? Flexible(
                    flex: 2,
                    fit: FlexFit.tight,
                    child: SizedBox(),
                  )
                : SizedBox(),
            Flexible(
                fit: FlexFit.tight,
                child: _currentAddressName == _searchAddress.text
                    ? ElevatedButton(
                        onPressed: _searchAddress.text.isEmpty ||
                                _searchAddress.text == "Нет адреса"
                            ? null
                            : () {
                                showModalBottomSheet(
                                  context: context,
                                  clipBehavior: Clip.antiAlias,
                                  useSafeArea: true,
                                  isScrollControlled: true,
                                  showDragHandle: false,
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              fit: FlexFit.tight,
                              child: Text(
                                "Продолжить",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontVariations: <FontVariation>[
                                    FontVariation('wght', 800)
                                  ],
                                  fontSize: 42 * globals.scaleParam,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ElevatedButton(
                        onPressed: _searchAddress.text.isEmpty ||
                                _searchAddress.text == "Нет адреса"
                            ? null
                            : () {
                                searchGeoDataByString(_searchAddress.text).then(
                                  (v) {
                                    showDialog(
                                      context: context,
                                      builder: (context) {
                                        print(foundAddresses.length);
                                        return AlertDialog(
                                          backgroundColor: Colors.white,
                                          title: const Text("Выберите адрес"),
                                          content: Container(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.8,
                                            height: MediaQuery.of(context)
                                                    .size
                                                    .height *
                                                0.4,
                                            child: SingleChildScrollView(
                                              child: Column(
                                                children: [
                                                  ListView.builder(
                                                    itemCount:
                                                        foundAddresses.length,
                                                    primary: false,
                                                    shrinkWrap: true,
                                                    itemBuilder:
                                                        (context, index) {
                                                      return Material(
                                                        color: Colors.white,
                                                        shadowColor:
                                                            Colors.black12,
                                                        borderRadius:
                                                            BorderRadius.all(
                                                                Radius.circular(
                                                                    15)),
                                                        elevation: 10,
                                                        child: ListTile(
                                                          tileColor:
                                                              Colors.white,
                                                          onTap: () {
                                                            showModalBottomSheet(
                                                              backgroundColor:
                                                                  Colors.white,
                                                              barrierColor:
                                                                  Colors
                                                                      .black45,
                                                              isScrollControlled:
                                                                  true,
                                                              context: context,
                                                              useSafeArea: true,
                                                              builder:
                                                                  (context) {
                                                                return CreateAddressPage(
                                                                  lat: foundAddresses[
                                                                          index]
                                                                      [
                                                                      "point"]["lat"],
                                                                  lon: foundAddresses[
                                                                          index]
                                                                      [
                                                                      "point"]["lon"],
                                                                  addressName:
                                                                      foundAddresses[
                                                                              index]
                                                                          [
                                                                          "name"]!,
                                                                  isFromCreateOrder:
                                                                      true,
                                                                );
                                                              },
                                                            );
                                                          },
                                                          title: Text(
                                                              foundAddresses[
                                                                      index]
                                                                  ["name"]),
                                                          titleTextStyle:
                                                              TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: Colors
                                                                      .black),
                                                          subtitle: Wrap(
                                                            spacing: 5,
                                                            children: [
                                                              for (var v
                                                                  in foundAddresses[
                                                                          index]
                                                                      [
                                                                      "adm_div"])
                                                                Text(v["name"])
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  )
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              fit: FlexFit.tight,
                              child: Text(
                                "Искать",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontVariations: <FontVariation>[
                                    FontVariation('wght', 800)
                                  ],
                                  fontSize: 42 * globals.scaleParam,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
          ],
        ),
      ),
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Помощь",
                          style: TextStyle(
                            color: Colors.black,
                            fontVariations: <FontVariation>[
                              FontVariation('wght', 800)
                            ],
                            fontSize: 50 * globals.scaleParam,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Не выбирается адрес",
                          style: TextStyle(
                            color: Colors.black,
                            fontVariations: <FontVariation>[
                              FontVariation('wght', 800)
                            ],
                            fontSize: 38 * globals.scaleParam,
                          ),
                        ),
                        Padding(
                          padding:
                              EdgeInsets.only(left: 20 * globals.scaleParam),
                          child: Text(
                              "Если у вас не получается выбрать адрес, пропробуйте навести кружок на основание дома, на тёмную часть дома.",
                              style: TextStyle(
                                color: Colors.black,
                                fontVariations: <FontVariation>[
                                  FontVariation('wght', 500)
                                ],
                                fontSize: 38 * globals.scaleParam,
                              )),
                        ),
                        SizedBox(
                          height: 20 * globals.scaleParam,
                        ),
                        Text("Не могу найти на карте",
                            style: TextStyle(
                              color: Colors.black,
                              fontVariations: <FontVariation>[
                                FontVariation('wght', 800)
                              ],
                              fontSize: 38 * globals.scaleParam,
                            )),
                        Padding(
                          padding:
                              EdgeInsets.only(left: 20 * globals.scaleParam),
                          child: Text(
                              "Вы можете вручную написать желаемый адрес в поисковую строку и нажать кнопку подтверждения на вашей клавиатуре.",
                              style: TextStyle(
                                color: Colors.black,
                                fontVariations: <FontVariation>[
                                  FontVariation('wght', 500)
                                ],
                                fontSize: 38 * globals.scaleParam,
                              )),
                        )
                      ],
                    ),
                  );
                },
              );
            },
            icon: Icon(Icons.help),
          ),
        ],
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                padding: EdgeInsets.symmetric(
                    horizontal: 15 * globals.scaleParam,
                    vertical: 15 * globals.scaleParam),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return Dialog(
                      shape: const RoundedRectangleBorder(),
                      child: Container(
                        alignment: Alignment.center,
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
                                padding:
                                    EdgeInsets.all(10 * globals.scaleParam),
                                child: Row(
                                  children: [
                                    Text(
                                      widget.cities[index]["name"],
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontVariations: <FontVariation>[
                                          FontVariation('wght', 800)
                                        ],
                                        fontSize: 48 * globals.scaleParam,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(_currentCity.isEmpty ? "Выберите город" : _currentCity,
                      style: TextStyle(
                        color: Colors.black,
                        fontVariations: <FontVariation>[
                          FontVariation('wght', 800)
                        ],
                        fontSize: 48 * globals.scaleParam,
                      )),
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
      body: Stack(
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.646,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                maxZoom: 17,
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
                  subdomains: ['tile0', 'tile1', 'tile2', 'tile3'],

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
                    point: LatLng(widget.currentPosition?.latitude ?? 0,
                        widget.currentPosition?.longitude ?? 0),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // AnimatedCurrentPosition(),
                        Icon(
                          Icons.circle,
                          color: globals.mainColor,
                          shadows: [
                            BoxShadow(
                                color: Colors.orange,
                                blurRadius: 10,
                                spreadRadius: 200 * globals.scaleParam)
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
          ),
          Container(
            height: MediaQuery.sizeOf(context).height * 0.66,
            alignment: Alignment.center,
            child: Icon(
              Icons.circle_outlined,
              size: 58 * globals.scaleParam,
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: MediaQuery.sizeOf(context).height * 0.265,
                padding: EdgeInsets.symmetric(
                    horizontal: 30 * globals.scaleParam,
                    vertical: 20 * globals.scaleParam),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15)),
                  color: Colors.white,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      fit: FlexFit.tight,
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          "Наведите кружок на ваш адрес",
                          style: TextStyle(
                            color: Colors.black,
                            fontVariations: <FontVariation>[
                              FontVariation('wght', 800)
                            ],
                            fontSize: 42 * globals.scaleParam,
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      flex: 2,
                      fit: FlexFit.tight,
                      child: TextField(
                        onChanged: (v) {
                          setState(() {});
                        },
                        focusNode: addressFocus,
                        controller: _searchAddress,
                        onSubmitted: (value) {
                          searchGeoDataByString(_searchAddress.text).then(
                            (v) {
                              showDialog(
                                context: context,
                                builder: (context) {
                                  print(foundAddresses.length);
                                  return AlertDialog(
                                    backgroundColor: Colors.white,
                                    title: Text("Выберите адрес"),
                                    titleTextStyle: TextStyle(
                                      color: Colors.black,
                                      fontFamily: "Raleway",
                                      fontVariations: <FontVariation>[
                                        FontVariation('wght', 800)
                                      ],
                                      fontSize: 42 * globals.scaleParam,
                                    ),
                                    content: Container(
                                      width: MediaQuery.of(context).size.width *
                                          0.8,
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.4,
                                      child: SingleChildScrollView(
                                        child: Column(
                                          children: [
                                            ListView.builder(
                                              itemCount: foundAddresses.length,
                                              primary: false,
                                              shrinkWrap: true,
                                              itemBuilder: (context, index) {
                                                return Material(
                                                  color: Colors.white,
                                                  shadowColor: Colors.black12,
                                                  borderRadius:
                                                      BorderRadius.all(
                                                          Radius.circular(15)),
                                                  elevation: 10,
                                                  child: ListTile(
                                                    tileColor: Colors.white,
                                                    onTap: () {
                                                      showModalBottomSheet(
                                                        backgroundColor:
                                                            Colors.white,
                                                        barrierColor:
                                                            Colors.black45,
                                                        isScrollControlled:
                                                            true,
                                                        context: context,
                                                        useSafeArea: true,
                                                        builder: (context) {
                                                          return CreateAddressPage(
                                                            lat: foundAddresses[
                                                                        index]
                                                                    ["point"]
                                                                ["lat"],
                                                            lon: foundAddresses[
                                                                        index]
                                                                    ["point"]
                                                                ["lon"],
                                                            addressName:
                                                                foundAddresses[
                                                                        index]
                                                                    ["name"]!,
                                                            isFromCreateOrder:
                                                                true,
                                                          );
                                                        },
                                                      );
                                                    },
                                                    title: Text(
                                                        foundAddresses[index]
                                                            ["name"]),
                                                    titleTextStyle: TextStyle(
                                                      color: Colors.white,
                                                      fontVariations: <FontVariation>[
                                                        FontVariation(
                                                            'wght', 800)
                                                      ],
                                                      fontSize: 42 *
                                                          globals.scaleParam,
                                                    ),
                                                    subtitle: Wrap(
                                                      spacing: 5,
                                                      children: [
                                                        for (var v
                                                            in foundAddresses[
                                                                    index]
                                                                ["adm_div"])
                                                          Text(
                                                            v["name"],
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontVariations: <FontVariation>[
                                                                FontVariation(
                                                                    'wght', 800)
                                                              ],
                                                              fontSize: 42 *
                                                                  globals
                                                                      .scaleParam,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                          )
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            )
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                        maxLines: 1,
                        textAlign: TextAlign.start,
                        textAlignVertical: TextAlignVertical.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontVariations: <FontVariation>[
                            FontVariation('wght', 700)
                          ],
                          fontSize: 42 * globals.scaleParam,
                        ),
                        decoration: InputDecoration(
                          hintText: "Поиск",
                          suffixIcon: Icon(Icons.search),
                          fillColor: Colors.blueGrey.shade50,
                          filled: true,
                          border: InputBorder.none,
                          errorBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          labelStyle: TextStyle(
                            color: Colors.black,
                            fontVariations: <FontVariation>[
                              FontVariation('wght', 800)
                            ],
                            fontSize: 42 * globals.scaleParam,
                          ),
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontVariations: <FontVariation>[
                              FontVariation('wght', 700)
                            ],
                            fontSize: 42 * globals.scaleParam,
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      fit: FlexFit.tight,
                      child: SizedBox(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (details) {
              print("HELLO");
              addressFocus.unfocus();
            },
            child: Container(
              height: MediaQuery.sizeOf(context).height * 0.65,
              // color: Colors.amber,
            ),
          )
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
  const CreateAddressPage(
      {super.key,
      required this.lat,
      required this.lon,
      required this.addressName,
      required this.isFromCreateOrder});
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
    return DraggableScrollableSheet(
      snap: true,
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.9,
      minChildSize: 0.85,
      shouldCloseOnMinExtent: true,
      snapAnimationDuration: const Duration(milliseconds: 300),
      builder: (context, scrollController) {
        return Scaffold(
          resizeToAvoidBottomInset: false,
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: Padding(
            padding: EdgeInsets.symmetric(horizontal: 30 * globals.scaleParam),
            child: Row(
              children: [
                MediaQuery.sizeOf(context).width >
                        MediaQuery.sizeOf(context).height
                    ? Flexible(
                        flex: 2,
                        fit: FlexFit.tight,
                        child: SizedBox(),
                      )
                    : SizedBox(),
                Flexible(
                  fit: FlexFit.tight,
                  child: ElevatedButton(
                    onPressed: () {
                      _createAddress().whenComplete(() {
                        // widget.isFromCreateOrder
                      });
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          fit: FlexFit.tight,
                          child: Text(
                            "Продолжить",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontVariations: <FontVariation>[
                                FontVariation('wght', 800)
                              ],
                              fontSize: 42 * globals.scaleParam,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          body: SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.all(35 * globals.scaleParam),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.addressName,
                          style: TextStyle(
                            color: Colors.black,
                            fontVariations: <FontVariation>[
                              FontVariation('wght', 800)
                            ],
                            fontSize: 48 * globals.scaleParam,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(
                    thickness: 1,
                  ),
                  Flexible(
                    child: TextField(
                      maxLength: 100,
                      buildCounter: (context,
                          {required currentLength,
                          required isFocused,
                          required maxLength}) {
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: "Название",
                        filled: true,
                        fillColor: Colors.white,
                        border: const UnderlineInputBorder(),
                        labelStyle: TextStyle(
                          color: Colors.grey,
                          fontVariations: <FontVariation>[
                            FontVariation('wght', 500)
                          ],
                          fontSize: 42 * globals.scaleParam,
                        ),
                        hintStyle: TextStyle(
                          color: Colors.grey,
                          fontVariations: <FontVariation>[
                            FontVariation('wght', 500)
                          ],
                          fontSize: 42 * globals.scaleParam,
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.black,
                        fontVariations: <FontVariation>[
                          FontVariation('wght', 600)
                        ],
                        fontSize: 46 * globals.scaleParam,
                      ),
                      controller: name,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: TextField(
                          maxLength: 20,
                          keyboardType: TextInputType.text,
                          controller: house,
                          inputFormatters: [
                            FilteringTextInputFormatter.singleLineFormatter
                          ],
                          decoration: InputDecoration(
                            labelText: "Квартира/Офис",
                            filled: true,
                            fillColor: Colors.white,
                            border: const UnderlineInputBorder(),
                            labelStyle: TextStyle(
                              color: Colors.grey,
                              fontVariations: <FontVariation>[
                                FontVariation('wght', 500)
                              ],
                              fontSize: 42 * globals.scaleParam,
                            ),
                          ),
                          style: TextStyle(
                            color: Colors.black,
                            fontVariations: <FontVariation>[
                              FontVariation('wght', 600)
                            ],
                            fontSize: 46 * globals.scaleParam,
                          ),
                        ),
                      ),
                      Flexible(
                        child: TextField(
                          maxLength: 20,
                          keyboardType: TextInputType.text,
                          controller: entrance,
                          inputFormatters: [
                            FilteringTextInputFormatter.singleLineFormatter
                          ],
                          decoration: InputDecoration(
                            labelText: "Подъезд/Вход",
                            filled: true,
                            fillColor: Colors.white,
                            border: const UnderlineInputBorder(),
                            labelStyle: TextStyle(
                              color: Colors.grey,
                              fontVariations: <FontVariation>[
                                FontVariation('wght', 500)
                              ],
                              fontSize: 42 * globals.scaleParam,
                            ),
                          ),
                          style: TextStyle(
                            color: Colors.black,
                            fontVariations: <FontVariation>[
                              FontVariation('wght', 600)
                            ],
                            fontSize: 46 * globals.scaleParam,
                          ),
                        ),
                      ),
                      Flexible(
                        child: TextField(
                          maxLength: 20,
                          keyboardType: TextInputType.text,
                          controller: floor,
                          inputFormatters: [
                            FilteringTextInputFormatter.singleLineFormatter
                          ],
                          decoration: InputDecoration(
                            labelText: "Этаж",
                            filled: true,
                            fillColor: Colors.white,
                            border: const UnderlineInputBorder(),
                            labelStyle: TextStyle(
                              color: Colors.grey,
                              fontVariations: <FontVariation>[
                                FontVariation('wght', 500)
                              ],
                              fontSize: 42 * globals.scaleParam,
                            ),
                          ),
                          style: TextStyle(
                            color: Colors.black,
                            fontVariations: <FontVariation>[
                              FontVariation('wght', 600)
                            ],
                            fontSize: 46 * globals.scaleParam,
                          ),
                        ),
                      )
                    ],
                  ),
                  TextField(
                    maxLength: 200,
                    buildCounter: (context,
                        {required currentLength,
                        required isFocused,
                        required maxLength}) {
                      if (isFocused) {
                        return Text(
                          '$currentLength/$maxLength',
                          semanticsLabel: 'character count',
                          style: TextStyle(fontSize: 42 * globals.scaleParam),
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
                      labelStyle: TextStyle(
                        color: Colors.grey,
                        fontVariations: <FontVariation>[
                          FontVariation('wght', 500)
                        ],
                        fontSize: 42 * globals.scaleParam,
                      ),
                    ),
                    style: TextStyle(
                      color: Colors.black,
                      fontVariations: <FontVariation>[
                        FontVariation('wght', 600)
                      ],
                      fontSize: 46 * globals.scaleParam,
                    ),
                    controller: other,
                  ),
                  Row(
                    children: [
                      Text(
                        widget.lat.toString(),
                        style: TextStyle(
                            fontSize: 28 * globals.scaleParam,
                            color: Colors.grey),
                      ),
                      SizedBox(
                        width: 20 * globals.scaleParam,
                      ),
                      Text(
                        widget.lon.toString(),
                        style: TextStyle(
                            fontSize: 28 * globals.scaleParam,
                            color: Colors.grey),
                      )
                    ],
                  ),
                  // GestureDetector(
                  //   onTap: () {
                  //     _createAddress().whenComplete(() {
                  //       // widget.isFromCreateOrder
                  //     });
                  //   },
                  //   child: Container(
                  //     padding: EdgeInsets.all(30 * globals.scaleParam),
                  //     margin: const EdgeInsets.only(bottom: 30),
                  //     decoration: BoxDecoration(
                  //       color: globals.mainColor,
                  //       borderRadius: const BorderRadius.all(Radius.circular(10)),
                  //     ),
                  //     child: Row(
                  //       mainAxisAlignment: MainAxisAlignment.center,
                  //       children: [
                  //         Text(
                  //           "Продолжить",
                  //           style: TextStyle(
                  //             color: Colors.white,
                  //             fontWeight: FontWeight.w900,
                  //             fontSize: 48 * globals.scaleParam,
                  //           ),
                  //         )
                  //       ],
                  //     ),
                  //   ),
                  // ),

                  // SizedBox(
                  //   height: 50 * globals.scaleParam,
                  // ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
