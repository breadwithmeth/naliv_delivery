import 'dart:math';

import 'package:flutter/material.dart';

Widget _customIcon() {
  return TextButton(
      onPressed: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Image.asset("assets/icons/fire_outlined.png"), ],
      ));
}


  double getDisc(double gyp2_lat, double gyp2_lon, double gyp1_lat, double gyp1_lon) {
    double p = 0.017453292519943295;
    double a = 0.5 -
        cos((gyp2_lat - gyp1_lat) * p) / 2 +
        cos(gyp1_lat * p) *
            cos(gyp2_lat * p) *
            (1 - cos((gyp2_lon - gyp1_lon) * p)) /
            2;

    // 12742 * Math.asin(Math.sqrt(a));
    double d = acos((sin(gyp1_lat) * sin(gyp2_lat)) +
            cos(gyp1_lat) *
                cos(gyp2_lat) *
                cos(gyp2_lon - gyp1_lon)) *
        6371;
    return 12742 * asin(sqrt(a));
  }