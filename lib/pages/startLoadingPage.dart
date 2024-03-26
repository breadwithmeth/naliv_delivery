import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class StartLoadingPage extends StatefulWidget {
  const StartLoadingPage({super.key});

  @override
  State<StartLoadingPage> createState() => _StartLoadingPageState();
}

class _StartLoadingPageState extends State<StartLoadingPage> {
  late Timer _timer;
  int _tick = 0;
  Random random = Random();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    setState(() {
      _timer = Timer.periodic(Duration(milliseconds: 300), (timer) {
        setState(() {
          _tick = timer.tick * random.nextInt(10) + 10;
        });
      });
    });
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _timer.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(
      children: [
        Center(
          child: AnimatedContainer(
            transform: Matrix4.rotationZ(_tick.toDouble() * 3.5),
            width: _tick % 100,
            height: _tick % 100,
            curve: Curves.decelerate,
            decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.all(Radius.circular(1999))),
            duration: Duration(seconds: 10),
          ),
        ),
        Center(
          child: AnimatedContainer(
            transform: Matrix4.rotationZ(_tick.toDouble() * 1.2),
            width: _tick % 200,
            height: _tick % 200,
            curve: Curves.decelerate,
            decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.all(Radius.circular(1999))),
            duration: Duration(seconds: 2),
          ),
        ),
        Center(
          child: AnimatedContainer(
            transform: Matrix4.rotationZ(_tick.toDouble() * 3.1),
            width: _tick % 500,
            height: _tick % 500,
            curve: Curves.decelerate,
            decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.all(Radius.circular(1999))),
            duration: Duration(seconds: 10),
          ),
        ),
        Center(
          child: AnimatedContainer(
            transform: Matrix4.rotationZ(_tick.toDouble() + 0.5),
            width: _tick % 300,
            height: _tick % 300,
            curve: Curves.decelerate,
            decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.all(Radius.circular(1999))),
            duration: Duration(seconds: 10),
          ),
        ),
      ],
    ));
  }
}
