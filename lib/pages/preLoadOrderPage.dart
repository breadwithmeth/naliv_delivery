import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/createOrderPage2.dart';
import 'package:naliv_delivery/shared/loadingScreen.dart';

class PreLoadOrderPage extends StatefulWidget {
  const PreLoadOrderPage({super.key, required this.business});
  final Map<dynamic, dynamic> business;

  @override
  State<PreLoadOrderPage> createState() => _PreLoadOrderPageState();
}

class _PreLoadOrderPageState extends State<PreLoadOrderPage> {
  Map currentAddress = {};
  List addresses = [];

  Future<void> _getAddresses() async {
    List _addresses = await getAddresses();

    for (var element in _addresses) {
      if (element["is_selected"] == "1") {
        setState(() {
          currentAddress = element;
          print(currentAddress);
        });
      }
    }

    setState(() {
      addresses = _addresses;
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getAddresses().then((v) {
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (context) {
          return CreateOrderPage2(
            business: widget.business,
            currentAddress: currentAddress,
            addresses: addresses,
          );
        },
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          // children: [Text(localSum.toString())],
          children: [LoadingScrenn()],
        ),
      ),
    );
  }
}
