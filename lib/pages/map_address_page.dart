import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:naliv_delivery/shared/app_theme.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import '../utils/address_storage_service.dart';

/// Страница для уточнения адреса на карте
class MapAddressPage extends StatefulWidget {
  final double initialLat;
  final double initialLon;
  final Function(Map<String, dynamic>) onAddressSelected;

  const MapAddressPage({
    Key? key,
    required this.initialLat,
    required this.initialLon,
    required this.onAddressSelected,
  }) : super(key: key);

  @override
  State<MapAddressPage> createState() => _MapAddressPageState();
}

class _MapAddressPageState extends State<MapAddressPage> with TickerProviderStateMixin {
  late LatLng _markerPos;
  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  bool _isSheetExpanded = false;
  // Current address string from reverse geocoding
  String _currentAddress = '';
  // Controllers for additional address details
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _apartmentController = TextEditingController();
  final TextEditingController _entranceController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _markerPos = LatLng(widget.initialLat, widget.initialLon);
    // Get initial address
    _reverseAddress(_markerPos.latitude, _markerPos.longitude);
    _sheetController.addListener(() {
      if (_sheetController.size > .7) {
        // _sheetController.animateTo(
        //   0.85,
        //   duration: const Duration(milliseconds: 300),
        //   curve: Curves.easeInOut,
        // );
        setState(() {
          _isSheetExpanded = true;
        });
      } else {
        setState(() {
          _isSheetExpanded = false;
        });
      }
    });
  }

  void _reverseAddress(double lat, double lon) async {
    final addressData = await ApiService.searchAddresses(
      lat: lat,
      lon: lon,
    );
    // Update current address text
    if (addressData != null && addressData.isNotEmpty) {
      final result = ApiService.extractAddressLabel(
            addressData.first,
            lat: lat,
            lon: lon,
          ) ??
          'Адрес не найден';
      if (mounted) {
        setState(() {
          _currentAddress = result;
          _addressController.text = result;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _currentAddress = 'Адрес не найден';
          _addressController.text = 'Адрес не найден';
        });
      }
    }
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _addressController.dispose();
    _apartmentController.dispose();
    _entranceController.dispose();
    _floorController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double safeTop = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.text,
        title: const Text('Добавить адрес', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _openSearch,
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Column(
            children: [
              Expanded(
                flex: 7,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _markerPos,
                        initialZoom: 16.0,
                        onPointerUp: (event, point) {
                          setState(() {
                            _markerPos = _mapController.camera.center;
                          });
                          _reverseAddress(_markerPos.latitude, _markerPos.longitude);
                        },
                        onTap: (tapPos, latlng) {
                          setState(() {
                            _markerPos = latlng;
                          });
                          _reverseAddress(latlng.latitude, latlng.longitude);
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile3.maps.2gis.com/tiles?x={x}&y={y}&z={z}',
                          subdomains: ['tile0', 'tile1', 'tile2', 'tile3'],
                          tileProvider: CancellableNetworkTileProvider(),
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _markerPos,
                              width: 48,
                              height: 48,
                              child: const Icon(Icons.location_on, size: 40, color: AppColors.orange),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      top: safeTop + kToolbarHeight + 6,
                      left: 16,
                      right: 16,
                      child: _searchOverlay(),
                    ),
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Column(
                        children: [
                          _roundIconButton(icon: Icons.add, onTap: () => _zoom(delta: 1)),
                          const SizedBox(height: 10),
                          _roundIconButton(icon: Icons.remove, onTap: () => _zoom(delta: -1)),
                          const SizedBox(height: 10),
                          _roundIconButton(icon: Icons.gps_fixed, onTap: () => _reverseAddress(_markerPos.latitude, _markerPos.longitude)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
          _deliveryHereChip(top: safeTop + kToolbarHeight + 70),
          _sheet(),
        ],
      ),
    );
  }

  void _zoom({required double delta}) {
    final current = _mapController.camera.zoom;
    _mapController.move(_markerPos, current + delta);
  }

  Future<void> _openSearch() async {
    final selected = await showDialog<Map<String, dynamic>>(
      useSafeArea: true,
      context: context,
      builder: (context) {
        List<Map<String, dynamic>> results = [];
        String query = '';
        return Dialog(
          insetPadding: const EdgeInsets.all(10),
          backgroundColor: AppColors.card,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: ListView(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Поиск адреса', style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800)),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.text),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      autofocus: true,
                      style: const TextStyle(color: AppColors.text),
                      decoration: InputDecoration(
                        hintText: 'Введите адрес',
                        hintStyle: const TextStyle(color: AppColors.textMute),
                        filled: true,
                        fillColor: AppColors.cardDark,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search, color: AppColors.orange),
                          onPressed: () async {
                            final res = await ApiService.searchAddressByText(query);
                            if (res != null) {
                              setModalState(() => results = res);
                            }
                          },
                        ),
                      ),
                      onChanged: (v) async {
                        query = v;
                        final res = await ApiService.searchAddressByText(query);
                        if (res != null) {
                          setModalState(() => results = res);
                        }
                      },
                      onSubmitted: (v) => query = v,
                    ),
                    const SizedBox(height: 12),
                    ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      primary: false,
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final item = results[i];
                        double lat, lon;
                        if (item['geometry'] != null && item['geometry']['coordinates'] is List) {
                          final coords = item['geometry']['coordinates'] as List;
                          lon = (coords[0] as num).toDouble();
                          lat = (coords[1] as num).toDouble();
                        } else if (item['point'] != null) {
                          lat = (item['point']['lat'] as num).toDouble();
                          lon = (item['point']['lon'] as num).toDouble();
                        } else {
                          lat = ((item['lat'] as num?) ?? 0).toDouble();
                          lon = ((item['lon'] as num?) ?? 0).toDouble();
                        }
                        String name;
                        if (item['properties'] != null && item['properties']['geocoding'] != null) {
                          name = (item['properties']['geocoding']['label'] as String?) ?? '';
                        } else {
                          name = (item['display_name'] as String?) ?? (item['label'] as String?) ?? '';
                        }
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          title: Text(name, style: const TextStyle(color: AppColors.text)),
                          onTap: () {
                            setModalState(() {
                              _isSheetExpanded = true;
                              _sheetController.animateTo(0.85, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                            });
                            Navigator.of(context).pop({'lat': lat, 'lon': lon});
                          },
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (selected != null) {
      setState(() {
        _markerPos = LatLng(selected['lat']!, selected['lon']!);
      });
      _mapController.move(_markerPos, 16.0);
      _reverseAddress(selected['lat']!, selected['lon']!);
    }
  }

  Widget _searchOverlay() {
    return GestureDetector(
      onTap: _openSearch,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: const [
            Icon(Icons.search, color: AppColors.textMute),
            SizedBox(width: 10),
            Expanded(
              child: Text('Поиск города, улицы или дома', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundIconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, color: AppColors.text, size: 20),
      ),
    );
  }

  Widget _deliveryHereChip({required double top}) {
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.orange,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
          ),
          child: const Text('Доставка сюда', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }

  Widget _sheet() {
    return DraggableScrollableSheet(
      snap: true,
      controller: _sheetController,
      initialChildSize: 0.4,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        final handle = Center(
          child: Container(
            width: 44,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(30)),
          ),
        );

        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 24, offset: const Offset(0, -12))],
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              handle,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Детали адреса', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(_currentAddress.isNotEmpty ? _currentAddress : 'Загрузка адреса...',
                        style: const TextStyle(color: AppColors.textMute, fontSize: 14)),
                    const SizedBox(height: 14),
                    _inputField(label: 'Улица и номер дома', controller: _addressController, hint: 'ул. Пушкина, 10'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _inputField(label: 'Кв/Офис', controller: _apartmentController, hint: '42')),
                        const SizedBox(width: 10),
                        Expanded(child: _inputField(label: 'Подъезд', controller: _entranceController, hint: '2')),
                        const SizedBox(width: 10),
                        Expanded(child: _inputField(label: 'Этаж', controller: _floorController, hint: '5')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _inputField(label: 'Комментарий', controller: _commentController, hint: 'Позвонить за 5 минут'),
                    const SizedBox(height: 16),
                    _primaryButton('Установить адрес', onPressed: _saveAddress),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _inputField({required String label, required TextEditingController controller, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMute, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textMute),
            filled: true,
            fillColor: AppColors.card,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.orange),
            ),
          ),
        ),
      ],
    );
  }

  Widget _primaryButton(String label, {required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(colors: [Color(0xFF8B1F1E), AppColors.red]),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 10)),
          ],
        ),
        child: Center(
          child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }

  Future<void> _saveAddress() async {
    final data = {
      'lat': _markerPos.latitude,
      'lon': _markerPos.longitude,
      'address': _addressController.text.isNotEmpty ? _addressController.text : _currentAddress,
      'apartment': _apartmentController.text,
      'entrance': _entranceController.text,
      'floor': _floorController.text,
      'comment': _commentController.text,
    };
    await AddressStorageService.saveSelectedAddress(data);
    await AddressStorageService.addToAddressHistory({
      'name': data['address'],
      'point': {'lat': data['lat'], 'lon': data['lon']},
      'apartment': data['apartment'],
      'entrance': data['entrance'],
      'floor': data['floor'],
      'comment': data['comment'],
    });
    widget.onAddressSelected(data);
    if (mounted) Navigator.of(context).pop();
  }
}
