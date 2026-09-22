/// Money formatting, in one place.
///
/// The design prints sums as `92 190 ₸` — a narrow no-break-space group separator and the
/// tenge sign — in the cart button, product prices and order totals alike, so every surface
/// must format identically.
library;

/// `92190 -> "92 190 ₸"`.
///
/// The separator is a **non-breaking space** (U+00A0), which is what the design's own text nodes
/// contain (`'11\xa0853 ₸ '`) and what keeps a price from wrapping mid-number. The frozen
/// `lib/globals.dart:formatPrice` used a regular space; the digits are identical, only the
/// separator differs.
String formatTenge(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('\u00A0');
    buffer.write(digits[i]);
  }
  return '${amount < 0 ? '-' : ''}$buffer ₸';
}
