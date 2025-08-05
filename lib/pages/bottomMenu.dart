import 'dart:async';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/cart_page.dart';
import 'package:naliv_delivery/pages/catalog.dart';
import 'package:naliv_delivery/pages/login_page.dart';
import 'package:naliv_delivery/pages/mainPage.dart';
import 'package:naliv_delivery/pages/profile_page.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/utils/cartFloatingButton.dart';
import 'package:naliv_delivery/utils/location_service.dart';
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
  bool _isLoadingLocation = false;
  String _locationStatus = 'Геолокация не запрошена';

  // Акции загружаются в MainPage

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
    _loadSavedAddress();
  }

  Future<void> _loadSavedAddress() async {
    final address = await AddressStorageService.getSelectedAddress();
    if (address != null && mounted) {
      setState(() {
        _selectedAddress = address;
      });
      // Optionally auto-select nearest business after loading address
      _autoSelectNearestBusiness();
    }
  }

  /// Загружает список бизнесов из API
  Future<void> _loadBusinesses() async {
    setState(() {
      _isLoadingBusinesses = true;
    });

    try {
      // Загружаем бизнесы с первой страницы
      final data = await ApiService.getBusinesses(page: 1, limit: 20);

      if (data != null && data['businesses'] != null) {
        setState(() {
          _businesses = List<Map<String, dynamic>>.from(data['businesses']);
          _isLoadingBusinesses = false;
        });
        print(_businesses);
        print('Загружено ${_businesses.length} бизнесов');

        // Автоматически выбираем ближайший магазин если есть геолокация
        _autoSelectNearestBusiness();

        // Выводим информацию о пагинации
        if (data['pagination'] != null) {
          final pagination = data['pagination'];
          print(
              'Пагинация: страница ${pagination['page']} из ${pagination['totalPages']}, всего ${pagination['total']} элементов');
        }
      } else {
        setState(() {
          _isLoadingBusinesses = false;
        });
        print('Не удалось загрузить бизнесы');
      }
    } catch (e) {
      setState(() {
        _isLoadingBusinesses = false;
      });
      print('Ошибка при загрузке бизнесов: $e');
    }
  }

  /// Выбирает магазин и сохраняет его в памяти
  void _selectBusiness(Map<String, dynamic> business) {
    setState(() {
      _selectedBusiness = business;
    });

    // Акции загружаются в MainPage при выборе магазина
  }

  /// Автоматически выбирает ближайший магазин если доступна геолокация
  void _autoSelectNearestBusiness() {
    
    if (_selectedBusiness == null &&
        _userPosition != null &&
        _businesses.isNotEmpty) {
      final nearest = _findNearestBusiness(_userPosition!);
      if (nearest != null) {
        setState(() {
          _selectedBusiness = nearest;
        });
        print('Автоматически выбран ближайший магазин: ${nearest['name']}');
      }
    }
  }

  /// Изменяет выбранный адрес пользователя
  Future<void> _changeAddress() async {
    // Проверяем, что контекст доступен и виджет mounted
    if (!mounted) return;

    try {
      final newAddress = await AddressSelectionModalHelper.show(context);

      if (newAddress != null && mounted) {
        // Persist to SharedPreferences
        await AddressStorageService.saveSelectedAddress(newAddress);
        await AddressStorageService.addToAddressHistory({
          'name': newAddress['address'],
          'point': {'lat': newAddress['lat'], 'lon': newAddress['lon']}
        });
        setState(() {
          _selectedAddress = newAddress;
        });
        // Auto-select nearest business based on new address
        _autoSelectNearestBusiness();
      }
    } catch (e) {
      print('Ошибка при изменении адреса: $e');
    }
  }

  /// Получает ближайший магазин или выбранный пользователем
  Map<String, dynamic>? get _currentBusiness {
    // Если пользователь выбрал магазин, возвращаем его
    if (_selectedBusiness != null) {
      return _selectedBusiness;
    }

    // Иначе пытаемся найти ближайший
    if (_userPosition != null) {
      final nearest = _findNearestBusiness(_userPosition!);
      if (nearest != null) return nearest;
    }

    // В крайнем случае возвращаем первый из списка
    if (_businesses.isNotEmpty) {
      return _businesses.first;
    }

    // Возвращаем mock данные если API не доступно
    return {
      'business_id': 1,
      'name': 'Налив',
      'address': 'Москва',
      'description': 'Mock магазин',
      'logo': '',
      'city_id': 1
    };
  }

  /// Запрашивает разрешение на геолокацию и получает координаты
  Future<void> _requestLocationPermission() async {
    setState(() {
      _isLoadingLocation = true;
      _locationStatus = 'Запрос разрешения...';
    });

    try {
      bool success = await requestLocationAndGetPosition();

      if (success && currentPosition != null) {
        setState(() {
          _userPosition = currentPosition;
          _isLoadingLocation = false;
          _locationStatus = 'Геолокация получена';
        });

        print(
            'Координаты пользователя: ${_userPosition!.latitude}, ${_userPosition!.longitude}');

        // Автоматически выбираем ближайший магазин
        _autoSelectNearestBusiness();

        // Можно показать диалог с информацией
        if (mounted) {
          showCurrentLocationInfo();
        }
      } else {
        setState(() {
          _isLoadingLocation = false;
          _locationStatus = 'Не удалось получить геолокацию';
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
        _locationStatus = 'Ошибка: $e';
      });
    }
  }

  /// Проверяет статус разрешения геолокации
  Future<void> _checkLocationPermission() async {
    LocationPermissionResult result =
        await locationService.checkAndRequestPermissions();

    setState(() {
      if (result.success) {
        _locationStatus = 'Разрешение получено';
      } else {
        _locationStatus = result.message;
      }
    });
  }

  /// Находит ближайший магазин по координатам пользователя
  Map<String, dynamic>? _findNearestBusiness(Position userPosition) {
    if (_businesses.isEmpty) return null;

    Map<String, dynamic>? nearestBusiness;
    double minDistance = double.infinity;

    for (var business in _businesses) {
      // Проверяем наличие координат в данных бизнеса
      double? businessLat = business['lat']?.toDouble();
      double? businessLon = business['lon']?.toDouble();

      if (businessLat != null && businessLon != null) {
        // Вычисляем расстояние
        double distance = locationService.calculateDistance(
          userPosition.latitude,
          userPosition.longitude,
          businessLat,
          businessLon,
        );

        if (distance < minDistance) {
          minDistance = distance;
          nearestBusiness = {
            ...business,
            'distance': distance,
            'distanceKm': distance / 1000,
          };
        }
      }
    }

    return nearestBusiness;
  }

  /// Запрашивает геолокацию и находит ближайший магазин
  Future<void> _findNearestStore() async {
    setState(() {
      _isLoadingLocation = true;
      _locationStatus = 'Поиск ближайшего магазина...';
    });

    try {
      bool success = await requestLocationAndGetPosition();

      if (success && currentPosition != null) {
        setState(() {
          _userPosition = currentPosition;
        });

        // Находим ближайший магазин
        Map<String, dynamic>? nearestStore =
            _findNearestBusiness(currentPosition!);

        if (nearestStore != null) {
          setState(() {
            _isLoadingLocation = false;
            _locationStatus =
                'Найден ближайший магазин: ${nearestStore['name']}';
          });

          // Показываем диалог с информацией о ближайшем магазине
          _showNearestStoreDialog(nearestStore);
        } else {
          setState(() {
            _isLoadingLocation = false;
            _locationStatus = 'Не удалось найти ближайший магазин';
          });
        }
      } else {
        setState(() {
          _isLoadingLocation = false;
          _locationStatus = 'Не удалось получить геолокацию';
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
        _locationStatus = 'Ошибка: $e';
      });
    }
  }

  /// Показывает диалог с информацией о ближайшем магазине
  void _showNearestStoreDialog(Map<String, dynamic> store) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ближайший магазин'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              '🏪 ${store['name']}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text('📍 ${store['address']}'),
            const SizedBox(height: 8),
            Text(
              '📏 Расстояние: ${store['distanceKm'].toStringAsFixed(2)} км',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '🌍 Координаты: ${store['lat']}, ${store['lon']}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Закрыть'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Выбрать'),
            onPressed: () {
              Navigator.of(context).pop();
              // Здесь можно добавить логику выбора магазина
              _selectStore(store);
            },
          ),
        ],
      ),
    );
  }

  /// Выбирает магазин как текущий
  void _selectStore(Map<String, dynamic> store) {
    // Обновляем _currentBusiness или сохраняем выбранный магазин
    setState(() {
      _locationStatus = 'Выбран магазин: ${store['name']}';
    });

    // Показываем подтверждение
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Магазин выбран'),
        content: Text('Вы выбрали магазин "${store['name']}"'),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

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
          color: isActive
              ? Colors.grey.withValues(alpha: 0.2)
              : Colors.transparent,
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
        return Scaffold(
          appBar: AppBar(
            title: const Text('Корзина'),
          ),
          body: const Center(
            child: Text(
              'Корзина удалена из проекта',
              style: TextStyle(fontSize: 18),
            ),
          ),
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
