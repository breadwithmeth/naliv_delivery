import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Сервис для работы с геолокацией
class LocationService {
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();
  LocationService._();

  /// Текущая позиция пользователя
  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  /// Статус разрешения на геолокацию
  LocationPermission? _permission;
  LocationPermission? get permission => _permission;

  /// Проверяет доступность сервисов геолокации
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Получает текущий статус разрешения
  Future<LocationPermission> checkPermission() async {
    _permission = await Geolocator.checkPermission();
    return _permission!;
  }

  /// Запрашивает разрешение на использование геолокации
  Future<LocationPermission> requestPermission() async {
    // Сначала проверяем текущий статус
    _permission = await Geolocator.checkPermission();

    if (_permission == LocationPermission.denied) {
      // Запрашиваем разрешение
      _permission = await Geolocator.requestPermission();
    }

    return _permission!;
  }

  /// Запрашивает разрешение через permission_handler (для более детального контроля)
  Future<PermissionStatus> requestLocationPermissionDetailed() async {
    // Проверяем текущий статус
    PermissionStatus status = await Permission.location.status;

    if (status.isDenied) {
      // Запрашиваем разрешение
      status = await Permission.location.request();
    }

    return status;
  }

  /// Проверяет и запрашивает все необходимые разрешения
  Future<LocationPermissionResult> checkAndRequestPermissions() async {
    try {
      // Проверяем доступность сервисов геолокации
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationPermissionResult(
          success: false,
          message:
              'Сервисы геолокации отключены. Включите GPS в настройках устройства.',
          permissionStatus: LocationPermission.denied,
        );
      }

      // Проверяем и запрашиваем разрешение
      LocationPermission permission = await requestPermission();

      switch (permission) {
        case LocationPermission.denied:
          return LocationPermissionResult(
            success: false,
            message: 'Разрешение на использование геолокации отклонено.',
            permissionStatus: permission,
          );

        case LocationPermission.deniedForever:
          return LocationPermissionResult(
            success: false,
            message:
                'Разрешение на геолокацию отклонено навсегда. Разрешите доступ в настройках приложения.',
            permissionStatus: permission,
            needsSettingsRedirect: true,
          );

        case LocationPermission.whileInUse:
        case LocationPermission.always:
          return LocationPermissionResult(
            success: true,
            message: 'Разрешение на геолокацию получено.',
            permissionStatus: permission,
          );

        default:
          return LocationPermissionResult(
            success: false,
            message: 'Неизвестный статус разрешения.',
            permissionStatus: permission,
          );
      }
    } catch (e) {
      return LocationPermissionResult(
        success: false,
        message: 'Ошибка при запросе разрешения: $e',
        permissionStatus: LocationPermission.denied,
      );
    }
  }

  /// Получает текущую позицию пользователя
  Future<Position?> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration? timeLimit,
  }) async {
    try {
      // Проверяем разрешения
      LocationPermissionResult permissionResult =
          await checkAndRequestPermissions();
      if (!permissionResult.success) {
        print('Не удалось получить разрешение: ${permissionResult.message}');
        return null;
      }

      // Получаем позицию
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: timeLimit,
      );

      return _currentPosition;
    } catch (e) {
      print('Ошибка при получении геолокации: $e');
      return null;
    }
  }

  /// Вычисляет расстояние между двумя точками в метрах
  double calculateDistance(double startLatitude, double startLongitude,
      double endLatitude, double endLongitude) {
    return Geolocator.distanceBetween(
        startLatitude, startLongitude, endLatitude, endLongitude);
  }

  /// Отслеживает позицию пользователя (стрим)
  Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10,
  }) {
    LocationSettings locationSettings = LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  /// Открывает настройки приложения для изменения разрешений
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Открывает настройки геолокации устройства
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }
}

/// Результат запроса разрешения на геолокацию
class LocationPermissionResult {
  final bool success;
  final String message;
  final LocationPermission permissionStatus;
  final bool needsSettingsRedirect;

  LocationPermissionResult({
    required this.success,
    required this.message,
    required this.permissionStatus,
    this.needsSettingsRedirect = false,
  });

  @override
  String toString() {
    return 'LocationPermissionResult{success: $success, message: $message, status: $permissionStatus}';
  }
}

/// Виджет для отображения диалога запроса разрешения
class LocationPermissionDialog {
  /// Показывает диалог с объяснением необходимости разрешения
  static Future<bool> showPermissionExplanation(BuildContext context) async {
    bool? result = await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Доступ к геолокации'),
        content: const Text(
          'Приложению необходим доступ к вашему местоположению для:\n\n'
          '• Определения ближайших магазинов\n'
          '• Расчета стоимости доставки\n'
          '• Улучшения качества сервиса',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Отказаться'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Разрешить'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Показывает диалог с ошибкой и предложением перейти в настройки
  static Future<bool> showPermissionDeniedDialog(
      BuildContext context, String message,
      {bool canOpenSettings = true}) async {
    bool? result = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Доступ к геолокации'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('Закрыть'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          if (canOpenSettings)
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Настройки'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Показывает диалог с информацией о текущем местоположении
  static void showLocationInfo(BuildContext context, Position position) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Ваше местоположение'),
        content: Text(
          'Широта: ${position.latitude.toStringAsFixed(6)}\n'
          'Долгота: ${position.longitude.toStringAsFixed(6)}\n'
          'Точность: ${position.accuracy.toStringAsFixed(1)} м',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Закрыть'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// Миксин для упрощения работы с геолокацией в виджетах
mixin LocationMixin<T extends StatefulWidget> on State<T> {
  LocationService get locationService => LocationService.instance;
  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  /// Запрашивает разрешение и получает текущую позицию
  Future<bool> requestLocationAndGetPosition() async {
    // Показываем объяснение пользователю
    bool userAccepted =
        await LocationPermissionDialog.showPermissionExplanation(context);
    if (!userAccepted) {
      return false;
    }

    // Проверяем и запрашиваем разрешения
    LocationPermissionResult result =
        await locationService.checkAndRequestPermissions();

    if (!result.success) {
      // Показываем диалог с ошибкой
      bool openSettings =
          await LocationPermissionDialog.showPermissionDeniedDialog(
        context,
        result.message,
        canOpenSettings: result.needsSettingsRedirect,
      );

      if (openSettings && result.needsSettingsRedirect) {
        await locationService.openAppSettings();
      }

      return false;
    }

    // Получаем текущую позицию
    _currentPosition = await locationService.getCurrentPosition();

    if (_currentPosition != null) {
      setState(() {});
      return true;
    }

    return false;
  }

  /// Показывает информацию о текущем местоположении
  void showCurrentLocationInfo() {
    if (_currentPosition != null) {
      LocationPermissionDialog.showLocationInfo(context, _currentPosition!);
    }
  }
}
