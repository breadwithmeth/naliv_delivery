import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/onboarding_service.dart';
import '../utils/api.dart';
import '../utils/location_service.dart';
import '../utils/responsive.dart';

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
            top: safeTop + 10.s,
            left: 14.s,
            right: 14.s,
            child: _topBar(),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Transform.translate(
                  offset: Offset(0, -20.s),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12.s,
                        height: 12.s,
                        decoration: BoxDecoration(
                          color: _orange,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: _orange.withValues(alpha: 0.36), blurRadius: 18, spreadRadius: 2),
                          ],
                        ),
                      ),
                      Icon(Icons.location_on_rounded, size: 42.s, color: _orange),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 14.s,
            bottom: 148.s + safeBottom,
            child: _locateButton(),
          ),
          Positioned(
            left: 14.s,
            right: 14.s,
            bottom: 14.s + safeBottom,
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
          tileProvider: NetworkTileProvider(),
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
        borderRadius: BorderRadius.circular(16.s),
        onTap: _openSearch,
        child: Ink(
          height: 46.s,
          padding: EdgeInsets.symmetric(horizontal: 12.s),
          decoration: BoxDecoration(
            color: _card.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(16.s),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.24), blurRadius: 16, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: _textMute),
              SizedBox(width: 8.s),
              Expanded(
                child: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _text, fontSize: 13.sp, fontWeight: FontWeight.w700),
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
        borderRadius: BorderRadius.circular(16.s),
        onTap: onTap,
        child: Ink(
          width: 46.s,
          height: 46.s,
          decoration: BoxDecoration(
            color: _card.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(16.s),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Icon(icon, color: _text, size: 16.s),
        ),
      ),
    );
  }

  Widget _locateButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16.s),
        onTap: _isLocatingUser ? null : _centerOnUserLocation,
        child: Ink(
          width: 46.s,
          height: 46.s,
          decoration: BoxDecoration(
            color: _card.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(16.s),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: _isLocatingUser
              ? Padding(
                  padding: EdgeInsets.all(12.s),
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: _orange),
                )
              : Icon(Icons.my_location_rounded, color: _text, size: 18.s),
        ),
      ),
    );
  }

  Widget _addressCard() {
    final addressLabel =
        _isResolvingAddress ? 'Ищем адрес...' : (_currentAddress.trim().isEmpty ? 'Подвиньте карту немного' : _currentAddress.trim());

    return Container(
      padding: EdgeInsets.all(12.s),
      decoration: BoxDecoration(
        color: _cardDark.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(22.s),
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
            style: TextStyle(color: _text, fontSize: 15.sp, fontWeight: FontWeight.w800, height: 1.25),
          ),
          SizedBox(height: 7.s),
          Text(
            'Сначала подтвердите точку на карте, затем добавьте подъезд, этаж и квартиру на следующем шаге.',
            style: TextStyle(color: _textMute, fontSize: 12.sp, height: 1.35),
          ),
          SizedBox(height: 10.s),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isResolvingAddress ? null : _confirmAddress,
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.black,
                disabledBackgroundColor: _orange.withValues(alpha: 0.55),
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 14.s),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.s)),
              ),
              child: Text(
                _isResolvingAddress ? 'Определяем...' : 'Подтвердить адрес',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900),
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
      resizeToAvoidBottomInset: false,
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
            padding: EdgeInsets.fromLTRB(14.s, 10.s, 14.s, bottomInset + 14.s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16.s),
                        onTap: () => Navigator.of(context).pop(),
                        child: Ink(
                          width: 46.s,
                          height: 46.s,
                          decoration: BoxDecoration(
                            color: _card.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(16.s),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: Icon(Icons.arrow_back_ios_new_rounded, color: _text, size: 16.s),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.s),
                    Expanded(
                      child: Text(
                        'Детали адреса',
                        style: TextStyle(color: _text, fontSize: 22.sp, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.s),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(14.s),
                  decoration: BoxDecoration(
                    color: _cardDark,
                    borderRadius: BorderRadius.circular(22.s),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Выбранный адрес',
                        style: TextStyle(color: _textMute, fontSize: 12.sp, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 7.s),
                      Text(
                        widget.address,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _text, fontSize: 15.sp, fontWeight: FontWeight.w800, height: 1.35),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 18.s),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _detailsField(
                          controller: _entranceController,
                          label: 'Подъезд',
                          hint: 'Например, 2 или 2А',
                          icon: Icons.stairs_rounded,
                        ),
                        SizedBox(height: 12.s),
                        _detailsField(
                          controller: _floorController,
                          label: 'Этаж',
                          hint: 'Например, 7 или м',
                          icon: Icons.layers_rounded,
                        ),
                        SizedBox(height: 12.s),
                        _detailsField(
                          controller: _apartmentController,
                          label: 'Квартира',
                          hint: 'Например, 45 или 45Б',
                          icon: Icons.door_front_door_rounded,
                        ),
                        SizedBox(height: 12.s),
                        Text(
                          'Можно заполнить сейчас или позже на этапе оформления заказа. Буквы тоже подойдут: корпус, секция, подъезд А, кв. 12Б.',
                          style: TextStyle(color: _textMute, fontSize: 12.sp, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 14.s),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orange,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 14.s),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.s)),
                    ),
                    child: Text(
                      'Подтвердить и выбрать адрес',
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900),
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
        Text(label, style: TextStyle(color: _text, fontSize: 13.sp, fontWeight: FontWeight.w800)),
        SizedBox(height: 7.s),
        TextField(
          controller: controller,
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.characters,
          style: TextStyle(color: _text, fontSize: 14.sp, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _textMute),
            prefixIcon: Icon(icon, color: _orange),
            filled: true,
            fillColor: _card,
            contentPadding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 14.s),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.s),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.s),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(16.s)),
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
              padding: EdgeInsets.fromLTRB(14.s, 10.s, 14.s, 7.s),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: _text, size: 16.s),
                  ),
                  Expanded(
                    child: Container(
                      height: 46.s,
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(16.s),
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
                          contentPadding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 12.s),
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
                              padding: EdgeInsets.fromLTRB(14.s, 7.s, 14.s, 14.s),
                              itemCount: _results.length,
                              separatorBuilder: (_, __) => SizedBox(height: 7.s),
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
                                    borderRadius: BorderRadius.circular(16.s),
                                    onTap: () => Navigator.of(context).pop({
                                      'lat': lat,
                                      'lon': lon,
                                      'label': label,
                                    }),
                                    child: Ink(
                                      padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 12.s),
                                      decoration: BoxDecoration(
                                        color: _cardDark,
                                        borderRadius: BorderRadius.circular(16.s),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 32.s,
                                            height: 32.s,
                                            decoration: BoxDecoration(
                                              color: _orange.withValues(alpha: 0.14),
                                              borderRadius: BorderRadius.circular(10.s),
                                            ),
                                            child: Icon(Icons.place_outlined, color: _orange, size: 16.s),
                                          ),
                                          SizedBox(width: 10.s),
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
