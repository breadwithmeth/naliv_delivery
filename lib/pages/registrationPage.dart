import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/loginPage.dart';
import 'package:naliv_delivery/pages/startPage.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final TextEditingController _login = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _name = TextEditingController();

  final Widget _resultWidget = Container();

  Future<void> _register() async {
    bool status = await register(_login.text, _password.text, _name.text);
    if (status) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LoginPage(
            login: _login.text,
            password: _password.text,
          ),
        ),
      );
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
        actions: [
          Padding(
            padding: const EdgeInsets.all(5),
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              },
              child: Text(
                "Войти",
              ),
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const Spacer(),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Регистрация",
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w400, fontSize: 24),
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
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                            labelStyle: TextStyle(color: Colors.grey, fontSize: 16),
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 30,
                                ),
                                SizedBox(
                                  width: 5,
                                ),
                                Text("Имя")
                              ],
                            ),
                            focusColor: Colors.black,
                            enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(width: 0.5, color: Color(0xFFD8DADC)), borderRadius: BorderRadius.all(Radius.circular(10))),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black))),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      TextFormField(
                        controller: _login,
                        decoration: const InputDecoration(
                            labelStyle: TextStyle(color: Colors.grey, fontSize: 16),
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
                                borderSide: BorderSide(width: 0.5, color: Color(0xFFD8DADC)), borderRadius: BorderRadius.all(Radius.circular(10))),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black))),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        decoration: const InputDecoration(
                            labelStyle: TextStyle(color: Colors.grey, fontSize: 16),
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
                                borderSide: BorderSide(width: 0.5, color: Color(0xFFD8DADC)), borderRadius: BorderRadius.all(Radius.circular(10))),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black))),
                      ),
                      const SizedBox(
                        height: 50,
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(18)),
                        onPressed: () {
                          _register();
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.max,
                          children: [Text("Регистрация")],
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const Spacer(
                flex: 3,
              )
            ],
          ),
          _resultWidget
        ],
      ),
    );
  }
}
