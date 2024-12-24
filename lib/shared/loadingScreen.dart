import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class LoadingScrenn extends StatefulWidget {
  const LoadingScrenn({super.key});

  @override
  State<LoadingScrenn> createState() => _LoadingScrennState();
}

class _LoadingScrennState extends State<LoadingScrenn> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black38,
      child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Center(
            child: Container(
                alignment: Alignment.center,
                child: Center(
                    child: Container(
                    child: LoadingAnimationWidget.discreteCircle(
                    color: Colors.white,
                    secondRingColor: Colors.grey.shade900,
                    thirdRingColor: Colors.grey,
                    size: MediaQuery.of(context).size.width / 10,
                  ),
                ))),
          )),
    );
  }
}
