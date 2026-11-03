import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../pages/map_address_page.dart';
import '../services/onboarding_service.dart';
import '../utils/address_storage_service.dart';

class AddressSelectionModalHelper {
  /// Opens the address flow.
  ///
  /// [city] scopes the whole flow to one city (checkout passes the selected store's city, so
  /// a Temirtau store can be ordered to from a phone that onboarded in Karaganda): reverse
  /// lookup, text search and label extraction use it instead of the onboarding city, and a
  /// stored or history address whose known city differs from it is ignored. [fallbackCenter]
  /// centres the map when no usable address coordinate remains. Without both, behaviour is
  /// the onboarding-city flow used by the profile.
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    Map<String, dynamic>? initialAddress,
    bool openDetailsFirst = false,
    TileProvider? tileProvider,
    Future<AddressLocateResult> Function()? locate,
    String? detailsConfirmButtonLabel,
    String? city,
    ({double lat, double lon})? fallbackCenter,
  }) async {
    final scopedCity = _cleanCity(city);
    var prefill =
        initialAddress ?? await AddressStorageService.getSelectedAddress();
    if (!context.mounted) return null;
    if (prefill != null && _isOtherCity(prefill, scopedCity)) prefill = null;
    if (openDetailsFirst &&
        prefill != null &&
        AddressStorageService.coordinates(prefill) != null &&
        _label(prefill).isNotEmpty) {
      final current = prefill;
      Map<String, dynamic> mapPrefill = current;
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
            builder: (_) => AddressDetailsPage(
                  address: _label(current),
                  city: _cityOf(current),
                  initialEntrance: current['entrance']?.toString() ?? '',
                  initialFloor: current['floor']?.toString() ?? '',
                  initialApartment: current['apartment']?.toString() ?? '',
                  confirmButtonLabel:
                      detailsConfirmButtonLabel ?? 'Сохранить адрес',
                  onChangeAddress: (detailsContext) async {
                    final selected = await _showMap(
                      detailsContext,
                      initialAddress: mapPrefill,
                      tileProvider: tileProvider,
                      locate: locate,
                      collectDetails: false,
                      city: scopedCity,
                      fallbackCenter: fallbackCenter,
                    );
                    if (selected != null) mapPrefill = selected;
                    return selected;
                  },
                )),
      );
      if (result == null) return null;
      final changed = result['_selectedAddress'];
      if (changed is Map) return Map<String, dynamic>.from(changed);
      return {
        ...current,
        'address': _label(current),
        ...result,
      };
    }
    return _showMap(context,
        initialAddress: prefill,
        tileProvider: tileProvider,
        locate: locate,
        detailsConfirmButtonLabel: detailsConfirmButtonLabel,
        city: scopedCity,
        fallbackCenter: fallbackCenter);
  }

  static Future<Map<String, dynamic>?> _showMap(
    BuildContext context, {
    Map<String, dynamic>? initialAddress,
    TileProvider? tileProvider,
    Future<AddressLocateResult> Function()? locate,
    bool collectDetails = true,
    String? detailsConfirmButtonLabel,
    String? city,
    ({double lat, double lon})? fallbackCenter,
  }) async {
    final center = await _initialCenter(initialAddress, city, fallbackCenter);
    if (!context.mounted) return null;
    return Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
          builder: (_) => MapAddressPage(
                initialLat: center.lat,
                initialLon: center.lon,
                initialAddress: initialAddress,
                tileProvider: tileProvider,
                locate: locate,
                collectDetails: collectDetails,
                city: city,
                detailsConfirmButtonLabel:
                    detailsConfirmButtonLabel ?? 'Подтвердить и выбрать адрес',
              )),
    );
  }

  static String? _cleanCity(String? city) {
    final trimmed = city?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _cityOf(Map<String, dynamic> address) =>
      _cleanCity(address['city']?.toString());

  /// True when [address] names a city and it is not [city]. An address without a known city is
  /// kept: older saved addresses carry none and the reverse lookup resolves them anyway.
  static bool _isOtherCity(Map<String, dynamic> address, String? city) {
    if (city == null) return false;
    final known = _cityOf(address);
    return known != null && !sameAddressCity(known, city);
  }

  static String _label(Map<String, dynamic> address) {
    final label =
        (address['address'] ?? address['name'])?.toString().trim() ?? '';
    if (label.isNotEmpty) return label;
    return [address['street'], address['house']]
        .where(
            (part) => part != null && '$part'.trim().isNotEmpty && part != '-')
        .join(', ');
  }

  static Future<CityMapCenter> _initialCenter(
    Map<String, dynamic>? address,
    String? city,
    ({double lat, double lon})? fallbackCenter,
  ) async {
    CityMapCenter? usable(Map<String, dynamic>? candidate) {
      if (candidate == null || _isOtherCity(candidate, city)) return null;
      final point = AddressStorageService.coordinates(candidate);
      return point == null ? null : CityMapCenter(lat: point.$1, lon: point.$2);
    }

    final initial = usable(address);
    if (initial != null) return initial;
    final selected = usable(await AddressStorageService.getSelectedAddress());
    if (selected != null) return selected;
    for (final stored in await AddressStorageService.getAddressHistory()) {
      final point = usable(stored);
      if (point != null) return point;
    }
    if (fallbackCenter != null) {
      return CityMapCenter(lat: fallbackCenter.lat, lon: fallbackCenter.lon);
    }
    final centreCity = city ?? await OnboardingService.getSelectedCity();
    return OnboardingService.getCityCenter(centreCity) ??
        const CityMapCenter(lat: 43.2220, lon: 76.8512);
  }
}
