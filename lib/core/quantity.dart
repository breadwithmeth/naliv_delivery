/// Formats a supported quantity without rounding fractional litres to tenths.
String formatQuantity(double quantity, String unit) {
  if (quantity <= 0) return '0';
  final String label;
  if (quantity % 1 == 0) {
    label = quantity.toStringAsFixed(0);
  } else {
    final text = quantity.toStringAsFixed(3);
    var end = text.length;
    while (end > 0 && text[end - 1] == '0') {
      end--;
    }
    if (end > 0 && text[end - 1] == '.') end--;
    label = text.substring(0, end);
  }
  return unit.isEmpty ? label : '$label $unit';
}
