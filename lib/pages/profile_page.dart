import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/login_page.dart';
import 'package:naliv_delivery/pages/orders_history_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/telemetry_consent_service.dart';
import '../utils/api.dart';
import '../utils/responsive.dart';
import 'profile_addresses_page.dart';
import 'profile_cards_page.dart';
import '../widgets/authentication_wrapper.dart';

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic> userInfo;

  const ProfilePage({required this.userInfo, super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  // ─── Palette (mirrors mainPage) ──────────────────────────
  static const Color _bgDeep = Color(0xFF121212);
  static const Color _bgTop = Color(0xFF161616);
  static const Color _card = Color(0xFF1E1E1E);
  static const Color _cardDark = Color(0xFF181818);
  static const Color _blue = Color(0xFF242A32);
  static const Color _orange = Color(0xFFF6A10C);
  static const Color _red = Color(0xFFC23B30);
  static const Color _text = Colors.white;
  static const Color _textMute = Color(0xFF9FB0C8);
  static const String _hiddenAddressesKey = 'profile_hidden_addresses';

  late final Future<Map<String, dynamic>?> _profileFuture;
  bool _telemetryAllowed = false;
  Set<String> _hiddenAddressIds = <String>{};
  late final AnimationController _staggerCtrl;
  bool _dataReady = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = ApiService.getFullInfo();
    _checkAuth();
    _loadTelemetryConsent();
    _loadHiddenAddresses();
    _staggerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHiddenAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList(_hiddenAddressesKey) ?? <String>[]).toSet();
    if (!mounted) return;
    setState(() => _hiddenAddressIds = ids);
  }

  String _addressId(Map<String, dynamic> addr) {
    return addr['id']?.toString() ??
        addr['address_id']?.toString() ??
        addr['uuid']?.toString() ??
        addr['address']?.toString() ??
        '${addr['lat']}_${addr['lon']}_${addr['address']}';
  }

  Future<void> _loadTelemetryConsent() async {
    final allowed = await TelemetryConsentService.loadConsent();
    if (!mounted) return;
    setState(() {
      _telemetryAllowed = allowed;
    });
  }

  Future<void> _checkAuth() async {
    final isLoggedIn = await ApiService.isUserLoggedIn();
    if (!mounted) return;
    if (!isLoggedIn) return;
    final data = await _profileFuture;
    if (!mounted) return;
    if (data == null) return;
  }

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

  // ─── Card decoration (matches mainPage) ──────────────────
  BoxDecoration _cardBox({double radius = 18, Color? color, bool accent = false}) {
    return BoxDecoration(
      color: color ?? _card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: accent ? _orange.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.05)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 16, offset: const Offset(0, 10))],
    );
  }

  BoxDecoration _pillBox({Color? color}) {
    return BoxDecoration(
      color: color ?? _blue,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
    );
  }

  Widget _staggered(int index, int total, Widget child) {
    final begin = (index / total).clamp(0.0, 1.0);
    final end = ((index + 1) / total).clamp(0.0, 1.0);
    final interval = Interval(begin, end, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: _staggerCtrl,
      builder: (context, child) {
        final t = interval.transform(_staggerCtrl.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  B U I L D
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: _text,
        title: const Text('Профиль', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Stack(
        children: [
          _background(),
          FutureBuilder<Map<String, dynamic>?>(
            future: _profileFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: _orange));
              }
              if (snapshot.hasError || snapshot.data == null) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage(redirectTabIndex: 4)));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orange,
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 10.s),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.s)),
                    ),
                    child: const Text('Войти', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                );
              }
              final data = snapshot.data!;
              final user = data['user'] as Map<String, dynamic>;
              final addresses = (data['addresses'] as List<dynamic>).cast<Map<String, dynamic>>();
              final cards = (data['cards'] as List<dynamic>).cast<Map<String, dynamic>>();

              TelemetryConsentService.applyUserContext(
                id: (user['id'] ?? user['user_id'])?.toString(),
                username: user['login'] as String?,
                email: user['email'] as String?,
              );

              if (!_dataReady) {
                _dataReady = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _staggerCtrl.forward();
                });
              }

              return SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(14.s, 0, 14.s, 110.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _staggered(
                          0,
                          6,
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await AuthService.clearToken();
                                if (!mounted) return;
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (_) => const AuthenticationWrapper(initialTabIndex: 0)),
                                  (route) => false,
                                );
                              },
                              icon: const Icon(Icons.logout),
                              label: const Text('Выйти'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _orange,
                                foregroundColor: Colors.black,
                                padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 10.s),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.s)),
                              ),
                            ),
                          )),
                      SizedBox(height: 10.s),
                      _staggered(1, 6, _infoCard(user)),
                      _staggered(2, 6, _ordersCard()),
                      _staggered(3, 6, _addressesCard(addresses)),
                      _staggered(4, 6, _cardsCard(cards)),
                      _staggered(5, 6, _telemetryCard()),
                      SizedBox(height: 14.s),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── User info ───────────────────────────────────────────
  Widget _infoCard(Map<String, dynamic> user) {
    return Container(
      margin: EdgeInsets.only(bottom: 14.s),
      padding: EdgeInsets.all(14.s),
      decoration: _cardBox(radius: 16.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(9.s),
                decoration: _pillBox(color: _blue),
                child: Icon(Icons.person, color: _orange, size: 25.s),
              ),
              SizedBox(width: 10.s),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user['name'] ?? '', style: TextStyle(color: _text, fontSize: 16.sp, fontWeight: FontWeight.w800)),
                  Text(user['login'] ?? '', style: TextStyle(color: _textMute, fontSize: 12.sp)),
                ],
              ),
            ],
          ),
          if (user['date_of_birth'] != null) ...[
            SizedBox(height: 7.s),
            Text('Дата рождения: ${user['date_of_birth']}', style: TextStyle(color: _textMute, fontSize: 12.sp)),
          ],
          if (user['sex'] != null) ...[
            SizedBox(height: 4.s),
            Text('Пол: ${user['sex'] == 1 ? 'Мужской' : 'Женский'}', style: TextStyle(color: _textMute, fontSize: 12.sp)),
          ],
        ],
      ),
    );
  }

  // ─── Orders ──────────────────────────────────────────────
  Widget _ordersCard() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 7.s),
      decoration: _cardBox(radius: 14.s),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 5.s),
        leading: Container(
          padding: EdgeInsets.all(9.s),
          decoration: _pillBox(color: _blue),
          child: const Icon(Icons.receipt_long, color: _orange),
        ),
        title: const Text('История заказов', style: TextStyle(color: _text, fontWeight: FontWeight.w900)),
        subtitle: const Text('Открыть все активные и завершённые заказы', style: TextStyle(color: _textMute)),
        trailing: const Icon(Icons.chevron_right, color: _textMute),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OrdersHistoryPage())),
      ),
    );
  }

  // ─── Addresses ───────────────────────────────────────────
  Widget _addressesCard(List<Map<String, dynamic>> addresses) {
    final visible = addresses.where((addr) => !_hiddenAddressIds.contains(_addressId(addr))).toList();
    final count = visible.length;
    final preview = count > 0 ? (visible.first['address']?.toString() ?? '') : 'Адресов нет';

    return Container(
      margin: EdgeInsets.symmetric(vertical: 7.s),
      decoration: _cardBox(radius: 14.s),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 6.s),
        leading: Container(
          padding: EdgeInsets.all(9.s),
          decoration: _pillBox(color: _blue),
          child: const Icon(Icons.location_on, color: _orange),
        ),
        title: const Text('Адреса', style: TextStyle(color: _text, fontWeight: FontWeight.w800)),
        subtitle: Text(
          count == 0 ? 'Нет сохранённых адресов' : '$count адрес(ов) • $preview',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _textMute),
        ),
        trailing: const Icon(Icons.chevron_right, color: _textMute),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileAddressesPage())).then((_) => _loadHiddenAddresses());
        },
      ),
    );
  }

  // ─── Saved cards ─────────────────────────────────────────
  Widget _cardsCard(List<Map<String, dynamic>> cards) {
    final count = cards.length;
    final preview = count > 0 ? (cards.first['mask']?.toString() ?? '••••') : 'Добавленных карт нет';

    return Container(
      margin: EdgeInsets.symmetric(vertical: 7.s),
      decoration: _cardBox(radius: 14.s),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 6.s),
        leading: Container(
          padding: EdgeInsets.all(9.s),
          decoration: _pillBox(color: _blue),
          child: const Icon(Icons.credit_card, color: _orange),
        ),
        title: const Text('Карты', style: TextStyle(color: _text, fontWeight: FontWeight.w800)),
        subtitle: Text(
          count == 0 ? 'Добавленных карт нет' : '$count карт(ы) • $preview',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _textMute),
        ),
        trailing: const Icon(Icons.chevron_right, color: _textMute),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileCardsPage()));
        },
      ),
    );
  }

  // ─── Telemetry toggle ────────────────────────────────────
  Widget _telemetryCard() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 7.s),
      decoration: _cardBox(radius: 14.s, accent: true),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.white.withValues(alpha: 0.06)),
        child: SwitchListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 6.s),
          secondary: const Icon(Icons.analytics_outlined, color: _orange),
          title: const Text('Сбор информации', style: TextStyle(color: _text, fontWeight: FontWeight.w800)),
          subtitle: const Text(
            'Анонимные отчёты об ошибках. Можно отключить в любой момент.',
            style: TextStyle(color: _textMute, height: 1.35),
          ),
          activeColor: _orange,
          value: _telemetryAllowed,
          onChanged: (value) async {
            setState(() => _telemetryAllowed = value);
            await TelemetryConsentService.setConsent(value);
          },
        ),
      ),
    );
  }
}
