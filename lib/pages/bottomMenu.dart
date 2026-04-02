import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gradusy24/pages/cart_page.dart';
import 'package:gradusy24/pages/catalog.dart';
import 'package:gradusy24/pages/likedPage.dart';
import 'package:gradusy24/pages/mainPage.dart';
import 'package:gradusy24/pages/profile_page.dart';
import 'package:gradusy24/services/onboarding_service.dart';
import 'package:gradusy24/utils/api.dart';
import 'package:gradusy24/utils/business_provider.dart';
import 'package:gradusy24/utils/liked_items_provider.dart';
import 'package:gradusy24/utils/location_service.dart';
import 'package:provider/provider.dart';
import 'package:gradusy24/widgets/address_selection_modal_material.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/responsive.dart';
import 'package:gradusy24/utils/address_storage_service.dart';
import 'package:gradusy24/pages/login_page.dart';
import 'package:gradusy24/utils/cart_provider.dart';
import 'package:gradusy24/shared/app_theme.dart';

class BottomMenu extends StatefulWidget {
  final bool isAuthenticated;
  final Map<String, dynamic>? userInfo;
  final int? initialTabIndex;

  const BottomMenu({required this.isAuthenticated, this.userInfo, this.initialTabIndex, super.key});

  @override
  State<BottomMenu> createState() => _BottomMenuState();
}

class _BottomMenuState extends State<BottomMenu> with LocationMixin {
  // Palette to match main page design
  static const Color _bgDeep = AppColors.bgDeep;
  static const Color _bgTop = AppColors.bgTop;
  static const Color _orange = AppColors.orange;
  static const Color _text = AppColors.text;
  static const Color _textMute = AppColors.textMute;

  List<Map<String, dynamic>> _allBusinesses = [];
  List<Map<String, dynamic>> _businesses = [];
  List<String> _availableCities = [];
  bool _isLoadingBusinesses = true;
  String? _selectedCity;

  // Выбранный магазин
  Map<String, dynamic>? _selectedBusiness;

  // Выбранный адрес пользователя
  Map<String, dynamic>? _selectedAddress;

  // Ключ для предотвращения повторного показа одного и того же диалога
  String? _lastNearestPromptKey;

  // Данные геолокации
  Position? _userPosition;

  // Акции загружаются в MainPage

  String _money(double value) {
    return value == value.roundToDouble() ? '${value.toInt()} ₸' : '${value.toStringAsFixed(0)} ₸';
  }

  int? _selectedBusinessIdAsInt() {
    final rawId = _selectedBusiness?['id'] ?? _selectedBusiness?['business_id'] ?? _selectedBusiness?['businessId'];
    if (rawId == null) return null;
    if (rawId is int) return rawId;
    return int.tryParse(rawId.toString());
  }

