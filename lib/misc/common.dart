import 'package:flutter/material.dart';
import '../globals.dart' as globals;
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/productPage.dart';
import 'package:naliv_delivery/shared/itemCards.dart';

Future<Widget?> search(int page, String search) async {
  await getItemsMain(page, search).then((value) {
    List? items = value;
    if (items != null) {
      if (items.isEmpty) {
        return null;
      } else if (items.length < 30) {
        return null;
      } else if (items.length == 30) {
      } else {
        return null;
      }
    } else {
      return null;
    }
  });
}
