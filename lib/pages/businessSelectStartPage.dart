import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:naliv_delivery/main.dart';

import '../misc/api.dart';

class BusinessSelectStartPage extends StatefulWidget {
  const BusinessSelectStartPage({super.key});

  @override
  State<BusinessSelectStartPage> createState() =>
      _BusinessSelectStartPageState();
}

class _BusinessSelectStartPageState extends State<BusinessSelectStartPage> {
  Widget _stores = Container(
    child: const Text("К сожалению в вашем регионе нет наших магазинов"),
  );

  List<Widget> _stores1 = [];

  Future<void> getPosition() async {
    Position location = await determinePosition();
    print(location.latitude);
    print(location.longitude);
    setCityAuto(location.latitude, location.longitude);
  }

  Future<void> _getBusinesses() async {
    List? businesses = await getBusinesses();
    if (businesses == null) {
    } else {
      List<Widget> businessesWidget = [];
      for (var element in businesses) {
        businessesWidget.add(Card(
          child: ListTile(
            tileColor: Colors.black12,
            onTap: () async {
              if (await setCurrentStore(element["business_id"])) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Main()),
                );
              }
            },
            title: Container(
              child: Text(element["name"]),
            ),
            subtitle: Text(element["address"]),
          ),
        ));
      }
      setState(() {
        _stores = Column(
          children: businessesWidget,
        );
        _stores1 = businessesWidget;
      });
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getBusinesses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            
            const Text("Выберите магазин"),
            ListView(
              padding: EdgeInsets.all(10),
              primary: false,
              shrinkWrap: true,
              children: _stores1,
            )
          ],
        ),
      ),
    );
  }
}
