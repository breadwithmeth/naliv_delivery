import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/design/tokens.dart';
import 'package:naliv_delivery/design/typography.dart';
import 'package:naliv_delivery/services/notification_service.dart';
import 'package:naliv_delivery/services/onboarding_service.dart';
import 'package:naliv_delivery/ui/app_states.dart';
import 'package:naliv_delivery/ui/app_icon.dart';
import 'package:naliv_delivery/ui/surfaces.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/utils/location_service.dart';

class OnboardingActions {
  const OnboardingActions({
    this.requestLocationPermission,
    this.locate,
    this.enableNotifications,
    this.locationSupported,
    this.notificationsSupported,
  });

  final Future<LocationPermissionResult> Function()? requestLocationPermission;
  final Future<Position?> Function()? locate;
  final Future<bool> Function()? enableNotifications;
  final bool? locationSupported;
  final bool? notificationsSupported;
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.onCompleted,
    this.initialCity,
    this.actions,
  });

  final VoidCallback onCompleted;
  final String? initialCity;
  final OnboardingActions? actions;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final LocationService _locationService = LocationService.instance;
  int _cityRevision = 0;
  int _locationRevision = 0;
  List<OnboardingCity> _cities = const [];
  String? _selectedCity;
  bool _loadingCities = true;
  bool _citiesFailed = false;
  bool _citiesStale = false;
  bool _saving = false;
  bool _locating = false;
  String? _locationMessage;
  String? _saveError;

  bool get _locationSupported =>
      widget.actions?.locationSupported ??
      (kIsWeb ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  bool get _notificationsSupported =>
      widget.actions?.notificationsSupported ??
      (kIsWeb ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _validSelection => _cities.any((city) => city.name == _selectedCity);

  @override
  void initState() {
    super.initState();
    _selectedCity = widget.initialCity;
    _loadCities();
  }

  @override
  void dispose() {
    _cityRevision++;
    _locationRevision++;
    super.dispose();
  }

  Future<void> _loadCities() async {
    final revision = ++_cityRevision;
    setState(() => _loadingCities = true);
    final result = await OnboardingService.loadAvailableCities();
    if (!mounted || revision != _cityRevision) return;
    setState(() {
      _cities = result.cities;
      _citiesFailed = result.failed;
      _citiesStale = result.isStale;
      _loadingCities = false;
      if (!_validSelection) _selectedCity = null;
      // One city needs no choice.
      if (_selectedCity == null && _cities.length == 1) {
        _selectedCity = _cities.single.name;
      }
    });
  }

  void _selectCity(String city) {
    if (_saving) return;
    setState(() {
      _locationRevision++;
      _locating = false;
      _selectedCity = city;
      _saveError = null;
    });
  }

  /// Finds the customer's city on request; the city stays a manual choice.
  Future<void> _locateCity() async {
    if (_saving || _locating || !_locationSupported) return;
    final revision = ++_locationRevision;
    setState(() {
      _locating = true;
      _locationMessage = null;
    });
    bool current() => mounted && revision == _locationRevision;
    try {
      final result = await (widget.actions?.requestLocationPermission?.call() ??
          _locationService.checkAndRequestPermissions());
      if (!current()) return;
      await OnboardingService.markLocationPromptSeen();
      if (!current()) return;
      if (!result.success) {
        setState(() => _locationMessage =
            'Нет доступа к геолокации. Выберите город в списке.');
        return;
      }
      final position = await (widget.actions?.locate?.call() ??
          _locationService.getCurrentPosition(
            permissionResult: result,
            accuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 10),
          ));
      if (!current()) return;
      final addresses = position == null
          ? null
          : await ApiService.searchAddresses(
              lat: position.latitude,
              lon: position.longitude,
            ).timeout(const Duration(seconds: 10));
      if (!current()) return;
      OnboardingCity? matched;
      for (final address in addresses ?? const <Map<String, dynamic>>[]) {
        final name = ApiService.extractCityName(address)?.toLowerCase();
        matched = _cities
            .where((city) => city.name.toLowerCase() == name)
            .firstOrNull;
        if (matched != null) break;
      }
      setState(() {
        if (matched == null) {
          _locationMessage =
              'Не удалось определить город. Выберите его в списке.';
        } else {
          _selectedCity = matched.name;
          _locationMessage = null;
        }
      });
    } catch (_) {
      if (!current()) return;
      setState(() => _locationMessage =
          'Не удалось определить город. Выберите его в списке.');
    } finally {
      if (current()) setState(() => _locating = false);
    }
  }

  /// Saves the city and finishes. Notifications are on by default; the system
  /// is asked once for permission to show them, right on this tap.
  Future<void> _continue() async {
    if (_saving || _loadingCities || !_validSelection) return;
    final city = _selectedCity!;
    if (_notificationsSupported) {
      // Started inside the tap, so a browser accepts the permission prompt.
      // A refused or failed request never blocks onboarding.
      try {
        final request = widget.actions?.enableNotifications?.call() ??
            NotificationService.instance.enablePushNotifications();
        unawaited(request.catchError((Object _) => false));
      } catch (_) {}
    }
    setState(() {
      _saving = true;
      _saveError = null;
      _locationRevision++;
      _locating = false;
    });
    try {
      await OnboardingService.setSelectedCity(city);
      await OnboardingService.markNotificationPromptSeen();
      await OnboardingService.complete(city: city);
      if (!mounted) return;
      widget.onCompleted();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Не удалось сохранить город. Попробуйте ещё раз.';
      });
    }
  }

  Widget _message(String message, {bool error = false}) {
    final palette = context.palette;
    return Semantics(
      liveRegion: true,
      child: Text(
        message,
        style: AppTypography.body.copyWith(
          color: error ? palette.error : palette.textSecondary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                          AppSpacing.huge, AppSpacing.gutter, AppSpacing.xxxl),
                      children: [
                        Center(
                          child: AppIcon(AppIcons.wordmark,
                              width: 164, height: 36, color: palette.accent),
                        ),
                        const SizedBox(height: AppSpacing.huge),
                        Text('Ваш город', style: AppTypography.headline),
                        const SizedBox(height: AppSpacing.xl),
                        if (_loadingCities) ...[
                          const LinearProgressIndicator(),
                          const SizedBox(height: AppSpacing.xxxl),
                        ],
                        if (!_loadingCities && _cities.isEmpty)
                          AppEmptyState(
                            key: ValueKey(_citiesFailed
                                ? 'onboarding-cities-error'
                                : 'onboarding-cities-empty'),
                            title: _citiesFailed
                                ? 'Не удалось загрузить города'
                                : 'Доступных городов пока нет',
                            subtitle: _citiesFailed
                                ? 'Проверьте подключение и повторите.'
                                : 'Попробуйте обновить список позже.',
                            action: OutlinedButton(
                              key: const ValueKey('onboarding-retry-cities'),
                              onPressed: _loadCities,
                              child: const Text('Обновить список'),
                            ),
                          ),
                        if (_citiesStale && _cities.isNotEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              key: const ValueKey('onboarding-retry-cities'),
                              onPressed: _loadingCities ? null : _loadCities,
                              child:
                                  const Text('Список мог устареть · обновить'),
                            ),
                          ),
                        RadioGroup<String>(
                          groupValue: _selectedCity,
                          onChanged: (city) {
                            if (city != null && !_saving && !_loadingCities) {
                              _selectCity(city);
                            }
                          },
                          child: Column(
                            children: [
                              for (final city in _cities) ...[
                                AppSurface(
                                  fill: city.name == _selectedCity
                                      ? Color.alphaBlend(
                                          palette.accentFaint, palette.surface)
                                      : palette.surface,
                                  radius: AppRadii.lg,
                                  clip: true,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: RadioListTile<String>(
                                      key: ValueKey(
                                          'onboarding-city-${city.id}'),
                                      value: city.name,
                                      enabled: !_saving && !_loadingCities,
                                      activeColor: palette.accent,
                                      title: Text(city.name,
                                          style: AppTypography.titleMedium),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                        vertical: AppSpacing.xs,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                              ],
                            ],
                          ),
                        ),
                        if (_locationSupported && _cities.length > 1)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              key: const ValueKey('onboarding-location'),
                              onPressed:
                                  _saving || _locating ? null : _locateCity,
                              icon: const Icon(Icons.my_location_rounded,
                                  size: 18),
                              label: Text(_locating
                                  ? 'Определяем…'
                                  : 'Определить мой город'),
                            ),
                          ),
                        if (_locationMessage != null)
                          _message(_locationMessage!),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        AppSpacing.gutter,
                        AppSpacing.md,
                        AppSpacing.gutter,
                        AppSpacing.xl + bottom),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_saveError != null) ...[
                          _message(_saveError!, error: true),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        FilledButton(
                          key: const ValueKey('onboarding-continue'),
                          onPressed:
                              _saving || _loadingCities || !_validSelection
                                  ? null
                                  : _continue,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(_saving ? 'Сохраняем…' : 'Продолжить'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
