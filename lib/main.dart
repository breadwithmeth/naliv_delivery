import 'dart:async';

import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/misc/colors.dart';
import 'package:naliv_delivery/pages/homePage.dart';
import 'package:naliv_delivery/pages/permissionPage.dart';
import 'package:naliv_delivery/pages/startLoadingPage.dart';
import 'package:naliv_delivery/pages/startPage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const Main());
}

class Main extends StatefulWidget {
  const Main({super.key});

  @override
  State<Main> createState() => _MainState();
}

class _MainState extends State<Main> {
  late Timer _timer;
  int _tick = 0;

  Widget _redirect = const Center(
    child: CircularProgressIndicator(),
  );

  void _initLoadingScreen() {
    setState(() {
      _redirect = StartLoadingPage();
    });
  }

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
        _redirect = PermissionPage();
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
        _redirect = PermissionPage();
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
        _redirect = PermissionPage();
      });
    }

    return isGranted;
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _initLoadingScreen();

    _checkAuth();
    // setState(() {
    //   _redirect = PermissionPage();
    // });
  }

  Future<void> _checkAuth() async {
    String? token = await getToken();
    if (token != null) {
      setState(() {
        _redirect = const HomePage();
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
    // TODO: implement dispose
    super.dispose();
    _timer.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.amber,
            background: Colors.white,
            onBackground: Colors.black,
            error: Colors.red,
            primary: Colors.black,
            onPrimary: Colors.white,
            onError: Colors.white,
            secondary: Colors.grey
                .shade300, // TODO: Change this later? To make more sense with black/white style
            onSecondary: Colors.black,
          ),
          useMaterial3: true,
          brightness: Brightness.light,
          pageTransitionsTheme: const PageTransitionsTheme(builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder()
          }),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(),
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: AppBarTheme(
            // shadowColor: Color(0x70FFFFFF),
            shadowColor: Colors.transparent,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 4,
            scrolledUnderElevation: 4,
            titleTextStyle: GoogleFonts.inter(
                fontSize: 24, fontWeight: FontWeight.w700, color: Colors.black),
            // backgroundColor: Colors.white,
            // shadowColor: Colors.grey.withOpacity(0.2),
            // foregroundColor: Colors.black
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(3))),
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
                Radius.circular(3),
              ),
            ),
          ),
          textTheme: const TextTheme(
              bodyMedium: TextStyle(color: gray1),
              titleSmall: TextStyle(
                  color: gray1, fontWeight: FontWeight.w400, fontSize: 16)),
        ),
        debugShowCheckedModeBanner: false,
        home: _redirect);
  }
}

// Стандартное закруление Radius.circular(15);