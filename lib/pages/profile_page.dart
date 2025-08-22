import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/login_page.dart';
import '../utils/api.dart';
import '../services/agreement_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _checkAuth();
  }

  void _checkAuth() async {
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

    final data = await ApiService.getFullInfo();
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
      appBar: AppBar(
        title: const Text('Профиль'),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: ApiService.getFullInfo(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
                child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginPage()),
                      );
                    },
                    child: Text('Войти')));
          }
          final data = snapshot.data!;
          final user = data['user'] as Map<String, dynamic>;
          final addresses =
              (data['addresses'] as List<dynamic>).cast<Map<String, dynamic>>();
          final cards =
              (data['cards'] as List<dynamic>).cast<Map<String, dynamic>>();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              size: 40,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user['name'] ?? '',
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                Text(user['login'] ?? '',
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ],
                        ),
                        if (user['date_of_birth'] != null) ...[
                          const SizedBox(height: 8),
                          Text('Дата рождения: ${user['date_of_birth']}',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                        if (user['sex'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                              'Пол: ${user['sex'] == 1 ? 'Мужской' : 'Женский'}',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ],
                    ),
                  ),
                ),
                // Addresses
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                  child: ExpansionTile(
                    leading: Icon(
                      Icons.location_on,
                    ),
                    title: Text('Адреса',
                        style: Theme.of(context).textTheme.titleMedium),
                    children: addresses
                        .map((addr) => Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              elevation: 1,
                              child: ListTile(
                                leading: Icon(
                                  Icons.home,
                                ),
                                title: Text(addr['address'] ?? '',
                                    style:
                                        Theme.of(context).textTheme.bodyLarge),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if ((addr['name'] as String).isNotEmpty)
                                      Text('Имя: ${addr['name']}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                    if ((addr['apartment'] as String)
                                        .isNotEmpty)
                                      Text('Кв.: ${addr['apartment']}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                    if ((addr['entrance'] as String).isNotEmpty)
                                      Text('Под.: ${addr['entrance']}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                    if ((addr['floor'] as String).isNotEmpty)
                                      Text('Эт.: ${addr['floor']}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                    if ((addr['other'] as String).isNotEmpty)
                                      Text('Прим.: ${addr['other']}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                  ],
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                // Cards
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                  child: ExpansionTile(
                    leading: Icon(
                      Icons.credit_card,
                    ),
                    title: Text('Карты',
                        style: Theme.of(context).textTheme.titleMedium),
                    children: cards
                        .map((card) => ListTile(
                              leading: const Icon(Icons.credit_card),
                              title: Text(card['mask'] ?? ''),
                            ))
                        .toList(),
                  ),
                ),

                // Раздел настроек (только для разработки/отладки)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                  child: ExpansionTile(
                    leading: const Icon(Icons.settings),
                    title: Text('Настройки разработчика',
                        style: Theme.of(context).textTheme.titleMedium),
                    children: [
                      ListTile(
                        leading: const Icon(Icons.description),
                        title: const Text('Сбросить согласие с офертой'),
                        subtitle: const Text('Для тестирования экрана оферты'),
                        onTap: () async {
                          await AgreementService.resetAllAgreements();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Согласия сброшены. Перезапустите приложение.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.info),
                        title: const Text('Проверить статус согласий'),
                        onTap: () async {
                          final isAccepted =
                              await AgreementService.isOfferAccepted();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Оферта ${isAccepted ? "принята" : "не принята"}',
                                ),
                                backgroundColor:
                                    isAccepted ? Colors.green : Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}
