import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:chatwoot_sdk/chatwoot_sdk.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key, required this.user});
  final Map user;
  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  whatsapp(String text) async {
    var contact = "+77710131111";
    var androidUrl = "whatsapp://send?phone=$contact&text=$text!";
    var iosUrl = "https://wa.me/$contact?text=${Uri.parse(text)}";

    try {
      if (Platform.isIOS) {
        await launchUrl(Uri.parse(iosUrl));
      } else {
        await launchUrl(Uri.parse(androidUrl));
      }
    } on Exception {
      //  EasyLoading.showError('WhatsApp is not installed.');
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        body: Center(
          child: ListView(
            children: [
              ListTile(
                title: Text("Проблемы с заказом"),
                onTap: () async {
                  whatsapp("проблемы с заказом");
                },
              ),
              ListTile(
                title: Text("Вакансии"),
                onTap: () async {
                  whatsapp("вакансии");
                },
              ),
            ],
          ),
        ));
  }
}
