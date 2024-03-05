import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/main.dart';
import 'package:naliv_delivery/misc/api.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Настройки"),
      ),
      body: ListView(
        children: [
          ElevatedButton(
              onPressed: () {
                showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text("Удалить аккаунт?"),
                        actions: [
                          TextButton(
                              onPressed: () {
                                logout();
                                Timer timer =
                                    new Timer(new Duration(seconds: 5), () {
                                  Navigator.pushReplacement(context,
                                      MaterialPageRoute(
                                    builder: (context) {
                                      return Main();
                                    },
                                  ));
                                });
                                deleteAccount().then((value) {
                                  Navigator.pushReplacement(context,
                                      MaterialPageRoute(builder: ((context) {
                                    return Main();
                                  })));
                                });
                                Navigator.pushReplacement(context,
                                    MaterialPageRoute(
                                  builder: (context) {
                                    return Main();
                                  },
                                ));
                              },
                              child: Text("Да")),
                          TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: Text("Нет"))
                        ],
                      );
                    });
              },
              child: Text("Удалить аккаунт"))
        ],
      ),
    );
  }
}
