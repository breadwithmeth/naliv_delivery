import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/login_page.dart';
import '../utils/api.dart';
import '../services/agreement_service.dart';
import '../services/auth_service.dart';
import 'package:naliv_delivery/widgets/authentication_wrapper.dart';
import 'package:naliv_delivery/shared/app_theme.dart';

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic> userInfo;

  const ProfilePage({required this.userInfo, super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final Future<Map<String, dynamic>?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = ApiService.getFullInfo();
    _checkAuth();
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
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Войти', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                );
              }
              final data = snapshot.data!;
              final user = data['user'] as Map<String, dynamic>;
              final addresses = (data['addresses'] as List<dynamic>).cast<Map<String, dynamic>>();
              final cards = (data['cards'] as List<dynamic>).cast<Map<String, dynamic>>();

              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
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
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _infoCard(user),
                      _addressesCard(addresses),
                      _cardsCard(cards),
                      _devSettingsCard(),
                      const SizedBox(height: 16),
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: AppDecorations.pill(color: AppColors.blue),
                child: const Icon(Icons.person, color: AppColors.orange, size: 28),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user['name'] ?? '', style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(user['login'] ?? '', style: TextStyle(color: AppColors.textMute, fontSize: 13)),
                ],
              ),
            ],
          ),
          if (user['date_of_birth'] != null) ...[
            const SizedBox(height: 8),
            Text('Дата рождения: ${user['date_of_birth']}', style: TextStyle(color: AppColors.textMute, fontSize: 13)),
          ],
          if (user['sex'] != null) ...[
            const SizedBox(height: 4),
            Text('Пол: ${user['sex'] == 1 ? 'Мужской' : 'Женский'}', style: TextStyle(color: AppColors.textMute, fontSize: 13)),
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
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: AppDecorations.card(radius: 16),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.white.withValues(alpha: 0.06)),
        child: ExpansionTile(
          leading: const Icon(Icons.location_on, color: AppColors.orange),
          title: const Text('Адреса', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
          children: normalized
              .map(
                (addr) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: AppDecorations.card(radius: 12, shadow: false, color: AppColors.cardDark),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.home, color: AppColors.textMute),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(addr['address']!, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...[
                        if (addr['name']!.isNotEmpty) 'Имя: ${addr['name']}',
                        if (addr['apartment']!.isNotEmpty) 'Кв.: ${addr['apartment']}',
                        if (addr['entrance']!.isNotEmpty) 'Под.: ${addr['entrance']}',
                        if (addr['floor']!.isNotEmpty) 'Эт.: ${addr['floor']}',
                        if (addr['other']!.isNotEmpty) 'Прим.: ${addr['other']}',
                      ].map((text) => Text(text, style: TextStyle(color: AppColors.textMute, fontSize: 12))).toList(),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _cardsCard(List<Map<String, dynamic>> cards) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: AppDecorations.card(radius: 16),
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

  Widget _devSettingsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: AppDecorations.card(radius: 16),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.white.withValues(alpha: 0.06)),
        child: ExpansionTile(
          leading: const Icon(Icons.settings, color: AppColors.orange),
          title: const Text('Настройки разработчика', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
          children: [
            ListTile(
              leading: const Icon(Icons.description, color: AppColors.textMute),
              title: const Text('Сбросить согласие с офертой', style: TextStyle(color: AppColors.text)),
              subtitle: Text('Для тестирования экрана оферты', style: TextStyle(color: AppColors.textMute)),
              onTap: () async {
                await AgreementService.resetAllAgreements();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Согласия сброшены. Перезапустите приложение.'),
                      backgroundColor: AppColors.orange,
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.info, color: AppColors.textMute),
              title: const Text('Проверить статус согласий', style: TextStyle(color: AppColors.text)),
              onTap: () async {
                final isAccepted = await AgreementService.isOfferAccepted();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Оферта ${isAccepted ? "принята" : "не принята"}'),
                      backgroundColor: isAccepted ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
