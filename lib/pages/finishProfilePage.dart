import 'package:datepicker_dropdown/order_format.dart';
import 'package:flutter/material.dart';
import 'package:datepicker_dropdown/datepicker_dropdown.dart';
import 'package:naliv_delivery/main.dart';
import 'package:naliv_delivery/misc/api.dart';

class Finishprofilepage extends StatefulWidget {
  const Finishprofilepage({super.key, required this.user});
  final Map<String, dynamic> user;

  @override
  State<Finishprofilepage> createState() => _FinishprofilepageState();
}

class _FinishprofilepageState extends State<Finishprofilepage>
    with TickerProviderStateMixin {
  late PageController _pageViewController;
  late TabController _tabController;
  int _currentPageIndex = 0;
  TextEditingController _name = TextEditingController();
  TextEditingController _last_name = TextEditingController();
  TextEditingController _first_name = TextEditingController();
  String? year = null;
  String? day = null;

  String? month = null;

  bool male = false;
  bool female = false;

  @override
  void initState() {
    super.initState();
    _pageViewController = PageController();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    super.dispose();
    _pageViewController.dispose();
    _tabController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          physics: const NeverScrollableScrollPhysics(),
          controller: _pageViewController,
          children: <Widget>[
            Container(
              decoration: const BoxDecoration(
                  boxShadow: [BoxShadow()], color: Colors.black),
              margin: const EdgeInsets.all(10),
              child: Column(
                children: [
                  const Spacer(
                    flex: 2,
                  ),
                  Flexible(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            const Text(
                              "Как Вас зовут?",
                              style: TextStyle(
                                  fontSize: 48,
                                  fontVariations: <FontVariation>[
                                    FontVariation('wght', 700)
                                  ],
                                  color: Colors.white),
                            ),
                            TextField(
                              controller: _first_name,
                              textCapitalization: TextCapitalization.words,
                              onChanged: (value) {
                                setState(() {});
                              },
                              style: const TextStyle(
                                  fontVariations: <FontVariation>[
                                    FontVariation('wght', 700)
                                  ],
                                  color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: "Имя",
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const Divider(
                              color: Colors.black,
                            ),
                            TextField(
                              controller: _last_name,
                              textCapitalization: TextCapitalization.words,
                              onChanged: (value) {
                                setState(() {});
                              },
                              style: const TextStyle(
                                  fontVariations: <FontVariation>[
                                    FontVariation('wght', 700)
                                  ],
                                  color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: "Фамилия",
                                border: OutlineInputBorder(),
                              ),
                            )
                          ],
                        ),
                      )),
                  const Spacer(),
                  Flexible(
                    child: Container(
                        width: MediaQuery.of(context).size.width / 2,
                        height: 100,
                        child: GestureDetector(
                            onTap: _first_name.text.length > 2 &&
                                    _last_name.text.length > 2
                                ? () {
                                    print(1);
                                    _pageViewController.nextPage(
                                        duration: Durations.medium4,
                                        curve: Curves.slowMiddle);
                                  }
                                : null,
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: Text(
                                _first_name.text.length > 2 &&
                                        _last_name.text.length > 2
                                    ? "Продолжить"
                                    : "",
                                style: const TextStyle(
                                    fontVariations: <FontVariation>[
                                      FontVariation('wght', 700)
                                    ],
                                    color: Colors.white),
                              ),
                            ))),
                  )
                ],
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                  boxShadow: [BoxShadow()], color: Colors.black),
              margin: const EdgeInsets.all(10),
              child: Column(
                children: [
                  const Spacer(),
                  Flexible(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            const Text(
                              "Когда Ваш день рождения?",
                              style: TextStyle(
                                  fontSize: 48,
                                  fontVariations: <FontVariation>[
                                    FontVariation('wght', 700)
                                  ],
                                  color: Colors.white),
                            ),
                            DropdownDatePicker(
                              dateformatorder:
                                  OrderFormat.YDM, // default is myd
                              inputDecoration: InputDecoration(
                                  enabledBorder: const OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Colors.grey, width: 1.0),
                                  ),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                          10))), // optional
                              isDropdownHideUnderline: false, // optional
                              isFormValidator: true, // optional
                              startYear: 1900, // optional
                              endYear: DateTime.now().year - 21, // optional
                              onChangedDay: (value) {
                                setState(() {
                                  day = value;
                                });
                              },

                              onChangedMonth: (value) {
                                setState(() {
                                  month = value;
                                });
                              },
                              onChangedYear: (value) {
                                setState(() {
                                  year = value;
                                });
                              },
                              textStyle: const TextStyle(
                                  fontVariations: <FontVariation>[
                                    FontVariation('wght', 700)
                                  ],
                                  color: Colors.white),
                              boxDecoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: Colors.grey,
                                      width: 1.0)), // optional
                              showDay: true, // optional
                              dayFlex: 2, // optional
                              locale: "ru_RU", // optional
                              hintDay: 'День', // optional
                              hintMonth: 'Месяц', // optional
                              hintYear: 'Год',
                              hintTextStyle: const TextStyle(
                                  color: Colors.grey), // optional
                            ),
                          ],
                        ),
                      )),
                  const Spacer(),
                  Flexible(
                    child: Container(
                        width: MediaQuery.of(context).size.width / 2,
                        height: 100,
                        child: GestureDetector(
                            onTap: day != null && month != null && year != null
                                ? () {
                                    print(1);
                                    _pageViewController.nextPage(
                                        duration: Durations.medium4,
                                        curve: Curves.slowMiddle);
                                  }
                                : null,
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: Text(
                                day != null && month != null && year != null
                                    ? "Продолжить"
                                    : "",
                                style: const TextStyle(
                                    fontVariations: <FontVariation>[
                                      FontVariation('wght', 700)
                                    ],
                                    color: Colors.white),
                              ),
                            ))),
                  )
                ],
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                  boxShadow: [BoxShadow()], color: Colors.black),
              margin: const EdgeInsets.all(10),
              child: Column(
                children: [
                  const Spacer(),
                  Flexible(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            const Text(
                              "Выберите пол",
                              style: TextStyle(
                                  fontSize: 48,
                                  fontVariations: <FontVariation>[
                                    FontVariation('wght', 700)
                                  ],
                                  color: Colors.white),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: ChoiceChip(
                                  onSelected: (value) {
                                    if (value) {
                                      setState(() {
                                        male = true;
                                        female = false;
                                      });
                                    } else {
                                      setState(() {
                                        male = false;
                                        female = true;
                                      });
                                    }
                                  },
                                  label: const Text(
                                    "Мужской",
                                    style: TextStyle(
                                        fontSize: 24,
                                        fontVariations: <FontVariation>[
                                          FontVariation('wght', 700)
                                        ],
                                        color: Colors.white),
                                  ),
                                  selected: male),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: ChoiceChip(
                                  onSelected: (value) {
                                    if (value) {
                                      setState(() {
                                        male = false;
                                        female = true;
                                      });
                                    } else {
                                      setState(() {
                                        male = true;
                                        female = false;
                                      });
                                    }
                                  },
                                  label: const Text(
                                    "Женский",
                                    style: TextStyle(
                                        fontSize: 24,
                                        fontVariations: <FontVariation>[
                                          FontVariation('wght', 700)
                                        ],
                                        color: Colors.white),
                                  ),
                                  selected: female),
                            ),
                          ],
                        ),
                      )),
                  const Spacer(),
                  Flexible(
                    child: Container(
                        width: MediaQuery.of(context).size.width / 2,
                        height: 100,
                        child: GestureDetector(
                            onTap: !(male || female)
                                ? null
                                : () async {
                                    print(1);
                                    if (_last_name.text.isNotEmpty &&
                                        _first_name.text.isNotEmpty &&
                                        year != null &&
                                        month != null &&
                                        day != null) {
                                      bool isfinished = await finishProfile(
                                          "${_last_name.text} ${_first_name.text}",
                                          "$year-$month-$day",
                                          _first_name.text,
                                          _last_name.text,
                                          male ? "1" : "2");
                                      if (isfinished) {
                                        print(123);
                                        Navigator.pushReplacement(context,
                                            MaterialPageRoute(
                                          builder: (context) {
                                            return Main();
                                          },
                                        ));
                                      }
                                    }
                                  },
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: Text(
                                !(male || female) ? "" : "Готово",
                                style: const TextStyle(
                                    fontVariations: <FontVariation>[
                                      FontVariation('wght', 700)
                                    ],
                                    color: Colors.white),
                              ),
                            ))),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
