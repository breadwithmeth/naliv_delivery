import 'package:flutter/material.dart';
import 'package:naliv_delivery/services/notification_service.dart';
import 'package:naliv_delivery/services/onboarding_service.dart';
import 'package:naliv_delivery/services/telemetry_consent_service.dart';
import 'package:naliv_delivery/utils/location_service.dart';
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
  static const Color _text = Colors.white;
  static const Color _textMute = Color(0xFF9FB0C8);

  final PageController _pageController = PageController();
  final LocationService _locationService = LocationService.instance;

  int _pageIndex = 0;
  List<_CityOption> _cities = const <_CityOption>[];
  String? _selectedCity;
  String? _guessedCity;
  bool _isLoadingCities = true;
  String? _citiesError;
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
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    setState(() => _pageIndex = index);
  }

  Future<void> _loadCities() async {
    final cachedCities = OnboardingService.cachedCities.map(_mapCityOption).toList();
    if (mounted && cachedCities.isNotEmpty) {
      setState(() {
        _cities = cachedCities;
        _citiesError = null;
        if (_selectedCity != null && !_cities.any((city) => city.name == _selectedCity)) {
          _selectedCity = null;
        }
      });
    }

    setState(() {
      _isLoadingCities = true;
      _citiesError = null;
    });

    final cities = await OnboardingService.fetchAvailableCities(forceRefresh: true);
    if (!mounted) return;

    final mappedCities = cities.map(_mapCityOption).toList();
    setState(() {
      _cities = mappedCities;
      _isLoadingCities = false;
      _citiesError = mappedCities.isEmpty ? 'Не удалось получить список городов.' : null;
      if (_selectedCity != null && !_cities.any((city) => city.name == _selectedCity)) {
        _selectedCity = null;
      }
    });

    if (_selectedCity == null) {
      _guessCityFromIp();
    }
  }

  Future<void> _guessCityFromIp() async {
    final guess = await OnboardingService.guessCityByIp();
    if (!mounted || guess == null) return;
    if (!_cities.any((c) => c.name.toLowerCase() == guess.toLowerCase())) return;
    setState(() {
      _guessedCity = guess;
      _selectedCity ??= guess;
    });
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

  Future<void> _continueFromCity() async {
    final city = _selectedCity;
    if (city == null) return;
    await OnboardingService.setSelectedCity(city);
    await _goToPage(1);
  }

  Future<void> _requestLocationPermission() async {
    if (_isRequestingLocation) return;
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

    if (result.success) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (mounted) {
        await _goToPage(2);
      }
    }
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
      await _finishOnboarding();
    }
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
            '${_pageIndex + 1}/3',
            style: const TextStyle(color: _textMute, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildProgress() {
    return Row(
      children: List.generate(
        3,
        (index) => Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            margin: EdgeInsets.only(right: index == 2 ? 0 : 7.s),
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

  Widget _buildCityGrid() {
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
              onTap: () => setState(() => _selectedCity = city.name),
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

  Widget _buildCityStep() {
    return _buildShell(
      eyebrow: 'ШАГ 1',
      title: 'Выберите ваш город',
      description: 'Это поможет сразу показать нужный сценарий доставки и ближайшие магазины.',
      icon: Icons.location_city_rounded,
      artGradient: const [_orange, _red],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                ],
              ),
            ),
          _buildCityGrid(),
        ],
      ),
      actions: [
        if (_guessedCity != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() => _selectedCity = _guessedCity);
                _continueFromCity();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(vertical: 14.s),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.s)),
                textStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp),
              ),
              child: Text('Да, я в городе $_guessedCity'),
            ),
          ),
        if (_guessedCity != null) SizedBox(height: 10.s),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _selectedCity == null ? null : _continueFromCity,
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange,
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(vertical: 16.s),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.s)),
              textStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp),
            ),
            child: const Text('Продолжить'),
          ),
        ),
      ],
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
                'Дадим доступ только для поиска ближайшего магазина и ускорения выбора адреса.',
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
      description: 'Покажем ближайший магазин, быстрее заполним адрес и точнее рассчитаем доставку.',
      icon: Icons.near_me_rounded,
      artGradient: const [_blue, _orange],
      body: Column(
        children: [
          _buildLocationStatusCard(),
          const SizedBox(height: 16),
          _buildBenefitWrap(const [
            _BenefitItem(icon: Icons.storefront_rounded, label: 'Ближайший магазин'),
            _BenefitItem(icon: Icons.bolt_rounded, label: 'Быстрее адрес'),
          ]),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              await OnboardingService.markLocationPromptSeen();
              await _goToPage(2);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange,
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(vertical: 16.s),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.s)),
              textStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp),
            ),
            child: const Text('Продолжить без геолокации'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isRequestingLocation ? null : _requestLocationPermission,
            style: OutlinedButton.styleFrom(
              foregroundColor: _text,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              padding: EdgeInsets.symmetric(vertical: 14.s),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.s)),
            ),
            child: _isRequestingLocation
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                : const Text('Включить геолокацию сейчас'),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () async {
              await OnboardingService.markLocationPromptSeen();
              await _goToPage(2);
            },
            style: TextButton.styleFrom(foregroundColor: _textMute),
            child: const Text('Пока пропустить'),
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
                'Уведомления нужны для статусов заказа, новых акций и важных обновлений по доставке.',
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
      eyebrow: 'ШАГ 3',
      title: 'Включите уведомления',
      description: 'Так вы не пропустите статус заказа, новые акции и изменения по доставке.',
      icon: Icons.notifications_active_rounded,
      artGradient: const [_red, _orange],
      body: Column(
        children: [
          _buildNotificationStatusCard(),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(bottom: 12.s),
            decoration: BoxDecoration(
              color: _cardDark,
              borderRadius: BorderRadius.circular(16.s),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: SwitchListTile.adaptive(
              value: _shareDiagnostics,
              onChanged: (value) async {
                setState(() => _shareDiagnostics = value);
                await TelemetryConsentService.setConsent(value);
              },
              contentPadding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 4.s),
              activeColor: _orange,
              title: const Text('Помочь улучшить приложение', style: TextStyle(color: _text, fontWeight: FontWeight.w800)),
              subtitle: const Text(
                'Оставьте включённым, чтобы анонимно отправлять отчёты об ошибках и сбоях.',
                style: TextStyle(color: _textMute, height: 1.35, fontWeight: FontWeight.w600),
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
            onPressed: _isRequestingNotifications ? null : (_notificationsGranted ? _finishOnboarding : _requestNotificationPermission),
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange,
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(vertical: 16.s),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.s)),
              textStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp),
            ),
            child: _isRequestingNotifications
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black))
                : Text(_notificationsGranted ? 'Перейти в приложение' : 'Разрешить уведомления'),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: _finishOnboarding,
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
                              children: [_buildCityStep(), _buildLocationStep(), _buildNotificationStep()],
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
