import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:naliv_delivery/pages/createAddress.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import '../misc/api.dart';

class PickAddressPage extends StatefulWidget {
  const PickAddressPage({super.key});

  @override
  State<PickAddressPage> createState() => _PickAddressPageState();
}

class _PickAddressPageState extends State<PickAddressPage>
    with SingleTickerProviderStateMixin {
  late YandexMapController controller;
  late CameraPosition cameraPos;
  Widget mapWidget = Container();
  List<MapObject> mapObjects = [];
  List<Widget> suggestions = [];
  Widget selectedAddress = Container();

  MapObjectId cameraMapObjectId = const MapObjectId("current_location");

  bool map_expanded = true;

  final TextEditingController _addressInputController = TextEditingController();

  late Animation<double> animation;
  late Animation<double> animationR;

  late AnimationController aController;

  final Widget _loadingScreen = Container();

  String street = "";
  String house = "";

  Color test = Colors.black;

  bool isCameraMoved = false;

  Map<String, dynamic> city = {};
  Future<void> _getCity() async {
    Map<String, dynamic>? city = await getCity();
    if (city != null) {
      setState(() {
        city = city;
      });
    }

    controller.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(
            zoom: 12,
            target: Point(
                latitude:
                    ((double.parse(city!["x1"]) + double.parse(city!["x2"])) /
                            2) ??
                        50,
                longitude:
                    ((double.parse(city!["y1"]) + double.parse(city!["y2"])) /
                        2))))) ??
        50;
  }

  _getStores() async {
    List? businesses = await getBusinesses();
    Timer(const Duration(seconds: 5), () {
      List<MapObject> mapObjects = [];
      mapObjects.add(
        PlacemarkMapObject(
          mapId: cameraMapObjectId,
          point: Point(
              latitude:
                  (double.parse(city["x1"]) + double.parse(city["x2"])) / 2,
              longitude:
                  (double.parse(city["y1"]) + double.parse(city["y2"])) / 2),
          icon: PlacemarkIcon.single(PlacemarkIconStyle(
              image: BitmapDescriptor.fromAssetImage('assets/icons/place.png'),
              scale: 0.75)),
          opacity: 0.5,
        ),
      );

      if (businesses != null) {
        for (var element in businesses) {
          mapObjects.add(
            PlacemarkMapObject(
              mapId: MapObjectId(element["business_id"]),
              point: Point(
                  latitude: double.parse(element["lat"]),
                  longitude: double.parse(element["lon"])),
              text: PlacemarkText(
                  text: element["name"], style: const PlacemarkTextStyle()),
              opacity: 0.5,
            ),
          );
        }
      }
      setState(() {
        mapObjects = mapObjects;
      });
    });
  }

  void _search() async {
    print('Point: ${cameraPos.target}, Zoom: ${cameraPos.zoom}');

    final resultWithSession = YandexSearch.searchByPoint(
      point: cameraPos.target,
      zoom: cameraPos.zoom.toInt(),
      searchOptions: const SearchOptions(
        searchType: SearchType.geo,
        geometry: false,
      ),
    );

    String? street = await resultWithSession.result.then((value) => value
        .items!
        .first
        .toponymMetadata!
        .address
        .addressComponents[SearchComponentKind.street]);
    String? appartment = await resultWithSession.result.then((value) => value
        .items!
        .first
        .toponymMetadata!
        .address
        .addressComponents[SearchComponentKind.house]);
    double? lat = await resultWithSession.result.then(
        (value) => value.items!.first.toponymMetadata!.balloonPoint.latitude);
    double? lon = await resultWithSession.result.then(
        (value) => value.items!.first.toponymMetadata!.balloonPoint.longitude);
    print(street);

    resultWithSession.session.close();
    setState(() {
      house = appartment ?? "";
      street = street ?? "";
    });

    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateAddress(
            lon: lon!,
            lat: lat!,
            street: street!,
            house: appartment!,
          ),
        ));
  }

  void _searchByText() async {
    final query = _addressInputController.text;

    print('Search query: $query');

    final resultWithSession = YandexSearch.searchByText(
      searchText: query,
      geometry: Geometry.fromBoundingBox(BoundingBox(
        southWest: Point(latitude: city["x1"], longitude: city["y2"]),
        northEast: Point(latitude: city["x2"], longitude: city["y1"]),
      )),
      searchOptions: const SearchOptions(
        searchType: SearchType.geo,
        geometry: false,
      ),
    );

    double? lat = await resultWithSession.result.then(
        (value) => value.items!.first.toponymMetadata!.balloonPoint.latitude);
    double? lon = await resultWithSession.result.then(
        (value) => value.items!.first.toponymMetadata!.balloonPoint.longitude);
    print(lat);

    setState(() {
      controller.moveCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: Point(latitude: lat!, longitude: lon!))));
      controller.moveCamera(CameraUpdate.zoomTo(20));
    });

    resultWithSession.session.close();

    // await Navigator.push(
    //     context,
    //     MaterialPageRoute(
    //         builder: (BuildContext context) => _SessionPage(
    //             query, resultWithSession.session, resultWithSession.result)));
  }

  Future<void> _getAddressAuto() async {
    Position curPos = await determinePosition();

    final resultWithSession = YandexSearch.searchByPoint(
      point: Point(latitude: curPos.latitude, longitude: curPos.longitude),
      searchOptions: const SearchOptions(
        searchType: SearchType.geo,
        geometry: false,
      ),
    );

    String? street = await resultWithSession.result.then((value) => value
        .items!
        .first
        .toponymMetadata!
        .address
        .addressComponents[SearchComponentKind.street]);
    String? appartment = await resultWithSession.result.then((value) => value
        .items!
        .first
        .toponymMetadata!
        .address
        .addressComponents[SearchComponentKind.house]);
    resultWithSession.session.close();

    print(street);
    print(appartment);
    if (street != null && appartment != null) {
      controller.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(
          zoom: 20,
          target: Point(
              latitude: curPos.latitude, longitude: curPos.longitude))));
      showDialog(
        useSafeArea: false,
        context: context,
        builder: (context) {
          return AlertDialog(
            contentPadding: const EdgeInsets.all(0),
            content: Container(
              padding: const EdgeInsets.all(15),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(30))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Ваше устройство находится здесь?",
                    style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                        color: Colors.black),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Row(
                    children: [
                      const Text("Улица: "),
                      Text(
                        street,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Colors.black),
                      )
                    ],
                  ),
                  Row(
                    children: [
                      const Text("Дом: "),
                      Text(
                        appartment,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Colors.black),
                      )
                    ],
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  ElevatedButton(
                      onPressed: () {
                        _search();
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [Text("Использовать этот адрес")],
                      )),
                  const SizedBox(
                    height: 5,
                  ),
                  ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [Text("Добавить другой адрес")],
                      )),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  Future<void> _suggest() async {
    SuggestResultWithSession resultWithSession = YandexSuggest.getSuggestions(
        text: _addressInputController.text,
        boundingBox: BoundingBox(
          southWest: Point(
              latitude: double.parse(city["x1"]),
              longitude: double.parse(city["y2"])),
          northEast: Point(
              latitude: double.parse(city["x2"]),
              longitude: double.parse(city["y1"])),
        ),
        suggestOptions: const SuggestOptions(
          suggestType: SuggestType.geo,
          suggestWords: true,
        ));
    List<SuggestSessionResult> results = [];

    results.add(await resultWithSession.result);
    List<Widget> list = [];

    for (var r in results) {
      r.items!.asMap().forEach((i, item) {
        print(item.title);
        if (item.center!.longitude > double.parse(city["y1"]) &&
            item.center!.longitude < double.parse(city["y2"]) &&
            item.center!.latitude > double.parse(city["x1"]) &&
            item.center!.latitude < double.parse(city["x2"])) {
          list.add(GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
                setState(() {
                  _addressInputController.text = item.title;
                  suggestions = [];
                  controller.moveCamera(CameraUpdate.newCameraPosition(
                      CameraPosition(
                          zoom: 20,
                          target: Point(
                              latitude: item.center!.latitude,
                              longitude: item.center!.longitude))));
                });
              },
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined),
                      Column(
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Colors.black),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider()
                ],
              )));
        }
      });
    }
    setState(() {
      suggestions = list;
    });
    // if (results.isEmpty) {
    //   setState(() {
    //     suggestions = [];
    //   });
    //   list.add(Text("Ничего не найдено"));
    // } else {}
    print(list);
    await resultWithSession.session.close();
  }

  void initMap() {
    setState(() {
      mapWidget = Column(
        children: [
          Flexible(
              flex: map_expanded ? 30 : 10,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  YandexMap(
                    nightModeEnabled: false,
                    mapType: MapType.vector,
                    mapObjects: mapObjects,
                    onCameraPositionChanged:
                        (cameraPosition, reason, finished) {
                      PlacemarkMapObject placemarkMapObject = mapObjects
                              .firstWhere((el) => el.mapId == cameraMapObjectId)
                          as PlacemarkMapObject;

                      setState(() {
                        cameraPos = cameraPosition;
                        mapObjects[mapObjects.indexOf(placemarkMapObject)] =
                            placemarkMapObject.copyWith(
                                point: cameraPosition.target);
                      });
                    },
                    onMapCreated: (controller) {
                      controller = controller;

                      controller.moveCamera(CameraUpdate.newCameraPosition(
                              CameraPosition(
                                  zoom: 12,
                                  target: Point(
                                      latitude: ((double.parse(city["x1"]) +
                                                  double.parse(city["x2"])) /
                                              2) ??
                                          50,
                                      longitude: ((double.parse(city["y1"]) +
                                              double.parse(city["y2"])) /
                                          2))))) ??
                          50;
                    },
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.all(Radius.circular(15))),
                        width: MediaQuery.of(context).size.width,
                        padding: const EdgeInsets.all(10),
                        margin:
                            const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search),
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.7,
                              child: TextFormField(
                                decoration: const InputDecoration(
                                    hintText: "Поиск улицы",
                                    border: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none),
                                minLines: 1,
                                maxLines: 1,
                                controller: _addressInputController,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Container(
                    margin: const EdgeInsets.all(15),
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                        color: Colors.white),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: suggestions,
                    ),
                  ),
                  Center(
                    child: Icon(
                      Icons.pin_drop_rounded,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.all(20),
                                backgroundColor: test),
                            onPressed: () {
                              setState(() {
                                test = Colors.blue;
                              });
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Text(
                                  "Продолжить",
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                      color: Colors.black),
                                )
                              ],
                            )),
                      )
                    ],
                  )
                ],
              )),
        ],
      );
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    aController = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    animation = Tween<double>(begin: 0.7, end: 0.5)
        .animate(CurvedAnimation(parent: aController, curve: Curves.easeInOut))
      ..addListener(() {
        setState(() {
          // The state that has changed here is the animation object’s value.
        });
      });
    animationR = Tween<double>(begin: 0.5, end: 0.7)
        .animate(CurvedAnimation(parent: aController, curve: Curves.easeInOut))
      ..addListener(() {
        setState(() {
          // The state that has changed here is the animation object’s value.
        });
      });
    aController.forward();
    aController.addListener(() {
      if (aController.isCompleted) {
        aController.reverse();
      }
      if (aController.isDismissed) {
        aController.forward();
      }
    });
    Timer timer = Timer(const Duration(seconds: 2), () {
      initMap();
      _getCity();

      aController.dispose();
      _getStores();
    });
  }

  @override
  void dispose() {
    super.dispose();

    aController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Выберите адрес",
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: Stack(
        children: [
          // Container(
          //   alignment: Alignment.center,
          //   color: Colors.white,
          //   child: Column(
          //     mainAxisAlignment: MainAxisAlignment.center,
          //     children: [
          //       Text(
          //         "Загружаем карты...",
          //         style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20),
          //       ),
          //       SizedBox(
          //         height: 30,
          //       ),
          //       Container(
          //         child: Row(
          //           mainAxisAlignment: MainAxisAlignment.center,
          //           crossAxisAlignment: CrossAxisAlignment.end,
          //           children: [
          //             Transform.scale(
          //                 alignment: Alignment.center,
          //                 scale: animation.value,
          //                 child: Container(
          //                   decoration: BoxDecoration(
          //                       color: Colors.black,
          //                       borderRadius:
          //                           BorderRadius.all(Radius.circular(50))),
          //                   width: 50,
          //                   height: 50,
          //                 )),
          //             SizedBox(
          //               width: 5,
          //             ),
          //             Transform.scale(
          //                 alignment: Alignment.center,
          //                 scale: animationR.value,
          //                 child: Container(
          //                   decoration: BoxDecoration(
          //                       color: Colors.black,
          //                       borderRadius:
          //                           BorderRadius.all(Radius.circular(50))),
          //                   width: 50,
          //                   height: 50,
          //                 )),
          //             SizedBox(
          //               width: 5,
          //             ),
          //             Transform.scale(
          //                 alignment: Alignment.center,
          //                 scale: animation.value,
          //                 child: Container(
          //                   decoration: BoxDecoration(
          //                       color: Colors.black,
          //                       borderRadius:
          //                           BorderRadius.all(Radius.circular(50))),
          //                   width: 50,
          //                   height: 50,
          //                 )),
          //           ],
          //         ),
          //       )
          //     ],
          //   ),
          // ),
          // mapWidget,
          Column(
            children: [
              Flexible(
                  flex: map_expanded ? 30 : 10,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      YandexMap(
                        nightModeEnabled: false,
                        mapType: MapType.vector,
                        mapObjects: mapObjects,
                        onCameraPositionChanged:
                            (cameraPosition, reason, finished) {
                          PlacemarkMapObject placemarkMapObject =
                              mapObjects.firstWhere(
                                      (el) => el.mapId == cameraMapObjectId)
                                  as PlacemarkMapObject;

                          setState(() {
                            cameraPos = cameraPosition;
                            mapObjects[mapObjects.indexOf(placemarkMapObject)] =
                                placemarkMapObject.copyWith(
                                    point: cameraPosition.target);
                          });

                          if (!isCameraMoved) {
                            _getAddressAuto();
                            setState(() {
                              isCameraMoved = true;
                            });
                          }
                        },
                        onMapCreated: (controller) {
                          controller = controller;
                        },
                      ),
                      Center(
                        child: Icon(
                          Icons.pin_drop_rounded,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.all(20),
                                    backgroundColor: Colors.grey.shade400),
                                onPressed: () {
                                  _search();
                                },
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Text(
                                      "Продолжить",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 18,
                                          color: Colors.black),
                                    )
                                  ],
                                )),
                          ),
                        ],
                      )
                    ],
                  )),
            ],
          ),
          Column(
            children: [
              Container(
                decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(15))),
                width: MediaQuery.of(context).size.width,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.7,
                      child: TextFormField(
                        onChanged: (value) {
                          _suggest();
                        },
                        decoration: const InputDecoration(
                            hintText: "Поиск улицы",
                            border: InputBorder.none,
                            errorBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none),
                        minLines: 1,
                        maxLines: 1,
                        controller: _addressInputController,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 1),
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    color: Colors.white),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: suggestions,
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionPageByGeo extends StatefulWidget {
  final Future<SearchSessionResult> result;
  final SearchSession session;
  final Point point;

  const _SessionPageByGeo(this.point, this.session, this.result);

  @override
  _SessionState createState() => _SessionState();
}

