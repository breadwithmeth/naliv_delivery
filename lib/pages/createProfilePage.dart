import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/preLoadDataPage2.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../globals.dart' as globals;

class ProfileCreatePage extends StatefulWidget {
  const ProfileCreatePage({super.key, required this.user});
  final Map<String, dynamic> user;
  @override
  State<ProfileCreatePage> createState() => _ProfileCreatePageState();
}

class _ProfileCreatePageState extends State<ProfileCreatePage> {
  TextEditingController _name = TextEditingController();
  TextEditingController _lastName = TextEditingController();

  DateTime selectedDate = DateTime(
      DateTime.now().year - 18, DateTime.now().month, DateTime.now().day);
  DateTime initialDate = DateTime(
      DateTime.now().year - 18, DateTime.now().month, DateTime.now().day);

  Future<void> _selectDate(BuildContext context, Function setStateObj) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDatePickerMode: DatePickerMode.day,
      initialDate: selectedDate,
      firstDate: DateTime(initialDate.year - 100),
      lastDate: initialDate,
      locale: Locale('ru', 'RU'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogBackgroundColor: Colors.deepOrange, // days/years gridview
            textTheme: TextTheme(
              bodyMedium: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 48 * globals.scaleParam,
                color: Colors.black,
              ),
            ),
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  // Title, selected date and day selection background (dark and light mode)
                  surface: Colors.grey.shade200,
                  primary: Colors.black,
                  // Title, selected date and month/year picker color (dark and light mode)
                  onSurface: Colors.black,
                  onPrimary: Colors.white,
                ),
            // Buttons
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                textStyle: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 48 * globals.scaleParam,
                  color: Colors.white,
                ),
              ),
            ),
            // Input
            inputDecorationTheme: InputDecorationTheme(
              labelStyle: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 24 * globals.scaleParam,
                color: Colors.white,
              ), // Input label
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setStateObj(() {
        selectedDate = picked;
      });
    }
  }

  @override
  void initState() {
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
                                    color: Colors.black,
                                    fontVariations: <FontVariation>[
                                      FontVariation('wght', 600)
                                    ],
                                    fontSize: 46 * globals.scaleParam,
                                  ),
                                  minLines: 1,
                                  autofocus: true,
                                  decoration: InputDecoration.collapsed(
                                    border: UnderlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                    hintText: "Ваше имя ",
                                    hintStyle: TextStyle(
                                      color: Colors.grey,
                                      fontVariations: <FontVariation>[
                                        FontVariation('wght', 500)
                                      ],
                                      fontSize: 42 * globals.scaleParam,
                                    ),
                                  ),
                                ),
                              ),
                              Flexible(
                                fit: FlexFit.tight,
                                child: TextField(
                                  controller: _lastName,
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontVariations: <FontVariation>[
                                      FontVariation('wght', 600)
                                    ],
                                    fontSize: 46 * globals.scaleParam,
                                  ),
                                  minLines: 1,
                                  autofocus: true,
                                  decoration: InputDecoration.collapsed(
                                    border: UnderlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                    hintText: "Фамилия ",
                                    hintStyle: TextStyle(
                                      color: Colors.grey,
                                      fontVariations: <FontVariation>[
                                        FontVariation('wght', 500)
                                      ],
                                      fontSize: 42 * globals.scaleParam,
                                    ),
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
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 30 * globals.scaleParam,
                                    ),
                                    titlePadding: EdgeInsets.symmetric(
                                        horizontal: 30 * globals.scaleParam,
                                        vertical: 30 * globals.scaleParam),
                                    actionsPadding: EdgeInsets.symmetric(
                                        horizontal: 30 * globals.scaleParam,
                                        vertical: 15 * globals.scaleParam),
                                    title: Text(
                                      "Дата рождения",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontVariations: <FontVariation>[
                                          FontVariation('wght', 600)
                                        ],
                                        fontSize: 46 * globals.scaleParam,
                                      ),
                                    ),
                                    content: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        TextButton(
                                          onPressed: () {
                                            _selectDate(context, setState);
                                          },
                                          child: Text(
                                            "${selectedDate.day}.${selectedDate.month}.${selectedDate.year}",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontVariations: <FontVariation>[
                                                FontVariation('wght', 500)
                                              ],
                                              fontSize: 46 * globals.scaleParam,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      Padding(
                                        padding: EdgeInsets.only(
                                            top: 5 * globals.scaleParam),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            TextButton(
                                              onPressed: () async {
                                                await changeName(_name.text)
                                                    .then((v) {
                                                  Navigator.pushAndRemoveUntil(
                                                      context,
                                                      CupertinoPageRoute(
                                                    builder: (context) {
                                                      return Preloaddatapage2();
                                                    },
                                                  ), (route) => false);
                                                });
                                              },
                                              child: Text(
                                                "Продолжить",
                                                style: TextStyle(
                                                  color: Colors.black,
                                                  fontVariations: <FontVariation>[
                                                    FontVariation('wght', 800)
                                                  ],
                                                  fontSize:
                                                      42 * globals.scaleParam,
                                                ),
                                              ),
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
                            color: _name.text.isNotEmpty &&
                                    _lastName.text.isNotEmpty
                                ? Colors.white
                                : Colors.white54,
                            fontVariations: <FontVariation>[
                              FontVariation('wght', 800)
                            ],
                            fontSize: 62 * globals.scaleParam,
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
