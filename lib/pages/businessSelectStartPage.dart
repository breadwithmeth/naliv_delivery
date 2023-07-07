import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
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
    child: Text("К сожалению в вашем регионе нет наших магазинов"),
  );

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
      List<Widget> _businessesWidget = [];
      businesses.forEach((element) {
        _businessesWidget.add(ListTile(
          onTap: () async {
            if (await setCurrentStore(element["business_id"])) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Main()),
              );
            }
          },
          title: Text(element["name"]),
        ));
      });
      setState(() {
        _stores = Column(
          children: _businessesWidget,
        );
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
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Text("Выберите магазин"), _stores],
        ),
      ),
    );
  }
}
