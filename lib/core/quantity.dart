/// Formats base-unit quantities with the same precision as container allocation.
String formatQuantity(double quantity, String unit) {
  final value = quantity <= 0 ? 0.0 : quantity;
  final String label;
  if (value % 1 == 0) {
    label = value.toStringAsFixed(0);
  } else {
    final text = value.toStringAsFixed(6);
    var end = text.length;
    while (end > 0 && text[end - 1] == '0') {
      end--;
    }
    if (end > 0 && text[end - 1] == '.') end--;
    label = text.substring(0, end);
  }
  return unit.isEmpty ? label : '$label $unit';
}

String? quantityUnitLabel(String? unit) {
  final normalized = unit?.trim().toLowerCase().replaceAll('.', '');
  if (normalized == null || normalized.isEmpty) return null;
  if (const ['кг', 'kg', 'килограмм', 'килограммы'].contains(normalized)) {
    return 'кг';
  }
  if (const ['л', 'l', 'литр', 'литры'].contains(normalized)) return 'л';
  if (const ['шт', 'pcs', 'pc', 'штука', 'штуки'].contains(normalized)) {
    return 'шт';
  }
  return unit!.trim();
}
