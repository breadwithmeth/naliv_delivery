import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../services/onboarding_service.dart';
import '../ui/app_icon.dart';
import '../ui/app_icon_button.dart';
import '../ui/app_states.dart';
import '../ui/app_top_bar.dart';
import '../ui/surfaces.dart';
import '../utils/address_storage_service.dart';
import '../utils/api.dart';
import '../utils/location_service.dart';

class AddressLocateResult {
  const AddressLocateResult.found(LatLng this.point)
      : message = null,
        needsAppSettings = false,
        needsLocationSettings = false;

  const AddressLocateResult.unavailable({
    required String this.message,
    this.needsAppSettings = false,
    this.needsLocationSettings = false,
  }) : point = null;

  final LatLng? point;
  final String? message;
  final bool needsAppSettings;
  final bool needsLocationSettings;
}

/// Compares two city names the way addresses spell them: case, punctuation and a leading
/// «г.» / «город» do not matter. Null or blank names never match.
bool sameAddressCity(String? a, String? b) {
  final left = _cityKey(a);
  final right = _cityKey(b);
  return left.isNotEmpty && left == right;
}

String _cityKey(String? value) {
  var key = (value ?? '')
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();
  for (final prefix in const ['город ', 'г ']) {
    if (key.startsWith(prefix)) key = key.substring(prefix.length).trim();
  }
  return key;
}

class MapAddressPage extends StatefulWidget {
  const MapAddressPage({
    super.key,
    required this.initialLat,
    required this.initialLon,
    this.initialAddress,
    this.tileProvider,
    this.locate,
    this.collectDetails = true,
    this.city,
    this.detailsConfirmButtonLabel = 'Подтвердить и выбрать адрес',
  });

  final double initialLat;
  final double initialLon;
  final Map<String, dynamic>? initialAddress;
  final TileProvider? tileProvider;
  final Future<AddressLocateResult> Function()? locate;
  final bool collectDetails;

  /// Scopes reverse lookup, search and label extraction to one city (checkout passes the
  /// store's city). Null keeps the onboarding city.
  final String? city;
  final String detailsConfirmButtonLabel;

  @override
  State<MapAddressPage> createState() => _MapAddressPageState();
}

class _MapAddressPageState extends State<MapAddressPage> {
  final MapController _mapController = MapController();
  late final TileProvider _tileProvider;
  final LocationService _locationService = LocationService.instance;
  late LatLng _center;
  String? _selectedCity;
  String? _addressLabel;
  Map<String, dynamic>? _resolvedAddress;
  String? _resolveError;
  bool _resolving = true;
  bool _locating = false;
  bool _openingDetails = false;
  int _requestId = 0;
  int _selectionRevision = 0;
  Timer? _reverseDebounce;
  late String _entrance;
  late String _floor;
  late String _apartment;

  /// True when the caller scopes every lookup to one city; otherwise the onboarding city is used.
  bool get _cityScoped => widget.city?.trim().isNotEmpty ?? false;

  @override
  void initState() {
    super.initState();
    _tileProvider = widget.tileProvider ?? NetworkTileProvider();
    _center = LatLng(widget.initialLat, widget.initialLon);
    _entrance = widget.initialAddress?['entrance']?.toString() ?? '';
    _floor = widget.initialAddress?['floor']?.toString() ?? '';
    _apartment = widget.initialAddress?['apartment']?.toString() ?? '';
    _initialize();
  }

  Future<void> _initialize() async {
    final revision = _selectionRevision;
    try {
      if (_cityScoped) {
        _selectedCity = widget.city!.trim();
        await null;
      } else {
        _selectedCity = await OnboardingService.getSelectedCity();
      }
      if (!mounted || revision != _selectionRevision) return;
      await _reverse(_center);
    } catch (_) {
      if (!mounted || revision != _selectionRevision) return;
      setState(() {
        _resolving = false;
        _resolveError =
            'Не удалось загрузить выбранный город. Попробуйте снова.';
      });
    }
  }

