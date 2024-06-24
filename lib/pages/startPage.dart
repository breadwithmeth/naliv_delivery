import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../globals.dart' as globals;
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
      floatingActionButton: Padding(
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
          const Spacer(),
          const Flexible(
            flex: 2,
            child: SizedBox(),
          ),
          // Flexible(
          //   flex: 2,
          //   child: Container(
          //     padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          //     child: TextButton(
          //       style: ElevatedButton.styleFrom(
          //           shape: RoundedRectangleBorder(),
          //           backgroundColor: Colors.black,
          //           foregroundColor: Colors.white),
          //       onPressed: () {
          //         // Navigator.pushReplacement(context, MaterialPageRoute(
          //         //   builder: (context) {
          //         //     return RegistrationPage();
          //         //   },
          //         // ));
          //         Navigator.pushReplacement(context, MaterialPageRoute(
          //           builder: (context) {
          //             return const DealPage();
          //           },
          //         ));
          //       },
          //       child: Container(
          //         padding:
          //             const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          //         child: Row(
          //           mainAxisSize: MainAxisSize.max,
          //           mainAxisAlignment: MainAxisAlignment.center,
          //           children: [
          //             Text(
          //               "Продолжить",
          //               style: TextStyle(
          //                 fontSize: 16,
          //                 fontWeight: FontWeight.w700,
          //                 color: Theme.of(context).colorScheme.onPrimary,
          //               ),
          //             ),
          //           ],
          //         ),
          //       ),
          //     ),
          //   ),
          // ),
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
