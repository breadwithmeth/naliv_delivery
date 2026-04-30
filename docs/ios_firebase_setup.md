# iOS Push Notifications Setup для Firebase

## 🍎 Настройка iOS для Firebase Push Notifications

### 1. Подготовка в Apple Developer Account

#### Создание App ID с Push Notifications:
1. Войдите в [Apple Developer Console](https://developer.apple.com/account/)
2. Перейдите в "Certificates, Identifiers & Profiles"
3. В разделе "Identifiers" найдите ваш App ID
4. Убедитесь, что включена опция "Push Notifications"
5. Если не включена - отредактируйте и включите

#### Создание APNs ключа (рекомендуется):
1. В разделе "Keys" создайте новый ключ
2. Дайте ему имя (например, "Naliv Push Notifications")
3. Выберите "Apple Push Notifications service (APNs)"
4. Скачайте файл ключа (.p8)
5. Запомните Key ID и Team ID

### 2. Настройка в Firebase Console

#### Добавление iOS приложения:
1. Откройте [Firebase Console](https://console.firebase.google.com/)
2. Выберите ваш проект
3. Нажмите "Add app" → iOS
4. Введите Bundle ID: `naliv_delivery` (или ваш Bundle ID)
5. Скачайте `GoogleService-Info.plist`

#### Загрузка APNs ключа:
1. В Firebase Console перейдите в Project Settings
2. Вкладка "Cloud Messaging"
3. В разделе "iOS app configuration"
4. Загрузите ваш APNs ключ (.p8 файл)
5. Введите Key ID и Team ID

### 3. Файлы проекта (уже настроены)

#### ✅ Обновленные файлы:
- `ios/Runner/AppDelegate.swift` - добавлена поддержка Firebase Messaging
- `ios/Runner/Info.plist` - настроены background modes
- `ios/Runner/Runner.entitlements` - настроен aps-environment
- `ios/Podfile` - указана минимальная версия iOS 12.0

#### ✅ Должен присутствовать:
- `ios/Runner/GoogleService-Info.plist` ✅ (уже есть)

### 4. Проверка настройки

#### Запуск приложения:
```bash
cd /Users/shrvse/naliv_delivery
flutter run
```

#### Проверка в логах:
Должны появиться сообщения:
- `🔔 Инициализация сервиса уведомлений...`
- `📱 FCM Token: [длинный токен]`
- `Firebase registration token: [токен]`

### 5. Тестирование уведомлений

#### Через Firebase Console:
1. Перейдите в "Cloud Messaging"
2. Нажмите "Send your first message"
3. Введите заголовок и текст
4. Выберите iOS приложение
5. Отправьте тестовое сообщение

#### Через код (для разработки):
```dart
import 'package:naliv_delivery/services/notification_service.dart';

// Получить токен
final token = NotificationService.instance.fcmToken;
print('FCM Token для тестирования: $token');
```

### 6. Режимы работы

#### Development (Разработка):
- `aps-environment: development` в entitlements
- Работает только на реальных устройствах
- Использует development APNs сервер

#### Production (Продакшн):
- `aps-environment: production` в entitlements
- Работает на всех устройствах
- Использует production APNs сервер

### 7. Troubleshooting

#### Уведомления не приходят:
1. ✅ Проверьте Bundle ID в Firebase и Xcode
2. ✅ Убедитесь, что APNs ключ загружен в Firebase
3. ✅ Проверьте, что приложение запущено на реальном устройстве
4. ✅ Убедитесь, что разрешения на уведомления предоставлены

#### FCM токен не генерируется:
1. ✅ Проверьте наличие GoogleService-Info.plist
2. ✅ Убедитесь, что Firebase.configure() вызывается
3. ✅ Проверьте подключение к интернету

#### Ошибки сборки:
```bash
# Очистить и пересобрать
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
flutter clean
flutter pub get
flutter run
```

### 8. Финальный чек-лист

- [ ] App ID с Push Notifications создан в Apple Developer
- [ ] APNs ключ создан и скачан (.p8 файл)
- [ ] iOS приложение добавлено в Firebase Console
- [ ] APNs ключ загружен в Firebase Console
- [ ] GoogleService-Info.plist добавлен в проект
- [ ] AppDelegate.swift обновлен
- [ ] aps-environment настроен в entitlements
- [ ] Pod dependencies установлены
- [ ] Приложение тестируется на реальном устройстве
- [ ] FCM токен генерируется
- [ ] Тестовое уведомление отправлено и получено

### 9. Bundle ID для проекта

**Текущий Bundle ID:** проверьте в `ios/Runner.xcodeproj`

```bash
# Проверить Bundle ID
grep -r "PRODUCT_BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/
```

### 10. Дополнительные возможности

#### Расширенные уведомления:
- Rich notifications (изображения, видео)
- Actionable notifications (кнопки)
- Custom sounds

#### Аналитика:
- Отслеживание доставки уведомлений
- Метрики открытий
- A/B тестирование уведомлений

---

**Важно:** iOS уведомления работают только на реальных устройствах, не на симуляторе!
