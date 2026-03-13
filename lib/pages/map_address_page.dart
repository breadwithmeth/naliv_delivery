import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/onboarding_service.dart';
import '../utils/api.dart';
import '../utils/location_service.dart';

class MapAddressPage extends StatefulWidget {
  final double initialLat;
  final double initialLon;
  final Map<String, dynamic>? initialAddress;

  const MapAddressPage({
    super.key,
    required this.initialLat,
    required this.initialLon,
    this.initialAddress,
  });

  @override
  State<MapAddressPage> createState() => _MapAddressPageState();
}

class _MapAddressPageState extends State<MapAddressPage> {
  static const Color _bgDeep = Color(0xFF121212);
  static const Color _bgTop = Color(0xFF161616);
  static const Color _card = Color(0xFF1E1E1E);
  static const Color _cardDark = Color(0xFF181818);
  static const Color _orange = Color(0xFFF6A10C);
  static const Color _text = Colors.white;
  static const Color _textMute = Color(0xFF9FB0C8);

  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService.instance;

  late LatLng _center;
  String? _selectedCity;
  String _currentAddress = '';
  bool _isResolvingAddress = true;
  bool _isLocatingUser = false;
  int _reverseRequestId = 0;
  final TextEditingController _entranceController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _apartmentController = TextEditingController();

  @override
  void dispose() {
    _entranceController.dispose();
    _floorController.dispose();
    _apartmentController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _center = LatLng(widget.initialLat, widget.initialLon);
    _prefillFromInitialAddress();
    _initialize();
  }

  void _prefillFromInitialAddress() {
    final initialAddress = widget.initialAddress;
    if (initialAddress == null) return;

    _currentAddress = initialAddress['address']?.toString() ?? initialAddress['name']?.toString() ?? '';
    _entranceController.text = initialAddress['entrance']?.toString() ?? '';
    _floorController.text = initialAddress['floor']?.toString() ?? '';
    _apartmentController.text = initialAddress['apartment']?.toString() ?? '';
  }

  Future<void> _initialize() async {
    _selectedCity = await OnboardingService.getSelectedCity();
    if (!mounted) return;

    unawaited(_reverseAddress(_center.latitude, _center.longitude));
    if (widget.initialAddress == null) {
      unawaited(_centerOnUserLocation());
    }
  }

  Future<void> _centerOnUserLocation() async {
    if (!mounted || _isLocatingUser) return;

    setState(() => _isLocatingUser = true);
    try {
      final permission = await _locationService.checkAndRequestPermissions();
      if (!permission.success) return;

      final serviceEnabled = await _locationService.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      Position? position;
      for (final accuracy in [LocationAccuracy.high, LocationAccuracy.medium, LocationAccuracy.low]) {
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: accuracy,
            timeLimit: const Duration(seconds: 7),
          );
          break;
        } catch (_) {}
      }

      if (position == null || !mounted) return;

