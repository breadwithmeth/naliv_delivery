import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Утилита для тестирования отправки push-уведомлений
/// ВНИМАНИЕ: Используйте только для тестирования!
class NotificationTester {
  // Server Key из Firebase Console
  static const String _serverKey = 'YOUR_SERVER_KEY_HERE';
  static const String _fcmUrl = 'https://fcm.googleapis.com/fcm/send';

  /// Отправить тестовое уведомление
  /// [token] - FCM токен устройства
  /// [title] - заголовок уведомления
  /// [body] - текст уведомления
  /// [data] - дополнительные данные
  static Future<bool> sendTestNotification({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final payload = {
        'to': token,
        'notification': {
          'title': title,
          'body': body,
          'sound': 'default',
        },
        'data': data ?? {},
        'priority': 'high',
      };

      final response = await http.post(
        Uri.parse(_fcmUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_serverKey',
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Уведомление отправлено успешно');
        return true;
      } else {
        debugPrint('❌ Ошибка отправки: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Ошибка: $e');
      return false;
    }
  }

  /// Отправить уведомление о смене статуса заказа
  static Future<bool> sendOrderStatusNotification({
    required String token,
    required String orderId,
    required String status,
    String? businessId,
  }) async {
    final statusMessages = {
      'confirmed': 'Ваш заказ подтвержден',
      'preparing': 'Ваш заказ готовится',
      'ready': 'Ваш заказ готов к выдаче',
      'delivering': 'Курьер в пути',
      'delivered': 'Заказ доставлен',
    };

    return await sendTestNotification(
      token: token,
      title: 'Статус заказа #$orderId',
      body: statusMessages[status] ?? 'Статус заказа изменен',
      data: {
        'type': 'order_status_change',
        'order_id': orderId,
        'status': status,
        if (businessId != null) 'business_id': businessId,
      },
    );
  }

  /// Отправить уведомление о новой акции
  static Future<bool> sendPromotionNotification({
    required String token,
    required String promotionTitle,
    required String businessId,
  }) async {
    return await sendTestNotification(
      token: token,
      title: 'Новая акция! 🎉',
      body: promotionTitle,
      data: {
        'type': 'promotion',
        'business_id': businessId,
      },
    );
  }

  /// Отправить уведомление о доставке
  static Future<bool> sendDeliveryNotification({
    required String token,
    required String orderId,
    required String message,
    String? estimatedTime,
  }) async {
    return await sendTestNotification(
      token: token,
      title: 'Доставка заказа #$orderId',
      body: message,
      data: {
        'type': 'delivery_update',
        'order_id': orderId,
        if (estimatedTime != null) 'estimated_time': estimatedTime,
      },
    );
  }
}

/// Примеры использования:
/// 
/// // Получить FCM токен
/// final token = NotificationService.instance.fcmToken;
/// 
/// // Отправить уведомление о статусе заказа
/// await NotificationTester.sendOrderStatusNotification(
///   token: token!,
///   orderId: '12345',
///   status: 'ready',
///   businessId: '1',
/// );
/// 
/// // Отправить уведомление о новой акции
/// await NotificationTester.sendPromotionNotification(
///   token: token!,
///   promotionTitle: 'Скидка 20% на все товары!',
///   businessId: '1',
/// );
/// 
/// // Отправить уведомление о доставке
/// await NotificationTester.sendDeliveryNotification(
///   token: token!,
///   orderId: '12345',
///   message: 'Курьер прибудет через 10 минут',
///   estimatedTime: '10 мин',
/// );
