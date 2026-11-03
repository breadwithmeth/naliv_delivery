import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Everything here follows «Оплата с Kaspi.kz | Компоненты и правила» (Figma file
// pNQjZoaE1v2Ud2cpqtU4sq). Artwork is used only as exported from that file, never
// redrawn, recoloured or given effects; every logo keeps clear space of at least 20%
// of its height, and the pay button keeps at least 8 dp around it.

const _kaspiRed = Color(0xFFF14635);

/// Kaspi.kz logo for screens of the payment process.
///
/// The full logo is the basic one (6199:60564) on light backgrounds; dark backgrounds do
/// not give the basic logo's black wordmark enough contrast, so they use the official
/// logo for coloured or complex backgrounds (white plate, 6199:59860), scaled uniformly
/// to the 112 dp the rules ask of a full logo. Every layout of this app has room for it
/// (a payment-method row at 320 dp keeps 220 dp for the logo and Gold), so the compact
/// mark (written-name or short-space variant) is never needed. The white wordmark that
/// sits inside the red button is a button element and is not used on its own.
///
/// The logo keeps a clear space of 20% of its height on every side. A layout that
/// already guarantees that space around it (a list row with its own padding) passes
/// [clearSpace] `false`, so the artwork lines up with the row's other leading glyphs.
class KaspiLogo extends StatelessWidget {
  const KaspiLogo({super.key, this.clearSpace = true});

  /// Whether the logo adds its own 20% free zone.
  final bool clearSpace;

  /// Width of the full logo: the minimum the rules allow, on both backgrounds.
  static const double fullWidth = 112;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // The plate is drawn 96 × 28; scaling it to 112 keeps its proportions.
    final height = dark ? fullWidth * 28 / 96 : 28.0;
    return Padding(
      padding: EdgeInsets.all(clearSpace ? height * .2 : 0),
      child: SvgPicture.asset(
        dark
            ? 'assets/icons/kaspi/logo_plate.svg'
            : 'assets/icons/kaspi/logo.svg',
        width: fullWidth,
        height: height,
        semanticsLabel: 'Kaspi.kz',
      ),
    );
  }
}

/// ProductBadge / Gold as shown next to Kaspi.kz in a list of payment methods
/// (6199:60019, drawn at the list height of 28). [clearSpace] works as on
/// [KaspiLogo].
class KaspiGoldBadge extends StatelessWidget {
  const KaspiGoldBadge({super.key, this.clearSpace = true});

  final bool clearSpace;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.all(clearSpace ? 28 * .2 : 0),
        child: SvgPicture.asset(
          'assets/icons/kaspi/gold.svg',
          width: 36.4,
          height: 28,
          semanticsLabel: 'Kaspi Gold',
        ),
      );
}

/// The official full-width red «Button / Gold» (6199:60416): `#F14635`, recommended
/// radius 8, height 52, and centred Logo / White, a 1 × 28 white divider and
/// ProductBadge / Gold with 16 dp between them. Only its width follows the layout,
/// as the component's centred auto-layout does. The appearance never changes with
/// state (no other colours or effects), so an unavailable payment is explained by
/// the page rather than by dimming the button.
class KaspiPayButton extends StatelessWidget {
  const KaspiPayButton({super.key, this.buttonKey, required this.onPressed});

  final Key? buttonKey;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        // Free zone of at least 8 dp. Horizontally the frosted dock already keeps
        // 16 dp, so the button spans its full width and is never smaller than the
        // other payment action.
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: FilledButton(
          key: buttonKey,
          onPressed: onPressed,
          style: ButtonStyle(
            backgroundColor: const WidgetStatePropertyAll(_kaspiRed),
            foregroundColor: const WidgetStatePropertyAll(Colors.white),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
            elevation: const WidgetStatePropertyAll(0),
            shadowColor: const WidgetStatePropertyAll(Colors.transparent),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
            padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(vertical: 12)),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          child: Semantics(
            label: 'Оплатить с Kaspi.kz',
            excludeSemantics: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/icons/kaspi/button_logo.svg',
                  width: 112,
                  height: 28,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: 16),
                const SizedBox(
                  width: 1,
                  height: 28,
                  child: ColoredBox(color: Colors.white),
                ),
                const SizedBox(width: 16),
                SvgPicture.asset(
                  'assets/icons/kaspi/button_gold.svg',
                  width: 36,
                  height: 28,
                  excludeFromSemantics: true,
                ),
              ],
            ),
          ),
        ),
      );
}

/// Kaspi's recommended loader for the payment process: a red arc on the page.
class KaspiLoader extends StatelessWidget {
  const KaspiLoader({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 72,
        height: 72,
        child: CircularProgressIndicator(
          strokeWidth: 6,
          color: _kaspiRed,
        ),
      );
}

/// Kaspi's recommended result marks: a green check for an accepted payment and a
/// grey cross for a cancelled or failed one, each in a soft ring.
class KaspiResultMark extends StatelessWidget {
  const KaspiResultMark({super.key, required this.accepted});

  final bool accepted;

  @override
  Widget build(BuildContext context) {
    final fill = accepted ? const Color(0xFFA5DC5A) : const Color(0xFF757575);
    final ring = accepted
        ? const Color(0xFFA5DC5A).withValues(alpha: .25)
        : Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFE5E5E5);
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: 8),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(shape: BoxShape.circle, color: fill),
        child: Icon(accepted ? Icons.check_rounded : Icons.close_rounded,
            size: 44, color: Colors.white),
      ),
    );
  }
}
