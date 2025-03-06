import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';
import '../globals.dart' as globals;
import 'package:loading_animation_widget/loading_animation_widget.dart';

class PaintLogoPage extends StatefulWidget {
  const PaintLogoPage({super.key});

  @override
  State<PaintLogoPage> createState() => _PaintLogoPageState();
}

class _PaintLogoPageState extends State<PaintLogoPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _fadeAnimation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  Text(
                    "Налив",
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: CupertinoColors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(top: 4),
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: CupertinoColors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: CupertinoColors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      "Градусы24",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.white.withOpacity(0.8),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 40),
            
            CupertinoActivityIndicator(
              radius: 14,
              color: CupertinoColors.white,
            ),
          ],
        ),
      ),
    );
  }
}
