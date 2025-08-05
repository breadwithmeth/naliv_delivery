import 'package:naliv_delivery/models/Pagination.dart';

class Business {
  final int businessId;
  final String name;
  final String address;
  final String description;
  final String logo;
  final int cityId;

  Business({
    required this.businessId,
    required this.name,
    required this.address,
    required this.description,
    required this.logo,
    required this.cityId,
  });

  /// Создать объект Business из JSON
  factory Business.fromJson(Map<String, dynamic> json) {
    return Business(
      businessId: json['business_id'] ?? 0,
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      description: json['description'] ?? '',
      logo: json['logo'] ?? '',
      cityId: json['city_id'] ?? 0,
    );
  }

  /// Преобразовать объект Business в JSON
  Map<String, dynamic> toJson() {
    return {
      'business_id': businessId,
      'name': name,
      'address': address,
      'description': description,
      'logo': logo,
      'city_id': cityId,
    };
  }

  @override
  String toString() {
    return 'Business{businessId: $businessId, name: $name, address: $address}';
  }
}


/// Ответ API с бизнесами
class BusinessesResponse {
  final List<Business> businesses;
  final Pagination pagination;

  BusinessesResponse({
    required this.businesses,
    required this.pagination,
  });

  /// Создать объект BusinessesResponse из JSON
  factory BusinessesResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> businessesJson = json['businesses'] ?? [];
    final List<Business> businesses = businessesJson
        .map((businessJson) => Business.fromJson(businessJson))
        .toList();

    final Pagination pagination = Pagination.fromJson(json['pagination'] ?? {});

    return BusinessesResponse(
      businesses: businesses,
      pagination: pagination,
    );
  }
}
