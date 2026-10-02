import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Unmodified SVG exports from the supplied «Оплата с Kaspi.kz» Figma file:
// compact 6199:60011, Gold 6199:60019, full 6199:60564, white 6199:60478.
// Guide 6199:60135 permits the compact mark beside a text name; 6199:60299
// requires at least 20% of the artwork height as clear space.
class KaspiLogo extends StatelessWidget {
  const KaspiLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 32.0 : 28.0;
    final white = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.all(height * .2),
      child: SvgPicture.asset(
        'assets/icons/kaspi/${compact ? 'compact' : white ? 'logo_white' : 'logo'}.svg',
        width: compact ? 32 : 112,
        height: height,
        semanticsLabel: compact ? null : 'Kaspi.kz',
        excludeFromSemantics: compact,
      ),
    );
  }
}

class KaspiGoldBadge extends StatelessWidget {
  const KaspiGoldBadge({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(5.6),
        child: SvgPicture.asset(
          'assets/icons/kaspi/gold.svg',
          width: 36.4,
          height: 28,
          semanticsLabel: 'Kaspi Gold',
        ),
      );
}

// Official Button / Logo / Compact, exported intact from 6199:60489:
// 160 × 52, #F14635 and radius 8. The native action extends the same plain
// background to the app's full-width hit area without changing the artwork.
// This logo-only variant needs no redrawn or unscaled ordinary text.
class KaspiPayButton extends StatelessWidget {
  const KaspiPayButton({super.key, this.buttonKey, required this.onPressed});

  final Key? buttonKey;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
        key: buttonKey,
        onPressed: onPressed,
        style: ButtonStyle(
          backgroundColor: const WidgetStatePropertyAll(Color(0xFFF14635)),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          minimumSize: const WidgetStatePropertyAll(Size(160, 52)),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        child: Semantics(
          label: 'Оплатить с Kaspi.kz',
          excludeSemantics: true,
          child: SvgPicture.asset(
            'assets/icons/kaspi/pay_compact.svg',
            width: 160,
            height: 52,
            excludeFromSemantics: true,
          ),
        ),
      );
}
