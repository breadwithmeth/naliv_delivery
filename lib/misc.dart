import 'dart:math';

import 'package:flutter/material.dart';
import '../globals.dart' as globals;

Widget _customIcon() {
  return TextButton(
      onPressed: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset("assets/icons/fire_outlined.png"),
        ],
      ));
}

double getDisc(double gyp2Lat, double gyp2Lon, double gyp1Lat, double gyp1Lon) {
  double p = 0.017453292519943295;
  double a = 0.5 -
      cos((gyp2Lat - gyp1Lat) * p) / 2 +
      cos(gyp1Lat * p) *
          cos(gyp2Lat * p) *
          (1 - cos((gyp2Lon - gyp1Lon) * p)) /
          2;

  // 12742 * Math.asin(Math.sqrt(a));
  double d = acos((sin(gyp1Lat) * sin(gyp2Lat)) +
          cos(gyp1Lat) * cos(gyp2Lat) * cos(gyp2Lon - gyp1Lon)) *
      6371;
  return 12742 * asin(sqrt(a));
}
