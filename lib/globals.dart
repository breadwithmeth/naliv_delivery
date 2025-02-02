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

bool addressSelectPopUpDone = false;

// Navigator.push(
//   context,
//   CupertinoPageRoute(builder: (context) => const StartPage()),
// );

Route getPlatformSpecialRoute(Widget route) {
  if (Platform.isIOS) {
    return CupertinoPageRoute(
      builder: (context) => route,
    );
  } else {
    return CupertinoPageRoute(
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
//   return CupertinoPageRoute(
//     builder: (context) => route,
//   );
// }
//   }
// }

String formatCost(String costString) {
  double cost = double.parse(costString);
  return NumberFormat("###,###", "en_US").format(cost);
}

String currentToken = "";

setToken(String t) {
  currentToken = t;
}

String formatQuantity(double quantity, String unit) {
  if (quantity <= 0) {
    return "0";
  }
  String formattedQuantity = quantity.toString();
  // Проверяем, целое ли число
  if (unit == "л" || unit == "л.") {
    formattedQuantity = (quantity % 1 == 0)
        ? quantity.toStringAsFixed(0) // Целое число без знаков после запятой
        : quantity
            .toStringAsFixed(1); // Дробное число с 3 знаками после запятой
  } else {
    formattedQuantity = (quantity % 1 == 0)
        ? quantity.toStringAsFixed(0) // Целое число без знаков после запятой
        : quantity.toStringAsFixed(3);
  }
  return "$formattedQuantity $unit";
}

String formatPrice(int price) {
  if (price < 0) {
    return "!";
  }

  // Форматируем целую часть (добавляем пробелы)
  String formattedPrice = price.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (Match match) => "${match[1]} ",
      );

  // Собираем итоговую строку
  return "$formattedPrice ₸";
}
