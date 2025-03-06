import 'package:flutter/cupertino.dart';
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
        });
      }
    }

    setState(() {
      addresses = _addresses;
    });
  }

  @override
  void initState() {
    super.initState();
    _getAddresses().then((_) {
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(
          builder: (context) => CreateOrderPage2(
            business: widget.business,
            currentAddress: currentAddress,
            addresses: addresses,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LoadingScrenn(),
            ],
          ),
        ),
      ),
    );
  }
}
