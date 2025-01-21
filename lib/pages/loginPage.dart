import 'package:flutter/material.dart';
import 'package:naliv_delivery/main.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/startPage.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:naliv_delivery/shared/loadingScreen.dart';
import '../globals.dart' as globals;
import 'package:flutter/cupertino.dart';

class LoginPage extends StatefulWidget {
  const LoginPage();

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _login = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _phone_number = TextEditingController();
  final TextEditingController _one_time_code = TextEditingController();
  bool _isLoading = false;
  bool isCodeSend = false;
  String _number = "";
  Future<void> _getOneTimeCode() async {
    await getOneTimeCode("+7" + _number).then(
      (value) {
        setState(() {
          _isLoading = false;
        });
        print(_phone_number.text);
        setState(() {
          isCodeSend = true;
        });
        Navigator.pushReplacement(context, CupertinoPageRoute(
          builder: (context) {
            return VerifyPage(phone: "+7" + _number);
          },
        ));
      },
    );
  }

  buildNumPadDigitWidget(String digit, BoxConstraints constraints) {
    return Container(
      margin: EdgeInsets.all(5),
      clipBehavior: Clip.hardEdge,
      decoration:
          BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(100))),
      height: constraints.maxHeight * 0.2,
      width: constraints.maxWidth * 0.3,
      child: InkWell(
        onTap: () {
          if (_number.length < 10) {
            setState(() {
              _number += digit;
            });
          }
        },
        child: Container(
          margin: EdgeInsets.all(5),
          decoration: BoxDecoration(),
          child: Center(
            child: Text(
              digit,
              style: TextStyle(fontSize: 24),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          surfaceTintColor: Colors.black,
        ),
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Column(
              children: [
                Flexible(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(child: Container()),
                      Flexible(
                        flex: 3,
                        child: Container(
                          alignment: Alignment.center,
                          child: Text("+7" + _number,
                              style: TextStyle(fontSize: 24)),
                        ),
                      ),
                      Flexible(
                          child: IconButton(
                              onPressed: () {
                                setState(() {
                                  _number = "";
                                });
                              },
                              icon: Icon(Icons.cancel)))
                    ],
                  ),
                  flex: 2,
                ),
                Flexible(
                    child: Container(
                  alignment: Alignment.center,
                  child: Text("Введите номер телефона"),
                )),
                Flexible(
                    flex: 10,
                    child: Container(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  buildNumPadDigitWidget("1", constraints),
                                  buildNumPadDigitWidget("2", constraints),
                                  buildNumPadDigitWidget("3", constraints),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  buildNumPadDigitWidget("4", constraints),
                                  buildNumPadDigitWidget("5", constraints),
                                  buildNumPadDigitWidget("6", constraints),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  buildNumPadDigitWidget("7", constraints),
                                  buildNumPadDigitWidget("8", constraints),
                                  buildNumPadDigitWidget("9", constraints),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    height: constraints.maxHeight * 0.2,
                                    width: constraints.maxWidth * 0.3,
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          if (_number.length > 0) {
                                            _number = _number.substring(
                                                0, _number.length - 1);
                                          }
                                        });
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border:
                                              Border.all(color: Colors.black),
                                        ),
                                        child: Center(
                                          child: Icon(Icons.arrow_back_ios_new),
                                        ),
                                      ),
                                    ),
                                  ),
                                  buildNumPadDigitWidget("0", constraints),
                                  Container(
                                    height: constraints.maxHeight * 0.2,
                                    width: constraints.maxWidth * 0.3,
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _isLoading = true;
                                        });
                                        _getOneTimeCode();
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border:
                                              Border.all(color: Colors.black),
                                        ),
                                        child: Center(
                                            child:
                                                Icon(Icons.arrow_forward_ios)),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          );
                        },
                      ),
                    ))
              ],
            ),
            _isLoading ? LoadingScrenn() : Container()
          ],
        ));
  }
}

class VerifyPage extends StatefulWidget {
  const VerifyPage({super.key, required this.phone});
  final String phone;
  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  String _code = "";
  bool _isLoading = false;

  _verify() {
    verify(widget.phone, _code).then((value) {
      if (value) {
        Navigator.pushReplacement(context, CupertinoPageRoute(
          builder: (context) {
            return Main();
          },
        ));
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  buildNumPadDigitWidget(String digit, BoxConstraints constraints) {
    return Container(
      margin: EdgeInsets.all(5),
      clipBehavior: Clip.hardEdge,
      decoration:
          BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(100))),
      height: constraints.maxHeight * 0.2,
      width: constraints.maxWidth * 0.3,
      child: InkWell(
        onTap: () {
          if (_code.length < 10) {
            setState(() {
              _code += digit;
            });
          }
        },
        child: Container(
          margin: EdgeInsets.all(5),
          decoration: BoxDecoration(),
          child: Center(
            child: Text(
              digit,
              style: TextStyle(fontSize: 24),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          surfaceTintColor: Colors.black,
        ),
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Column(
              children: [
                Flexible(
                  child: Container(
                    alignment: Alignment.center,
                    child: Text(_code, style: TextStyle(fontSize: 24)),
                  ),
                  flex: 2,
                ),
                Flexible(
                    child: Container(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: () {},
                          child: Text("Изменить " + widget.phone,
                              style:
                                  TextStyle(fontSize: 12, color: Colors.white)),
                        ))),
                Flexible(
                    child: Container(
                  alignment: Alignment.center,
                  child: Text("Введите код"),
                )),
                Flexible(
                    flex: 10,
                    child: Container(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  buildNumPadDigitWidget("1", constraints),
                                  buildNumPadDigitWidget("2", constraints),
                                  buildNumPadDigitWidget("3", constraints),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  buildNumPadDigitWidget("4", constraints),
                                  buildNumPadDigitWidget("5", constraints),
                                  buildNumPadDigitWidget("6", constraints),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  buildNumPadDigitWidget("7", constraints),
                                  buildNumPadDigitWidget("8", constraints),
                                  buildNumPadDigitWidget("9", constraints),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    height: constraints.maxHeight * 0.2,
                                    width: constraints.maxWidth * 0.3,
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _code = "";
                                        });
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border:
                                              Border.all(color: Colors.black),
                                        ),
                                        child: Center(
                                          child: Icon(Icons.close),
                                        ),
                                      ),
                                    ),
                                  ),
                                  buildNumPadDigitWidget("0", constraints),
                                  Container(
                                    height: constraints.maxHeight * 0.2,
                                    width: constraints.maxWidth * 0.3,
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _isLoading = true;
                                        });
                                        // _getOneTimeCode();
                                        _verify();
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border:
                                              Border.all(color: Colors.black),
                                        ),
                                        child: Center(
                                            child:
                                                Icon(Icons.arrow_forward_ios)),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          );
                        },
                      ),
                    ))
              ],
            ),
            _isLoading ? LoadingScrenn() : Container()
          ],
        ));
  }
}
