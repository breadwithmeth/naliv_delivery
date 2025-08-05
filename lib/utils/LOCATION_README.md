# Сервис геолокации

Этот файл содержит полный сервис для работы с геолокацией в Flutter приложении.

## Возможности

- ✅ Запрос разрешений на геолокацию
- ✅ Получение текущих координат
- ✅ Отслеживание изменения позиции (стрим)
- ✅ Вычисление расстояния между точками
- ✅ Проверка доступности GPS сервисов
- ✅ Готовые диалоги для пользователя
- ✅ Миксин для упрощения использования в виджетах

## Подключенные пакеты

В `pubspec.yaml` уже подключены:
```yaml
dependencies:
  geolocator: ^12.0.0
  permission_handler: ^11.3.0
  location: ^5.0.3
```

## Разрешения

### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Приложение использует данные GPS для определения ближайших магазинов</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Приложение использует данные GPS для определения ближайших магазинов</string>
```

## Основные классы

### 1. LocationService (Singleton)

Основной сервис для работы с геолокацией.

```dart
LocationService locationService = LocationService.instance;
```

#### Методы:

**Проверка разрешений:**
```dart
// Проверить текущий статус
LocationPermission permission = await locationService.checkPermission();

// Запросить разрешение
LocationPermission permission = await locationService.requestPermission();

// Комплексная проверка с результатом
LocationPermissionResult result = await locationService.checkAndRequestPermissions();
```

**Получение координат:**
```dart
// Текущая позиция
Position? position = await locationService.getCurrentPosition();

// С настройками точности
Position? position = await locationService.getCurrentPosition(
  accuracy: LocationAccuracy.high,
  timeLimit: Duration(seconds: 10),
);
```

**Отслеживание позиции:**
```dart
Stream<Position> positionStream = locationService.getPositionStream(
  accuracy: LocationAccuracy.high,
  distanceFilter: 10, // Обновлять при изменении на 10+ метров
);

positionStream.listen((Position position) {
  print('Новая позиция: ${position.latitude}, ${position.longitude}');
});
```

**Утилиты:**
```dart
// Вычисление расстояния между точками
double distance = locationService.calculateDistance(
  55.7558, 37.6176, // Москва
  59.9311, 30.3609, // СПб
);

// Проверка доступности GPS
bool isEnabled = await locationService.isLocationServiceEnabled();

// Открытие настроек
await locationService.openAppSettings();
await locationService.openLocationSettings();
```

### 2. LocationPermissionResult

Класс для результата запроса разрешений:

```dart
class LocationPermissionResult {
  final bool success;                    // Успешно ли получено разрешение
  final String message;                  // Сообщение для пользователя
  final LocationPermission permissionStatus; // Статус разрешения
  final bool needsSettingsRedirect;     // Нужно ли перейти в настройки
}
```

### 3. LocationPermissionDialog

Готовые диалоги для взаимодействия с пользователем:

```dart
// Объяснение зачем нужна геолокация
bool accepted = await LocationPermissionDialog.showPermissionExplanation(context);

// Диалог об ошибке с предложением перейти в настройки
bool openSettings = await LocationPermissionDialog.showPermissionDeniedDialog(
  context, 
  'Разрешение отклонено',
  canOpenSettings: true,
);

