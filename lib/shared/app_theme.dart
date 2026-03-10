import 'package:flutter/material.dart';

class AppColors {
  static const Color bgDeep = Color(0xFF0B0D14);
  static const Color bgTop = Color(0xFF0E1119);
  static const Color card = Color(0xFF111A2D);
  static const Color cardDark = Color(0xFF0F1726);
  static const Color blue = Color(0xFF1C273A);
  static const Color orange = Color(0xFFF38B2A);
  static const Color red = Color(0xFFC22624);
  static const Color text = Colors.white;
  static const Color textMute = Color(0xFF9FB0C8);
}

class AppDecorations {
  static BoxDecoration card({double radius = 18, Color? color, bool shadow = true}) {
    return BoxDecoration(
      color: color ?? AppColors.card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      boxShadow: shadow
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ]
          : null,
    );
  }

  static BoxDecoration pill({Color? color}) {
    return BoxDecoration(
      color: color ?? AppColors.blue,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
    );
  }
}

class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bgDeep],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.4, -0.6),
                    radius: 1.2,
                    colors: [Colors.white.withValues(alpha: 0.04), Colors.transparent],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.6, 0.8),
                    radius: 1.4,
                    colors: [Colors.white.withValues(alpha: 0.03), Colors.transparent],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
