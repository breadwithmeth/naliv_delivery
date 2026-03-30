import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/login_page.dart';
import 'package:naliv_delivery/pages/orders_history_page.dart';
import '../utils/api.dart';
import '../services/auth_service.dart';
import '../services/telemetry_consent_service.dart';
import 'package:naliv_delivery/widgets/authentication_wrapper.dart';
import 'package:naliv_delivery/shared/app_theme.dart';
import '../utils/responsive.dart';

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic> userInfo;

  const ProfilePage({required this.userInfo, super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final Future<Map<String, dynamic>?> _profileFuture;
  bool _telemetryAllowed = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = ApiService.getFullInfo();
    _checkAuth();
    _loadTelemetryConsent();
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
    if (!mounted) return; // виджет мог быть удалён пока ждали

    if (!isLoggedIn) {
      // Откладываем показ SnackBar до следующего кадра, чтобы Scaffold точно существовал
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Пожалуйста, авторизуйтесь')),
          );
      });
      return;
    }

    final data = await _profileFuture;
    if (!mounted) return;

    if (data == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Ошибка получения данных профиля')),
          );
      });
      return;
    }

    // Успех
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Данные профиля успешно получены')),
        );
    });
  }

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
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppColors.orange),
                  ),
                );
              }
              if (snapshot.hasError || snapshot.data == null) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(redirectTabIndex: 4),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
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

              // Update Sentry user context when consent is granted and data is available.
              TelemetryConsentService.applyUserContext(
                id: (user['id'] ?? user['user_id'])?.toString(),
                username: user['login'] as String?,
                email: user['email'] as String?,
              );

              return SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(14.s, 0, 14.s, 110.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await AuthService.clearToken();
                            if (!mounted) return;
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const AuthenticationWrapper(initialTabIndex: 0),
                              ),
                              (route) => false,
                            );
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Выйти'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.orange,
                            foregroundColor: Colors.black,
                            padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 10.s),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.s)),
                          ),
                        ),
                      ),
                      SizedBox(height: 10.s),
                      _infoCard(user),
                      _ordersCard(),
                      _addressesCard(addresses),
                      _cardsCard(cards),
                      _telemetryCard(),
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

  Widget _infoCard(Map<String, dynamic> user) {
    return Container(
      margin: EdgeInsets.only(bottom: 14.s),
      padding: EdgeInsets.all(14.s),
      decoration: AppDecorations.card(radius: 16.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(9.s),
                decoration: AppDecorations.pill(color: AppColors.blue),
                child: Icon(Icons.person, color: AppColors.orange, size: 25.s),
              ),
              SizedBox(width: 10.s),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user['name'] ?? '', style: TextStyle(color: AppColors.text, fontSize: 16.sp, fontWeight: FontWeight.w800)),
                  Text(user['login'] ?? '', style: TextStyle(color: AppColors.textMute, fontSize: 12.sp)),
                ],
              ),
            ],
          ),
          if (user['date_of_birth'] != null) ...[
            SizedBox(height: 7.s),
            Text('Дата рождения: ${user['date_of_birth']}', style: TextStyle(color: AppColors.textMute, fontSize: 12.sp)),
          ],
          if (user['sex'] != null) ...[
            SizedBox(height: 4.s),
            Text('Пол: ${user['sex'] == 1 ? 'Мужской' : 'Женский'}', style: TextStyle(color: AppColors.textMute, fontSize: 12.sp)),
          ],
        ],
      ),
    );
  }

  Widget _addressesCard(List<Map<String, dynamic>> addresses) {
    final normalized = addresses
        .map((addr) => {
              'address': (addr['address'] as String?) ?? '',
              'name': (addr['name'] as String?) ?? '',
              'apartment': (addr['apartment'] as String?) ?? '',
              'entrance': (addr['entrance'] as String?) ?? '',
              'floor': (addr['floor'] as String?) ?? '',
              'other': (addr['other'] as String?) ?? '',
            })
        .toList();

    return Container(
      margin: EdgeInsets.symmetric(vertical: 7.s),
      decoration: AppDecorations.card(radius: 14.s),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.white.withValues(alpha: 0.06)),
        child: ExpansionTile(
          leading: const Icon(Icons.location_on, color: AppColors.orange),
          title: const Text('Адреса', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
          children: normalized
              .map(
                (addr) => Container(
                  margin: EdgeInsets.symmetric(horizontal: 10.s, vertical: 5.s),
                  padding: EdgeInsets.all(10.s),
                  decoration: AppDecorations.card(radius: 10.s, shadow: false, color: AppColors.cardDark),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.home, color: AppColors.textMute),
                          SizedBox(width: 7.s),
                          Expanded(
                            child: Text(addr['address']!, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      SizedBox(height: 5.s),
                      ...[
                        if (addr['name']!.isNotEmpty) 'Имя: ${addr['name']}',
                        if (addr['apartment']!.isNotEmpty) 'Кв.: ${addr['apartment']}',
                        if (addr['entrance']!.isNotEmpty) 'Под.: ${addr['entrance']}',
                        if (addr['floor']!.isNotEmpty) 'Эт.: ${addr['floor']}',
                        if (addr['other']!.isNotEmpty) 'Прим.: ${addr['other']}',
                      ].map((text) => Text(text, style: TextStyle(color: AppColors.textMute, fontSize: 11.sp))).toList(),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _ordersCard() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 7.s),
      decoration: AppDecorations.card(radius: 14.s),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 5.s),
        leading: Container(
          padding: EdgeInsets.all(9.s),
          decoration: AppDecorations.pill(color: AppColors.blue),
          child: const Icon(Icons.receipt_long, color: AppColors.orange),
        ),
        title: const Text(
          'История заказов',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w900),
        ),
        subtitle: const Text(
          'Открыть все активные и завершённые заказы',
          style: TextStyle(color: AppColors.textMute),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMute),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const OrdersHistoryPage(),
            ),
          );
        },
      ),
    );
  }

  Widget _cardsCard(List<Map<String, dynamic>> cards) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 7.s),
      decoration: AppDecorations.card(radius: 14.s),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.white.withValues(alpha: 0.06)),
        child: ExpansionTile(
          leading: const Icon(Icons.credit_card, color: AppColors.orange),
          title: const Text('Карты', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
          children: cards
              .map(
                (card) => ListTile(
                  leading: const Icon(Icons.credit_card, color: AppColors.textMute),
                  title: Text(card['mask'] ?? '', style: const TextStyle(color: AppColors.text)),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _telemetryCard() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 7.s),
      decoration: AppDecorations.card(radius: 14.s),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.white.withValues(alpha: 0.06)),
        child: SwitchListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 6.s),
          secondary: const Icon(Icons.analytics_outlined, color: AppColors.orange),
          title: const Text('Сбор информации', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
          subtitle: const Text(
            'Помогает собирать ошибки и аналитические данные для улучшения приложения. Личные данные отправляются только с вашего согласия.',
            style: TextStyle(color: AppColors.textMute),
          ),
          value: _telemetryAllowed,
          onChanged: (value) async {
            setState(() {
              _telemetryAllowed = value;
            });
            await TelemetryConsentService.setConsent(value);
          },
        ),
      ),
    );
  }
}
