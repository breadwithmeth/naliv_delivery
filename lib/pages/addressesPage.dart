import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

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

  bool _isExtended = false;
  bool? _isAddressPicked = null;
  TextEditingController _search = TextEditingController();

  MapController _mapController = MapController();

  LatLng _selectedAddress = LatLng(0, 0);

  List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();
    // _showBottomSheet();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _determinePosition().then((value) {
        setState(() {
          _selectedAddress = LatLng(value.latitude, value.longitude);
        });
        _mapController.move(_selectedAddress, 20);
        setState(() {
          _markers.add(Marker(
              point: _mapController.camera.center, child: Icon(Icons.pin)));
        });
      });
    });
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Сервис местоположения отключен.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Нет разрешения к сервису местоположения');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Доступ к местоположению полностью заблокирован, мы не можем запросить разрешение.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          surfaceTintColor: Colors.white,
          automaticallyImplyLeading: true,
          title: Column(
            children: [
              Text(
                "Выбрать адрес",
              )
            ],
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
          alignment: Alignment.bottomCenter,
          children: [
            Column(
              children: [
                Expanded(
                    flex: _isExtended ? 1 : 2,
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: LatLng(51.509364, -0.128928),
                        initialZoom: 9.2,
                        onPointerDown: (event, point) {
                          setState(() {
                            _isAddressPicked = null;
                          });
                        },
                        onPointerUp: (position, hasGesture) {
                          setState(() {
                            _isAddressPicked = false;
                          });
                        },
                      ),
                      children: [
                        TileLayer(
                          tileBuilder: _darkModeTileBuilder,
                          // Display map tiles from any source
                          urlTemplate:
                              'https://{s}.maps.2gis.com/tiles?x={x}&y={y}&z={z}',
                          subdomains: ['tile0', 'tile1', 'tile2', 'tile3'],
                          // And many more recommended properties!
                        ),
                        MarkerLayer(markers: [
                          Marker(point: _selectedAddress, child: FlutterLogo())
                        ]),
                        MarkerLayer(markers: _markers),
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
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(child: Container()),
                  Flexible(
                    child: Row(
                      children: [
                        Container(
                          margin: EdgeInsets.only(bottom: 40),
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(50),
                                  topRight: Radius.circular(50),
                                  bottomRight: Radius.circular(50))),
                          child: _isAddressPicked == null
                              ? Container(child: CircularProgressIndicator())
                              : (_isAddressPicked!
                                  ? GestureDetector(
                                      child: Container(
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.3,
                                        child: Text("Использовать этот адрес"),
                                      ),
                                      onTap: () {
                                        // Navigator.push(context, CupertinoPageRoute(
                                        //   builder: (context) {
                                        //     return CreateAddressName(
                                        //         street: _adressName,
                                        //         lat: _selectedAddress.latitude,
                                        //         lon: _selectedAddress.latitude);
                                        //   },
                                        // ));
                                      },
                                    )
                                  : Container(
                                      width: MediaQuery.of(context).size.width *
                                          0.3,
                                      child: TextButton(
                                        child: Text("Выбрать"),
                                        onPressed: () {},
                                      ))),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _isExtended
                ? Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        color: Colors.white,
                        child: SingleChildScrollView(
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
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.black,
                                                    fontSize: 24),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Wrap(
                                                  crossAxisAlignment:
                                                      WrapCrossAlignment.center,
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
                                                          widget.addresses[
                                                                  index]
                                                              ["apartment"],
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Colors.black,
                                                          fontSize: 16),
                                                    ),
                                                  ],
                                                ),
                                              )
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
                                                        fontVariations: <FontVariation>[
                                                          FontVariation(
                                                              'wght', 600)
                                                        ],
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
                              ),
                              SizedBox(
                                height: 200,
                              )
                            ],
                          ),
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.all(30),
                        child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _isExtended = false;
                              });
                            },
                            child: Icon(Icons.add)),
                      )
                    ],
                  )
                : Container(
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                      color: Colors.white,
                    ),
                    margin: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          flex: 4,
                          child: TextField(
                            controller: _search,
                            decoration: const InputDecoration(
                              hintText: "Улица, дом",
                              border: OutlineInputBorder(
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Flexible(
                              flex: 4,
                              child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white,
                                      surfaceTintColor: Colors.white),
                                  onPressed: () async {
                                    await getGeoData(_search.text)
                                        .then((value) {
                                      List objects = value;

                                      double lat = double.parse(objects
                                          .first["GeoObject"]["Point"]["pos"]
                                          .toString()
                                          .split(' ')[1]);
                                      double lon = double.parse(objects
                                          .first["GeoObject"]["Point"]["pos"]
                                          .toString()
                                          .split(' ')[0]);

                                      print(value);
                                      setState(() {
                                        _selectedAddress = LatLng(lat, lon);
                                        _isAddressPicked = true;
                                      });
                                      _mapController.move(LatLng(lat, lon), 20);
                                    });
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [Icon(Icons.search)],
                                  )),
                            ),
                            Flexible(
                              child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      surfaceTintColor: Colors.white,
                                      shadowColor: Colors.transparent),
                                  onPressed: () {
                                    setState(() {
                                      _isExtended = true;
                                    });
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [Icon(Icons.arrow_upward)],
                                  )),
                            )
                          ],
                        )
                      ],
                    ),
                  )
          ],
        ));
  }
}

Widget _darkModeTileBuilder(
  BuildContext context,
  Widget tileWidget,
  TileImage tile,
) {
  return ColorFiltered(
    colorFilter: const ColorFilter.matrix(<double>[
      -0.2126, -0.7152, -0.0722, 0, 255, // Red channel
      -0.2126, -0.7152, -0.0722, 0, 255, // Green channel
      -0.2126, -0.7152, -0.0722, 0, 255, // Blue channel
      0, 0, 0, 1, 0, // Alpha channel
    ]),
    child: tileWidget,
  );
}
