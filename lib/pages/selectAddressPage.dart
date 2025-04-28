import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/createAddressPage.dart';
import 'package:naliv_delivery/pages/mainPage.dart';
import 'package:naliv_delivery/pages/preLoadOrderPage.dart';
import 'package:naliv_delivery/pages/selectBusinessesPage.dart';
import 'package:naliv_delivery/shared/loadingScreen.dart';
import 'package:flutter/cupertino.dart';

class SelectAddressPage extends StatefulWidget {
  const SelectAddressPage(
      {super.key,
      required this.addresses,
      required this.currentAddress,
      required this.createOrder,
      required this.business});
  final List addresses;
  final Map currentAddress;
  final bool createOrder;
  final Map? business;
  @override
  State<SelectAddressPage> createState() => _SelectAddressPageState();
}

class _SelectAddressPageState extends State<SelectAddressPage> {
  bool _isLoading = false;
  List addresses = [];
  Future<List> _getBusinesses() async {
    List businesses = await getBusinesses();
    //print(businesses);
    if (businesses == null) {
      return [];
    } else {
      return businesses;
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    determinePosition(context).then((v) {
      //print(v);
    });
    if (mounted) {
      setState(() {
        addresses = widget.addresses;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Выбор адреса',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
        border: null,
        // leading: CupertinoButton(
        //   padding: EdgeInsets.zero,
        //   child: Icon(CupertinoIcons.back),
        //   onPressed: () => Navigator.pop(context),
        // ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CupertinoColors.activeBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              CupertinoIcons.add,
              color: CupertinoColors.activeBlue,
            ),
          ),
          onPressed: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => CreateAddressPage(
                  createOrder: widget.createOrder,
                  business: widget.business,
                ),
              ),
            );
          },
        ),
      ),
      child: _isLoading
          ? Center(child: CupertinoActivityIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.currentAddress["lat"] != null) ...[
                    SizedBox(height: 16),
                    // Карта с тенью
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: CupertinoColors.systemGrey.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 200,
                          child: FlutterMap(
                            options: MapOptions(
                              interactionOptions: InteractionOptions(
                                flags: InteractiveFlag.none,
                              ),
                              initialZoom: 18,
                              initialCenter: LatLng(
                                double.parse(
                                    widget.currentAddress["lat"] ?? "0"),
                                double.parse(
                                    widget.currentAddress["lon"] ?? "0"),
                              ),
                            ),
                            children: [
                              TileLayer(
                                tileBuilder:
                                    MediaQuery.platformBrightnessOf(context) ==
                                            Brightness.dark
                                        ? _darkModeTileBuilder
                                        : null,
                                urlTemplate:
                                    'https://{s}.maps.2gis.com/tiles?x={x}&y={y}&z={z}',
                                subdomains: [
                                  'tile0',
                                  'tile1',
                                  'tile2',
                                  'tile3'
                                ],
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    width: 40,
                                    height: 40,
                                    point: LatLng(
                                      double.parse(
                                          widget.currentAddress["lat"] ?? "0"),
                                      double.parse(
                                          widget.currentAddress["lon"] ?? "0"),
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
                    ),
                    SizedBox(height: 24),

                    // Текущий адрес
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemBackground
                            .resolveFrom(context),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: CupertinoColors.systemGrey.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Текущий адрес",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            widget.currentAddress["city_name"] ??
                                "Этого города еще нет в базе",
                            style: TextStyle(
                              fontSize: 15,
                              color: CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            widget.currentAddress["address"] ?? "",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),

                    // Кнопка продолжить
                    Container(
                      width: double.infinity,
                      child: CupertinoButton.filled(
                        borderRadius: BorderRadius.circular(12),
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                          });
                          _getBusinesses().then((v) {
                            if (widget.createOrder) {
                              Navigator.pushReplacement(context,
                                  CupertinoPageRoute(builder: (context) {
                                return PreLoadOrderPage(
                                    business: widget.business!);
                              }));
                            } else {
                              // //print(v);
                              // v.sort((a, b) => a['distance']
                              //     .compareTo(b['distance']));
                              // Map closestBusijess = v.where(
                              //   (element) {

                              //   },
                              // );

                              var min = v[0];
                              v.forEach((item) {
                                if (double.parse(item['distance']) <
                                    double.parse(min['distance'])) min = item;
                              });
                              //print(min['distance']);
                              //print(v);
                              Map closestBusijess = min;
                              //print(closestBusijess);
                              getUser().then((user) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) {
                                      return MainPage(
                                          businesses: v,
                                          currentAddress: widget.currentAddress,
                                          user: user!,
                                          business: closestBusijess);
                                    },
                                  ),
                                  (Route<dynamic> route) => false,
                                );
                              });
                              Navigator.push(context, CupertinoPageRoute(
                                builder: (context) {
                                  return SelectBusinessesPage(
                                    businesses: v,
                                    currentAddress: widget.currentAddress,
                                  );
                                },
                              ));
                              setState(() {
                                _isLoading = false;
                              });
                            }
                          });
                        },
                        child: Text(
                          "Продолжить",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 32),
                  ],

                  // Сохраненные адреса
                  Padding(
                    padding: EdgeInsets.only(left: 16, bottom: 16),
                    child: Text(
                      "Сохраненные адреса",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.label,
                      ),
                    ),
                  ),

                  // Список адресов
                  Container(
                    decoration: BoxDecoration(
                      color:
                          CupertinoColors.systemBackground.resolveFrom(context),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.systemGrey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        children: addresses.map((address) {
                          return Column(
                            children: [
                              CupertinoListTile(
                                padding: EdgeInsets.all(16),
                                leading: Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.activeBlue
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    CupertinoIcons.location,
                                    color: CupertinoColors.activeBlue,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  address["address"],
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                                subtitle: Text(
                                  address["city_name"] ??
                                      "Этого города еще нет в базе",
                                  style: TextStyle(
                                    color: CupertinoColors.secondaryLabel
                                        .resolveFrom(context),
                                    fontSize: 14,
                                  ),
                                ),
                                trailing: Icon(
                                  CupertinoIcons.chevron_right,
                                  color: CupertinoColors.systemGrey3
                                      .resolveFrom(context),
                                  size: 20,
                                ),
                                onTap: () async {
                                  setState(() {
                                    _isLoading =
                                        true; // Показываем индикатор загрузки
                                  });

                                  try {
                                    await selectAddress(address["address_id"]);
                                    final addresses = await getAddresses();

                                    if (mounted) {
                                      Navigator.pushReplacement(
                                        context,
                                        CupertinoPageRoute(
                                          builder: (context) =>
                                              SelectAddressPage(
                                            addresses: addresses,
                                            currentAddress:
                                                addresses.firstWhere(
                                              (element) =>
                                                  element["is_selected"] == "1",
                                              orElse: () => {},
                                            ),
                                            createOrder: widget.createOrder,
                                            business: widget.business,
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      showCupertinoDialog(
                                        context: context,
                                        builder: (context) =>
                                            CupertinoAlertDialog(
                                          title: Text('Ошибка'),
                                          content:
                                              Text('Не удалось выбрать адрес'),
                                          actions: [
                                            CupertinoDialogAction(
                                              child: Text('OK'),
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _isLoading =
                                            false; // Скрываем индикатор загрузки
                                      });
                                    }
                                  }
                                },
                              ),
                              if (address != addresses.last)
                                Divider(
                                  height: 1,
                                  indent: 60,
                                ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  SizedBox(height: 32),
                ],
              ),
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
