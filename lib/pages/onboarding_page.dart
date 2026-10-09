import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/design/tokens.dart';
import 'package:naliv_delivery/design/typography.dart';
import 'package:naliv_delivery/services/notification_service.dart';
import 'package:naliv_delivery/services/onboarding_service.dart';
import 'package:naliv_delivery/services/telemetry_consent_service.dart';
import 'package:naliv_delivery/ui/app_states.dart';
import 'package:naliv_delivery/ui/app_icon.dart';
import 'package:naliv_delivery/ui/app_top_bar.dart';
import 'package:naliv_delivery/ui/surfaces.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/utils/location_service.dart';

class OnboardingActions {
  const OnboardingActions({
    this.requestLocationPermission,
    this.locate,
    this.enableNotifications,
    this.openLocationSettings,
    this.locationSupported,
    this.notificationsSupported,
  });

  final Future<LocationPermissionResult> Function()? requestLocationPermission;
  final Future<Position?> Function()? locate;
  final Future<bool> Function()? enableNotifications;
  final Future<bool> Function()? openLocationSettings;
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
  final ScrollController _scrollController = ScrollController();
  int _step = 0;
  int _cityRevision = 0;
  int _locationRevision = 0;
  int _notificationRevision = 0;
  List<OnboardingCity> _cities = const [];
  String? _selectedCity;
  bool _loadingCities = true;
  bool _citiesFailed = false;
  bool _citiesStale = false;
  bool _loadingConsent = true;
  bool _saving = false;
  bool _locating = false;
  bool _requestingNotifications = false;
  bool _openingSettings = false;
  bool _locationGranted = false;
  bool _notificationsGranted = false;
  bool _locationNeedsSettings = false;
  LocationPermission? _locationPermission;
  bool _shareDiagnostics = false;
  String? _locationMessage;
  String? _notificationMessage;
  String? _saveError;
  String? _consentError;

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

  bool get _canOpenSettings =>
      !kIsWeb || widget.actions?.openLocationSettings != null;

  bool get _validSelection => _cities.any((city) => city.name == _selectedCity);

  @override
  void initState() {
    super.initState();
    _selectedCity = widget.initialCity;
    _loadCities();
    _loadConsent();
  }

