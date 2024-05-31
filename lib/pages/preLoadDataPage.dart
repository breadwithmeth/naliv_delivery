import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/organizationSelectPage.dart';
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

  Future<void> _getUser() async {
    await getUser().then((value) {
      setState(() {
        if (value != null) {
          user = value;
        }
      });
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getAddresses().then((v) {
      _getUser().then((vv) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
          builder: (context) {
            return OrganizationSelectPage(addresses: _addresses, currentAddress: _currentAddress, user: user,);
          },
        ), (Route<dynamic> route) => false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return const LoadingScreen();
  }
}
