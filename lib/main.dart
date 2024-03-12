import 'package:flutter/material.dart';
import 'package:naliv_delivery/bottomMenu.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/misc/colors.dart';
import 'package:naliv_delivery/pages/startPage.dart';

void main() {
  runApp(const Main());
}

class Main extends StatefulWidget {
  const Main({super.key});

  @override
  State<Main> createState() => _MainState();
}

class _MainState extends State<Main> {
  Widget _redirect = const Center(
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
        _redirect = const BottomMenu(
          page: 0,
        );
      });
    } else {
      setState(() {
        _redirect = const StartPage();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          pageTransitionsTheme: const PageTransitionsTheme(builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder()
          }),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(),
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            // shadowColor: Colors.grey.withOpacity(0.2),
            // foregroundColor: Colors.black
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 15),
                foregroundColor: Colors.white),
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
