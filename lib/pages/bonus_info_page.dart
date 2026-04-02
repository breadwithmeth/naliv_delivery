import 'package:flutter/material.dart';
import 'package:gradusy24/shared/app_theme.dart';
import 'package:gradusy24/utils/responsive.dart';

class BonusInfoPage extends StatelessWidget {
  const BonusInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.text,
        title: const Text('Как работают бонусы', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16.s, 8.s, 16.s, 24.s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero
                  Container(
                    padding: EdgeInsets.all(18.s),
                    decoration: AppDecorations.card(radius: 24, color: AppColors.cardDark.withValues(alpha: 0.96)),
                    child: Column(
                      children: [
                        Container(
                          width: 80.s,
                          height: 80.s,
                          decoration: BoxDecoration(
                            color: AppColors.orange.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(18.s),
                            child: Image.asset('assets/icons/gift.png', fit: BoxFit.contain),
                          ),
                        ),
                        SizedBox(height: 14.s),
                        Text(
                          'Бонусы за каждый заказ',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.text, fontSize: 20.sp, fontWeight: FontWeight.w800, height: 1.15),
                        ),
                        SizedBox(height: 6.s),
                        Text(
                          'Получайте бонусы за покупки и используйте их при следующем заказе.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMute, fontSize: 13.sp, height: 1.4, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16.s),

                  // Steps
                  _stepCard(
                    step: '1',
                    icon: Icons.add_shopping_cart_rounded,
                    title: 'Соберите заказ',
                    description: 'Бонусы считаются по подходящим товарам в корзине.',
                  ),
                  SizedBox(height: 8.s),
                  _stepCard(
                    step: '2',
                    icon: Icons.receipt_long_rounded,
                    title: 'Оформите покупку',
                    description: 'Итог начисления уже виден в корзине и при оформлении.',
                  ),
                  SizedBox(height: 8.s),
                  _stepCard(
                    step: '3',
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Получите бонусы',
                    description: 'После завершения заказа бонусы появятся на балансе.',
                  ),

                  SizedBox(height: 16.s),

                  // Key points
                  Text(
                    'Важно знать',
                    style: TextStyle(color: AppColors.text, fontSize: 15.sp, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 8.s),
                  _keyPoint(Icons.local_shipping_outlined, 'Доставка и некоторые категории товаров в начисление не входят.'),
                  SizedBox(height: 6.s),
                  _keyPoint(Icons.schedule_outlined, 'Бонусы начисляются после завершения заказа, не сразу.'),
                  SizedBox(height: 6.s),
                  _keyPoint(Icons.percent_rounded, 'Списать можно только бонусы, которые уже на балансе.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepCard({
    required String step,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: EdgeInsets.all(12.s),
      decoration: AppDecorations.card(radius: 16, color: AppColors.cardDark.withValues(alpha: 0.96)),
      child: Row(
        children: [
          Container(
            width: 32.s,
            height: 32.s,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.orange,
              borderRadius: BorderRadius.circular(10.s),
            ),
            child: Text(step, style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14.sp)),
          ),
          SizedBox(width: 10.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: AppColors.orange, size: 15.s),
                    SizedBox(width: 5.s),
                    Expanded(
                      child: Text(title, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 13.sp)),
                    ),
                  ],
                ),
                SizedBox(height: 3.s),
                Text(description, style: TextStyle(color: AppColors.textMute, fontWeight: FontWeight.w600, fontSize: 12.sp, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _keyPoint(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.orange, size: 16.s),
        SizedBox(width: 8.s),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: AppColors.textMute, fontSize: 12.sp, height: 1.35, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
