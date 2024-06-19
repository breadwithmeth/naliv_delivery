import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naliv_delivery/main.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/preLoadDataPage.dart';
import '../globals.dart' as globals;

class ProfileCreatePage extends StatefulWidget {
  const ProfileCreatePage({super.key});

  @override
  State<ProfileCreatePage> createState() => _ProfileCreatePageState();
}

class _ProfileCreatePageState extends State<ProfileCreatePage> {
  TextEditingController _name = TextEditingController();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _name = TextEditingController()
      ..addListener(() {
        setState(() {});
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: globals.mainColor,
      body: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                  flex: 1,
                  child: Container(
                    padding: EdgeInsets.all(globals.scaleParam * 20),
                    alignment: Alignment.bottomLeft,
                    child: Text("Привет! Введи своё имя, чтобы начать.",
                        style: GoogleFonts.mulish(
                            textStyle: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                                color: Colors.white))),
                  )),
              Expanded(
                flex: 1,
                child: Container(
                    margin: EdgeInsets.all(globals.scaleParam * 40),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                            topRight: Radius.circular(50 * globals.scaleParam),
                            bottomRight:
                                Radius.circular(50 * globals.scaleParam),
                            topLeft: Radius.circular(50 * globals.scaleParam))),
                    padding: EdgeInsets.all(globals.scaleParam * 40),
                    child: TextField(
                      controller: _name,
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 50 * globals.scaleParam,
                          color: Colors.black),
                      minLines: 2,
                      maxLines: 3,
                      autofocus: true,
                      decoration: const InputDecoration.collapsed(
                          filled: true,
                          fillColor: Colors.white,
                          hintText: "Ваше имя "),
                    )),
              ),
              Expanded(
                  flex: 1,
                  child: Container(
                      alignment: Alignment.topCenter,
                      child: _name.text.length >= 2
                          ? TextButton(
                              onPressed: () async {
                                await changeName(_name.text).then((v) {
                                  Navigator.pushAndRemoveUntil(context,
                                      MaterialPageRoute(
                                    builder: (context) {
                                      return PreLoadDataPage();
                                    },
                                  ), (route) => false);
                                });
                              },
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "продолжить",
                                    style: TextStyle(
                                        fontSize: 32, color: Colors.white),
                                  ),
                                ],
                              ))
                          : Container())),
            ],
          )),
    );
  }
}
