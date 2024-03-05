<<<<<<< HEAD
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
=======
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Flexible(
            flex: 10,
            child: Container(
              decoration: BoxDecoration(
                  image: DecorationImage(
                      colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.4), BlendMode.darken),
                      fit: BoxFit.cover,
                      image: NetworkImage(
                          "https://www.wallpaperup.com/uploads/wallpapers/2016/04/12/928589/e06cf8b680f4e013ade86a34c13138d8.jpg"))),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Expanded(
                            child: Container(
                          height: 1,
                          color: gray1,
                        )),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            "Продолжить с помощью",
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Expanded(
                            child: Container(
                          height: 1,
                          color: gray1,
                        ))
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  // Container(
                  //   padding: EdgeInsets.symmetric(horizontal: 15),
                  //   child: ElevatedButton(
                  //       style: ElevatedButton.styleFrom(
                  //         shape: RoundedRectangleBorder(
                  //             borderRadius:
                  //                 BorderRadius.all(Radius.circular(10))),
                  //         backgroundColor: Colors.black,
                  //         padding: EdgeInsets.symmetric(vertical: 15),
                  //       ),
                  //       onPressed: () {},
                  //       child: Row(
                  //         mainAxisAlignment: MainAxisAlignment.center,
                  //         children: [Icon(Icons.facebook), Text(" Facebook")],
                  //       )),
                  // ),
                  // SizedBox(
                  //   height: 10,
                  // ),
                  // Container(
                  //   padding: EdgeInsets.symmetric(horizontal: 15),
                  //   child: ElevatedButton(
                  //       style: ElevatedButton.styleFrom(
                  //         alignment: Alignment.center,
                  //         shape: RoundedRectangleBorder(
                  //             borderRadius:
                  //                 BorderRadius.all(Radius.circular(10))),
                  //         backgroundColor: Colors.black,
                  //         padding: EdgeInsets.symmetric(vertical: 15),
                  //       ),
                  //       onPressed: () {},
                  //       child: Row(
                  //         mainAxisAlignment: MainAxisAlignment.center,
                  //         children: [Icon(Icons.facebook), Text(" Google")],
                  //       )),
                  // ),
                  SizedBox(
                    height: 20,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 5,
          ),
          Flexible(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                    style: TextButton.styleFrom(primary: Colors.black),
                    onPressed: () {
                      _checkAgreement();
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LoginPage(),
                          ));
                    },
                    child: Row(
                      children: [
                        Text(
                          "Уже есть аккаунт? ",
                          style: TextStyle(
                              fontWeight: FontWeight.w400,
                              color: gray1,
                              fontSize: 16),
                        ),
                        Text(
                          "Войти",
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                              fontSize: 16),
                        )
                      ],
                    ))
              ],
            ),
          )
        ],
      ),
    );
  }
}
>>>>>>> 37ba097f1604e732d2f44d714e57c6cecb19c698
