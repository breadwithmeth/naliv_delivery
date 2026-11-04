import 'draft_bottles.dart';

/// The branded bag («пакет-майка») checkout adds to every order; its verified
/// public catalogue master code (store-local ids and prices are read live).
const brandedBagCode = 'KR-00002264';

/// Order lines the app adds by itself and that must never be copied back into
/// a cart (repeating an order would otherwise double them): the branded bag,
/// and the 1 л / 2 л bottles that came with drinks on tap — the cart adds
/// those again from the drinks' litres.
bool isAutoAddedOrderLine(
  Map<String, dynamic> line, {
  required bool orderHasDraftDrink,
}) {
  final nested = [
    line,
    for (final key in const ['item_data', 'item', 'catalog_item', 'product'])
      if (line[key] is Map) line[key] as Map,
  ];
  for (final source in nested) {
    final code = (source['code'] ?? source['item_code'])?.toString().trim();
    if (code == brandedBagCode) return true;
  }
  final name = (line['name'] ?? line['item_name'])?.toString() ?? '';
  final lower = name.toLowerCase().trim();
  // The store sells it as «Майка фирменная»; older orders call it a
  // «пакет-майка».
  if (lower == 'майка фирменная' ||
      (lower.contains('пакет') && lower.contains('майк'))) {
    return true;
  }
  return orderHasDraftDrink && DraftBottleCatalogue.bottleLitres(name) != null;
}
