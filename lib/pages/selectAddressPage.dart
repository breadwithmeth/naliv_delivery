import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/createAddressPage.dart';
import 'package:naliv_delivery/pages/mainPage.dart';
import 'package:naliv_delivery/pages/preLoadOrderPage.dart';
import 'package:naliv_delivery/pages/selectBusinessesPage.dart';
import 'package:naliv_delivery/shared/loadingScreen.dart';
import 'package:flutter/cupertino.dart';

class SelectAddressPage extends StatefulWidget {
  const SelectAddressPage(
      {super.key,
      required this.addresses,
      required this.currentAddress,
      required this.createOrder,
      required this.business});
  final List addresses;
  final Map currentAddress;
  final bool createOrder;
  final Map? business;
  @override
  State<SelectAddressPage> createState() => _SelectAddressPageState();
}

class _SelectAddressPageState extends State<SelectAddressPage> {
  bool _isLoading = false;
  List addresses = [];
  Future<List> _getBusinesses() async {
    List businesses = await getBusinesses();
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
    if (mounted) {
      setState(() {
        addresses = widget.addresses;
      });
    }
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
              Navigator.push(context, CupertinoPageRoute(
                builder: (context) {
                  return CreateAddressPage(
                      createOrder: widget.createOrder,
                      business: widget.business);
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
                widget.currentAddress["lat"] != null
                    ? SliverPadding(
                        padding: EdgeInsets.only(left: 30, right: 30, top: 10),
                        sliver: SliverToBoxAdapter(
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Container(
                              child: FittedBox(
                                child: Text(
                                  "Текущий адрес     ",
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
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(30))),
                                  child: FlutterMap(
                                    options: MapOptions(
                                      interactionOptions: InteractionOptions(
                                          flags: InteractiveFlag.none),
                                      initialZoom: 18,
                                      initialCenter: LatLng(
                                          double.parse(
                                              widget.currentAddress["lat"] ??
                                                  "0"),
                                          double.parse(
                                              widget.currentAddress["lon"] ??
                                                  "0")),
                                    ),
                                    children: [
                                      TileLayer(
                                        tileBuilder: _darkModeTileBuilder,
                                        // Display map tiles from any source
                                        urlTemplate:
                                            'https://{s}.maps.2gis.com/tiles?x={x}&y={y}&z={z}',
                                        subdomains: [
                                          'tile0',
                                          'tile1',
                                          'tile2',
                                          'tile3'
                                        ],
                                        // And many more recommended properties!
                                      ),
                                      MarkerLayer(markers: [
                                        Marker(
                                            width: 80.0,
                                            height: 80.0,
                                            point: LatLng(
                                                double.parse(
                                                    widget.currentAddress[
                                                            "lat"] ??
                                                        "0"),
                                                double.parse(
                                                    widget.currentAddress[
                                                            "lon"] ??
                                                        "0")),
                                            child: Icon(
                                              Icons.location_on,
                                              color: Color(0xFFEE7203),
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
                                  widget.currentAddress["city_name"] ??
                                      "Этого города еще нет в базе",
                                  style: GoogleFonts.roboto(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  widget.currentAddress["address"] ?? "",
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
                                    backgroundColor: Color(0xFFEE7203),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(15)))),
                                onPressed: () {
                                  setState(() {
                                    _isLoading = true;
                                  });
                                  _getBusinesses().then((v) {
                                    if (widget.createOrder) {
                                      Navigator.pushReplacement(context,
                                          CupertinoPageRoute(
                                              builder: (context) {
                                        return PreLoadOrderPage(
                                            business: widget.business!);
                                      }));
                                    } else {
                                      // print(v);
                                      // v.sort((a, b) => a['distance']
                                      //     .compareTo(b['distance']));
                                      // Map closestBusijess = v.where(
                                      //   (element) {

                                      //   },
                                      // );

                                      var min = v[0];
                                      v.forEach((item) {
                                        if (double.parse(item['distance']) <
                                            double.parse(min['distance']))
                                          min = item;
                                      });
                                      print(min['distance']);
                                      print(v);
                                      Map closestBusijess = min;
                                      print(closestBusijess);
                                      getUser().then((user) {
                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          CupertinoPageRoute(
                                            builder: (context) {
                                              return MainPage(
                                                  businesses: v,
                                                  currentAddress:
                                                      widget.currentAddress,
                                                  user: user!,
                                                  business: closestBusijess);
                                            },
                                          ),
                                          (Route<dynamic> route) => false,
                                        );
                                      });
                                      Navigator.push(context,
                                          CupertinoPageRoute(
                                        builder: (context) {
                                          return SelectBusinessesPage(
                                            businesses: v,
                                            currentAddress:
                                                widget.currentAddress,
                                          );
                                        },
                                      ));
                                      setState(() {
                                        _isLoading = false;
                                      });
                                    }
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
                                Icon(Icons.keyboard_arrow_down,
                                    color: Colors.white),
                              ],
                            )
                          ],
                        )),
                      )
                    : SliverToBoxAdapter(),
                SliverPadding(
                  padding: EdgeInsets.only(left: 0, right: 0, top: 10),
                  sliver: SliverList.builder(
                    itemCount: addresses.length,
                    itemBuilder: (context, index) {
                      return Column(
                        children: [
                          ListTile(
                            leading: IconButton(
                                onPressed: () {
                                  print("object");
                                  setState(() {
                                    addresses.removeAt(index);
                                  });
                                  deleteAddress(
                                    addresses[index]["address_id"],
                                  );
                                },
                                icon: Icon(Icons.close)),
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                            onTap: () {
                              selectAddress(addresses[index]["address_id"])
                                  .then((value) {
                                getAddresses().then((addresses) {
                                  Navigator.pushReplacement(context,
                                      CupertinoPageRoute(
                                    builder: (context) {
                                      return SelectAddressPage(
                                          addresses: addresses,
                                          currentAddress: addresses.firstWhere(
                                            (element) =>
                                                element["is_selected"] == "1",
                                            orElse: () {
                                              return {};
                                            },
                                          ),
                                          createOrder: widget.createOrder,
                                          business: widget.business);
                                    },
                                  ));
                                });
                              });
                            },
                            trailing: Icon(Icons.keyboard_arrow_right,
                                color: Colors.white),
                            title: Text(
                              addresses[index]["address"],
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: Text(
                              addresses[index]["city_name"] ??
                                  "Этого города еще нет в базе",
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
