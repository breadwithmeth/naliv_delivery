library my_prj.globals;

import "dart:math";

import "dart:io" show Platform;

import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

final _random = new Random();

// List<Color> primaryColors = [Colors.lightBlueAccent, Colors.lightGreenAccent, Colors.deepOrangeAccent, Colors.indigoAccent, Colors.primaries];

Color currentColor = Colors.primaries[_random.nextInt(Colors.primaries.length)];

bool isLoggedIn = false;
double scaleParam = 1;
Color mainColor = Colors.deepOrangeAccent;


bool addressSelectPopUpDone  = false;

// Navigator.push(
//   context,
//   MaterialPageRoute(builder: (context) => const StartPage()),
// );

Route getPlatformSpecialRoute(Widget route) {
  if (Platform.isIOS) {
    return CupertinoPageRoute(
      builder: (context) => route,
    );
  } else {
    return MaterialPageRoute(
      builder: (context) => route,
    );
  }
}

// class UnifiedPageRoute {
//   final Widget route;

//   UnifiedPageRoute(this.route);

// Route call() {
// if (Platform.isIOS) {
//   return CupertinoPageRoute(
//     builder: (context) => route,
//   );
// } else {
//   return MaterialPageRoute(
//     builder: (context) => route,
//   );
// }
//   }
// }

String formatCost(String costString) {
  int cost = int.parse(costString);
  return NumberFormat("###,###", "en_US").format(cost);
}



