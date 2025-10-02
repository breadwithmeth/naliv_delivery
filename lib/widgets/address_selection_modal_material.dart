import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/api.dart';
import '../utils/location_service.dart';
import '../utils/address_storage_service.dart';
import '../pages/map_address_page.dart';

/// Модальное окно для выбора адреса при первом запуске (Material Design)
class AddressSelectionModal extends StatefulWidget {
  final Function(Map<String, dynamic>) onAddressSelected;

  const AddressSelectionModal({
    super.key,
    required this.onAddressSelected,
  });

  @override
  State<AddressSelectionModal> createState() => _AddressSelectionModalState();
}

class _AddressSelectionModalState extends State<AddressSelectionModal> {
  bool _isLoadingLocation = false;
  String _locationAttemptStatus = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Определяет адрес по геолокации
  Future<void> _detectLocationAddress() async {
    setState(() {
      _isLoadingLocation = true;
      _locationAttemptStatus = 'Проверяем разрешения...';
    });

    try {
      print('🌍 Начинаем определение адреса по геолокации');

      final locationService = LocationService.instance;

      // Сначала явно проверяем и запрашиваем разрешения
      print('🔐 Проверяем разрешения на геолокацию...');
      final permissionResult =
          await locationService.checkAndRequestPermissions();

      if (!permissionResult.success) {
        print('❌ Разрешения не получены: ${permissionResult.message}');
        if (permissionResult.needsSettingsRedirect) {
          _showLocationErrorDialog();
        } else {
          // Если разрешение просто отклонено, показываем обычную ошибку
          _showErrorDialog(
              'Необходимо разрешение на доступ к геолокации для определения адреса.');
        }
        return;
      }

      print('✅ Разрешения получены, начинаем определение координат...');

      // Проверяем доступность GPS сервисов
      final isServiceEnabled = await locationService.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        print('❌ Службы геолокации отключены');
        _showLocationErrorDialog();
        return;
      }

      setState(() {
        _locationAttemptStatus = 'Попытка 1/3 - высокая точность...';
      });

      // Первая попытка - быстрая проверка с высокой точностью
      print('🎯 Первая попытка - высокая точность...');
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
        print('✅ Координаты (high): $position');
      } catch (e) {
        print('⚠️ Первая попытка неудачна: $e');
      }

