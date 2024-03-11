import 'dart:async';

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
        title: const Text("Настройки"),
      ),
      body: ListView(
        children: [
          ElevatedButton(
              onPressed: () {
                showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text("Удалить аккаунт?"),
                        actions: [
                          TextButton(
                              onPressed: () {
                                logout();
                                Timer timer =
                                    Timer(const Duration(seconds: 5), () {
                                  Navigator.pushReplacement(context,
                                      MaterialPageRoute(
                                    builder: (context) {
                                      return const Main();
                                    },
                                  ));
                                });
                                deleteAccount().then((value) {
                                  Navigator.pushReplacement(context,
                                      MaterialPageRoute(builder: ((context) {
                                    return const Main();
                                  })));
                                });
                                Navigator.pushReplacement(context,
                                    MaterialPageRoute(
                                  builder: (context) {
                                    return const Main();
                                  },
                                ));
                              },
                              child: const Text("Да")),
                          TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text("Нет"))
                        ],
                      );
                    });
              },
              child: const Text("Удалить аккаунт"))
        ],
      ),
    );
  }
}
