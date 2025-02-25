import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// import 'package:mesh_gradient/mesh_gradient.dart';
import '../globals.dart' as globals;
import 'package:loading_animation_widget/loading_animation_widget.dart';

class PaintLogoPage extends StatefulWidget {
  const PaintLogoPage({super.key});

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
      backgroundColor: Color(0xFF000000),
      body: Container(
          alignment: Alignment.center,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: MediaQuery.of(context).size.width * 0.75,
                  padding: EdgeInsets.all(15),
                  child: FittedBox(
                    child: Text(
                      "Налив/Градусы24",
                      style: GoogleFonts.prostoOne(
                        fontSize: 50,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                LoadingAnimationWidget.discreteCircle(
                  color: Colors.white,
                  secondRingColor: Colors.grey.shade900,
                  thirdRingColor: Colors.grey,
                  size: MediaQuery.of(context).size.width / 10,
                ),
              ],
            ),
          )),
    );
  }
}
