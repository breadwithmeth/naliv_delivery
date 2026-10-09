import 'package:flutter/material.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../features/faq/faq_navigation.dart';
import '../../../features/faq/models/faq.dart';
import '../../../ui/app_icon.dart';
import '../../../ui/surfaces.dart';
import '../../../ui/app_top_bar.dart';

/// Explains estimates, server-confirmed bonus operations, and checkout benefits.
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
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
            const _BonusHero(),
            const SizedBox(height: AppSpacing.huge),
            Text(
              'Как это работает',
              style:
                  AppTypography.headline.copyWith(color: palette.textPrimary),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            const _Card(
              title: 'Начисление',
              lines: [
                'До завершения заказа показывается только предварительная оценка.',
                'Фактический баланс и начисления подтверждаются серверной историей бонусов.',
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
              body: 'Проверьте предварительную оценку и итог при оформлении.',
            ),
            const _Step(
              number: '3',
              title: 'Получите бонусы',
              body: 'Проверьте начисление в истории бонусов после обработки заказа.',
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
              lines: [
                'Доступная сумма списания показывается при оформлении заказа.',
                'Списание работает только внутри приложения во время оформления корзины.',
                'Бонусы, промокод и сертификат нельзя применить вместе.',
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const _Card(
              title: 'Ограничения',
              lines: [
                'Доступная сумма зависит от актуального баланса и подходящих товаров.',
                'Возврат и отмена не подтверждают автоматическое изменение бонусов: проверьте серверную историю.',
                'Если операция отсутствует или баланс не обновился, обратитесь в поддержку.',
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            AppSurface(
              fill: palette.accentFaint,
              border: Border.all(
                  color: palette.accent.withValues(alpha: .25)),
              padding: const EdgeInsets.all(16),
              onTap: onOpenFaq ??
                  () => openFaqPage(context,
                      initialSection: FaqSection.bonuses),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIcon(AppIcons.faq, size: 28, color: palette.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FAQ по бонусам и акциям',
                            style: AppTypography.bodyBold
                                .copyWith(color: palette.textPrimary)),
                        const SizedBox(height: 6),
                        Text(
                          'Ответы о списании, начислении и возвратах.',
                          style: AppTypography.label
                              .copyWith(color: palette.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        Text('Открыть FAQ',
                            style: AppTypography.body
                                .copyWith(color: palette.accent)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }
}

class _BonusHero extends StatelessWidget {
  const _BonusHero();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Бонусы за покупки',
            style: AppTypography.titleMedium
                .copyWith(color: palette.textPrimary)),
        const SizedBox(height: 6),
        Text('Используйте доступные бонусы при следующем заказе.',
            style: AppTypography.label
                .copyWith(color: palette.textSecondary)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
              color: palette.accentSoft, borderRadius: AppRadii.lgAll),
          child: Text('1 бонус = 1 ₸',
              style: AppTypography.bodySmallSemibold
                  .copyWith(color: palette.textPrimary)),
        ),
      ],
    );
    final artwork = Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
          shape: BoxShape.circle, color: palette.accentFaint),
      child: AppIcon(AppIcons.bonusStar, size: 44, color: palette.accent),
    );
    return AppSurface(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [artwork, const SizedBox(height: 12), text],
          );
        }
        return Row(
          children: [
            artwork,
            const SizedBox(width: 16),
            Expanded(child: text),
          ],
        );
      }),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bodyStyle =
        AppTypography.bodySmall.copyWith(color: palette.textSecondary);
    return Container(
      padding: const EdgeInsets.all(12),
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
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 4, color: palette.accent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(line, style: bodyStyle)),
                ],
              ),
            ),
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
      child: AppSurface(
        padding: const EdgeInsets.all(12),
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: palette.accent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(number,
                style: AppTypography.bodyBold
                    .copyWith(color: palette.textOnAccent)),
          ),
          const SizedBox(width: 8),
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
                  style: AppTypography.bodySmall
                      .copyWith(color: palette.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