// Показать информацию о координатах
LocationPermissionDialog.showLocationInfo(context, position);
```

### 4. LocationMixin

Миксин для упрощения работы с геолокацией в виджетах:

```dart
class MyPage extends StatefulWidget {
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> with LocationMixin {
  
  void _getLocation() async {
    // Автоматически показывает диалоги и обрабатывает ошибки
    bool success = await requestLocationAndGetPosition();
    
    if (success && currentPosition != null) {
      print('Координаты: ${currentPosition!.latitude}, ${currentPosition!.longitude}');
      showCurrentLocationInfo(); // Показать диалог с координатами
    }
  }
}
```

## Примеры использования

### Простое получение координат

```dart
Future<void> getLocation() async {
  LocationService locationService = LocationService.instance;
  
  // Проверяем и запрашиваем разрешения
  LocationPermissionResult result = await locationService.checkAndRequestPermissions();
  
  if (result.success) {
    // Получаем координаты
    Position? position = await locationService.getCurrentPosition();
    
    if (position != null) {
      print('Широта: ${position.latitude}');
      print('Долгота: ${position.longitude}');
      print('Точность: ${position.accuracy} м');
    }
  } else {
    print('Ошибка: ${result.message}');
  }
}
```

### С обработкой ошибок и диалогами

```dart
class LocationPage extends StatefulWidget {
  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> with LocationMixin {
  Position? _position;
  
  void _requestLocation() async {
    bool success = await requestLocationAndGetPosition();
    
    if (success && currentPosition != null) {
      setState(() {
        _position = currentPosition;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Center(
        child: Column(
          children: [
            if (_position != null)
              Text('Координаты: ${_position!.latitude}, ${_position!.longitude}'),
            
            CupertinoButton.filled(
              onPressed: _requestLocation,
              child: Text('Получить геолокацию'),
            ),
            
            if (_position != null)
              CupertinoButton(
                onPressed: showCurrentLocationInfo,
                child: Text('Показать детали'),
              ),
          ],
        ),
      ),
    );
  }
}
```

### Отслеживание позиции

```dart
class TrackingPage extends StatefulWidget {
  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  StreamSubscription<Position>? _positionSubscription;
  Position? _currentPosition;
  
  void _startTracking() async {
    LocationService locationService = LocationService.instance;
    
    // Проверяем разрешения
    LocationPermissionResult result = await locationService.checkAndRequestPermissions();
    
    if (result.success) {
      // Запускаем отслеживание
      _positionSubscription = locationService.getPositionStream().listen(
        (Position position) {
          setState(() {
            _currentPosition = position;
          });
        },
        onError: (error) {
          print('Ошибка отслеживания: $error');
        },
      );
    }
  }
  
  void _stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }
  
  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }
}
```

### Вычисление расстояния до ближайшего магазина

```dart
Future<Map<String, dynamic>?> findNearestStore(Position userPosition, List<Map<String, dynamic>> stores) async {
  if (stores.isEmpty) return null;
  
  LocationService locationService = LocationService.instance;
  Map<String, dynamic>? nearestStore;
  double minDistance = double.infinity;
  
  for (var store in stores) {
    double? storeLat = store['latitude']?.toDouble();
    double? storeLng = store['longitude']?.toDouble();
    
    if (storeLat != null && storeLng != null) {
      double distance = locationService.calculateDistance(
        userPosition.latitude,
        userPosition.longitude,
        storeLat,
        storeLng,
      );
      
      if (distance < minDistance) {
        minDistance = distance;
        nearestStore = {
          ...store,
          'distance': distance,
        };
      }
    }
  }
  
  return nearestStore;
}
```

## Интеграция в главное приложение

В `main.dart` добавлено:

1. **Импорты:**
```dart
import 'package:naliv_delivery/utils/location_service.dart';
import 'package:geolocator/geolocator.dart';
```

2. **Миксин в главном виджете:**
```dart
class _MainState extends State<Main> with LocationMixin {
  Position? _userPosition;
  bool _isLoadingLocation = false;
  String _locationStatus = 'Геолокация не запрошена';
}
```

3. **Методы для работы с геолокацией:**
```dart
Future<void> _requestLocationPermission() async {
  bool success = await requestLocationAndGetPosition();
  if (success && currentPosition != null) {
    setState(() {
      _userPosition = currentPosition;
      _locationStatus = 'Геолокация получена';
    });
  }
}
```

4. **UI в разделе "Поиск"** с кнопками:
- Получить геолокацию
- Проверить разрешения
- Отображение координат

## Статусы разрешений

```dart
enum LocationPermission {
  denied,          // Разрешение отклонено
  deniedForever,   // Разрешение отклонено навсегда
  whileInUse,      // Разрешено при использовании приложения
  always,          // Разрешено всегда
}
```

## Обработка ошибок

### Типичные ошибки и решения:

1. **GPS отключен:**
```dart
bool serviceEnabled = await locationService.isLocationServiceEnabled();
if (!serviceEnabled) {
  // Предложить включить GPS
  await locationService.openLocationSettings();
}
```

2. **Разрешение отклонено навсегда:**
```dart
if (result.permissionStatus == LocationPermission.deniedForever) {
  // Предложить перейти в настройки
  await locationService.openAppSettings();
}
```

3. **Таймаут получения координат:**
```dart
Position? position = await locationService.getCurrentPosition(
  timeLimit: Duration(seconds: 10),
);
```

## Тестирование

Для тестирования создана демо-страница `LocationExamplePage` с:
- Кнопками для всех функций
- Отображением координат
- Информационными сообщениями
- Обработкой всех возможных состояний

Запустите приложение и перейдите в раздел "Поиск" для тестирования функциональности.

## Производительность

- Сервис использует паттерн Singleton
- Кеширование последней полученной позиции
- Настраиваемая точность и фильтрация по расстоянию
- Автоматическая отмена запросов при превышении таймаута

## Безопасность

- Запрос разрешений только при необходимости
- Объяснение пользователю зачем нужна геолокация
- Graceful обработка отказа от разрешений
- Никакой передачи координат без согласия пользователя
