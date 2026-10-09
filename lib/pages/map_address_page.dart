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

class MapAddressPage extends StatefulWidget {
  const MapAddressPage({
    super.key,
    required this.initialLat,
    required this.initialLon,
    this.initialAddress,
    this.tileProvider,
    this.locate,
    this.collectDetails = true,
    this.detailsConfirmButtonLabel = 'Подтвердить и выбрать адрес',
  });

  final double initialLat;
  final double initialLon;
  final Map<String, dynamic>? initialAddress;
  final TileProvider? tileProvider;
  final Future<AddressLocateResult> Function()? locate;
  final bool collectDetails;
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
  Timer? _reverseDebounce;
  late String _entrance;
  late String _floor;
  late String _apartment;

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
    try {
      _selectedCity = await OnboardingService.getSelectedCity();
      if (!mounted) return;
      await _reverse(_center);
    } catch (_) {
      if (!mounted) return;
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

  Future<void> _reverse(LatLng point) async {
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
      setState(() {
        _resolvedAddress = resolved;
        _addressLabel = label;
        _resolveError = resolved == null
            ? 'Адрес не найден в выбранном городе. Передвиньте карту или воспользуйтесь поиском.'
            : null;
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

  void _mapMoved(LatLng point) {
    _reverseDebounce?.cancel();
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
    final selected = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
          builder: (_) => AddressSearchPage(selectedCity: _selectedCity)),
    );
    if (!mounted || selected == null) return;
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
    if (!await _locationService.isLocationServiceEnabled()) {
      return AddressLocateResult.unavailable(
        message: _locationService.isIosBrowserLocationFlow
            ? _locationService.browserLocationSettingsInstructions()
            : 'Геолокация выключена. Включите её в настройках устройства или найдите адрес вручную.',
        needsLocationSettings: !_locationService.isIosBrowserLocationFlow,
      );
    }
    final permission = await _locationService.checkAndRequestPermissions();
    if (!permission.success) {
      return AddressLocateResult.unavailable(
        message: permission.message,
        needsAppSettings: permission.needsSettingsRedirect,
      );
    }
    final position = await _locationService.getCurrentPosition(
        timeLimit: const Duration(seconds: 10));
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
    setState(() => _locating = true);
    try {
      final result = await (widget.locate?.call() ?? _locateDevice());
      if (!mounted) return;
      final point = result.point;
      if (point != null &&
          point.latitude.isFinite &&
          point.longitude.isFinite &&
          point.latitude.abs() <= 90 &&
          point.longitude.abs() <= 180) {
        _reverseDebounce?.cancel();
        _mapController.move(point, 16.5);
        setState(() => _center = point);
        await _reverse(point);
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
                    if (!opened && mounted) {
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
      if (mounted) {
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
    final point = _center;
    if (widget.collectDetails) {
      setState(() => _openingDetails = true);
      final details = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
            builder: (_) => AddressDetailsPage(
                  address: label,
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
      'point': {'lat': point.latitude, 'lon': point.longitude},
      'source': 'map_selection',
      'timestamp': DateTime.now().toIso8601String(),
    });
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
          const Center(
              child: IgnorePointer(
                  child: Icon(
            Icons.location_on,
            color: Color(0xFFF16800),
            size: 48,
          ))),
          SafeArea(
              child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
                child: Column(children: [
                  Row(children: [
                    AppIconButton(
                        asset: AppIcons.back,
                        onTap: () => Navigator.pop(context),
                        tooltip: 'Назад'),
                    const SizedBox(width: 12),
                    Expanded(
                        child: InkWell(
                      key: const Key('address_map_search'),
                      onTap: _openSearch,
                      borderRadius: AppRadii.pillAll,
                      child: AppGlassPanel(
                      radius: AppRadii.pill,
                      tint: palette.surface.withValues(alpha: .94),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(children: [
                        Icon(Icons.search,
                            color: palette.textSecondary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(
                          _selectedCity == null
                              ? 'Поиск адреса'
                              : '$_selectedCity, улица или дом',
                          style: AppTypography.bodyLight
                              .copyWith(color: palette.textSecondary),
                        )),
                      ]),
                    )),
                    ),
                  ]),
                  const Spacer(),
                  Flexible(
                      flex: 3,
                      child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              AppGlassPanel(
                                radius: 24,
                                width: 44,
                                height: 44,
                                child:
                              IconButton.filled(
                                key: const Key('address_locate'),
                                tooltip: 'Определить моё местоположение',
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: palette.textPrimary,
                                  minimumSize: const Size(44, 44),
                                ),
                                onPressed: _locating ? null : _locate,
                                icon: _locating
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Icon(Icons.my_location),
                              ),
                              ),
                              const SizedBox(height: 12),
                              AppGlassPanel(
                                radius: 16,
                                tint: palette.surface.withValues(alpha: .94),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          _resolving
                                              ? 'Определяем адрес…'
                                              : _addressLabel ??
                                                  'Адрес не определён',
                                          style: AppTypography.title.copyWith(
                                              color: palette.textPrimary)),
                                      const SizedBox(height: 12),
                                      Text(
                                          _resolveError ??
                                              'Сначала подтвердите точку на карте, затем добавьте подъезд, этаж и квартиру на следующем шаге.',
                                          style: AppTypography.label.copyWith(
                                              color: palette.textSecondary)),
                                      if (_resolveError != null)
                                        TextButton(
                                            onPressed: _initialize,
                                            child: const Text(
                                                'Повторить определение адреса')),
                                      const SizedBox(height: 24),
                                      SizedBox(
                                          width: double.infinity,
                                          child: FilledButton(
                                            key: const Key(
                                                'address_map_confirm'),
                                            style: FilledButton.styleFrom(
                                              minimumSize: const Size(0, 44),
                                              shape: const StadiumBorder(),
                                              textStyle: AppTypography.bodyBold,
                                            ),
                                            onPressed: _resolving ||
                                                    _resolvedAddress == null ||
                                                    _openingDetails
                                                ? null
                                                : _confirm,
                                            child: const Text(
                                                'Подтвердить адрес',
                                                textAlign: TextAlign.center),
                                          )),
                                    ]),
                              ),
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
}

class AddressDetailsPage extends StatefulWidget {
  const AddressDetailsPage({
    super.key,
    required this.address,
    required this.initialEntrance,
    required this.initialFloor,
    required this.initialApartment,
    this.onChangeAddress,
    this.confirmButtonLabel = 'Подтвердить и выбрать адрес',
  });

  final String address;
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  AppTopBar(
                    title: 'Детали адреса',
                    onBack: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Builder(builder: (bodyContext) {
                      return ListView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.only(
                            bottom:
                                MediaQuery.paddingOf(bodyContext).bottom + 16),
                        children: [
                          AppSurface(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Выбранный адрес',
                                    style: AppTypography.label
                                        .copyWith(color: palette.textSecondary)),
                                const SizedBox(height: 6),
                                Text(_label,
                                    style: AppTypography.title
                                        .copyWith(color: palette.textPrimary)),
                              ],
                            ),
                          ),
                          if (widget.onChangeAddress != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _changing ? null : _changeAddress,
                                icon: const Icon(Icons.map_outlined),
                                label: const Text('Изменить на карте'),
                              ),
                            ),
                          const SizedBox(height: 24),
                          _field(_entrance, 'entrance', 'Подъезд',
                              'Например: 2 или 2А'),
                          const SizedBox(height: 12),
                          _field(_floor, 'floor', 'Этаж', 'Например: 7 или м'),
                          const SizedBox(height: 12),
                          _field(_apartment, 'apartment', 'Квартира',
                              'Например: 45 или 45Б',
                              last: true),
                          const SizedBox(height: 12),
                          Text(
                            'Можно заполнить сейчас или позже на этапе оформления заказа. Буквы тоже подойдут: корпус, секция, подъезд А, кв. 12Б.',
                            style: AppTypography.bodySmall
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
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AppGlassPanel(
              radius: 32,
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('address_details_confirm'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 49),
                    shape: const StadiumBorder(),
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

  Widget _field(
      TextEditingController controller, String name, String label, String hint,
      {bool last = false}) {
    final palette = context.palette;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: AppTypography.title.copyWith(color: palette.textPrimary)),
      const SizedBox(height: 8),
      TextField(
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
        style: AppTypography.titleRegular.copyWith(color: palette.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTypography.base(
              size: 16, weight: 300, color: palette.textSecondary),
          filled: true,
          fillColor: palette.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: AppRadii.lgAll,
              borderSide: BorderSide(color: palette.divider)),
          enabledBorder: OutlineInputBorder(
              borderRadius: AppRadii.lgAll,
              borderSide: BorderSide(color: palette.divider)),
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
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
              child: Row(children: [
                AppIconButton(
                    asset: AppIcons.back,
                    onTap: () => Navigator.pop(context),
                    tooltip: 'Назад'),
                const SizedBox(width: 12),
                Expanded(
                    child: TextField(
                  key: const Key('address_search_field'),
                  controller: _controller,
                  focusNode: _focus,
                  textInputAction: TextInputAction.search,
                  onChanged: _changed,
                  onSubmitted: (_) => _retry(),
                  style:
                      AppTypography.body.copyWith(color: palette.textPrimary),
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: InputDecoration(
                    hintText: widget.selectedCity == null
                        ? 'Улица или дом'
                        : '${widget.selectedCity}, улица или дом',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: palette.surface,
                    border: const OutlineInputBorder(
                        borderRadius: AppRadii.pillAll,
                        borderSide: BorderSide.none),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Очистить поиск',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _controller.clear();
                              _changed('');
                            },
                          ),
                  ),
                )),
              ])),
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
    if (_controller.text.trim().length < 3 || _results.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.only(top: 80),
        child: AppEmptyState(
          title: _controller.text.trim().length < 3
              ? 'Введите не менее 3 символов'
              : 'Адреса не найдены',
          subtitle: widget.selectedCity == null
              ? 'Поиск адресов в Казахстане'
              : 'Поиск в городе ${widget.selectedCity}. Укажите улицу и номер дома.',
          muted: true,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _results[index];
        final point = AddressStorageService.coordinates(item)!;
        final label = ApiService.extractAddressLabel(item,
            preferredCity: widget.selectedCity)!;
        return AppSurface(
          padding: const EdgeInsets.all(14),
          onTap: () => Navigator.pop(context, <String, dynamic>{
            'lat': point.$1,
            'lon': point.$2,
            'label': label,
            'rawAddress': item,
          }),
          child: Row(children: [
            Icon(Icons.location_on_outlined, color: context.palette.accent),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: AppTypography.bodyMedium
                        .copyWith(color: context.palette.textPrimary))),
          ]),
        );
      },
    );
  }
}
