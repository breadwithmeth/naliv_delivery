const Map<String, String> orderStatusLabels = <String, String>{
  '0': 'Новый заказ',
  '1': 'Принят магазином',
  '11': 'Просмотрен',
  '12': 'Собирается',
  '2': 'Готов к выдаче',
  '21': 'Передан курьеру',
  '3': 'Доставляется',
  '31': 'Курьер рядом',
  '4': 'Доставлен',
  '5': 'Отменен',
  '50': 'Отменен пользователем',
  '51': 'Отменен магазином',
  '52': 'Отменен: нет в наличии',
  '6': 'Ошибка платежа',
  '60': 'Ожидает оплаты',
  '61': 'Оплата в обработке',
  '66': 'Ожидает оплаты',
  '7': 'Возврат начат',
  '71': 'Возврат завершен',
};

Map<String, dynamic>? asOrderMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, entryValue) => MapEntry(key.toString(), entryValue));
  }
  return null;
}

bool isTruthy(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;

  final normalized = value.toString().trim().toLowerCase();
  return normalized == '1' || normalized == 'true' || normalized == 'yes';
}

bool isOrderCanceled(Map<String, dynamic> order) {
  final currentStatus = asOrderMap(order['current_status']);
  final statusCode = currentStatus?['status']?.toString() ?? asOrderMap(order['status'])?['status']?.toString();

  return isTruthy(order['is_canceled']) || isTruthy(currentStatus?['is_canceled']) || const {'5', '50', '51', '52'}.contains(statusCode);
}

String resolveOrderStatusText(
  Map<String, dynamic> order, {
  Map<String, dynamic>? status,
  String fallback = 'Статус уточняется',
}) {
  if (isOrderCanceled(order)) return 'Отменен';
  return resolveStatusLabel(status ?? asOrderMap(order['current_status']) ?? asOrderMap(order['status']), fallback: fallback);
}

String resolveStatusLabel(Map<String, dynamic>? status, {String fallback = 'Статус уточняется'}) {
  if (status == null) return fallback;

  final explicitText = status['status_description']?.toString() ?? status['status_name']?.toString() ?? status['description']?.toString();
  if (explicitText != null && explicitText.trim().isNotEmpty && !_isUnknownStatusText(explicitText)) {
    return explicitText.trim();
  }

  final code = status['status']?.toString();
  if (code == null || code.isEmpty) return fallback;
  return orderStatusLabels[code] ?? (int.tryParse(code) == null ? code : 'Статус $code');
}

String resolveDeliveryTypeText(Map<String, dynamic> order) {
  final rawType = order['delivery_type']?.toString().trim().toUpperCase();
  if (rawType == 'PICKUP') return 'Самовывоз';
  if (rawType == 'DELIVERY') return 'Доставка';

  final address = asOrderMap(order['delivery_address']);
  if (isPickupAddress(address)) return 'Самовывоз';

  final extra = order['extra']?.toString().trim().toLowerCase() ?? '';
  if (extra.contains('самовывоз')) return 'Самовывоз';

  final addressText = address?['address']?.toString().trim();
  if (addressText != null && addressText.isNotEmpty) return 'Доставка';

  return 'Не указан';
}

bool isPickupOrder(Map<String, dynamic> order) {
  return resolveDeliveryTypeText(order) == 'Самовывоз';
}

bool isDeliveryOrder(Map<String, dynamic> order) {
  return resolveDeliveryTypeText(order) == 'Доставка';
}

bool isPickupAddress(Map<String, dynamic>? address) {
  if (address == null) return false;
  final addressText = address['address']?.toString().trim().toLowerCase();
  final name = address['name']?.toString().trim().toLowerCase();
  return addressText == 'самовывоз' || name == 'самовывоз';
}

bool _isUnknownStatusText(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized == 'неизвестно' || normalized == 'неизвестный статус' || normalized.contains('unknown');
}
