import 'package:flutter/material.dart';
import 'package:naliv_delivery/shared/app_theme.dart';
import 'package:naliv_delivery/utils/responsive.dart';
import 'faq_page.dart';

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
        title: const Text('Как работают бонусы',
            style: TextStyle(fontWeight: FontWeight.w800)),
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
                  _heroCard(),
                  SizedBox(height: 16.s),
                  _sectionLabel('Как это работает'),
                  SizedBox(height: 8.s),
                  _factCard(
                    title: 'Начисление',
                    icon: Icons.add_chart_rounded,
                    accent: AppColors.orange,
                    lines: const [
                      'После каждого выполненного заказа начисляются Бонусы Продавца.',
                      'Размер начисления зависит от товара и процента, указанного в его карточке.',
                      '1 бонус = 1 тенге.',
                    ],
                  ),
                  SizedBox(height: 16.s),
                  _stepCard(
                    step: '1',
                    icon: Icons.add_shopping_cart_rounded,
                    title: 'Соберите заказ',
                    description:
                        'Бонусы считаются по подходящим товарам в корзине.',
                  ),
                  SizedBox(height: 8.s),
                  _stepCard(
                    step: '2',
                    icon: Icons.receipt_long_rounded,
                    title: 'Оформите покупку',
                    description:
                        'Итог начисления уже виден в корзине и при оформлении.',
                  ),
                  SizedBox(height: 8.s),
                  _stepCard(
                    step: '3',
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Получите бонусы',
                    description:
                        'После завершения заказа бонусы появятся на балансе.',
                  ),
                  SizedBox(height: 16.s),
                  _sectionLabel('Как списывать бонусы'),
                  SizedBox(height: 8.s),
                  _factCard(
                    title: 'Использование',
                    icon: Icons.account_balance_wallet_outlined,
                    accent: const Color(0xFF34C759),
                    lines: const [
                      'Бонусами можно оплатить до 25% стоимости следующих заказов.',
                      'Списание работает только внутри приложения во время оформления корзины.',
                      'Бонусы не суммируются с промокодом в одном заказе.',
                    ],
                  ),
                  SizedBox(height: 8.s),
                  _factCard(
                    title: 'Ограничения',
                    icon: Icons.rule_rounded,
                    accent: AppColors.textMute,
                    lines: const [
                      'Доставка и табачная продукция не оплачиваются бонусами.',
                      'Начисление не происходит мгновенно: бонусы появляются после завершения заказа.',
                      'Если нужен полный разбор по кешбэку, акциям и промокодам, откройте FAQ ниже.',
                    ],
                  ),
                  SizedBox(height: 18.s),
                  FaqShortcutCard(
                    title: 'FAQ по бонусам и акциям',
                    subtitle:
                        'Откройте ответы о кешбэке, промокодах и механике акций 1+1 / 2+1 / 3+1.',
                    initialSection: FaqSection.bonuses,
                    icon: Icons.stars_rounded,
                    compact: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: EdgeInsets.all(18.s),
      decoration: AppDecorations.card(
        radius: 24,
        color: AppColors.cardDark.withValues(alpha: 0.96),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58.s,
                height: 58.s,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(12.s),
                  child: Image.asset(
                    'assets/icons/gift.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              SizedBox(width: 12.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Бонусы за каждый заказ',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 4.s),
                    Text(
                      'Получайте бонусы за покупки и используйте их при следующем заказе.',
                      style: TextStyle(
                        color: AppColors.textMute,
                        fontSize: 12.sp,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.s),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 10.s),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14.s),
              border:
                  Border.all(color: AppColors.orange.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                Icon(Icons.toll_rounded, color: AppColors.orange, size: 16.s),
                SizedBox(width: 8.s),
                Expanded(
                  child: Text(
                    'Главное правило: 1 бонус = 1 тенге.',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.text,
        fontSize: 15.sp,
        fontWeight: FontWeight.w800,
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
      decoration: AppDecorations.card(
          radius: 16, color: AppColors.cardDark.withValues(alpha: 0.96)),
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
            child: Text(step,
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.sp)),
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
                      child: Text(title,
                          style: TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.sp)),
                    ),
                  ],
                ),
                SizedBox(height: 3.s),
                Text(description,
                    style: TextStyle(
                        color: AppColors.textMute,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.sp,
                        height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _factCard({
    required String title,
    required IconData icon,
    required Color accent,
    required List<String> lines,
  }) {
    return Container(
      padding: EdgeInsets.all(14.s),
      decoration: AppDecorations.card(
        radius: 18,
        color: AppColors.cardDark.withValues(alpha: 0.96),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34.s,
                height: 34.s,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.s),
                ),
                child: Icon(icon, color: accent, size: 18.s),
              ),
              SizedBox(width: 10.s),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.s),
          ...lines.asMap().entries.map(
            (entry) => Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == lines.length - 1 ? 0 : 7.s,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 5.s,
                    height: 5.s,
                    margin: EdgeInsets.only(top: 6.s),
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8.s),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        color: AppColors.textMute,
                        fontSize: 12.sp,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
