import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../utils/address_storage_service.dart';
import '../utils/api.dart';
import '../utils/cart_provider.dart';
import '../utils/location_service.dart';
import '../widgets/address_selection_modal_material.dart';
import 'categoryPage.dart';
import 'promotion_items_page.dart';
import 'search_page.dart';

class MainPage extends StatefulWidget {
  final List<Map<String, dynamic>> businesses;
  final Map<String, dynamic>? selectedBusiness;
  final Map<String, dynamic>? selectedAddress;
  final Position? userPosition;
  final Function(Map<String, dynamic>) onBusinessSelected;
  final VoidCallback onAddressChangeRequested;
  final bool isLoadingBusinesses;

  const MainPage({
    super.key,
    required this.businesses,
    this.selectedBusiness,
    this.selectedAddress,
    this.userPosition,
    required this.onBusinessSelected,
    required this.onAddressChangeRequested,
    required this.isLoadingBusinesses,
  });

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  // Palette
  static const Color _bgDeep = Color(0xFF0B0D14);
  static const Color _bgTop = Color(0xFF0E1119);
  static const Color _card = Color(0xFF111A2D);
  static const Color _cardDark = Color(0xFF0F1726);
  static const Color _blue = Color(0xFF1C273A);
  static const Color _orange = Color(0xFFF38B2A);
  static const Color _red = Color(0xFFC22624);
  static const Color _text = Colors.white;
  static const Color _textMute = Color(0xFF9FB0C8);

  final PageController _promoPageController = PageController();
  Timer? _promoAutoScrollTimer;
  int _currentPromoPage = 0;
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

