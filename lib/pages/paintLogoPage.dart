import 'dart:math';

import 'package:flutter/material.dart';
import 'package:animated_path/animated_path.dart';

class paintLogoPage extends StatefulWidget {
  const paintLogoPage({super.key});

  @override
  State<paintLogoPage> createState() => _paintLogoPageState();
}

class _paintLogoPageState extends State<paintLogoPage>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          width: MediaQuery.sizeOf(context).shortestSide * 0.5,
          height: MediaQuery.sizeOf(context).shortestSide * 0.5,
          // color: Colors.green.shade100,
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: SizedBox(
                            width: constraints.maxWidth * 0.5,
                            height: constraints.maxHeight * 0.5,
                            child: Image.asset("./assets/naliv_logo.png"),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Container(
                            width: constraints.maxWidth * 0.8,
                            height: constraints.maxHeight * 0.05,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.all(
                                Radius.circular(100),
                              ),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white,
                                  Colors.grey.shade400,
                                  Colors.white,
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                stops: [0.02, 0.5, 0.98],
                              ),
                            ),
                            child: LinearProgressIndicator(
                              backgroundColor: Colors.transparent,
                              borderRadius: BorderRadius.all(
                                Radius.circular(100),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
