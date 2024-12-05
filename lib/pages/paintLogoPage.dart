import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// import 'package:mesh_gradient/mesh_gradient.dart';
import '../globals.dart' as globals;
import 'package:loading_animation_widget/loading_animation_widget.dart';

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
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
          color: Colors.white,
          alignment: Alignment.center,
          child: Center(
            child: LoadingAnimationWidget.staggeredDotsWave(
              color: Colors.black,
              size: MediaQuery.of(context).size.width / 3,
            ),
          )

          // AnimatedMeshGradient(
          //   colors: [
          //     Colors.orangeAccent,
          //     Colors.orange,
          //     Colors.amberAccent,
          //     Colors.yellowAccent
          //   ],
          //   options: AnimatedMeshGradientOptions(frequency: 10, amplitude: 1),
          //   child: ShaderMask(
          //     blendMode: BlendMode.srcOut,
          //     child: Text(
          //       "НАЛИВ\nГРАДУСЫ24",
          //       style: GoogleFonts.interTight(
          //         fontSize: 50,
          //         fontWeight: FontWeight.w900,
          //         color: Colors.black,
          //       ),
          //     ),
          //     shaderCallback: (bounds) => LinearGradient(colors: [
          //       Colors.white,
          //     ], stops: [
          //       0.0
          //     ]).createShader(bounds),
          //   ),
          // ),
          ),
    );
  }
}
