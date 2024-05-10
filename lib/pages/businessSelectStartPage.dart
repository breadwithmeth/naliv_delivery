import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:naliv_delivery/main.dart';
import 'package:naliv_delivery/pages/homePage.dart';
import 'package:shimmer/shimmer.dart';

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

  bool isBusinessesLoading = false;

  Future<void> getPosition() async {
    Position location = await determinePosition(context);
    print(location.latitude);
    print(location.longitude);
    setCityAuto(location.latitude, location.longitude);
  }

  Future<void> _getBusinesses() async {
    setState(() {
      isBusinessesLoading = true;
    });
    List? businesses = await getBusinesses();
    if (businesses == null) {
    } else {
      List<Widget> businessesWidget = [];
      for (var element in businesses) {
        businessesWidget.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Card(
            color: Colors.black12,
            elevation: 0.0,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10))),
            child: ListTile(
              onTap: () async {
                if (await setCurrentStore(element["business_id"])) {
                  Navigator.pushAndRemoveUntil(context,
                      MaterialPageRoute(builder: (context) {
                    return Main();
                  }), (route) => false);
                }
              },
              title: Container(
                child: Text(element["name"].toString().toUpperCase()),
              ),
              subtitle: Text(element["address"]),
            ),
          ),
        ));
      }
      setState(() {
        _stores = Column(
          children: businessesWidget,
        );
        _stores1 = businessesWidget;
        isBusinessesLoading = false;
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
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                "Выберите магазин",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
            ),
            isBusinessesLoading
                ? Shimmer.fromColors(
                    baseColor: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withOpacity(0.05),
                    highlightColor: Theme.of(context).colorScheme.secondary,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Container(
                            width: MediaQuery.of(context).size.width,
                            height: 70,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.all(
                                Radius.circular(10),
                              ),
                              color: Theme.of(context).colorScheme.background,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Container(
                            width: MediaQuery.of(context).size.width,
                            height: 70,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.all(
                                Radius.circular(10),
                              ),
                              color: Theme.of(context).colorScheme.background,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Container(
                            width: MediaQuery.of(context).size.width,
                            height: 70,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.all(
                                Radius.circular(10),
                              ),
                              color: Theme.of(context).colorScheme.background,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Flexible(
                    flex: 2,
                    child: ListView(
                      padding: EdgeInsets.zero,
                      primary: false,
                      shrinkWrap: true,
                      children: _stores1,
                    ),
                  ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Card(
                color: Theme.of(context).colorScheme.primary,
                elevation: 0.0,
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                child: ListTile(
                  onTap: () {
                    Navigator.pushAndRemoveUntil(context,
                        MaterialPageRoute(builder: (context) {
                      return const HomePage();
                    }), (route) => false);
                  },
                  title: Container(
                    child: Text(
                      "Назад",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
