import 'package:flutter/material.dart';

import '../core/money.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// The one promotion sentence a customer sees at the exact threshold, priced
/// by what the next step really costs: «Ещё 1 шт — бесплатно», or for a bottled
/// drink «Ещё 1 л за 100 ₸ — только бутылка» (the drink is free, its bottle is
/// not). Anything else about a gift is told by the struck-through price.
String promotionNudgeText({
  required String quantityLabel,
  required double cost,
  required bool bottled,
}) {
  if (cost <= 0.5) return 'Ещё $quantityLabel — бесплатно';
  if (bottled) {
    return 'Ещё $quantityLabel за ${formatTenge(cost)} — только бутылка';
  }
  return 'Ещё $quantityLabel за ${formatTenge(cost)}';
}

/// A single line with the nudge and an «Добавить» action. The step is taken
/// only when the customer taps it.
class PromotionNudge extends StatelessWidget {
  const PromotionNudge({
    required this.text,
    required this.onAdd,
    this.actionKey,
    super.key,
  });

  final String text;
  final VoidCallback? onAdd;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.accentFaint,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.xl),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: AppTypography.bodySmallMedium
                    .copyWith(color: palette.textPrimary),
              ),
            ),
            TextButton(
              key: actionKey,
              onPressed: onAdd,
              style: TextButton.styleFrom(
                minimumSize:
                    const Size(AppSpacing.touchTarget, AppSpacing.touchTarget),
                foregroundColor: palette.accent,
                textStyle: AppTypography.bodySmallBold,
              ),
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }
}