      // Вторая попытка
      if (position == null) {
        if (mounted) {
          setState(() {
            _locationAttemptStatus = 'Попытка 2/3 - средняя точность...';
          });
        }
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 10),
          );
          print('✅ Координаты (medium): $position');
        } catch (e) {
          print('⚠️ Вторая попытка неудачна: $e');
        }
      }

      // Третья попытка
      if (position == null) {
        if (mounted) {
          setState(() {
            _locationAttemptStatus = 'Попытка 3/3 - низкая точность...';
          });
        }
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 12),
          );
          print('✅ Координаты (low): $position');
        } catch (e) {
          print('❌ Третья попытка неудачна: $e');
        }
      }

      if (position == null) {
        _showErrorDialog(
            'Не удалось получить координаты. Выберите адрес вручную.');
        return;
      }

      // Обратное геокодирование
      final addressData = await ApiService.searchAddresses(
        lat: position.latitude,
        lon: position.longitude,
      );

      if (addressData != null && addressData.isNotEmpty) {
        final selectedAddress = {
          'address': addressData.first['name'] ??
              addressData.first['description'] ??
              'Неизвестный адрес',
          'lat': position.latitude,
          'lon': position.longitude,
          'accuracy': position.accuracy,
          'source': 'geolocation',
          'timestamp': DateTime.now().toIso8601String(),
        };

        print('💾 Сохраняем базовый адрес: ${selectedAddress['address']}');
        if (mounted) {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MapAddressPage(
              initialLat: selectedAddress['lat'],
              initialLon: selectedAddress['lon'],
              onAddressSelected: widget.onAddressSelected,
            ),
          ));
        }
      } else {
        print('❌ API не вернул данные об адресе');
        _showErrorDialog(
            'Не удалось определить адрес по координатам. Попробуйте выбрать адрес вручную.');
      }
    } catch (e) {
      print('❌ Ошибка при определении адреса: $e');

      // Дополнительная информация об ошибке
      if (e.toString().contains('permission') ||
          e.toString().contains('PERMISSION') ||
          e.toString().contains('denied')) {
        _showLocationErrorDialog();
      } else {
        _showErrorDialog(
            'Ошибка при определении местоположения: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _locationAttemptStatus = '';
        });
      }
    }
  }

  /// Показывает диалог ошибки
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ошибка'),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// Показывает диалог ошибки геолокации с предложением открыть настройки
  void _showLocationErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Геолокация недоступна'),
        content: const Text(
          'Для определения адреса по вашему местоположению необходимо:\n\n'
          '1. Разрешить доступ к геолокации в настройках\n'
          '2. Включить службы геолокации на устройстве\n'
          '3. Убедиться в наличии GPS-сигнала\n'
          '4. Выйти на открытое пространство\n\n'
          'Попробуйте еще раз или выберите адрес вручную.',
        ),
        actions: [
          TextButton(
            child: const Text('Попробовать еще раз'),
            onPressed: () {
              Navigator.of(context).pop();
              // Пробуем еще раз
              _detectLocationAddress();
            },
          ),
          TextButton(
            child: const Text('Настройки'),
            onPressed: () async {
              Navigator.of(context).pop();
              await LocationService.instance.openAppSettings();
              // Небольшая пауза после возврата из настроек
              await Future.delayed(const Duration(seconds: 2));
              if (mounted) {
                _detectLocationAddress();
              }
            },
          ),
          TextButton(
            child: const Text('Выбрать вручную'),
            onPressed: () async {
              Navigator.of(context).pop();
              // Открываем MapAddressPage для ручного выбора адреса
              // Используем координаты Алматы по умолчанию
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => MapAddressPage(
                  initialLat: 43.2220,
                  initialLon: 76.8512,
                  onAddressSelected: widget.onAddressSelected,
                ),
              ));
            },
          ),
        ],
      ),
    );
  }

  /// Строит подзаголовок с деталями адреса
  Widget? _buildAddressSubtitle(Map<String, dynamic> addr) {
    final List<String> details = [];

    if (addr['apartment']?.toString().isNotEmpty == true) {
      details.add('кв. ${addr['apartment']}');
    }
    if (addr['entrance']?.toString().isNotEmpty == true) {
      details.add('подъезд ${addr['entrance']}');
    }
    if (addr['floor']?.toString().isNotEmpty == true) {
      details.add('этаж ${addr['floor']}');
    }
    if (addr['comment']?.toString().isNotEmpty == true) {
      details.add('${addr['comment']}');
    }

    if (details.isEmpty) return null;

    return Text(
      details.join(', '),
      style: TextStyle(
        color: Colors.grey[600],
        fontSize: 12,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          // Заголовок
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[300]!,
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Выберите адрес доставки',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          // Кнопка геолокации
          Container(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoadingLocation ? null : _detectLocationAddress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  foregroundColor: Colors.blue,
                  elevation: 0,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                ),
                child: _isLoadingLocation
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.blue),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text('Определяем местоположение...'),
                            ],
                          ),
                          if (_locationAttemptStatus.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              _locationAttemptStatus,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade600,
                              ),
                            ),
                          ],
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.my_location,
                            color: Colors.blue,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Определить по геолокации',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          // Сохраненные адреса (история)
          FutureBuilder<List<Map<String, dynamic>>>(
            future: AddressStorageService.getAddressHistory(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Text(
                        'Сохранённые адреса',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ...snapshot.data!.map((addr) => ListTile(
                          leading: Icon(Icons.history, color: Colors.blue),
                          title: Text(addr['name'] ?? ''),
                          subtitle: _buildAddressSubtitle(addr),
                          onTap: () {
                            // Передаем все сохраненные детали адреса
                            final fullAddress = {
                              'address': addr['name'],
                              'lat': addr['point']['lat'],
                              'lon': addr['point']['lon'],
                              'source': 'history',
                              'timestamp': DateTime.now().toIso8601String(),
                            };

                            // Добавляем детали адреса если они есть
                            if (addr['apartment']?.toString().isNotEmpty ==
                                true) {
                              fullAddress['apartment'] = addr['apartment'];
                            }
                            if (addr['entrance']?.toString().isNotEmpty ==
                                true) {
                              fullAddress['entrance'] = addr['entrance'];
                            }
                            if (addr['floor']?.toString().isNotEmpty == true) {
                              fullAddress['floor'] = addr['floor'];
                            }
                            if (addr['comment']?.toString().isNotEmpty ==
                                true) {
                              fullAddress['comment'] = addr['comment'];
                            }

                            widget.onAddressSelected(fullAddress);
                          },
                        )),
                  ],
                );
              }
              return SizedBox.shrink();
            },
          ),

          // Разделитель "ИЛИ"

          // Результаты поиска
        ],
      ),
    );
  }
}

/// Вспомогательный класс для показа модального окна
class AddressSelectionModalHelper {
  static Future<Map<String, dynamic>?> show(BuildContext context) async {
    Map<String, dynamic>? pickedAddress;
    // Показываем модальное нижнее меню для выбора адреса. Не передаём Map напрямую в pop,
    // чтобы избежать конфликтов с маршрутами, ожидающими bool?/null.
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: AddressSelectionModal(
          onAddressSelected: (address) {
            pickedAddress = address;
            // Закрываем лист без результата (result = null)
            if (Navigator.of(ctx).canPop()) {
              Navigator.of(ctx).pop();
            }
          },
        ),
      ),
    );
    return pickedAddress;
  }
}
