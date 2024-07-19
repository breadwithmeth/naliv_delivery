import 'package:flutter/material.dart';

class PaintLogoPage extends StatefulWidget {
  const PaintLogoPage({super.key, required this.city});

  final String city;

  @override
  State<PaintLogoPage> createState() => _PaintLogoPageState();
}

class _PaintLogoPageState extends State<PaintLogoPage>
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
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            child: widget.city == "Павлодар"
                                ? Image.asset("./assets/naliv_logo_loading.png")
                                : Image.asset(
                                    "./assets/gradusy_logo_loading.png"),
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