class _SessionGeoState extends State<_SessionPageByGeo> {
  final List<MapObject> mapObjects = [];

  final List<SearchSessionResult> results = [];
  bool _progress = true;

  String? street = "";
  String? house = "";

  @override
  void initState() {
    super.initState();

    _init();
  }

  @override
  void dispose() {
    super.dispose();

    _close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Row(
          children: [Text(street ?? "не найдено"), Text(house ?? "")],
        ),
      ),
    );
  }

  List<Widget> _getList() {
    final list = <Widget>[];

    if (results.isEmpty) {
      list.add((const Text('Nothing found')));
    }
    print(results[0]
        .items![0]
        .toponymMetadata!
        .address
        .addressComponents[SearchComponentKind.street]);
    print(results[0]
        .items![0]
        .toponymMetadata!
        .address
        .addressComponents[SearchComponentKind.house]);

    setState(() {
      house = results[0]
          .items![0]
          .toponymMetadata!
          .address
          .addressComponents[SearchComponentKind.house];
      street = results[0]
          .items![0]
          .toponymMetadata!
          .address
          .addressComponents[SearchComponentKind.street];

      print(results[0].items![0].toponymMetadata!.balloonPoint.latitude);

      print(results[0].items![0].toponymMetadata!.balloonPoint.longitude);
    });
    for (var r in results) {
      list.add(Text('Page: ${r.page}'));
      list.add(Container(height: 20));

      r.items!.asMap().forEach((i, item) {
        list.add(
            Text('Item $i: ${item.toponymMetadata!.address.formattedAddress}'));
      });

      list.add(Container(height: 20));
    }

    return list;
  }

  Future<void> _cancel() async {
    await widget.session.cancel();

    setState(() {
      _progress = false;
    });
  }

  Future<void> _close() async {
    await widget.session.close();
  }

  Future<void> _init() async {
    await _handleResult(await widget.result);
  }

  Future<void> _handleResult(SearchSessionResult result) async {
    setState(() {
      _progress = false;
    });

    if (result.error != null) {
      print('Error: ${result.error}');
      return;
    }

    print('Page ${result.page}: $result');
    setState(() {
      results.add(result);
    });

    if (await widget.session.hasNextPage()) {
      print('Got ${result.found} items, fetching next page...');
      setState(() {
        _progress = true;
      });
      await _handleResult(await widget.session.fetchNextPage());
    } else {
      _getList();
    }
  }
}

