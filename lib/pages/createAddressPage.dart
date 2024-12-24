import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/selectAddressPage.dart';

class CreateAddressPage extends StatefulWidget {
  const CreateAddressPage({super.key});

  @override
  State<CreateAddressPage> createState() => _CreateAddressPageState();
}

class _CreateAddressPageState extends State<CreateAddressPage> {
  TextEditingController _searchController = TextEditingController();
  List addresses = [];
  MapController mapController = MapController();
  Future<void> searchGeoDataByString(String search) async {
    await getGeoData(search).then((value) {
      setState(() {
        addresses = value;
      });
      // print(value["result"]["items"]);
      // List? _fa = value["result"]["items"];
      print(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(
      children: [
        Container(
          child: FlutterMap(
            mapController: mapController,
            options: MapOptions(
              interactionOptions:
                  InteractionOptions(flags: InteractiveFlag.none),
              initialZoom: 16,
              initialCenter: LatLng(0, 0),
            ),
            children: [
              TileLayer(
                tileBuilder: _darkModeTileBuilder,
                // Display map tiles from any source
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png', // OSMF's Tile Server
                userAgentPackageName: 'com.example.app',
                // And many more recommended properties!
              ),
              // MarkerLayer(markers: [
              //   Marker(
              //       width: 80.0,
              //       height: 80.0,
              //       point: LatLng(double.parse(widget.currentAddress["lat"]),
              //           double.parse(widget.currentAddress["lon"])),
              //       child: Icon(
              //         Icons.location_on,
              //         color: Colors.orangeAccent,
              //         size: 40,
              //       ))
              // ]),
            ],
          ),
        ),
        SafeArea(
            child: Column(
          children: [
            Container(
                margin: EdgeInsets.all(15),
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Color(0xFF121212),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    Flexible(
                      child: TextFormField(
                        onFieldSubmitted: (value) {
                          searchGeoDataByString(value);
                        },
                        controller: _searchController,
                        decoration: const InputDecoration(
                          border:
                              OutlineInputBorder(borderSide: BorderSide.none),
                          hintText: 'Введите адрес',
                        ),
                      ),
                    ),
                    IconButton(
                        onPressed: () {
                          searchGeoDataByString(_searchController.text);

                          FocusScope.of(context).unfocus();
                          searchGeoDataByString(_searchController.text);
                        },
                        icon: Icon(Icons.arrow_forward_ios))
                  ],
                )),
            addresses.length > 0
                ? Container(
                    height: MediaQuery.of(context).size.height * 0.5,
                    margin: EdgeInsets.all(15),
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Color(0xFF121212),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ListView.builder(
                      primary: false,
                      shrinkWrap: true,
                      itemCount: addresses.length,
                      itemBuilder: (context, index) {
                        return Container(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                          child: ListTile(
                            title: Text(addresses[index]["name"]),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ConfirmAddressPage(
                                    currentAddress: addresses[index],
                                  ),
                                ),
                              );
                              print(addresses[index]["point"]);
                              mapController.move(
                                  LatLng(addresses[index]["point"]["lat"],
                                      addresses[index]["point"]["lon"]),
                                  16);
                              // widget.onAddressSelected();
                            },
                          ),
                        );
                      },
                    ),
                  )
                : Container()
          ],
        ))
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

class ConfirmAddressPage extends StatefulWidget {
  const ConfirmAddressPage({super.key, required this.currentAddress});
  final Map currentAddress;
  @override
  State<ConfirmAddressPage> createState() => _ConfirmAddressPageState();
}

class _ConfirmAddressPageState extends State<ConfirmAddressPage> {
  TextEditingController name = TextEditingController();
  TextEditingController house = TextEditingController();
  TextEditingController entrance = TextEditingController();
  TextEditingController floor = TextEditingController();
  TextEditingController other = TextEditingController();

  Future<void> _createAddress() async {
    await createAddress({
      "lat": widget.currentAddress["point"]["lat"],
      "lon": widget.currentAddress["point"]["lon"],
      "address": widget.currentAddress["name"],
      "name": name.text,
      "apartment": house.text,
      "entrance": entrance.text,
      "floor": floor.text,
      "other": other.text,
    }).then((value) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
              expandedHeight: MediaQuery.of(context).size.height * 0.3,
              flexibleSpace: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      interactionOptions:
                          InteractionOptions(flags: InteractiveFlag.none),
                      initialZoom: 18,
                      initialCenter: LatLng(
                          widget.currentAddress["point"]["lat"],
                          widget.currentAddress["point"]["lon"]),
                    ),
                    children: [
                      TileLayer(
                        tileBuilder: _darkModeTileBuilder,
                        // Display map tiles from any source
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png', // OSMF's Tile Server
                        userAgentPackageName: 'com.example.app',
                        // And many more recommended properties!
                      ),
                      MarkerLayer(markers: [
                        Marker(
                            width: 80.0,
                            height: 80.0,
                            point: LatLng(widget.currentAddress["point"]["lat"],
                                widget.currentAddress["point"]["lon"]),
                            child: Icon(
                              Icons.location_on,
                              color: Colors.orangeAccent,
                              size: 40,
                            ))
                      ]),
                    ],
                  ),
                ],
              )),
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.all(15),
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  Text(
                    widget.currentAddress["name"],
                    style: GoogleFonts.prostoOne(fontSize: 20),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.all(15),
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Color(0xFF121212),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  TextFormField(
                    controller: entrance,
                    decoration: InputDecoration(
                      focusColor: Colors.white,
                      hoverColor: Colors.white,
                      hintText: "Вход/Подьезд",
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                  TextFormField(
                    controller: house,
                    decoration: InputDecoration(
                      focusColor: Colors.white,
                      hintText: "Офис/Кв.",
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                  TextFormField(
                    controller: floor,
                    decoration: InputDecoration(
                      focusColor: Colors.white,
                      hintText: "Этаж",
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                  TextFormField(
                    controller: other,
                    decoration: InputDecoration(
                      focusColor: Colors.white,
                      hintText: "Дополнительно",
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
              child: Container(
            margin: EdgeInsets.all(15),
            padding: EdgeInsets.all(15),
            child: ElevatedButton(
                onPressed: () {
                  _createAddress().then((value) {
                    getAddresses().then((addresses) {
                      Navigator.pushReplacement(context, MaterialPageRoute(
                        builder: (context) {
                          return SelectAddressPage(
                              addresses: addresses,
                              currentAddress: addresses.firstWhere(
                                (element) => element["is_selected"] == "1",
                                orElse: () {
                                  return {};
                                },
                              ));
                        },
                      ));
                    });
                  });
                },
                child: Text(
                  "Сохранить адрес",
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: Colors.white),
                )),
          )),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 1000,
            ),
          )
        ],
      ),
    );
  }
}
