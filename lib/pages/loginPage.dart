import 'package:flutter/material.dart';
import 'package:naliv_delivery/bottomMenu.dart';
import 'package:naliv_delivery/main.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/misc/colors.dart';
import 'package:naliv_delivery/pages/registrationPage.dart';
import 'package:naliv_delivery/pages/startPage.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.login = "", this.password = ""});
  final String login;
  final String password;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController _login = TextEditingController();
  TextEditingController _password = TextEditingController();
  TextEditingController _phone_number = TextEditingController();
  TextEditingController _one_time_code = TextEditingController();
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
    // TODO: implement initState
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
      appBar: AppBar(
        leading: IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StartPage()),
              );
            },
            icon: Icon(Icons.arrow_back)),
        // actions: [
        //   Padding(
        //     padding: EdgeInsets.all(5),
        //     child: TextButton(
        //         onPressed: () {
        //           Navigator.push(
        //             context,
        //             MaterialPageRoute(
        //                 builder: (context) => const RegistrationPage()),
        //           );
        //         },
        //         child: Text(
        //           "Регистрация",
        //           style: TextStyle(
        //               color: Colors.black,
        //               fontWeight: FontWeight.w600,
        //               fontSize: 16),
        //         )),
        //   )
        // ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Вход",
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w400,
                    fontSize: 24),
              )
            ],
          ),
          Spacer(),
          Container(
            margin: EdgeInsets.all(20),
            child: Form(
                autovalidateMode: AutovalidateMode.always,
                child: Column(
                  children: [
                    IntlPhoneField(
                      controller: _phone_number,
                      enabled: !isCodeSend,
                      dropdownIconPosition: IconPosition.trailing,
                      showCountryFlag: true,
                      decoration: InputDecoration(
                        labelText: 'Номер телефона',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(),
                        ),
                      ),
                      initialCountryCode: 'KZ',
                      onChanged: (phone) {
                        setState(() {
                          _number = phone.completeNumber;
                        });
                      },
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    AnimatedSwitcher(
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
                                decoration: InputDecoration(
                                    labelText: "Введите одноразовый код из СМС",
                                    border: OutlineInputBorder()),
                              )
                            : Container()),
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
                    //       focusColor: Colors.black,
                    //       enabledBorder: OutlineInputBorder(
                    //           borderSide: BorderSide(
                    //               width: 0.5, color: Color(0xFFD8DADC)),
                    //           borderRadius:
                    //               BorderRadius.all(Radius.circular(10))),
                    //       focusedBorder: OutlineInputBorder(
                    //           borderSide: BorderSide(color: Colors.black))),
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
                    //       focusColor: Colors.black,
                    //       enabledBorder: OutlineInputBorder(
                    //           borderSide: BorderSide(
                    //               width: 0.5, color: Color(0xFFD8DADC)),
                    //           borderRadius:
                    //               BorderRadius.all(Radius.circular(10))),
                    //       focusedBorder: OutlineInputBorder(
                    //           borderSide: BorderSide(color: Colors.black))),
                    // ),
                    SizedBox(
                      height: 20,
                    ),
                    // Spacer(),
                    !isCodeSend
                        ? ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.all(18)),
                            onPressed: () async {
                              print(_phone_number.text.length);
                              if (_phone_number.text.length == 10) {
                                _getOneTimeCode();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            "Проверьте правильность номера")));
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
                              children: [Text("Получить код подтверждения")],
                            ))
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.all(18)),
                            onPressed: () async {
                              await verify(_number, _one_time_code.text)
                                  .then((value) => {
                                        if (value == true)
                                          {
                                            Navigator.pushReplacement(context,
                                                MaterialPageRoute(
                                              builder: (context) {
                                                return Main();
                                              },
                                            ))
                                          }
                                      });
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.max,
                              children: [Text("Отправить код")],
                            ))
                  ],
                )),
          ),
          Spacer(
            flex: 3,
          )
        ],
      ),
    );
  }
}
