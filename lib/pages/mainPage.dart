import 'dart:async';
import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../shared/app_theme.dart';
import '../utils/address_storage_service.dart';
import '../utils/api.dart';
import '../utils/cart_provider.dart';
import '../utils/location_service.dart';
import '../widgets/address_selection_modal_material.dart';
import 'bonus_history_page.dart';
import 'categoryPage.dart';
import 'login_page.dart';
import 'orders_history_page.dart';
import 'promotion_items_page.dart';
import 'search_page.dart';

class MainPage extends StatefulWidget {
  final List<Map<String, dynamic>> businesses;
  final List<Map<String, dynamic>> allBusinesses;
  final List<String> availableCities;
  final Map<String, dynamic>? selectedBusiness;
  final Map<String, dynamic>? selectedAddress;
  final String? selectedCity;
  final Position? userPosition;
  final Function(Map<String, dynamic>) onBusinessSelected;
  final ValueChanged<String> onCityChanged;
  final VoidCallback onAddressChangeRequested;
  final bool isLoadingBusinesses;

  const MainPage({
    super.key,
    required this.businesses,
    required this.allBusinesses,
    required this.availableCities,
    this.selectedBusiness,
    this.selectedAddress,
    this.selectedCity,
    this.userPosition,
    required this.onBusinessSelected,
    required this.onCityChanged,
    required this.onAddressChangeRequested,
    required this.isLoadingBusinesses,
  });

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  // ─── Palette ─────────────────────────────────────────────
  static const Color _bgDeep = Color(0xFF121212);
  static const Color _bgTop = Color(0xFF161616);
  static const Color _card = Color(0xFF1E1E1E);
  static const Color _cardDark = Color(0xFF181818);
  static const Color _blue = Color(0xFF242A32);
  static const Color _orange = Color(0xFFF6A10C);
  static const Color _red = Color(0xFFC23B30);
  static const Color _text = Colors.white;
  static const Color _textMute = Color(0xFF9FB0C8);

  final CarouselSliderController _promoCarouselController = CarouselSliderController();
  final LocationService _locationService = LocationService.instance;
  StreamSubscription<Map<String, dynamic>?>? _addressSubscription;
  String? _lastPromptKey;

  List<Promotion> _promotions = [];
  bool _isLoadingPromotions = false;
  String? _promotionsError;

  List<Map<String, dynamic>> _superCategories = [];
  bool _isLoadingSuperCategories = false;
  String? _superCategoriesError;

  Map<String, dynamic>? _selectedAddress;

  Map<String, dynamic>? _bonuses;
  bool _isLoadingBonuses = true;
  String? _bonusesError;
  String? _activeCardUuid;
  String? _qrPayload;
  Timer? _qrTimer;
  List<Map<String, dynamic>> _activeOrders = <Map<String, dynamic>>[];

  int _currentPromoIndex = 0;

  // ─── Lifecycle ───────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _selectedAddress = widget.selectedAddress;

    _addressSubscription = AddressStorageService.selectedAddressStream.listen((addr) {
      if (!mounted) return;
      final hadSelectedAddress = _selectedAddress != null;
      setState(() => _selectedAddress = addr);
      if (addr != null) {
        if (!hadSelectedAddress) {
          _selectNearestBusinessIfNeeded(replaceCurrent: true);
        } else if (widget.selectedBusiness == null) {
          _autoSelectNearestBusiness();
        } else {
          _maybePromptNearestSwitch();
        }
      }
    });

