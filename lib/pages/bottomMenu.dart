import 'dart:async';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/cart_page.dart';
import 'package:naliv_delivery/pages/catalog.dart';
import 'package:naliv_delivery/pages/likedPage.dart';
import 'package:naliv_delivery/pages/mainPage.dart';
import 'package:naliv_delivery/pages/profile_page.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:naliv_delivery/utils/liked_items_provider.dart';
import 'package:naliv_delivery/utils/cartFloatingButton.dart';
import 'package:naliv_delivery/utils/location_service.dart';
import 'package:provider/provider.dart';
import 'package:naliv_delivery/widgets/address_selection_modal_material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:naliv_delivery/utils/address_storage_service.dart';

class BottomMenu extends StatefulWidget {
  const BottomMenu({super.key});

  @override
  State<BottomMenu> createState() => _BottomMenuState();
}

class _BottomMenuState extends State<BottomMenu> with LocationMixin {
  List<Map<String, dynamic>> _businesses = [];
  bool _isLoadingBusinesses = true;

  // Выбранный магазин
  Map<String, dynamic>? _selectedBusiness;

  // Выбранный адрес пользователя
  Map<String, dynamic>? _selectedAddress;

  // Данные геолокации
  Position? _userPosition;

  // Акции загружаются в MainPage

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
    _loadSavedAddress();
  }

  Future<void> _loadBusinesses() async {
    setState(() {
      _isLoadingBusinesses = true;
    });
    try {
      final data = await ApiService.getBusinesses(page: 1, limit: 20);
      if (!mounted) return;
      if (data != null && data['businesses'] != null) {
        final list = List<Map<String, dynamic>>.from(data['businesses']);
        setState(() {
          _businesses = list;
          _isLoadingBusinesses = false;
        });
        // Пытаемся выбрать ближайший магазин к текущему адресу
        _autoSelectNearestBusiness();
      } else {
        setState(() {
          _isLoadingBusinesses = false;
        });
        debugPrint('Не удалось получить список бизнесов (пустой ответ)');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingBusinesses = false;
      });
      debugPrint('Ошибка загрузки бизнесов: $e');
    }
  }

  void _selectBusiness(Map<String, dynamic> business) {
    setState(() {
      _selectedBusiness = business;
    });
    Provider.of<BusinessProvider>(context, listen: false)
        .setSelectedBusiness(business);
    final likedProvider =
        Provider.of<LikedItemsProvider>(context, listen: false);
    final businessId =
        business['id'] ?? business['business_id'] ?? business['businessId'];
    if (businessId != null) {
      likedProvider.loadLiked(int.tryParse(businessId.toString()) ?? 0);
    }
  }

  // --- ЛОГИКА АВТОВЫБОРА БЛИЖАЙШЕГО МАГАЗИНА ---

  void _autoSelectNearestBusiness({bool force = false}) {
    if (_businesses.isEmpty) return;
    if (_selectedAddress == null) {
      // Если нет адреса – fallback: если ничего не выбрано, возьмём первый для стабильности
      if (_selectedBusiness == null && _businesses.isNotEmpty) {
        _selectBusiness(_businesses.first);
        _showBusinessChangeSnack(_businesses.first, auto: true);
      }
      return;
    }

    final coords = _extractAddressLatLon(_selectedAddress!);
    if (coords == null) return;

    // Если уже выбран магазин и не принудительный выбор, проверим – вдруг он уже ближайший
    if (!force && _selectedBusiness != null) {
      // всё равно пересчитаем, чтобы понять ближайший
      final nearest = _findNearestBusiness(coords['lat']!, coords['lon']!);
      if (nearest != null && nearest['id'] != _selectedBusiness!['id']) {
        _selectBusiness(nearest);
        _showBusinessChangeSnack(nearest, auto: true);
      }
      return;
    }

    final nearest = _findNearestBusiness(coords['lat']!, coords['lon']!);
    if (nearest != null) {
      _selectBusiness(nearest);
      _showBusinessChangeSnack(nearest, auto: true);
    }
  }

  Map<String, double>? _extractAddressLatLon(Map<String, dynamic> address) {
    try {
      // Поддержка разных структур: {lat, lon} или {point: {lat, lon}}
      dynamic lat = address['lat'] ?? address['latitude'];
      dynamic lon = address['lon'] ?? address['lng'] ?? address['longitude'];
      if (lat == null || lon == null) {
        final point = address['point'];
        if (point is Map) {
          lat = point['lat'];
          lon = point['lon'] ?? point['lng'];
        }
      }
      if (lat == null || lon == null) return null;
      final dLat = double.tryParse(lat.toString());
      final dLon = double.tryParse(lon.toString());
      if (dLat == null || dLon == null) return null;
      return {'lat': dLat, 'lon': dLon};
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _findNearestBusiness(double lat, double lon) {
    Map<String, dynamic>? nearest;
    double bestDistance = double.infinity;
    for (final b in _businesses) {
      final bLat = b['lat'];
      final bLon = b['lon'];
      if (bLat == null || bLon == null) continue;
      final dLat = double.tryParse(bLat.toString());
      final dLon = double.tryParse(bLon.toString());
      if (dLat == null || dLon == null) continue;
      final dist = Geolocator.distanceBetween(lat, lon, dLat, dLon); // метры
      if (dist < bestDistance) {
        bestDistance = dist;
        nearest = b;
      }
    }
    if (nearest != null) {
      return {
        ...nearest,
        'distanceMeters': bestDistance,
      };
    }
    return null;
  }

  void _showBusinessChangeSnack(Map<String, dynamic> business,
      {bool auto = false}) {
    // Показываем уже после построения кадра, чтобы Scaffold был доступен
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final distanceM = business['distanceMeters'];
      String distanceText = '';
      if (distanceM is num) {
        final km =
            (distanceM / 1000).toStringAsFixed(distanceM >= 1000 ? 1 : 2);
        distanceText = ' ($km км)';
      }
      final text = auto
          ? 'Выбран ближайший магазин: ${business['name']}$distanceText'
          : 'Магазин изменён: ${business['name']}$distanceText';
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(text),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Изменить',
              onPressed: () {
                // Открываем селектор магазинов через MainPage (там уже есть логика)
                // Можно навигацией или callback; упрощённо ничего не делаем здесь.
              },
            ),
          ),
        );
    });
  }

  Future<void> _changeAddress() async {
    final newAddress = await AddressSelectionModalHelper.show(context);
    if (newAddress != null && mounted) {
      await AddressStorageService.saveSelectedAddress(newAddress);
      setState(() {
        _selectedAddress = newAddress;
      });
      // После смены адреса обязательно пересчитываем ближайший магазин
      _autoSelectNearestBusiness(force: true);
    }
  }

  Future<void> _loadSavedAddress() async {
    final address = await AddressStorageService.getSelectedAddress();
    if (address != null && mounted) {
      setState(() {
        _selectedAddress = address;
      });
      // Если адрес уже был сохранён ранее – попробуем выбрать ближайший
      _autoSelectNearestBusiness();
    }
  }

  /// Находит ближайший магазин по координатам пользователя
  // Убран расчет ближайшего магазина для упрощения

  /// Показывает диалог с информацией о ближайшем магазине

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: CartFloatingButton(),
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: _getCurrentPage(),
      // floatingActionButton: const CartFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(16),
        height: 70,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              blurRadius: 1,
              spreadRadius: 2,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            // color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(35),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(
                icon: Icons.home,
                isActive: _currentIndex == 0,
                onTap: () => _onTabTapped(0),
              ),
              _buildNavItem(
                icon: Icons.manage_search_outlined,
                isActive: _currentIndex == 1,
                onTap: () => _onTabTapped(1),
              ),
              _buildNavItem(
                icon: Icons.favorite,
                isActive: _currentIndex == 2,
                onTap: () => _onTabTapped(2),
              ),
              _buildNavItem(
                icon: Icons.person,
                isActive: _currentIndex == 4,
                onTap: () => _onTabTapped(4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _currentIndex = 0;

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _buildNavItem({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? Colors.orange : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.black87 : Colors.grey,
          size: 28,
        ),
      ),
    );
  }

  Widget _getCurrentPage() {
    // Показываем индикатор загрузки, если данные еще загружаются
    if (_isLoadingBusinesses) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    switch (_currentIndex) {
      case 0:
        return MainPage(
          businesses: _businesses,
          selectedBusiness: _selectedBusiness,
          selectedAddress: _selectedAddress,
          userPosition: _userPosition,
          onBusinessSelected: _selectBusiness,
          onAddressChangeRequested: _changeAddress,
          isLoadingBusinesses: _isLoadingBusinesses,
        );
      case 1:
        return Catalog(
          businessId: _selectedBusiness?['id'] ??
              _selectedBusiness?['business_id'] ??
              _selectedBusiness?['businessId'],
        );
      case 2:
        return LikedPage(
          businessId: _selectedBusiness?['id'] ??
              _selectedBusiness?['business_id'] ??
              _selectedBusiness?['businessId'],
        );
      case 3:
        return CartPage();
      case 4:
        return ProfilePage();
      default:
        return Container();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
