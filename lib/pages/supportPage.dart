import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:chatwoot_sdk/chatwoot_sdk.dart';
import 'package:flutter/services.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key, required this.user});
  final Map user;
  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Naliv.Support"),
      ),
      body: ChatwootWidget(
        websiteToken: "gfHGUpGQdGbmCscyuZB8dZiE",
        baseUrl: "https://chatwoot.naliv.kz",
        user: ChatwootUser(
          identifier: widget.user["user_id"],
          name: widget.user["name"],
        ),
        locale: "ru",
        closeWidget: () {
          if (Platform.isAndroid) {
            SystemNavigator.pop();
          } else if (Platform.isIOS) {
            exit(0);
          }
        },
        //attachment only works on android for now
        onLoadStarted: () {
          print("loading widget");
        },
        onLoadProgress: (int progress) {
          print("loading... ${progress}");
        },
        onLoadCompleted: () {
          print("widget loaded");
        },
      ),
    );
  }
}
