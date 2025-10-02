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
  bool _isSearching = false;
  String _searchQuery = '';
  String _locationAttemptStatus = '';
  List<Map<String, dynamic>> _searchResults = [];
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
        print(position);
      } catch (e) {
        print('⚠️ Первая попытка неудачна: $e');
      }

      // Если первая попытка не удалась, пробуем с меньшей точностью
      if (position == null && mounted) {
        setState(() {
          _locationAttemptStatus = 'Попытка 2/3 - средняя точность...';
        });
        print('⚡ Первая попытка не удалась, пробуем со средней точностью...');
        await Future.delayed(const Duration(milliseconds: 500));

        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 12),
          );
        } catch (e) {
          print('⚠️ Вторая попытка неудачна: $e');
        }
      }

      // Если и вторая попытка не удалась, пробуем с низкой точностью
      if (position == null && mounted) {
        setState(() {
          _locationAttemptStatus = 'Попытка 3/3 - низкая точность...';
        });
        print('🔄 Вторая попытка не удалась, пробуем с низкой точностью...');
        await Future.delayed(const Duration(milliseconds: 500));

        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 15),
          );
        } catch (e) {
          print('⚠️ Третья попытка неудачна: $e');
        }
      }

      if (position == null) {
        print('❌ Не удалось получить координаты после трех попыток');
        _showLocationErrorDialog();
        return;
      }

      setState(() {
        _locationAttemptStatus = 'Получаем адрес...';
      });

      print(
          '📍 Координаты получены: ${position.latitude}, ${position.longitude}');
      print('📏 Точность: ${position.accuracy} метров');

      // Получаем адрес по координатам через API
      final addressData = await ApiService.searchAddresses(
        lat: position.latitude,
        lon: position.longitude,
      );

      if (addressData != null && addressData.isNotEmpty) {
        print('🏠 Адрес получен: ${addressData.first}');

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
          // Уточнение на карте с возможностью добавления деталей
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MapAddressPage(
              initialLat: selectedAddress['lat'],
              initialLon: selectedAddress['lon'],
              onAddressSelected: widget.onAddressSelected,
            ),
          ));
          // Callback already called by MapAddressPage via widget.onAddressSelected
          // MapAddressPage сам сохранит адрес с деталями в AddressStorageService
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

  /// Выполняет поиск адресов
  Future<void> _searchAddresses(String query) async {
    if (query.length < 3) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    try {
      print('🔍 Поиск адресов: $query');

      final results = await ApiService.searchAddresses(query: query);
      if (results != null && results.isNotEmpty) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(results);
          _isSearching = false;
        });
        print('✅ Найдено ${_searchResults.length} адресов');
        print(_searchResults);
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
        print('🔍 Адреса не найдены');
      }
    } catch (e) {
      print('❌ Ошибка поиска: $e');
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      _showErrorDialog('Ошибка поиска: ${e.toString()}');
    }
  }

  /// Выбирает адрес из результатов поиска
  Future<void> _selectSearchResult(Map<String, dynamic> address) async {
    try {
      // Создаем объект адреса для сохранения
      final selectedAddress = {
        'address':
            address['name'] ?? address['description'] ?? 'Неизвестный адрес',
        'lat': address['point']?['lat'] ?? address['lat'],
        'lon': address['point']?['lon'] ?? address['lon'],
        'source': 'search',
        'timestamp': DateTime.now().toIso8601String(),
      };

      print('🏠 Выбран адрес: $selectedAddress');

      // Запрашиваем дополнительные детали и закрываем с полным адресом
      if (mounted) {
        final extra = await _askAddressDetails(selectedAddress);
        final full =
            (extra != null) ? {...selectedAddress, ...extra} : selectedAddress;

        // Сохраняем адрес с деталями
        await AddressStorageService.saveSelectedAddress(full);

        // Уточнение на карте
        final mapRes = await Navigator.of(context)
            .push<Map<String, dynamic>>(MaterialPageRoute(
          builder: (_) => MapAddressPage(
            initialLat: full['lat'],
            initialLon: full['lon'],
            onAddressSelected: widget.onAddressSelected,
          ),
        ));
        if (mapRes != null) {
          full['lat'] = mapRes['lat'];
          full['lon'] = mapRes['lon'];
          // Пересохраняем с обновленными координатами
          await AddressStorageService.saveSelectedAddress(full);
        }

        // Добавляем адрес в историю поиска с полными данными
        final historyEntry = {
          'name': full['address'],
          'point': {'lat': full['lat'], 'lon': full['lon']},
        };

        // Добавляем детали если они есть
        if (full['apartment']?.toString().isNotEmpty == true) {
          historyEntry['apartment'] = full['apartment'];
        }
        if (full['entrance']?.toString().isNotEmpty == true) {
          historyEntry['entrance'] = full['entrance'];
        }
        if (full['floor']?.toString().isNotEmpty == true) {
          historyEntry['floor'] = full['floor'];
        }
        if (full['other']?.toString().isNotEmpty == true) {
          historyEntry['comment'] = full['other'];
        }

        await AddressStorageService.addToAddressHistory(historyEntry);

        widget.onAddressSelected(full);
      }
    } catch (e) {
      print('❌ Ошибка при выборе адреса: $e');
      _showErrorDialog('Ошибка при сохранении адреса: ${e.toString()}');
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

  /// Запрашивает у пользователя дополнительные детали адреса
  Future<Map<String, String>?> _askAddressDetails(
      Map<String, dynamic> address) async {
    String selectedType = 'Квартира';
    final types = ['Квартира', 'Офис', 'Дом', 'Другое'];
    final apartmentController = TextEditingController();
    final entranceController = TextEditingController();
    final floorController = TextEditingController();
    final otherController = TextEditingController();

    final formKey = GlobalKey<FormState>();
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(ctx).dialogBackgroundColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Уточните детали адреса',
                  style: Theme.of(ctx).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        items: types
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setState(() => selectedType = v!),
                        decoration: const InputDecoration(
                          labelText: 'Тип адреса',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: apartmentController,
                        decoration: const InputDecoration(
                          labelText: 'Квартира',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: entranceController,
                        decoration: const InputDecoration(
                          labelText: 'Подъезд',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: floorController,
                        decoration: const InputDecoration(
                          labelText: 'Этаж',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: otherController,
                        decoration: const InputDecoration(
                          labelText: 'Комментарий',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(null),
                      child: const Text('Отмена'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState?.validate() ?? true) {
                          Navigator.of(ctx).pop({
                            'addressType': selectedType,
                            'apartment': apartmentController.text.trim(),
                            'entrance': entranceController.text.trim(),
                            'floor': floorController.text.trim(),
                            'other': otherController.text.trim(),
                          });
                        }
                      },
                      child: const Text('Сохранить'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return result;
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
    // Показываем модальное нижнее меню для выбора адреса
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: AddressSelectionModal(
          onAddressSelected: (address) {
            Navigator.of(ctx).pop(address);
          },
        ),
      ),
    );
    return result;
  }
}
