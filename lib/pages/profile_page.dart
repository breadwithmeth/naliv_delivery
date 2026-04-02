import 'package:flutter/material.dart';
import 'package:gradusy24/pages/login_page.dart';
import 'package:gradusy24/pages/orders_history_page.dart';
import 'package:gradusy24/shared/app_theme.dart';
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

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
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
    setState(() => _telemetryAllowed = allowed);
  }

  Future<void> _checkAuth() async {
    final isLoggedIn = await ApiService.isUserLoggedIn();
    if (!mounted) return;
    if (!isLoggedIn) return;
    final data = await _profileFuture;
    if (!mounted) return;
    if (data == null) return;
  }

  // ── Stagger animation ────────────────────────────────────

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

  // ── Helpers ───────────────────────────────────────────────

  Widget _thinDivider() => Divider(height: 1, thickness: 0.5, color: AppColors.textMute.withValues(alpha: 0.12));

  Widget _tapRow({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 18.s, vertical: 14.s),
        child: Row(
          children: [
            Icon(icon, color: AppColors.orange, size: 22.s),
            SizedBox(width: 14.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: AppColors.text, fontSize: 14.sp, fontWeight: FontWeight.w700)),
                  if (subtitle != null) ...[
                    SizedBox(height: 2.s),
                    Text(subtitle,
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textMute, fontSize: 12.sp, height: 1.3)),
                  ],
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right, color: AppColors.textMute.withValues(alpha: 0.5), size: 20.s),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.text,
        title: const Text('Профиль', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Stack(
        children: [
          const AppBackground(),
          FutureBuilder<Map<String, dynamic>?>(
            future: _profileFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.orange));
              }
              if (snapshot.hasError || snapshot.data == null) {
                return _loginPrompt();
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
                  padding: EdgeInsets.fromLTRB(0, 0, 0, 110.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── User header ──
                      _staggered(0, 7, _userHeader(user)),
                      _staggered(1, 7, _thinDivider()),
                      // ── Navigation rows ──
                      _staggered(
                          2,
                          7,
                          _tapRow(
                            icon: Icons.receipt_long_rounded,
                            title: 'История заказов',
                            subtitle: 'Активные и завершённые заказы',
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OrdersHistoryPage())),
                          )),
                      _staggered(3, 7, _thinDivider()),
                      _staggered(4, 7, _addressRow(addresses)),
                      _staggered(5, 7, _thinDivider()),
                      _staggered(6, 7, _cardsRow(cards)),
                      _thinDivider(),
                      _telemetryRow(),
                      _thinDivider(),
                      SizedBox(height: 22.s),
                      // ── Logout ──
                      _logoutRow(),
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

  // ── Login prompt (not logged in) ─────────────────────────

  Widget _loginPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline_rounded, size: 48.s, color: AppColors.textMute.withValues(alpha: 0.5)),
          SizedBox(height: 12.s),
          Text('Войдите в аккаунт', style: TextStyle(color: AppColors.text, fontSize: 16.sp, fontWeight: FontWeight.w700)),
          SizedBox(height: 4.s),
          Text('Для просмотра профиля', style: TextStyle(color: AppColors.textMute, fontSize: 13.sp)),
          SizedBox(height: 18.s),
          SizedBox(
            width: 180.s,
            height: 44.s,
            child: Material(
              color: AppColors.orange,
              borderRadius: BorderRadius.circular(14.s),
              child: InkWell(
                borderRadius: BorderRadius.circular(14.s),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage(redirectTabIndex: 4))),
                child: Center(
                  child: Text('Войти', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: Colors.black)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── User header ──────────────────────────────────────────

  Widget _userHeader(Map<String, dynamic> user) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18.s, 8.s, 18.s, 14.s),
      child: Row(
        children: [
          Container(
            width: 48.s,
            height: 48.s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.orange.withValues(alpha: 0.15),
            ),
            child: Icon(Icons.person_rounded, color: AppColors.orange, size: 26.s),
          ),
          SizedBox(width: 14.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['name'] ?? '', style: TextStyle(color: AppColors.text, fontSize: 17.sp, fontWeight: FontWeight.w800)),
                SizedBox(height: 2.s),
                Text(user['login'] ?? '', style: TextStyle(color: AppColors.textMute, fontSize: 13.sp)),
                if (user['date_of_birth'] != null) ...[
                  SizedBox(height: 2.s),
                  Text(user['date_of_birth'], style: TextStyle(color: AppColors.textMute.withValues(alpha: 0.6), fontSize: 12.sp)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Address row ──────────────────────────────────────────

  Widget _addressRow(List<Map<String, dynamic>> addresses) {
    final visible = addresses.where((a) => !_hiddenAddressIds.contains(_addressId(a))).toList();
    final count = visible.length;
    final preview = count > 0 ? (visible.first['address']?.toString() ?? '') : 'Нет сохранённых адресов';

    return _tapRow(
      icon: Icons.location_on_rounded,
      title: 'Адреса',
      subtitle: count == 0 ? 'Нет сохранённых адресов' : '$count адрес(ов) · $preview',
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileAddressesPage())).then((_) => _loadHiddenAddresses());
      },
    );
  }

  // ── Cards row ────────────────────────────────────────────

  Widget _cardsRow(List<Map<String, dynamic>> cards) {
    final count = cards.length;
    final preview = count > 0 ? (cards.first['mask']?.toString() ?? '••••') : 'Добавленных карт нет';

    return _tapRow(
      icon: Icons.credit_card_rounded,
      title: 'Карты',
      subtitle: count == 0 ? 'Добавленных карт нет' : '$count карт(ы) · $preview',
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileCardsPage())),
    );
  }

  // ── Telemetry toggle ─────────────────────────────────────

  Widget _telemetryRow() {
    return InkWell(
      onTap: () async {
        final value = !_telemetryAllowed;
        setState(() => _telemetryAllowed = value);
        await TelemetryConsentService.setConsent(value);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 18.s, vertical: 14.s),
        child: Row(
          children: [
            Icon(Icons.analytics_outlined, color: AppColors.orange, size: 22.s),
            SizedBox(width: 14.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Сбор информации', style: TextStyle(color: AppColors.text, fontSize: 14.sp, fontWeight: FontWeight.w700)),
                  SizedBox(height: 2.s),
                  Text('Анонимные отчёты об ошибках', style: TextStyle(color: AppColors.textMute, fontSize: 12.sp, height: 1.3)),
                ],
              ),
            ),
            SizedBox(
              height: 28,
              child: Switch(
                value: _telemetryAllowed,
                activeTrackColor: AppColors.orange,
                activeThumbColor: Colors.white,
                onChanged: (value) async {
                  setState(() => _telemetryAllowed = value);
                  await TelemetryConsentService.setConsent(value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Logout ───────────────────────────────────────────────

  Widget _logoutRow() {
    return Center(
      child: TextButton.icon(
        onPressed: () async {
          await AuthService.clearToken();
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthenticationWrapper(initialTabIndex: 0)),
            (route) => false,
          );
        },
        icon: Icon(Icons.logout_rounded, size: 18.s, color: AppColors.red),
        label: Text('Выйти', style: TextStyle(color: AppColors.red, fontSize: 14.sp, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
