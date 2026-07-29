import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pages/cart_page.dart';
import '../utils/cart_provider.dart';
import '../utils/responsive.dart';

/// Кастомный Painter, который динамически "сшивает" шестеренку и плашку
/// в единый монолитный 3D-объект.
class CombinedClayPainter extends CustomPainter {
  final double buttonSize;    // Размер шестеренки
  final double exposedWidth;  // На сколько выпирает плашка
  final Color baseColor;

  CombinedClayPainter({
    required this.buttonSize,
    required this.exposedWidth,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Формируем путь шестеренки
    final scale = buttonSize / 163.0;
    final svgPath = _getCartPath();
    final matrix = Matrix4.identity()..scale(scale, scale);
    final buttonPath = svgPath.transform(matrix.storage);

    Path finalPath = buttonPath;

    // 2. Если плашка должна быть видна, "привариваем" ее прямоугольник к шестеренке
    if (exposedWidth > 0.5) {
      final pillTop = buttonSize * 0.25;  // Отступ сверху
      final pillHeight = buttonSize * 0.5; // Высота плашки (половина кнопки)
      
      // Плашка начинается из центра шестеренки, чтобы гарантировать идеальное слияние
      final pillRect = RRect.fromLTRBR(
        buttonSize * 0.5, 
        pillTop, 
        buttonSize + exposedWidth, 
        pillTop + pillHeight, 
        Radius.circular(pillHeight / 2),
      );
      
      final pillPath = Path()..addRRect(pillRect);
      
      // ВАЖНО: Сливаем фигуры в единый контур!
      finalPath = Path.combine(PathOperation.union, buttonPath, pillPath);
    }

    final bounds = finalPath.getBounds();

    // 3. ОБЩАЯ Внешняя падающая тень
    final dropShadowPaint = Paint()
      ..color = const Color(0x40000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    canvas.save();
    canvas.translate(0, 6.0);
    canvas.drawPath(finalPath, dropShadowPaint);
    canvas.restore();

    // 4. ОБЩИЙ Градиентный объем (свет покрывает весь объект монолитно)
    final baseGradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFFF9E43), // Светлая верхушка
          baseColor,               // База
          const Color(0xFFD34B00), // Тень внизу
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(bounds);

    canvas.drawPath(finalPath, baseGradientPaint);

    // 5. ОБЩАЯ Внутренняя тень и блики по краям
    canvas.save();
    canvas.clipPath(finalPath); // Рисуем строго внутри монолита

    // Внутреннее затемнение (фаска снизу-справа)
    final innerShadowPaint = Paint()
      ..color = const Color(0x99832200)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.0;

    canvas.save();
    canvas.translate(-3.0, -4.0);
    canvas.drawPath(finalPath, innerShadowPaint);
    canvas.restore();

    // Внутренний светлый блик (фаска сверху-слева)
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    canvas.save();
    canvas.translate(2.0, 2.0);
    canvas.drawPath(finalPath, highlightPaint);
    canvas.restore();

    canvas.restore(); // Снимаем clipPath
  }

  @override
  bool shouldRepaint(covariant CombinedClayPainter oldDelegate) {
    return oldDelegate.exposedWidth != exposedWidth || 
           oldDelegate.buttonSize != buttonSize;
  }

  Path _getCartPath() {
    final path = Path();
    path.moveTo(85.7139, 5.12339);
    path.cubicTo(88.9903, 2.91148, 92.3338, -0.472281, 95.2988, 0.0550279);
    path.cubicTo(98.3489, 0.595607, 100.38, 4.94574, 102.687, 8.15268);
    path.cubicTo(105.556, 9.0197, 108.355, 10.0569, 111.067, 11.2503);
    path.cubicTo(114.882, 10.3049, 119.177, 8.29716, 121.808, 9.84311);
    path.cubicTo(124.464, 11.4022, 124.899, 16.1836, 125.985, 20.0042);
    path.cubicTo(128.376, 21.8114, 130.659, 23.7572, 132.821, 25.8333);
    path.cubicTo(136.718, 26.2616, 141.437, 25.867, 143.403, 28.2435);
    path.cubicTo(145.367, 30.6121, 144.165, 35.2579, 143.91, 39.2298);
    path.cubicTo(145.545, 41.742, 147.04, 44.3567, 148.378, 47.0648);
    path.cubicTo(151.896, 48.8119, 156.471, 50.079, 157.523, 53.0169);
    path.cubicTo(158.558, 55.9027, 155.858, 59.8359, 154.277, 63.4867);
    path.cubicTo(154.959, 66.3931, 155.477, 69.3673, 155.819, 72.3939);
    path.cubicTo(158.53, 75.2457, 162.398, 78.0377, 162.398, 81.1976);
    path.cubicTo(162.398, 84.3575, 158.53, 87.1489, 155.819, 90.0033);
    path.cubicTo(155.477, 93.0326, 155.959, 96.0052, 154.277, 98.9144);
    path.cubicTo(155.86, 102.565, 158.558, 106.498, 157.523, 109.384);
    path.cubicTo(156.468, 112.319, 151.896, 113.588, 148.378, 115.335);
    path.cubicTo(147.039, 118.043, 145.547, 120.658, 143.91, 123.17);
    path.cubicTo(144.165, 127.142, 145.364, 131.785, 143.403, 134.157);
    path.cubicTo(141.437, 136.533, 136.718, 136.139, 132.821, 136.568);
    path.cubicTo(130.659, 138.641, 128.379, 140.589, 125.985, 142.394);
    path.cubicTo(124.897, 146.212, 124.464, 150.996, 121.808, 152.555);
    path.cubicTo(119.177, 154.098, 114.882, 152.091, 111.067, 151.148);
    path.cubicTo(108.352, 152.341, 105.556, 153.377, 102.687, 154.244);
    path.cubicTo(100.38, 157.451, 98.3489, 161.803, 95.2988, 162.343);
    path.cubicTo(92.3338, 162.87, 88.9903, 159.488, 85.7139, 157.274);
    path.cubicTo(84.2184, 157.363, 82.7153, 157.415, 81.1992, 157.415);
    path.cubicTo(79.6832, 157.415, 78.1774, 157.363, 76.6846, 157.274);
    path.cubicTo(73.4081, 159.486, 70.0647, 162.87, 67.0996, 162.343);
    path.cubicTo(64.0495, 161.803, 62.0181, 157.451, 59.7119, 154.244);
    path.cubicTo(56.8421, 153.377, 54.0439, 152.341, 51.3311, 151.148);
    path.cubicTo(47.5167, 152.093, 43.2212, 154.101, 40.5908, 152.555);
    path.cubicTo(37.9346, 150.996, 37.4992, 146.215, 36.4131, 142.394);
    path.cubicTo(34.022, 140.587, 31.7392, 138.641, 29.5771, 136.565);
    path.cubicTo(25.6803, 136.137, 20.9616, 136.531, 18.9951, 134.155);
    path.cubicTo(17.0312, 131.786, 18.2335, 127.139, 18.4883, 123.167);
    path.cubicTo(16.854, 120.655, 15.3588, 118.041, 14.0205, 115.333);
    path.cubicTo(10.502, 113.586, 5.92773, 112.319, 4.875, 109.381);
    path.cubicTo(3.84031, 106.495, 6.54071, 102.562, 8.12109, 98.9115);
    path.cubicTo(7.43901, 96.0049, 6.92143, 93.03, 6.5791, 90.0033);
    path.cubicTo(3.86887, 87.1516, 0.000266942, 84.3603, 0, 81.2005);
    path.cubicTo(0, 78.0406, 3.86877, 75.2483, 6.5791, 72.3939);
    path.cubicTo(6.92143, 69.3646, 7.43903, 66.3929, 8.12109, 63.4837);
    path.cubicTo(6.53815, 59.8328, 3.84033, 55.8997, 4.875, 53.014);
    path.cubicTo(5.9303, 50.0787, 10.502, 48.809, 14.0205, 47.0619);
    path.cubicTo(15.3588, 44.354, 16.8514, 41.74, 18.4883, 39.2279);
    path.cubicTo(18.2335, 35.2557, 17.0338, 30.6118, 18.9951, 28.2406);
    path.cubicTo(20.9616, 25.8642, 25.6803, 26.2587, 29.5771, 25.8304);
    path.cubicTo(31.7392, 23.757, 34.0194, 21.8087, 36.4131, 20.0042);
    path.cubicTo(37.5019, 16.1862, 37.9345, 11.4022, 40.5908, 9.84311);
    path.cubicTo(43.2213, 8.29977, 47.5166, 10.3075, 51.3311, 11.2503);
    path.cubicTo(54.0465, 10.0569, 56.8421, 9.0197, 59.7119, 8.15268);
    path.cubicTo(62.0181, 4.94574, 64.0496, 0.595607, 67.0996, 0.0550279);
    path.cubicTo(70.0647, -0.472288, 73.4081, 2.90886, 76.6846, 5.12339);
    path.cubicTo(78.1774, 5.0346, 79.6832, 4.98276, 81.1992, 4.98276);
    path.cubicTo(82.7152, 4.98276, 84.221, 5.0346, 85.7139, 5.12339);
    path.close();
    return path;
  }
}

class CartFloatingButton extends StatelessWidget {
  const CartFloatingButton({super.key});