    if (widget.selectedBusiness != null) {
      _loadPromotions();
      _loadCategories();
    }
  }

  @override
  void didUpdateWidget(covariant MainPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedBusiness != widget.selectedBusiness) {
      _loadPromotions();
      _loadCategories();
    }
    if (oldWidget.selectedAddress != widget.selectedAddress && widget.selectedAddress != null) {
      setState(() => _selectedAddress = widget.selectedAddress);
      _autoSelectNearestBusiness();
    }
  }

  @override
  void dispose() {
    _promoAutoScrollTimer?.cancel();
    _promoPageController.dispose();
    _addressSubscription?.cancel();
    super.dispose();
  }

  // ---------------- Data loading ----------------
  Future<void> _loadPromotions() async {
    if (!mounted) return;
    setState(() {
      _isLoadingPromotions = true;
      _promotionsError = null;
    });
    try {
      final int? businessId = widget.selectedBusiness != null
          ? widget.selectedBusiness!['id'] ?? widget.selectedBusiness!['business_id'] ?? widget.selectedBusiness!['businessId']
          : null;
      final promos = await ApiService.getActivePromotionsTyped(businessId: businessId, limit: 12);
      if (!mounted) return;
      setState(() {
        _promotions = promos ?? [];
        _isLoadingPromotions = false;
      });
      _startPromoAutoScroll();
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

      final reverse = await ApiService.searchAddresses(lat: pos.latitude, lon: pos.longitude);
      final autoAddress = {
        'address': (reverse?.isNotEmpty ?? false)
            ? (reverse!.first['name'] ?? reverse.first['description'] ?? '*Определённый адрес')
            : '*Определённый адрес',
        'lat': pos.latitude,
        'lon': pos.longitude,
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('ГРАДУСЫ', style: TextStyle(color: _text, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(10)),
                  child: const Text('24', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
        const Spacer(),
        _circleBadge(icon: Icons.local_shipping, label: '24/7'),
        const SizedBox(width: 10),
        _circleBadge(icon: Icons.notifications_none_rounded),
      ],
    );
  }

  Widget _circleBadge({required IconData icon, String? label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration:
          BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
      child: Row(
        children: [
          Icon(icon, color: _orange, size: 18),
          if (label != null) ...[
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: _text, fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _addressCard() {
    final addressText = _selectedAddress != null ? _selectedAddress!['address'] ?? '*Укажите адрес доставки' : '*Укажите адрес доставки';
    return GestureDetector(
      onTap: _showAddressSelectionModal,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.location_pin, color: _orange, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('*Доставка по адресу', style: TextStyle(color: _textMute.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(addressText,
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _text, fontSize: 15, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: _textMute),
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
              child: Text('*Найти любимый напиток...', style: TextStyle(color: _textMute, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            Icon(Icons.tune, color: _textMute),
          ],
        ),
      ),
    );
  }

  Promotion _fakePromotion(String name) {
    final now = DateTime.now();
    final bizId = widget.selectedBusiness != null
        ? (widget.selectedBusiness!['id'] as int?) ??
            (widget.selectedBusiness!['business_id'] as int?) ??
            (widget.selectedBusiness!['businessId'] as int?)
        : 0;
    return Promotion(
      marketingPromotionId: name.hashCode & 0x7fffffff,
      name: name,
      startPromotionDate: now.subtract(const Duration(days: 1)),
      endPromotionDate: now.add(const Duration(days: 30)),
      businessId: bizId ?? 0,
      cover: null,
      visible: 1,
      isActive: true,
      business: null,
      details: const [],
      stories: const [],
      itemsCount: 0,
      daysLeft: 0,
    );
  }

  Widget _promotionsSection() {
    final hasData = _promotions.isNotEmpty;
    final items = hasData
        ? _promotions
        : [
            _fakePromotion('*Премиальные вина Италии'),
            _fakePromotion('*Коллекция виски'),
          ];

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

    return SizedBox(
      height: 230,
      child: PageView.builder(
        controller: _promoPageController,
        onPageChanged: (i) => setState(() => _currentPromoPage = i),
        itemCount: items.length,
        itemBuilder: (_, i) => _promotionCard(items[i], hasData),
      ),
    );
  }

  Widget _promotionCard(Promotion promo, bool hasData) {
    final bizId =
        widget.selectedBusiness != null ? (widget.selectedBusiness!['id'] as int?) ?? (widget.selectedBusiness!['businessId'] as int?) : null;
    return GestureDetector(
      onTap: hasData && bizId != null
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
        margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_red, _cardDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 12))],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.16,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.2, -0.4),
                      radius: 1.1,
                      colors: [Colors.white, Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(12)),
                    child: const Text('*Доставка за 30 мин', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                  const Spacer(),
                  Text(promo.name ?? '*Акция',
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _text, fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(hasData && promo.details.isNotEmpty ? promo.details.first.name : '*Скидка 20%',
                      style: TextStyle(color: _text.withValues(alpha: 0.9), fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('*Выбрать', style: TextStyle(color: _text.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
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

    final visible = (_categories.isNotEmpty ? _categories : _placeholderCategories()).take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Категории', style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: visible.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final cat = visible[i];
              final style = _getCategoryIconAndColor(cat['name'] ?? '');
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  final businessId =
                      widget.selectedBusiness?['id'] ?? widget.selectedBusiness?['business_id'] ?? widget.selectedBusiness?['businessId'];
                  if (businessId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сначала выберите магазин')));
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
                child: Column(
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _blue,
                        gradient: LinearGradient(
                            colors: (style['gradient'] as List<Color>?) ?? [_blue, _cardDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 6))],
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Icon(style['icon'], color: style['color'], size: 30),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 78,
                      child: Text(cat['name'] ?? '*Категория',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _text, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _popularSection() {
    final items = _promotions.isNotEmpty
        ? _promotions.take(6).toList()
        : [
            _fakePromotion('*Chianti Classico Riserva DOCG'),
            _fakePromotion('*Macallan 12 Years Double Cask'),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text('Популярное сейчас', style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w800)),
            Spacer(),
            Text('*Все', style: TextStyle(color: _orange, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 280,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _popularCard(items[i]),
          ),
        ),
      ],
    );
  }

  Widget _popularCard(Promotion promo) {
    return Container(
      width: 210,
      decoration: BoxDecoration(
        color: _blue,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 12))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_card, _cardDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(0),
                  ),
                  child: promo.cover != null ? Image.network(promo.cover!, fit: BoxFit.cover) : Container(color: _cardDark),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(12)),
                    child: const Text('-15%', style: TextStyle(color: _text, fontWeight: FontWeight.w800)),
                  ),
                ),
                const Positioned(
                  top: 10,
                  right: 10,
                  child: Icon(Icons.favorite_border, color: _text, size: 20),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('*ИТАЛИЯ • 0.75 л', style: TextStyle(color: _textMute.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(promo.name ?? '*Товар',
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('2 450₽', style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w900)),
                      const Spacer(),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle),
                        child: const Icon(Icons.add, color: Colors.black, size: 22),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

  List<Map<String, dynamic>> _placeholderCategories() {
    return [
      {'name': '*Пиво'},
      {'name': '*Вино'},
      {'name': '*Виски'},
      {'name': '*Игристое'},
      {'name': '*Крепкий алкоголь'},
      {'name': '*Снеки'},
      {'name': '*Безалкогольное'},
    ];
  }

  void _startPromoAutoScroll() {
    _promoAutoScrollTimer?.cancel();
    if (_promotions.length <= 1) return;
    _promoAutoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final next = (_currentPromoPage + 1) % _promotions.length;
      _promoPageController.animateToPage(next, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      _currentPromoPage = next;
      if (mounted) setState(() {});
    });
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
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 14),
                  _addressCard(),
                  const SizedBox(height: 14),
                  _searchBar(),
                  const SizedBox(height: 18),
                  _promotionsSection(),
                  const SizedBox(height: 18),
                  _categoriesSection(),
                  const SizedBox(height: 20),
                  _popularSection(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
