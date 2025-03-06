import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/selectAddressPage.dart';

class CreateAddressPage extends StatefulWidget {
  const CreateAddressPage(
      {super.key, required this.createOrder, this.business});
  final bool createOrder;
  final Map? business;
  @override
  State<CreateAddressPage> createState() => _CreateAddressPageState();
}

class _CreateAddressPageState extends State<CreateAddressPage> {
  final TextEditingController _searchController = TextEditingController();
  List addresses = [];
  MapController mapController = MapController();

  Future<void> searchGeoDataByString(String search) async {
    await getGeoData(search).then((value) {
      setState(() {
        addresses = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Новый адрес'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    interactionOptions:
                        InteractionOptions(flags: InteractiveFlag.all),
                    initialZoom: 16,
                    initialCenter: LatLng(43.238949, 76.889709), // Алматы
                  ),
                  children: [
                    TileLayer(
                      tileProvider: CancellableNetworkTileProvider(),
                      tileBuilder: MediaQuery.platformBrightnessOf(context) ==
                              Brightness.dark
                          ? _darkModeTileBuilder
                          : null,
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: ['tile0', 'tile1', 'tile2', 'tile3'],
                    ),
                  ],
                ),
                SafeArea(
                  child: Column(
                    children: [
                      Container(
                        margin: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  CupertinoColors.systemGrey.withOpacity(0.1),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CupertinoSearchTextField(
                            controller: _searchController,
                            onSubmitted: searchGeoDataByString,
                            placeholder: 'Введите адрес',
                            backgroundColor: CupertinoColors.systemBackground,
                            prefixIcon: Icon(CupertinoIcons.search),
                            suffixIcon:
                                Icon(CupertinoIcons.clear_thick_circled),
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      if (addresses.isNotEmpty)
                        Expanded(
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: CupertinoColors.systemBackground,
                              boxShadow: [
                                BoxShadow(
                                  color: CupertinoColors.systemGrey
                                      .withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: ListView.separated(
                                itemCount: addresses.length,
                                separatorBuilder: (context, index) =>
                                    Container(),
                                itemBuilder: (context, index) {
                                  return CupertinoListTile(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    title: Text(addresses[index]["name"]),
                                    trailing:
                                        Icon(CupertinoIcons.right_chevron),
                                    onTap: () {
                                      mapController.move(
                                        LatLng(
                                          addresses[index]["point"]["lat"],
                                          addresses[index]["point"]["lon"],
                                        ),
                                        16,
                                      );
                                      Navigator.pushReplacement(
                                        context,
                                        CupertinoPageRoute(
                                          builder: (context) =>
                                              ConfirmAddressPage(
                                            currentAddress: addresses[index],
                                            createOrder: widget.createOrder,
                                            business: widget.business,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _darkModeTileBuilder(
  BuildContext context,
  Widget tileWidget,
  TileImage tile,
) {
  return ColorFiltered(
    colorFilter: const ColorFilter.matrix(<double>[
      -0.2126, -0.7152, -0.0722, 0, 255, // Red channel
      -0.2126, -0.7152, -0.0722, 0, 255, // Green channel
      -0.2126, -0.7152, -0.0722, 0, 255, // Blue channel
      0, 0, 0, 1, 0, // Alpha channel
    ]),
    child: tileWidget,
  );
}

class ConfirmAddressPage extends StatefulWidget {
  const ConfirmAddressPage(
      {super.key,
      required this.currentAddress,
      required this.createOrder,
      this.business});
  final Map currentAddress;
  final bool createOrder;
  final Map? business;
  @override
  State<ConfirmAddressPage> createState() => _ConfirmAddressPageState();
}

class _ConfirmAddressPageState extends State<ConfirmAddressPage> {
  final TextEditingController name = TextEditingController();
  final TextEditingController house = TextEditingController();
  final TextEditingController entrance = TextEditingController();
  final TextEditingController floor = TextEditingController();
  final TextEditingController other = TextEditingController();

  Future<void> _createAddress() async {
    await createAddress({
      "lat": widget.currentAddress["point"]["lat"],
      "lon": widget.currentAddress["point"]["lon"],
      "address": widget.currentAddress["name"],
      "name": name.text,
      "apartment": house.text,
      "entrance": entrance.text,
      "floor": floor.text,
      "other": other.text,
    }).then((value) {});
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Подтверждение адреса'),
      ),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              height: 200,
              child: FlutterMap(
                options: MapOptions(
                  interactionOptions:
                      InteractionOptions(flags: InteractiveFlag.none),
                  initialZoom: 18,
                  initialCenter: LatLng(
                    widget.currentAddress["point"]["lat"],
                    widget.currentAddress["point"]["lon"],
                  ),
                ),
                children: [
                  TileLayer(
                    tileBuilder: MediaQuery.platformBrightnessOf(context) ==
                            Brightness.dark
                        ? _darkModeTileBuilder
                        : null,
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: ['tile0', 'tile1', 'tile2', 'tile3'],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 40,
                        height: 40,
                        point: LatLng(
                          widget.currentAddress["point"]["lat"],
                          widget.currentAddress["point"]["lon"],
                        ),
                        child: Icon(
                          CupertinoIcons.location_solid,
                          color: CupertinoColors.activeOrange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(widget.currentAddress["name"]),
                  SizedBox(height: 16),
                  CupertinoTextField(
                    controller: entrance,
                    placeholder: "Вход/Подъезд",
                  ),
                  SizedBox(height: 8),
                  CupertinoTextField(
                    controller: house,
                    placeholder: "Офис/Кв.",
                  ),
                  SizedBox(height: 8),
                  CupertinoTextField(
                    controller: floor,
                    placeholder: "Этаж",
                  ),
                  SizedBox(height: 8),
                  CupertinoTextField(
                    controller: other,
                    placeholder: "Дополнительно",
                  ),
                  SizedBox(height: 16),
                  CupertinoButton.filled(
                    child: Text("Сохранить адрес"),
                    onPressed: () {
                      _createAddress().then((value) {
                        getAddresses().then((addresses) {
                          Navigator.pushReplacement(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => SelectAddressPage(
                                addresses: addresses,
                                currentAddress: addresses.firstWhere(
                                  (element) => element["is_selected"] == "1",
                                  orElse: () => {},
                                ),
                                createOrder: widget.createOrder,
                                business: widget.business,
                              ),
                            ),
                          );
                        });
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
