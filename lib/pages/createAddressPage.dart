import 'package:flutter/material.dart';
import '../globals.dart' as globals;
import 'package:flutter/services.dart';
import 'package:naliv_delivery/bottomMenu.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/homePage.dart';

class CreateAddressName extends StatefulWidget {
  const CreateAddressName(
      {super.key, required this.street, required this.lat, required this.lon});
  final String street;
  final double lat;
  final double lon;
  @override
  State<CreateAddressName> createState() => _CreateAddressNameState();
}

class _CreateAddressNameState extends State<CreateAddressName> {
  TextEditingController floor = TextEditingController();
  TextEditingController house = TextEditingController();
  TextEditingController entrance = TextEditingController();
  TextEditingController other = TextEditingController();
  TextEditingController name = TextEditingController();

  Future<void> _createAddress() async {
    await createAddress({
      "lat": widget.lat,
      "lon": widget.lon,
      "address": "${widget.street}",
      "name": name.text,
      "apartment": house.text,
      "entrance": entrance.text,
      "floor": floor.text,
      "other": other.text
    }).then((value) {
      if (value == true) {
        // Navigator.pushReplacement(
        //     context, CupertinoPageRoute(builder: (context) => HomePage()));
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Создание адреса"),
      ),
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
                      maxLength: 250,
                      buildCounter: (context,
                          {required currentLength,
                          required isFocused,
                          required maxLength}) {
                        return null;
                      },
                      decoration: InputDecoration(
                          labelText: "Название",
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: const OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.black, width: 10),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)))),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 20),
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
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 20),
                      controller: TextEditingController(text: widget.street),
                    ),
                  ),
                  const Spacer(
                    flex: 1,
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: "Квартира/Офис",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Colors.black, width: 10),
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    flex: 5,
                    child: TextField(
                      controller: entrance,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: "Подъезд/Вход",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Colors.black, width: 10),
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    flex: 3,
                    child: TextField(
                      controller: floor,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: "Этаж",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Colors.black, width: 10),
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
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
                    maxLength: 500,
                    buildCounter: (context,
                        {required currentLength,
                        required isFocused,
                        required maxLength}) {
                      if (isFocused) {
                        return Text(
                          '$currentLength/$maxLength',
                          semanticsLabel: 'character count',
                        );
                      } else {
                        return null;
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: "Комментарий",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black, width: 10),
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                    ),
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
                ),
              )
            ],
          )),
    );
  }
}
