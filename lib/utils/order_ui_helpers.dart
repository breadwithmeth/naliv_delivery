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

bool canPayOrder(Map<String, dynamic> order) {
  if (isOrderCanceled(order)) return false;
  if (_resolveOrderId(order) == null) return false;

  final amount = resolveOrderTotalAmount(order);
  if (amount == null || amount <= 0) return false;

  final currentStatus = asOrderMap(order['current_status']);
  final statusCode =
      currentStatus?['status']?.toString() ?? asOrderMap(order['status'])?['status']?.toString();
  if (const {'6', '60', '66'}.contains(statusCode)) {
    return true;
  }

  final paymentStatus = _normalizeStatus(order['payment_status']);
  final kaspiStatus = _normalizeStatus(order['kaspi_status']);

  if (_repayablePaymentStatuses.contains(paymentStatus) ||
      _repayablePaymentStatuses.contains(kaspiStatus)) {
    return true;
  }

  if (_completedPaymentStatuses.contains(paymentStatus) ||
      _completedPaymentStatuses.contains(kaspiStatus)) {
    return false;
  }

  return false;
}

num? resolveOrderTotalAmount(Map<String, dynamic> order) {
  return _asNum(order['payable_amount']) ??
      _asNum(order['final_amount']) ??
      _asNum(order['total_sum']) ??
      _asNum(order['total_amount']) ??
      _asNum(order['amount']) ??
      _asNum(asOrderMap(order['cost_summary'])?['total_sum']) ??
      _asNum(asOrderMap(order['cost_summary'])?['total']) ??
      _asNum(asOrderMap(order['cost_summary'])?['order_total']) ??
      _asNum(asOrderMap(order['cost'])?['total_sum']) ??
      _asNum(asOrderMap(order['cost'])?['total']) ??
      _asNum(asOrderMap(order['cost'])?['order_total']);
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

String? _resolveOrderId(Map<String, dynamic> order) {
  final raw = order['order_id'] ?? order['order_uuid'] ?? order['id'];
  final normalized = raw?.toString().trim();
  if (normalized == null || normalized.isEmpty || normalized.toLowerCase() == 'null') {
    return null;
  }
  return normalized;
}

num? _asNum(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  return num.tryParse(value.toString());
}

String _normalizeStatus(dynamic value) {
  return value?.toString().trim().toLowerCase().replaceAll('-', '_') ?? '';
}

const Set<String> _completedPaymentStatuses = <String>{
  'completed',
  'paid',
  'processed',
  'success',
  'succeeded',
};

const Set<String> _repayablePaymentStatuses = <String>{
  'failed',
  'rejected',
  'canceled',
  'cancelled',
  'expired',
  'error',
  'declined',
  'awaiting_payment',
  'waiting_for_payment',
  'payment_required',
  'requires_payment',
  'pending_payment',
};
