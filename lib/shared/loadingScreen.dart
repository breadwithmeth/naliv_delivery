import 'dart:async';

import 'package:flutter/material.dart';
import '../globals.dart' as globals;
import 'dart:math' as math;

import 'package:google_fonts/google_fonts.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          MarqueeText(
            text: "НАЛИВ",
          ),
          Center(
            child: Container(
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      "Загрузка..",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 60 * globals.scaleParam,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onBackground,
                        shadows: [
                          Shadow(
                            color: Colors.black38,
                            offset: Offset(
                                3 * globals.scaleParam, 5 * globals.scaleParam),
                            blurRadius: 20 * globals.scaleParam,
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MarqueeText extends StatefulWidget {
  MarqueeText({
    super.key,
    required this.text,
  });

  final String text;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late final Animation<Offset> _animationOne;
  late final Animation<Offset> _animationTwo;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: 220),
      vsync: this,
    )..repeat(reverse: true);

    _animationOne = Tween<Offset>(
      begin: Offset(0.66 * globals.scaleParam, 0),
      end: Offset(-0.66 * globals.scaleParam, 0),
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    _animationTwo = Tween<Offset>(
      begin: Offset(-0.60 * globals.scaleParam, 0),
      end: Offset(0.60 * globals.scaleParam, 0),
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _controller.dispose();
    _animationOne.removeListener(() {});
    _animationTwo.removeListener(() {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      // decoration:  BoxDecoration(
      //   color: Colors.gre,
      // ),
      child: OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: RotationTransition(
          turns: AlwaysStoppedAnimation(-30 / 360),
          child: Column(
            children: [
              for (int i = 0; i < 24; i++)
                SlideTransition(
                  position: i.isOdd ? _animationOne : _animationTwo,
                  child: Text(
                    i.isOdd
                        ? "ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO"
                        : "ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO",
                    // textScaler: MediaQuery.textScalerOf(context),
                    style: TextStyle(
                      fontSize: 55,
                      // fontSize: 150 * globals.scaleParam,
                      fontWeight: FontWeight.w900,
                      color: Colors.black12,
                      height: MediaQuery.sizeOf(context).longestSide *
                          0.001 /
                          globals.scaleParam /
                          2.5,
                      wordSpacing: 8 * globals.scaleParam,
                      fontFamily: "montserrat",
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
