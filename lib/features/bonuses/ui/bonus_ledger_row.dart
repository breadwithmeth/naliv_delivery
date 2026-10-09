import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../design/theme.dart';
import '../../../design/typography.dart';
import '../../../ui/surfaces.dart';
import '../bonus_account.dart';

class BonusLedgerRow extends StatelessWidget {
  const BonusLedgerRow({required this.entry, this.onTap, super.key});

  final BonusLedgerEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(entry.title,
            style: AppTypography.bodyBold.copyWith(color: palette.textPrimary)),
        const SizedBox(height: 3),
        Text(_dateLabel(),
            style: AppTypography.label.copyWith(color: palette.textSecondary)),
        if (entry.reference case final reference?)
          Text(reference,
              style: AppTypography.label.copyWith(color: palette.textSecondary)),
      ],
    );
    final amount = Text(
      signedBonusLabel(entry.amount),
      textAlign: TextAlign.end,
      style: AppTypography.body.copyWith(
          color: entry.amount > 0 ? palette.gold : palette.textPrimary),
    );
    return AppSurface(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(14) > 19) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [identity, const SizedBox(height: 8), amount],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: identity),
            const SizedBox(width: 12),
            Flexible(child: amount),
          ],
        );
      }),
    );
  }

  String _dateLabel() {
    final raw = entry.timestamp;
    final date = DateTime.tryParse(raw ?? '')?.toLocal();
    if (date == null) return raw ?? 'Дата не передана';
    return '${DateFormat('d MMMM', 'ru').format(date)} в '
        '${DateFormat('HH:mm').format(date)}';
  }
}