      final nextCenter = LatLng(position.latitude, position.longitude);
      setState(() => _center = nextCenter);
      _mapController.move(nextCenter, 16.5);
      await _reverseAddress(nextCenter.latitude, nextCenter.longitude);
    } finally {
      if (mounted) {
        setState(() => _isLocatingUser = false);
      }
    }
  }

  Future<void> _reverseAddress(double lat, double lon) async {
    final requestId = ++_reverseRequestId;
    if (mounted) {
      setState(() => _isResolvingAddress = true);
    }

    final addressData = await ApiService.searchAddresses(
      lat: lat,
      lon: lon,
      city: _selectedCity,
    );

    if (!mounted || requestId != _reverseRequestId) return;

    final label = addressData != null && addressData.isNotEmpty
        ? ApiService.extractAddressLabel(
              addressData.first,
              lat: lat,
              lon: lon,
              preferredCity: _selectedCity,
            ) ??
            'Адрес не найден'
        : 'Адрес не найден';

    setState(() {
      _currentAddress = label;
      _isResolvingAddress = false;
    });
  }

  void _onMapSettled() {
    final nextCenter = _mapController.camera.center;
    setState(() => _center = nextCenter);
    unawaited(_reverseAddress(nextCenter.latitude, nextCenter.longitude));
  }

  Future<void> _openSearch() async {
    final selected = await showGeneralDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'address-search',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (_, animation, __, ___) {
        return FadeTransition(
          opacity: animation,
          child: _AddressSearchSheet(selectedCity: _selectedCity),
        );
      },
    );

    if (selected == null || !mounted) return;

    final lat = (selected['lat'] as num).toDouble();
    final lon = (selected['lon'] as num).toDouble();
    final label = selected['label']?.toString() ?? '';
    final nextCenter = LatLng(lat, lon);

    setState(() {
      _center = nextCenter;
      if (label.isNotEmpty) {
        _currentAddress = label;
      }
    });

    _mapController.move(nextCenter, 17);
    await _reverseAddress(lat, lon);
  }

  void _confirmAddress() {
    final address = _currentAddress.trim().isNotEmpty ? _currentAddress.trim() : 'Адрес не найден';
    _openAddressDetailsStep(address);
  }

  Future<void> _openAddressDetailsStep(String address) async {
    final details = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(
        builder: (_) => AddressDetailsPage(
          address: address,
          initialEntrance: _entranceController.text,
          initialFloor: _floorController.text,
          initialApartment: _apartmentController.text,
        ),
      ),
    );

    if (details == null || !mounted) return;

    _entranceController.text = details['entrance'] ?? '';
    _floorController.text = details['floor'] ?? '';
    _apartmentController.text = details['apartment'] ?? '';

    Navigator.of(context).pop({
      'lat': _center.latitude,
      'lon': _center.longitude,
      'address': address,
      'entrance': _entranceController.text.trim(),
      'floor': _floorController.text.trim(),
      'apartment': _apartmentController.text.trim(),
      'source': 'map_selection',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _bgDeep,
      body: Stack(
        children: [
          Positioned.fill(child: _map()),
          Positioned.fill(child: _backgroundGlow()),
          Positioned(
            top: safeTop + 12,
            left: 16,
            right: 16,
            child: _topBar(),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _orange,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: _orange.withValues(alpha: 0.36), blurRadius: 18, spreadRadius: 2),
                          ],
                        ),
                      ),
                      const Icon(Icons.location_on_rounded, size: 48, color: _orange),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 164 + safeBottom,
            child: _locateButton(),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16 + safeBottom,
            child: _addressCard(),
          ),
        ],
      ),
    );
  }

  Widget _map() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: 16,
        onPointerUp: (_, __) => _onMapSettled(),
        onTap: (_, latLng) {
          _mapController.move(latLng, _mapController.camera.zoom);
          _onMapSettled();
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile3.maps.2gis.com/tiles?x={x}&y={y}&z={z}',
          subdomains: const ['tile0', 'tile1', 'tile2', 'tile3'],
          tileProvider: CancellableNetworkTileProvider(),
        ),
      ],
    );
  }

  Widget _backgroundGlow() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _bgTop.withValues(alpha: 0.20),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        _circleButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 10),
        Expanded(child: _searchBar()),
      ],
    );
  }

  Widget _searchBar() {
    final hint = _selectedCity == null ? 'Поиск адреса' : '$_selectedCity, улица или дом';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _openSearch,
        child: Ink(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _card.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.24), blurRadius: 16, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: _textMute),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _text, fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _card.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Icon(icon, color: _text, size: 18),
        ),
      ),
    );
  }

  Widget _locateButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _isLocatingUser ? null : _centerOnUserLocation,
        child: Ink(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _card.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: _isLocatingUser
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: _orange),
                )
              : const Icon(Icons.my_location_rounded, color: _text, size: 20),
        ),
      ),
    );
  }

  Widget _addressCard() {
    final addressLabel =
        _isResolvingAddress ? 'Ищем адрес...' : (_currentAddress.trim().isEmpty ? 'Подвиньте карту немного' : _currentAddress.trim());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardDark.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.34), blurRadius: 22, offset: const Offset(0, 14)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            addressLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.w800, height: 1.25),
          ),
          const SizedBox(height: 8),
          const Text(
            'Сначала подтвердите точку на карте, затем добавьте подъезд, этаж и квартиру на следующем шаге.',
            style: TextStyle(color: _textMute, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isResolvingAddress ? null : _confirmAddress,
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.black,
                disabledBackgroundColor: _orange.withValues(alpha: 0.55),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(
                _isResolvingAddress ? 'Определяем...' : 'Подтвердить адрес',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AddressDetailsPage extends StatefulWidget {
  const AddressDetailsPage({
    required this.address,
    required this.initialEntrance,
    required this.initialFloor,
    required this.initialApartment,
  });

  final String address;
  final String initialEntrance;
  final String initialFloor;
  final String initialApartment;

  @override
  State<AddressDetailsPage> createState() => _AddressDetailsPageState();
}

class _AddressDetailsPageState extends State<AddressDetailsPage> {
  static const Color _card = Color(0xFF1E1E1E);
  static const Color _cardDark = Color(0xFF181818);
  static const Color _bgDeep = Color(0xFF121212);
  static const Color _bgTop = Color(0xFF161616);
  static const Color _orange = Color(0xFFF6A10C);
  static const Color _text = Colors.white;
  static const Color _textMute = Color(0xFF9FB0C8);

  late final TextEditingController _entranceController;
  late final TextEditingController _floorController;
  late final TextEditingController _apartmentController;

  @override
  void initState() {
    super.initState();
    _entranceController = TextEditingController(text: widget.initialEntrance);
    _floorController = TextEditingController(text: widget.initialFloor);
    _apartmentController = TextEditingController(text: widget.initialApartment);
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _floorController.dispose();
    _apartmentController.dispose();
    super.dispose();
  }

  void _confirm() {
    Navigator.of(context).pop({
      'entrance': _entranceController.text.trim(),
      'floor': _floorController.text.trim(),
      'apartment': _apartmentController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: _bgDeep,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgDeep],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.of(context).pop(),
                        child: Ink(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: _card.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, color: _text, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Детали адреса',
                        style: TextStyle(color: _text, fontSize: 24, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _cardDark,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Выбранный адрес',
                        style: TextStyle(color: _textMute, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.address,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.w800, height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _detailsField(
                          controller: _entranceController,
                          label: 'Подъезд',
                          hint: 'Например, 2',
                          icon: Icons.stairs_rounded,
                        ),
                        const SizedBox(height: 14),
                        _detailsField(
                          controller: _floorController,
                          label: 'Этаж',
                          hint: 'Например, 7',
                          icon: Icons.layers_rounded,
                        ),
                        const SizedBox(height: 14),
                        _detailsField(
                          controller: _apartmentController,
                          label: 'Квартира',
                          hint: 'Например, 45',
                          icon: Icons.door_front_door_rounded,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Можно заполнить сейчас или позже на этапе оформления заказа.',
                          style: TextStyle(color: _textMute, fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orange,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: const Text(
                      'Подтвердить и выбрать адрес',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailsField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _text, fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: _text, fontSize: 15, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _textMute),
            prefixIcon: Icon(icon, color: _orange),
            filled: true,
            fillColor: _card,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(18)),
              borderSide: BorderSide(color: _orange),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddressSearchSheet extends StatefulWidget {
  final String? selectedCity;

  const _AddressSearchSheet({required this.selectedCity});

  @override
  State<_AddressSearchSheet> createState() => _AddressSearchSheetState();
}

class _AddressSearchSheetState extends State<_AddressSearchSheet> {
  static const Color _bgDeep = Color(0xFF121212);
  static const Color _card = Color(0xFF1E1E1E);
  static const Color _cardDark = Color(0xFF181818);
  static const Color _orange = Color(0xFFF6A10C);
  static const Color _text = Colors.white;
  static const Color _textMute = Color(0xFF9FB0C8);

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;
  int _latestRequestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String rawValue) async {
    final trimmed = rawValue.trim();
    if (trimmed.length < 3) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _results = [];
      });
      return;
    }

    final requestId = ++_latestRequestId;
    setState(() => _isSearching = true);

    final result = await ApiService.searchAddressByText(
      trimmed,
      city: widget.selectedCity,
    );

    if (!mounted || requestId != _latestRequestId) return;
    setState(() {
      _isSearching = false;
      _results = result ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _bgDeep,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _text, size: 18),
                  ),
                  Expanded(
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        style: const TextStyle(color: _text, fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          hintText: widget.selectedCity == null ? 'Поиск адреса' : '${widget.selectedCity}, улица или дом',
                          hintStyle: const TextStyle(color: _textMute),
                          prefixIcon: const Icon(Icons.search_rounded, color: _textMute),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                        onChanged: _runSearch,
                        textInputAction: TextInputAction.search,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _controller.text.trim().length < 3
                  ? const Center(
                      child: Text('Введите 3 символа', style: TextStyle(color: _textMute, fontWeight: FontWeight.w700)),
                    )
                  : _isSearching
                      ? const Center(child: CircularProgressIndicator(color: _orange))
                      : _results.isEmpty
                          ? const Center(
                              child: Text('Ничего не найдено', style: TextStyle(color: _textMute, fontWeight: FontWeight.w700)),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              itemCount: _results.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, index) {
                                final item = _results[index];
                                double lat;
                                double lon;

                                if (item['geometry'] != null && item['geometry']['coordinates'] is List) {
                                  final coordinates = item['geometry']['coordinates'] as List;
                                  lon = (coordinates[0] as num).toDouble();
                                  lat = (coordinates[1] as num).toDouble();
                                } else if (item['point'] != null) {
                                  lat = (item['point']['lat'] as num).toDouble();
                                  lon = (item['point']['lon'] as num).toDouble();
                                } else {
                                  lat = ((item['lat'] as num?) ?? 0).toDouble();
                                  lon = ((item['lon'] as num?) ?? 0).toDouble();
                                }

                                final label = ApiService.extractAddressLabel(item, preferredCity: widget.selectedCity) ?? 'Адрес';

                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: () => Navigator.of(context).pop({
                                      'lat': lat,
                                      'lon': lon,
                                      'label': label,
                                    }),
                                    child: Ink(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: _cardDark,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: _orange.withValues(alpha: 0.14),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(Icons.place_outlined, color: _orange, size: 18),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              label,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: _text, fontWeight: FontWeight.w700, height: 1.25),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
