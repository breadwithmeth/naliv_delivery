import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _orderNotifications = true;
  bool _promoNotifications = true;
  bool _deliveryNotifications = true;
  String? _fcmToken;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // TODO: Загрузить настройки из SharedPreferences
    final token = NotificationService.instance.fcmToken;
    setState(() {
      _fcmToken = token;
    });
  }

  Future<void> _toggleOrderNotifications(bool value) async {
    setState(() {
      _orderNotifications = value;
    });

    if (value) {
      await NotificationService.instance.subscribeToTopic('orders');
    } else {
      await NotificationService.instance.unsubscribeFromTopic('orders');
    }

    // TODO: Сохранить настройку в SharedPreferences
  }

  Future<void> _togglePromoNotifications(bool value) async {
    setState(() {
      _promoNotifications = value;
    });

    if (value) {
      await NotificationService.instance.subscribeToTopic('promotions');
    } else {
      await NotificationService.instance.unsubscribeFromTopic('promotions');
    }

    // TODO: Сохранить настройку в SharedPreferences
  }

  Future<void> _toggleDeliveryNotifications(bool value) async {
    setState(() {
      _deliveryNotifications = value;
    });

    if (value) {
      await NotificationService.instance.subscribeToTopic('delivery');
    } else {
      await NotificationService.instance.unsubscribeFromTopic('delivery');
    }

    // TODO: Сохранить настройку в SharedPreferences
  }

  Future<void> _clearAllNotifications() async {
    await NotificationService.instance.clearAllNotifications();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Все уведомления очищены'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки уведомлений'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Типы уведомлений',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Уведомления о заказах'),
                    subtitle:
                        const Text('Статус заказа, подтверждение, готовность'),
                    value: _orderNotifications,
                    onChanged: _toggleOrderNotifications,
                    secondary: const Icon(Icons.shopping_cart),
                  ),
                  SwitchListTile(
                    title: const Text('Акции и предложения'),
                    subtitle: const Text(
                        'Новые акции, скидки, специальные предложения'),
                    value: _promoNotifications,
                    onChanged: _togglePromoNotifications,
                    secondary: const Icon(Icons.local_offer),
                  ),
                  SwitchListTile(
                    title: const Text('Уведомления о доставке'),
                    subtitle: const Text('Курьер в пути, курьер прибыл'),
                    value: _deliveryNotifications,
                    onChanged: _toggleDeliveryNotifications,
                    secondary: const Icon(Icons.delivery_dining),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Действия',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Очистить все уведомления'),
                    subtitle: const Text('Убрать все текущие уведомления'),
                    leading: const Icon(Icons.clear_all),
                    onTap: _clearAllNotifications,
                  ),
                  ListTile(
                    title: const Text('Переинициализировать'),
                    subtitle: const Text('Перезапустить сервис уведомлений'),
                    leading: const Icon(Icons.refresh),
                    onTap: () async {
                      await NotificationService.instance.initialize();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Сервис уведомлений переинициализирован'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Информация',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('FCM Token'),
                    subtitle: Text(_fcmToken ?? 'Не получен'),
                    leading: const Icon(Icons.token),
                    trailing: _fcmToken != null
                        ? IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () {
                              // TODO: Скопировать токен в буфер обмена
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Токен скопирован в буфер обмена'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          )
                        : null,
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
