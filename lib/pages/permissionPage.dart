import 'package:flutter/material.dart';
import 'package:naliv_delivery/main.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionPage extends StatefulWidget {
  const PermissionPage({super.key});

  @override
  State<PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage> with WidgetsBindingObserver {
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
    print('AppLifecycleState: $state');
    // if (state == AppLifecycleState.resumed) {
    //   Navigator.pushReplacement(context, MaterialPageRoute(
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
        title: const Text(
          "Сбор данных",
        ),
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Разрешите приложению доступ к:",
              style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black, fontSize: 18),
              softWrap: true,
            ),
            const SizedBox(
              height: 10,
            ),
            Row(
              children: [
                const Icon(
                  Icons.pin_drop_outlined,
                  size: 32,
                ),
                const SizedBox(
                  width: 5,
                ),
                Flexible(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(color: Colors.black, fontSize: 16),
                      children: [
                        TextSpan(text: 'Геолокации:', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: ' для оперделения адреса доставки и поиска оптимального маршрута доставки!'),
                      ],
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            Row(
              children: [
                const Icon(
                  Icons.camera_outlined,
                  size: 32,
                ),
                const SizedBox(
                  width: 5,
                ),
                Flexible(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(color: Colors.black, fontSize: 16),
                      children: [
                        TextSpan(text: 'Камере:', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: '  для сканирования QR-кодов.'),
                      ],
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            Row(
              children: [
                const Icon(
                  Icons.file_open_outlined,
                  size: 32,
                ),
                const SizedBox(
                  width: 5,
                ),
                Flexible(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(color: Colors.black, fontSize: 16),
                      children: [
                        TextSpan(text: 'Хранилищу:', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: ' для кэширования данных - более быстрой загрузки и бесперебойной работы!'),
                      ],
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(
              height: 20,
            ),
            ElevatedButton(
              onPressed: () async {
                if (await Permission.locationWhenInUse.isPermanentlyDenied) {
                  // The user opted to never again see the permission request dialog for this
                  // app. The only way to change the permission's status now is to let the
                  // user manually enables it in the system settings.
                  await openAppSettings().then((value) {
                    Navigator.pushReplacement(context, MaterialPageRoute(
                      builder: (context) {
                        return const Main();
                      },
                    ));
                  });
                } else if (await Permission.storage.isPermanentlyDenied) {
                  await openAppSettings().then((value) {
                    Navigator.pushReplacement(context, MaterialPageRoute(
                      builder: (context) {
                        return const Main();
                      },
                    ));
                  });
                } else if (await Permission.camera.isPermanentlyDenied) {
                  await openAppSettings().then((value) {
                    Navigator.pushReplacement(context, MaterialPageRoute(
                      builder: (context) {
                        return const Main();
                      },
                    ));
                  });
                }
                Future.delayed(
                  Duration.zero,
                  () {
                    Navigator.pushReplacement(context, MaterialPageRoute(
                      builder: (context) {
                        return const Main();
                      },
                    ));
                  },
                );
              },
              child: Row(
                children: [
                  Container(
                    child: const Text("Перейти в настройки"),
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
