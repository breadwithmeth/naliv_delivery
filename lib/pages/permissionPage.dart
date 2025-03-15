import 'package:flutter/material.dart';
import 'package:naliv_delivery/main.dart';
import 'package:permission_handler/permission_handler.dart';
import '../globals.dart' as globals;
import 'package:flutter/cupertino.dart';

class PermissionPage extends StatefulWidget {
  PermissionPage({super.key});

  @override
  State<PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage>
    with WidgetsBindingObserver {
  Future<void> _requestPermission() async {
    final location = Permission.locationWhenInUse;

    if (await location.isDenied) {
      await location.request();
    }
    final storage = Permission.storage;

    if (await storage.isDenied) {
      await storage.request();
    }
  }

  @override
  void initState() {
    super.initState();
    _requestPermission();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    //print('AppLifecycleState: $state');
    // if (state == AppLifecycleState.resumed) {
    //   Navigator.pushReplacement(context, CupertinoPageRoute(
    //     builder: (context) {
    //       return Main();
    //     },
    //   ));
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          "Сбор данных",
        ),
      ),
      body: Container(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Разрешите приложению доступ к:",
              style: TextStyle(
                fontFamily: "Raleway",
                fontVariations: <FontVariation>[FontVariation('wght', 500)],
                color: Colors.black,
                fontWeight: FontWeight.w700,
                fontSize: 38 * globals.scaleParam,
              ),
              softWrap: true,
            ),
            SizedBox(
              height: 10,
            ),
            Row(
              children: [
                Icon(
                  Icons.pin_drop_outlined,
                  size: 32,
                ),
                SizedBox(
                  width: 5,
                ),
                Flexible(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Геолокации:',
                          style: TextStyle(
                            fontFamily: "Raleway",
                            fontVariations: <FontVariation>[
                              FontVariation('wght', 500)
                            ],
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 28 * globals.scaleParam,
                          ),
                        ),
                        TextSpan(
                          text:
                              ' для оперделения адреса доставки и поиска оптимального маршрута доставки!',
                          style: TextStyle(
                            fontFamily: "Raleway",
                            fontVariations: <FontVariation>[
                              FontVariation('wght', 500)
                            ],
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 28 * globals.scaleParam,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
            SizedBox(
              height: 10,
            ),
            Row(
              children: [
                Icon(
                  Icons.camera_outlined,
                  size: 32,
                ),
                SizedBox(
                  width: 5,
                ),
                Flexible(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Камере:',
                          style: TextStyle(
                            fontFamily: "Raleway",
                            fontVariations: <FontVariation>[
                              FontVariation('wght', 500)
                            ],
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 28 * globals.scaleParam,
                          ),
                        ),
                        TextSpan(
                          text: '  для сканирования QR-кодов.',
                          style: TextStyle(
                            fontFamily: "Raleway",
                            fontVariations: <FontVariation>[
                              FontVariation('wght', 500)
                            ],
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 28 * globals.scaleParam,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
            SizedBox(
              height: 10,
            ),
            Row(
              children: [
                Icon(
                  Icons.file_open_outlined,
                  size: 32,
                ),
                SizedBox(
                  width: 5,
                ),
                Flexible(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Хранилищу:',
                          style: TextStyle(
                            fontFamily: "Raleway",
                            fontVariations: <FontVariation>[
                              FontVariation('wght', 500)
                            ],
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 28 * globals.scaleParam,
                          ),
                        ),
                        TextSpan(
                          text:
                              ' для кэширования данных - более быстрой загрузки и бесперебойной работы!',
                          style: TextStyle(
                            fontFamily: "Raleway",
                            fontVariations: <FontVariation>[
                              FontVariation('wght', 500)
                            ],
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 28 * globals.scaleParam,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
            SizedBox(
              height: 20,
            ),
            ElevatedButton(
              onPressed: () async {
                if (await Permission.locationWhenInUse.isPermanentlyDenied) {
                  // The user opted to never again see the permission request dialog for this
                  // app. The only way to change the permission's status now is to let the
                  // user manually enables it in the system settings.
                  await openAppSettings().then((value) {
                    Navigator.pushReplacement(context, CupertinoPageRoute(
                      builder: (context) {
                        return Main();
                      },
                    ));
                  });
                } else if (await Permission.storage.isPermanentlyDenied) {
                  await openAppSettings().then((value) {
                    Navigator.pushReplacement(context, CupertinoPageRoute(
                      builder: (context) {
                        return Main();
                      },
                    ));
                  });
                } else if (await Permission.camera.isPermanentlyDenied) {
                  await openAppSettings().then((value) {
                    Navigator.pushReplacement(context, CupertinoPageRoute(
                      builder: (context) {
                        return Main();
                      },
                    ));
                  });
                }
                Future.delayed(
                  Duration.zero,
                  () {
                    Navigator.pushReplacement(context, CupertinoPageRoute(
                      builder: (context) {
                        return Main();
                      },
                    ));
                  },
                );
              },
              child: Row(
                children: [
                  Container(
                    child: Text(
                      "Перейти в настройки",
                      style: TextStyle(
                        fontFamily: "Raleway",
                        fontVariations: <FontVariation>[
                          FontVariation('wght', 800)
                        ],
                        color: Colors.white,
                        fontSize: 42 * globals.scaleParam,
                      ),
                    ),
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
