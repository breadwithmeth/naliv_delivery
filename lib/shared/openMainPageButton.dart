import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/mainPage.dart';

class OpenMainPage extends StatefulWidget {
  const OpenMainPage({super.key});

  @override
  State<OpenMainPage> createState() => _OpenMainPageState();
}

class _OpenMainPageState extends State<OpenMainPage> {
  bool isLoading = false;

  List _addresses = [];

  Map _currentAddress = {};
  List<Map> _businesses = [];
  Map<String, dynamic> user = {};
  Future<List> _getBusinesses() async {
    List businesses = await getBusinesses();
    print(businesses);
    if (businesses == null) {
      return [];
    } else {
      return businesses;
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? Text("Загружаем...")
        : ElevatedButton(
            onPressed: () {
              setState(() {
                isLoading = true;
              });
              _getAddresses().then((v) {
                _getBusinesses().then((v) {
                  var min = v[0];
                  v.forEach((item) {
                    if (double.parse(item['distance']) <
                        double.parse(min['distance'])) min = item;
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
                              currentAddress: _currentAddress,
                              user: user!,
                              business: closestBusijess);
                        },
                      ),
                      (Route<dynamic> route) => false,
                    );
                  });
                });
              });
            },
            child: Text("Вернутся на главную страницу"));
  }
}
