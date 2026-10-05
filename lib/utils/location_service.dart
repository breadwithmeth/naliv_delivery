import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Сервис для работы с геолокацией
class LocationService {
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();
  LocationService._();

  static const double autoAcceptAccuracyMeters = 200;
  static const double manualConfirmationAccuracyMeters = 1000;

  bool get isIosBrowserLocationFlow =>
      kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  String browserLocationSettingsInstructions(
      {String browserLabel = 'Safari или Chrome'}) {
    return 'На iPhone доступ к геолокации часто нужно включить для самого браузера. Откройте Настройки > Конфиденциальность и безопасность > Службы геолокации > $browserLabel и выберите «При использовании приложения». После этого вернитесь и нажмите кнопку геолокации еще раз.';
  }

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
              'Геолокация сейчас выключена. Если хотите, можно включить её в настройках устройства. Без неё тоже можно продолжить.',
          permissionStatus: LocationPermission.denied,
        );
      }

      // Проверяем и запрашиваем разрешение
      LocationPermission permission = await requestPermission();

      switch (permission) {
        case LocationPermission.denied:
          final deniedMessage = isIosBrowserLocationFlow
              ? browserLocationSettingsInstructions()
              : 'Без доступа к геолокации тоже можно продолжить. Город можно выбрать вручную, а адрес указать позже при оформлении заказа.';
          return LocationPermissionResult(
            success: false,
            message: deniedMessage,
            permissionStatus: permission,
          );

        case LocationPermission.deniedForever:
          final deniedForeverMessage = isIosBrowserLocationFlow
              ? browserLocationSettingsInstructions()
              : 'Доступ к геолокации отключён для приложения. Если захотите, его можно вернуть в настройках. Сейчас можно продолжить и без него.';
          return LocationPermissionResult(
            success: false,
            message: deniedForeverMessage,
            permissionStatus: permission,
            needsSettingsRedirect: !isIosBrowserLocationFlow,
          );

        case LocationPermission.whileInUse:
        case LocationPermission.always:
          return LocationPermissionResult(
            success: true,
            message:
                'Геолокация включена. Попробуем определить ваш город автоматически.',
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
        message:
            'Не получилось получить доступ к геолокации. Можно продолжить без неё и выбрать данные вручную.',
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
        debugPrint(
            'Не удалось получить разрешение: ${permissionResult.message}');
        return null;
      }

      // Получаем позицию
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: timeLimit,
      );

      return _currentPosition;
    } catch (e) {
      debugPrint('Ошибка при получении геолокации: $e');
      return null;
    }
  }

  bool isAccurateEnoughForAutoSelection(
    Position position, {
    double maxAccuracyMeters = autoAcceptAccuracyMeters,
  }) {
    return position.accuracy > 0 && position.accuracy <= maxAccuracyMeters;
  }

  bool requiresManualConfirmation(
    Position position, {
    double maxAccuracyMeters = manualConfirmationAccuracyMeters,
  }) {
    return position.accuracy <= 0 || position.accuracy > maxAccuracyMeters;
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
