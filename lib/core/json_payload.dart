Map<String, dynamic>? nullablePayloadMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }
  return null;
}

Map<String, dynamic> payloadMap(Object? value) =>
    nullablePayloadMap(value) ?? <String, dynamic>{};

List<dynamic> payloadList(Object? value) {
  if (value is List) return value;
  if (value is Map) return <dynamic>[value];
  return const <dynamic>[];
}

List<Map<String, dynamic>> payloadMaps(Object? value) => payloadList(value)
    .map(nullablePayloadMap)
    .whereType<Map<String, dynamic>>()
    .toList(growable: false);

String? payloadString(Object? value, {bool allowEmpty = false}) {
  if (value == null) return null;
  final normalized = value.toString().trim();
  if (!allowEmpty &&
      (normalized.isEmpty || normalized.toLowerCase() == 'null')) {
    return null;
  }
  return normalized;
}

bool payloadBool(Object? value, {bool defaultValue = false}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is num) return value != 0;
  switch ((payloadString(value) ?? '').toLowerCase()) {
    case 'true':
    case '1':
    case 'yes':
    case 'y':
    case 'on':
      return true;
    case 'false':
    case '0':
    case 'no':
    case 'n':
    case 'off':
      return false;
    default:
      return defaultValue;
  }
}

int payloadInt(Object? value, {int defaultValue = 0}) {
  if (value == null) return defaultValue;
  if (value is bool) return value ? 1 : 0;
  if (value is num) return value.toInt();
  final normalized = payloadString(value);
  if (normalized == null) return defaultValue;
  final compact = normalized.replaceAll(' ', '').replaceAll(',', '.');
  return int.tryParse(compact) ??
      double.tryParse(compact)?.toInt() ??
      defaultValue;
}

double? payloadDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final normalized = payloadString(value);
  return normalized == null
      ? null
      : double.tryParse(normalized.replaceAll(' ', '').replaceAll(',', '.'));
}

List<int> payloadInts(Object? value) => payloadList(value)
    .map((entry) => payloadInt(entry, defaultValue: -1))
    .where((entry) => entry >= 0)
    .toList(growable: false);
