import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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

class _MapAddressPageState extends State<MapAddressPage>
    with TickerProviderStateMixin {
  late LatLng _markerPos;
  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  bool _isSheetExpanded = false;
  // Current address string from reverse geocoding
  String _currentAddress = '';
  // Controllers for additional address details
  final TextEditingController _apartmentController = TextEditingController();
  final TextEditingController _entranceController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _markerPos = LatLng(widget.initialLat, widget.initialLon);
    // Get initial address
    _reverseAddress(_markerPos.latitude, _markerPos.longitude);
    _sheetController.addListener(() {
      print(_sheetController.size);
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
    print(addressData);
    // Update current address text
    if (addressData != null && addressData.isNotEmpty) {
      final first = addressData.first;
      String result;
      // Check if this is a GeoJSON FeatureCollection
      if (first.containsKey('features') && first['features'] is List) {
        final features = first['features'] as List<dynamic>;
        if (features.isNotEmpty) {
          final feature = features.first as Map<String, dynamic>;
          final properties = feature['properties'] as Map<String, dynamic>;
          final geo = properties['geocoding'] as Map<String, dynamic>;
          // Extract relevant fields
          final streetVal = geo['street']?.toString() ?? '';
          final houseVal = geo['housenumber']?.toString() ?? '';
          final districtVal = geo['district']?.toString() ?? '';
          final cityVal = geo['city']?.toString() ?? '';
          final nameVal = geo['name']?.toString() ?? '';

          // Build single-line address: city, street, house
          final parts = <String>[];
          if (nameVal.isNotEmpty) parts.add(nameVal);
          if (streetVal.isNotEmpty) parts.add(' $streetVal');
          if (houseVal.isNotEmpty) {
            parts.add('дом $houseVal');
          } else {
            // Use coordinates if no house number
            parts.add('${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}');
          }
          if (districtVal.isNotEmpty) parts.add(districtVal);
          if (cityVal.isNotEmpty) parts.add(cityVal);

          result = parts.join(', ');
        } else {
          result = 'Адрес не найден';
        }
      } else {
        // Fallback to display_name
        result = first['display_name'] as String? ?? '';
      }
      setState(() {
        _currentAddress = result;
      });
    } else {
      setState(() {
        _currentAddress = 'Адрес не найден';
      });
    }
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _apartmentController.dispose();
    _entranceController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Выберите адрес на карте'),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () async {
                // Open simple dialog for text-based address search
                final selected = await showDialog<Map<String, dynamic>>(
                  useSafeArea: true,
                  context: context,
                  builder: (context) {
                    List<Map<String, dynamic>> results = [];
                    String query = '';
                    return Dialog(
                      insetPadding: EdgeInsets.all(8),
                      child: StatefulBuilder(
                        builder: (context, setModalState) {
                          return Container(
                            padding: const EdgeInsets.all(8),
                            child: ListView(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Поиск адреса',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                    ),
                                  ],
                                ),
                                TextField(
                                  autofocus: true,
                                  decoration: InputDecoration(
                                    hintText: 'Введите адрес',
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.search),
                                      onPressed: () async {
                                        final res = await ApiService
                                            .searchAddressByText(query);
                                        if (res != null) {
                                          setModalState(() => results = res);
                                        }
                                      },
                                    ),
                                  ),
                                  onChanged: (v) async {
                                    query = v;
                                    final res =
                                        await ApiService.searchAddressByText(
                                            query);
                                    if (res != null) {
                                      setModalState(() => results = res);
                                    }
                                  },
                                  onSubmitted: (v) => query = v,
                                ),
                                ListView.builder(
                                  physics: NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  primary: false,
                                  itemCount: results.length,
                                  itemBuilder: (context, i) {
                                    final item = results[i];
                                    double lat, lon;
                                    if (item['geometry'] != null &&
                                        item['geometry']['coordinates']
                                            is List) {
                                      final coords = item['geometry']
                                          ['coordinates'] as List;
                                      lon = (coords[0] as num).toDouble();
                                      lat = (coords[1] as num).toDouble();
                                    } else if (item['point'] != null) {
                                      lat = (item['point']['lat'] as num)
                                          .toDouble();
                                      lon = (item['point']['lon'] as num)
                                          .toDouble();
                                    } else {
                                      lat = ((item['lat'] as num?) ?? 0)
                                          .toDouble();
                                      lon = ((item['lon'] as num?) ?? 0)
                                          .toDouble();
                                    }
                                    String name;
                                    if (item['properties'] != null &&
                                        item['properties']['geocoding'] !=
                                            null) {
                                      name = (item['properties']['geocoding']
                                              ['label'] as String?) ??
                                          '';
                                    } else {
                                      name =
                                          (item['display_name'] as String?) ??
                                              (item['label'] as String?) ??
                                              '';
                                    }
                                    return ListTile(
                                      contentPadding: EdgeInsets.all(4),
                                      title: Text(name),
                                      onTap: () {
                                        setState(() {
                                          _isSheetExpanded = true;
                                          _sheetController.animateTo(0.85,
                                              duration: const Duration(
                                                  milliseconds: 300),
                                              curve: Curves.easeInOut);
                                        });
                                        Navigator.of(context)
                                            .pop({'lat': lat, 'lon': lon});
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
              },
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
                            onPointerUp: (event, point) {
                              print(point);
                              setState(() {
                                _markerPos = _mapController.camera.center;
                                _reverseAddress(
                                    _markerPos.latitude, _markerPos.longitude);
                              });
                            },
                            onPositionChanged: (position, hasGesture) {
                              if (!hasGesture) {}
                            },
                            center: _markerPos,
                            zoom: 16.0,
                            onTap: (tapPos, latlng) {
                              setState(() {
                                _markerPos = latlng;
                              });
                            },
                          ),
                          children: [
                            TileLayer(
                              // tileBuilder: _darkModeTileBuilder,
                              urlTemplate:
                                  'https://tile3.maps.2gis.com/tiles?x={x}&y={y}&z={z}',
                              subdomains: ['tile0', 'tile1', 'tile2', 'tile3'],

                              // urlTemplate:
                              //     'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              // urlTemplate:
                              //     'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                              tileProvider: CancellableNetworkTileProvider(),
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _markerPos,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.circle,
                                    size: 20,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Center(
                          child: Icon(
                            Icons.circle_outlined,
                            size: 20,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    )),
                Spacer(
                  flex: 3,
                )
              ],
            ),
            // Draggable bottom sheet
            DraggableScrollableSheet(
              snap: true,
              controller: _sheetController,
              initialChildSize: 0.4,
              minChildSize: 0.4,
              maxChildSize: 0.85,
              builder:
                  (BuildContext context, ScrollController scrollController) {
                return !_isSheetExpanded
                    ? Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 15,
                              spreadRadius: 5,
                            ),
                          ],
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: ListView(
                          controller: scrollController,
                          children: [
                            // Drag handle
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                margin: EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[400],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            // After address display
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                _currentAddress.isNotEmpty
                                    ? _currentAddress
                                    : 'Загрузка адреса...',
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900),
                              ),
                            ),
                            // Apartment, entrance, comment inputs

                            // select button
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: ElevatedButton(
                                onPressed: () {
                                  _sheetController.animateTo(
                                    0.85,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: Text('Выбрать этот адрес'),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: ListView(
                          controller: scrollController,
                          children: [
                            // Drag handle
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                margin: EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[400],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            // After address display
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                _currentAddress.isNotEmpty
                                    ? _currentAddress
                                    : 'Загрузка адреса...',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            // Apartment, entrance, comment inputs
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 8.0),
                              child: TextField(
                                controller: _apartmentController,
                                decoration: InputDecoration(
                                  labelText: 'Квартира',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 8.0),
                              child: TextField(
                                controller: _entranceController,
                                decoration: InputDecoration(
                                  labelText: 'Подъезд',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 8.0),
                              child: TextField(
                                controller: _commentController,
                                decoration: InputDecoration(
                                  labelText: 'Комментарий',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: ElevatedButton(
                                onPressed: () async {
                                  // Build full address data
                                  final data = {
                                    'lat': _markerPos.latitude,
                                    'lon': _markerPos.longitude,
                                    'address': _currentAddress,
                                    'apartment': _apartmentController.text,
                                    'entrance': _entranceController.text,
                                    'comment': _commentController.text,
                                  };
                                  // Save as selected address
                                  await AddressStorageService
                                      .saveSelectedAddress(data);
                                  // Add to address history
                                  await AddressStorageService
                                      .addToAddressHistory({
                                    'name': data['address'],
                                    'point': {
                                      'lat': data['lat'],
                                      'lon': data['lon']
                                    },
                                    'apartment': data['apartment'],
                                    'entrance': data['entrance'],
                                    'comment': data['comment'],
                                  });
                                  // Notify upstream via callback
                                  widget.onAddressSelected(data);
                                  // Close the map page
                                  Navigator.of(context).pop();
                                },
                                child: Text('Выбрать этот адрес'),
                              ),
                            ),
                          ],
                        ),
                      );
              },
            ),
          ],
        ));
  }
}
