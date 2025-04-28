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
    // Показываем индикатор загрузки, если нужно
    // setState(() { _isLoading = true; });

    try {
      final value = await getGeoData(search);
      print(
          'API Response (count: ${value.length}):'); // Логируем количество полученных адресов
      // print(value); // Можно раскомментировать для детального просмотра ответа

      List formattedAddresses = [];

      for (var item in value) {
        try {
          // Проверяем наличие необходимых ключей перед доступом
          if (item != null &&
              item["metaDataProperty"] != null &&
              item["metaDataProperty"]["GeocoderMetaData"] != null &&
              item["metaDataProperty"]["GeocoderMetaData"]["Address"] != null &&
              item["Point"] != null &&
              item["Point"]["pos"] != null) {
            var geoData = item["metaDataProperty"]["GeocoderMetaData"];
            var address = geoData["Address"];
            var pointData = item["Point"]["pos"].split(" ");

            // Дополнительная проверка на корректность координат
            if (pointData.length == 2) {
              formattedAddresses.add({
                "name": address["formatted"] ??
                    "Адрес не указан", // Добавляем ?? для безопасности
                "full_address": geoData["text"] ?? "Полный адрес не указан",
                "components":
                    address["Components"] ?? [], // Пустой список по умолчанию
                "point": {
                  "lat": double.tryParse(pointData[1]) ??
                      0.0, // Безопасное преобразование
                  "lon": double.tryParse(pointData[0]) ?? 0.0,
                },
                "precision": geoData["precision"] ?? "unknown",
                "kind": geoData["kind"] ?? "unknown",
              });
            } else {
              print('Skipping item due to invalid point data: $item');
            }
          } else {
            print('Skipping item due to missing keys: $item');
          }
        } catch (e, stackTrace) {
          // Логируем ошибку и элемент, который ее вызвал
          print('Error processing address item: $e');
          print('Problematic item: $item');
          print('Stack trace: $stackTrace');
          // Можно решить, пропускать ли этот элемент или остановить обработку
        }
      }

      print(
          'Formatted Addresses Count: ${formattedAddresses.length}'); // Логируем количество успешно обработанных

      // Обновляем состояние только если виджет все еще активен
      if (mounted) {
        setState(() {
          addresses = formattedAddresses;
          // _isLoading = false; // Скрываем индикатор загрузки
        });
      }
    } catch (error, stackTrace) {
      // Обрабатываем ошибку самого запроса getGeoData
      print('Error fetching or processing geo data: $error');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          addresses = []; // Очищаем список в случае ошибки
          // _isLoading = false; // Скрываем индикатор загрузки
        });
        // Можно показать сообщение об ошибке пользователю
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
        'Can pop: ${Navigator.canPop(context)}'); // Добавьте эту строку для отладки
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle:
            Text('Новый адрес', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: CupertinoColors.systemBackground.withOpacity(0.8),
        border: null,
        automaticallyImplyLeading: true,
        // leading: CupertinoButton(
        //   padding: EdgeInsets.zero,
        //   child: Icon(CupertinoIcons.back),
        //   onPressed: () => Navigator.pop(context),
        // ),
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
                                  CupertinoColors.systemGrey.withOpacity(0.15),
                              blurRadius: 15,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CupertinoSearchTextField(
                            controller: _searchController,
                            onSubmitted: searchGeoDataByString,
                            placeholder: 'Введите название улицы или район',
                            backgroundColor: CupertinoColors.systemBackground,
                            prefixIcon: Icon(
                              CupertinoIcons.search,
                              color: CupertinoColors.activeBlue,
                            ),
                            suffixIcon: Icon(
                              CupertinoIcons.clear_circled_solid,
                              color: CupertinoColors.systemGrey,
                            ),
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      if (addresses.isNotEmpty)
                        Expanded(
                          child: Container(
                            margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: CupertinoColors.systemBackground
                                  .resolveFrom(context),
                              boxShadow: [
                                BoxShadow(
                                  color: CupertinoColors.systemGrey
                                      .withOpacity(0.15),
                                  blurRadius: 15,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: ListView.separated(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                itemCount: addresses.length,
                                separatorBuilder: (context, index) => Container(
                                  height: 1,
                                ),
                                itemBuilder: (context, index) {
                                  return CupertinoListTile(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical:
                                          12, // Уменьшил отступ для компактности
                                    ),
                                    leadingToTitle:
                                        16, // Увеличил отступ между иконкой и текстом
                                    leading: Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: CupertinoColors.activeBlue
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        CupertinoIcons.location_solid,
                                        color: CupertinoColors.activeBlue,
                                        size: 20,
                                      ),
                                    ),
                                    title: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Страна и город
                                        Text(
                                          [
                                            addresses[index]["components"]
                                                .firstWhere(
                                                    (c) =>
                                                        c["kind"] == "country",
                                                    orElse: () =>
                                                        {"name": ""})["name"],
                                            addresses[index]["components"]
                                                .firstWhere(
                                                    (c) =>
                                                        c["kind"] == "locality",
                                                    orElse: () =>
                                                        {"name": ""})["name"],
                                          ]
                                              .where((e) => e.isNotEmpty)
                                              .join(", "),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: CupertinoColors.systemGrey,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        // Основной адрес из компонентов
                                        Text(
                                          [
                                            addresses[index]["components"]
                                                .firstWhere(
                                                    (c) =>
                                                        c["kind"] == "street",
                                                    orElse: () =>
                                                        {"name": ""})["name"],
                                            addresses[index]["components"]
                                                .firstWhere(
                                                    (c) => c["kind"] == "house",
                                                    orElse: () =>
                                                        {"name": ""})["name"],
                                          ]
                                              .where((e) => e.isNotEmpty)
                                              .join(", "),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        // Дополнительная информация о районе если есть
                                        if (addresses[index]["components"].any(
                                            (c) => c["kind"] == "district"))
                                          Text(
                                            addresses[index]["components"]
                                                .firstWhere((c) =>
                                                    c["kind"] ==
                                                    "district")["name"],
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: CupertinoColors.systemGrey,
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: Padding(
                                      padding: EdgeInsets.only(
                                          left: 8), // Отступ от текста
                                      child: Icon(
                                        CupertinoIcons.chevron_right,
                                        color: CupertinoColors.systemGrey,
                                      ),
                                    ),
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
