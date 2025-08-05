/// Модель адреса, соответствует данным selectedAddress
class Address {
  final int? addressId;
  final String address;
  final double lat;
  final double lon;
  final double accuracy;
  final String source;
  final DateTime timestamp;
  final Map<String, String>?
      details; // Дополнительные поля, например квартира, подъезд

  Address({
    this.addressId,
    required this.address,
    required this.lat,
    required this.lon,
    required this.accuracy,
    required this.source,
    required this.timestamp,
    this.details,
  });

  /// Создает модель из Map<String, dynamic>, поддерживает формат API адресов
  factory Address.fromMap(Map<String, dynamic> map) {
    // ID адреса (place_id или сохраненный address_id)
    final int? id = map['place_id'] is int
        ? map['place_id'] as int
        : map['address_id'] is int
            ? map['address_id'] as int
            : null;
    // Основное название адреса
    final String addr =
        map['display_name'] as String? ?? map['name'] as String? ?? '';
    // Координаты (API использует вложенный point)
    double latVal = 0.0;
    double lonVal = 0.0;
    if (map['point'] is Map<String, dynamic>) {
      final point = map['point'] as Map<String, dynamic>;
      latVal = (point['lat'] as num?)?.toDouble() ?? 0.0;
      lonVal = (point['lon'] as num?)?.toDouble() ?? 0.0;
    } else {
      latVal = (map['lat'] as num?)?.toDouble() ?? 0.0;
      lonVal = (map['lon'] as num?)?.toDouble() ?? 0.0;
    }
    // Дополнительные данные адреса (house_number, road, city и пр.)
    Map<String, String>? extra;
    if (map['address'] is Map<String, dynamic>) {
      extra = (map['address'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v.toString()));
    }
    return Address(
      addressId: id,
      address: addr,
      lat: latVal,
      lon: lonVal,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0.0,
      source: map['type'] as String? ?? map['category'] as String? ?? '',
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ??
          DateTime.now(),
      details: extra,
    );
  }

  /// Конвертирует модель в Map<String, dynamic>
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> result = {
      'place_id': addressId,
      'display_name': address,
      'point': {'lat': lat, 'lon': lon},
      'accuracy': accuracy,
      'type': source,
      'timestamp': timestamp.toIso8601String(),
    };
    if (details != null) {
      result['address'] = details;
    }
    return result;
  }

  /// Копирует модель с изменением полей
  Address copyWith({
    int? addressId,
    String? address,
    double? lat,
    double? lon,
    double? accuracy,
    String? source,
    DateTime? timestamp,
    Map<String, String>? details,
  }) {
    return Address(
      addressId: addressId ?? this.addressId,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      accuracy: accuracy ?? this.accuracy,
      source: source ?? this.source,
      timestamp: timestamp ?? this.timestamp,
      details: details ?? this.details,
    );
  }

  @override
  String toString() {
    return 'Address(id: $addressId, address: $address)';
  }
}
