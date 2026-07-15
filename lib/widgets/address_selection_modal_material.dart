import 'package:flutter/material.dart';

import '../pages/map_address_page.dart';
import '../services/onboarding_service.dart';
import '../utils/address_storage_service.dart';

class AddressSelectionModalHelper {
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    Map<String, dynamic>? initialAddress,
    bool openDetailsFirst = false,
  }) async {
    final prefillAddress =
        initialAddress ?? await AddressStorageService.getSelectedAddress();
    if (!context.mounted) return null;

    if (openDetailsFirst &&
        prefillAddress != null &&
        _addressLabel(prefillAddress).isNotEmpty) {
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (_) => AddressDetailsPage(
            address: _addressLabel(prefillAddress),
            initialEntrance: prefillAddress['entrance']?.toString() ?? '',
            initialFloor: prefillAddress['floor']?.toString() ?? '',
            initialApartment: prefillAddress['apartment']?.toString() ?? '',
            confirmButtonLabel: 'Сохранить адрес',
            onChangeAddress: (detailsContext) =>
                _showMap(detailsContext, initialAddress: prefillAddress),
          ),
        ),
      );

      if (result == null) return null;
      final changedAddress = result['_selectedAddress'];
      if (changedAddress is Map) {
        return Map<String, dynamic>.from(changedAddress);
      }
      return <String, dynamic>{...prefillAddress, ...result};
    }

    return _showMap(context, initialAddress: prefillAddress);
  }

  static Future<Map<String, dynamic>?> _showMap(
    BuildContext context, {
    Map<String, dynamic>? initialAddress,
  }) async {
    final initialCenter =
        await _resolveInitialCenter(initialAddress: initialAddress);
    if (!context.mounted) return null;

    return Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => MapAddressPage(
          initialLat: initialCenter.lat,
          initialLon: initialCenter.lon,
          initialAddress: initialAddress,
        ),
      ),
    );
  }

  static String _addressLabel(Map<String, dynamic> address) {
    final label = address['address']?.toString().trim() ?? '';
    if (label.isNotEmpty) return label;

    final street = address['street']?.toString().trim() ?? '';
    final house = address['house']?.toString().trim() ?? '';
    return <String>[street, house]
        .where((part) => part.isNotEmpty && part != '-')
        .join(', ');
  }

  static Future<CityMapCenter> _resolveInitialCenter(
      {Map<String, dynamic>? initialAddress}) async {
    try {
      if (initialAddress != null &&
          initialAddress['lat'] != null &&
          initialAddress['lon'] != null) {
        return CityMapCenter(
          lat: (initialAddress['lat'] as num).toDouble(),
          lon: (initialAddress['lon'] as num).toDouble(),
        );
      }

      final selected = await AddressStorageService.getSelectedAddress();
      if (selected != null &&
          selected['lat'] != null &&
          selected['lon'] != null) {
        return CityMapCenter(
          lat: (selected['lat'] as num).toDouble(),
          lon: (selected['lon'] as num).toDouble(),
        );
      }

      final history = await AddressStorageService.getAddressHistory();
      if (history.isNotEmpty && history.first['point'] != null) {
        final point = history.first['point'];
        if (point['lat'] != null && point['lon'] != null) {
          return CityMapCenter(
            lat: (point['lat'] as num).toDouble(),
            lon: (point['lon'] as num).toDouble(),
          );
        }
      }
    } catch (_) {}

    final selectedCity = await OnboardingService.getSelectedCity();
    return OnboardingService.getCityCenter(selectedCity) ??
        const CityMapCenter(lat: 43.2220, lon: 76.8512);
  }
}