    if (_selectedAddress == null) {
      _initAddressSelection();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoSelectNearestBusiness());
      _maybeSuggestCloserAddress();
    }

    _loadPromotions();
    _loadSuperCategories();
    _loadBonuses();
    _loadActiveOrders();
  }

  @override
  void didUpdateWidget(covariant MainPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldBusinessId =
        oldWidget.selectedBusiness?['id'] ?? oldWidget.selectedBusiness?['business_id'] ?? oldWidget.selectedBusiness?['businessId'];
    final newBusinessId = widget.selectedBusiness?['id'] ?? widget.selectedBusiness?['business_id'] ?? widget.selectedBusiness?['businessId'];
    if (oldBusinessId != newBusinessId) {
      _loadPromotions();
    }

    if (oldWidget.selectedAddress != widget.selectedAddress) {
      setState(() => _selectedAddress = widget.selectedAddress);
    }
  }

  @override
  void dispose() {
    _addressSubscription?.cancel();
    _stopQrUpdates();
    super.dispose();
  }

  // ─── Data Loading ────────────────────────────────────────
  Future<void> _loadActiveOrders() async {
    try {
      final orders = await ApiService.getMyActiveOrdersList();
      if (!mounted) return;
      setState(() {
        _activeOrders = orders;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _activeOrders = <Map<String, dynamic>>[];
      });
    }
  }

  Future<void> _showMessageDialog(String title, String message) {
    return AppDialogs.showMessage(
      context,
      title: title,
      message: message,
    );
  }

  Future<void> _loadPromotions() async {
    setState(() {
      _isLoadingPromotions = true;
      _promotionsError = null;
    });
    try {
      final int? businessId = widget.selectedBusiness?['id'] ?? widget.selectedBusiness?['business_id'] ?? widget.selectedBusiness?['businessId'];
      final promos = await ApiService.getActivePromotionsTyped(businessId: businessId, limit: 12);
      if (!mounted) return;
      setState(() {
        _promotions = promos ?? [];
        _isLoadingPromotions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _promotionsError = 'Ошибка загрузки акций: $e';
        _isLoadingPromotions = false;
      });
    }
  }

  Future<void> _loadSuperCategories() async {
    if (!mounted) return;
    setState(() {
      _isLoadingSuperCategories = true;
      _superCategoriesError = null;
    });
    try {
      final result = await ApiService.getSuperCategories();
      if (!mounted) return;
      setState(() {
        _superCategories = result ?? [];
        _isLoadingSuperCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _superCategoriesError = 'Ошибка загрузки категорий: $e';
        _isLoadingSuperCategories = false;
      });
    }
  }

  Future<void> _loadBonuses() async {
    if (!mounted) return;
    setState(() {
      _isLoadingBonuses = true;
      _bonusesError = null;
    });

    try {
      final data = await ApiService.getUserBonuses();
      if (!mounted) return;
      if (data == null) {
        setState(() {
          _bonuses = null;
          _bonusesError = 'Авторизуйтесь, чтобы видеть бонусы';
          _isLoadingBonuses = false;
        });
        _stopQrUpdates();
        return;
      }

      final success = data['success'] == true;
      final cardUuid = data['data']?['bonusCard']?['cardUuid']?.toString();
      setState(() {
        _bonuses = data;
        _activeCardUuid = cardUuid;
        _qrPayload = _buildQrPayload(cardUuid);
        _isLoadingBonuses = false;
        _bonusesError = success ? null : (data['message']?.toString() ?? 'Не удалось загрузить бонусы');
      });

      if (success && cardUuid != null) {
        _restartQrUpdates();
      } else {
        _stopQrUpdates();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bonusesError = 'Ошибка загрузки бонусов: $e';
        _isLoadingBonuses = false;
      });
      _stopQrUpdates();
    }
  }

  // ─── Address / Business Selection ────────────────────────
  Future<void> _initAddressSelection() async {
    final saved = await AddressStorageService.getSelectedAddress();
    if (saved != null) {
      setState(() => _selectedAddress = saved);
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoSelectNearestBusiness());
      return;
    }
    final isFirst = await AddressStorageService.isFirstLaunch();
    if (isFirst) {
      _attemptAutoDetectAddress();
    } else {
      _fallbackShowAddressModal();
    }
  }

  Future<void> _attemptAutoDetectAddress() async {
    try {
      final permission = await _locationService.checkAndRequestPermissions();
      if (!permission.success) return _fallbackShowAddressModal();
      final enabled = await _locationService.isLocationServiceEnabled();
      if (!enabled) return _fallbackShowAddressModal();

      Position? pos;
      for (final acc in [LocationAccuracy.high, LocationAccuracy.medium, LocationAccuracy.low]) {
        try {
          pos = await Geolocator.getCurrentPosition(desiredAccuracy: acc, timeLimit: const Duration(seconds: 8));
          break;
        } catch (_) {}
      }
      if (pos == null) return _fallbackShowAddressModal();
      if (!_locationService.isAccurateEnoughForAutoSelection(pos)) {
        return _fallbackShowAddressModal();
      }

      final reverse = await ApiService.searchAddresses(lat: pos.latitude, lon: pos.longitude, city: widget.selectedCity);
      final resolvedAddress = (reverse?.isNotEmpty ?? false)
          ? ApiService.extractAddressLabel(reverse!.first, lat: pos.latitude, lon: pos.longitude, preferredCity: widget.selectedCity)
          : null;
      final autoAddress = {
        'address': resolvedAddress ?? 'Определённый адрес',
        'lat': pos.latitude,
        'lon': pos.longitude,
        'accuracy': pos.accuracy,
        'source': 'auto_geolocation',
        'timestamp': DateTime.now().toIso8601String(),
      };
      await AddressStorageService.saveSelectedAddress(autoAddress);
      await AddressStorageService.addToAddressHistory({
        'name': autoAddress['address'],
        'point': {'lat': pos.latitude, 'lon': pos.longitude},
      });
      await AddressStorageService.markAsLaunched();
      if (!mounted) return;
      setState(() => _selectedAddress = autoAddress);
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoSelectNearestBusiness());
    } catch (_) {
      _fallbackShowAddressModal();
    }
  }

  void _fallbackShowAddressModal() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 120));
      if (mounted) _showAddressSelectionModal();
    });
  }

  Future<void> _showAddressSelectionModal() async {
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    final hadSelectedAddress = _selectedAddress != null;
    final selectedAddress = await AddressSelectionModalHelper.show(context);
    if (selectedAddress != null && mounted) {
      await AddressStorageService.saveSelectedAddress(selectedAddress);
      await AddressStorageService.addToAddressHistory({
        'name': selectedAddress['address'],
        'point': {'lat': selectedAddress['lat'], 'lon': selectedAddress['lon']},
      });
      setState(() => _selectedAddress = selectedAddress);
      if (!hadSelectedAddress) {
        _selectNearestBusinessIfNeeded(replaceCurrent: true);
      } else if (widget.selectedBusiness == null) {
        _autoSelectNearestBusiness();
      } else {
        _maybePromptNearestSwitch();
      }
    }
  }

  void _autoSelectNearestBusiness() {
    _selectNearestBusinessIfNeeded();
  }

  void _selectNearestBusinessIfNeeded({bool replaceCurrent = false}) {
    if (_selectedAddress == null || widget.businesses.isEmpty) return;
    if (!replaceCurrent && widget.selectedBusiness != null) return;
    final coords = _extractAddressLatLon(_selectedAddress!);
    if (coords == null) return;
    final nearest = _findNearestBusiness(coords['lat']!, coords['lon']!);
    if (nearest == null) return;

    final currentId = widget.selectedBusiness?['id'] ?? widget.selectedBusiness?['business_id'] ?? widget.selectedBusiness?['businessId'];
    final nearestId = nearest['id'] ?? nearest['business_id'] ?? nearest['businessId'];
    if (currentId != null && nearestId != null && currentId == nearestId) {
      return;
    }

    widget.onBusinessSelected(nearest);
  }

  Map<String, double>? _extractAddressLatLon(Map<String, dynamic> address) {
    try {
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
    double best = double.infinity;
    for (final b in widget.businesses) {
      final bLat = double.tryParse(b['lat']?.toString() ?? '');
      final bLon = double.tryParse(b['lon']?.toString() ?? '');
      if (bLat == null || bLon == null) continue;
      final dist = Geolocator.distanceBetween(lat, lon, bLat, bLon);
      if (dist < best) {
        best = dist;
        nearest = {...b, 'distance': dist};
      }
    }
    return nearest;
  }

  Future<void> _maybeSuggestCloserAddress() async {
    if (_selectedAddress == null || _selectedAddress!['lat'] == null || _selectedAddress!['lon'] == null) return;
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low, timeLimit: const Duration(seconds: 4));
      if (!_locationService.isAccurateEnoughForAutoSelection(pos)) return;
      final savedLat = (_selectedAddress!['lat'] as num).toDouble();
      final savedLon = (_selectedAddress!['lon'] as num).toDouble();
      final currentDistance = _locationService.calculateDistance(pos.latitude, pos.longitude, savedLat, savedLon);
      if (currentDistance <= 1500) return;
      final history = await AddressStorageService.getAddressHistory();
      if (history.isEmpty) return;
      double bestDistance = double.infinity;
      Map<String, dynamic>? bestEntry;
      for (final entry in history) {
        final point = entry['point'];
        if (point == null) continue;
        final lat = (point['lat'] as num?)?.toDouble();
        final lon = (point['lon'] as num?)?.toDouble();
        if (lat == null || lon == null) continue;
        final d = _locationService.calculateDistance(pos.latitude, pos.longitude, lat, lon);
        if (d < bestDistance) {
          bestDistance = d;
          bestEntry = entry;
        }
      }
      if (bestEntry == null) return;
      if (currentDistance - bestDistance < 400) return;
      final promptKey =
          '${pos.latitude.toStringAsFixed(4)}_${pos.longitude.toStringAsFixed(4)}_${savedLat.toStringAsFixed(4)}_${savedLon.toStringAsFixed(4)}';
      final lastKey = await AddressStorageService.getLastReaddressPromptKey();
      if (lastKey == promptKey) return;
      await AddressStorageService.setLastReaddressPromptKey(promptKey);
      if (!mounted) return;
      final decision = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
          title: const Text('Обновить адрес?', style: TextStyle(color: _text, fontWeight: FontWeight.w800)),
          content: Text(
            'Найден более близкий адрес (~${(bestDistance / 1000).toStringAsFixed(2)} км). Заменить?',
            style: const TextStyle(color: _textMute),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, 'keep'), child: const Text('Оставить', style: TextStyle(color: _text))),
            TextButton(onPressed: () => Navigator.pop(ctx, 'switch'), child: const Text('Заменить', style: TextStyle(color: _orange))),
            TextButton(onPressed: () => Navigator.pop(ctx, 'dontask'), child: const Text('Не спрашивать', style: TextStyle(color: _textMute))),
          ],
        ),
      );
      if (!mounted) return;
      if (decision == 'switch') {
        final newAddress = {
          'address': bestEntry['name'],
          'lat': bestEntry['point']['lat'],
          'lon': bestEntry['point']['lon'],
          'source': 'history_replacement',
          'timestamp': DateTime.now().toIso8601String(),
        };
        await AddressStorageService.saveSelectedAddress(newAddress);
        setState(() => _selectedAddress = newAddress);
        if (widget.selectedBusiness == null) {
          _autoSelectNearestBusiness();
        } else {
          _maybePromptNearestSwitch();
        }
      }
    } catch (_) {}
  }

  Future<void> _maybePromptNearestSwitch() async {
    if (_selectedAddress == null || widget.businesses.isEmpty || widget.selectedBusiness == null) return;
    final coords = _extractAddressLatLon(_selectedAddress!);
    if (coords == null) return;
    final nearest = _findNearestBusiness(coords['lat']!, coords['lon']!);
    if (nearest == null) return;
    final currentId = widget.selectedBusiness!['id'] ?? widget.selectedBusiness!['business_id'] ?? widget.selectedBusiness!['businessId'];
    final nearestId = nearest['id'] ?? nearest['business_id'] ?? nearest['businessId'];
    if (currentId == null || nearestId == null || currentId == nearestId) return;
    final promptKey = '${coords['lat']!.toStringAsFixed(5)}_${coords['lon']!.toStringAsFixed(5)}_${currentId}_${nearestId}';
    if (_lastPromptKey == promptKey) return;
    _lastPromptKey = promptKey;
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final hasItems = cartProvider.items.isNotEmpty;
    final shouldSwitch = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        title: const Text('Ближайший магазин', style: TextStyle(color: _text, fontWeight: FontWeight.w800)),
        content: Text(
          hasItems
              ? 'Ближайший магазин: ${nearest['name']}. При переключении корзина очистится. Переключить?'
              : 'Ближайший магазин: ${nearest['name']}. Переключить?',
          style: const TextStyle(color: _textMute),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Оставить', style: TextStyle(color: _text))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Переключить', style: TextStyle(color: _orange))),
        ],
      ),
    );
    if (shouldSwitch == true) {
      if (hasItems) cartProvider.clearCart();
      widget.onBusinessSelected(nearest);
    }
  }

  // ─── QR / Bonus Helpers ──────────────────────────────────
  String? _buildQrPayload(String? cardUuid) {
    if (cardUuid == null) return null;
    final minuteBucket = DateTime.now().millisecondsSinceEpoch ~/ 60000;
    return '$cardUuid:$minuteBucket';
  }

  void _restartQrUpdates() {
    _qrTimer?.cancel();
    _qrTimer = Timer.periodic(const Duration(minutes: 1), (_) => _updateQrPayload());
  }

  void _stopQrUpdates() {
    _qrTimer?.cancel();
    _qrTimer = null;
  }

  void _updateQrPayload() {
    if (!mounted) return;
    setState(() {
      _qrPayload = _buildQrPayload(_activeCardUuid);
    });
  }

  Future<void> _openLoginPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    if (mounted) _loadBonuses();
  }

  // ─── Category Helpers ────────────────────────────────────
  Map<String, dynamic> _getCategoryIconAndColor(String name) {
    const accent = _orange;
    const accentAlt = _red;
    final lower = name.toLowerCase();
    if (lower.contains('пиво'))
      return {
        'icon': Icons.sports_bar,
        'color': accent,
        'gradient': const [Color(0xFF2A2214), _cardDark]
      };
    if (lower.contains('вино'))
      return {
        'icon': Icons.wine_bar,
        'color': accent,
        'gradient': const [Color(0xFF2A1A1C), _cardDark]
      };
    if (lower.contains('виски') || lower.contains('коньяк') || lower.contains('бурбон')) {
      return {
        'icon': Icons.local_bar,
        'color': accent,
        'gradient': const [Color(0xFF2A2018), _cardDark]
      };
    }
    if (lower.contains('игрист') || lower.contains('шампан')) {
      return {
        'icon': Icons.celebration,
        'color': accent,
        'gradient': const [Color(0xFF1E2430), _cardDark]
      };
    }
    if (lower.contains('крепкий') || lower.contains('водка')) {
      return {
        'icon': Icons.local_drink,
        'color': accent,
        'gradient': const [Color(0xFF202228), _cardDark]
      };
    }
    if (lower.contains('сигарет') || lower.contains('табак') || lower.contains('курение')) {
      return {
        'icon': Icons.smoking_rooms,
        'color': accent,
        'gradient': const [Color(0xFF26201E), _cardDark]
      };
    }
    if (lower.contains('сладост') || lower.contains('конфет') || lower.contains('шоколад') || lower.contains('печенье')) {
      return {
        'icon': Icons.cake,
        'color': accent,
        'gradient': const [Color(0xFF2A2418), _cardDark]
      };
    }
    if (lower.contains('напитк') || lower.contains('сок') || lower.contains('вода') || lower.contains('газировка') || lower.contains('лимонад')) {
      return {
        'icon': Icons.bubble_chart,
        'color': accent,
        'gradient': const [Color(0xFF1A2428), _cardDark]
      };
    }
    if (lower.contains('фрукт') || lower.contains('овощ') || lower.contains('ягод') || lower.contains('зелен')) {
      return {
        'icon': Icons.eco,
        'color': accent,
        'gradient': const [Color(0xFF1E2818), _cardDark]
      };
    }
    if (lower.contains('снек') || lower.contains('чипс') || lower.contains('орех')) {
      return {
        'icon': Icons.emoji_food_beverage,
        'color': accent,
        'gradient': const [Color(0xFF2A2418), _cardDark]
      };
    }
    if (lower.contains('молочн') || lower.contains('сыр')) {
      return {
        'icon': Icons.icecream,
        'color': accent,
        'gradient': const [Color(0xFF202430), _cardDark]
      };
    }
    if (lower.contains('мясо') || lower.contains('рыба') || lower.contains('колбас') || lower.contains('сосиск')) {
      return {
        'icon': Icons.set_meal,
        'color': accent,
        'gradient': const [Color(0xFF2A1C1A), _cardDark]
      };
    }
    if (lower.contains('хлеб') || lower.contains('выпечк') || lower.contains('булочк') || lower.contains('батон')) {
      return {
        'icon': Icons.bakery_dining,
        'color': accent,
        'gradient': const [Color(0xFF2A2418), _cardDark]
      };
    }
    return {
      'icon': Icons.category,
      'color': accentAlt,
      'gradient': const [_blue, _cardDark]
    };
  }

  String? _extractCategoryImage(Map<String, dynamic> category) {
    final image = category['image'] ?? category['img'];
    if (image == null) return null;
    final value = image.toString().trim();
    return value.isEmpty ? null : value;
  }

  Widget _buildCategoryLeading(String? imageUrl, Map<String, dynamic> style, {double size = 28}) {
    if (imageUrl == null) {
      return Icon(style['icon'], color: style['color'], size: size * 0.72);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.36),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.white.withValues(alpha: 0.08),
            alignment: Alignment.center,
            child: Icon(style['icon'], color: style['color'], size: size * 0.64),
          ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.white.withValues(alpha: 0.08),
              alignment: Alignment.center,
              child: SizedBox(
                width: size * 0.5,
                height: size * 0.5,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>((style['color'] as Color?) ?? _orange),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  U I   L A Y E R
  // ═══════════════════════════════════════════════════════════

  // ─── Background ──────────────────────────────────────────
  Widget _background() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgDeep],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.5, -0.8),
              radius: 1.6,
              colors: [Colors.white.withValues(alpha: 0.03), Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────
  Widget _buildHeader({required bool showLogoBackground}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: showLogoBackground
                ? BoxDecoration(
                    color: _cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  )
                : null,
            child: SvgPicture.asset(
              'assets/logo_new.svg',
              height: 46,
            ),
          ),
          const Spacer(),
          _shopChip(),
        ],
      ),
    );
  }

  String _compactShopAddress(String rawAddress, String? cityName) {
    final trimmed = rawAddress.trim();
    if (trimmed.isEmpty || cityName == null || cityName.trim().isEmpty) {
      return trimmed;
    }

    final parts = trimmed.split(',').map((part) => part.trim()).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return trimmed;

    final lastPart = parts.last.toLowerCase();
    final normalizedCity = cityName.trim().toLowerCase();
    if (lastPart == normalizedCity) {
      parts.removeLast();
    }

    return parts.join(', ');
  }

  /// Compact shop chip shown in the header row next to the logo.
  Widget _shopChip() {
    final selected = widget.selectedBusiness;
    final cityLabel = widget.selectedCity ?? 'Все города';
    final chipMaxWidth = MediaQuery.of(context).size.width * 0.48;
    final String title;
    final String subtitle;
    final String? shopAddress;
    if (selected != null) {
      final shopName = (selected['name'] ?? selected['title'] ?? 'Магазин').toString();
      title = '$cityLabel - $shopName';
      subtitle = cityLabel;
      final rawAddress = selected['address'] ?? selected['subtitle'];
      final addressText = rawAddress?.toString().trim() ?? '';
      final compactAddress = _compactShopAddress(addressText, cityLabel);
      shopAddress = compactAddress.isEmpty ? null : compactAddress;
    } else {
      title = widget.businesses.isEmpty ? '$cityLabel - Нет магазинов' : '$cityLabel - Все магазины';
      subtitle = cityLabel;
      shopAddress = null;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: widget.isLoadingBusinesses ? null : _showBusinessSelectorSheet,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: chipMaxWidth),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                width: constraints.maxWidth,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.storefront_rounded, color: _orange, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _textMute.withValues(alpha: 0.72),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            shopAddress ?? subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _text,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    widget.isLoadingBusinesses
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.5, color: _orange))
                        : const Icon(Icons.expand_more_rounded, color: _textMute, size: 18),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── Address + Shop Row ──────────────────────────────────
  Widget _addressShopRow({required bool showLogoBackground}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo + shop chip row
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _buildHeader(showLogoBackground: showLogoBackground),
          ),
          // Address pill — full width
          _addressPill(),
        ],
      ),
    );
  }

  Widget _addressPill() {
    final addressText = ApiService.formatAddressSummary(_selectedAddress, emptyText: 'Укажите адрес');
    return GestureDetector(
      onTap: _showAddressSelectionModal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.location_on_rounded, color: _orange, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                addressText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _text, fontSize: 12, fontWeight: FontWeight.w800, height: 1.15),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, color: _textMute, size: 20),
          ],
        ),
      ),
    );
  }

  // ─── Search ──────────────────────────────────────────────
  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchPage())),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: _textMute.withValues(alpha: 0.7), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Найти любимый напиток...',
                  style: TextStyle(color: _textMute.withValues(alpha: 0.6), fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.tune_rounded, color: _textMute.withValues(alpha: 0.7), size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Promotions ──────────────────────────────────────────
  Widget _promotionsSection() {
    if (_isLoadingPromotions) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: _orange)));
    }
    if (_promotionsError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(_promotionsError!, style: const TextStyle(color: _textMute)),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadPromotions, child: const Text('Повторить', style: TextStyle(color: _orange))),
          ],
        ),
      );
    }
    if (_promotions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              Icon(Icons.local_offer_outlined, color: _textMute.withValues(alpha: 0.5), size: 36),
              const SizedBox(height: 10),
              const Text('Акции пока не найдены', style: TextStyle(color: _text, fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 4),
              const Text('Выберите магазин или обновите страницу', style: TextStyle(color: _textMute, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        CarouselSlider.builder(
          carouselController: _promoCarouselController,
          itemCount: _promotions.length,
          itemBuilder: (_, i, __) => _promotionCard(_promotions[i]),
          options: CarouselOptions(
            height: 200,
            viewportFraction: 0.92,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 5),
            enlargeCenterPage: true,
            enlargeStrategy: CenterPageEnlargeStrategy.scale,
            enlargeFactor: 0.18,
            padEnds: true,
            onPageChanged: (index, _) => setState(() => _currentPromoIndex = index),
          ),
        ),
        const SizedBox(height: 14),
        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _promotions.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _currentPromoIndex ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == _currentPromoIndex ? _orange : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _promotionCard(Promotion promo) {
    final bizId =
        widget.selectedBusiness != null ? (widget.selectedBusiness!['id'] as int?) ?? (widget.selectedBusiness!['businessId'] as int?) : null;
    final hasCover = promo.cover != null && promo.cover!.trim().isNotEmpty;

    return GestureDetector(
      onTap: bizId != null
          ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PromotionItemsPage(
                    promotionId: promo.marketingPromotionId,
                    promotionName: promo.name,
                    businessId: bizId,
                  ),
                ),
              )
          : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background
              if (hasCover)
                Image.network(
                  promo.cover!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _promotionPlaceholder(promo),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return _promotionPlaceholder(promo, showLoader: true);
                  },
                )
              else
                _promotionPlaceholder(promo),
              // Gradient overlay
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                    colors: [Color(0xDD000000), Colors.transparent],
                  ),
                ),
              ),
              // Content
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(8)),
                      child: const Text('Акция', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 11)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      promo.name ?? 'Акция',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w900, height: 1.2),
                    ),
                    if (promo.details.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        promo.details.first.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _text.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _promotionPlaceholder(Promotion promo, {bool showLoader = false}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_red, _cardDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            top: -10,
            child: Icon(Icons.local_offer_outlined, size: 80, color: Colors.white.withValues(alpha: 0.06)),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_size_select_actual_outlined, color: Colors.white.withValues(alpha: 0.6), size: 32),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    promo.name ?? 'Акция',
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                if (showLoader) ...[
                  const SizedBox(height: 12),
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(_text)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Supercategories ─────────────────────────────────────
  Widget _superCategoriesSection() {
    if (_isLoadingSuperCategories) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(color: _orange, strokeWidth: 2.5)),
      );
    }
    if (_superCategoriesError != null) {
      return _errorRow(_superCategoriesError!, _loadSuperCategories);
    }
    if (_superCategories.isEmpty) {
      return _emptyHint('Категории недоступны', Icons.inbox_rounded);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Категории'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.0,
          children: _superCategories.map((sc) {
            final name = sc['name']?.toString() ?? 'Раздел';
            final style = _getCategoryIconAndColor(name);
            // Use image from first nested category to represent supercategory
            final cats = (sc['categories'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
            final imageUrl =
                cats.length > 1 ? _extractCategoryImage(cats[1]) : (cats.isNotEmpty ? _extractCategoryImage(cats.first) : _extractCategoryImage(sc));
            return _superCategoryTile(sc, style, imageUrl);
          }).toList(),
        ),
      ],
    );
  }

  Widget _superCategoryTile(Map<String, dynamic> superCat, Map<String, dynamic> style, String? imageUrl) {
    final name = superCat['name']?.toString() ?? 'Раздел';
    final cats = (superCat['categories'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    return GestureDetector(
      onTap: () {
        final businessId = widget.selectedBusiness?['id'] ?? widget.selectedBusiness?['business_id'] ?? widget.selectedBusiness?['businessId'];
        if (businessId == null) {
          _showMessageDialog('Магазин не выбран', 'Сначала выберите магазин, чтобы открыть категорию.');
          return;
        }
        if (cats.isEmpty) return;
        // Navigate to the first category in this supercategory
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CategoryPage(
              category: Category.fromJson(cats.first),
              allCategories: cats.map((c) => Category.fromJson(c)).toList(),
              businessId: businessId,
            ),
          ),
        );
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _cardDark,
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _categoryFallback(style),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return _categoryFallback(style, showLoader: true);
                },
              )
            else
              _categoryFallback(style),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.4, 1.0],
                  colors: [
                    Colors.transparent,
                    Color(0x18000000),
                    Color(0xCC000000),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryTile(Map<String, dynamic> cat, Map<String, dynamic> style, String? imageUrl) {
    final name = cat['name'] ?? 'Категория';
    return GestureDetector(
      onTap: () {
        final businessId = widget.selectedBusiness?['id'] ?? widget.selectedBusiness?['business_id'] ?? widget.selectedBusiness?['businessId'];
        if (businessId == null) {
          _showMessageDialog('Магазин не выбран', 'Сначала выберите магазин, чтобы открыть категорию.');
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CategoryPage(
              category: Category.fromJson(cat),
              allCategories: _superCategories
                  .expand((sc) => (sc['categories'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[])
                  .map((c) => Category.fromJson(c))
                  .toList(),
              businessId: businessId,
            ),
          ),
        );
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _cardDark,
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Full-size image or icon fallback
            if (imageUrl != null)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _categoryFallback(style),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return _categoryFallback(style, showLoader: true);
                },
              )
            else
              _categoryFallback(style),
            // Gradient scrim for text readability
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.4, 1.0],
                  colors: [
                    Colors.transparent,
                    Color(0x18000000),
                    Color(0xCC000000),
                  ],
                ),
              ),
            ),
            // Category name at bottom
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryFallback(Map<String, dynamic> style, {bool showLoader = false}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: (style['gradient'] as List<Color>?) ?? [_blue, _cardDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: showLoader
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _orange, strokeWidth: 2))
            : Icon(style['icon'] as IconData? ?? Icons.category, color: (style['color'] as Color? ?? _orange).withValues(alpha: 0.5), size: 36),
      ),
    );
  }

  // ─── Recently in Cart ────────────────────────────────────
  Widget _productDiscoveryRow() {
    final cart = Provider.of<CartProvider>(context);
    if (cart.items.isEmpty) return const SizedBox.shrink();
    final items = cart.items.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('В корзине'),
        const SizedBox(height: 10),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final item = items[i];
              return Container(
                width: 140,
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: item.image != null
                              ? Image.network(item.image!, width: double.infinity, fit: BoxFit.cover)
                              : Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [_blue, _cardDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(child: Icon(Icons.image_outlined, color: _textMute.withValues(alpha: 0.3), size: 28)),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.quantity} шт',
                        style: TextStyle(color: _textMute.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.totalPrice.toStringAsFixed(0)} ₸',
                        style: const TextStyle(color: _orange, fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Bonuses ─────────────────────────────────────────────
  Widget _bonusesSection() {
    final bonusData = _bonuses?['data'];
    final totalBonuses = (bonusData?['totalBonuses'] as num?)?.toDouble();
    final cardUuid = bonusData?['bonusCard']?['cardUuid']?.toString();
    final history = (bonusData?['bonusHistory'] as List?) ?? const [];
    final isLoginRequired = _bonuses == null && _bonusesError != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.card_giftcard_rounded, color: _orange, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Бонусная карта', style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            if (isLoginRequired)
              TextButton.icon(
                onPressed: _openLoginPage,
                icon: const Icon(Icons.login_rounded, size: 16),
                label: const Text('Войти'),
                style: TextButton.styleFrom(foregroundColor: _orange, textStyle: const TextStyle(fontWeight: FontWeight.w800)),
              )
            else
              IconButton(
                onPressed: _isLoadingBonuses ? null : _loadBonuses,
                icon: const Icon(Icons.refresh_rounded, color: _textMute, size: 20),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF1C1A16), _card],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: _orange.withValues(alpha: 0.12)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))],
          ),
          child: _isLoadingBonuses
              ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(color: _orange)))
              : _bonusesError != null
                  ? _bonusErrorContent(isLoginRequired)
                  : _bonusContent(totalBonuses, cardUuid, history),
        ),
      ],
    );
  }

  Widget _bonusErrorContent(bool isLoginRequired) {
    return Column(
      children: [
        Icon(
          isLoginRequired ? Icons.person_outline_rounded : Icons.warning_amber_rounded,
          color: _textMute,
          size: 36,
        ),
        const SizedBox(height: 10),
        Text(
          _bonusesError!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _text, fontSize: 14),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: isLoginRequired ? _openLoginPage : _loadBonuses,
          style: ElevatedButton.styleFrom(
            backgroundColor: _orange,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text(isLoginRequired ? 'Войти' : 'Обновить', style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _bonusContent(double? totalBonuses, String? cardUuid, List history) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Balance row
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Баланс', style: TextStyle(color: _textMute.withValues(alpha: 0.8), fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        totalBonuses != null ? totalBonuses.toStringAsFixed(0) : '—',
                        style: const TextStyle(color: _orange, fontSize: 34, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(width: 6),
                      Text('бонусов', style: TextStyle(color: _textMute.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => BonusHistoryPage(history: history)));
              },
              icon: const Icon(Icons.history_rounded, size: 16),
              label: const Text('История'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ],
        ),
        // QR Code
        if (cardUuid != null && _qrPayload != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                BarcodeWidget(
                  data: _qrPayload!,
                  barcode: Barcode.qrCode(),
                  color: Colors.black,
                  width: double.infinity,
                  height: 180,
                  backgroundColor: Colors.transparent,
                ),
                const SizedBox(height: 8),
                Text(
                  'Покажите QR на кассе',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'QR обновляется каждую минуту',
              style: TextStyle(color: _textMute.withValues(alpha: 0.6), fontSize: 11),
            ),
          ),
        ] else if (cardUuid == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Карта не найдена', style: TextStyle(color: _textMute.withValues(alpha: 0.7))),
          ),
      ],
    );
  }

  // ─── Reusable UI Blocks ──────────────────────────────────
  Widget _sectionHeader(String title) {
    return Text(title, style: const TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w800));
  }

  Widget _errorRow(String message, VoidCallback onRetry) {
    return Row(
      children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(color: _textMute, fontSize: 13))),
        TextButton(onPressed: onRetry, child: const Text('Повторить', style: TextStyle(color: _orange))),
      ],
    );
  }

  Widget _emptyHint(String message, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: _textMute.withValues(alpha: 0.5), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: _textMute, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _emptyCityBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline, color: _orange, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'В городе ${widget.selectedCity} пока не найдено доступных магазинов. Можно выбрать другой город.',
              style: const TextStyle(color: _text, height: 1.3, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Floating Active Orders ──────────────────────────────
  Widget _floatingActiveOrdersButton() {
    final total = _activeOrders.length;
    final bottomOffset = MediaQuery.of(context).padding.bottom + 122;

    return Positioned(
      right: 16,
      bottom: bottomOffset,
      child: SafeArea(
        top: false,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => OrdersHistoryPage(initialActiveOrders: _activeOrders)),
              );
              _loadActiveOrders();
            },
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _orange,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.receipt_long_rounded, color: Colors.black, size: 18),
                  const SizedBox(width: 8),
                  Container(
                    constraints: const BoxConstraints(minWidth: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(999)),
                    child: Text(
                      '$total',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _orange, fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Bottom Sheets ───────────────────────────────────────
  Future<void> _showBusinessSelectorSheet() async {
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      backgroundColor: _card,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      builder: (ctx) {
        return _ShopCitySheet(
          allBusinesses: widget.allBusinesses,
          availableCities: widget.availableCities,
          selectedCity: widget.selectedCity,
          selectedBusiness: widget.selectedBusiness,
        );
      },
    );

    if (!mounted || result == null) return;

    if (result is Map<String, dynamic>) {
      // A shop was picked — check if we need to change city first
      final shopCity = result['_cityName']?.toString() ?? '';
      if (shopCity.isNotEmpty && shopCity != widget.selectedCity) {
        widget.onCityChanged(shopCity);
        // Small delay to let city filter settle, then select the shop
        await Future.delayed(const Duration(milliseconds: 150));
        if (!mounted) return;
      }
      widget.onBusinessSelected(result);
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  B U I L D
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const navHeight = 110.0;
    final bottomPadding = bottomInset + navHeight;

    return Scaffold(
      backgroundColor: _bgDeep,
      body: Stack(
        children: [
          _background(),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Address + shop row ( pinned, includes logo ) ──
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SlimHeaderDelegate(
                    minExtent: 138,
                    maxExtent: 142,
                    builder: (context, _, overlapsContent) => _addressShopRow(showLogoBackground: overlapsContent),
                  ),
                ),
                // ── Search ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _searchBar(),
                  ),
                ),
                // ── Empty city banner ──
                if (widget.selectedCity != null && widget.businesses.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    sliver: SliverToBoxAdapter(child: _emptyCityBanner()),
                  ),
                // ── Promotions ──
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                  sliver: SliverToBoxAdapter(child: _promotionsSection()),
                ),
                // ── Supercategories ──
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(child: _superCategoriesSection()),
                ),
                // ── Cart discovery row ──
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  sliver: SliverToBoxAdapter(child: _productDiscoveryRow()),
                ),
                // ── Bonuses ──
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 18, 16, bottomPadding),
                  sliver: SliverToBoxAdapter(child: _bonusesSection()),
                ),
              ],
            ),
          ),
          if (_activeOrders.isNotEmpty) _floatingActiveOrdersButton(),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  Pinned address‑bar delegate
