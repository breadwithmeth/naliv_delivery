import 'package:flutter/material.dart';
import 'package:naliv_delivery/main.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/startPage.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../globals.dart' as globals;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.login = "", this.password = ""});
  final String login;
  final String password;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _login = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _phone_number = TextEditingController();
  final TextEditingController _one_time_code = TextEditingController();
  bool isCodeSend = false;
  String _number = "";
  Future<void> _getOneTimeCode() async {
    await getOneTimeCode(_number).then(
      (value) {
        print(_phone_number.text);
        setState(() {
          isCodeSend = true;
        });
      },
    );
  }

  @override
  void initState() {
    super.initState();
    if (!(widget.login.isEmpty && widget.password.isEmpty)) {
      setState(() {
        _login.text = widget.login;
        _password.text = widget.password;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: Padding(
      padding: EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            fit: FlexFit.tight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  fit: FlexFit.tight,
                  child: Text(
                    "Вход",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontVariations: <FontVariation>[
                        FontVariation('wght', 800)
                      ],
                      fontSize: 42 * globals.scaleParam,
                    ),
                  ),
                )
              ],
            ),
          ),
          Flexible(
            flex: 1,
            fit: FlexFit.tight,
            child: Form(
              autovalidateMode: AutovalidateMode.always,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    flex: 6,
                    fit: FlexFit.tight,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: IntlPhoneField(
                            controller: _phone_number,
                            enabled: !isCodeSend,
                            dropdownIconPosition: IconPosition.trailing,
                            showCountryFlag: true,
                            style: TextStyle(
                              color: Colors.white,
                              fontVariations: <FontVariation>[
                                FontVariation('wght', 500)
                              ],
                              fontSize: 42 * globals.scaleParam,
                            ),
                            dropdownTextStyle: TextStyle(
                              color: Colors.white,
                              fontVariations: <FontVariation>[
                                FontVariation('wght', 500)
                              ],
                              fontSize: 42 * globals.scaleParam,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Номер телефона',
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(10)),
                              ),
                              hintStyle: TextStyle(
                                color: Colors.grey,
                                fontVariations: <FontVariation>[
                                  FontVariation('wght', 500)
                                ],
                                fontSize: 42 * globals.scaleParam,
                              ),
                              labelStyle: TextStyle(
                                color: Colors.grey,
                                fontVariations: <FontVariation>[
                                  FontVariation('wght', 500)
                                ],
                                fontSize: 42 * globals.scaleParam,
                              ),
                              errorStyle: TextStyle(
                                color: Colors.red,
                                fontVariations: <FontVariation>[
                                  FontVariation('wght', 500)
                                ],
                                fontSize: 28 * globals.scaleParam,
                              ),
                              prefixStyle: TextStyle(
                                color: Colors.white,
                                fontVariations: <FontVariation>[
                                  FontVariation('wght', 500)
                                ],
                                fontSize: 42 * globals.scaleParam,
                              ),
                              helperStyle: TextStyle(
                                color: Colors.white,
                                fontVariations: <FontVariation>[
                                  FontVariation('wght', 500)
                                ],
                                fontSize: 38 * globals.scaleParam,
                              ),
                              floatingLabelStyle: TextStyle(
                                color: Colors.white,
                                fontVariations: <FontVariation>[
                                  FontVariation('wght', 500)
                                ],
                                fontSize: 42 * globals.scaleParam,
                              ),
                            ),
                            initialCountryCode: 'KZ',
                            onChanged: (phone) {
                              setState(() {
                                _number = phone.completeNumber;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(flex: 1, fit: FlexFit.tight, child: SizedBox()),
                  Flexible(
                    flex: 6,
                    fit: FlexFit.tight,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Flexible(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            transitionBuilder:
                                (Widget child, Animation<double> animation) {
                              return ScaleTransition(
                                  scale: animation, child: child);
                            },
                            child: isCodeSend
                                ? TextField(
                                    controller: _one_time_code,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontVariations: <FontVariation>[
                                        FontVariation('wght', 800)
                                      ],
                                      fontSize: 42 * globals.scaleParam,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: "Введите код из СМС",
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(10)),
                                      ),
                                      hintStyle: TextStyle(
                                        color: Colors.grey,
                                        fontVariations: <FontVariation>[
                                          FontVariation('wght', 500)
                                        ],
                                        fontSize: 42 * globals.scaleParam,
                                      ),
                                      labelStyle: TextStyle(
                                        color: Colors.grey,
                                        fontVariations: <FontVariation>[
                                          FontVariation('wght', 500)
                                        ],
                                        fontSize: 42 * globals.scaleParam,
                                      ),
                                      errorStyle: TextStyle(
                                        color: Colors.red,
                                        fontVariations: <FontVariation>[
                                          FontVariation('wght', 500)
                                        ],
                                        fontSize: 28 * globals.scaleParam,
                                      ),
                                      prefixStyle: TextStyle(
                                        color: Colors.white,
                                        fontVariations: <FontVariation>[
                                          FontVariation('wght', 500)
                                        ],
                                        fontSize: 42 * globals.scaleParam,
                                      ),
                                      helperStyle: TextStyle(
                                        color: Colors.white,
                                        fontVariations: <FontVariation>[
                                          FontVariation('wght', 500)
                                        ],
                                        fontSize: 38 * globals.scaleParam,
                                      ),
                                      floatingLabelStyle: TextStyle(
                                        color: Colors.white,
                                        fontVariations: <FontVariation>[
                                          FontVariation('wght', 500)
                                        ],
                                        fontSize: 42 * globals.scaleParam,
                                      ),
                                    ),
                                  )
                                : Container(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // TextFormField(
                  //   controller: _login,
                  //   decoration: InputDecoration(
                  //       labelStyle: TextStyle(color: gray1, fontSize: 16),
                  //       label: Row(
                  //         mainAxisSize: MainAxisSize.min,
                  //         children: [
                  //           Icon(
                  //             Icons.mail_outline_rounded,
                  //             size: 30,
                  //           ),
                  //           SizedBox(
                  //             width: 5,
                  //           ),
                  //           Text("Адрес эл.почты")
                  //         ],
                  //       ),
                  //       focusColor: Colors.white,
                  //       enabledBorder: OutlineInputBorder(
                  //           borderSide: BorderSide(
                  //               width: 0.5, color: Color(0xFFD8DADC)),
                  //           borderRadius:
                  //               BorderRadius.all(Radius.circular(10))),
                  //       focusedBorder: OutlineInputBorder(
                  //           borderSide: BorderSide(color: Colors.white))),
                  // ),
                  // SizedBox(
                  //   height: 10,
                  // ),
                  // TextFormField(
                  //   controller: _password,
                  //   obscureText: true,
                  //   decoration: InputDecoration(
                  //       labelStyle: TextStyle(color: gray1, fontSize: 16),
                  //       label: Row(
                  //         mainAxisSize: MainAxisSize.min,
                  //         children: [
                  //           Icon(
                  //             Icons.lock_outline,
                  //             size: 30,
                  //           ),
                  //           SizedBox(
                  //             width: 5,
                  //           ),
                  //           Text("Пароль")
                  //         ],
                  //       ),
                  //       focusColor: Colors.white,
                  //       enabledBorder: OutlineInputBorder(
                  //           borderSide: BorderSide(
                  //               width: 0.5, color: Color(0xFFD8DADC)),
                  //           borderRadius:
                  //               BorderRadius.all(Radius.circular(10))),
                  //       focusedBorder: OutlineInputBorder(
                  //           borderSide: BorderSide(color: Colors.white))),
                  // ),
                  // Spacer(),
                ],
              ),
            ),
          ),
          Flexible(
            flex: 2,
            fit: FlexFit.tight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                !isCodeSend
                    ? Flexible(
                        child: ElevatedButton(
                          onPressed: () async {
                            print(_phone_number.text.length);
                            if (_phone_number.text.length == 10) {
                              _getOneTimeCode();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Проверьте правильность номера",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontVariations: <FontVariation>[
                                        FontVariation('wght', 800)
                                      ],
                                      fontSize: 32 * globals.scaleParam,
                                    ),
                                  ),
                                ),
                              );
                            }
                            // bool _loginStatus =
                            //     await login(_login.text, _password.text);
                            // if (_loginStatus) {
                            //   Navigator.push(
                            //     context,
                            //     MaterialPageRoute(
                            //         builder: (context) => BottomMenu(
                            //               page: 0,
                            //             )),
                            //   );
                            // }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Flexible(
                                fit: FlexFit.tight,
                                child: Text(
                                  "Получить код подтверждения",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontVariations: <FontVariation>[
                                      FontVariation('wght', 800)
                                    ],
                                    fontSize: 42 * globals.scaleParam,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Flexible(
                        child: ElevatedButton(
                          onPressed: () async {
                            await verify(_number, _one_time_code.text).then(
                              (value) => {
                                if (value == true)
                                  {
                                    Navigator.pushAndRemoveUntil(context,
                                        MaterialPageRoute(
                                      builder: (context) {
                                        return const Main();
                                      },
                                    ), (route) => false)
                                  }
                              },
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Flexible(
                                fit: FlexFit.tight,
                                child: Text(
                                  "Отправить код",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontVariations: <FontVariation>[
                                      FontVariation('wght', 800)
                                    ],
                                    fontSize: 42 * globals.scaleParam,
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    )));
  }
}
