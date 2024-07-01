import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naliv_delivery/main.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/preLoadDataPage.dart';
import '../globals.dart' as globals;

class ProfileCreatePage extends StatefulWidget {
  const ProfileCreatePage({super.key});

  @override
  State<ProfileCreatePage> createState() => _ProfileCreatePageState();
}

class _ProfileCreatePageState extends State<ProfileCreatePage> {
  TextEditingController _name = TextEditingController();
  TextEditingController _lastName = TextEditingController();

  DateTime selectedDate = DateTime(DateTime.now().year - 21);
  DateTime initialDate = DateTime(DateTime.now().year - 21);

  Future<void> _selectDate(BuildContext context, Function setStateObj) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDatePickerMode: DatePickerMode.year,
      initialDate: selectedDate,
      firstDate: DateTime(initialDate.year - 100),
      lastDate: initialDate,
      locale: Locale('ru', 'RU'),
    );
    if (picked != null && picked != selectedDate) {
      setStateObj(() {
        selectedDate = picked;
      });
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _name = TextEditingController()
      ..addListener(() {
        setState(() {});
      });
    _lastName = TextEditingController()
      ..addListener(() {
        setState(() {});
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: globals.mainColor,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              flex: 15,
              child: Container(
                padding: EdgeInsets.all(globals.scaleParam * 20),
                alignment: Alignment.bottomLeft,
                child: Text(
                  "Привет! Введи своё имя, чтобы начать.",
                  style: GoogleFonts.mulish(
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 13,
              child: Column(
                children: [
                  Flexible(
                    fit: FlexFit.tight,
                    child: Container(
                      margin: EdgeInsets.all(globals.scaleParam * 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(50 * globals.scaleParam),
                          bottomRight: Radius.circular(50 * globals.scaleParam),
                          topLeft: Radius.circular(50 * globals.scaleParam),
                        ),
                      ),
                      padding: EdgeInsets.all(globals.scaleParam * 40),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Column(
                            children: [
                              Flexible(
                                fit: FlexFit.tight,
                                child: TextField(
                                  controller: _name,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 50 * globals.scaleParam,
                                      color: Colors.black),
                                  minLines: 1,
                                  autofocus: true,
                                  decoration: const InputDecoration.collapsed(
                                    border: UnderlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                    hintText: "Ваше имя ",
                                  ),
                                ),
                              ),
                              Flexible(
                                fit: FlexFit.tight,
                                child: TextField(
                                  controller: _lastName,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 50 * globals.scaleParam,
                                      color: Colors.black),
                                  minLines: 1,
                                  autofocus: true,
                                  decoration: const InputDecoration.collapsed(
                                    border: UnderlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                    hintText: "Фамилия ",
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 15,
              child: Container(
                alignment: Alignment.bottomCenter,
                child: TextButton(
                  onPressed: _name.text.length >= 2
                      ? () {
                          showAdaptiveDialog(
                            context: context,
                            builder: (context) {
                              return StatefulBuilder(
                                builder: (context, setState) {
                                  return AlertDialog(
                                    title: Text("Дата рождения"),
                                    content: TextButton(
                                      onPressed: () {
                                        _selectDate(context, setState);
                                      },
                                      child: Text(
                                          "${selectedDate.day}.${selectedDate.month}.${selectedDate.year}"),
                                    ),
                                    actions: [
                                      Padding(
                                        padding: EdgeInsets.only(
                                            top: 20 * globals.scaleParam),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            TextButton(
                                              onPressed: () async {
                                                await changeName(_name.text)
                                                    .then((v) {
                                                  Navigator.pushAndRemoveUntil(
                                                      context,
                                                      MaterialPageRoute(
                                                    builder: (context) {
                                                      return PreLoadDataPage();
                                                    },
                                                  ), (route) => false);
                                                });
                                              },
                                              child: Text("Продолжить"),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                        }
                      : null,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10 * globals.scaleParam,
                      vertical: 50 * globals.scaleParam,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "продолжить",
                          style: TextStyle(
                            fontSize: 32,
                            color: _name.text.isNotEmpty &&
                                    _lastName.text.isNotEmpty
                                ? Colors.white
                                : Colors.white54,
                          ),
                        ),
                      ],
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