  @override
  void dispose() {
    _cityRevision++;
    _locationRevision++;
    _notificationRevision++;
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConsent() async {
    try {
      final consent = await TelemetryConsentService.loadConsent();
      if (!mounted) return;
      setState(() {
        _shareDiagnostics = TelemetryConsentService.hasStoredConsent && consent;
        _loadingConsent = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingConsent = false;
        _consentError = 'Не удалось прочитать настройку диагностики. '
            'При завершении сохраним ваш выбор ниже.';
      });
    }
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
    });
  }

  void _cancelPermissionWork() {
    _locationRevision++;
    _notificationRevision++;
    _locating = false;
    _requestingNotifications = false;
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

  void _back() {
    if (_saving || _step == 0) return;
    setState(() {
      _cancelPermissionWork();
      _step = 0;
      _saveError = null;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  Future<void> _continueCity() async {
    if (_saving || _loadingCities || !_validSelection) return;
    final city = _selectedCity!;
    setState(() {
      _saving = true;
      _saveError = null;
      _cancelPermissionWork();
    });
    try {
      await OnboardingService.setSelectedCity(city);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _step = 1;
      });
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError =
            'Не удалось сохранить город. Попробуйте продолжить ещё раз.';
      });
    }
  }

  Future<void> _requestLocation({required bool determineCity}) async {
    if (_saving || _locating || !_locationSupported) return;
    final revision = ++_locationRevision;
    setState(() {
      _locating = true;
      _locationMessage = null;
      _locationNeedsSettings = false;
    });
    bool current() => mounted && revision == _locationRevision;
    try {
      final result = await (widget.actions?.requestLocationPermission?.call() ??
          _locationService.checkAndRequestPermissions());
      if (!current()) return;
      await OnboardingService.markLocationPromptSeen();
      if (!current()) return;
      setState(() {
        _locationGranted = result.success;
        _locationPermission = result.permissionStatus;
        _locationNeedsSettings = !result.success &&
            (result.needsSettingsRedirect ||
                result.permissionStatus == LocationPermission.deniedForever ||
                !kIsWeb);
        _locationMessage =
            result.success ? 'Доступ к геолокации разрешён.' : result.message;
      });
      if (!result.success || !determineCity) return;

      final position = await (widget.actions?.locate?.call() ??
          _locationService.getCurrentPosition(
            accuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 10),
          ));
      if (!current()) return;
      if (position == null) {
        setState(() => _locationMessage =
            'Доступ разрешён, но координаты получить не удалось. '
                'Выберите город вручную или повторите попытку.');
        return;
      }
      final addresses = await ApiService.searchAddresses(
        lat: position.latitude,
        lon: position.longitude,
      ).timeout(const Duration(seconds: 10));
      if (!current()) return;
      if (addresses == null) {
        setState(() =>
            _locationMessage = 'Не удалось определить город по координатам. '
                'Выберите его вручную или повторите попытку.');
        return;
      }
      OnboardingCity? matched;
      for (final address in addresses) {
        final name = ApiService.extractCityName(address)?.toLowerCase();
        for (final city in _cities) {
          if (city.name.toLowerCase() == name) {
            matched = city;
            break;
          }
        }
        if (matched != null) break;
      }
      if (matched == null) {
        setState(() =>
            _locationMessage = 'В доступных городах не найдено совпадение. '
                'Выберите город из списка вручную.');
      } else if (!_locationService.isAccurateEnoughForAutoSelection(position)) {
        final name = matched.name;
        setState(() => _locationMessage =
            'Похоже, вы в городе $name, но координаты неточные. '
                'Подтвердите город в списке.');
      } else {
        final name = matched.name;
        setState(() {
          _selectedCity = name;
          _locationMessage =
              'Определён город $name. Проверьте выбор и продолжите.';
        });
      }
    } catch (_) {
      if (!current()) return;
      setState(() => _locationMessage =
          'Не удалось получить или сохранить результат геолокации. '
              'Можно повторить попытку или продолжить с городом, выбранным вручную.');
    } finally {
      if (current()) setState(() => _locating = false);
    }
  }

  Future<void> _openSettings() async {
    if (_openingSettings || _saving || !_canOpenSettings) return;
    final revision = _locationRevision;
    setState(() => _openingSettings = true);
    try {
      final opened = await (widget.actions?.openLocationSettings?.call() ??
          (_locationPermission == LocationPermission.deniedForever
              ? _locationService.openAppSettings()
              : _locationService.openLocationSettings()));
      if (!mounted || revision != _locationRevision) return;
      setState(() => _locationMessage = opened
          ? 'Вернитесь из настроек и снова нажмите кнопку геолокации. '
              'Разрешение ещё не проверено.'
          : 'Не удалось открыть настройки. Измените доступ к геолокации '
              'в настройках устройства или выберите город вручную.');
    } catch (_) {
      if (!mounted || revision != _locationRevision) return;
      setState(() => _locationMessage =
          'Не удалось открыть настройки. Можно продолжить без геолокации.');
    } finally {
      if (mounted) setState(() => _openingSettings = false);
    }
  }

  Future<void> _requestNotifications() async {
    if (_saving || _requestingNotifications || !_notificationsSupported) return;
    final revision = ++_notificationRevision;
    setState(() {
      _requestingNotifications = true;
      _notificationMessage = null;
    });
    bool current() => mounted && revision == _notificationRevision;
    try {
      final granted = await (widget.actions?.enableNotifications?.call() ??
          NotificationService.instance.enablePushNotifications());
      if (!current()) return;
      await OnboardingService.markNotificationPromptSeen();
      if (!current()) return;
      setState(() {
        _notificationsGranted = granted;
        _notificationMessage = granted
            ? 'Разрешение на уведомления получено.'
            : 'Уведомления не включены. Доступ может быть запрещён или '
                'недоступен в этом браузере. Можно продолжить без них и '
                'изменить разрешение в настройках позже.';
      });
    } catch (_) {
      if (!current()) return;
      setState(() => _notificationMessage =
          'Не удалось включить уведомления или сохранить результат. '
              'Можно повторить попытку или продолжить без них.');
    } finally {
      if (current()) setState(() => _requestingNotifications = false);
    }
  }

  void _skipLocation() {
    if (_saving) return;
    setState(() {
      _locationRevision++;
      _locating = false;
      _locationMessage =
          'Продолжим с выбранным городом, без запроса геолокации.';
      _locationNeedsSettings = false;
    });
  }

  void _skipNotifications() {
    if (_saving) return;
    setState(() {
      _notificationRevision++;
      _requestingNotifications = false;
      _notificationMessage = 'Продолжим без запроса уведомлений.';
    });
  }

  Future<void> _complete() async {
    if (_saving || _loadingConsent || !_validSelection) return;
    final city = _selectedCity!;
    final consent = _shareDiagnostics;
    setState(() {
      _saving = true;
      _saveError = null;
      _cancelPermissionWork();
    });
    try {
      await TelemetryConsentService.setConsent(consent);
      if (!mounted) return;
      await OnboardingService.markLocationPromptSeen();
      if (!mounted) return;
      await OnboardingService.markNotificationPromptSeen();
      if (!mounted) return;
      await OnboardingService.complete(city: city);
      if (!mounted) return;
      widget.onCompleted();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Не удалось сохранить настройки. '
            'Завершение не подтверждено — попробуйте ещё раз.';
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

  String? _deliveryLabel(OnboardingCity city) {
    switch (city.deliveryType) {
      case 'DISTANCE':
        return 'Доставка по расстоянию';
      case 'AREA':
        return 'Доставка по зоне';
      case null:
      case '':
        return null;
      default:
        return null;
    }
  }

  Widget _locationControl({required bool determineCity}) {
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Геолокация', style: AppTypography.title),
          const SizedBox(height: AppSpacing.md),
          _message(_locationSupported
              ? (determineCity
                  ? 'Определим город только по вашему запросу. '
                      'Также можно выбрать его вручную.'
                  : 'Необязательно. Адрес можно указать вручную при оформлении.')
              : 'Геолокация не поддерживается на этой платформе. '
                  'Выберите город вручную.'),
          if (_locationMessage != null) ...[
            const SizedBox(height: AppSpacing.xl),
            _message(_locationMessage!),
          ],
          if (_locationSupported && (!_locationGranted || determineCity)) ...[
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton(
              key: const ValueKey('onboarding-location'),
              onPressed: _saving || _locating
                  ? null
                  : () => _requestLocation(determineCity: determineCity),
              child: Text(_locating
                  ? 'Определяем…'
                  : determineCity
                      ? 'Определить город'
                      : 'Разрешить геолокацию'),
            ),
          ],
          if (_locationNeedsSettings && _canOpenSettings) ...[
            const SizedBox(height: AppSpacing.md),
            TextButton(
              key: const ValueKey('onboarding-location-settings'),
              onPressed: _saving || _openingSettings ? null : _openSettings,
              child:
                  Text(_openingSettings ? 'Открываем…' : 'Открыть настройки'),
            ),
          ],
          if (!determineCity && !_locationGranted)
            TextButton(
              key: const ValueKey('onboarding-skip-location'),
              onPressed: _saving ? null : _skipLocation,
              child: const Text('Без геолокации'),
            ),
        ],
      ),
    );
  }

  Widget _cityStep() {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Выберите город', style: AppTypography.headline),
        const SizedBox(height: AppSpacing.xl),
        _message('Покажем магазины в выбранном городе. '
            'Точный адрес можно добавить позже.'),
        const SizedBox(height: AppSpacing.huge),
        if (_loadingCities) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: AppSpacing.xl),
          _message('Обновляем доступные города…'),
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
                ? 'Проверьте подключение и повторите запрос.'
                : 'Сервис пока не вернул города для выбора. '
                    'Попробуйте обновить список позже.',
            action: OutlinedButton(
              key: const ValueKey('onboarding-retry-cities'),
              onPressed: _loadCities,
              child: const Text('Обновить список'),
            ),
          ),
        if (_citiesStale && _cities.isNotEmpty) ...[
          _message('Не удалось обновить список. Показаны ранее загруженные '
              'города — их доступность могла измениться.'),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('onboarding-retry-cities'),
              onPressed: _loadingCities ? null : _loadCities,
              child: const Text('Повторить запрос'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        RadioGroup<String>(
          groupValue: _selectedCity,
          onChanged: (city) {
            if (city != null && !_saving && !_loadingCities) _selectCity(city);
          },
          child: Column(
            children: [
              for (final city in _cities) ...[
                AppGlassPanel(
                  tint: city.name == _selectedCity
                      ? palette.accentFaint
                      : palette.surface.withValues(alpha: .75),
                  radius: AppRadii.lg,
                  child: RadioListTile<String>(
                    key: ValueKey('onboarding-city-${city.id}'),
                    value: city.name,
                    enabled: !_saving && !_loadingCities,
                    activeColor: palette.accent,
                    title: Text(city.name, style: AppTypography.titleMedium),
                    subtitle: _deliveryLabel(city) == null
                        ? null
                        : Text(_deliveryLabel(city)!,
                            style: AppTypography.body),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxxl),
        _locationControl(determineCity: true),
        const SizedBox(height: AppSpacing.huge),
        if (_saveError != null) ...[
          _message(_saveError!, error: true),
          const SizedBox(height: AppSpacing.xl),
        ],
        AppGlassPanel(
          radius: AppRadii.pill,
          tint: palette.accentSoft,
          child: TextButton(
            key: const ValueKey('onboarding-continue'),
            onPressed: _saving || _loadingCities || !_validSelection
                ? null
                : _continueCity,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              foregroundColor: Colors.black,
            ),
            child: Text(_saving ? 'Сохраняем…' : 'Продолжить',
                style: AppTypography.titleMedium),
          ),
        ),
      ],
    );
  }

  Widget _permissionsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Настройте приложение', style: AppTypography.headline),
        const SizedBox(height: AppSpacing.xl),
        _message('Город: $_selectedCity. Все разрешения необязательны.'),
        const SizedBox(height: AppSpacing.huge),
        _locationControl(determineCity: false),
        const SizedBox(height: AppSpacing.xxxl),
        AppSurface(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Уведомления', style: AppTypography.title),
              const SizedBox(height: AppSpacing.md),
              _message(_notificationsSupported
                  ? 'Можно разрешить уведомления о заказах. '
                      'Отказ не мешает пользоваться приложением.'
                  : 'Push-уведомления не поддерживаются на этой платформе. '
                      'Продолжите без них.'),
              if (_notificationMessage != null) ...[
                const SizedBox(height: AppSpacing.xl),
                _message(_notificationMessage!),
              ],
              if (_notificationsSupported && !_notificationsGranted) ...[
                const SizedBox(height: AppSpacing.xl),
                OutlinedButton(
                  key: const ValueKey('onboarding-notifications'),
                  onPressed: _saving || _requestingNotifications
                      ? null
                      : _requestNotifications,
                  child: Text(_requestingNotifications
                      ? 'Запрашиваем…'
                      : 'Разрешить уведомления'),
                ),
              ],
              if (!_notificationsGranted)
                TextButton(
                  key: const ValueKey('onboarding-skip-notifications'),
                  onPressed: _saving ? null : _skipNotifications,
                  child: const Text('Без уведомлений'),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxxl),
        Material(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          clipBehavior: Clip.antiAlias,
          child: CheckboxListTile(
            key: const ValueKey('onboarding-telemetry'),
            value: _shareDiagnostics,
            onChanged: _saving || _loadingConsent
                ? null
                : (value) => setState(() => _shareDiagnostics = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title:
                Text('Помочь улучшить приложение', style: AppTypography.title),
            subtitle: Text(
              'Отправлять отчёты об ошибках. Выбор сохранится при завершении; '
              'его можно изменить в настройках.',
              style: AppTypography.body,
            ),
            contentPadding: const EdgeInsets.all(AppSpacing.xl),
          ),
        ),
        if (_consentError != null) ...[
          const SizedBox(height: AppSpacing.xl),
          _message(_consentError!),
        ],
        if (_saveError != null) ...[
          const SizedBox(height: AppSpacing.xl),
          _message(_saveError!, error: true),
        ],
        const SizedBox(height: AppSpacing.huge),
        AppGlassPanel(
          radius: AppRadii.pill,
          tint: context.palette.accentSoft,
          child: TextButton(
            key: const ValueKey('onboarding-complete'),
            onPressed: _saving || _loadingConsent ? null : _complete,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              foregroundColor: Colors.black,
            ),
            child: Text(_saving ? 'Сохраняем…' : 'Начать пользоваться',
                style: AppTypography.titleMedium),
          ),
        ),
        TextButton(
          key: const ValueKey('onboarding-back'),
          onPressed: _saving ? null : _back,
          child: const Text('Изменить город'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0 && !_saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: FocusTraversalGroup(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    0,
                    AppSpacing.gutter,
                    AppSpacing.huge,
                  ),
                  children: [
                    AppTopBar(
                      title: _step == 0 ? 'Ваш город' : 'Разрешения',
                      showBack: _step == 1,
                      backEnabled: !_saving,
                      onBack: _saving ? null : _back,
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    Center(
                      child: AppIcon(
                        AppIcons.wordmark,
                        width: 164,
                        height: 36,
                        color: context.palette.accent,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.huge),
                    Semantics(
                      label: 'Шаг ${_step + 1} из 2',
                      child: Text(
                        'Шаг ${_step + 1} из 2',
                        style: AppTypography.body.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    if (_step == 0) _cityStep() else _permissionsStep(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
