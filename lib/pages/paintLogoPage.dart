import 'package:flutter/material.dart';
import 'package:animated_path/animated_path.dart';

class paintLogoPage extends StatefulWidget {
  const paintLogoPage({super.key});

  @override
  State<paintLogoPage> createState() => _paintLogoPageState();
}

class _paintLogoPageState extends State<paintLogoPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController animationController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  bool isExample1 = false;

  Paint get paint => Paint()
    ..color = Colors.black
    ..strokeWidth = 6.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  late final Animation<double> firstAnimation = CurvedAnimation(
    parent: animationController,
    curve: Curves.easeOut,
  );

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        body: Container(
            padding: EdgeInsets.all(10),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(fit: FlexFit.tight, child: SizedBox()),
                Flexible(
                  flex: 3,
                  fit: FlexFit.tight,
                  child: AnimatedPath(
                    animation: animationController.view,
                    path: Path()
                      ..moveTo(0, 0)
                      ..quadraticBezierTo(-10, 50, 10, 50)
                      ..moveTo(50, 20)
                      ..cubicTo(20, 10, 20, 60, 50, 50)
                      ..moveTo(55, 15)
                      ..quadraticBezierTo(50, 50, 60, 50)
                      ..moveTo(80, 10)
                      ..quadraticBezierTo(60, 40, 90, 50)
                      ..quadraticBezierTo(110, 40, 100, 10)
                      ..moveTo(115, 0)
                      ..lineTo(115, 5)
                      ..moveTo(115, 15)
                      ..lineTo(115, 50)
                      ..moveTo(140, 10)
                      ..cubicTo(110, 20, 170, 40, 140, 50)
                      ..moveTo(160, 10)
                      ..lineTo(160, 50)
                      ..moveTo(160, 20)
                      ..quadraticBezierTo(180, 20, 180, 50),
                    paint: paint,
                    start: Tween(begin: 0.0, end: 0),
                    end: Tween(begin: 0.0, end: 1.0),
                    offset: Tween(begin: 0.0, end: 0),
                  ),
                ),
              ],
            )
            // Container(
            //   width: 200,
            //   height: 200,
            //   color: Colors.amber,
            //   child: CustomPaint(
            //     painter: LinePainter(progress: 1),
            //   ),
            // ),
            ));
  }
}

class LinePainter extends CustomPainter {
  final double progress;

  LinePainter({required this.progress});

  Paint _paint = Paint()
    ..color = Colors.black
    ..strokeWidth = 4.0
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    var path = Path();
    path.moveTo(0, 0);
    path..quadraticBezierTo(-10, 50, 10, 50);
    path.moveTo(50, 20);
    path.cubicTo(20, 10, 20, 60, 50, 50);

    canvas.drawPath(path, _paint);
  }

  @override
  bool shouldRepaint(LinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
