# API для получения бизнесов

Этот файл содержит функции для работы с API получения списка бизнесов.

## Эндпоинт

```
GET http://localhost:3000/businesses
```

## Параметры запроса

| Параметр | Тип | Обязательный | По умолчанию | Описание |
|----------|-----|--------------|--------------|----------|
| `page` | number | Нет | 1 | Номер страницы |
| `limit` | number | Нет | 10 | Количество элементов на странице |

## Формат ответа

```json
{
  "success": true,
  "data": {
    "businesses": [
      {
        "business_id": 1,
        "name": "Название магазина",
        "address": "Адрес магазина", 
        "description": "Описание",
        "logo": "logo_url",
        "city_id": 1
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 10,
      "total": 50,
      "totalPages": 5
    }
  }
}
```

## Использование

### Импорт

```dart
import 'package:naliv_delivery/utils/api.dart';
```

### Основные функции

#### 1. Получение бизнесов с пагинацией

```dart
// Получить первую страницу с 10 элементами (по умолчанию)
final data = await ApiService.getBusinesses();

// Получить конкретную страницу
final data = await ApiService.getBusinesses(page: 2, limit: 5);

if (data != null) {
  final businesses = data['businesses']; // List<Map<String, dynamic>>
  final pagination = data['pagination']; // Map<String, dynamic>
  
  print('Загружено ${businesses.length} бизнесов');
  print('Страница ${pagination['page']} из ${pagination['totalPages']}');
}
```

#### 2. Получение всех бизнесов

```dart
final businesses = await ApiService.getAllBusinesses();

if (businesses != null) {
  print('Всего бизнесов: ${businesses.length}');
  for (var business in businesses) {
    print('${business['name']} - ${business['address']}');
  }
}
```

#### 3. Получение бизнеса по ID

```dart
final business = await ApiService.getBusinessById(1);

if (business != null) {
  print('Найден бизнес: ${business['name']}');
}
```

### Работа с моделями данных

#### Класс Business

```dart
// Создание из JSON
final business = Business.fromJson({
  'business_id': 1,
  'name': 'Магазин',
  'address': 'Адрес',
  'description': 'Описание',
  'logo': 'logo.jpg',
  'city_id': 1
});

// Преобразование в JSON
final json = business.toJson();
```

#### Класс BusinessesResponse

```dart
// Парсинг полного ответа API
final response = BusinessesResponse.fromJson(apiData);

print('Количество бизнесов: ${response.businesses.length}');
print('Текущая страница: ${response.pagination.page}');
```

### Обработка ошибок

Все функции API возвращают `null` в случае ошибки и выводят информацию об ошибке в консоль:

```dart
final data = await ApiService.getBusinesses();

if (data == null) {
  // Обработка ошибки
  print('Не удалось загрузить данные');
  // Проверьте консоль для подробной информации об ошибке
}
```

### Типы ошибок

1. **Network Error** - проблемы с сетью или недоступность сервера
2. **HTTP Error** - сервер вернул код ошибки (например, 404, 500)
3. **API Error** - сервер вернул `success: false`

## Примеры

### Полный пример загрузки и отображения бизнесов

```dart
Future<void> loadBusinesses() async {
  try {
    final data = await ApiService.getBusinesses(page: 1, limit: 20);
    
    if (data != null) {
      final businesses = data['businesses'];
      final pagination = data['pagination'];
      
      setState(() {
        _businesses = List<Map<String, dynamic>>.from(businesses);
        _isLoading = false;
      });
      
      print('Загружено ${businesses.length} бизнесов');
      print('Пагинация: ${pagination['page']}/${pagination['totalPages']}');
    } else {
      setState(() {
        _isLoading = false;
      });
      // Показать пользователю ошибку
      showErrorDialog('Не удалось загрузить список магазинов');
    }
  } catch (e) {
    print('Ошибка: $e');
    setState(() {
      _isLoading = false;
    });
  }
}
```

### Пример с использованием моделей

```dart
Future<void> loadBusinessesWithModels() async {
  final data = await ApiService.getBusinesses();
  
  if (data != null) {
    // Создаем типизированные объекты
    final response = BusinessesResponse.fromJson(data);
    
    // Теперь у нас есть типизированный доступ к данным
    for (Business business in response.businesses) {
      print('ID: ${business.businessId}');
      print('Название: ${business.name}');
      print('Адрес: ${business.address}');
      print('---');
    }
    
    print('Пагинация:');
    print('Страница: ${response.pagination.page}');
    print('Всего страниц: ${response.pagination.totalPages}');
    print('Общее количество: ${response.pagination.total}');
  }
}
```

## Тестирование

Для тестирования API используйте файл `api_example.dart`:

```dart
import 'package:naliv_delivery/utils/api_example.dart';

// Запуск полного примера
main();

// Или только тестирование
testApi();
```

## Требования

1. Сервер должен быть запущен на `http://localhost:3000`
2. Эндпоинт `/businesses` должен быть доступен
3. Сервер должен возвращать JSON в указанном формате
4. В проекте должен быть подключен пакет `http`

## Настройка

Если ваш API находится на другом адресе, измените константу `baseUrl` в классе `ApiService`:

```dart
class ApiService {
  static const String baseUrl = 'http://your-api-server.com:3000';
  // ...
}
```
