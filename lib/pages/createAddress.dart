import 'package:flutter/material.dart';
import 'package:naliv_delivery/bottomMenu.dart';
import 'package:naliv_delivery/misc/api.dart';

class CreateAddress extends StatefulWidget {
  const CreateAddress(
      {super.key,
      required this.street,
      required this.house,
      required this.lat,
      required this.lon});
  final String street;
  final String house;
  final double lat;
  final double lon;
  @override
  State<CreateAddress> createState() => _CreateAddressState();
}

class _CreateAddressState extends State<CreateAddress> {
  TextEditingController floor = TextEditingController();
  TextEditingController house = TextEditingController();
  TextEditingController entrance = TextEditingController();
  TextEditingController other = TextEditingController();
  TextEditingController name = TextEditingController();

  Future<void> _createAddress() async {
    bool isCreated = await createAddress({
      "lat": widget.lat,
      "lon": widget.lon,
      "address": widget.street + " " + widget.house,
      "name": name.text,
      "apartment": house.text,
      "entrance": entrance.text,
      "floor": floor.text,
      "other": other.text
    });
    if (isCreated) {
      print(isCreated);
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => BottomMenu(page: 0)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
          padding: EdgeInsets.all(20),
          width: MediaQuery.of(context).size.width,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Flexible(
                    child: TextField(
                      decoration: InputDecoration(
                          labelText: "Название",
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.black, width: 10),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)))),
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                      controller: name,
                    ),
                    flex: 7,
                  ),
                ],
              ),
              SizedBox(
                height: 10,
              ),
              Row(
                children: [
                  Flexible(
                    child: TextField(
                      decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          border: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.black, width: 10),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)))),
                      readOnly: true,
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                      controller: TextEditingController(text: widget.street),
                    ),
                    flex: 7,
                  ),
                  Spacer(
                    flex: 1,
                  ),
                  Flexible(
                    child: TextField(
                      decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          border: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.black, width: 10),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)))),
                      readOnly: true,
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                      controller: TextEditingController(text: widget.house),
                    ),
                    flex: 3,
                  ),
                ],
              ),
              SizedBox(
                height: 10,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: TextField(
                      controller: house,
                      decoration: InputDecoration(
                          labelText: "Квартира/Офис",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.black, width: 10),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)))),
                    ),
                    flex: 5,
                  ),
                  Spacer(),
                  Flexible(
                    child: TextField(
                      controller: entrance,
                      decoration: InputDecoration(
                          labelText: "Подъезд/Вход",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.black, width: 10),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)))),
                    ),
                    flex: 5,
                  ),
                  Spacer(),
                  Flexible(
                    child: TextField(
                      controller: floor,
                      decoration: InputDecoration(
                          labelText: "Этаж",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.black, width: 10),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)))),
                    ),
                    flex: 3,
                  ),
                ],
              ),
              SizedBox(
                height: 10,
              ),
              Row(
                children: [
                  Flexible(
                      child: TextField(
                    decoration: InputDecoration(
                        labelText: "Комментарий",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.black, width: 10),
                            borderRadius:
                                BorderRadius.all(Radius.circular(10)))),
                    controller: other,
                  ))
                ],
              ),
              Row(
                children: [
                  Text(widget.lat.toString()),
                  SizedBox(
                    width: 10,
                  ),
                  Text(widget.lon.toString())
                ],
              ),
              SizedBox(
                height: 20,
              ),
              ElevatedButton(
                  onPressed: () {
                    _createAddress();
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [Text("Добавить новый адрес")],
                  ))
            ],
          )),
    );
  }
}
