import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/createAddressPage.dart';
import 'package:naliv_delivery/pages/selectBusinessesPage.dart';
import 'package:naliv_delivery/shared/loadingScreen.dart';

class SelectAddressPage extends StatefulWidget {
  const SelectAddressPage(
      {super.key, required this.addresses, required this.currentAddress});
  final List addresses;
  final Map currentAddress;
  @override
  State<SelectAddressPage> createState() => _SelectAddressPageState();
}

class _SelectAddressPageState extends State<SelectAddressPage> {
  bool _isLoading = false;
  Future<List<Map>> _getBusinesses() async {
    List<Map>? businesses = await getBusinesses();
    print(businesses);
    if (businesses == null) {
      return [];
    } else {
      return businesses;
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    determinePosition(context).then((v) {
      print(v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        floatingActionButton: Padding(
          padding: EdgeInsets.all(10),
          child: FloatingActionButton(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) {
                  return CreateAddressPage();
                },
              ));
            },
            child: Icon(Icons.add),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: Stack(
          children: [
            SafeArea(
                child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.only(left: 30, right: 30, top: 10),
                  sliver: SliverToBoxAdapter(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Container(
                        child: FittedBox(
                          child: Text(
                            "Текущий адрес",
                            style: GoogleFonts.prostoOne(
                              fontSize: 36,
                              fontWeight: FontWeight.w400,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Divider(
                        color: Colors.transparent,
                      ),
                      AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            clipBehavior: Clip.hardEdge,
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(30))),
                            child: FlutterMap(
                              options: MapOptions(
                                interactionOptions: InteractionOptions(
                                    flags: InteractiveFlag.none),
                                initialZoom: 16,
                                initialCenter: LatLng(
                                    double.parse(widget.currentAddress["lat"]),
                                    double.parse(widget.currentAddress["lon"])),
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
                                      point: LatLng(
                                          double.parse(
                                              widget.currentAddress["lat"]),
                                          double.parse(
                                              widget.currentAddress["lon"])),
                                      child: Icon(
                                        Icons.location_on,
                                        color: Colors.orangeAccent,
                                        size: 40,
                                      ))
                                ]),
                              ],
                            ),
                          )),
                      Divider(
                        color: Colors.transparent,
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.currentAddress["city_name"],
                            style: GoogleFonts.roboto(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            widget.currentAddress["address"],
                            style: GoogleFonts.prostoOne(
                              fontSize: 24,
                              fontWeight: FontWeight.w400,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            "",
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Divider(
                        color: Colors.transparent,
                      ),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(15)))),
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                            });
                            _getBusinesses().then((v) {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (context) {
                                  return SelectBusinessesPage(
                                    businesses: v,
                                    currentAddress: widget.currentAddress,
                                  );
                                },
                              ));
                              setState(() {
                                _isLoading = false;
                              });
                            });
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Продолжить",
                                style: GoogleFonts.prostoOne(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white,
                                ),
                              )
                            ],
                          )),
                      Divider(
                        color: Colors.transparent,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Другиe адреса",
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.white,
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_down, color: Colors.white),
                        ],
                      )
                    ],
                  )),
                ),
                SliverPadding(
                  padding: EdgeInsets.only(left: 30, right: 30, top: 10),
                  sliver: SliverList.builder(
                    itemCount: widget.addresses.length,
                    itemBuilder: (context, index) {
                      return Column(
                        children: [
                          ListTile(
                            onTap: () {
                              selectAddress(
                                      widget.addresses[index]["address_id"])
                                  .then((value) {
                                getAddresses().then((addresses) {
                                  Navigator.pushReplacement(context,
                                      MaterialPageRoute(
                                    builder: (context) {
                                      return SelectAddressPage(
                                          addresses: addresses,
                                          currentAddress: addresses.firstWhere(
                                            (element) =>
                                                element["is_selected"] == "1",
                                            orElse: () {
                                              return {};
                                            },
                                          ));
                                    },
                                  ));
                                });
                              });
                            },
                            trailing: Icon(Icons.keyboard_arrow_right,
                                color: Colors.white),
                            title: Text(
                              widget.addresses[index]["address"],
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: Text(
                              widget.addresses[index]["city_name"],
                              style: GoogleFonts.roboto(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Divider(
                            color: Colors.grey.shade800,
                          ),
                        ],
                      );
                    },
                  ),
                )
              ],
            )),
            _isLoading ? LoadingScrenn() : Container()
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
