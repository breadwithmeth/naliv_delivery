import 'package:flutter/material.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../ui/app_top_bar.dart';

/// «Как работают бонусы» — the design's explainer frames.
///
/// A static long-read: the copy is taken verbatim from the design (1 бонус = 1₸, the three-step
/// accrual, the 25 % spending cap, tobacco and delivery exclusions, and the FAQ pointer at the
/// end). The app had no equivalent screen, so this content exists only in the file.
///
/// Type sizes follow the frames: section headers 20/700, block titles 16/500, body 10/400, step
/// numbers 14/700 in the accent, and the footer link 14/400 in the accent.
class BonusHowItWorksPage extends StatelessWidget {
  const BonusHowItWorksPage({this.onOpenFaq, super.key});

  /// Opens the FAQ, which the design links to at the bottom.
  final VoidCallback? onOpenFaq;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xxxl,
            0,
            AppSpacing.xxxl,
            AppSpacing.huge + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            AppTopBar(
              title: 'Как работают бонусы',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(height: AppSpacing.huge),
            const _Card(
              title: 'Бонусы за каждый заказ',
              body:
                  'Получайте бонусы за покупки и используйте их при следующем заказе.',
              highlight: 'Главное правило: 1 бонус = 1₸',
            ),
            const SizedBox(height: AppSpacing.huge),
            Text(
              'Как это работает',
              style:
                  AppTypography.headline.copyWith(color: palette.textPrimary),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            const _Card(
              title: 'Начисление',
              lines: const [
                'После каждого выполненного заказа начисляются Бонусы Продавца.',
                'Размер начисления зависит от товара и процента, указанного в его карточке.',
                '1 бонус = 1₸',
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const _Step(
              number: '1',
              title: 'Соберите заказ',
              body: 'Бонусы считаются по подходящим товарам в корзине.',
            ),
            const _Step(
              number: '2',
              title: 'Оформите покупку',
              body: 'Итог начисления уже виден в корзине и при оформлении.',
            ),
            const _Step(
              number: '3',
              title: 'Получите бонусы',
              body: 'После завершения заказа бонусы появятся на балансе.',
            ),
            const SizedBox(height: AppSpacing.huge),
            Text(
              'Как списывать бонусы',
              style:
                  AppTypography.headline.copyWith(color: palette.textPrimary),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            const _Card(
              title: 'Использование',
              lines: const [
                'Бонусами можно оплатить\u00a0до 25%\u00a0стоимости следующих заказов.',
                'Списание работает только внутри приложения во время оформления корзины.',
                'Бонусы не суммируются с промокодом в одном заказе.',
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const _Card(
              title: 'Ограничения',
              lines: const [
                'Доставка и табачная продукция не оплачиваются бонусами.',
                'Начисление не происходит мгновенно: бонусы появляются после завершения заказа.',
                'Если нужен полный разбор по кешбэку, акциям и промокодам, откройте FAQ ниже.',
              ],
            ),
            const SizedBox(height: AppSpacing.huge),
            Text(
              'FAQ по бонусам и акциям',
              style:
                  AppTypography.bodyBold.copyWith(color: palette.textPrimary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Откройте ответы о кешбэке, промокодах и механике акций\u00a01+1 / 2+1 / 3+1.',
              style: AppTypography.base(size: 10, weight: 400)
                  .copyWith(color: palette.textSecondary, height: 1.3),
            ),
            const SizedBox(height: AppSpacing.xl),
            GestureDetector(
              onTap: onOpenFaq,
              behavior: HitTestBehavior.opaque,
              child: Text(
                'Открыть FAQ',
                style: AppTypography.body.copyWith(color: palette.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, this.body, this.lines, this.highlight});

  final String title;
  final String? body;
  final List<String>? lines;
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bodyStyle = AppTypography.base(size: 10, weight: 400)
        .copyWith(color: palette.textSecondary, height: 1.3);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:
                AppTypography.titleMedium.copyWith(color: palette.textPrimary),
          ),
          const SizedBox(height: AppSpacing.md),
          if (body != null) Text(body!, style: bodyStyle),
          for (final line in lines ?? const <String>[])
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(line, style: bodyStyle),
            ),
          if (highlight != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              highlight!,
              style: AppTypography.base(size: 10, weight: 600)
                  .copyWith(color: palette.textPrimary, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.body});

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              number,
              style: AppTypography.bodyBold.copyWith(color: palette.accent),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleMedium
                      .copyWith(color: palette.textPrimary),
                ),
                Text(
                  body,
                  style: AppTypography.base(size: 10, weight: 400)
                      .copyWith(color: palette.textSecondary, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
