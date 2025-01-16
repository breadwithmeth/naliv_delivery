import 'dart:async';

import 'package:flutter/material.dart';
import 'package:naliv_delivery/main.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/loginPage.dart';
import '../globals.dart' as globals;
import 'package:flutter/cupertino.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Timer? _timer;
  int seconds = 0;

  @override
  void dispose() {
    if (_timer != null) {
      _timer!.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Color(0xFF121212),
        surfaceTintColor: Colors.transparent,
        title: Text(
          "Настройки",
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.close),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: ListView(
          children: [
            SizedBox(
              height: 50 * globals.scaleParam,
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(15)),
                color: Color(0xFF121212),
              ),
              child: TextButton(
                onPressed: () {
                  if (_timer != null) {
                    _timer!.cancel();
                  }
                  seconds = 10;
                  showDialog(
                    context: context,
                    builder: (context) {
                      return StatefulBuilder(
                        builder: (context, setStateAlert) {
                          if (_timer != null) {
                            _timer!.cancel();
                          }
                          _timer = Timer(
                            Duration(seconds: 1),
                            () {
                              if (seconds > 0) {
                                setStateAlert(() {
                                  seconds--;
                                });
                              } else {
                                _timer!.cancel();
                              }
                            },
                          );
                          return AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            title: Text(
                              "Удалить аккаунт?",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontVariations: <FontVariation>[
                                  FontVariation('wght', 800)
                                ],
                                fontSize: 42 * globals.scaleParam,
                              ),
                            ),
                            content: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 20 * globals.scaleParam),
                              child: Text(
                                "Удаление приведёт к потере всех данных.\nЭто безвозвратное действие!",
                                textAlign: TextAlign.start,
                                style: TextStyle(
                                  color: Colors.red,
                                  fontVariations: <FontVariation>[
                                    FontVariation('wght', 800)
                                  ],
                                  fontSize: 38 * globals.scaleParam,
                                ),
                              ),
                            ),
                            actions: [
                              Row(
                                children: [
                                  Flexible(
                                    fit: FlexFit.tight,
                                    child: TextButton(
                                        onPressed: seconds > 0
                                            ? null
                                            : () {
                                                logout();
                                                Timer(
                                                    const Duration(seconds: 5),
                                                    () {
                                                  Navigator.pushReplacement(
                                                      context,
                                                      CupertinoPageRoute(
                                                    builder: (context) {
                                                      return const Main();
                                                    },
                                                  ));
                                                });
                                                deleteAccount().then((value) {
                                                  Navigator.pushReplacement(
                                                      context,
                                                      CupertinoPageRoute(
                                                          builder: ((context) {
                                                    return const Main();
                                                  })));
                                                });
                                                Navigator.pushReplacement(
                                                    context, CupertinoPageRoute(
                                                  builder: (context) {
                                                    return const Main();
                                                  },
                                                ));
                                              },
                                        child: Text(
                                          seconds > 0
                                              ? "Да (${seconds.toString()})"
                                              : "Да",
                                          style: TextStyle(
                                            color: seconds > 0
                                                ? Colors.grey
                                                : Colors.red,
                                            fontVariations: <FontVariation>[
                                              FontVariation('wght', 800)
                                            ],
                                            fontSize: 48 * globals.scaleParam,
                                          ),
                                        )),
                                  ),
                                  Flexible(
                                    fit: FlexFit.tight,
                                    child: TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      child: Text(
                                        "Нет",
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                          fontVariations: <FontVariation>[
                                            FontVariation('wght', 800)
                                          ],
                                          fontSize: 48 * globals.scaleParam,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Удалить аккаунт",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontVariations: <FontVariation>[
                          FontVariation('wght', 800)
                        ],
                        fontSize: 42 * globals.scaleParam,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 25 * globals.scaleParam,
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(15)),
                color: Color(0xFF121212),
              ),
              child: TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog.adaptive(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        title: Text(
                          "Вы точно хотите выйти из аккаунта?",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontVariations: <FontVariation>[
                              FontVariation('wght', 800)
                            ],
                            fontSize: 42 * globals.scaleParam,
                          ),
                        ),
                        actionsAlignment: MainAxisAlignment.center,
                        actions: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                fit: FlexFit.tight,
                                child: TextButton(
                                  onPressed: () {
                                    logout().whenComplete(
                                      () {
                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          CupertinoPageRoute(
                                            builder: (context) =>
                                                const LoginPage(),
                                          ),
                                          (route) => false,
                                        );
                                      },
                                    );
                                  },
                                  child: Text(
                                    "Да",
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontVariations: <FontVariation>[
                                        FontVariation('wght', 800)
                                      ],
                                      fontSize: 48 * globals.scaleParam,
                                    ),
                                  ),
                                ),
                              ),
                              Flexible(
                                fit: FlexFit.tight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text(
                                    "Нет",
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontVariations: <FontVariation>[
                                        FontVariation('wght', 800)
                                      ],
                                      fontSize: 48 * globals.scaleParam,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                  // setState(() {});
                  // print(123);
                  // logout();
                  // Navigator.pushAndRemoveUntil(context, CupertinoPageRoute(
                  //   builder: (context) {
                  //     return const LoginPage();
                  //   },
                  // ));
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Выйти",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontVariations: <FontVariation>[
                          FontVariation('wght', 800)
                        ],
                        fontSize: 42 * globals.scaleParam,
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
