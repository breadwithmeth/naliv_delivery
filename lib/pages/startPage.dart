import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../misc/api.dart';
import 'DealPage.dart';
import '../globals.dart' as globals;

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  List<String> images = [
    "assets/s/s3.jpg",
    "assets/s/s2.jpg",
    "assets/s/s1.jpg",
  ];

  late Timer _timer;

  int currentPage = 0;
  PageController p_controller = PageController();
  Future<void> _checkAgreement() async {
    bool? token = await getAgreement();
    if (token != true) {
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DealPage(),
          ));
    }
  }

  @override
  void initState() {
    super.initState();

    setState(() {
      _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
        setState(() {
          if (currentPage == 2) {
            currentPage = 0;
          } else {
            currentPage = currentPage + 1;
          }
        });
        p_controller.animateToPage(currentPage,
            duration: const Duration(seconds: 1), curve: Curves.decelerate);
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    p_controller.dispose();
    _timer.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        // floatingActionButton:
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Spacer(),
              Container(
                padding:
                    EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Colors.deepOrangeAccent, Colors.orange])),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                        child: Text(
                      "НАЛИВ/",
                      style: TextStyle(
                          color: Colors.white,
                          fontVariations: <FontVariation>[
                            FontVariation('wght', 700)
                          ],
                          fontSize: 48),
                    )),
                    Flexible(
                        child: Text(
                      "ГРАДУСЫ",
                      style: TextStyle(
                          color: Colors.white,
                          fontVariations: <FontVariation>[
                            FontVariation('wght', 700)
                          ],
                          fontSize: 48),
                    )),
                    Flexible(
                        child: Text(
                      "24",
                      style: TextStyle(
                          color: Colors.white,
                          fontVariations: <FontVariation>[
                            FontVariation('wght', 700)
                          ],
                          fontSize: 48),
                    )),
                  ],
                ),
              ),
              Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) {
                          return const DealPage();
                        },
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Войти",
                        style: TextStyle(
                          color: Colors.black,
                          fontVariations: <FontVariation>[
                            FontVariation('wght', 700)
                          ],
                          fontSize: 72 * globals.scaleParam,
                        ),
                      )
                    ],
                  ),
                ),
              ),
              Center(
                  child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: MediaQuery.of(context).size.width * 0.08,
                    height: MediaQuery.of(context).size.height * 0.08,
                    alignment: Alignment.center,
                    child: Image.asset("assets/s/visa.png"),
                  ),
                  SizedBox(
                    width: 20,
                  ),
                  Container(
                    width: MediaQuery.of(context).size.width * 0.08,
                    height: MediaQuery.of(context).size.height * 0.08,
                    alignment: Alignment.center,
                    child: Image.asset("assets/s/mc.png"),
                  ),
                ],
              )),
            ],
          ),
        ));
  }
}
