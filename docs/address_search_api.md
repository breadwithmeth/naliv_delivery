# 📍 API поиска адресов через Яндекс.Карты

Этот документ описывает новые методы для поиска адресов в `ApiService`, которые интегрируются с Яндекс.Карты API через ваш сервер.

## 🔗 Endpoint

**Базовый URL:** `http://localhost:3000/api/addresses/search`

## 📋 Доступные методы

### 1. **Поиск по текстовому запросу**

#### `searchAddressByText(String query)`
Ищет адреса по текстовому запросу.

```dart
// Пример использования
final addresses = await ApiService.searchAddressByText('улица Пушкина 12');
if (addresses != null) {
  for (var address in addresses) {
    print('Найден адрес: ${address['name']}');
    print('Координаты: ${address['point']['lat']}, ${address['point']['lon']}');
  }
}
```

**Параметры:**
- `query` (String) - строка поиска

**Возвращает:** `Future<List<Map<String, dynamic>>?>`

### 2. **Поиск по координатам (обратное геокодирование)**

#### `searchAddressByCoordinates(double lat, double lon)`
Находит адрес по географическим координатам.

```dart
// Пример использования
final addresses = await ApiService.searchAddressByCoordinates(43.238293, 76.945465);
if (addresses != null) {
  for (var address in addresses) {
    print('Адрес: ${address['name']}');
    print('Расстояние: ${address['distance']}м');
  }
}
```

**Параметры:**
- `lat` (double) - широта (от -90 до 90)
- `lon` (double) - долгота (от -180 до 180)

**Возвращает:** `Future<List<Map<String, dynamic>>?>`

**Валидация:** Автоматически проверяет корректность координат.

### 3. **Универсальный поиск**

#### `searchAddresses({String? query, double? lat, double? lon})`
Универсальный метод, который автоматически определяет тип поиска.

```dart
// Поиск по тексту
final textResults = await ApiService.searchAddresses(query: 'Москва Красная площадь');

// Поиск по координатам  
final coordResults = await ApiService.searchAddresses(lat: 55.7558, lon: 37.6176);
```

**Параметры:**
- `query` (String?, опционально) - текстовый запрос
- `lat` (double?, опционально) - широта
- `lon` (double?, опционально) - долгота

**Возвращает:** `Future<List<Map<String, dynamic>>?>`

## 🎯 Типизированные методы (с моделями)

### 1. **Типизированный поиск по тексту**

#### `searchAddressesByText(String query)`
Возвращает типизированные объекты `Address`.

```dart
final addresses = await ApiService.searchAddressesByText('улица Пушкина 12');
if (addresses != null) {
  for (Address address in addresses) {
    print('Название: ${address.name}');
    print('Координаты: ${address.point.lat}, ${address.point.lon}');
    print('Описание: ${address.description}');
    print('Тип: ${address.kind}');
    print('Точность: ${address.precision}');
  }
}
```

### 2. **Типизированный поиск по координатам**

#### `searchAddressesByCoordinates(double lat, double lon)`
Возвращает типизированные объекты `Address`.

```dart
final addresses = await ApiService.searchAddressesByCoordinates(43.238293, 76.945465);
if (addresses != null) {
  for (Address address in addresses) {
    print('Адрес: ${address.name}');
    if (address.distance != null) {
      print('Расстояние: ${address.distance}м');
    }
  }
}
```

### 3. **Универсальный типизированный поиск**

#### `searchAddressesTyped({String? query, double? lat, double? lon})`
Универсальный типизированный метод.

```dart
// Поиск по тексту
final textResults = await ApiService.searchAddressesTyped(query: 'Москва');

// Поиск по координатам
final coordResults = await ApiService.searchAddressesTyped(lat: 55.7558, lon: 37.6176);
```

## 📊 Модели данных

### `Address`
Основная модель для адреса.

```dart
class Address {
  final String name;           // Полное название адреса
  final AddressPoint point;    // Координаты
  final String description;    // Описание (город, страна)
  final String kind;          // Тип объекта (house, street, etc.)
  final String precision;     // Точность поиска (exact, near, etc.)
  final double? distance;     // Расстояние в метрах (для поиска по координатам)
}
```

### `AddressPoint`  
Модель для координат.

```dart
class AddressPoint {
  final double lat;  // Широта
  final double lon;  // Долгота
}
```

## 🔧 Примеры интеграции

### В LocationService
```dart
// Получение адреса по текущим координатам пользователя
Future<String?> getCurrentAddressName() async {
  if (currentPosition != null) {
    final addresses = await ApiService.searchAddressesByCoordinates(
      currentPosition!.latitude, 
      currentPosition!.longitude
    );
    return addresses?.first.name;
  }
  return null;
}
```

### В UI компонентах
```dart
// Автокомплит для поиска адресов
class AddressSearchWidget extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return CupertinoSearchTextField(
      onChanged: (query) async {
        if (query.length > 2) {
          final addresses = await ApiService.searchAddressesByText(query);
          // Показать результаты в выпадающем списке
        }
      },
    );
  }
}
```

## ⚠️ Обработка ошибок

Все методы возвращают `null` в случае ошибки и выводят информацию в консоль:

- **Сетевые ошибки:** `Network Error: ...`
- **HTTP ошибки:** `HTTP Error: [код] - [сообщение]`
- **API ошибки:** `API Error: [сообщение из ответа]`
- **Валидация координат:** `Invalid latitude/longitude: ...`

## 🎯 Лучшие практики

1. **Проверяйте результат на null:**
   ```dart
   final addresses = await ApiService.searchAddressByText('запрос');
   if (addresses != null && addresses.isNotEmpty) {
     // Обрабатываем результаты
   }
   ```

2. **Используйте типизированные методы:**
   ```dart
   // Лучше
   final addresses = await ApiService.searchAddressesByText('запрос');
   
   // Чем
   final addresses = await ApiService.searchAddressByText('запрос');
   ```

3. **Кэшируйте результаты для часто используемых запросов**

4. **Устанавливайте таймауты для сетевых запросов в production**

## 📱 Готовые компоненты

Для быстрого старта используйте готовые примеры из `/utils/address_search_example.dart`:

```dart
// Запуск всех демонстраций
await AddressSearchExample.runAllDemos();

// Или отдельные методы
await AddressSearchExample.demonstrateTextSearch();
await AddressSearchExample.demonstrateCoordinateSearch();
```
