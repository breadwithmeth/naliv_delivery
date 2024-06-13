library my_prj.globals;

import "dart:math";

import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

final _random = new Random();

// List<Color> primaryColors = [Colors.lightBlueAccent, Colors.lightGreenAccent, Colors.deepOrangeAccent, Colors.indigoAccent, Colors.primaries];

Color currentColor = Colors.primaries[_random.nextInt(Colors.primaries.length)];

bool isLoggedIn = false;
double scaleParam = 1;
Color mainColor = Colors.deepOrangeAccent;

String formatCost(String costString) {
  int cost = int.parse(costString);
  return NumberFormat("###,###", "en_US").format(cost);
}
