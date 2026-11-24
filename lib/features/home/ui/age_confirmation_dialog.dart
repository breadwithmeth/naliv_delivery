import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../ui/app_icon.dart';
import '../../onboarding/legal_acceptance.dart';
import '../../onboarding/ui/legal_document_page.dart';

Future<bool> showAgeConfirmationDialog(BuildContext context) async {
  final navigator = Navigator.of(context);
  final route = DialogRoute<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0x99000000),
    requestFocus: true,
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    animationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (_) => const _AgeConfirmationDialog(),
  );
  final confirmed = await navigator.push(route);
  // Leave the dialog fully behind before opening a deferred destination.
  await route.completed;
  return confirmed == true;
}

class _AgeConfirmationDialog extends StatelessWidget {
  const _AgeConfirmationDialog();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    const actionFill = Color(0xFFB94F00);
    final linkColor = dark ? const Color(0xFFFF9B50) : actionFill;
    return PopScope<bool>(
      canPop: false,
      child: Dialog(
        backgroundColor: dark ? palette.surface : palette.background,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.xlAll),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        constraints: const BoxConstraints(maxWidth: 327),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.huge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: _AgeSeal(dark: dark)),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Оформлять заказы могут только покупатели от 21 года. '
                'Подтвердите свой возраст.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              Center(
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: linkColor,
                    minimumSize: const Size(44, 44),
                    textStyle: AppTypography.bodySmall,
                  ),
                  onPressed: () {
                    if (ModalRoute.of(context)?.isCurrent != true) return;
                    final asset = LegalAcceptance.assets['offer']!;
                    unawaited(Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => LegalDocumentPage.asset(
                          title: 'Публичная оферта',
                          asset: asset,
                        ),
                      ),
                    ));
                  },
                  child: const Text('Договор оферты', textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: actionFill,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 49),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: const StadiumBorder(),
                  textStyle: AppTypography.bodyBold,
                ),
                onPressed: () {
                  if (ModalRoute.of(context)?.isCurrent == true) {
                    Navigator.of(context).pop(true);
                  }
                },
                child: const Text('Мне есть 21 год', textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgeSeal extends StatelessWidget {
  const _AgeSeal({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    namesRoute: true,
    label: 'Подтверждение возраста',
    excludeSemantics: true,
    child: Stack(
      alignment: Alignment.center,
      children: [
        AppIcon(
          'assets/icons/design/age_seal.svg',
          size: 80,
          color: dark ? const Color(0xFF8B3D00) : const Color(0xFFFFB780),
        ),
        SizedBox(
          width: 60,
          height: 44,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '21+',
              style: AppTypography.base(
                size: 28,
                weight: 700,
                color: dark ? const Color(0xFFFF9B50) : const Color(0xFF8A3A00),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
