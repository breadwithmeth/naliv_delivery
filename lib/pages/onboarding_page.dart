import 'package:flutter/material.dart';
import 'package:naliv_delivery/services/notification_service.dart';
import 'package:naliv_delivery/services/onboarding_service.dart';
import 'package:naliv_delivery/utils/location_service.dart';

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

  static const List<_CityOption> _cities = [
    _CityOption(name: 'Павлодар', subtitle: 'Северо-восточный маршрут', icon: Icons.location_city_rounded),
    _CityOption(name: 'Караганда', subtitle: 'Доставка по району и центру', icon: Icons.apartment_rounded),
    _CityOption(name: 'Темиртау', subtitle: 'Быстрый старт для частых заказов', icon: Icons.factory_rounded),
    _CityOption(name: 'Астана', subtitle: 'Столица и ближайшие адреса', icon: Icons.location_on_rounded),
  ];

  final PageController _pageController = PageController();
  final LocationService _locationService = LocationService.instance;

  int _pageIndex = 0;
  String? _selectedCity;
  bool _isRequestingLocation = false;
  bool _isRequestingNotifications = false;
  bool _locationGranted = false;
  bool _notificationsGranted = false;
  String? _locationMessage;
  String? _notificationMessage;

  @override
  void initState() {
    super.initState();
    _selectedCity = widget.initialCity;
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

  Future<void> _openLocationSettings() async {
    final serviceEnabled = await _locationService.isLocationServiceEnabled();
    if (serviceEnabled) {
      await _locationService.openAppSettings();
      return;
    }
    await _locationService.openLocationSettings();
  }

  Future<void> _requestNotificationPermission() async {
    if (_isRequestingNotifications) return;
    setState(() {
      _isRequestingNotifications = true;
      _notificationMessage = null;
    });

    final granted = await NotificationService.instance.enablePushNotifications();
    await OnboardingService.markNotificationPromptSeen();

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
        const Text(
          'ГРАДУСЫ',
          style: TextStyle(color: _text, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            margin: EdgeInsets.only(right: index == 2 ? 0 : 8),
            height: 4,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 16, offset: const Offset(0, 12))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: artGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(icon, color: Colors.white, size: 34),
              ),
              const SizedBox(height: 24),
              Text(
                eyebrow,
                style: TextStyle(color: _orange.withValues(alpha: 0.95), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(color: _text, fontSize: 30, fontWeight: FontWeight.w900, height: 1.02),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: TextStyle(color: _textMute.withValues(alpha: 0.96), fontSize: 15, height: 1.45, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              body,
            ],
          ),
        ),
        const Spacer(),
        ...actions,
      ],
    );
  }

  Widget _buildCityStep() {
    return _buildShell(
      eyebrow: 'ШАГ 1',
      title: 'Выберите ваш город',
      description: 'Это поможет сразу показать нужный сценарий доставки и ближайшие магазины.',
      icon: Icons.location_city_rounded,
      artGradient: const [_orange, _red],
      body: GridView.builder(
        shrinkWrap: true,
        itemCount: _cities.length,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.08,
        ),
        itemBuilder: (context, index) {
          final city = _cities[index];
          final isSelected = _selectedCity == city.name;
          return InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => setState(() => _selectedCity = city.name),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isSelected ? const [_orange, _red] : const [_blue, _cardDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: isSelected ? 0.18 : 0.06)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 10))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(city.icon, color: Colors.white, size: 28),
                  const Spacer(),
                  Text(city.name, style: const TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    city.subtitle,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 12, height: 1.35, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _selectedCity == null ? null : _continueFromCity,
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.place_outlined, color: _orange),
            ),
            const SizedBox(width: 12),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _locationGranted ? _orange.withValues(alpha: 0.12) : _cardDark,
        borderRadius: BorderRadius.circular(20),
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
          Row(
            children: const [
              Expanded(child: _BenefitPill(icon: Icons.storefront_rounded, label: 'Ближайший магазин')),
              SizedBox(width: 10),
              Expanded(child: _BenefitPill(icon: Icons.bolt_rounded, label: 'Быстрее адрес')),
            ],
          ),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isRequestingLocation ? null : (_locationGranted ? () => _goToPage(2) : _requestLocationPermission),
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            child: _isRequestingLocation
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black))
                : Text(_locationGranted ? 'Продолжить' : 'Разрешить доступ'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _locationGranted ? null : _openLocationSettings,
            style: OutlinedButton.styleFrom(
              foregroundColor: _text,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: const Text('Открыть настройки'),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => _goToPage(2),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: const Row(
          children: [
            Icon(Icons.notifications_active_outlined, color: _orange),
            SizedBox(width: 12),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _notificationsGranted ? _orange.withValues(alpha: 0.12) : _cardDark,
        borderRadius: BorderRadius.circular(20),
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
          Row(
            children: const [
              Expanded(child: _BenefitPill(icon: Icons.local_offer_rounded, label: 'Новые акции')),
              SizedBox(width: 10),
              Expanded(child: _BenefitPill(icon: Icons.receipt_long_rounded, label: 'Статус заказа')),
            ],
          ),
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
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                children: [
                  _buildTopBar(),
                  const SizedBox(height: 16),
                  _buildProgress(),
                  const SizedBox(height: 14),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildCityStep(),
                        _buildLocationStep(),
                        _buildNotificationStep(),
                      ],
                    ),
                  ),
                ],
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _OnboardingPageState._cardDark,
        borderRadius: BorderRadius.circular(18),
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

class _CityOption {
  const _CityOption({required this.name, required this.subtitle, required this.icon});

  final String name;
  final String subtitle;
  final IconData icon;
}
