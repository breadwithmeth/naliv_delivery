import 'dart:async';
import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:carousel_slider/carousel_slider.dart';
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
  // Palette
  static const Color _bgDeep = Color(0xFF121212); // matte black base
  static const Color _bgTop = Color(0xFF161616); // subtle top tint
  static const Color _card = Color(0xFF1E1E1E); // surface
  static const Color _cardDark = Color(0xFF181818); // deep surface
  static const Color _blue = Color(0xFF242A32); // cool accent for chips
  static const Color _orange = Color(0xFFF6A10C); // vivid amber/gold
  static const Color _red = Color(0xFFC23B30);
  static const Color _text = Colors.white;
  static const Color _textMute = Color(0xFF9FB0C8);
  static const double _selectorMinHeight = 84;

  final CarouselSliderController _promoCarouselController = CarouselSliderController();
  final LocationService _locationService = LocationService.instance;
  StreamSubscription<Map<String, dynamic>?>? _addressSubscription;
  String? _lastPromptKey;

  List<Promotion> _promotions = [];
  bool _isLoadingPromotions = false;
  String? _promotionsError;

  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingCategories = false;
  String? _categoriesError;

  Map<String, dynamic>? _selectedAddress;

  Map<String, dynamic>? _bonuses;
  bool _isLoadingBonuses = true;
  String? _bonusesError;
  String? _activeCardUuid;
  String? _qrPayload;
  Timer? _qrTimer;
  List<Map<String, dynamic>> _activeOrders = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _selectedAddress = widget.selectedAddress;

    _addressSubscription = AddressStorageService.selectedAddressStream.listen((addr) {
      if (!mounted) return;
      setState(() => _selectedAddress = addr);
      if (addr != null) {
        if (widget.selectedBusiness == null) {
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
    _loadCategories();
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
      _loadCategories();
    }

    if (oldWidget.selectedAddress != widget.selectedAddress) {
      setState(() => _selectedAddress = widget.selectedAddress);
    }
  }

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

  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() {
      _isLoadingCategories = true;
      _categoriesError = null;
    });
    try {
      final int? businessId = widget.selectedBusiness != null
          ? widget.selectedBusiness!['id'] ?? widget.selectedBusiness!['business_id'] ?? widget.selectedBusiness!['businessId']
          : null;
      final cats = await ApiService.getCategories(businessId: businessId);
      if (!mounted) return;
      setState(() {
        _categories = cats ?? [];
        _isLoadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _categoriesError = 'Ошибка загрузки категорий: $e';
        _isLoadingCategories = false;
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

  // ---------------- Address / business selection ----------------
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
    final selectedAddress = await AddressSelectionModalHelper.show(context);
    if (selectedAddress != null && mounted) {
      await AddressStorageService.saveSelectedAddress(selectedAddress);
      await AddressStorageService.addToAddressHistory({
        'name': selectedAddress['address'],
        'point': {'lat': selectedAddress['lat'], 'lon': selectedAddress['lon']},
      });
      setState(() => _selectedAddress = selectedAddress);
      if (widget.selectedBusiness == null) {
        _autoSelectNearestBusiness();
      } else {
        _maybePromptNearestSwitch();
      }
    }
  }

  void _autoSelectNearestBusiness() {
    if (_selectedAddress == null || widget.businesses.isEmpty || widget.selectedBusiness != null) return;
    final coords = _extractAddressLatLon(_selectedAddress!);
    if (coords == null) return;
    final nearest = _findNearestBusiness(coords['lat']!, coords['lon']!);
    if (nearest != null) widget.onBusinessSelected(nearest);
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

  // ---------------- UI helpers ----------------
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
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.4, -0.6),
                    radius: 1.2,
                    colors: [Colors.white.withValues(alpha: 0.04), Colors.transparent],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.6, 0.8),
                    radius: 1.4,
                    colors: [Colors.white.withValues(alpha: 0.03), Colors.transparent],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('ГРАДУСЫ', style: TextStyle(color: _text, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          ),
        ),
        const SizedBox(width: 12),
        _citySwitcher(),
      ],
    );
  }

  Widget _citySwitcher() {
    final cityLabel = widget.selectedCity ?? 'Выбрать город';
    final shopsLabel = widget.businesses.isEmpty ? 'нет магазинов' : '${widget.businesses.length} магаз.';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _showCitySelectorSheet,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_city_rounded, color: _orange, size: 18),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cityLabel, style: const TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.w800)),
                  Text(shopsLabel, style: TextStyle(color: _textMute.withValues(alpha: 0.92), fontSize: 10.5, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(width: 6),
              const Icon(Icons.unfold_more_rounded, color: _textMute, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slimAddressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(child: _addressCard()),
          const SizedBox(width: 10),
          Expanded(child: _businessSelector()),
        ],
      ),
    );
  }

  Widget _addressCard() {
    final addressText = ApiService.formatAddressSummary(_selectedAddress, emptyText: 'Укажите адрес доставки');
    return Container(
      constraints: const BoxConstraints(minHeight: _selectorMinHeight),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _showAddressSelectionModal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.location_pin, color: _orange, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Адрес доставки',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _textMute.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    addressText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _text, fontSize: 14, fontWeight: FontWeight.w800, height: 1.15),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down, color: _textMute),
          ],
        ),
      ),
    );
  }

  Widget _businessSelector() {
    final selected = widget.selectedBusiness;
    final title = selected != null
        ? (selected['name'] ?? selected['title'] ?? 'Магазин')
        : widget.businesses.isEmpty
            ? 'Нет магазинов в городе'
            : 'Выберите магазин';

    return Container(
      constraints: const BoxConstraints(minHeight: _selectorMinHeight),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.isLoadingBusinesses ? null : _showBusinessSelectorSheet,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.storefront, color: _orange, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Магазин',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _textMute.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _text, fontSize: 14, fontWeight: FontWeight.w800, height: 1.15),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            widget.isLoadingBusinesses
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.keyboard_arrow_down, color: _textMute),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchPage())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: const [
            Icon(Icons.search, color: _textMute),
            SizedBox(width: 10),
            Expanded(
              child: Text('Найти любимый напиток...', style: TextStyle(color: _textMute, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            Icon(Icons.tune, color: _textMute),
          ],
        ),
      ),
    );
  }

  Widget _promotionsSection() {
    if (_isLoadingPromotions) {
      return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
    }
    if (_promotionsError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(_promotionsError!, style: const TextStyle(color: _text)),
            TextButton(onPressed: _loadPromotions, child: const Text('Повторить')),
          ],
        ),
      );
    }

    if (_promotions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Акции пока не найдены', style: TextStyle(color: _text, fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('Попробуйте выбрать другой магазин или обновить страницу.', style: TextStyle(color: _textMute)),
          ],
        ),
      );
    }

    return CarouselSlider.builder(
      carouselController: _promoCarouselController,
      itemCount: _promotions.length,
      itemBuilder: (_, i, __) => _promotionCard(_promotions[i]),
      options: CarouselOptions(
        height: 230,
        viewportFraction: 0.95,
        autoPlay: true,
        autoPlayInterval: const Duration(seconds: 5),
        enlargeCenterPage: true,
        enlargeStrategy: CenterPageEnlargeStrategy.height,
        disableCenter: true,
        padEnds: true,
      ),
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
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 14))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              Positioned.fill(
                child: hasCover
                    ? Image.network(
                        promo.cover!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _promotionPlaceholder(promo),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return _promotionPlaceholder(promo, showLoader: true);
                        },
                      )
                    : Container(
                        child: _promotionPlaceholder(promo),
                      ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xAA000000), Colors.transparent],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(12)),
                      child: const Text('Акция', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      promo.name ?? 'Акция',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _text, fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      promo.details.isNotEmpty ? promo.details.first.name : 'Скидка и спецпредложения',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _text.withValues(alpha: 0.9), fontSize: 14, fontWeight: FontWeight.w700),
                    ),
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
            right: -18,
            top: -12,
            child: Icon(Icons.local_offer_outlined, size: 92, color: Colors.white.withValues(alpha: 0.08)),
          ),
          Positioned(
            left: 18,
            top: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Text('Нет изображения', style: TextStyle(color: _text, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_size_select_actual_outlined, color: Colors.white.withValues(alpha: 0.82), size: 38),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    promo.name ?? 'Акция',
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                if (showLoader) ...[
                  const SizedBox(height: 14),
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation<Color>(_text)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoriesSection() {
    if (_isLoadingCategories) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 3),
      );
    }
    if (_categoriesError != null) {
      return Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 8),
          Expanded(child: Text(_categoriesError!, style: const TextStyle(color: _text))),
          TextButton(onPressed: _loadCategories, child: const Text('Повторить')),
        ],
      );
    }

    if (_categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: const [
            Icon(Icons.inbox, color: _textMute),
            SizedBox(width: 8),
            Expanded(child: Text('Категории недоступны для выбранного магазина', style: TextStyle(color: _text))),
          ],
        ),
      );
    }

    final visible = _categories.take(12).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Категории', style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: visible.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final cat = visible[i];
              final style = _getCategoryIconAndColor(cat['name'] ?? '');
              final categoryImage = _extractCategoryImage(cat);
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  final businessId =
                      widget.selectedBusiness?['id'] ?? widget.selectedBusiness?['business_id'] ?? widget.selectedBusiness?['businessId'];
                  if (businessId == null) {
                    _showMessageDialog('Магазин не выбран', 'Сначала выберите магазин, чтобы открыть категорию.');
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CategoryPage(
                        category: Category.fromJson(cat),
                        allCategories: _categories.map((c) => Category.fromJson(c)).toList(),
                        businessId: businessId,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                        colors: (style['gradient'] as List<Color>?) ?? [_blue, _cardDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 8))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCategoryLeading(categoryImage, style),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(cat['name'] ?? 'Категория',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _text, fontSize: 14, fontWeight: FontWeight.w700)),
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

  Widget _productDiscoveryRow() {
    final cart = Provider.of<CartProvider>(context);
    if (cart.items.isEmpty) return const SizedBox.shrink();
    final items = cart.items.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Недавно в корзине', style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final item = items[i];
              return Container(
                width: 200,
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 10))],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
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
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _text, fontSize: 14, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('${item.quantity} шт • ${item.price.toStringAsFixed(0)} ₸',
                          style: TextStyle(color: _textMute.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('Итого: ${item.totalPrice.toStringAsFixed(0)} ₸',
                          style: const TextStyle(color: _orange, fontWeight: FontWeight.w900, fontSize: 14)),
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

  Map<String, dynamic> _getCategoryIconAndColor(String name) {
    const accent = _orange;
    const accentAlt = _red;
    const defGrad = [_blue, _cardDark];
    final lower = name.toLowerCase();
    if (lower.contains('пиво')) return {'icon': Icons.sports_bar, 'color': accent, 'gradient': defGrad};
    if (lower.contains('вино')) return {'icon': Icons.wine_bar, 'color': accent, 'gradient': defGrad};
    if (lower.contains('виски') || lower.contains('коньяк') || lower.contains('бурбон')) {
      return {'icon': Icons.local_bar, 'color': accent, 'gradient': defGrad};
    }
    if (lower.contains('игрист') || lower.contains('шампан')) {
      return {'icon': Icons.celebration, 'color': accent, 'gradient': defGrad};
    }
    if (lower.contains('крепкий') || lower.contains('водка')) {
      return {'icon': Icons.local_drink, 'color': accent, 'gradient': defGrad};
    }
    if (lower.contains('сигарет') || lower.contains('табак') || lower.contains('курение')) {
      return {'icon': Icons.smoking_rooms, 'color': accent, 'gradient': defGrad};
    }
    if (lower.contains('сладост') || lower.contains('конфет') || lower.contains('шоколад') || lower.contains('печенье')) {
      return {'icon': Icons.cake, 'color': accent, 'gradient': defGrad};
    }
    if (lower.contains('напитк') || lower.contains('сок') || lower.contains('вода') || lower.contains('газировка') || lower.contains('лимонад')) {
      return {'icon': Icons.bubble_chart, 'color': accent, 'gradient': defGrad};
    }
    if (lower.contains('фрукт') || lower.contains('овощ') || lower.contains('ягод') || lower.contains('зелен')) {
      return {'icon': Icons.eco, 'color': accent, 'gradient': defGrad};
    }
    if (lower.contains('снек') || lower.contains('чипс') || lower.contains('орех')) {
      return {'icon': Icons.emoji_food_beverage, 'color': accent, 'gradient': defGrad};
    }
    if (lower.contains('молочн') || lower.contains('сыр')) {
      return {'icon': Icons.icecream, 'color': accent, 'gradient': defGrad};
    }
    if (lower.contains('мясо') || lower.contains('рыба') || lower.contains('колбас') || lower.contains('сосиск')) {
      return {'icon': Icons.set_meal, 'color': accent, 'gradient': defGrad};
    }
    if (lower.contains('хлеб') || lower.contains('выпечк') || lower.contains('булочк') || lower.contains('батон')) {
      return {'icon': Icons.bakery_dining, 'color': accent, 'gradient': defGrad};
    }
    return {'icon': Icons.category, 'color': accentAlt, 'gradient': defGrad};
  }

  String? _extractCategoryImage(Map<String, dynamic> category) {
    final image = category['image'] ?? category['img'];
    if (image == null) return null;
    final value = image.toString().trim();
    return value.isEmpty ? null : value;
  }

  Widget _buildCategoryLeading(String? imageUrl, Map<String, dynamic> style) {
    if (imageUrl == null) {
      return Icon(style['icon'], color: style['color'], size: 20);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 28,
        height: 28,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.white.withValues(alpha: 0.08),
            alignment: Alignment.center,
            child: Icon(style['icon'], color: style['color'], size: 18),
          ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.white.withValues(alpha: 0.08),
              alignment: Alignment.center,
              child: SizedBox(
                width: 14,
                height: 14,
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
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
    );

    if (mounted) {
      _loadBonuses();
    }
  }

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
            const Text('Бонусы', style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w800)),
            const Spacer(),
            if (isLoginRequired)
              TextButton(
                onPressed: _openLoginPage,
                style: TextButton.styleFrom(
                  foregroundColor: _orange,
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                child: const Text('Войти'),
              )
            else
              IconButton(
                onPressed: _isLoadingBonuses ? null : _loadBonuses,
                icon: const Icon(Icons.refresh, color: _textMute),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: _card,
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 10))],
          ),
          child: _isLoadingBonuses
              ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()))
              : _bonusesError != null
                  ? Column(
                      crossAxisAlignment: _bonuses == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                      children: [
                        if (_bonuses == null)
                          SizedBox(
                            width: double.infinity,
                            child: Column(
                              children: [
                                Text(_bonusesError!, textAlign: TextAlign.center, style: const TextStyle(color: _text)),
                                const SizedBox(height: 8),
                              ],
                            ),
                          )
                        else ...[
                          Text(_bonusesError!, style: const TextStyle(color: _text)),
                          const SizedBox(height: 8),
                        ],
                        ElevatedButton(
                          onPressed: isLoginRequired ? _openLoginPage : _loadBonuses,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: _orange,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: Text(isLoginRequired ? 'Войти' : 'Обновить'),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Ваш баланс', style: TextStyle(color: _textMute, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  Text(
                                    totalBonuses != null ? totalBonuses.toStringAsFixed(0) : '—',
                                    style: const TextStyle(color: _text, fontSize: 32, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => BonusHistoryPage(history: history),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _orange,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              child: const Text('История'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (cardUuid != null && _qrPayload != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _cardDark,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            child: Column(
                              children: [
                                BarcodeWidget(
                                  data: _qrPayload!,
                                  barcode: Barcode.qrCode(),
                                  color: _text,
                                  width: double.infinity,
                                  height: 200,
                                  backgroundColor: Colors.transparent,
                                ),
                                const SizedBox(height: 10),
                                Text('QR обновляется каждую минуту', style: TextStyle(color: _textMute.withValues(alpha: 0.9))),
                              ],
                            ),
                          )
                        else
                          const Text('Карта не найдена', style: TextStyle(color: _textMute)),
                      ],
                    ),
        ),
      ],
    );
  }

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
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  floating: true,
                  snap: true,
                  pinned: false,
                  automaticallyImplyLeading: false,
                  toolbarHeight: 72,
                  title: _buildHeader(),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  floating: false,
                  delegate: _SlimHeaderDelegate(
                    minExtent: 92,
                    maxExtent: 96,
                    child: _slimAddressBar(),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        if (widget.selectedCity != null && widget.businesses.isEmpty) ...[
                          _emptyCityBanner(),
                          const SizedBox(height: 12),
                        ],
                        _searchBar(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(child: _promotionsSection()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(child: _categoriesSection()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(child: _productDiscoveryRow()),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, bottomPadding),
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

  Widget _floatingActiveOrdersButton() {
    final total = _activeOrders.length;
    final bottomOffset = MediaQuery.of(context).padding.bottom + 122;

    return Positioned(
      right: 16,
      bottom: bottomOffset,
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomRight,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OrdersHistoryPage(initialActiveOrders: _activeOrders),
                  ),
                );
                _loadActiveOrders();
              },
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _orange,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: Colors.black, size: 18),
                    const SizedBox(width: 8),
                    Container(
                      constraints: const BoxConstraints(minWidth: 24),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(999),
                      ),
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
      ),
    );
  }

  Future<void> _showBusinessSelectorSheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: _card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      builder: (ctx) {
        if (widget.businesses.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.store_mall_directory, color: _textMute, size: 28),
                SizedBox(height: 10),
                Text('Магазины не найдены', style: TextStyle(color: _text)),
              ],
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.selectedCity == null ? 'Выберите магазин' : 'Магазины: ${widget.selectedCity}',
                  style: const TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: widget.businesses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final b = widget.businesses[i];
                      final name = b['name'] ?? b['title'] ?? 'Магазин';
                      final addr = b['address'] ?? b['subtitle'] ?? '';
                      return ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        tileColor: _cardDark,
                        leading: const Icon(Icons.storefront, color: _orange),
                        title: Text(name, style: const TextStyle(color: _text, fontWeight: FontWeight.w800)),
                        subtitle: addr.isNotEmpty ? Text(addr.toString(), style: TextStyle(color: _textMute.withValues(alpha: 0.9))) : null,
                        onTap: () => Navigator.pop(ctx, b),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != null && mounted) {
      widget.onBusinessSelected(result);
    }
  }

  Future<void> _showCitySelectorSheet() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Выберите город', style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text(
                  'От выбранного города зависят адресный поиск и доступные магазины.',
                  style: TextStyle(color: _textMute),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: widget.availableCities.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final city = widget.availableCities[i];
                      final isSelected = city == widget.selectedCity;
                      return ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        tileColor: isSelected ? _orange.withValues(alpha: 0.14) : _cardDark,
                        leading: Icon(isSelected ? Icons.check_circle : Icons.location_city_rounded, color: isSelected ? _orange : _textMute),
                        title: Text(city, style: const TextStyle(color: _text, fontWeight: FontWeight.w800)),
                        subtitle: Text(
                          isSelected ? 'Выбранный' : '',
                          style: TextStyle(color: _textMute.withValues(alpha: 0.92)),
                        ),
                        onTap: () => Navigator.pop(ctx, city),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != null && mounted && result != widget.selectedCity) {
      widget.onCityChanged(result);
    }
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

  @override
  void dispose() {
    _addressSubscription?.cancel();
    _stopQrUpdates();
    super.dispose();
  }
}

class _SlimHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minExtent;
  final double maxExtent;
  final Widget child;

  _SlimHeaderDelegate({required this.minExtent, required this.maxExtent, required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0x00000000),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _SlimHeaderDelegate oldDelegate) {
    return oldDelegate.minExtent != minExtent || oldDelegate.maxExtent != maxExtent || oldDelegate.child != child;
  }
}
