import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:naliv_delivery/pages/paintLogoPage.dart';
import '../globals.dart' as globals;
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/preLoadDataPage.dart';
import 'package:naliv_delivery/pages/startPage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  FlutterForegroundTask.initCommunicationPort();

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

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      print(MediaQuery.of(context).size.aspectRatio);
    });
    _checkAuth();
    setState(() {
      // _redirect = PermissionPage();
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
    print(
        "SCREEN WIDTH IS: ${view.display.size.width}; SCREEN HEIGHT IS: ${view.display.size.height}");
    // 1560 + 720
    if (view.display.size.width + view.display.size.height >= 2560 + 1600) {
      globals.scaleParam = (view.display.size.shortestSide / 720) * 0.3;
    } else if (view.display.size.width + view.display.size.height >=
        1920 + 1080) {
      globals.scaleParam = (view.display.size.shortestSide / 720) * 0.3;
    } else if (view.display.size.width + view.display.size.height >=
        (1560 + 720)) {
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
        fontFamily: "Raleway",
        typography: Typography.material2021(),
        bottomSheetTheme:
            BottomSheetThemeData(backgroundColor: Colors.transparent),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          surface: Colors.white,
          onSurface: Colors.black,
          error: Colors.red,
          primary: Colors.black,
          onPrimary: Colors.white,
          onError: Colors.white,
          secondary: Colors
              .black38, // TODO: Change this later? To make more sense with black/white style
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
          shadowColor: Colors.black12,
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
                borderRadius: BorderRadius.all(Radius.circular(15))),
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
        textTheme: TextTheme(
            displayLarge: TextStyle(
                fontFamily: "MontserratAlternates",
                fontWeight: FontWeight.w700,
                fontSize: 64 * globals.scaleParam)),

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






