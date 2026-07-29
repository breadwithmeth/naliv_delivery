import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class RefractiveGlassContainer extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blurX;
  final double blurY;

  const RefractiveGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 28.0,
    this.padding,
    this.blurX = 8.0, // Сбалансированный блюр для матового эффекта
    this.blurY = 8.0,
  });

  @override
  State<RefractiveGlassContainer> createState() =>
      _RefractiveGlassContainerState();
}

class _RefractiveGlassContainerState extends State<RefractiveGlassContainer> {
  FragmentProgram? _program;
  bool _shaderFailed = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _shaderFailed = true;
    } else {
      _loadShader();
    }
  }

  Future<void> _loadShader() async {
    try {
      final program = await FragmentProgram.fromAsset(
          'assets/shaders/glass_refraction.frag');
      if (mounted) {
        setState(() {
          _program = program;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _shaderFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. ФОЛЛБЭК ДЛЯ WEB И SKIA
    if (_shaderFailed || _program == null) {
      return ClipRRect(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(widget.borderRadius)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: widget.blurX, sigmaY: widget.blurY),
          child: Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(widget.borderRadius)),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 18,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: widget.child,
          ),
        ),
      );
    }

    // 2. FROSTED GLASS ДЛЯ IMPELLER (iOS / Android)
    // Внутри виджета RefractiveGlassContainer (секция для Impeller):

    return ClipRRect(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(widget.borderRadius)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shader = _program!.fragmentShader();

          shader.setFloat(0, constraints.maxWidth);
          shader.setFloat(1, constraints.maxHeight);
          shader.setFloat(2, widget.blurX);

          return BackdropFilter(
            filter: ImageFilter.shader(shader),
            child: Container(
              padding: widget.padding,
              decoration: BoxDecoration(
                // Симметричный полупрозрачный подмалёвок для объёма
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.08), // Мягкий блик сверху
                    Colors.black.withOpacity(0.20), // Тёмный центр
                    Colors.white.withOpacity(0.05), // Легкий блик снизу
                  ],
                ),
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(widget.borderRadius)),
                // Тонкая аккуратная стеклянная фаска
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}
