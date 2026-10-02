/// Money formatting, in one place.
///
/// The design prints sums as `92 190 ₸` — a narrow no-break-space group separator and the
/// tenge sign — in the cart button, product prices and order totals alike, so every surface
/// must format identically.
library;

/// `92190 -> "92 190 ₸"`.
///
/// The non-breaking space (U+00A0) keeps grouped digits together.
String formatTenge(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('\u00A0');
    buffer.write(digits[i]);
  }
  return '${amount < 0 ? '-' : ''}$buffer ₸';
}
