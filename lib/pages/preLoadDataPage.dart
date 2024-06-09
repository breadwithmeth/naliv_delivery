import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/createProfilePage.dart';
import '../globals.dart' as globals;
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/organizationSelectPage.dart';
import 'package:naliv_delivery/pages/pickAddressPage.dart';
import 'package:naliv_delivery/shared/loadingScreen.dart';

class PreLoadDataPage extends StatefulWidget {
  const PreLoadDataPage({super.key});

  @override
  State<PreLoadDataPage> createState() => _PreLoadDataPageState();
}

class _PreLoadDataPageState extends State<PreLoadDataPage> {
  List _addresses = [];

  Map _currentAddress = {};

  Map<String, dynamic> user = {};
  Future<void> _getAddresses() async {
    List addresses = await getAddresses();
    print(addresses);
    if (addresses.isEmpty) {
      setState(() {
        _currentAddress = {};
      });
    } else {
      setState(() {
        _addresses = addresses;
        _currentAddress = _addresses.firstWhere(
          (element) => element["is_selected"] == "1",
          orElse: () {
            return null;
          },
        );
      });
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

  Future<List> _getBusinesses() async {
    List? businesses = await getBusinesses();
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
    _getAddresses().then((v) {
      _getUser().then((vv) {
        _getBusinesses().then((b) {
          if (user["name"].toString().isEmpty) {
            Navigator.pushAndRemoveUntil(context, CupertinoPageRoute(
              builder: (context) {
                return const ProfileCreatePage();
              },
            ), (route) => false);
          } else {
            _addresses.isNotEmpty
                ? Navigator.pushAndRemoveUntil(context, CupertinoPageRoute(
                    builder: (context) {
                      return OrganizationSelectPage(
                        addresses: _addresses,
                        currentAddress: _currentAddress,
                        user: user,
                        businesses: b,
                      );
                    },
                  ), (Route<dynamic> route) => false)
                : Navigator.pushAndRemoveUntil(context, CupertinoPageRoute(
                    builder: (context) {
                      return PickAddressPage(client: user, isFirstTime: true);
                    },
                  ), (Route<dynamic> route) => false);
            _addresses.isNotEmpty
                ? Navigator.pushAndRemoveUntil(context, CupertinoPageRoute(
                    builder: (context) {
                      return OrganizationSelectPage(
                        addresses: _addresses,
                        currentAddress: _currentAddress,
                        user: user,
                        businesses: b,
                      );
                    },
                  ), (Route<dynamic> route) => false)
                : Navigator.pushAndRemoveUntil(context, CupertinoPageRoute(
                    builder: (context) {
                      return PickAddressPage(client: user, isFirstTime: true);
                    },
                  ), (Route<dynamic> route) => false);
          }
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return const LoadingScreen();
  }
}
