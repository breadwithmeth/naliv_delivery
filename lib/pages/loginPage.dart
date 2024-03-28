import 'package:flutter/material.dart';
import 'package:naliv_delivery/main.dart';
import 'package:naliv_delivery/misc/api.dart';
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
            icon: const Icon(Icons.arrow_back)),
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
          const Spacer(),
          const Row(
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
          const Spacer(),
          Container(
            margin: const EdgeInsets.all(20),
            child: Form(
                autovalidateMode: AutovalidateMode.always,
                child: Column(
                  children: [
                    IntlPhoneField(
                      controller: _phone_number,
                      enabled: !isCodeSend,
                      dropdownIconPosition: IconPosition.trailing,
                      showCountryFlag: true,
                      decoration: const InputDecoration(
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
                    const SizedBox(
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
                                decoration: const InputDecoration(
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
                    const SizedBox(
                      height: 20,
                    ),
                    // Spacer(),
                    !isCodeSend
                        ? ElevatedButton(
                            onPressed: () async {
                              print(_phone_number.text.length);
                              if (_phone_number.text.length == 10) {
                                _getOneTimeCode();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
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
                              children: [
                                Text(
                                  "Получить код подтверждения",
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ))
                        : ElevatedButton(
                            onPressed: () async {
                              await verify(_number, _one_time_code.text)
                                  .then((value) => {
                                        if (value == true)
                                          {
                                            Navigator.pushReplacement(context,
                                                MaterialPageRoute(
                                              builder: (context) {
                                                return const Main();
                                              },
                                            ))
                                          }
                                      });
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.max,
                              children: [Text("Отправить код")],
                            ))
                  ],
                )),
          ),
          const Spacer(
            flex: 3,
          )
        ],
      ),
    );
  }
}