  @override
  void initState() {
    super.initState();
    // Установка стартовой вкладки, если передан индекс
    if (widget.initialTabIndex != null) {
      _currentIndex = widget.initialTabIndex!.clamp(0, 4);
    }
    // Загружаем сохранённый магазин из storage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bp = Provider.of<BusinessProvider>(context, listen: false);
      bp.loadSavedBusiness();
    });
    _loadCitiesAndSelection();
    _loadSavedAddress();
  }

  Future<void> _loadCitiesAndSelection() async {
    final cities = await OnboardingService.fetchAvailableCities(forceRefresh: true);
    final city = await OnboardingService.getSelectedCity();
    if (!mounted) return;

    final cityNames = cities.map((item) => item.name).toList();
    final fallbackSelectedCity = cityNames.contains(city) ? city : (cityNames.isNotEmpty ? cityNames.first : null);

    setState(() {
      _availableCities = cityNames;
      _selectedCity = fallbackSelectedCity;
    });

    // Re-enrich businesses that were loaded before cities arrived
    if (_allBusinesses.isNotEmpty) {
      for (final b in _allBusinesses) {
        b['_cityName'] = _detectBusinessCity(b) ?? '';
      }
    }

    // Load businesses if not loaded yet, otherwise just refresh filter
    if (_allBusinesses.isEmpty) {
      await _loadBusinesses();
    } else {
      await _refreshBusinessesForSelectedCity();
    }
  }

  Future<void> _loadBusinesses() async {
    setState(() {
      _isLoadingBusinesses = true;
    });
    try {
      final allBusinesses = await ApiService.getAllBusinesses();
      if (!mounted) return;
      if (allBusinesses != null && allBusinesses.isNotEmpty) {
        final list = List<Map<String, dynamic>>.from(allBusinesses);
        // Enrich each business with resolved city name for the shop selector
        for (final b in list) {
          b['_cityName'] = _detectBusinessCity(b) ?? '';
        }
        _allBusinesses = list;
        await _refreshBusinessesForSelectedCity(markLoadingComplete: true);
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

  Future<void> _selectBusiness(Map<String, dynamic> business) async {
    setState(() {
      _selectedBusiness = business;
    });
    await Provider.of<BusinessProvider>(context, listen: false).setSelectedBusiness(business);
    final likedProvider = Provider.of<LikedItemsProvider>(context, listen: false);
    final businessId = business['id'] ?? business['business_id'] ?? business['businessId'];
    if (businessId != null) {
      likedProvider.loadLiked(int.tryParse(businessId.toString()) ?? 0);
    }
  }

  Future<void> _refreshBusinessesForSelectedCity({bool markLoadingComplete = false}) async {
    if (!mounted) return;

    final filteredBusinesses = _filterBusinessesByCity(_allBusinesses, _selectedCity);
    final currentBusinessId = _businessIdOf(_selectedBusiness);
    Map<String, dynamic>? preservedSelection;

    if (currentBusinessId != null) {
      for (final business in filteredBusinesses) {
        if (_businessIdOf(business) == currentBusinessId) {
          preservedSelection = business;
          break;
        }
      }
    }

    final shouldClearStoredBusiness = _selectedBusiness != null && preservedSelection == null;

    setState(() {
      _businesses = filteredBusinesses;
      _selectedBusiness = preservedSelection;
      _lastNearestPromptKey = null;
      if (markLoadingComplete) {
        _isLoadingBusinesses = false;
      }
    });

    if (shouldClearStoredBusiness) {
      await Provider.of<BusinessProvider>(context, listen: false).clearSelectedBusiness();
    }

    if (!mounted || filteredBusinesses.isEmpty) return;
    if (preservedSelection == null) {
      _autoSelectNearestBusiness(force: true);
    }
  }

  Future<void> _changeSelectedCity(String city) async {
    if (city == _selectedCity) return;

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    if (cartProvider.items.isNotEmpty) {
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _bgTop,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
          title: const Text('Сменить город?', style: TextStyle(color: _text, fontWeight: FontWeight.w800)),
          content: const Text(
            'При смене города активный магазин обновится, а корзина будет очищена.',
            style: TextStyle(color: _textMute),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Отмена', style: TextStyle(color: _text))),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Сменить', style: TextStyle(color: _orange))),
          ],
        ),
      );

      if (shouldProceed != true || !mounted) {
        return;
      }

      cartProvider.clearCart();
    }

    await OnboardingService.setSelectedCity(city);
    if (!mounted) return;

    setState(() {
      _selectedCity = city;
    });

    await _refreshBusinessesForSelectedCity();

    if (!mounted) return;
    if (_selectedAddress != null && !_addressMatchesSelectedCity(_selectedAddress!, city)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Город изменён на $city. Проверьте адрес доставки.'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _filterBusinessesByCity(List<Map<String, dynamic>> businesses, String? city) {
    if (city == null || city.trim().isEmpty) {
      return List<Map<String, dynamic>>.from(businesses);
    }

    final cityIdMap = _buildCityIdMap(businesses);
    return businesses.where((business) => _businessMatchesCity(business, city, cityIdMap)).toList();
  }

  Map<int, String> _buildCityIdMap(List<Map<String, dynamic>> businesses) {
    final mapping = <int, String>{};

    for (final business in businesses) {
      final cityId = _parseCityId(business['city_id'] ?? business['cityId']);
      if (cityId == null || mapping.containsKey(cityId)) continue;

      final detectedCity = _detectBusinessCity(business);
      if (detectedCity != null) {
        mapping[cityId] = detectedCity;
      }
    }

    for (final city in _availableCities) {
      final cityId = OnboardingService.cachedCities
          .where((item) => item.name == city)
          .map((item) => item.id)
          .cast<int?>()
          .firstWhere((value) => value != null, orElse: () => null);
      if (cityId != null) {
        mapping.putIfAbsent(cityId, () => city);
      }
    }

    return mapping;
  }

  bool _businessMatchesCity(Map<String, dynamic> business, String city, Map<int, String> cityIdMap) {
    final explicitCity = _detectBusinessCity(business);
    if (explicitCity != null) {
      return explicitCity == city;
    }

    final cityId = _parseCityId(business['city_id'] ?? business['cityId']);
    if (cityId != null) {
      final mappedCity = cityIdMap[cityId] ?? OnboardingService.getCityNameById(cityId);
      if (mappedCity != null) {
        return mappedCity == city;
      }
    }

    return false;
  }

  String? _detectBusinessCity(Map<String, dynamic> business) {
    final rawSources = [
      business['city'],
      business['city_name'],
      business['cityName'],
      business['city_title'],
      business['cityTitle'],
      business['address'],
      business['description'],
    ];

    for (final source in rawSources) {
      if (source == null) continue;
      final text = source.toString();
      for (final city in _availableCities) {
        if (_textMatchesCity(text, city)) {
          return city;
        }
      }
    }

    return null;
  }

  bool _addressMatchesSelectedCity(Map<String, dynamic> address, String city) {
    final label = ApiService.formatAddressSummary(address, emptyText: '');
    if (label.isEmpty) return true;

    final containsKnownCity = _availableCities.any((knownCity) => _textMatchesCity(label, knownCity));
    if (!containsKnownCity) return true;

    return _textMatchesCity(label, city);
  }

  bool _textMatchesCity(String text, String city) {
    final normalizedText = _normalizeText(text);
    final normalizedCity = _normalizeText(city);
    return normalizedCity.isNotEmpty && normalizedText.contains(normalizedCity);
  }

  String _normalizeText(String value) {
    return value.toLowerCase().replaceAll('ё', 'е').replaceAll(RegExp(r'[^a-zа-я0-9]+'), ' ').trim();
  }

  int? _parseCityId(dynamic cityId) {
    if (cityId == null) return null;
    if (cityId is int) return cityId;
    return int.tryParse(cityId.toString());
  }

  dynamic _businessIdOf(Map<String, dynamic>? business) {
    return business?['id'] ?? business?['business_id'] ?? business?['businessId'];
  }

  // --- ЛОГИКА АВТОВЫБОРА БЛИЖАЙШЕГО МАГАЗИНА ---

  void _autoSelectNearestBusiness({bool force = false}) {
    if (_businesses.isEmpty) return;
    if (_selectedAddress == null) {
      // Если нет адреса – fallback: если ничего не выбрано, возьмём первый для стабильности
      if (_selectedBusiness == null && _businesses.isNotEmpty) {
        _selectBusiness(_businesses.first);
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
      }
      return;
    }

    final nearest = _findNearestBusiness(coords['lat']!, coords['lon']!);
    if (nearest != null) {
      _selectBusiness(nearest);
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

  Future<void> _changeAddress() async {
    final hadSelectedAddress = _selectedAddress != null;
    final newAddress = await AddressSelectionModalHelper.show(context);
    if (newAddress != null && mounted) {
      await AddressStorageService.saveSelectedAddress(newAddress);
      setState(() {
        _selectedAddress = newAddress;
      });
      if (!hadSelectedAddress) {
        _autoSelectNearestBusiness(force: true);
        return;
      }
      // Если магазин ещё не выбран – просто выберем ближайший
      if (_selectedBusiness == null) {
        _autoSelectNearestBusiness(force: true);
      } else {
        // Иначе предложим переключиться, если текущий не ближайший
        _maybePromptNearestSwitch();
      }
    }
  }

  /// Предлагает переключиться на ближайший магазин, если текущий не ближайший
  Future<void> _maybePromptNearestSwitch() async {
    if (!mounted) return;
    if (_selectedAddress == null) return;
    if (_selectedBusiness == null) return; // нечего сравнивать
    if (_businesses.isEmpty) return;

    final coords = _extractAddressLatLon(_selectedAddress!);
    if (coords == null) return;

    final nearest = _findNearestBusiness(coords['lat']!, coords['lon']!);
    if (nearest == null) return;

    final currentId = _selectedBusiness!['id'] ?? _selectedBusiness!['business_id'] ?? _selectedBusiness!['businessId'];
    final nearestId = nearest['id'] ?? nearest['business_id'] ?? nearest['businessId'];
    if (currentId == null || nearestId == null) return;

    // Уже ближайший
    if (currentId == nearestId) return;

    final promptKey = '${coords['lat']!.toStringAsFixed(5)}_${coords['lon']!.toStringAsFixed(5)}_${currentId}_${nearestId}';
    if (_lastNearestPromptKey == promptKey) return; // уже спрашивали в этой конфигурации
    _lastNearestPromptKey = promptKey;

    // Расстояния
    final nearestDistM = (nearest['distanceMeters'] as num?)?.toDouble() ?? 0;
    final currentDistM = () {
      final bLat = _selectedBusiness!['lat'];
      final bLon = _selectedBusiness!['lon'];
      if (bLat != null && bLon != null) {
        final dLat = double.tryParse(bLat.toString());
        final dLon = double.tryParse(bLon.toString());
        if (dLat != null && dLon != null) {
          return Geolocator.distanceBetween(coords['lat']!, coords['lon']!, dLat, dLon);
        }
      }
      return 0.0;
    }();

    final nearestKm = (nearestDistM / 1000).toStringAsFixed(2);
    final currentKm = (currentDistM / 1000).toStringAsFixed(2);

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final hasCartItems = cartProvider.items.isNotEmpty;

    final shouldSwitch = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _bgTop,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        title: const Text('Ближайший магазин', style: TextStyle(color: _text, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Текущий магазин находится на ~$currentKm км от выбранного адреса.', style: const TextStyle(color: _textMute)),
            const SizedBox(height: 8),
            Text('Ближайший магазин: ${nearest['name']} (~$nearestKm км).', style: const TextStyle(fontWeight: FontWeight.w600, color: _text)),
            const SizedBox(height: 12),
            Text(
              hasCartItems ? 'Переключение очистит текущую корзину. Перейти к ближайшему магазину?' : 'Переключить на ближайший магазин?',
              style: const TextStyle(color: _textMute),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Оставить', style: TextStyle(color: _text)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Переключить', style: TextStyle(color: _orange)),
          ),
        ],
      ),
    );

    if (shouldSwitch == true) {
      if (hasCartItems) {
        cartProvider.clearCart();
      }
      await _selectBusiness(nearest);
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
    final selectedBusinessId = _selectedBusinessIdAsInt();
    final pages = <Widget>[
      MainPage(
        key: const PageStorageKey('tab-home'),
        businesses: _businesses,
        allBusinesses: _allBusinesses,
        availableCities: _availableCities,
        selectedBusiness: _selectedBusiness,
        selectedAddress: _selectedAddress,
        selectedCity: _selectedCity,
        userPosition: _userPosition,
        onBusinessSelected: _selectBusiness,
        onCityChanged: _changeSelectedCity,
        onAddressChangeRequested: _changeAddress,
        isLoadingBusinesses: _isLoadingBusinesses,
      ),
      Catalog(
        key: ValueKey('tab-catalog-${_selectedBusiness?['id'] ?? _selectedBusiness?['business_id'] ?? _selectedBusiness?['businessId']}'),
        businessId: selectedBusinessId,
      ),
      widget.isAuthenticated && selectedBusinessId != null
          ? LikedPage(
              key: ValueKey('tab-liked-${_selectedBusiness?['id'] ?? _selectedBusiness?['business_id'] ?? _selectedBusiness?['businessId']}'),
              businessId: selectedBusinessId,
            )
          : const LoginPage(redirectTabIndex: 2),
      const CartPage(key: PageStorageKey('tab-cart')),
      widget.isAuthenticated
          ? ProfilePage(key: const PageStorageKey('tab-profile'), userInfo: widget.userInfo!)
          : const LoginPage(redirectTabIndex: 4),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: _bgDeep,
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  int _currentIndex = 0;

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _buildBottomNav() {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 88.s,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Container(
                margin: EdgeInsets.fromLTRB(16.s, 10.s, 16.s, 16.s),
                padding: EdgeInsets.symmetric(horizontal: 16.s),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_bgTop, _bgDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(26.s),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12.s, offset: Offset(0, 8.s))],
                  border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _navItem(icon: Icons.home_rounded, label: 'Главная', index: 0),
                    _navItem(icon: Icons.grid_view_rounded, label: 'Каталог', index: 1),
                    SizedBox(width: 64.s),
                    _navItem(icon: Icons.favorite_border, label: 'Избранное', index: 2),
                    _navItem(icon: Icons.person_outline, label: 'Профиль', index: 4),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -16.s,
              left: 0,
              right: 0,
              child: Center(
                child: Consumer<CartProvider>(
                  builder: (context, cart, _) {
                    final itemCount = cart.items.length;
                    final total = cart.getTotalPrice();
                    final hasItems = itemCount > 0;

                    return GestureDetector(
                      onTap: () => _onTabTapped(3),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 70.s,
                                height: 70.s,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                      colors: [_orange, Color(0xFFFFB457)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 12.s, offset: Offset(0, 8.s))],
                                ),
                                child: Center(
                                  child: Icon(Icons.shopping_cart_outlined, color: Colors.black, size: 26.s),
                                ),
                              ),
                              if (hasItems)
                                Positioned(
                                  top: -2.s,
                                  right: -2.s,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 7.s, vertical: 3.s),
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(10.s),
                                      border: Border.all(color: _orange, width: 1.4),
                                    ),
                                    child: Text(
                                      '$itemCount',
                                      style: TextStyle(
                                        color: _orange,
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (hasItems) ...[
                            SizedBox(height: 6.s),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.s, vertical: 4.s),
                              decoration: BoxDecoration(
                                color: _orange,
                                borderRadius: BorderRadius.circular(12.s),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    blurRadius: 8.s,
                                    offset: Offset(0, 4.s),
                                  ),
                                ],
                              ),
                              child: Text(
                                _money(total),
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem({required IconData icon, required String label, required int index}) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(7.s),
            decoration: BoxDecoration(
              color: isActive ? _orange.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(12.s),
            ),
            child: Icon(icon, color: isActive ? _orange : _textMute, size: 22.s),
          ),
          SizedBox(height: 3.s),
          Text(label, style: TextStyle(color: isActive ? _text : _textMute, fontSize: 10.sp, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
