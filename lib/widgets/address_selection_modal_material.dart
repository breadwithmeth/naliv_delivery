import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:naliv_delivery/shared/app_theme.dart';
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
    if (!mounted) return;
    setState(() {
      _isLoadingLocation = true;
      _locationAttemptStatus = 'Проверяем разрешения...';
    });

    try {
      final locationService = LocationService.instance;
      final permissionResult = await locationService.checkAndRequestPermissions();

      if (!permissionResult.success) {
        if (permissionResult.needsSettingsRedirect) {
          _showLocationErrorDialog();
        } else {
          // Если разрешение просто отклонено, показываем обычную ошибку
          _showErrorDialog('Необходимо разрешение на доступ к геолокации для определения адреса.');
        }
        return;
      }

      final isServiceEnabled = await locationService.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        _showLocationErrorDialog();
        return;
      }

      if (mounted) {
        setState(() {
          _locationAttemptStatus = 'Попытка 1/3 - высокая точность...';
        });
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
      } catch (e) {}

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
        } catch (e) {}
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
        } catch (e) {}
      }

      if (position == null) {
        _showErrorDialog('Не удалось получить координаты. Выберите адрес вручную.');
        return;
      }

      // Обратное геокодирование
      final addressData = await ApiService.searchAddresses(
        lat: position.latitude,
        lon: position.longitude,
      );

      if (addressData != null && addressData.isNotEmpty) {
        final selectedAddress = {
          'address': addressData.first['name'] ?? addressData.first['description'] ?? 'Неизвестный адрес',
          'lat': position.latitude,
          'lon': position.longitude,
          'accuracy': position.accuracy,
          'source': 'geolocation',
          'timestamp': DateTime.now().toIso8601String(),
        };
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
        _showErrorDialog('Не удалось определить адрес по координатам. Попробуйте выбрать адрес вручную.');
      }
    } catch (e) {
      debugPrint('Ошибка при определении адреса: $e');

      // Дополнительная информация об ошибке
      if (e.toString().contains('permission') || e.toString().contains('PERMISSION') || e.toString().contains('denied')) {
        _showLocationErrorDialog();
      } else {
        _showErrorDialog('Ошибка при определении местоположения: ${e.toString()}');
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
      builder: (context) => AppDialogs.dialog(
        title: 'Ошибка',
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('OK', style: TextStyle(color: AppColors.orange)),
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
      builder: (context) => AppDialogs.dialog(
        title: 'Геолокация недоступна',
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
            child: const Text('Попробовать еще раз', style: TextStyle(color: AppColors.orange)),
            onPressed: () {
              Navigator.of(context).pop();
              _detectLocationAddress();
            },
          ),
          TextButton(
            child: const Text('Настройки', style: TextStyle(color: AppColors.orange)),
            onPressed: () async {
              Navigator.of(context).pop();
              await LocationService.instance.openAppSettings();
              await Future.delayed(const Duration(seconds: 2));
              if (mounted) {
                _detectLocationAddress();
              }
            },
          ),
          TextButton(
            child: const Text('Выбрать вручную', style: TextStyle(color: AppColors.orange)),
            onPressed: () async {
              Navigator.of(context).pop();
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
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.cardDark, AppColors.bgDeep]),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 22, offset: const Offset(0, -12)),
            ],
          ),
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              _modalHeader(),
              _geoButton(),
              _dividerLabel('или'),
              _mapSelectButton(),
              _historyList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modalHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        color: AppColors.card.withValues(alpha: 0.9),
      ),
      child: Column(
        children: const [
          SizedBox(height: 6),
          SizedBox(
            width: 48,
            height: 5,
            child: DecoratedBox(
              decoration: BoxDecoration(color: Color(0x33FFFFFF), borderRadius: BorderRadius.all(Radius.circular(30))),
            ),
          ),
          SizedBox(height: 14),
          Text('Выберите адрес доставки',
              style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _geoButton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isLoadingLocation ? null : _detectLocationAddress,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            backgroundColor: AppColors.orange,
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _isLoadingLocation
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.black)),
                        ),
                        SizedBox(width: 12),
                        Text('Определяем местоположение...', style: TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    if (_locationAttemptStatus.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_locationAttemptStatus, style: const TextStyle(color: Colors.black87, fontSize: 12)),
                    ],
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.my_location, color: Colors.black, size: 22),
                    SizedBox(width: 10),
                    Text('Определить по геолокации', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _dividerLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.08))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(label, style: const TextStyle(color: AppColors.textMute, fontWeight: FontWeight.w700)),
          ),
          Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.08))),
        ],
      ),
    );
  }

  Widget _mapSelectButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () async {
            double initLat = 43.2220;
            double initLon = 76.8512;

            try {
              final selected = await AddressStorageService.getSelectedAddress();
              if (selected != null && selected['lat'] != null && selected['lon'] != null) {
                initLat = (selected['lat'] as num).toDouble();
                initLon = (selected['lon'] as num).toDouble();
              } else {
                final hist = await AddressStorageService.getAddressHistory();
                if (hist.isNotEmpty && hist.first['point'] != null) {
                  final p = hist.first['point'];
                  if (p['lat'] != null && p['lon'] != null) {
                    initLat = (p['lat'] as num).toDouble();
                    initLon = (p['lon'] as num).toDouble();
                  }
                }
              }
            } catch (_) {}

            if (!mounted) return;
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MapAddressPage(
                  initialLat: initLat,
                  initialLon: initLon,
                  onAddressSelected: widget.onAddressSelected,
                ),
              ),
            );
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            side: const BorderSide(color: AppColors.orange, width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Colors.white.withValues(alpha: 0.02),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.map_outlined, size: 20, color: AppColors.orange),
              SizedBox(width: 10),
              Text('Выбрать адрес на карте', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.orange)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: AddressStorageService.getAddressHistory(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                child: Text('Сохранённые адреса', style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              ...snapshot.data!.map((addr) => ListTile(
                    leading: const Icon(Icons.history, color: AppColors.orange),
                    title: Text(addr['name'] ?? '', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
                    subtitle: _buildAddressSubtitle(addr),
                    onTap: () {
                      final fullAddress = {
                        'address': addr['name'],
                        'lat': addr['point']['lat'],
                        'lon': addr['point']['lon'],
                        'source': 'history',
                        'timestamp': DateTime.now().toIso8601String(),
                      };

                      if (addr['apartment']?.toString().isNotEmpty == true) {
                        fullAddress['apartment'] = addr['apartment'];
                      }
                      if (addr['entrance']?.toString().isNotEmpty == true) {
                        fullAddress['entrance'] = addr['entrance'];
                      }
                      if (addr['floor']?.toString().isNotEmpty == true) {
                        fullAddress['floor'] = addr['floor'];
                      }
                      if (addr['comment']?.toString().isNotEmpty == true) {
                        fullAddress['comment'] = addr['comment'];
                      }

                      widget.onAddressSelected(fullAddress);
                    },
                  )),
            ],
          );
        }
        return const SizedBox.shrink();
      },
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
