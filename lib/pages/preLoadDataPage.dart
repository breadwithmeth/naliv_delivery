import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:naliv_delivery/pages/createProfilePage.dart';
import 'package:naliv_delivery/pages/finishProfilePage.dart';
import 'package:naliv_delivery/pages/paintLogoPage.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/organizationSelectPage.dart';
import 'package:naliv_delivery/pages/pickAddressPage.dart';
import 'package:naliv_delivery/pages/pickOnMap.dart';

class PreLoadDataPage extends StatefulWidget {
  const PreLoadDataPage({super.key});

  @override
  State<PreLoadDataPage> createState() => _PreLoadDataPageState();
}

class _PreLoadDataPageState extends State<PreLoadDataPage> {
  List _addresses = [];

  Map _currentAddress = {};

  Map<String, dynamic> user = {};
  Future<bool> _getAddresses() async {
    List addresses = await getAddresses();
    print(addresses);
    if (addresses.isEmpty) {
      setState(() {
        _currentAddress = {};
      });
      return true;
    } else {
      setState(() {
        _addresses = addresses;
        _currentAddress = _addresses.firstWhere(
          (element) => element["is_selected"] == "1",
          orElse: () {
            return {};
          },
        );
      });
      return true;
    }
  }

  Future<void> _getUser() async {
    await getUser().then((value) {
      setState(() {
        if (value != null) {
          user = value;
        }
      });
    });
  }

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
    super.initState();
    // FlutterView view = WidgetsBinding.instance.platformDispatcher.views.first;
    // Size size = view.physicalSize / view.devicePixelRatio;
    // MediaQuery.textScalerOf(context).scale(fontSize)
    // if (size.aspectRatio < 1) {
    //   // globals.scaleParam = (height / 1920) * (width / 1080) * .4;
    //   globals.scaleParam = 0.4;
    // } else {
    //   globals.scaleParam = 0.4;
    //   // globals.scaleParam = (height / 1080) * (width / 1920) * 1;
    // }

    // globals.scaleParam = 1;

    _getAddresses().then((v) {
      if (v == false) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
          builder: (context) {
            return PickAddressPage(client: user, isFirstTime: true);
          },
        ), (Route<dynamic> route) => false);
      } else {
        _getUser().then((vv) {
          user["city_name"] = _currentAddress["city_name"];
          _getBusinesses().then((b) {
            if (user.values.where((v) {
                  return v == null;
                }).length >
                0) {
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
                builder: (context) {
                  return Finishprofilepage(
                    user: user,
                  );
                },
              ), (route) => false);
            } else {
              _addresses.isNotEmpty
                  ? Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
                      builder: (context) {
                        return OrganizationSelectPage(
                          addresses: _addresses,
                          currentAddress: _currentAddress,
                          user: user,
                          businesses: b,
                        );
                      },
                    ), (Route<dynamic> route) => false)
                  : () {
                      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
                        builder: (context) {
                          return PickAddressPage(
                              client: user, isFirstTime: true);
                        },
                      ), (Route<dynamic> route) => false);
                      // Navigator.push(context, MaterialPageRoute(builder: (context) {
                      //   return PickOnMapPage(currentPosition: , cities: );
                      // },))
                    };
              _addresses.isNotEmpty
                  ? Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
                      builder: (context) {
                        return OrganizationSelectPage(
                          addresses: _addresses,
                          currentAddress: _currentAddress,
                          user: user,
                          businesses: b,
                        );
                      },
                    ), (Route<dynamic> route) => false)
                  : Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
                      builder: (context) {
                        return PickAddressPage(client: user, isFirstTime: true);
                      },
                    ), (Route<dynamic> route) => false);
            }
          });
        });
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentAddress.isEmpty) {
      return PaintLogoPage(city: "Павлодар");
    } else {
      return PaintLogoPage(city: _currentAddress["city_name"]);
    }
  }
}
