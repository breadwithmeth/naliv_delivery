import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:naliv_delivery/services/notification_service.dart';
import 'package:naliv_delivery/services/onboarding_service.dart';
import 'package:naliv_delivery/services/telemetry_consent_service.dart';
import 'package:naliv_delivery/utils/location_service.dart';
import '../utils/api.dart';
import '../utils/responsive.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onCompleted, this.initialCity});

  final VoidCallback onCompleted;
  final String? initialCity;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const Color _bgDeep = Color(0xFF121212);
  static const Color _bgTop = Color(0xFF161616);
  static const Color _card = Color(0xFF1E1E1E);
  static const Color _cardDark = Color(0xFF181818);
  static const Color _blue = Color(0xFF242A32);
  static const Color _orange = Color(0xFFF6A10C);
  static const Color _red = Color(0xFFC23B30);
  static const Color _teal = Color(0xFF2AD1C9);
  static const Color _text = Colors.white;
  static const Color _textMute = Color(0xFF9FB0C8);

  final PageController _pageController = PageController();
  final LocationService _locationService = LocationService.instance;

  int _pageIndex = 0;
  int get _totalSteps => 2;
  List<_CityOption> _cities = const <_CityOption>[];
  String? _selectedCity;
  String? _guessedCity;
  bool _isLoadingCities = true;
  String? _citiesError;
  bool _isDeterminingCity = false;
  bool _isRequestingLocation = false;
  bool _isRequestingNotifications = false;
  bool _locationGranted = false;
  bool _notificationsGranted = false;
  String? _locationMessage;
  String? _notificationMessage;
  bool _shareDiagnostics = true;

  @override
  void initState() {
    super.initState();
    _selectedCity = widget.initialCity;
    _loadCities();
    _setupDiagnosticsToggle();
  }

  void _setupDiagnosticsToggle() {
    final hasStored = TelemetryConsentService.hasStoredConsent;
    final cached = TelemetryConsentService.cachedConsent;
    setState(() {
      _shareDiagnostics = hasStored ? cached : true; // Pre-check for first-time users
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goToPage(int index) async {
    if (index >= _totalSteps) return;
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    setState(() => _pageIndex = index);
  }

  Future<void> _loadCities() async {
    setState(() {
      _isLoadingCities = true;
      _citiesError = null;
    });

    try {
      final cities = await OnboardingService.fetchAvailableCities(forceRefresh: false);
      if (!mounted) return;

      setState(() {
        _cities = cities.map(_mapCityOption).toList();
        _isLoadingCities = false;
        if (_cities.isEmpty) {
          _citiesError = 'Не удалось загрузить список городов.';
        }
      });

      await _autoResolveCity();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingCities = false;
        _citiesError = 'Не удалось загрузить список городов.';
      });
    }
  }

  bool _isCityAvailable(String city) {
    return _cities.any((c) => c.name.toLowerCase() == city.toLowerCase());
  }

  Future<bool> _autoResolveCity() async {
    if (_cities.isEmpty) {
      final cached = OnboardingService.cachedCities.map(_mapCityOption).toList();
      if (cached.isNotEmpty) {
        setState(() => _cities = cached);
      } else {
        final fetched = await OnboardingService.fetchAvailableCities(forceRefresh: false);
        if (fetched.isNotEmpty) {
          setState(() => _cities = fetched.map(_mapCityOption).toList());
        }
      }
    }

    if (_selectedCity != null && _isCityAvailable(_selectedCity!)) {
      return true;
    }

    if (_guessedCity != null && _isCityAvailable(_guessedCity!)) {
      setState(() => _selectedCity = _guessedCity);
      await OnboardingService.setSelectedCity(_guessedCity!);
      return true;
    }

    final guess = await OnboardingService.guessCityByIp();
    if (guess != null && _isCityAvailable(guess)) {
      setState(() {
        _guessedCity = guess;
        _selectedCity = guess;
      });
      await OnboardingService.setSelectedCity(guess);
      return true;
    }

    return false;
  }

  _CityOption _mapCityOption(OnboardingCity city) {
    switch (city.name) {
      case 'Павлодар':
        return const _CityOption(name: 'Павлодар', subtitle: 'Северо-восточный маршрут', icon: Icons.location_city_rounded);
      case 'Караганда':
        return const _CityOption(name: 'Караганда', subtitle: 'Доставка по району и центру', icon: Icons.apartment_rounded);
      case 'Темиртау':
        return const _CityOption(name: 'Темиртау', subtitle: 'Быстрый старт для частых заказов', icon: Icons.factory_rounded);
      case 'Астана':
        return const _CityOption(name: 'Астана', subtitle: 'Столица и ближайшие адреса', icon: Icons.location_on_rounded);
      default:
        return _CityOption(
          name: city.name,
          subtitle: city.deliveryType == 'DISTANCE' ? 'Доставка по расстоянию' : 'Доставка по зоне покрытия',
          icon: Icons.location_city_rounded,
        );
    }
  }

  Future<void> _selectCity(String city) async {
    setState(() {
      _selectedCity = city;
      _guessedCity ??= city;
    });
    await OnboardingService.setSelectedCity(city);
  }

  Future<void> _showCityChooser() async {
    final selectedCity = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.s)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              padding: EdgeInsets.fromLTRB(16.s, 12.s, 16.s, 24.s),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 46,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Text(
                      'Выберите город',
                      style: TextStyle(color: _text, fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Не получилось определить автоматически. Выберите вручную.',
                      style: TextStyle(color: _textMute, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    if (_guessedCity != null)
                      Container(
                        margin: EdgeInsets.only(bottom: 12.s),
                        padding: EdgeInsets.all(14.s),
                        decoration: BoxDecoration(
                          color: _cardDark,
                          borderRadius: BorderRadius.circular(16.s),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14)),
                              child: const Icon(Icons.location_searching_rounded, color: _orange),
                            ),
                            SizedBox(width: 12.s),
                            Expanded(
                              child: Text(
                                'Похоже, вы в городе $_guessedCity. Подтвердите, чтобы не искать в списке.',
                                style: const TextStyle(color: _text, height: 1.35, fontWeight: FontWeight.w700),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(_guessedCity),
                              child: const Text('Выбрать'),
                            ),
                          ],
                        ),
                      ),
                    _buildCityGrid(closeOnSelect: true),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || selectedCity == null || selectedCity.isEmpty) return;
    await _selectCity(selectedCity);
  }

  Future<void> _requestNotificationPermission() async {
    if (_isRequestingNotifications) return;
    setState(() {
      _isRequestingNotifications = true;
      _notificationMessage = null;
    });

    final granted = await NotificationService.instance.enablePushNotifications();
    await OnboardingService.markNotificationPromptSeen();
    await TelemetryConsentService.setConsent(_shareDiagnostics);

    if (!mounted) return;
    setState(() {
      _isRequestingNotifications = false;
      _notificationsGranted = granted;
      _notificationMessage = granted
          ? 'Уведомления включены. Вы будете получать статус заказа и акции.'
          : 'Разрешение не получено. Его можно включить позже в настройках устройства.';
    });

    if (granted) {
      await _goToPage(1);
    }
  }

  Future<void> _handleLocationFlow() async {
    if (_isRequestingLocation || _isDeterminingCity) return;
    setState(() {
      _isRequestingLocation = true;
      _locationMessage = null;
    });

    final result = await _locationService.checkAndRequestPermissions();
    await OnboardingService.markLocationPromptSeen();

    if (!mounted) return;
    setState(() {
      _isRequestingLocation = false;
      _locationGranted = result.success;
      _locationMessage = result.message;
    });

    if (!result.success) return;

    await _startDeterminingCity();
  }

  Future<void> _startDeterminingCity() async {
    if (_isDeterminingCity) return;
    setState(() => _isDeterminingCity = true);

    try {
      final position = await _locationService.getCurrentPosition(
        accuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 2),
      );

      var autoResolved = await _autoResolveCity();

      if (!autoResolved && position != null) {
        final reverse = await ApiService.searchAddresses(
          lat: position.latitude,
          lon: position.longitude,
          city: _selectedCity,
        );

        final resolvedCity = reverse != null && reverse.isNotEmpty ? ApiService.extractCityName(reverse.first) : null;

        final canUseResolved = resolvedCity != null && (_isCityAvailable(resolvedCity) || _cities.isEmpty);

        if (canUseResolved) {
          setState(() {
            _selectedCity = resolvedCity;
            _guessedCity = resolvedCity;
          });
          await OnboardingService.setSelectedCity(resolvedCity);
          autoResolved = true;
        }
      }

      if (!mounted) return;

      if (_selectedCity == null && !autoResolved) {
        await _showCityChooser();
        if (_selectedCity == null) return;
      }

      await _finishOnboarding();
    } finally {
      if (mounted) {
        setState(() => _isDeterminingCity = false);
      }
    }
  }

  Future<void> _continueWithoutLocation() async {
    await OnboardingService.markLocationPromptSeen();

    if (_selectedCity == null) {
      await _autoResolveCity();
    }

    if (_selectedCity == null) {
      await _showCityChooser();
      if (_selectedCity == null) return;
    }

    await _finishOnboarding();
  }

  Future<void> _finishOnboarding() async {
    final city = _selectedCity;
    if (city == null) return;
    await TelemetryConsentService.setConsent(_shareDiagnostics);
    await OnboardingService.complete(city: city);
    widget.onCompleted();
  }

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
                    center: const Alignment(-0.45, -0.72),
                    radius: 1.18,
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
                    center: const Alignment(0.72, 0.9),
                    radius: 1.36,
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

  Widget _buildTopBar() {
    return Row(
      children: [
        const Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'ГРАДУСЫ',
              style: TextStyle(color: _text, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.s, vertical: 7.s),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Text(
            '${_pageIndex + 1}/$_totalSteps',
            style: const TextStyle(color: _textMute, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildProgress() {
    return Row(
      children: List.generate(
        _totalSteps,
        (index) => Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            margin: EdgeInsets.only(right: index == _totalSteps - 1 ? 0 : 7.s),
            height: 4.s,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: index <= _pageIndex ? _orange : Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShell({
    required String eyebrow,
    required String title,
    required String description,
    required Widget body,
    required List<Widget> actions,
    required IconData icon,
    required List<Color> artGradient,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompactWidth = constraints.maxWidth < 380;
        final isCompactHeight = constraints.maxHeight < 720;
        final isTinyHeight = constraints.maxHeight < 640;
        final maxContentWidth = constraints.maxWidth > 680 ? 560.0 : constraints.maxWidth;
        final topSpacing = isTinyHeight ? 8.0 : 16.0;
        final cardPadding = isTinyHeight ? 18.0 : (isCompactHeight ? 20.0 : 24.0);
        final cardRadius = isTinyHeight ? 24.0 : 28.0;
        final iconBoxSize = isTinyHeight ? 60.0 : 72.0;
        final iconRadius = isTinyHeight ? 18.0 : 22.0;
        final iconSize = isTinyHeight ? 30.0 : 34.0;
        final titleSize = isTinyHeight ? 25.0 : (isCompactHeight ? 27.0 : 30.0);
        final descriptionSize = isCompactWidth ? 14.0 : 15.0;
        final sectionGap = isTinyHeight ? 18.0 : 24.0;
        final actionsGap = isTinyHeight ? 16.0 : 24.0;
        final showHeroIcon = !(isTinyHeight && isCompactWidth);

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.only(top: topSpacing),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(cardPadding),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(cardRadius),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 16, offset: const Offset(0, 12))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showHeroIcon) ...[
                            Container(
                              width: iconBoxSize,
                              height: iconBoxSize,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: artGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                                borderRadius: BorderRadius.circular(iconRadius),
                              ),
                              child: Icon(icon, color: Colors.white, size: iconSize),
                            ),
                            SizedBox(height: sectionGap),
                          ],
                          Text(
                            eyebrow,
                            style: TextStyle(color: _orange.withValues(alpha: 0.95), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            style: TextStyle(color: _text, fontSize: titleSize, fontWeight: FontWeight.w900, height: 1.02),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            description,
                            style: TextStyle(
                                color: _textMute.withValues(alpha: 0.96), fontSize: descriptionSize, height: 1.45, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: sectionGap),
                          body,
                        ],
                      ),
                    ),
                    SizedBox(height: actionsGap),
                    ...actions,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCityGrid({bool closeOnSelect = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_isLoadingCities && _cities.isEmpty) {
          return _buildCityGridSkeleton(constraints.maxWidth);
        }

        if (_cities.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _cardDark,
              borderRadius: BorderRadius.circular(20.s),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _citiesError ?? 'Список городов пока пуст.',
                  style: const TextStyle(color: _text, height: 1.4, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isLoadingCities ? null : _loadCities,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _text,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.s)),
                    ),
                    child: Text(_isLoadingCities ? 'Загружаем...' : 'Повторить'),
                  ),
                ),
              ],
            ),
          );
        }

        final isSingleColumn = constraints.maxWidth < 380;
        final tileHeight = isSingleColumn ? 136.0 : (constraints.maxWidth < 460 ? 152.0 : 164.0);
        final iconSize = isSingleColumn ? 26.0 : 28.0;
        final titleSize = isSingleColumn ? 17.0 : 18.0;

        return GridView.builder(
          shrinkWrap: true,
          itemCount: _cities.length,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isSingleColumn ? 1 : 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: tileHeight,
          ),
          itemBuilder: (context, index) {
            final city = _cities[index];
            final isSelected = _selectedCity == city.name;
            return InkWell(
              borderRadius: BorderRadius.circular(20.s),
              onTap: () {
                if (closeOnSelect) {
                  Navigator.of(context).pop(city.name);
                  return;
                }

                setState(() => _selectedCity = city.name);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: EdgeInsets.all(14.s),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isSelected ? const [_orange, _red] : const [_blue, _cardDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20.s),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(city.icon, color: Colors.white, size: iconSize),
                    const Spacer(),
                    Text(
                      city.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _text, fontSize: titleSize, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      city.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 12, height: 1.35, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCityGridSkeleton(double maxWidth) {
    final isSingleColumn = maxWidth < 380;
    final tileHeight = isSingleColumn ? 136.0 : (maxWidth < 460 ? 152.0 : 164.0);
    final cardCount = isSingleColumn ? 3 : 4;

    return GridView.builder(
      shrinkWrap: true,
      itemCount: cardCount,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isSingleColumn ? 1 : 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: tileHeight,
      ),
      itemBuilder: (_, __) {
        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_blue, _cardDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Spacer(),
              Container(
                width: 96,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: isSingleColumn ? maxWidth * 0.45 : 90,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBenefitWrap(List<_BenefitItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSingleColumn = constraints.maxWidth < 360;
        final itemWidth = isSingleColumn ? constraints.maxWidth : (constraints.maxWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: _BenefitPill(icon: item.icon, label: item.label),
              ),
          ],
        );
      },
    );
  }

  Widget _buildLocationStatusCard() {
    if (_locationMessage == null) {
      return Container(
        padding: EdgeInsets.all(14.s),
        decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(18.s),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 36.s,
              height: 36.s,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12.s)),
              child: const Icon(Icons.place_outlined, color: _orange),
            ),
            SizedBox(width: 10.s),
            const Expanded(
              child: Text(
                'Найдём ваш город и ближайший магазин. Точный адрес можно будет указать позже, при оформлении заказа.',
                style: TextStyle(color: _textMute, height: 1.4, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(14.s),
      decoration: BoxDecoration(
        color: _locationGranted ? _orange.withValues(alpha: 0.12) : _cardDark,
        borderRadius: BorderRadius.circular(18.s),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_locationGranted ? Icons.check_circle_rounded : Icons.info_outline_rounded, color: _locationGranted ? _orange : _textMute),
          const SizedBox(width: 12),
          Expanded(child: Text(_locationMessage!, style: const TextStyle(color: _text, height: 1.45, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildLocationStep() {
    return _buildShell(
      eyebrow: 'ШАГ 2',
      title: 'Разрешите геолокацию',
      description: 'Поможем быстрее определить ваш город. Точный адрес добавите уже при оформлении заказа.',
      icon: Icons.near_me_rounded,
      artGradient: const [_blue, _teal],
      body: Column(
        children: [
          _buildLocationStatusCard(),
          const SizedBox(height: 16),
          _buildBenefitWrap(const [
            _BenefitItem(icon: Icons.storefront_rounded, label: 'Ближайший магазин'),
            _BenefitItem(icon: Icons.pin_drop_outlined, label: 'Точный адрес позже'),
          ]),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_isRequestingLocation || _isDeterminingCity) ? null : _handleLocationFlow,
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange,
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(vertical: 16.s),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.s)),
              textStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp),
            ),
            child: (_isRequestingLocation || _isDeterminingCity)
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black))
                : const Text('Разрешить геолокацию'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isDeterminingCity ? null : _continueWithoutLocation,
            style: OutlinedButton.styleFrom(
              foregroundColor: _text,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              padding: EdgeInsets.symmetric(vertical: 14.s),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.s)),
            ),
            child: const Text('Выбрать город вручную'),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: _isDeterminingCity ? null : _continueWithoutLocation,
            style: TextButton.styleFrom(foregroundColor: _textMute),
            child: const Text('Пока без геолокации'),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationStatusCard() {
    if (_notificationMessage == null) {
      return Container(
        padding: EdgeInsets.all(14.s),
        decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(18.s),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: const Row(
          children: [
            Icon(Icons.notifications_active_outlined, color: _orange),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Найдём ваш город и ближайший магазин. Точный адрес можно будет указать позже, при оформлении заказа.',
                style: TextStyle(color: _textMute, height: 1.35, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(14.s),
      decoration: BoxDecoration(
        color: _notificationsGranted ? _orange.withValues(alpha: 0.12) : _cardDark,
        borderRadius: BorderRadius.circular(18.s),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_notificationsGranted ? Icons.check_circle_rounded : Icons.info_outline_rounded, color: _notificationsGranted ? _orange : _textMute),
          const SizedBox(width: 12),
          Expanded(child: Text(_notificationMessage!, style: const TextStyle(color: _text, height: 1.45, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildNotificationStep() {
    return _buildShell(
      eyebrow: 'ШАГ 1',
      title: 'Включите уведомления',
      description: 'Статусы заказа и персональные акции вовремя.',
      icon: Icons.notifications_active_rounded,
      artGradient: const [_red, _teal],
      body: Column(
        children: [
          _buildNotificationStatusCard(),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 4.s, bottom: 6.s),
              child: Text(
                'Прозрачность',
                style: TextStyle(color: _teal.withValues(alpha: 0.85), fontWeight: FontWeight.w800, letterSpacing: 0.2),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(bottom: 12.s),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_blue, _cardDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16.s),
              border: Border.all(color: _teal.withValues(alpha: 0.25)),
            ),
            child: CheckboxListTile(
              value: _shareDiagnostics,
              onChanged: (value) async {
                if (value == null) return;
                setState(() => _shareDiagnostics = value);
                await TelemetryConsentService.setConsent(value);
              },
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: _orange,
              checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              contentPadding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 6.s),
              title: const Text('Помочь улучшить приложение', style: TextStyle(color: _text, fontWeight: FontWeight.w800)),
              subtitle: const Text(
                'Анонимные отчёты об ошибках. Можно отключить в настройках.',
                style: TextStyle(color: _textMute, height: 1.3, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          _buildBenefitWrap(const [
            _BenefitItem(icon: Icons.local_offer_rounded, label: 'Новые акции'),
            _BenefitItem(icon: Icons.receipt_long_rounded, label: 'Статус заказа'),
          ]),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isRequestingNotifications ? null : (_notificationsGranted ? () => _goToPage(1) : _requestNotificationPermission),
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange,
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(vertical: 16.s),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.s)),
              textStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp),
            ),
            child: _isRequestingNotifications
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black))
                : Text(_notificationsGranted ? 'Далее' : 'Разрешить уведомления'),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => _goToPage(1),
            style: TextButton.styleFrom(foregroundColor: _textMute),
            child: const Text('Включить позже'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDeep,
      body: Stack(
        children: [
          _background(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding = constraints.maxWidth < 360 ? 16.0 : 20.0;
                final topPadding = constraints.maxHeight < 700 ? 14.0 : 18.0;
                final bottomPadding = constraints.maxHeight < 700 ? 16.0 : 20.0;
                final topSectionGap = constraints.maxHeight < 700 ? 12.0 : 16.0;
                final progressGap = constraints.maxHeight < 700 ? 10.0 : 14.0;
                final maxFrameWidth = constraints.maxWidth > 760 ? 640.0 : constraints.maxWidth;

                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxFrameWidth),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(horizontalPadding, topPadding, horizontalPadding, bottomPadding),
                      child: Column(
                        children: [
                          _buildTopBar(),
                          SizedBox(height: topSectionGap),
                          _buildProgress(),
                          SizedBox(height: progressGap),
                          Expanded(
                            child: PageView(
                              controller: _pageController,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                _buildNotificationStep(),
                                _buildLocationStep(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitPill extends StatelessWidget {
  const _BenefitPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 12.s),
      decoration: BoxDecoration(
        color: _OnboardingPageState._cardDark,
        borderRadius: BorderRadius.circular(16.s),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _OnboardingPageState._orange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: _OnboardingPageState._text, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitItem {
  const _BenefitItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _CityOption {
  const _CityOption({required this.name, required this.subtitle, required this.icon});

  final String name;
  final String subtitle;
  final IconData icon;
}
