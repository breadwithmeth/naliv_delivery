import 'dart:async';

import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/colors.dart';
import 'package:naliv_delivery/pages/loginPage.dart';
import 'package:naliv_delivery/pages/registrationPage.dart';

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
            builder: (context) => DealPage(),
          ));
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    setState(() {
      _timer = Timer.periodic(new Duration(seconds: 10), (timer) {
        setState(() {
          if (currentPage == 2) {
            currentPage = 0;
          } else {
            currentPage = currentPage + 1;
          }
        });
        p_controller.animateToPage(currentPage,
            duration: Duration(seconds: 1), curve: Curves.decelerate);
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
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Flexible(flex: 14, child: Container()),
          // Flexible(
          //     flex: 16,
          //     child: PageView.builder(
          //         padEnds: false,
          //         controller: p_controller,
          //         clipBehavior: Clip.none,
          //         itemCount: 3,
          //         pageSnapping: true,
          //         itemBuilder: (context, pagePosition) {
          //           return Container(
          //               child: Image.asset(
          //             images[pagePosition],
          //             fit: BoxFit.cover,
          //           ));
          //         })),
          Spacer(),
          Flexible(
              flex: 2,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                child: TextButton(
                    style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(5))),
                        backgroundColor: Color(0xFFFFCA3C)),
                    onPressed: () {
                      // Navigator.pushReplacement(context, MaterialPageRoute(
                      //   builder: (context) {
                      //     return RegistrationPage();
                      //   },
                      // ));
                      Navigator.pushReplacement(context, MaterialPageRoute(
                        builder: (context) {
                          return DealPage();
                        },
                      ));
                    },
                    child: Container(
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Продолжить",
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black),
                          ),
                        ],
                      ),
                      padding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    )),
              )),
          // Flexible(
          //     flex: 2,
          //     child: Container(
          //       child: TextButton(
          //           style: TextButton.styleFrom(
          //               foregroundColor: Colors.black,
          //               backgroundColor: Colors.transparent),
          //           onPressed: () {
          //             Navigator.pushReplacement(context, MaterialPageRoute(
          //               builder: (context) {
          //                 return LoginPage();
          //               },
          //             ));
          //           },
          //           child: Row(
          //             mainAxisAlignment: MainAxisAlignment.center,
          //             children: [
          //               Text(
          //                 "Уже есть аккаунт?  ",
          //                 style: TextStyle(
          //                     fontWeight: FontWeight.w300,
          //                     fontSize: 16,
          //                     color: Colors.grey.shade600),
          //               ),
          //               Text("Войти",
          //                   style: TextStyle(
          //                       fontWeight: FontWeight.w600,
          //                       fontSize: 16,
          //                       color: Color(0xFFFFCA3C)))
          //             ],
          //           )),
          //     )),
          // SizedBox(
          //   height: 5,
          // ),

          // Flexible(
          //   child: Row(
          //     mainAxisAlignment: MainAxisAlignment.center,
          //     children: [
          //       TextButton(
          //           style: TextButton.styleFrom(primary: Colors.black),
          //           onPressed: () {
          //             _checkAgreement();
          //             Navigator.push(
          //                 context,
          //                 MaterialPageRoute(
          //                   builder: (context) => LoginPage(),
          //                 ));
          //           },
          //           child: Row(
          //             children: [
          //               Text(
          //                 "Уже есть аккаунт? ",
          //                 style: TextStyle(
          //                     fontWeight: FontWeight.w400,
          //                     color: gray1,
          //                     fontSize: 16),
          //               ),
          //               Text(
          //                 "Войти",
          //                 style: TextStyle(
          //                     color: Colors.black,
          //                     fontWeight: FontWeight.w600,
          //                     fontSize: 16),
          //               )
          //             ],
          //           ))
          //     ],
          //   ),
          // )
        ],
      ),
    );
  }
}
