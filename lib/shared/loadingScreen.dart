import 'dart:async';

import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:google_fonts/google_fonts.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;
    double scaleParam =
        (screenSize.height / 1080) * (screenSize.width / 720) * 2;

    return Scaffold(
      body: Stack(
        children: [
          MarqueeText(
            text: "НАЛИВ",
            scaleParam: scaleParam,
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
                        fontSize: 60 * scaleParam,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onBackground,
                        shadows: [
                          Shadow(
                            color: Colors.black38,
                            offset: Offset(3 * scaleParam, 5 * scaleParam),
                            blurRadius: 20 * scaleParam,
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
  MarqueeText({super.key, required this.text, required this.scaleParam});

  final String text;
  final double scaleParam;

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
      begin: Offset(0.66 * widget.scaleParam, 0),
      end: Offset(-0.66 * widget.scaleParam, 0),
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    _animationTwo = Tween<Offset>(
      begin: Offset(-0.66 * widget.scaleParam, 0),
      end: Offset(0.66 * widget.scaleParam, 0),
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
              for (int i = 0; i < 14; i++)
                SlideTransition(
                  position: i.isOdd ? _animationOne : _animationTwo,
                  child: Text(
                    i.isOdd
                        ? "ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO"
                        : "ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO ALLCO",
                    style: TextStyle(
                      fontSize: 150 * widget.scaleParam,
                      fontWeight: FontWeight.w900,
                      color: Colors.black12,
                      height: 1.9 * widget.scaleParam,
                      wordSpacing: 8 * widget.scaleParam,
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
