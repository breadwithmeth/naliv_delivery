import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class PickOnMapPage extends StatefulWidget {
  const PickOnMapPage({super.key, required this.currentPosition});
  final Position currentPosition;
  @override
  State<PickOnMapPage> createState() => _PickOnMapPageState();
}

class _PickOnMapPageState extends State<PickOnMapPage> {
  MapController _mapController = MapController();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _mapController.move(
          LatLng(widget.currentPosition.latitude,
              widget.currentPosition.longitude),
          15);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
              child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(widget.currentPosition.latitude,
                  widget.currentPosition.longitude),
              initialZoom: 9.2,
              onPointerDown: (event, point) {
                //   setState(() {
                //     _isAddressPicked = null;
                //   });
                // },
                // onPointerUp: (position, hasGesture) {
                //   setState(() {
                //     _isAddressPicked = false;
                //   });
              },
            ),
            children: [
              TileLayer(
                // tileBuilder: _darkModeTileBuilder,
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                tileProvider: NetworkTileProvider(),
              ),
              // MarkerLayer(markers: [
              //   Marker(point: _selectedAddress, child: FlutterLogo())
              // ]),
              // MarkerLayer(markers: _markers),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    // onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
                  ),
                ],
              ),
            ],
          ))
        ],
      ),
    );
  }
}
