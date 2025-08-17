import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api.dart';

/// Глобальная функция для обработки фоновых сообщений
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Обработка фонового сообщения: ${message.messageId}');
  await NotificationService.instance.showNotification(message);
}

/// Сервис для управления push-уведомлениями
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  String? _fcmToken;

  /// Инициализация сервиса уведомлений
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🔔 Инициализация сервиса уведомлений...');

      // Инициализация локальных уведомлений
      await _initializeLocalNotifications();

      // Запрос разрешений
      await _requestPermissions();

      // Получение FCM токена
      await _getFCMToken();

      // Настройка обработчиков сообщений
      _setupMessageHandlers();

      // Обработка уведомлений при запуске приложения
      await _handleInitialMessage();

      _isInitialized = true;
      print('✅ Сервис уведомлений инициализирован');
    } catch (e) {
      print('❌ Ошибка инициализации уведомлений: $e');
    }
  }

  /// Инициализация локальных уведомлений
  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Создание канала уведомлений для Android
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'naliv_orders',
        'Заказы Naliv',
        description: 'Уведомления о статусе заказов',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Запрос разрешений на уведомления
  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    }

    if (Platform.isAndroid) {
      final androidImplementation =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
    }
  }

  /// Получение FCM токена
  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      if (_fcmToken != null) {
        print('📱 FCM Token: $_fcmToken');
        await _saveTokenToStorage(_fcmToken!);
        // Здесь можно отправить токен на сервер
        await _sendTokenToServer(_fcmToken!);
      }
    } catch (e) {
      print('❌ Ошибка получения FCM токена: $e');
    }

    // Обновление токена
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      print('🔄 Новый FCM Token: $newToken');
      _fcmToken = newToken;
      await _saveTokenToStorage(newToken);
      await _sendTokenToServer(newToken);
    });
  }

  /// Сохранение токена в локальное хранилище
  Future<void> _saveTokenToStorage(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
  }

  /// Отправка токена на сервер
  Future<void> _sendTokenToServer(String token) async {
    try {
      print('📤 Отправка токена на сервер: $token');

      final success = await ApiService.updateFCMToken(token);

      if (success) {
        print('✅ Токен успешно отправлен на сервер');
      } else {
        print('❌ Ошибка отправки токена на сервер');
      }
    } catch (e) {
      print('❌ Ошибка отправки токена: $e');
    }
  }

  /// Настройка обработчиков сообщений
  void _setupMessageHandlers() {
    // Обработка сообщений на переднем плане
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📨 Получено сообщение на переднем плане: ${message.messageId}');
      showNotification(message);
    });

    // Обработка нажатий на уведомления
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔔 Нажато на уведомление: ${message.messageId}');
      _handleNotificationTap(message);
    });

    // Установка обработчика фоновых сообщений
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  /// Обработка начального сообщения (при запуске приложения из уведомления)
  Future<void> _handleInitialMessage() async {
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      print(
          '🚀 Приложение запущено из уведомления: ${initialMessage.messageId}');
      _handleNotificationTap(initialMessage);
    }
  }

  /// Показ локального уведомления
  Future<void> showNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;

      if (notification != null) {
        final androidDetails = AndroidNotificationDetails(
          'naliv_orders',
          'Заказы Naliv',
          channelDescription: 'Уведомления о статусе заказов',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        );

        const iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

        final details = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

        await _localNotifications.show(
          message.hashCode,
          notification.title ?? 'Naliv',
          notification.body ?? 'У вас новое уведомление',
          details,
          payload: json.encode(message.data),
        );
      }
    } catch (e) {
      print('❌ Ошибка показа уведомления: $e');
    }
  }

  /// Обработка нажатия на уведомление
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!);
        print('🔔 Нажато на локальное уведомление с данными: $data');
        _handleNotificationData(data);
      } catch (e) {
        print('❌ Ошибка обработки данных уведомления: $e');
      }
    }
  }

  /// Обработка нажатия на Firebase уведомление
  void _handleNotificationTap(RemoteMessage message) {
    print('🔔 Обработка нажатия на уведомление: ${message.data}');
    _handleNotificationData(message.data);
  }

  /// Обработка данных уведомления
  void _handleNotificationData(Map<String, dynamic> data) {
    final type = data['type'] ?? '';
    final orderId = data['order_id'];
    final businessId = data['business_id'];

    print(
        '📋 Тип уведомления: $type, Order ID: $orderId, Business ID: $businessId');

    // TODO: Реализовать навигацию в зависимости от типа уведомления
    switch (type) {
      case 'order_status_change':
        // Открыть страницу заказа
        _navigateToOrder(orderId);
        break;
      case 'promotion':
        // Открыть страницу акций
        _navigateToPromotions(businessId);
        break;
      case 'delivery_update':
        // Открыть трекинг доставки
        _navigateToDeliveryTracking(orderId);
        break;
      default:
        // Открыть главную страницу
        _navigateToHome();
        break;
    }
  }

  /// Навигация к заказу
  void _navigateToOrder(String? orderId) {
    if (orderId != null) {
      print('🚀 Навигация к заказу: $orderId');
      // TODO: Реализовать навигацию к странице заказа
    }
  }

  /// Навигация к акциям
  void _navigateToPromotions(String? businessId) {
    if (businessId != null) {
      print('🚀 Навигация к акциям магазина: $businessId');
      // TODO: Реализовать навигацию к странице акций
    }
  }

  /// Навигация к трекингу доставки
  void _navigateToDeliveryTracking(String? orderId) {
    if (orderId != null) {
      print('🚀 Навигация к трекингу заказа: $orderId');
      // TODO: Реализовать навигацию к странице трекинга
    }
  }

  /// Навигация на главную
  void _navigateToHome() {
    print('🚀 Навигация на главную страницу');
    // TODO: Реализовать навигацию на главную страницу
  }

  /// Получить текущий FCM токен
  String? get fcmToken => _fcmToken;

  /// Подписка на топик
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('✅ Подписка на топик: $topic');
    } catch (e) {
      print('❌ Ошибка подписки на топик $topic: $e');
    }
  }

  /// Отписка от топика
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('✅ Отписка от топика: $topic');
    } catch (e) {
      print('❌ Ошибка отписки от топика $topic: $e');
    }
  }

  /// Очистка всех уведомлений
  Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  /// Получить количество непрочитанных уведомлений (только iOS)
  Future<int> getBadgeCount() async {
    if (Platform.isIOS) {
      // Реализация для iOS
      return 0;
    }
    return 0;
  }

  /// Установить количество непрочитанных уведомлений (только iOS)
  Future<void> setBadgeCount(int count) async {
    if (Platform.isIOS) {
      // TODO: Реализовать установку badge для iOS
    }
  }
}
