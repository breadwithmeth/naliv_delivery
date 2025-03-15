import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naliv_delivery/misc/databaseapi.dart';
import 'package:naliv_delivery/pages/mainPage.dart';
import 'package:naliv_delivery/pages/paintLogoPage.dart';
import 'package:naliv_delivery/pages/preLoadDataPage2.dart';
import '../globals.dart' as globals;
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/startPage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

Future<void> main() async {
WidgetsFlutterBinding.ensureInitialized();
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
   runApp(const Main());
}

class Main extends StatefulWidget {
  const Main({super.key});

  @override
  State<Main> createState() => _MainState();
}

class _MainState extends State<Main> {
  Widget _redirect = PaintLogoPage();
  DatabaseManager dbm = DatabaseManager();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    String? token = await getToken();
    if (token != null) {
      setState(() {
        _redirect = Preloaddatapage2();
      });
    } else {
      setState(() {
        _redirect = const StartPage();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    FlutterView view = WidgetsBinding.instance.platformDispatcher.views.first;

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

    return CupertinoApp(
      navigatorObservers: [routeObserver],
      title: "Налив/Градусы24",
      localizationsDelegates: const [
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru'),
        Locale('en'),
      ],
      theme: CupertinoThemeData(
        applyThemeToAll: true,
        brightness:
            MediaQueryData.fromView(View.of(context)).platformBrightness,
        primaryColor: CupertinoColors.activeOrange,
        primaryContrastingColor: CupertinoColors.label,
        scaffoldBackgroundColor:
            CupertinoColors.systemBackground.resolveFrom(context),
        barBackgroundColor: CupertinoColors.systemGrey6.resolveFrom(context),
        textTheme: CupertinoTextThemeData(
          // Заголовок навигации
          navTitleTextStyle: GoogleFonts.unbounded(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: CupertinoColors.label,
          ),
          // Основной текст
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.2,
            color: CupertinoColors.label,
          ),
          // Кнопки действий
          actionTextStyle: GoogleFonts.unbounded(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.2,
            color: CupertinoColors.activeOrange,
          ),
          // Текст в навигации
          navActionTextStyle: GoogleFonts.unbounded(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.2,
            color: CupertinoColors.activeOrange,
          ),
          // Большие заголовки
          navLargeTitleTextStyle: GoogleFonts.unbounded(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: CupertinoColors.label,
          ),
          // Табуляция
          tabLabelTextStyle: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
            color: CupertinoColors.label,
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: _redirect,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
