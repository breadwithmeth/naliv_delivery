import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Frosted-glass panel: a real refractive shader on Impeller, a blurred
/// translucent surface everywhere else.
///
/// The shader path is **Impeller-only**. `ImageFilter.shader` throws
/// [UnsupportedError] on any other backend, and that throw happens during
/// layout, so without the probe below it aborts the entire screen — including
/// under `flutter_test`, whose renderer is not Impeller. Web is skipped up
/// front for the same reason.
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

  /// Set the first time [ImageFilter.shader] reports the backend cannot do it,
  /// so the probe runs once instead of on every frame.
  bool _shaderUnsupported = false;

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

  BorderRadius get _radius =>
      BorderRadius.vertical(top: Radius.circular(widget.borderRadius));

  ImageFilter get _blurFilter =>
      ImageFilter.blur(sigmaX: widget.blurX, sigmaY: widget.blurY);

  /// The refractive filter for [constraints], or null when the renderer cannot
  /// build it. Records the finding so later frames skip the shader entirely.
  ImageFilter? _shaderFilter(
      FragmentProgram program, BoxConstraints constraints) {
    if (_shaderUnsupported) return null;
    try {
      final shader = program.fragmentShader();
      shader.setFloat(0, constraints.maxWidth);
      shader.setFloat(1, constraints.maxHeight);
      shader.setFloat(2, widget.blurX);
      return ImageFilter.shader(shader);
    } on UnsupportedError {
      _shaderUnsupported = true;
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final program = _program;

    // 1. ФОЛЛБЭК ДЛЯ WEB, SKIA И ТЕСТОВОГО РЕНДЕРА
    if (_shaderFailed || program == null || _shaderUnsupported) {
      return ClipRRect(
        borderRadius: _radius,
        child: BackdropFilter(
          filter: _blurFilter,
          child: _fallbackSurface(),
        ),
      );
    }

    // 2. FROSTED GLASS ДЛЯ IMPELLER (iOS / Android)
    return ClipRRect(
      borderRadius: _radius,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final filter = _shaderFilter(program, constraints);
          // The first unsupported frame must receive the complete fallback,
          // including blur. A later rebuild is not guaranteed.
          if (filter == null) {
            return BackdropFilter(
              filter: _blurFilter,
              child: _fallbackSurface(),
            );
          }

          return BackdropFilter(
            filter: filter,
            child: _shaderSurface(),
          );
        },
      ),
    );
  }

  Widget _fallbackSurface() {
    return Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: _radius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: widget.child,
    );
  }

  Widget _shaderSurface() {
    return Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        // Симметричный полупрозрачный подмалёвок для объёма
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.08), // Мягкий блик сверху
            Colors.black.withValues(alpha: 0.20), // Тёмный центр
            Colors.white.withValues(alpha: 0.05), // Легкий блик снизу
          ],
        ),
        borderRadius: _radius,
        // Тонкая аккуратная стеклянная фаска
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: widget.child,
    );
  }
}
