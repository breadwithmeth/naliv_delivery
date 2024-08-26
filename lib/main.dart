import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:naliv_delivery/pages/paintLogoPage.dart';
import '../globals.dart' as globals;
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/permissionPage.dart';
import 'package:naliv_delivery/pages/preLoadDataPage.dart';
import 'package:naliv_delivery/pages/startPage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'dart:async';
import 'dart:ui';

void startBackgroundService() {
  final service = FlutterBackgroundService();
  service.startService();
}

void stopBackgroundService() {
  final service = FlutterBackgroundService();
  service.invoke("stop");
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
    androidConfiguration: AndroidConfiguration(
      autoStart: true,
      onStart: onStart,
      isForegroundMode: false,
      autoStartOnBoot: true,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  final socket = io.io("your-server-url", <String, dynamic>{
    'transports': ['websocket'],
    'autoConnect': true,
  });
  socket.onConnect((_) {
    print('Connected. Socket ID: ${socket.id}');
    // Implement your socket logic here
    // For example, you can listen for events or send data
  });

  socket.onDisconnect((_) {
    print('Disconnected');
  });
  socket.on("event-name", (data) {
    //do something here like pushing a notification
  });
  service.on("stop").listen((event) {
    service.stopSelf();
    print("background process is now stopped");
  });

  service.on("start").listen((event) {});

  Timer.periodic(const Duration(seconds: 30), (timer) async {
    socket.emit("event-name", "your-message");
    Position _p = await _determinePosition();
    print(_p.latitude);
    print(_p.longitude);
    setCityAuto(_p.latitude, _p.longitude);
    print("service is successfully running ${DateTime.now().second}");
  });
}

Future<Position> _determinePosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  // Test if location services are enabled.
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services are not enabled don't continue
    // accessing the position and request users of the
    // App to enable the location services.
    return Future.error('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // Permissions are denied, next time you could try
      // requesting permissions again (this is also where
      // Android's shouldShowRequestPermissionRationale
      // returned true. According to Android guidelines
      // your App should show an explanatory UI now.
      return Future.error('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // Permissions are denied forever, handle appropriately.
    return Future.error('Location permissions are permanently denied, we cannot request permissions.');
  }

  // When we reach here, permissions are granted and we can
  // continue accessing the position of the device.
  return await Geolocator.getCurrentPosition();
}

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  await initializeService();

  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  runApp(const Main());
}

class Main extends StatefulWidget {
  const Main({super.key});

  @override
  State<Main> createState() => _MainState();
}

class _MainState extends State<Main> {
  // late Timer _timer;
  // int _tick = 0;

  // Widget _redirect = const StartLoadingPage();
  Widget _redirect = PaintLogoPage(city: "Караганда");

  Future<bool> _requestPermission() async {
    bool isGranted = true;
    final camera = Permission.camera;

    if (await camera.isDenied) {
      await camera.request().then((value) {
        if (value.isPermanentlyDenied || value.isDenied) {
          isGranted = false;
        }
      });
    } else if (await camera.isPermanentlyDenied) {
      setState(() {
        _redirect = const PermissionPage();
      });
    }

    final location = Permission.locationWhenInUse;

    if (await location.isDenied) {
      await location.request().then((value) {
        if (value.isPermanentlyDenied || value.isDenied) {
          isGranted = false;
        }
      });
    } else if (await location.isPermanentlyDenied) {
      setState(() {
        _redirect = const PermissionPage();
      });
    }
    final storage = Permission.storage;

    if (await storage.isDenied) {
      await storage.request().then((value) {
        if (value.isPermanentlyDenied || value.isDenied) {
          isGranted = false;
        }
      });
    } else if (await storage.isPermanentlyDenied) {
      setState(() {
        _redirect = const PermissionPage();
      });
    }

    return isGranted;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      print(MediaQuery.of(context).size.aspectRatio);
    });
    _checkAuth();
    setState(() {
      _redirect = PermissionPage();
    });
    FlutterNativeSplash.remove();
  }

  Future<void> _checkAuth() async {
    String? token = await getToken();
    if (token != null) {
      setState(() {
        _redirect = PreLoadDataPage();
      });
      // determinePosition().then((value) {
      //   setCityAuto(value.latitude, value.longitude).then((value) {
      //     setState(() {
      //       _redirect = const HomePage();
      //     });
      //   });
      // });
    } else {
      setState(() {
        _redirect = const StartPage();
      });
    }
    // _requestPermission().then((value) async {
    //   if (value) {
    //   } else {
    //     _redirect = PermissionPage();
    //   }
    // });
  }

  @override
  void dispose() {
    super.dispose();
    // _timer.cancel();
  }

  @override
  Widget build(BuildContext context) {
    //! UNCOMMENT IN PRODUCTION
    // SystemChrome.setPreferredOrientations([
    //   DeviceOrientation.portraitUp,
    //   DeviceOrientation.portraitDown,
    // ]);
    // First get the FlutterView.
    FlutterView view = WidgetsBinding.instance.platformDispatcher.views.first;
    print("SCREEN WIDTH IS: ${view.display.size.width}; SCREEN HEIGHT IS: ${view.display.size.height}");
    // 1560 + 720
    if (view.display.size.width + view.display.size.height >= 2560 + 1600) {
      globals.scaleParam = (view.display.size.shortestSide / 720) * 0.3;
    } else if (view.display.size.width + view.display.size.height >= 1920 + 1080) {
      globals.scaleParam = (view.display.size.shortestSide / 720) * 0.3;
    } else if (view.display.size.width + view.display.size.height >= (1560 + 720)) {
      globals.scaleParam = (view.display.size.shortestSide / 720) * 0.4;
    } else {
      globals.scaleParam = 0.5;
    }
    print("SCALE PARAM IS: ${globals.scaleParam}");
    // globals.scaleParam = 1;
    return MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('ru'),
        const Locale('en'),
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          surface: Colors.white,
          onSurface: Colors.black,
          error: Colors.red,
          primary: Colors.black,
          onPrimary: Colors.white,
          onError: Colors.white,
          secondary: Colors.black38, // TODO: Change this later? To make more sense with black/white style
          onSecondary: Colors.black,
        ),
        useMaterial3: true,
        brightness: Brightness.light,
        pageTransitionsTheme: const PageTransitionsTheme(
            builders: {TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(), TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder()}),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          // shadowColor: Color(0x70FFFFFF),
          shadowColor: Colors.black12,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 4,
          scrolledUnderElevation: 4,
          titleTextStyle: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.black),
          // backgroundColor: Colors.white,
          // shadowColor: Colors.grey.withOpacity(0.2),
          // foregroundColor: Colors.black
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
            backgroundColor: Colors.black,
            // backgroundColor: Color(0xFFFFCA3C),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(20),
            // foregroundColor: Colors.white
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(10),
            ),
          ),
        ),
        dividerTheme: DividerThemeData(
          color: Colors.grey.shade300,
        ),
        textTheme: GoogleFonts.nunitoTextTheme().copyWith(
          labelLarge: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),

        // До этого здесь был шрифт Mulish

        // textTheme: const TextTheme(
        //     bodyMedium: TextStyle(color: gray1),
        //     titleSmall: TextStyle(
        //         color: gray1, fontWeight: FontWeight.w400, fontSize: 16)),
      ),
      debugShowCheckedModeBanner: false,
      home: _redirect,
    );
  }
}

// Стандартное закруление Radius.circular(15);
// style: const TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w700,
//                 color: Colors.black,
//               ),
