import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api.dart';
import 'package:naliv_delivery/utils/app_navigator.dart';

/// Глобальная функция для обработки фоновых сообщений
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Обработка фонового сообщения: ${message.messageId}');
  await NotificationService.instance.showNotification(message);
}

/// Сервис для управления push-уведомлениями
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  String? _fcmToken;

  /// Инициализация сервиса уведомлений
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🔔 Инициализация сервиса уведомлений...');

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
      debugPrint('✅ Сервис уведомлений инициализирован');
    } catch (e) {
      debugPrint('❌ Ошибка инициализации уведомлений: $e');
    }
  }

  /// Инициализация локальных уведомлений
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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

      await _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
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
      final androidImplementation = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
    }
  }

  /// Получение FCM токена
  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      if (_fcmToken != null) {
        debugPrint('📱 FCM Token: $_fcmToken');
        await _saveTokenToStorage(_fcmToken!);
        // Здесь можно отправить токен на сервер
        await _sendTokenToServer(_fcmToken!);
      }
    } catch (e) {
      debugPrint('❌ Ошибка получения FCM токена: $e');
    }

    // Обновление токена
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      debugPrint('🔄 Новый FCM Token: $newToken');
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
      debugPrint('📤 Отправка токена на сервер: $token');

      final success = await ApiService.updateFCMToken(token);

      if (success) {
        debugPrint('✅ Токен успешно отправлен на сервер');
      } else {
        debugPrint('❌ Ошибка отправки токена на сервер');
      }
    } catch (e) {
      debugPrint('❌ Ошибка отправки токена: $e');
    }
  }

  /// Настройка обработчиков сообщений
  void _setupMessageHandlers() {
    // Обработка сообщений на переднем плане
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📨 Получено сообщение на переднем плане: ${message.messageId}');
      showNotification(message);
    });

    // Обработка нажатий на уведомления
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔔 Нажато на уведомление: ${message.messageId}');
      _handleNotificationTap(message);
    });

    // Установка обработчика фоновых сообщений
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  /// Обработка начального сообщения (при запуске приложения из уведомления)
  Future<void> _handleInitialMessage() async {
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('🚀 Приложение запущено из уведомления: ${initialMessage.messageId}');
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
      debugPrint('❌ Ошибка показа уведомления: $e');
    }
  }

  /// Обработка нажатия на уведомление
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!);
        debugPrint('🔔 Нажато на локальное уведомление с данными: $data');
        _handleNotificationData(data);
      } catch (e) {
        debugPrint('❌ Ошибка обработки данных уведомления: $e');
      }
    }
  }

  /// Обработка нажатия на Firebase уведомление
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('🔔 Обработка нажатия на уведомление: ${message.data}');
    _handleNotificationData(message.data);
  }

  /// Обработка данных уведомления
  void _handleNotificationData(Map<String, dynamic> data) {
    final type = data['type'] ?? '';
    final orderId = data['order_id'];
    final businessId = data['business_id'];

    debugPrint('📋 Тип уведомления: $type, Order ID: $orderId, Business ID: $businessId');

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
      debugPrint('🚀 Навигация к заказу: $orderId');
      // Простейшая реализация: открываем вкладку Профиль (4), где пользователь видит список заказов
      AppNavigator.goToHomeTab(4);
    }
  }

  /// Навигация к акциям
  void _navigateToPromotions(String? businessId) {
    if (businessId != null) {
      debugPrint('🚀 Навигация к акциям магазина: $businessId');
      // Открываем главную (0), где обычно баннеры/акции
      AppNavigator.goToHomeTab(0);
    }
  }

  /// Навигация к трекингу доставки
  void _navigateToDeliveryTracking(String? orderId) {
    if (orderId != null) {
      debugPrint('🚀 Навигация к трекингу заказа: $orderId');
      // Пока отдельной страницы нет — ведём в Профиль, где доступна информация о заказах
      AppNavigator.goToHomeTab(4);
    }
  }

  /// Навигация на главную
  void _navigateToHome() {
    debugPrint('🚀 Навигация на главную страницу');
    AppNavigator.goToHomeTab(0);
  }

  /// Получить текущий FCM токен
  String? get fcmToken => _fcmToken;

  /// Подписка на топик
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      debugPrint('✅ Подписка на топик: $topic');
    } catch (e) {
      debugPrint('❌ Ошибка подписки на топик $topic: $e');
    }
  }

  /// Отписка от топика
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      debugPrint('✅ Отписка от топика: $topic');
    } catch (e) {
      debugPrint('❌ Ошибка отписки от топика $topic: $e');
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
