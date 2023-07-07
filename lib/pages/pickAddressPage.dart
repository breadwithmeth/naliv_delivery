import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
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
  List<MapObject> mapObjects = [];

  Widget selectedAddress = Container();

  MapObjectId cameraMapObjectId = MapObjectId("current_location");

  bool map_expanded = true;

  TextEditingController _addressInputController = TextEditingController();

  Map<String, dynamic> city = {};
  Future<void> _getCity() async {
    Map<String, dynamic>? _city = await getCity();
    if (_city != null) {
      setState(() {
        city = _city;
      });
    }
  }

  _getStores() async {
    List? businesses = await getBusinesses();
    List<MapObject> _mapObjects = [];
    _mapObjects.add(
      PlacemarkMapObject(
        mapId: cameraMapObjectId,
        point: Point(
            latitude: (double.parse(city["x1"]) + double.parse(city["x2"])) / 2,
            longitude:
                (double.parse(city["y1"]) + double.parse(city["y2"])) / 2),
        icon: PlacemarkIcon.single(PlacemarkIconStyle(
            image: BitmapDescriptor.fromAssetImage('assets/icons/place.png'),
            scale: 0.75)),
        opacity: 0.5,
      ),
    );

    if (businesses != null) {
      businesses.forEach((element) {
        _mapObjects.add(
          PlacemarkMapObject(
            mapId: MapObjectId(element["business_id"]),
            point: Point(
                latitude: double.parse(element["lat"]),
                longitude: double.parse(element["lon"])),
            text: PlacemarkText(
                text: element["name"], style: PlacemarkTextStyle()),
            opacity: 0.5,
          ),
        );
      });
    }
    setState(() {
      mapObjects = _mapObjects;
    });
  }

  void _search() async {
    print('Point: ${cameraPos.target}, Zoom: ${cameraPos.zoom}');

    final resultWithSession = YandexSearch.searchByPoint(
      point: cameraPos.target,
      zoom: cameraPos.zoom.toInt(),
      searchOptions: SearchOptions(
        searchType: SearchType.geo,
        geometry: false,
      ),
    );

    String? _street = await resultWithSession.result.then((value) => value
        .items!
        .first
        .toponymMetadata!
        .address
        .addressComponents[SearchComponentKind.street]);
    String? _appartment = await resultWithSession.result.then((value) => value
        .items!
        .first
        .toponymMetadata!
        .address
        .addressComponents[SearchComponentKind.house]);
    double? _lat = await resultWithSession.result.then(
        (value) => value.items!.first.toponymMetadata!.balloonPoint.latitude);
    double? _lon = await resultWithSession.result.then(
        (value) => value.items!.first.toponymMetadata!.balloonPoint.longitude);
    print(_street);

    resultWithSession.session.close();

    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (BuildContext context) => CreateAddress(
                street: _street!,
                appartment: _appartment!,
                lat: _lat!,
                lon: _lon!)));
  }

  void _searchByText() async {
    final query = _addressInputController.text;

    print('Search query: $query');

    final resultWithSession = YandexSearch.searchByText(
      searchText: query,
      geometry: Geometry.fromBoundingBox(BoundingBox(
        southWest:
            Point(latitude: 55.76996383933034, longitude: 37.57483142322235),
        northEast:
            Point(latitude: 55.785322774728414, longitude: 37.590924677311705),
      )),
      searchOptions: SearchOptions(
        searchType: SearchType.geo,
        geometry: false,
      ),
    );

    double? _lat = await resultWithSession.result.then(
        (value) => value.items!.first.toponymMetadata!.balloonPoint.latitude);
    double? _lon = await resultWithSession.result.then(
        (value) => value.items!.first.toponymMetadata!.balloonPoint.longitude);
    print(_lat);

    setState(() {
      controller.moveCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: Point(latitude: _lat!, longitude: _lon!))));
      controller.moveCamera(CameraUpdate.zoomTo(20));
    });

    resultWithSession.session.close();

    // await Navigator.push(
    //     context,
    //     MaterialPageRoute(
    //         builder: (BuildContext context) => _SessionPage(
    //             query, resultWithSession.session, resultWithSession.result)));
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getCity();
    _getStores();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Выберите адрес",
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: Column(
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
                    onMapCreated: (_controller) {
                      controller = _controller;

                      controller.moveCamera(CameraUpdate.newCameraPosition(
                          CameraPosition(
                              zoom: 12,
                              target: Point(
                                  latitude: (double.parse(city["x1"]) +
                                          double.parse(city["x2"])) /
                                      2,
                                  longitude: (double.parse(city["y1"]) +
                                          double.parse(city["y2"])) /
                                      2))));
                    },
                  ),
                  Container(
                    height: 300,
                    width: MediaQuery.of(context).size.width,
                    margin: EdgeInsets.all(50),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                            onPressed: () {
                              _search();
                            },
                            child: Text(
                              "Выбрать",
                              style: TextStyle(fontSize: 14),
                            )),
                        Container(
                          width: 100,
                          child: TextFormField(
                            minLines: 1,
                            maxLines: 1,
                            controller: _addressInputController,
                          ),
                        ),
                        ElevatedButton(
                            onPressed: () {
                              _searchByText();
                            },
                            child: Text(
                              "Поиск",
                              style: TextStyle(fontSize: 14),
                            )),
                      ],
                    ),
                  )
                ],
              )),
        ],
      ),
    );
  }
}

class _SessionPageByGeo extends StatefulWidget {
  final Future<SearchSessionResult> result;
  final SearchSession session;
  final Point point;

  _SessionPageByGeo(this.point, this.session, this.result);

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
      list.add((Text('Nothing found')));
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

  _SessionPage(this.query, this.session, this.result);

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
            padding: EdgeInsets.all(8),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(height: 20),
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
                                style: TextStyle(
                                  fontSize: 20,
                                )),
                            !_progress
                                ? Container()
                                : TextButton.icon(
                                    icon: CircularProgressIndicator(),
                                    label: Text('Cancel'),
                                    onPressed: _cancel)
                          ],
                        )),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        Flexible(
                          child: Padding(
                              padding: EdgeInsets.only(top: 20),
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
      list.add((Text('Nothing found')));
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
