import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:naliv_delivery/bottomMenu.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/misc/colors.dart';
import 'package:naliv_delivery/pages/DealPage.dart';
import 'package:naliv_delivery/pages/startPage.dart';

void main() {
  runApp(Main());
}

class Main extends StatefulWidget {
  const Main({super.key});

  @override
  State<Main> createState() => _MainState();
}

class _MainState extends State<Main> {
  Widget _redirect = Center(
    child: CircularProgressIndicator(),
  );

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    String? token = await getToken();
    if (token != null) {
      setState(() {
        _redirect = BottomMenu(
          page: 0,
        );
      });
    } else {
      setState(() {
        _redirect = StartPage();
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        theme: ThemeData(
          brightness: Brightness.light,
          pageTransitionsTheme: PageTransitionsTheme(builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          }),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(),
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: AppBarTheme(
              backgroundColor: Colors.white54,
              shadowColor: Colors.grey.withOpacity(0.2),
              foregroundColor: Colors.black),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10))),
              backgroundColor: Colors.black,
              padding: EdgeInsets.symmetric(vertical: 15),
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
