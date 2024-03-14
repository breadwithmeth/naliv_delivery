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
      "address": "${widget.street} ${widget.house}",
      "name": name.text,
      "apartment": house.text,
      "entrance": entrance.text,
      "floor": floor.text,
      "other": other.text
    });
    if (isCreated) {
      print(isCreated);
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => const BottomMenu()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
          padding: const EdgeInsets.all(20),
          width: MediaQuery.of(context).size.width,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Flexible(
                    flex: 7,
                    child: TextField(
                      decoration: InputDecoration(
                          labelText: "Название",
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: const OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.black, width: 10),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)))),
                      style:
                          const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                      controller: name,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 10,
              ),
              Row(
                children: [
                  Flexible(
                    flex: 7,
                    child: TextField(
                      decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          border: const OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.black, width: 10),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)))),
                      readOnly: true,
                      style:
                          const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                      controller: TextEditingController(text: widget.street),
                    ),
                  ),
                  const Spacer(
                    flex: 1,
                  ),
                  Flexible(
                    flex: 3,
                    child: TextField(
                      decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          border: const OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.black, width: 10),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)))),
                      readOnly: true,
                      style:
                          const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                      controller: TextEditingController(text: widget.house),
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 10,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    flex: 5,
                    child: TextField(
                      controller: house,
                      decoration: const InputDecoration(
                          labelText: "Квартира/Офис",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.black, width: 10),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)))),
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    flex: 5,
                    child: TextField(
                      controller: entrance,
                      decoration: const InputDecoration(
                          labelText: "Подъезд/Вход",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.black, width: 10),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)))),
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    flex: 3,
                    child: TextField(
                      controller: floor,
                      decoration: const InputDecoration(
                          labelText: "Этаж",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.black, width: 10),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)))),
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 10,
              ),
              Row(
                children: [
                  Flexible(
                      child: TextField(
                    decoration: const InputDecoration(
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
                  const SizedBox(
                    width: 10,
                  ),
                  Text(widget.lon.toString())
                ],
              ),
              const SizedBox(
                height: 20,
              ),
              ElevatedButton(
                  onPressed: () {
                    _createAddress();
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [Text("Добавить новый адрес")],
                  ))
            ],
          )),
    );
  }
}
