import 'package:flutter/material.dart';
import 'package:naliv_delivery/bottomMenu.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/misc/colors.dart';
import 'package:naliv_delivery/pages/registrationPage.dart';
import 'package:naliv_delivery/pages/startPage.dart';

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
                MaterialPageRoute(
                    builder: (context) => const StartPage()),
              );
            },
            icon: Icon(Icons.arrow_back)),
        actions: [
          Padding(
            padding: EdgeInsets.all(5),
            child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const RegistrationPage()),
                  );
                },
                child: Text(
                  "Регистрация",
                  style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 16),
                )),
          )
        ],
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
                    TextFormField(
                      controller: _login,
                      decoration: InputDecoration(
                          labelStyle: TextStyle(color: gray1, fontSize: 16),
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.mail_outline_rounded,
                                size: 30,
                              ),
                              SizedBox(
                                width: 5,
                              ),
                              Text("Адрес эл.почты")
                            ],
                          ),
                          focusColor: Colors.black,
                          enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  width: 0.5, color: Color(0xFFD8DADC)),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10))),
                          focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.black))),
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: InputDecoration(
                          labelStyle: TextStyle(color: gray1, fontSize: 16),
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_outline,
                                size: 30,
                              ),
                              SizedBox(
                                width: 5,
                              ),
                              Text("Пароль")
                            ],
                          ),
                          focusColor: Colors.black,
                          enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  width: 0.5, color: Color(0xFFD8DADC)),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10))),
                          focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.black))),
                    ),
                    SizedBox(
                      height: 50,
                    ),
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.all(18)),
                        onPressed: () async {
                          bool _loginStatus =
                              await login(_login.text, _password.text);
                          if (_loginStatus) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>  BottomMenu(page: 0,)),
                            );
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.max,
                          children: [Text("Войти")],
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
