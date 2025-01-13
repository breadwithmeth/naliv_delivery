import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naliv_delivery/pages/mainPage.dart';
import 'package:naliv_delivery/pages/paintLogoPage.dart';
import 'package:naliv_delivery/pages/preLoadDataPage2.dart';
import '../globals.dart' as globals;
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/preLoadDataPage.dart';
import 'package:naliv_delivery/pages/startPage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

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
  Widget _redirect = PaintLogoPage();

  @override
  void initState() {
    super.initState();
    // Permission.notification.request();
    // _handlePromptForPushPermission();
    // _handleOptIn();
    // OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

    // OneSignal.initialize("f9a3bf44-4a96-4859-99a9-37aa2b579577");
    // OneSignal.Notifications.requestPermission(true).then((v) {
    //   OneSignal.User.getOnesignalId().then((v) {
    //     print("onesignalid" + v!);
    //   });
    // });

    // OneSignal.Notifications.requestPermission(true);
    // //Remove this method to stop OneSignal Debugging
    // initPlatformState();
    // OneSignal.consentRequired(true);

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
        _redirect = Preloaddatapage2();
        // _redirect = MainPage();
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

  String _debugLabelString = "";
  String? _emailAddress;
  String? _smsNumber;
  String? _externalUserId;
  String? _language;
  String? _liveActivityId;
  bool _enableConsentButton = false;
  bool _requireConsent = false;

  Future<void> initPlatformState() async {
    if (!mounted) return;
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

    OneSignal.Debug.setAlertLevel(OSLogLevel.none);
    OneSignal.consentRequired(_requireConsent);

    OneSignal.initialize("f9a3bf44-4a96-4859-99a9-37aa2b579577");
// f9a3bf44-4a96-4859-99a9-37aa2b579577
    OneSignal.LiveActivities.setupDefault();

    OneSignal.Notifications.clearAll();

    OneSignal.User.pushSubscription.addObserver((state) {
      print(OneSignal.User.pushSubscription.optedIn);
      print(OneSignal.User.pushSubscription.id);
      print(OneSignal.User.pushSubscription.token);
      print(state.current.jsonRepresentation());
    });

    OneSignal.User.addObserver((state) {
      var userState = state.jsonRepresentation();
      print('OneSignal user changed: $userState');
    });

    OneSignal.Notifications.addPermissionObserver((state) {
      print("Has permission " + state.toString());
    });

    OneSignal.Notifications.addClickListener((event) {
      print('NOTIFICATION CLICK LISTENER CALLED WITH EVENT: $event');
      this.setState(() {
        _debugLabelString =
            "Clicked notification: \n${event.notification.jsonRepresentation().replaceAll("\\n", "\n")}";
      });
    });

    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      print(
          'NOTIFICATION WILL DISPLAY LISTENER CALLED WITH: ${event.notification.jsonRepresentation()}');

      /// Display Notification, preventDefault to not display
      event.preventDefault();

      /// Do async work

      /// notification.display() to display after preventing default
      event.notification.display();

      this.setState(() {
        _debugLabelString =
            "Notification received in foreground notification: \n${event.notification.jsonRepresentation().replaceAll("\\n", "\n")}";
      });
    });

    OneSignal.InAppMessages.addClickListener((event) {
      this.setState(() {
        _debugLabelString =
            "In App Message Clicked: \n${event.result.jsonRepresentation().replaceAll("\\n", "\n")}";
      });
    });
    OneSignal.InAppMessages.addWillDisplayListener((event) {
      print("ON WILL DISPLAY IN APP MESSAGE ${event.message.messageId}");
    });
    OneSignal.InAppMessages.addDidDisplayListener((event) {
      print("ON DID DISPLAY IN APP MESSAGE ${event.message.messageId}");
    });
    OneSignal.InAppMessages.addWillDismissListener((event) {
      print("ON WILL DISMISS IN APP MESSAGE ${event.message.messageId}");
    });
    OneSignal.InAppMessages.addDidDismissListener((event) {
      print("ON DID DISMISS IN APP MESSAGE ${event.message.messageId}");
    });

    this.setState(() {
      _enableConsentButton = _requireConsent;
    });

    OneSignal.InAppMessages.paused(false);
  }

  void _handlePromptForPushPermission() {
    print("Prompting for Permission");
    OneSignal.Notifications.requestPermission(true);
  }

  void _handleSetLanguage() {
    if (_language == null) return;
    print("Setting language");
    OneSignal.User.setLanguage(_language!);
  }

  void _handleConsent() {
    print("Setting consent to true");
    OneSignal.consentGiven(true);

    print("Setting state");
    this.setState(() {
      _enableConsentButton = false;
    });
  }

  void _handleSetLocationShared() {
    print("Setting location shared to true");
    OneSignal.Location.setShared(true);
  }

  void _handleGetExternalId() async {
    var externalId = await OneSignal.User.getExternalId();
    print('External ID: $externalId');
  }

  void _handleLogin() {
    print("Setting external user ID");
    if (_externalUserId == null) return;
    OneSignal.login(_externalUserId!);
    OneSignal.User.addAlias("fb_id", "1341524");
  }

  void _handleLogout() {
    OneSignal.logout();
    OneSignal.User.removeAlias("fb_id");
  }

  void _handleGetOnesignalId() async {
    var onesignalId = await OneSignal.User.getOnesignalId();
    print('OneSignal ID: $onesignalId');
  }

  void _handleOptIn() {
    OneSignal.User.pushSubscription.optIn();
  }

  void _handleOptOut() {
    OneSignal.User.pushSubscription.optOut();
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
      title: "Налив/Градусы24",
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
        // colorScheme: ColorScheme.fromSeed(
        //   seedColor: Colors.amber,
        //   surface: Colors.white,
        //   onSurface: Colors.black,
        //   error: Colors.red,
        //   primary: Colors.white,
        //   onPrimary: Colors.white,
        //   onError: Colors.white,
        //   secondary: Colors
        //       .black38, // TODO: Change this later? To make more sense with black/white style
        //   onSecondary: Colors.black,
        // ),
        useMaterial3: true,
        brightness: Brightness.dark,
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder()
        }),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(),
        scaffoldBackgroundColor: Color(0xFF000000),
        appBarTheme: AppBarTheme(
          // shadowColor: Color(0x70FFFFFF),
          shadowColor: Colors.black12,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 4,
          scrolledUnderElevation: 4,
          titleTextStyle: TextStyle(
            fontSize: 24,
            fontFamily: "Raleway",
            fontVariations: <FontVariation>[FontVariation('wght', 700)],
            overflow: TextOverflow.ellipsis,
            color: Colors.white,
          ),
          // backgroundColor: Colors.white,
          // shadowColor: Colors.grey.withOpacity(0.2),
          // foregroundColor: Colors.black
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.all(15),
            backgroundColor: Colors.grey.shade900,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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
        textTheme: GoogleFonts.robotoTextTheme(TextTheme(
            displayLarge: TextStyle(
          fontSize: 64 * globals.scaleParam,
        ))),

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
