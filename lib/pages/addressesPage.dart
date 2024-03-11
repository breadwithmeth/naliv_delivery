import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/pickAddressPage.dart';

class AddressesPage extends StatefulWidget {
  const AddressesPage({super.key});

  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  List addresses = [];

  Future<void> _getAddresses() async {
    List addresses = await getAddresses();
    setState(() {
      addresses = addresses;
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    _getAddresses();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: GestureDetector(
        child: Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.all(10),
          width: MediaQuery.of(context).size.width,
          decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: const BorderRadius.all(Radius.circular(10))),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Добавить адрес",
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 18),
              ),
            ],
          ),
        ),
        onTap: () {          Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const PickAddressPage()),
              );},
      ),
      body: Column(
        children: [
          ListView.builder(
            primary: false,
            shrinkWrap: true,
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 25),
                decoration: BoxDecoration(
                    color: addresses[index]["is_selected"] == "1"
                        ? Colors.grey.shade700
                        : Colors.white,
                    borderRadius: const BorderRadius.all(Radius.circular(10))),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          addresses[index]["name"],
                          style: TextStyle(
                              color: addresses[index]["is_selected"] == "1"
                                  ? Colors.white
                                  : Colors.black),
                        ),
                        addresses[index]["is_selected"] == "1"
                            ? const Icon(
                                Icons.check_box_outlined,
                                color: Colors.white,
                              )
                            : Container()
                      ],
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    RichText(
                      text: TextSpan(
                          style: const TextStyle(
                              textBaseline: TextBaseline.ideographic,
                              fontSize: 12,
                              color: Colors.black),
                          children: [
                            TextSpan(
                                text: addresses[index]["city_name"],
                                style: TextStyle(color: Colors.grey.shade500)),
                            WidgetSpan(
                                child: Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: Colors.grey.shade500,
                            )),
                            TextSpan(
                                text: addresses[index]["address"],
                                style: TextStyle(color: Colors.grey.shade500)),
                          ]),
                    ),
                  ],
                ),
              );
            },
          )
        ],
      ),
    ));
  }
}