  static const Color _cartOrange = Color(0xFFF16800);

  void _openCart(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.9,
        child: const CartPage(),
      ),
    );
  }

  String _money(double v) {
    return v == v.roundToDouble()
        ? '${v.toInt()} ₸'
        : '${v.toStringAsFixed(0)} ₸';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        final screenWidth = MediaQuery.of(context).size.width;
        final itemCount = cart.displayItemCount;
        final total = cart.getTotalPrice();
        final showPrice = itemCount > 0;

        final buttonSize = 100.s;
        final maxPillExtension = 110.s; // На сколько плашка выезжает вправо

        return Stack(
          alignment: Alignment.bottomLeft,
          clipBehavior: Clip.none,
          children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              tween: Tween<double>(begin: 0.0, end: showPrice ? 1.0 : 0.0),
              builder: (context, t, child) {
                // Текущая ширина "выпирающей" части плашки
                final currentExposedWidth = maxPillExtension * t;
                
                // Чтобы весь объект всегда оставался визуально по центру:
                // Мы вычисляем его общую ширину (шестеренка + выпирающая плашка) 
                // и позиционируем строго посередине экрана
                final currentTotalWidth = buttonSize + currentExposedWidth;
                final leftPosition = (screenWidth / 2) - (currentTotalWidth / 2);

                return Positioned(
                  left: leftPosition,
                  bottom: 16.s,
                  child: GestureDetector(
                    onTap: () => _openCart(context),
                    child: SizedBox(
                      width: currentTotalWidth,
                      height: buttonSize,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // 1. Монолитный 3D-фон (Шестеренка + Плашка = Одно целое)
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            right: 0,
                            child: CustomPaint(
                              painter: CombinedClayPainter(
                                buttonSize: buttonSize,
                                exposedWidth: currentExposedWidth,
                                baseColor: _cartOrange,
                              ),
                            ),
                          ),

                          // 2. Текст с ценой (Плавно появляется внутри плашки)
                          if (t > 0.05)
                            Positioned(
                              left: buttonSize * 0.85, // Смещение вправо от шестеренки
                              top: 0,
                              bottom: 0,
                              width: currentExposedWidth + (buttonSize * 0.15),
                              child: Opacity(
                                opacity: t,
                                child: Align(
                                  alignment: Alignment.center,
                                  child: Text(
                                    _money(total),
                                    key: ValueKey(total),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w900,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.3),
                                          offset: const Offset(0, 1),
                                          blurRadius: 2,
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),

                          // 3. Бейджик количества товаров (Всегда в центре шестеренки)
                          Positioned(
                            left: 0,
                            top: 0,
                            width: buttonSize,
                            height: buttonSize,
                            child: itemCount > 0
                                ? Center(
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8.s, vertical: 4.s),
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius: BorderRadius.circular(12.s),
                                      ),
                                      child: Text(
                                        '$itemCount',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}