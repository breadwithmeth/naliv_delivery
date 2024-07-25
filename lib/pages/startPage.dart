import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../misc/api.dart';
import 'DealPage.dart';

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
    // TODO: implement initState
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
    // TODO: implement dispose
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
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Flexible(
            flex: 14,
            fit: FlexFit.tight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: MediaQuery.of(context).size.width * 0.2,
                  height: MediaQuery.of(context).size.height * 0.2,
                  alignment: Alignment.center,
                  child: Image.asset("assets/naliv_logo.png"),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: ElevatedButton(
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
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onPrimary),
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
                width: MediaQuery.of(context).size.width * 0.1,
                height: MediaQuery.of(context).size.height * 0.1,
                alignment: Alignment.center,
                child: Image.asset("assets/s/visa.png"),
              ),
              SizedBox(
                width: 20,
              ),
              Container(
                width: MediaQuery.of(context).size.width * 0.1,
                height: MediaQuery.of(context).size.height * 0.1,
                alignment: Alignment.center,
                child: Image.asset("assets/s/mc.png"),
              ),
            ],
          )),
        ],
      ),
    );
  }
}