// ═════════════════════════════════════════════════════════════
class _SlimHeaderDelegate extends SliverPersistentHeaderDelegate {
  @override
  final double minExtent;
  @override
  final double maxExtent;
  final Widget Function(BuildContext context, double shrinkOffset, bool overlapsContent) builder;

  _SlimHeaderDelegate({required this.minExtent, required this.maxExtent, required this.builder});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0x00000000),
      alignment: Alignment.centerLeft,
      child: builder(context, shrinkOffset, overlapsContent),
    );
  }

  @override
  bool shouldRebuild(covariant _SlimHeaderDelegate oldDelegate) {
    return oldDelegate.minExtent != minExtent || oldDelegate.maxExtent != maxExtent || oldDelegate.builder != builder;
  }
}

// ═════════════════════════════════════════════════════════════
//  Combined Shop + City selector sheet
// ═════════════════════════════════════════════════════════════
class _ShopCitySheet extends StatefulWidget {
  final List<Map<String, dynamic>> allBusinesses;
  final List<String> availableCities;
  final String? selectedCity;
  final Map<String, dynamic>? selectedBusiness;

  const _ShopCitySheet({
    required this.allBusinesses,
    required this.availableCities,
    required this.selectedCity,
    required this.selectedBusiness,
  });

  @override
  State<_ShopCitySheet> createState() => _ShopCitySheetState();
}

