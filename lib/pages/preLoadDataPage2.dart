import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/createAddressPage.dart';
import 'package:naliv_delivery/pages/finishProfilePage.dart';
import 'package:naliv_delivery/pages/mainPage.dart';
import 'package:naliv_delivery/pages/paintLogoPage.dart';
import 'package:naliv_delivery/pages/selectAddressPage.dart';
import 'package:naliv_delivery/pages/selectBusinessesPage.dart';
import 'package:flutter/cupertino.dart';

class Preloaddatapage2 extends StatefulWidget {
  const Preloaddatapage2({super.key});

  @override
  State<Preloaddatapage2> createState() => _Preloaddatapage2State();
}

class _Preloaddatapage2State extends State<Preloaddatapage2> {
  List _addresses = [];

  Map _currentAddress = {};
  List<Map> _businesses = [];
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
      setState(() {
        _businesses = businesses;
      });
      return businesses;
    }
  }

  getInfo() {
    _getUser().then((v) {
      _getAddresses().then((v) {
        _getBusinesses().then((v) {
          if (user["first_name"] == null) {
            Navigator.pushReplacement(
              context,
              CupertinoPageRoute(
                  builder: (context) => Finishprofilepage(user: user)),
            );
          } else {
            if (_addresses.isEmpty) {
              Navigator.pushReplacement(
                context,
                CupertinoPageRoute(
                  builder: (context) => CreateAddressPage(
                    createOrder: false,
                    business: null,
                  ),
                ),
              );
            } else {
              Navigator.pushReplacement(
                context,
                CupertinoPageRoute(
                  builder: (context) => SelectAddressPage(
                    addresses: _addresses,
                    currentAddress: _currentAddress,
                    createOrder: false,
                    business: null,
                  ),
                ),
                // CupertinoPageRoute(
                //   builder: (context) => SelectBusinessesPage(
                //     addresses: _addresses,
                //     currentAddress: _currentAddress,
                //     user: user,
                //     businesses: _businesses,
                //   ),
                // ),
              );
            }
          }
        });
      });
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getInfo();
  }

  @override
  Widget build(BuildContext context) {
    return PaintLogoPage();
  }
}
