import 'package:flutter/foundation.dart';

/// Provider для управления выбранным магазином
class BusinessProvider with ChangeNotifier {
  Map<String, dynamic>? _selectedBusiness;

  /// Получить текущий выбранный магазин
  Map<String, dynamic>? get selectedBusiness => _selectedBusiness;

  /// Получить название текущего магазина
  String? get selectedBusinessName => _selectedBusiness?['name'];

  /// Получить ID текущего магазина
  int? get selectedBusinessId {
    return _selectedBusiness?['id'] ??
        _selectedBusiness?['business_id'] ??
        _selectedBusiness?['businessId'];
  }

  /// Установить выбранный магазин
  void setSelectedBusiness(Map<String, dynamic>? business) {
    _selectedBusiness = business;
    notifyListeners();
  }

  /// Очистить выбранный магазин
  void clearSelectedBusiness() {
    _selectedBusiness = null;
    notifyListeners();
  }

  /// Проверить, выбран ли магазин
  bool get hasSelectedBusiness => _selectedBusiness != null;
}
