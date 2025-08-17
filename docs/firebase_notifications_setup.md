# Firebase Push Notifications Setup

## 🚀 Что реализовано

1. **Firebase Cloud Messaging (FCM)** - интеграция для push-уведомлений
2. **Локальные уведомления** - отображение уведомлений даже когда приложение закрыто
3. **Автоматическая отправка токенов** - FCM токены автоматически отправляются на сервер
4. **Обработка различных типов уведомлений** - заказы, акции, доставка
5. **Настройки уведомлений** - пользователь может управлять типами уведомлений
6. **Навигация по уведомлениям** - клик по уведомлению открывает нужную страницу

## 📱 Файлы проекта

### Основные файлы:
- `lib/services/notification_service.dart` - основной сервис для работы с уведомлениями
- `lib/pages/notification_settings_page.dart` - страница настроек уведомлений
- `lib/utils/notification_tester.dart` - утилита для тестирования уведомлений
- `lib/utils/api.dart` - добавлены методы для работы с FCM токенами

### Конфигурационные файлы:
- `android/app/src/main/AndroidManifest.xml` - настройки Android
- `android/app/src/main/res/values/colors.xml` - цвета уведомлений
- `android/app/src/main/res/drawable/ic_notification.xml` - иконка уведомлений
- `ios/Runner/Info.plist` - настройки iOS (уже настроен)

## 🔧 Настройка Firebase Console

### 1. Создание проекта Firebase
1. Перейдите в [Firebase Console](https://console.firebase.google.com/)
2. Создайте новый проект или выберите существующий
3. Добавьте Android и iOS приложения в проект

### 2. Настройка Android приложения
1. Добавьте Android app с package name: `com.naliv.delivery`
2. Скачайте `google-services.json` 
3. Поместите файл в `android/app/`

### 3. Настройка iOS приложения
1. Добавьте iOS app с Bundle ID из проекта
2. Скачайте `GoogleService-Info.plist`
3. Поместите файл в `ios/Runner/`

### 4. Включение Cloud Messaging
1. В Firebase Console перейдите в "Cloud Messaging"
2. Настройте Server Key (для тестирования)

## 🛠 Серверная часть

### API эндпоинты для FCM токенов:

```typescript
// POST /api/users/fcm-token - сохранить FCM токен
{
  "fcm_token": "string"
}

// DELETE /api/users/fcm-token - удалить FCM токен
```

### Пример отправки уведомления с сервера:

```javascript
const admin = require('firebase-admin');

// Инициализация
const serviceAccount = require('./path/to/serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

// Отправка уведомления
const message = {
  notification: {
    title: 'Статус заказа изменен',
    body: 'Ваш заказ #12345 готов к выдаче'
  },
  data: {
    type: 'order_status_change',
    order_id: '12345',
    status: 'ready'
  },
  token: 'user_fcm_token_here'
};

admin.messaging().send(message)
  .then((response) => {
    console.log('Successfully sent message:', response);
  })
  .catch((error) => {
    console.log('Error sending message:', error);
  });
```

## 🎯 Типы уведомлений

### 1. Уведомления о заказах
```json
{
  "type": "order_status_change",
  "order_id": "12345",
  "status": "ready",
  "business_id": "1"
}
```

### 2. Уведомления о акциях
```json
{
  "type": "promotion",
  "business_id": "1",
  "promotion_id": "123"
}
```

### 3. Уведомления о доставке
```json
{
  "type": "delivery_update",
  "order_id": "12345",
  "estimated_time": "10 мин"
}
```

## 🧪 Тестирование

### 1. Получение FCM токена
```dart
final token = NotificationService.instance.fcmToken;
print('FCM Token: $token');
```

### 2. Отправка тестового уведомления
```dart
import 'package:naliv_delivery/utils/notification_tester.dart';

// Замените YOUR_SERVER_KEY на реальный ключ из Firebase Console
await NotificationTester.sendOrderStatusNotification(
  token: token!,
  orderId: '12345',
  status: 'ready',
);
```

### 3. Проверка через Firebase Console
1. Перейдите в "Cloud Messaging" → "Send your first message"
2. Введите заголовок и текст
3. Выберите приложение
4. Отправьте тестовое сообщение

## 📋 Чек-лист проверки

- [ ] Firebase проект создан
- [ ] `google-services.json` добавлен в Android
- [ ] `GoogleService-Info.plist` добавлен в iOS (если нужен)
- [ ] Приложение запускается без ошибок
- [ ] FCM токен генерируется и отображается в логах
- [ ] Уведомления приходят в foreground режиме
- [ ] Уведомления приходят в background режиме
- [ ] Клики по уведомлениям обрабатываются
- [ ] Сервер может сохранять FCM токены

## 🔍 Отладка

### Логи для проверки:
- `🔔 Инициализация сервиса уведомлений...`
- `📱 FCM Token: [токен]`
- `📨 Получено сообщение на переднем плане`
- `🔔 Нажато на уведомление`

### Частые проблемы:
1. **Токен не генерируется** - проверьте файлы конфигурации Firebase
2. **Уведомления не приходят** - проверьте Server Key и токен
3. **Навигация не работает** - проверьте обработчики в `NotificationService`

## 🎮 Использование

### Доступ к сервису:
```dart
final notificationService = NotificationService.instance;
```

### Подписка на топики:
```dart
await notificationService.subscribeToTopic('orders');
await notificationService.subscribeToTopic('promotions');
```

### Очистка уведомлений:
```dart
await notificationService.clearAllNotifications();
```

### Страница настроек:
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const NotificationSettingsPage(),
  ),
);
```