  @override
  void dispose() {
    _reverseDebounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _reverse(LatLng point, {bool fromDevice = false}) async {
    final request = ++_requestId;
    setState(() {
      _resolving = true;
      _resolvedAddress = null;
      _addressLabel = null;
      _resolveError = null;
    });
    try {
      final result = await ApiService.searchAddresses(
        lat: point.latitude,
        lon: point.longitude,
        city: _selectedCity,
      );
      if (!mounted || request != _requestId) return;
      if (result == null) throw StateError('Не удалось определить адрес');
      Map<String, dynamic>? resolved;
      String? label;
      for (final item in result) {
        final candidate =
            ApiService.extractAddressLabel(item, preferredCity: _selectedCity);
        if (ApiService.isKazakhstanAddress(item) &&
            candidate != null &&
            candidate.trim().isNotEmpty) {
          resolved = item;
          label = candidate;
          break;
        }
      }
      String? error;
      if (resolved == null) {
        final outside = fromDevice && await _isOutsideCity(point);
        if (!mounted || request != _requestId) return;
        error = outside ? _outsideCityMessage : _notFoundMessage;
      }
      setState(() {
        _resolvedAddress = resolved;
        _addressLabel = label;
        _resolveError = error;
        _resolving = false;
      });
    } catch (_) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _resolving = false;
        _resolveError =
            'Не удалось определить адрес. Проверьте соединение и попробуйте снова.';
      });
    }
  }

  /// Whether the geocoder places [point] in a city other than the scoped one. Only asked after
  /// a device fix found nothing in the scoped city, so the common path costs no extra request.
  Future<bool> _isOutsideCity(LatLng point) async {
    final city = _selectedCity;
    if (city == null || city.trim().isEmpty) return false;
    try {
      final unscoped = await ApiService.searchAddressByCoordinates(
          point.latitude, point.longitude);
      for (final item in unscoped ?? const <Map<String, dynamic>>[]) {
        final actual = ApiService.extractCityName(item);
        if (ApiService.isKazakhstanAddress(item) &&
            actual != null &&
            !sameAddressCity(actual, city)) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  String get _notFoundMessage {
    final city = _selectedCity;
    return city == null || city.trim().isEmpty
        ? 'Адрес здесь не найден. Передвиньте карту или воспользуйтесь поиском.'
        : 'В г. $city здесь адрес не найден. Передвиньте карту или воспользуйтесь поиском.';
  }

  String get _outsideCityMessage {
    final city = _selectedCity ?? '';
    return _cityScoped
        ? 'Вы сейчас не в г. $city. Магазин доставляет только по г. $city — найдите адрес поиском или передвиньте карту.'
        : 'Вы сейчас не в г. $city. Найдите адрес поиском или передвиньте карту.';
  }

  void _mapMoved(LatLng point) {
    _reverseDebounce?.cancel();
    ++_selectionRevision;
    ++_requestId;
    setState(() {
      _center = point;
      _resolvedAddress = null;
      _addressLabel = null;
      _resolveError = null;
      _resolving = true;
    });
    _reverseDebounce =
        Timer(const Duration(milliseconds: 350), () => _reverse(point));
  }

  Future<void> _openSearch() async {
    final revision = ++_selectionRevision;
    final selected = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
          builder: (_) => AddressSearchPage(selectedCity: _selectedCity)),
    );
    if (!mounted || revision != _selectionRevision || selected == null) return;
    final coordinates = AddressStorageService.coordinates(selected);
    final raw = selected['rawAddress'];
    final label = selected['label']?.toString().trim();
    if (coordinates == null || raw is! Map || label == null || label.isEmpty) {
      return;
    }
    _reverseDebounce?.cancel();
    ++_requestId;
    final point = LatLng(coordinates.$1, coordinates.$2);
    _mapController.move(point, 17);
    setState(() {
      _center = point;
      _resolvedAddress = Map<String, dynamic>.from(raw);
      _addressLabel = label;
      _resolveError = null;
      _resolving = false;
    });
  }

  Future<AddressLocateResult> _locateDevice() async {
    final permission = await _locationService.checkAndRequestPermissions();
    if (!permission.serviceEnabled) {
      return AddressLocateResult.unavailable(
        message: _locationService.isIosBrowserLocationFlow
            ? _locationService.browserLocationSettingsInstructions()
            : permission.message,
        needsLocationSettings: !_locationService.isIosBrowserLocationFlow,
      );
    }
    if (!permission.success) {
      return AddressLocateResult.unavailable(
        message: permission.message,
        needsAppSettings: permission.needsSettingsRedirect,
      );
    }
    final position = await _locationService.getCurrentPosition(
      permissionResult: permission,
      timeLimit: const Duration(seconds: 10),
    );
    if (position == null) {
      return const AddressLocateResult.unavailable(
          message:
              'Не удалось определить местоположение. Попробуйте снова или найдите адрес вручную.');
    }
    return AddressLocateResult.found(
        LatLng(position.latitude, position.longitude));
  }

  Future<void> _locate() async {
    if (_locating) return;
    final revision = _selectionRevision;
    setState(() => _locating = true);
    try {
      final result = await (widget.locate?.call() ?? _locateDevice());
      if (!mounted || revision != _selectionRevision) return;
      final point = result.point;
      if (point != null &&
          point.latitude.isFinite &&
          point.longitude.isFinite &&
          point.latitude.abs() <= 90 &&
          point.longitude.abs() <= 180) {
        _reverseDebounce?.cancel();
        _mapController.move(point, 16.5);
        setState(() => _center = point);
        await _reverse(point, fromDevice: true);
      } else {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Местоположение недоступно'),
            content: Text(result.message ??
                'Найдите адрес через поиск или выберите точку на карте.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Понятно'),
              ),
              if (result.needsAppSettings || result.needsLocationSettings)
                TextButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    final opened = result.needsLocationSettings
                        ? await _locationService.openLocationSettings()
                        : await _locationService.openAppSettings();
                    if (!opened && mounted && revision == _selectionRevision) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Не удалось открыть настройки. Откройте их на устройстве вручную.'),
                      ));
                    }
                  },
                  child: const Text('Открыть настройки'),
                ),
            ],
          ),
        );
      }
    } catch (_) {
      if (mounted && revision == _selectionRevision) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Местоположение недоступно. Используйте поиск или карту.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _confirm() async {
    final resolved = _resolvedAddress;
    final label = _addressLabel;
    if (_resolving ||
        _openingDetails ||
        resolved == null ||
        label == null ||
        label.trim().isEmpty ||
        !ApiService.isKazakhstanAddress(resolved)) {
      return;
    }
    ++_selectionRevision;
    final point = _center;
    if (widget.collectDetails) {
      setState(() => _openingDetails = true);
      final details = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
            builder: (_) => AddressDetailsPage(
                  address: label,
                  city: ApiService.extractCityName(resolved) ?? _selectedCity,
                  initialEntrance: _entrance,
                  initialFloor: _floor,
                  initialApartment: _apartment,
                  confirmButtonLabel: widget.detailsConfirmButtonLabel,
                )),
      );
      if (!mounted) return;
      setState(() => _openingDetails = false);
      if (details == null) return;
      _entrance = details['entrance']?.toString() ?? '';
      _floor = details['floor']?.toString() ?? '';
      _apartment = details['apartment']?.toString() ?? '';
    }
    Navigator.pop(context, <String, dynamic>{
      'lat': point.latitude,
      'lon': point.longitude,
      'address': label,
      'street': ApiService.extractStreetName(resolved),
      'house': ApiService.extractHouseNumber(resolved),
      'city': ApiService.extractCityName(resolved),
      'country': ApiService.extractCountryName(resolved),
      'entrance': _entrance,
      'floor': _floor,
      'apartment': _apartment,
      if (widget.initialAddress?.containsKey('comment') ?? false)
        'comment': widget.initialAddress!['comment'],
      'point': {'lat': point.latitude, 'lon': point.longitude},
      'source': 'map_selection',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// «г. Караганда» when [name] is the scoped city, otherwise the name as the geocoder spells it.
  String? _cityLine(String? name) {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return sameAddressCity(trimmed, _selectedCity) ? 'г. $trimmed' : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          Positioned.fill(
              child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 16,
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) _mapMoved(camera.center);
              },
              onTap: (_, point) {
                _mapController.move(point, _mapController.camera.zoom);
                _mapMoved(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile3.maps.2gis.com/tiles?x={x}&y={y}&z={z}',
                tileProvider: _tileProvider,
              ),
            ],
          )),
          Positioned.fill(child: _Pin(lifted: _resolving)),
          SafeArea(
              child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 12,
                    AppSpacing.gutter, AppSpacing.gutter),
                child: Column(children: [
                  Row(children: [
                    AppIconButton(
                        asset: AppIcons.back,
                        size: 44,
                        onTap: () => Navigator.pop(context),
                        tooltip: 'Назад'),
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(child: _searchPill(palette)),
                  ]),
                  const SizedBox(height: AppSpacing.xxxl),
                  Expanded(
                      child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _locateButton(palette),
                              const SizedBox(height: AppSpacing.xl),
                              Flexible(child: _confirmCard(palette)),
                            ],
                          ))),
                ]),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _searchPill(AppPalette palette) {
    final city = _selectedCity?.trim();
    final hasCity = city != null && city.isNotEmpty;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: hasCity ? 'Найти адрес в г. $city' : 'Найти адрес',
      onTap: _openSearch,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadii.pillAll,
          boxShadow: AppShadows.control(palette),
        ),
        child: Material(
          color: palette.surface,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('address_map_search'),
            onTap: _openSearch,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxxl, vertical: AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 28),
                child: Row(children: [
                  AppIcon(AppIcons.search,
                      size: 18, color: palette.textSecondary),
                  const SizedBox(width: AppSpacing.xl),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasCity)
                          Text('Адрес в г. $city',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSemibold
                                  .copyWith(color: palette.textPrimary)),
                        Text(
                          'Улица или номер дома',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: (hasCity
                                  ? AppTypography.bodySmall
                                  : AppTypography.bodyLight)
                              .copyWith(color: palette.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _locateButton(AppPalette palette) {
    return SizedBox(
      width: 52,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: AppShadows.control(palette),
        ),
        child: Material(
          color: palette.surface,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: IconButton(
            key: const Key('address_locate'),
            tooltip: 'Определить моё местоположение',
            style: IconButton.styleFrom(
              foregroundColor: palette.textPrimary,
              minimumSize: const Size(52, 52),
            ),
            onPressed: _locating ? null : _locate,
            icon: _locating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _confirmCard(AppPalette palette) {
    final label = _addressLabel;
    final hasAddress = !_resolving && label != null;
    final hasIssue = !_resolving && _resolveError != null;
    final city = hasAddress
        ? _cityLine(
            ApiService.extractCityName(_resolvedAddress) ?? _selectedCity)
        : null;
    final title =
        _resolving ? 'Определяем адрес…' : (label ?? 'Адрес не определён');
    final canConfirm =
        !_resolving && _resolvedAddress != null && !_openingDetails;

    final String? subtitle = _resolving
        ? 'Ищем ближайший дом к точке на карте'
        : hasAddress
            ? city
            : _resolveError;

    return AppSurface(
      radius: AppRadii.xxl + 8,
      fill: palette.surface,
      shadow: [
        BoxShadow(
            color: palette.shadow, blurRadius: 24, offset: const Offset(0, 8)),
      ],
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Semantics(
                  liveRegion: true,
                  container: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: hasIssue
                              ? palette.surfaceMuted
                              : palette.accentFaint,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: AppIcon(
                          AppIcons.location,
                          size: 20,
                          color:
                              hasIssue ? palette.textSecondary : palette.accent,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xl),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: (hasAddress
                                      ? AppTypography.headline
                                      : AppTypography.title)
                                  .copyWith(
                                color: _resolving
                                    ? palette.textSecondary
                                    : palette.textPrimary,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(subtitle,
                                  style: AppTypography.bodySmall
                                      .copyWith(color: palette.textSecondary)),
                            ],
                            if (hasAddress && widget.collectDetails) ...[
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                  'Подъезд, этаж и квартиру добавите на следующем шаге.',
                                  style: AppTypography.label
                                      .copyWith(color: palette.textSecondary)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (hasIssue) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.textPrimary,
                side: BorderSide(color: palette.divider),
                minimumSize: const Size(0, 48),
                shape: const StadiumBorder(),
                textStyle: AppTypography.bodySmallBold,
              ),
              onPressed: _initialize,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Повторить определение адреса'),
            ),
          ],
          SizedBox(height: hasIssue ? AppSpacing.md : AppSpacing.xxxl),
          FilledButton(
            key: const Key('address_map_confirm'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 52),
              shape: const StadiumBorder(),
              textStyle: AppTypography.bodyBold,
              disabledBackgroundColor: palette.surfaceMuted,
              disabledForegroundColor: palette.textSecondary,
            ),
            onPressed: canConfirm ? _confirm : null,
            child: const Text('Подтвердить адрес', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

/// The selection pin. Its tip sits exactly on the map centre (the point that is resolved), and
/// it lifts off a ground shadow while the map is moving or the address is being looked up.
class _Pin extends StatelessWidget {
  const _Pin({required this.lifted});

  final bool lifted;

  static const double _glyph = 52;
  static const double _lift = 10;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return IgnorePointer(
      child: Center(
        child: Transform.translate(
          // The box's bottom edge is the contact point, so raise it by its own height.
          offset: const Offset(0, -(_glyph + _lift) / 2),
          child: SizedBox(
            width: _glyph,
            height: _glyph + _lift,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  bottom: -3,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: lifted ? 10 : 16,
                    height: lifted ? 4 : 6,
                    decoration: BoxDecoration(
                      color: palette.shadow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  bottom: (lifted ? _lift : 0) - 4,
                  child: Icon(Icons.location_on,
                      color: palette.accent,
                      size: _glyph,
                      shadows: const [
                        Shadow(
                            color: Color(0x40000000),
                            blurRadius: 6,
                            offset: Offset(0, 2)),
                      ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AddressDetailsPage extends StatefulWidget {
  const AddressDetailsPage({
    super.key,
    required this.address,
    required this.initialEntrance,
    required this.initialFloor,
    required this.initialApartment,
    this.city,
    this.onChangeAddress,
    this.confirmButtonLabel = 'Подтвердить и выбрать адрес',
  });

  final String address;

  /// Shown under the street in the summary card when known.
  final String? city;
  final String initialEntrance;
  final String initialFloor;
  final String initialApartment;
  final Future<Map<String, dynamic>?> Function(BuildContext context)?
      onChangeAddress;
  final String confirmButtonLabel;

  @override
  State<AddressDetailsPage> createState() => _AddressDetailsPageState();
}

class _AddressDetailsPageState extends State<AddressDetailsPage> {
  late final TextEditingController _entrance;
  late final TextEditingController _floor;
  late final TextEditingController _apartment;
  bool _changing = false;
  Map<String, dynamic>? _changedAddress;

  String get _label =>
      _changedAddress?['address']?.toString() ?? widget.address;

  String? get _city {
    final raw = _changedAddress == null
        ? widget.city
        : _changedAddress!['city']?.toString();
    final trimmed = raw?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  void initState() {
    super.initState();
    _entrance = TextEditingController(text: widget.initialEntrance);
    _floor = TextEditingController(text: widget.initialFloor);
    _apartment = TextEditingController(text: widget.initialApartment);
  }

  @override
  void dispose() {
    _entrance.dispose();
    _floor.dispose();
    _apartment.dispose();
    super.dispose();
  }

  Future<void> _changeAddress() async {
    if (_changing) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _changing = true);
    try {
      final selected = await widget.onChangeAddress?.call(context);
      if (!mounted || selected == null) return;
      final normalized = AddressStorageService.deliveryAddress(selected);
      if (normalized == null) return;
      setState(() => _changedAddress = normalized);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Не удалось изменить адрес. Текущие данные сохранены.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  void _confirm() {
    if (_changing || _label.trim().isEmpty) return;
    final details = <String, dynamic>{
      'entrance': _entrance.text.trim(),
      'floor': _floor.text.trim(),
      'apartment': _apartment.text.trim(),
    };
    Navigator.pop(
        context,
        _changedAddress == null
            ? details
            : <String, dynamic>{
                '_selectedAddress': {..._changedAddress!, ...details},
              });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              child: Column(
                children: [
                  AppTopBar(
                    title: 'Детали адреса',
                    onBack: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: AppSpacing.huge),
                  Expanded(
                    child: Builder(builder: (bodyContext) {
                      return ListView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.only(
                            bottom:
                                MediaQuery.paddingOf(bodyContext).bottom + 16),
                        children: [
                          _summary(palette),
                          const SizedBox(height: AppSpacing.huge + 8),
                          Text('Как вас найти',
                              style: AppTypography.headline
                                  .copyWith(color: palette.textPrimary)),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Необязательно: курьеру проще найти дверь, а заполнить можно и позже при оформлении.',
                            style: AppTypography.bodySmall
                                .copyWith(color: palette.textSecondary),
                          ),
                          const SizedBox(height: AppSpacing.xxxl),
                          _fields(),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'Буквы тоже подойдут: корпус, секция, подъезд А, кв. 12Б.',
                            style: AppTypography.label
                                .copyWith(color: palette.textSecondary),
                          ),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.md,
            AppSpacing.gutter, AppSpacing.gutter),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AppSurface(
              radius: 36,
              padding: const EdgeInsets.all(AppSpacing.md),
              clip: true,
              shadow: AppShadows.control(palette),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('address_details_confirm'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    shape: const StadiumBorder(),
                    textStyle: AppTypography.bodyBold,
                    disabledBackgroundColor: palette.surfaceMuted,
                    disabledForegroundColor: palette.textSecondary,
                  ),
                  onPressed:
                      _changing || _label.trim().isEmpty ? null : _confirm,
                  child: Text(widget.confirmButtonLabel,
                      textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The chosen street with its city, and the way back to the map.
  Widget _summary(AppPalette palette) {
    final city = _city;
    final canChange = widget.onChangeAddress != null;
    return AppSurface(
      radius: AppRadii.xxl,
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: LayoutBuilder(builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final stacked = constraints.maxWidth < 300 || scale > 1.3;
        final change = TextButton(
          onPressed: _changing ? null : _changeAddress,
          style: TextButton.styleFrom(
            foregroundColor: palette.textPrimary,
            textStyle: AppTypography.bodySmallBold,
            minimumSize: const Size(AppSpacing.touchTarget, 44),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            backgroundColor: palette.surfaceMuted,
            shape: const StadiumBorder(),
          ),
          child:
              const Text('Изменить', semanticsLabel: 'Изменить адрес на карте'),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: palette.accentFaint, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: AppIcon(AppIcons.location,
                      size: 20, color: palette.accent),
                ),
                const SizedBox(width: AppSpacing.xl),
                Expanded(
                  child: Semantics(
                    container: true,
                    label: 'Выбранный адрес',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_label,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.headline
                                .copyWith(color: palette.textPrimary)),
                        if (city != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text('г. $city',
                              style: AppTypography.bodySmall
                                  .copyWith(color: palette.textSecondary)),
                        ],
                      ],
                    ),
                  ),
                ),
                if (canChange && !stacked) ...[
                  const SizedBox(width: AppSpacing.md),
                  change,
                ],
              ],
            ),
            if (canChange && stacked) ...[
              const SizedBox(height: AppSpacing.xl),
              change,
            ],
          ],
        );
      }),
    );
  }

  /// Подъезд / Этаж / Квартира side by side, stacked when the row would crush the labels.
  Widget _fields() {
    return LayoutBuilder(builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final inRow = constraints.maxWidth >= 300 && scale <= 1.3;
      final entrance = _field(_entrance, 'entrance', 'Подъезд', '2А');
      final floor = _field(_floor, 'floor', 'Этаж', '7');
      final apartment =
          _field(_apartment, 'apartment', 'Квартира', '45Б', last: true);
      if (inRow) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: entrance),
            const SizedBox(width: AppSpacing.xl),
            Expanded(child: floor),
            const SizedBox(width: AppSpacing.xl),
            Expanded(child: apartment),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          entrance,
          const SizedBox(height: AppSpacing.xl),
          floor,
          const SizedBox(height: AppSpacing.xl),
          apartment,
        ],
      );
    });
  }

  Widget _field(
      TextEditingController controller, String name, String label, String hint,
      {bool last = false}) {
    final palette = context.palette;
    const shape = AppRadii.xlAll;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ExcludeSemantics(
        child: Text(label,
            style: AppTypography.bodySmallMedium
                .copyWith(color: palette.textPrimary)),
      ),
      const SizedBox(height: AppSpacing.md),
      Semantics(
        label: label,
        child: TextField(
          key: ValueKey('address_$name'),
          controller: controller,
          textInputAction: last ? TextInputAction.done : TextInputAction.next,
          onSubmitted: (_) {
            if (last) {
              FocusManager.instance.primaryFocus?.unfocus();
            } else {
              FocusScope.of(context).nextFocus();
            }
          },
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          cursorColor: palette.accent,
          style:
              AppTypography.titleRegular.copyWith(color: palette.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                AppTypography.bodyLight.copyWith(color: palette.textSecondary),
            filled: true,
            fillColor: palette.surface,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl, vertical: AppSpacing.xxl),
            border: const OutlineInputBorder(
                borderRadius: shape, borderSide: BorderSide.none),
            enabledBorder: const OutlineInputBorder(
                borderRadius: shape, borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: shape,
                borderSide: BorderSide(color: palette.accent, width: 1.5)),
          ),
        ),
      ),
    ]);
  }
}

class AddressSearchPage extends StatefulWidget {
  const AddressSearchPage({super.key, this.selectedCity});

  final String? selectedCity;

  @override
  State<AddressSearchPage> createState() => _AddressSearchPageState();
}

class _AddressSearchPageState extends State<AddressSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;
  int _requestId = 0;
  bool _searching = false;
  String? _error;
  List<Map<String, dynamic>> _results = [];

  String? get _city {
    final trimmed = widget.selectedCity?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    final request = ++_requestId;
    final query = value.trim();
    setState(() {
      _results = [];
      _error = null;
      _searching = query.length >= 3;
    });
    if (query.length < 3) return;
    _debounce =
        Timer(const Duration(milliseconds: 350), () => _search(query, request));
  }

  void _retry() {
    _debounce?.cancel();
    final query = _controller.text.trim();
    if (query.length < 3) return;
    final request = ++_requestId;
    setState(() {
      _searching = true;
      _error = null;
    });
    _search(query, request);
  }

  Future<void> _search(String query, int request) async {
    try {
      final result = await ApiService.searchAddressByText(query,
          city: widget.selectedCity);
      if (!mounted || request != _requestId) return;
      if (result == null) throw StateError('Поиск недоступен');
      final valid = result
          .where((item) =>
              AddressStorageService.coordinates(item) != null &&
              ApiService.isKazakhstanAddress(item) &&
              (ApiService.extractAddressLabel(item,
                          preferredCity: widget.selectedCity)
                      ?.trim()
                      .isNotEmpty ??
                  false))
          .toList();
      setState(() {
        _results = valid;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _results = [];
        _searching = false;
        _error =
            'Не удалось найти адреса. Проверьте соединение и попробуйте снова.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final city = _city;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter, 12, AppSpacing.gutter, AppSpacing.md),
              child: Row(children: [
                AppIconButton(
                    asset: AppIcons.back,
                    size: 44,
                    onTap: () => Navigator.pop(context),
                    tooltip: 'Назад'),
                const SizedBox(width: AppSpacing.xl),
                Expanded(
                    child: TextField(
                  key: const Key('address_search_field'),
                  controller: _controller,
                  focusNode: _focus,
                  textInputAction: TextInputAction.search,
                  onChanged: _changed,
                  onSubmitted: (_) => _retry(),
                  cursorColor: palette.accent,
                  style:
                      AppTypography.body.copyWith(color: palette.textPrimary),
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: InputDecoration(
                    hintText: 'Улица или номер дома',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xxl),
                      child: AppIcon(AppIcons.search,
                          size: 18, color: palette.textSecondary),
                    ),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 0, minHeight: 48),
                    filled: true,
                    fillColor: palette.surface,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                    border: const OutlineInputBorder(
                        borderRadius: AppRadii.pillAll,
                        borderSide: BorderSide.none),
                    enabledBorder: const OutlineInputBorder(
                        borderRadius: AppRadii.pillAll,
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadii.pillAll,
                        borderSide:
                            BorderSide(color: palette.accent, width: 1.5)),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Очистить поиск',
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              _controller.clear();
                              _changed('');
                            },
                          ),
                  ),
                )),
              ])),
          if (city != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter + 44 + AppSpacing.xl + AppSpacing.xxxl,
                  0,
                  AppSpacing.gutter,
                  AppSpacing.md),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Ищем адреса в г. $city',
                    style: AppTypography.label
                        .copyWith(color: palette.textSecondary)),
              ),
            ),
          Expanded(child: _body()),
        ]),
      ))),
    );
  }

  Widget _body() {
    if (_searching) return const AppLoading();
    if (_error != null) {
      return SingleChildScrollView(
          padding: const EdgeInsets.only(top: 32),
          child: AppErrorState(message: _error!, onRetry: _retry));
    }
    final city = _city;
    final short = _controller.text.trim().length < 3;
    if (short || _results.isEmpty) {
      return SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(top: 64),
        child: AppEmptyState(
          title: short ? 'Введите не менее 3 символов' : 'Адреса не найдены',
          subtitle: short
              ? (city == null
                  ? 'Поиск адресов в Казахстане'
                  : 'Начните с названия улицы в г. $city — номер дома можно добавить после.')
              : (city == null
                  ? 'Проверьте написание или уберите номер дома.'
                  : 'В г. $city такого адреса нет. Проверьте написание или уберите номер дома.'),
          muted: true,
        ),
      );
    }
    final palette = context.palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, AppSpacing.huge),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Material(
          color: palette.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.xxl)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < _results.length; i++) ...[
                if (i > 0)
                  Divider(
                      height: 1,
                      indent: AppSpacing.xxxl + 40 + AppSpacing.xl,
                      color: palette.divider),
                _resultRow(_results[i], palette),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _resultRow(Map<String, dynamic> item, AppPalette palette) {
    final point = AddressStorageService.coordinates(item)!;
    final label = ApiService.extractAddressLabel(item,
        preferredCity: widget.selectedCity)!;
    final secondary = _secondaryLine(item);
    return InkWell(
      onTap: () => Navigator.pop(context, <String, dynamic>{
        'lat': point.$1,
        'lon': point.$2,
        'label': label,
        'rawAddress': item,
      }),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxxl, vertical: AppSpacing.xl),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: palette.surfaceMuted, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: AppIcon(AppIcons.location,
                  size: 18, color: palette.textSecondary),
            ),
            const SizedBox(width: AppSpacing.xl),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyBold
                          .copyWith(color: palette.textPrimary)),
                  if (secondary != null)
                    Text(secondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall
                            .copyWith(color: palette.textSecondary)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// District and city under the street, as the geocoder reports them.
  String? _secondaryLine(Map<String, dynamic> item) {
    final properties = item['properties'];
    final geocoding =
        properties is Map ? properties['geocoding'] : item['geocoding'];
    String? district;
    if (geocoding is Map) {
      for (final key in const [
        'district',
        'borough',
        'quarter',
        'suburb',
        'neighbourhood'
      ]) {
        final value = geocoding[key]?.toString().trim();
        if (value != null && value.isNotEmpty) {
          district = value;
          break;
        }
      }
    }
    final city = ApiService.extractCityName(item);
    final cityText = city == null
        ? null
        : sameAddressCity(city, widget.selectedCity)
            ? 'г. $city'
            : city;
    final parts = [
      if (district != null && !sameAddressCity(district, city)) district,
      if (cityText != null) cityText,
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }
}
