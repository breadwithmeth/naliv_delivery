import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../pages/map_address_page.dart';
import '../services/onboarding_service.dart';
import '../utils/address_storage_service.dart';

class AddressSelectionModalHelper {
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    Map<String, dynamic>? initialAddress,
    bool openDetailsFirst = false,
    TileProvider? tileProvider,
    Future<AddressLocateResult> Function()? locate,
    String? detailsConfirmButtonLabel,
  }) async {
    final prefill =
        initialAddress ?? await AddressStorageService.getSelectedAddress();
    if (!context.mounted) return null;
    if (openDetailsFirst &&
        prefill != null &&
        AddressStorageService.coordinates(prefill) != null &&
        _label(prefill).isNotEmpty) {
      Map<String, dynamic> mapPrefill = prefill;
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
            builder: (_) => AddressDetailsPage(
                  address: _label(prefill),
                  initialEntrance: prefill['entrance']?.toString() ?? '',
                  initialFloor: prefill['floor']?.toString() ?? '',
                  initialApartment: prefill['apartment']?.toString() ?? '',
                  confirmButtonLabel:
                      detailsConfirmButtonLabel ?? 'Сохранить адрес',
                  onChangeAddress: (detailsContext) async {
                    final selected = await _showMap(
                      detailsContext,
                      initialAddress: mapPrefill,
                      tileProvider: tileProvider,
                      locate: locate,
                      collectDetails: false,
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
        ...prefill,
        'address': _label(prefill),
        ...result,
      };
    }
    return _showMap(context,
        initialAddress: prefill,
        tileProvider: tileProvider,
        locate: locate,
        detailsConfirmButtonLabel: detailsConfirmButtonLabel);
  }

  static Future<Map<String, dynamic>?> _showMap(
    BuildContext context, {
    Map<String, dynamic>? initialAddress,
    TileProvider? tileProvider,
    Future<AddressLocateResult> Function()? locate,
    bool collectDetails = true,
    String? detailsConfirmButtonLabel,
  }) async {
    final center = await _initialCenter(initialAddress);
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
                detailsConfirmButtonLabel:
                    detailsConfirmButtonLabel ?? 'Подтвердить и выбрать адрес',
              )),
    );
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
      Map<String, dynamic>? address) async {
    final initial =
        address == null ? null : AddressStorageService.coordinates(address);
    if (initial != null) return CityMapCenter(lat: initial.$1, lon: initial.$2);
    final selected = await AddressStorageService.getSelectedAddress();
    final selectedPoint =
        selected == null ? null : AddressStorageService.coordinates(selected);
    if (selectedPoint != null) {
      return CityMapCenter(lat: selectedPoint.$1, lon: selectedPoint.$2);
    }
    final history = await AddressStorageService.getAddressHistory();
    for (final address in history) {
      final point = AddressStorageService.coordinates(address);
      if (point != null) return CityMapCenter(lat: point.$1, lon: point.$2);
    }
    final city = await OnboardingService.getSelectedCity();
    return OnboardingService.getCityCenter(city) ??
        const CityMapCenter(lat: 43.2220, lon: 76.8512);
  }
}
