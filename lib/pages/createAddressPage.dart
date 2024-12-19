import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:naliv_delivery/misc/api.dart';

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
        )
        
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
