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
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10))),
                          backgroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: () {},
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [Icon(Icons.facebook), Text(" Facebook")],
                        )),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          alignment: Alignment.center,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10))),
                          backgroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: () {},
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [Icon(Icons.facebook), Text(" Google")],
                        )),
                  ),
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