class _ShopCitySheetState extends State<_ShopCitySheet> {
  static const Color _cardDark = Color(0xFF181818);
  static const Color _orange = Color(0xFFF6A10C);
  static const Color _text = Colors.white;
  static const Color _textMute = Color(0xFF9FB0C8);

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _selectedShopKey = GlobalKey();

  /// Group businesses by their resolved city name, ordered by availableCities.
  Map<String, List<Map<String, dynamic>>> _groupedByCity() {
    final groups = <String, List<Map<String, dynamic>>>{};
    // Initialize in the order of availableCities
    for (final city in widget.availableCities) {
      groups[city] = [];
    }
    groups['Другое'] = [];

    for (final b in widget.allBusinesses) {
      final city = b['_cityName']?.toString() ?? '';
      if (city.isNotEmpty && groups.containsKey(city)) {
        groups[city]!.add(b);
      } else if (city.isNotEmpty) {
        // City name resolved but not in availableCities list
        groups.putIfAbsent(city, () => []);
        groups[city]!.add(b);
      } else {
        groups['Другое']!.add(b);
      }
    }
    // Remove empty groups
    groups.removeWhere((_, shops) => shops.isEmpty);
    return groups;
  }

  bool _isSelected(Map<String, dynamic> shop) {
    if (widget.selectedBusiness == null) return false;
    return widget.selectedBusiness!['id'] == shop['id'];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedContext = _selectedShopKey.currentContext;
      if (selectedContext != null) {
        Scrollable.ensureVisible(
          selectedContext,
          alignment: 0.35,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.8;
    final grouped = _groupedByCity();

    // Build flat list: [city header, shop, shop, city header, shop, ...]
    final items = <_SheetItem>[];
    for (final entry in grouped.entries) {
      items.add(_SheetItem.header(entry.key, entry.value.length, entry.key == widget.selectedCity));
      for (final shop in entry.value) {
        items.add(_SheetItem.shop(shop, _isSelected(shop)));
      }
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // ── Title
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Выберите магазин',
                  style: TextStyle(color: _text, fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            // ── Subtitle
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Цены и ассортимент могут отличаться',
                  style: TextStyle(color: _textMute.withValues(alpha: 0.6), fontSize: 13),
                ),
              ),
            ),
            // ── Grouped list
            Flexible(
              child: widget.allBusinesses.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.store_mall_directory, color: _textMute, size: 32),
                          SizedBox(height: 10),
                          Text('Магазины не найдены', style: TextStyle(color: _text, fontSize: 15)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      itemCount: items.length,
                      itemBuilder: (ctx, i) {
                        final item = items[i];
                        if (item.isHeader) {
                          return _cityHeader(item.cityName!, item.shopCount!, item.isCurrentCity!);
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _shopCard(ctx, item.business!, item.isSelectedShop!),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cityHeader(String city, int count, bool isCurrent) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Icon(
            isCurrent ? Icons.my_location_rounded : Icons.location_city_rounded,
            size: 16,
            color: isCurrent ? _orange : _textMute.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          Text(
            city,
            style: TextStyle(
              color: isCurrent ? _orange : _text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isCurrent ? _orange.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: isCurrent ? _orange : _textMute.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (isCurrent) ...[
            const Spacer(),
            Text(
              'ваш город',
              style: TextStyle(color: _orange.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _shopCard(BuildContext context, Map<String, dynamic> shop, bool isSelected) {
    final name = (shop['name'] ?? shop['title'] ?? 'Магазин').toString();
    final addr = (shop['address'] ?? shop['subtitle'] ?? '').toString();

    return GestureDetector(
      onTap: () => Navigator.pop(context, shop),
      child: Container(
        key: isSelected ? _selectedShopKey : null,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? _orange.withValues(alpha: 0.10) : _cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _orange.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.04),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? _orange.withValues(alpha: 0.18) : _orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isSelected ? Icons.check_circle_rounded : Icons.storefront_rounded,
                color: _orange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? _orange : _text,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (addr.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      addr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _textMute.withValues(alpha: 0.85), fontSize: 13, height: 1.2),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.check_rounded, color: _orange, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}

/// Simple tagged union for the grouped list.
class _SheetItem {
  final bool isHeader;
  final String? cityName;
  final int? shopCount;
  final bool? isCurrentCity;
  final Map<String, dynamic>? business;
  final bool? isSelectedShop;

  _SheetItem._({
    required this.isHeader,
    this.cityName,
    this.shopCount,
    this.isCurrentCity,
    this.business,
    this.isSelectedShop,
  });

  factory _SheetItem.header(String city, int count, bool isCurrent) =>
      _SheetItem._(isHeader: true, cityName: city, shopCount: count, isCurrentCity: isCurrent);

  factory _SheetItem.shop(Map<String, dynamic> b, bool selected) => _SheetItem._(isHeader: false, business: b, isSelectedShop: selected);
}
