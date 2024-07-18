import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/createProfilePage.dart';
import 'package:naliv_delivery/pages/paintLogoPage.dart';
import '../globals.dart' as globals;
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/organizationSelectPage.dart';
import 'package:naliv_delivery/pages/pickAddressPage.dart';

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
    FlutterView view = WidgetsBinding.instance.platformDispatcher.views.first;
    Size size = view.physicalSize / view.devicePixelRatio;
    // MediaQuery.textScalerOf(context).scale(fontSize)
    if (size.aspectRatio < 1) {
      // globals.scaleParam = (height / 1920) * (width / 1080) * .4;
      globals.scaleParam = 0.4;
    } else {
      globals.scaleParam = 0.4;
      // globals.scaleParam = (height / 1080) * (width / 1920) * 1;
    }

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
          _getBusinesses().then((b) {
            if (user["name"] == null) {
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
                builder: (context) {
                  return const ProfileCreatePage();
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
                  : Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
                      builder: (context) {
                        return PickAddressPage(client: user, isFirstTime: true);
                      },
                    ), (Route<dynamic> route) => false);
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
    // TODO: implement dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const paintLogoPage();
  }
}
