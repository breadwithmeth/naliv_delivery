import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const MarqueeText(text: "НАЛИВ"),
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
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onBackground,
                        shadows: const [
                          Shadow(
                            color: Colors.black38,
                            offset: Offset(3, 5),
                            blurRadius: 20,
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
  const MarqueeText({super.key, required this.text});

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
      duration: const Duration(seconds: 220),
      vsync: this,
    )..repeat(reverse: true);

    _animationOne = Tween<Offset>(
      begin: const Offset(0.35, 0),
      end: const Offset(-0.35, 0),
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    _animationTwo = Tween<Offset>(
      begin: const Offset(-0.35, 0),
      end: const Offset(0.35, 0),
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      // decoration: const BoxDecoration(
      //   color: Colors.gre,
      // ),
      child: OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: RotationTransition(
          turns: const AlwaysStoppedAnimation(-30 / 360),
          child: Column(
            children: [
              SlideTransition(
                position: _animationOne,
                child: const Text(
                  "НАЛИВ НАЛИВ НАЛИВ НАЛИВ НАЛИВ НАЛИВ НАЛИВ НАЛИВ ",
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: Colors.black12,
                    height: 1.2,
                    wordSpacing: 10,
                  ),
                ),
              ),
              SlideTransition(
                position: _animationTwo,
                child: const Text(
                  "ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ",
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: Colors.black12,
                    height: 1.2,
                    wordSpacing: 10,
                  ),
                ),
              ),
              SlideTransition(
                position: _animationOne,
                child: const Text(
                  "НАЛИВ НАЛИВ НАЛИВ НАЛИВ НАЛИВ НАЛИВ НАЛИВ НАЛИВ ",
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: Colors.black12,
                    height: 1.2,
                    wordSpacing: 10,
                  ),
                ),
              ),
              SlideTransition(
                position: _animationTwo,
                child: const Text(
                  "ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ",
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: Colors.black12,
                    height: 1.2,
                    wordSpacing: 10,
                  ),
                ),
              ),
              SlideTransition(
                position: _animationOne,
                child: const Text(
                  "НАЛИВ НАЛИВ НАЛИВ НАЛИВ НАЛИВ НАЛИВ НАЛИВ НАЛИВ ",
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: Colors.black12,
                    height: 1.2,
                    wordSpacing: 10,
                  ),
                ),
              ),
              SlideTransition(
                position: _animationTwo,
                child: const Text(
                  "ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ",
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: Colors.black12,
                    height: 1.2,
                    wordSpacing: 10,
                  ),
                ),
              ),
              SlideTransition(
                position: _animationOne,
                child: const Text(
                  "НАЛИВ НАЛИВ НАЛИВ НАЛИВ НАЛИВ НАЛИВ НАЛИВ НАЛИВ ",
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: Colors.black12,
                    height: 1.2,
                    wordSpacing: 10,
                  ),
                ),
              ),
              SlideTransition(
                position: _animationTwo,
                child: const Text(
                  "ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ",
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: Colors.black12,
                    height: 1.2,
                    wordSpacing: 10,
                  ),
                ),
              ),
              SlideTransition(
                position: _animationOne,
                child: const Text(
                  "НАЛИВ НАЛИВ НАЛИВ НАЛИВ НАЛИВ НАЛИВ НАЛИВ НАЛИВ ",
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: Colors.black12,
                    height: 1.2,
                    wordSpacing: 10,
                  ),
                ),
              ),
              SlideTransition(
                position: _animationTwo,
                child: const Text(
                  "ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ГРАДУСЫ ",
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: Colors.black12,
                    height: 1.2,
                    wordSpacing: 10,
                  ),
                ),
              ),
              SlideTransition(
                position: _animationOne,
                child: const Text(
                  "НАЛИВ НАЛИВ НАЛИВ НАЛИВ НАЛИВ НАЛИВ НАЛИВ НАЛИВ ",
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: Colors.black12,
                    height: 1.2,
                    wordSpacing: 10,
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
