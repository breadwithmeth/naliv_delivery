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
    // Обновленные координаты векторной шестеренки со сглаженными зубьями
    path.moveTo(85.7139, 7.12339);
    path.cubicTo(88.0, 5.0, 92.33, 2.5, 95.2988, 3.055);
    path.cubicTo(97.5, 3.5, 99.8, 6.5, 102.0, 9.5);
    path.cubicTo(105.0, 10.3, 108.0, 11.5, 110.5, 12.5);
    path.cubicTo(113.8, 11.8, 118.0, 10.5, 120.8, 11.84);
    path.cubicTo(123.0, 12.9, 124.0, 16.5, 125.0, 19.5);
    path.cubicTo(127.5, 21.2, 130.0, 23.0, 132.0, 25.0);
    path.cubicTo(135.5, 25.5, 139.8, 25.5, 141.8, 27.5);
    path.cubicTo(143.5, 29.2, 143.0, 33.5, 142.8, 37.2);
    path.cubicTo(144.5, 39.5, 146.0, 42.0, 147.2, 44.5);
    path.cubicTo(150.2, 46.0, 154.2, 47.5, 155.2, 50.0);
    path.cubicTo(156.2, 52.5, 154.0, 56.2, 152.8, 59.5);
    path.cubicTo(153.8, 62.2, 154.5, 65.0, 154.8, 68.0);
    path.cubicTo(157.2, 70.5, 160.5, 73.0, 160.5, 76.0);
    path.cubicTo(160.5, 79.0, 157.2, 81.5, 154.8, 84.0);
    path.cubicTo(154.5, 87.0, 153.8, 89.8, 152.8, 92.5);
    path.cubicTo(154.0, 95.8, 156.2, 99.5, 155.2, 102.0);
    path.cubicTo(154.2, 104.5, 150.2, 106.0, 147.2, 107.5);
    path.cubicTo(146.0, 110.0, 144.5, 112.5, 142.8, 114.8);
    path.cubicTo(143.0, 118.5, 143.5, 122.8, 141.8, 124.5);
    path.cubicTo(139.8, 126.5, 135.5, 126.5, 132.0, 127.0);
    path.cubicTo(130.0, 129.0, 127.5, 130.8, 125.0, 132.5);
    path.cubicTo(124.0, 135.5, 123.0, 139.1, 120.8, 140.16);
    path.cubicTo(118.0, 141.5, 113.8, 140.2, 110.5, 139.5);
    path.cubicTo(108.0, 140.5, 105.0, 141.7, 102.0, 142.5);
    path.cubicTo(99.8, 145.5, 97.5, 148.5, 95.2988, 148.945);
    path.cubicTo(92.33, 149.5, 88.0, 147.0, 85.7139, 144.876);
    path.cubicTo(84.2, 144.95, 82.7, 145.0, 81.1992, 145.0);
    path.cubicTo(79.68, 145.0, 78.18, 144.95, 76.6846, 144.876);
    path.cubicTo(74.4, 147.0, 70.06, 149.5, 67.0996, 148.945);
    path.cubicTo(64.8, 148.5, 62.5, 145.5, 60.3, 142.5);
    path.cubicTo(57.3, 141.7, 54.3, 140.5, 51.8, 139.5);
    path.cubicTo(48.5, 140.2, 44.3, 141.5, 41.5, 140.16);
    path.cubicTo(39.3, 139.1, 38.3, 135.5, 37.3, 132.5);
    path.cubicTo(34.8, 130.8, 32.3, 129.0, 30.3, 127.0);
    path.cubicTo(26.8, 126.5, 22.5, 126.5, 20.5, 124.5);
    path.cubicTo(18.8, 122.8, 19.3, 118.5, 19.5, 114.8);
    path.cubicTo(17.8, 112.5, 16.3, 110.0, 15.1, 107.5);
    path.cubicTo(12.1, 106.0, 8.1, 104.5, 7.1, 102.0);
    path.cubicTo(6.1, 99.5, 8.3, 95.8, 9.5, 92.5);
    path.cubicTo(8.5, 89.8, 7.8, 87.0, 7.5, 84.0);
    path.cubicTo(5.1, 81.5, 1.8, 79.0, 1.8, 76.0);
    path.cubicTo(1.8, 73.0, 5.1, 70.5, 7.5, 68.0);
    path.cubicTo(7.8, 65.0, 8.5, 62.2, 9.5, 59.5);
    path.cubicTo(8.3, 56.2, 6.1, 52.5, 7.1, 50.0);
    path.cubicTo(8.1, 47.5, 12.1, 46.0, 15.1, 44.5);
    path.cubicTo(16.3, 42.0, 17.8, 39.5, 19.5, 37.2);
    path.cubicTo(19.3, 33.5, 18.8, 29.2, 20.5, 27.5);
    path.cubicTo(22.5, 25.5, 26.8, 25.5, 30.3, 25.0);
    path.cubicTo(32.3, 23.0, 34.8, 21.2, 37.3, 19.5);
    path.cubicTo(38.3, 16.5, 39.3, 12.9, 41.5, 11.84);
    path.cubicTo(44.3, 10.5, 48.5, 11.8, 51.8, 12.5);
    path.cubicTo(54.3, 11.5, 57.3, 10.3, 60.3, 9.5);
    path.cubicTo(62.5, 6.5, 64.8, 3.5, 67.0996, 3.055);
    path.cubicTo(70.06, 2.5, 74.4, 5.0, 76.6846, 7.12339);
    path.cubicTo(78.18, 7.0346, 79.68, 6.98276, 81.1992, 6.98276);
    path.cubicTo(82.71, 6.98276, 84.2, 7.0346, 85.7139, 7.12339);
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

        final buttonSize = 70.s;
        final maxPillExtension = 110.s; // На сколько плашка выезжает вправо

        return Stack(
          alignment: Alignment.bottomLeft,
          clipBehavior: Clip.none,
          children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutCirc,
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
                                      color: 
                                      showPrice ? Colors.white : Colors.transparent,
                                      
                                      fontSize: 24.sp,
                                      fontWeight: FontWeight.w900,
                                      // shadows: [
                                      //   Shadow(
                                      //     color: Colors.black.withOpacity(0.3),
                                      //     offset: const Offset(0, 1),
                                      //     blurRadius: 2,
                                      //   ),
                                      // ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),

                          // 3. Бейджик количества товаров (Всегда в центре шестеренки)
                          // Positioned(
                          //   left: 0,
                          //   top: 0,
                          //   width: buttonSize,
                          //   height: buttonSize,
                          //   child: itemCount > 0
                          //       ? Center(
                          //           child: Container(
                          //             padding: EdgeInsets.symmetric(horizontal: 8.s, vertical: 4.s),
                          //             decoration: BoxDecoration(
                          //               color: Colors.black26,
                          //               borderRadius: BorderRadius.circular(12.s),
                          //             ),
                          //             child: Text(
                          //               '$itemCount',
                          //               style: TextStyle(
                          //                 color: Colors.white,
                          //                 fontSize: 14.sp,
                          //                 fontWeight: FontWeight.w900,
                          //               ),
                          //             ),
                          //           ),
                          //         )
                          //       : const SizedBox.shrink(),
                          // ),
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