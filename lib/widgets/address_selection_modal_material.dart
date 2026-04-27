import 'package:flutter/material.dart';

import '../pages/map_address_page.dart';
import '../services/onboarding_service.dart';
import '../utils/address_storage_service.dart';

class AddressSelectionModalHelper {
  static Future<Map<String, dynamic>?> show(BuildContext context, {Map<String, dynamic>? initialAddress}) async {
    final initialCenter = await _resolveInitialCenter(initialAddress: initialAddress);
    final prefillAddress = initialAddress ?? await AddressStorageService.getSelectedAddress();
    if (!context.mounted) return null;

    return Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => MapAddressPage(
          initialLat: initialCenter.lat,
          initialLon: initialCenter.lon,
          initialAddress: prefillAddress,
        ),
      ),
    );
  }

  static Future<CityMapCenter> _resolveInitialCenter({Map<String, dynamic>? initialAddress}) async {
    try {
      if (initialAddress != null && initialAddress['lat'] != null && initialAddress['lon'] != null) {
        return CityMapCenter(
          lat: (initialAddress['lat'] as num).toDouble(),
          lon: (initialAddress['lon'] as num).toDouble(),
        );
      }

      final selected = await AddressStorageService.getSelectedAddress();
      if (selected != null && selected['lat'] != null && selected['lon'] != null) {
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
    return OnboardingService.getCityCenter(selectedCity) ?? const CityMapCenter(lat: 43.2220, lon: 76.8512);
  }
}