class _SessionPage extends StatefulWidget {
  final Future<SearchSessionResult> result;
  final SearchSession session;
  final String query;

  const _SessionPage(this.query, this.session, this.result);

  @override
  _SessionState createState() => _SessionState();
}

class _SessionState extends State<_SessionPage> {
  final List<SearchSessionResult> results = [];
  bool _progress = true;

  @override
  void initState() {
    super.initState();

    _init();
  }

  @override
  void dispose() {
    super.dispose();

    _close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('Search ${widget.session.id}')),
        body: Container(
            padding: const EdgeInsets.all(8),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 20),
                  Expanded(
                      child: SingleChildScrollView(
                          child: Column(children: <Widget>[
                    SizedBox(
                        height: 60,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(widget.query,
                                style: const TextStyle(
                                  fontSize: 20,
                                )),
                            !_progress
                                ? Container()
                                : TextButton.icon(
                                    icon: const CircularProgressIndicator(),
                                    label: const Text('Cancel'),
                                    onPressed: _cancel)
                          ],
                        )),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        Flexible(
                          child: Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _getList(),
                              )),
                        ),
                      ],
                    ),
                  ])))
                ])));
  }

  List<Widget> _getList() {
    final list = <Widget>[];

    if (results.isEmpty) {
      list.add((const Text('Nothing found')));
    }

    for (var r in results) {
      list.add(Text('Page: ${r.page}'));
      list.add(Container(height: 20));

      r.items!.asMap().forEach((i, item) {
        list.add(
            Text('Item $i: ${item.toponymMetadata!.address.formattedAddress}'));
      });

      list.add(Container(height: 20));
    }

    return list;
  }

  Future<void> _cancel() async {
    await widget.session.cancel();

    setState(() {
      _progress = false;
    });
  }

  Future<void> _close() async {
    await widget.session.close();
  }

  Future<void> _init() async {
    await _handleResult(await widget.result);
  }

  Future<void> _handleResult(SearchSessionResult result) async {
    setState(() {
      _progress = false;
    });

    if (result.error != null) {
      print('Error: ${result.error}');
      return;
    }

    print('Page ${result.page}: $result');

    setState(() {
      results.add(result);
    });

    if (await widget.session.hasNextPage()) {
      print('Got ${result.found} items, fetching next page...');
      setState(() {
        _progress = true;
      });
      await _handleResult(await widget.session.fetchNextPage());
    }
  }
}
