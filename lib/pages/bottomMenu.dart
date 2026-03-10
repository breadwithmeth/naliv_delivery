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
import 'package:naliv_delivery/utils/location_service.dart';
import 'package:provider/provider.dart';
import 'package:naliv_delivery/widgets/address_selection_modal_material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:naliv_delivery/utils/address_storage_service.dart';
import 'package:naliv_delivery/pages/login_page.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/shared/app_theme.dart';

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

  List<Map<String, dynamic>> _businesses = [];
  bool _isLoadingBusinesses = true;

  // Выбранный магазин
  Map<String, dynamic>? _selectedBusiness;

  // Выбранный адрес пользователя
  Map<String, dynamic>? _selectedAddress;

  // Ключ для предотвращения повторного показа одного и того же диалога
  String? _lastNearestPromptKey;

  // Данные геолокации
  Position? _userPosition;

  // Акции загружаются в MainPage

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

  void _showBusinessChangeSnack(Map<String, dynamic> business, {bool auto = false}) {
    // Показываем уже после построения кадра, чтобы Scaffold был доступен
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final distanceM = business['distanceMeters'];
      String distanceText = '';
      if (distanceM is num) {
        final km = (distanceM / 1000).toStringAsFixed(distanceM >= 1000 ? 1 : 2);
        distanceText = ' ($km км)';
      }
      final text = auto ? 'Выбран ближайший магазин: ${business['name']}$distanceText' : 'Магазин изменён: ${business['name']}$distanceText';
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Корзина очищена из-за смены магазина'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
      await _selectBusiness(nearest);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Вы переключились на ближайший магазин: ${nearest['name']}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
      extendBody: true,
      backgroundColor: _bgDeep,
      body: _getCurrentPage(),
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
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 96 + bottomInset,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Container(
                margin: EdgeInsets.fromLTRB(18, 12, 18, 18 + bottomInset / 2),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_bgTop, _bgDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 10))],
                  border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _navItem(icon: Icons.home_rounded, label: '*Главная', index: 0),
                    _navItem(icon: Icons.grid_view_rounded, label: '*Каталог', index: 1),
                    const SizedBox(width: 70),
                    _navItem(icon: Icons.favorite_border, label: '*Избранное', index: 2),
                    _navItem(icon: Icons.person_outline, label: '*Профиль', index: 4),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -18,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => _onTabTapped(3),
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [_orange, Color(0xFFFFB457)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 10))],
                    ),
                    child: const Center(
                      child: Icon(Icons.shopping_cart_outlined, color: Colors.black, size: 30),
                    ),
                  ),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive ? _orange.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: isActive ? _orange : _textMute, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isActive ? _text : _textMute, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
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
        // Главная страница доступна всем
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
        // Каталог доступен всем
        return Catalog(
          businessId: _selectedBusiness?['id'] ?? _selectedBusiness?['business_id'] ?? _selectedBusiness?['businessId'],
        );
      case 2:
        // Избранное требует авторизации
        if (!widget.isAuthenticated) {
          return const LoginPage(redirectTabIndex: 2);
        }
        return LikedPage(
          businessId: _selectedBusiness?['id'] ?? _selectedBusiness?['business_id'] ?? _selectedBusiness?['businessId'],
        );
      case 3:
        // Корзина доступна всем
        return const CartPage();
      case 4:
        // Профиль требует авторизации
        if (!widget.isAuthenticated) {
          return const LoginPage(redirectTabIndex: 4);
        }
        return ProfilePage(userInfo: widget.userInfo!);
      default:
        return Container();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
