import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../shared/app_theme.dart';
import '../utils/responsive.dart';

// ignore: avoid_web_libraries_in_flutter
import 'app_loading_screen_web_stub.dart' if (dart.library.html) 'app_loading_screen_web_real.dart' as web_splash;

/// Styled loading screen – no logo, animated text + progress bar.
class AppLoadingScreen extends StatefulWidget {
  final String? message;
  const AppLoadingScreen({super.key, this.message});

  @override
  State<AppLoadingScreen> createState() => _AppLoadingScreenState();
}

class _AppLoadingScreenState extends State<AppLoadingScreen> with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _pulse;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _taglineFade;
  late final Animation<Offset> _taglineSlide;
  late final Animation<double> _barFade;
  late final Animation<double> _factFade;

  static const _taglines = [
    'Доставка 24/7',
    'Более 3 000 позиций',
    'Доставка за 35 минут',
    'Свежее разливное пиво',
    'Элитный алкоголь 21+',
  ];

  int _factIndex = 0;

  @override
  void initState() {
    super.initState();

    // Remove the native HTML splash on web
    if (kIsWeb) {
      web_splash.removeHtmlSplash();
    }

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // Title: fade + slide up
    _titleFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entrance, curve: const Interval(0.0, 0.35, curve: Curves.easeOut)),
    );
    _titleSlide = Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(parent: _entrance, curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic)),
    );

    // Tagline
    _taglineFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entrance, curve: const Interval(0.2, 0.55, curve: Curves.easeOut)),
    );
    _taglineSlide = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _entrance, curve: const Interval(0.2, 0.55, curve: Curves.easeOutCubic)),
    );

    // Progress bar
    _barFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entrance, curve: const Interval(0.45, 0.7, curve: Curves.easeOut)),
    );

    // Rotating fact text
    _factFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entrance, curve: const Interval(0.6, 0.85, curve: Curves.easeOut)),
    );

    _entrance.forward();

    // Cycle through facts
    Future.delayed(const Duration(milliseconds: 1600), _cycleFacts);
  }

  void _cycleFacts() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 2800));
      if (!mounted) return;
      setState(() => _factIndex = (_factIndex + 1) % _taglines.length);
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          const _AnimatedBackground(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 36.s),
                child: AnimatedBuilder(
                  animation: Listenable.merge([_entrance, _pulse]),
                  builder: (context, _) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated icon cluster
                        _GlowingIcon(pulse: _pulse, fade: _titleFade),

                        SizedBox(height: 36.s),

                        // Title
                        SlideTransition(
                          position: _titleSlide,
                          child: FadeTransition(
                            opacity: _titleFade,
                            child: Text(
                              'Налив / Градусы24',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 10.s),

                        // Tagline
                        SlideTransition(
                          position: _taglineSlide,
                          child: FadeTransition(
                            opacity: _taglineFade,
                            child: Text(
                              'Круглосуточный маркет-бар для тех,\nкто выбирает вкус и качество',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textMute,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 40.s),

                        // Progress bar
                        FadeTransition(
                          opacity: _barFade,
                          child: _AnimatedProgressBar(pulse: _pulse),
                        ),

                        SizedBox(height: 24.s),

                        // Rotating facts
                        FadeTransition(
                          opacity: _factFade,
                          child: SizedBox(
                            height: 20.s,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              child: Text(
                                _taglines[_factIndex],
                                key: ValueKey(_factIndex),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.orange,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  Animated background with floating particles
// ═══════════════════════════════════════════════════════════
class _AnimatedBackground extends StatefulWidget {
  const _AnimatedBackground();

  @override
  State<_AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<_AnimatedBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = Random(42);
    _particles = List.generate(14, (_) => _Particle.random(rng));
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return CustomPaint(
              painter: _ParticlePainter(_particles, _ctrl.value),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

class _Particle {
  final double x, y, radius, speed, phase;
  final Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.phase,
    required this.color,
  });

  factory _Particle.random(Random rng) {
    final isOrange = rng.nextDouble() < 0.3;
    return _Particle(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      radius: 1.5 + rng.nextDouble() * 2.5,
      speed: 0.3 + rng.nextDouble() * 0.7,
      phase: rng.nextDouble() * 2 * pi,
      color: isOrange
          ? AppColors.orange.withValues(alpha: 0.08 + rng.nextDouble() * 0.10)
          : Colors.white.withValues(alpha: 0.03 + rng.nextDouble() * 0.04),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  _ParticlePainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final progress = (t * p.speed + p.phase) % 1.0;
      final dx = p.x * size.width + sin(progress * 2 * pi) * 30;
      final dy = p.y * size.height + cos(progress * 2 * pi * 0.7) * 25;
      final paint = Paint()..color = p.color;
      canvas.drawCircle(Offset(dx, dy), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}

// ═══════════════════════════════════════════════════════════
//  Glowing icon (replaces logo)
// ═══════════════════════════════════════════════════════════
class _GlowingIcon extends StatelessWidget {
  final Animation<double> pulse;
  final Animation<double> fade;
  const _GlowingIcon({required this.pulse, required this.fade});

  @override
  Widget build(BuildContext context) {
    final glowIntensity = 0.10 + 0.08 * sin(pulse.value * 2 * pi);
    final scale = 1.0 + 0.03 * sin(pulse.value * 2 * pi);

    return FadeTransition(
      opacity: fade,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 80.s,
          height: 80.s,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.orange.withValues(alpha: glowIntensity),
                AppColors.orange.withValues(alpha: 0.02),
                Colors.transparent,
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
          child: Center(
            child: Container(
              width: 52.s,
              height: 52.s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.card,
                border: Border.all(
                  color: AppColors.orange.withValues(alpha: 0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.orange.withValues(alpha: 0.12),
                    blurRadius: 24.s,
                  ),
                ],
              ),
              child: Icon(
                Icons.local_bar_rounded,
                color: AppColors.orange,
                size: 26.s,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  Animated progress bar
// ═══════════════════════════════════════════════════════════
class _AnimatedProgressBar extends StatelessWidget {
  final Animation<double> pulse;
  const _AnimatedProgressBar({required this.pulse});

  @override
  Widget build(BuildContext context) {
    final shimmerPos = pulse.value;
    return Container(
      height: 3.s,
      width: 200.s,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2.s),
        color: Colors.white.withValues(alpha: 0.06),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2.s),
        child: CustomPaint(
          painter: _ProgressShimmerPainter(shimmerPos),
          size: Size(200.s, 3.s),
        ),
      ),
    );
  }
}

class _ProgressShimmerPainter extends CustomPainter {
  final double progress;
  _ProgressShimmerPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final shimmerWidth = size.width * 0.4;
    final center = progress * (size.width + shimmerWidth) - shimmerWidth / 2;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.clipRect(rect);

    final gradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Colors.transparent,
        AppColors.orange.withValues(alpha: 0.6),
        AppColors.orange,
        AppColors.orange.withValues(alpha: 0.6),
        Colors.transparent,
      ],
      stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
    );

    final shaderRect = Rect.fromCenter(
      center: Offset(center, size.height / 2),
      width: shimmerWidth,
      height: size.height,
    );

    final paint = Paint()..shader = gradient.createShader(shaderRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ProgressShimmerPainter old) => old.progress != progress;
}
