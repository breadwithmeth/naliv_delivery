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

  String _formatAccuracy(double accuracy) {
    if (accuracy >= 1000) {
      return '${(accuracy / 1000).toStringAsFixed(1)} км';
    }
    return '${accuracy.toStringAsFixed(0)} м';
  }

  Future<void> _openMapForDetectedPosition(Position position) async {
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MapAddressPage(
        initialLat: position.latitude,
        initialLon: position.longitude,
        onAddressSelected: widget.onAddressSelected,
      ),
    ));
  }

  Future<void> _handleApproximateLocation(Position position) async {
    final accuracyLabel = _formatAccuracy(position.accuracy);
    await showDialog(
      context: context,
      builder: (context) => AppDialogs.dialog(
        title: 'Геолокация неточная',
        content: Text(
          'Текущее местоположение определено приблизительно ($accuracyLabel). Проверьте точку на карте и подтвердите адрес вручную.',
        ),
        actions: [
          TextButton(
            child: const Text('Отмена', style: TextStyle(color: AppColors.textMute)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Открыть карту', style: TextStyle(color: AppColors.orange)),
            onPressed: () {
              Navigator.of(context).pop();
              _openMapForDetectedPosition(position);
            },
          ),
        ],
      ),
    );
  }

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

      if (locationService.requiresManualConfirmation(position)) {
        _showErrorDialog(
          'Текущее местоположение определено слишком грубо (${_formatAccuracy(position.accuracy)}). Выберите адрес на карте вручную.',
        );
        return;
      }

      if (!locationService.isAccurateEnoughForAutoSelection(position)) {
        await _handleApproximateLocation(position);
        return;
      }

      // Обратное геокодирование
      final addressData = await ApiService.searchAddresses(
        lat: position.latitude,
        lon: position.longitude,
      );

      if (addressData != null && addressData.isNotEmpty) {
        await _openMapForDetectedPosition(position);
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
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _modalHeader(),
            Expanded(
              child: ListView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  _geoButton(),
                  _dividerLabel('или'),
                  _mapSelectButton(),
                  _historyList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modalHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Выберите адрес доставки', style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _geoButton() {
    return SizedBox(
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
    );
  }

  Widget _dividerLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
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
    return SizedBox(
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
    );
  }

  Widget _historyList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: AddressStorageService.getAddressHistory(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final latestAddresses = snapshot.data!.take(5).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
                child: Text('Последние адреса', style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              ...latestAddresses.map(
                (addr) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    tileColor: AppColors.cardDark,
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
                  ),
                ),
              ),
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
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
