import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:naliv_delivery/services/diagnostics_consent_service.dart';
import 'package:naliv_delivery/services/sentry_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:naliv_delivery/utils/address_storage_service.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/widgets/address_selection_modal_material.dart';
import 'package:naliv_delivery/widgets/diagnostics_consent_dialog.dart';
import 'package:naliv_delivery/pages/map_address_page.dart';
import 'package:provider/provider.dart';
import '../utils/location_service.dart';
import '../utils/api.dart';
import 'promotion_items_page.dart';
import 'order_detail_page.dart';
import 'categoryPage.dart';
import 'search_page.dart';

class MainPage extends StatefulWidget {
  final List<Map<String, dynamic>> businesses;
  final Map<String, dynamic>? selectedBusiness;
  final Map<String, dynamic>? selectedAddress;
  final Position? userPosition;
  final Function(Map<String, dynamic>) onBusinessSelected;
  final VoidCallback onAddressChangeRequested;
  final bool isLoadingBusinesses;

  const MainPage({
    super.key,
    required this.businesses,
    this.selectedBusiness,
    this.selectedAddress,
    this.userPosition,
    required this.onBusinessSelected,
    required this.onAddressChangeRequested,
    required this.isLoadingBusinesses,
  });

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  // Контроллер и таймер для автопрокрутки промо
  final PageController _promoPageController = PageController();
  Timer? _promoAutoScrollTimer;
  int _currentPromoPage = 0;
  final LocationService locationService = LocationService.instance;
  StreamSubscription<Map<String, dynamic>?>? _addressSubscription;
  String? _lastPromptKey; // чтобы не спамить диалогами при одной и той же комбинации
  bool _diagnosticsPromptScheduled = false;

  // Состояние для акций
  List<Promotion> _promotions = [];
  bool _isLoadingPromotions = false;
  String? _promotionsError;

  // Состояние для бонусов
  Map<String, dynamic>? _bonusData;

  // Состояние для категорий
  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingCategories = false;
  String? _categoriesError;

  // Состояние для активных заказов
  List<Map<String, dynamic>> _activeOrders = [];
  bool _isLoadingActiveOrders = false;
  String? _activeOrdersError;

  /// Вычисляет расстояние до магазина если доступна геолокация
  double? _calculateDistance(Map<String, dynamic> business) {
    if (widget.userPosition != null && business['lat'] != null && business['lon'] != null) {
      return locationService.calculateDistance(
        widget.userPosition!.latitude,
        widget.userPosition!.longitude,
        business['lat'].toDouble(),
        business['lon'].toDouble(),
      );
    }
    return null;
  }

  /// Вычисляет расстояние до магазина по заданным координатам
  double? _calculateDistanceFromCoords(Map<String, dynamic> business, double lat, double lon) {
    if (business['lat'] != null && business['lon'] != null) {
      try {
        final businessLat = business['lat'].toDouble();
        final businessLon = business['lon'].toDouble();

        print('🧮 Расчет расстояния:');
        print('   От: $lat, $lon');
        print('   До: ${business['name']} ($businessLat, $businessLon)');

        final distance = locationService.calculateDistance(lat, lon, businessLat, businessLon);

        print('   Результат: ${(distance / 1000).toStringAsFixed(2)} км');
        return distance;
      } catch (e) {
        print('❌ Ошибка при расчете расстояния до ${business['name']}: $e');
        return null;
      }
    } else {
      print('❌ У магазина ${business['name']} отсутствуют координаты: lat=${business['lat']}, lon=${business['lon']}');
    }
    return null;
  }

  /// Находит ближайший магазин к указанным координатам
  Map<String, dynamic>? _findNearestBusiness(double lat, double lon) {
    if (widget.businesses.isEmpty) return null;

    Map<String, dynamic>? nearestBusiness;
    double minDistance = double.infinity;

    print('🔍 Поиск ближайшего магазина к координатам: $lat, $lon');
    print('📍 Количество доступных магазинов: ${widget.businesses.length}');

    for (var business in widget.businesses) {
      final distance = _calculateDistanceFromCoords(business, lat, lon);
      if (distance != null) {
        print('🏪 ${business['name']}: ${(distance / 1000).toStringAsFixed(2)} км');
        if (distance < minDistance) {
          minDistance = distance;
          nearestBusiness = {...business, 'distance': distance};
        }
      } else {
        print('❌ Не удалось рассчитать расстояние до ${business['name']}');
      }
    }

    if (nearestBusiness != null) {
      print('🎯 Ближайший магазин: ${nearestBusiness['name']} (${(minDistance / 1000).toStringAsFixed(2)} км)');
    } else {
      print('❌ Ближайший магазин не найден');
    }

    return nearestBusiness;
  }

  /// Автоматически выбирает ближайший магазин при смене адреса
  void _autoSelectNearestBusiness() {
    // Если уже есть выбранный магазин, не меняем его автоматически
    if (widget.selectedBusiness != null) {
      print('✅ Магазин уже выбран: ${widget.selectedBusiness!['name']}, автоматический выбор пропущен');
      return;
    }

    if (_selectedAddress != null && _selectedAddress!['lat'] != null && _selectedAddress!['lon'] != null) {
      final currentLat = _selectedAddress!['lat'].toDouble();
      final currentLon = _selectedAddress!['lon'].toDouble();

      print('🎯 Автоматический выбор ближайшего магазина для адреса:');
      print('   ${_selectedAddress!['address']}');
      print('   Координаты: $currentLat, $currentLon');

      final nearestBusiness = _findNearestBusiness(currentLat, currentLon);

      if (nearestBusiness != null) {
        print('🏪 Автоматически выбран ближайший магазин: ${nearestBusiness['name']}');
        print('   Расстояние: ${(nearestBusiness['distance'] / 1000).toStringAsFixed(2)} км');

        // Важно: вызываем onBusinessSelected для обновления состояния в родительском виджете
        widget.onBusinessSelected(nearestBusiness);

        // Показываем уведомление пользователю после небольшой задержки
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showNearestBusinessNotification(nearestBusiness);
          }
        });
      } else {
        print('❌ Не удалось найти ближайший магазин');
      }
    } else {
      print('❌ Нет координат адреса для автоматического выбора магазина');
    }
  }

  /// Показывает уведомление о выборе ближайшего магазина
  void _showNearestBusinessNotification(Map<String, dynamic> business) {
    final distance = business['distance'];
    final distanceText = distance != null ? ' (${(distance / 1000).toStringAsFixed(1)} км)' : '';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.store, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Выбран ближайший магазин: ${business['name']}$distanceText', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        action: SnackBarAction(label: 'Изменить', textColor: Colors.white, onPressed: _showBusinessSelector),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Обрабатывает выбор магазина с проверкой корзины
  Future<void> _handleBusinessSelection(Map<String, dynamic> business) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    // Проверяем, есть ли товары в корзине
    if (cartProvider.items.isNotEmpty) {
      // Проверяем, отличается ли выбранный магазин от текущего
      final currentBusinessId = widget.selectedBusiness?['id'] ?? widget.selectedBusiness?['business_id'] ?? widget.selectedBusiness?['businessId'];
      final newBusinessId = business['id'] ?? business['business_id'] ?? business['businessId'];

      if (currentBusinessId != newBusinessId) {
        // Показываем предупреждение
        final bool? shouldClear = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Смена магазина'),
              content: const Text('При смене магазина все товары из корзины будут удалены. Продолжить?'),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Отмена')),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                  child: const Text('Очистить корзину'),
                ),
              ],
            );
          },
        );

        if (shouldClear == true) {
          // Очищаем корзину
          cartProvider.clearCart();

          // Показываем уведомление
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Корзина очищена'),
                backgroundColor: Theme.of(context).colorScheme.primary,
                duration: const Duration(seconds: 2),
              ),
            );
          }

          // Выбираем новый магазин
          widget.onBusinessSelected(business);
          Navigator.of(context).pop();
        }
        // Если пользователь отменил, ничего не делаем
      } else {
        // Тот же магазин, просто закрываем диалог
        Navigator.of(context).pop();
      }
    } else {
      // Корзина пуста, просто выбираем магазин
      widget.onBusinessSelected(business);
      Navigator.of(context).pop();
    }
  }

  /// Загружает акции для выбранного магазина
  Future<void> _loadPromotions() async {
    if (!mounted) return;

    setState(() {
      _isLoadingPromotions = true;
      _promotionsError = null;
    });

    try {
      // Получаем ID выбранного магазина
      int? businessId;
      if (widget.selectedBusiness != null) {
        // Проверяем различные варианты поля ID
        businessId = widget.selectedBusiness!['id'] ?? widget.selectedBusiness!['business_id'] ?? widget.selectedBusiness!['businessId'];

        print('🔄 Загружаем акции для магазина ID: $businessId');
        print('📊 Данные магазина: ${widget.selectedBusiness}');
      }

      // Загружаем акции
      final promotions = await ApiService.getActivePromotionsTyped(businessId: businessId, limit: 10);

      if (mounted) {
        setState(() {
          _promotions = promotions ?? [];
          _isLoadingPromotions = false;
        });
        _startPromoAutoScroll();

        print('✅ Загружено акций: ${_promotions.length}');
      }
    } catch (e) {
      print('❌ Ошибка загрузки акций: $e');
      if (mounted) {
        setState(() {
          _promotionsError = 'Ошибка загрузки акций: $e';
          _isLoadingPromotions = false;
        });
      }
    }
  }

  /// Загрузить данные о бонусах пользователя
  Future<void> _loadUserBonuses() async {
    if (!mounted) return;

    // Проверяем авторизацию
    final isLoggedIn = await ApiService.isUserLoggedIn();
    if (!isLoggedIn) return;

    try {
      final bonuses = await ApiService.getUserBonuses();
      if (mounted) {
        setState(() {
          _bonusData = bonuses;
        });
      }
    } catch (e) {
      print('❌ Ошибка загрузки бонусов: $e');
    }
  }

  /// Загрузить активные заказы пользователя
  Future<void> _loadActiveOrders() async {
    if (!mounted) return;

    // Проверяем авторизацию
    final isLoggedIn = await ApiService.isUserLoggedIn();
    if (!isLoggedIn) {
      setState(() {
        _activeOrders = [];
        _isLoadingActiveOrders = false;
        _activeOrdersError = null;
      });
      return;
    }

    setState(() {
      _isLoadingActiveOrders = true;
      _activeOrdersError = null;
    });

    try {
      final result = await ApiService.getMyActiveOrders();
      if (mounted && result != null && result['success'] == true) {
        final data = result['data'];
        final activeOrdersList = data['active_orders'] as List<dynamic>? ?? [];
        print(activeOrdersList);
        // Фильтруем заказы за последние 36 часов
        final now = DateTime.now();
        final cutoffTime = now.subtract(const Duration(hours: 36));

        final filteredOrders = activeOrdersList.cast<Map<String, dynamic>>().where((order) {
          try {
            final createdAt = order['log_timestamp'];
            if (createdAt == null) return true; // Показываем если нет даты

            final orderDate = DateTime.parse(createdAt.toString());
            return orderDate.isAfter(cutoffTime);
          } catch (e) {
            print('❌ Ошибка парсинга даты заказа ${order['order_id']}: $e');
            return true; // Показываем заказ если не удалось распарсить дату
          }
        }).toList();

        setState(() {
          _activeOrders = filteredOrders;
          _isLoadingActiveOrders = false;
        });

        print('✅ Загружено активных заказов за последние 36 часов: ${_activeOrders.length} из ${activeOrdersList.length}');
      } else {
        setState(() {
          _activeOrders = [];
          _isLoadingActiveOrders = false;
        });
      }
    } catch (e) {
      print('❌ Ошибка загрузки активных заказов: $e');
      if (mounted) {
        setState(() {
          _activeOrdersError = 'Ошибка загрузки заказов: $e';
          _isLoadingActiveOrders = false;
        });
      }
    }
  }

  /// Загрузить категории товаров
  Future<void> _loadCategories() async {
    if (!mounted) return;

    setState(() {
      _isLoadingCategories = true;
      _categoriesError = null;
    });

    try {
      // Получаем ID выбранного магазина
      int? businessId;
      if (widget.selectedBusiness != null) {
        businessId = widget.selectedBusiness!['id'] ?? widget.selectedBusiness!['business_id'] ?? widget.selectedBusiness!['businessId'];

        print('🔄 Загружаем категории для магазина ID: $businessId');
      }

      // Загружаем категории из API
      final categoriesData = await ApiService.getCategories(businessId: businessId);

      if (mounted) {
        if (categoriesData != null) {
          setState(() {
            _categories = categoriesData;
            _isLoadingCategories = false;
          });
          print('✅ Загружено категорий: ${_categories.length}');
        } else {
          setState(() {
            _categories = [];
            _isLoadingCategories = false;
          });
          print('⚠️ Категории не найдены');
        }
      }
    } catch (e) {
      print('❌ Ошибка загрузки категорий: $e');
      if (mounted) {
        setState(() {
          _categoriesError = 'Ошибка загрузки категорий: $e';
          _isLoadingCategories = false;
        });
      }
    }
  }

  Map<String, dynamic>? _selectedAddress;

  @override
  void initState() {
    super.initState();
    // Подписка на изменение сохраненного адреса
    _addressSubscription = AddressStorageService.selectedAddressStream.listen((address) {
      if (mounted) {
        setState(() {
          _selectedAddress = address;
        });
        if (address != null) {
          if (widget.selectedBusiness == null) {
            _autoSelectNearestBusiness();
          } else {
            _maybePromptNearestSwitch();
          }
        }
      }
    });

    print('🚀 MainPage initState:');
    print('   Количество магазинов: ${widget.businesses.length}');
    print('   Выбранный магазин: ${widget.selectedBusiness?['name']}');
    print('   Выбранный адрес: ${widget.selectedAddress?['address']}');

    // Инициализируем адрес из widget или загружаем из хранилища
    _selectedAddress = widget.selectedAddress;
    _scheduleDiagnosticsConsentPrompt();
    if (_selectedAddress == null) {
      _initAddressSelection();
    } else {
      // Если адрес уже есть, автоматически выбираем ближайший магазин
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoSelectNearestBusiness();
      });
      // Дополнительно проверяем актуальность адреса относительно текущей позиции
      _maybeSuggestCloserAddress();
    }

    // Загружаем акции если магазин уже выбран
    if (widget.selectedBusiness != null) {
      _loadPromotions();
      _loadCategories(); // Также загружаем категории если магазин выбран
    }

    // Загружаем бонусы пользователя
    _loadUserBonuses();

    // Загружаем активные заказы
    _loadActiveOrders();
  }

  void _scheduleDiagnosticsConsentPrompt([Duration delay = const Duration(seconds: 2)]) {
    if (_diagnosticsPromptScheduled) {
      return;
    }

    _diagnosticsPromptScheduled = true;
    Future.delayed(delay, () async {
      _diagnosticsPromptScheduled = false;
      if (!mounted) {
        return;
      }
      await _maybeAskDiagnosticsConsent();
    });
  }

  Future<void> _maybeAskDiagnosticsConsent() async {
    final consent = await DiagnosticsConsentService.getDiagnosticsConsent();
    if (consent != null || !mounted) {
      return;
    }

    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      _scheduleDiagnosticsConsentPrompt();
      return;
    }

    final accepted = await showDiagnosticsConsentDialog(context);
    final sentryActive = await SentryService.updateConsent(accepted, source: 'main_page_prompt');

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          accepted
              ? sentryActive
                    ? 'Анонимная диагностика включена.'
                    : 'Анонимная диагностика включена. Сбор данных начнёт работать чуть позже.'
              : 'Анонимная диагностика отключена.',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Проверяет, далеко ли сохраненный адрес от текущей геопозиции и предлагает более близкий из истории
  Future<void> _maybeSuggestCloserAddress() async {
    if (_selectedAddress == null) return;
    if (_selectedAddress!['lat'] == null || _selectedAddress!['lon'] == null) return;

    // Пытаемся получить текущее местоположение быстро (низкая точность достаточна)
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low, timeLimit: const Duration(seconds: 4));
    } catch (e) {
      print('⚠️ Не удалось получить позицию для проверки более близкого адреса: $e');
      return;
    }
    final savedLat = (_selectedAddress!['lat'] as num).toDouble();
    final savedLon = (_selectedAddress!['lon'] as num).toDouble();
    final currentDistance = locationService.calculateDistance(pos.latitude, pos.longitude, savedLat, savedLon);

    // Порог (метры), после которого считаем адрес "не актуальным" (например 1500 м)
    const staleThresholdMeters = 1500.0;
    if (currentDistance <= staleThresholdMeters) return; // достаточно близко

    // Загружаем историю и ищем адрес ближе к текущему положению
    final history = await AddressStorageService.getAddressHistory();
    if (history.isEmpty) return;

    double bestDistance = double.infinity;
    Map<String, dynamic>? bestEntry;
    for (final entry in history) {
      final point = entry['point'];
      if (point == null) continue;
      final lat = (point['lat'] as num?)?.toDouble();
      final lon = (point['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;
      final d = locationService.calculateDistance(pos.latitude, pos.longitude, lat, lon);
      if (d < bestDistance) {
        bestDistance = d;
        bestEntry = entry;
      }
    }

    if (bestEntry == null) return;

    // Если ближайший из истории не существенно ближе (разница < 400 м) — не предлагаем
    if (currentDistance - bestDistance < 400) return;

    final promptKey =
        '${pos.latitude.toStringAsFixed(4)}_${pos.longitude.toStringAsFixed(4)}_${savedLat.toStringAsFixed(4)}_${savedLon.toStringAsFixed(4)}';
    final lastKey = await AddressStorageService.getLastReaddressPromptKey();
    if (lastKey == promptKey) return; // уже спрашивали в аналогичной ситуации

    await AddressStorageService.setLastReaddressPromptKey(promptKey);

    final bestKm = (bestDistance / 1000).toStringAsFixed(2);
    final currentKm = (currentDistance / 1000).toStringAsFixed(2);

    if (!mounted) return;
    final decision = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Обновить адрес?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Текущий выбранный адрес находится примерно в $currentKm км от вашего текущего местоположения.'),
              const SizedBox(height: 8),
              Text('В истории есть более близкий адрес (~$bestKm км). Заменить?'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop('keep'), child: const Text('Оставить')),
            TextButton(onPressed: () => Navigator.of(ctx).pop('switch'), child: const Text('Заменить')),
            TextButton(onPressed: () => Navigator.of(ctx).pop('dontask'), child: const Text('Не спрашивать')),
          ],
        );
      },
    );

    if (!mounted) return;
    if (decision == 'switch') {
      final newAddress = {
        'address': bestEntry['name'],
        'lat': bestEntry['point']['lat'],
        'lon': bestEntry['point']['lon'],
        if (bestEntry['apartment'] != null) 'apartment': bestEntry['apartment'],
        if (bestEntry['entrance'] != null) 'entrance': bestEntry['entrance'],
        if (bestEntry['floor'] != null) 'floor': bestEntry['floor'],
        if (bestEntry['comment'] != null) 'comment': bestEntry['comment'],
        'source': 'history_replacement',
        'timestamp': DateTime.now().toIso8601String(),
      };
      await AddressStorageService.saveSelectedAddress(newAddress);
      setState(() => _selectedAddress = newAddress);
      // После смены может потребоваться пересчитать ближайший магазин
      if (widget.selectedBusiness == null) {
        _autoSelectNearestBusiness();
      } else {
        _maybePromptNearestSwitch();
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Адрес обновлён на более близкий: ${newAddress['address']}'), duration: const Duration(seconds: 3)));
    } else if (decision == 'dontask') {
      // Сохраняем специальный ключ, чтобы не спрашивать до смены координат/адреса заметно
      await AddressStorageService.setLastReaddressPromptKey(promptKey);
    }
  }

  @override
  void dispose() {
    _promoAutoScrollTimer?.cancel();
    _promoPageController.dispose();
    _addressSubscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(MainPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    print('🔄 MainPage didUpdateWidget:');
    print('   Магазины изменились: ${widget.businesses.length} vs ${oldWidget.businesses.length}');
    print('   Адрес изменился: ${widget.selectedAddress != oldWidget.selectedAddress}');
    print('   Магазин изменился: ${widget.selectedBusiness != oldWidget.selectedBusiness}');

    // Обновляем локальный адрес при изменении widget.selectedAddress
    if (widget.selectedAddress != oldWidget.selectedAddress) {
      setState(() {
        _selectedAddress = widget.selectedAddress;
      });

      // Автоматически выбираем ближайший магазин при смене адреса после сборки
      if (_selectedAddress != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _autoSelectNearestBusiness();
        });
      }
    }

    // Перезагружаем акции при смене магазина
    if (widget.selectedBusiness != oldWidget.selectedBusiness) {
      if (widget.selectedBusiness != null) {
        _loadPromotions();
        _loadCategories(); // Загружаем категории для нового магазина
      } else {
        // Очищаем акции и категории если магазин не выбран
        setState(() {
          _promotions = [];
          _isLoadingPromotions = false;
          _promotionsError = null;
          _categories = [];
          _isLoadingCategories = false;
          _categoriesError = null;
        });
      }
    }

    // Если магазины загрузились, а адрес уже есть - выбираем ближайший
    if (oldWidget.businesses.isEmpty && widget.businesses.isNotEmpty && _selectedAddress != null && widget.selectedBusiness == null) {
      print('🏪 Магазины загрузились, выбираем ближайший');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _autoSelectNearestBusiness();
        }
      });
    }

    // Перезагружаем бонусы если изменились данные пользователя
    _loadUserBonuses();

    // Перезагружаем активные заказы
    _loadActiveOrders();
  }

  Future<void> _initAddressSelection() async {
    // Инициализация адреса, если он не выбран
    final address = await AddressStorageService.getSelectedAddress();
    if (address != null) {
      setState(() {
        _selectedAddress = address;
      });

      // Автоматически выбираем ближайший магазин после загрузки адреса
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _autoSelectNearestBusiness();
        }
      });
    } else {
      // Попытка автоматического определения адреса при первом запуске
      final isFirst = await AddressStorageService.isFirstLaunch();
      if (isFirst) {
        print('🆕 Первый запуск приложения – пробуем автоопределение адреса');
        _attemptAutoDetectAddress();
      } else {
        // Не первый запуск: пробуем взять ближайший адрес из истории к текущей геопозиции, если можем
        try {
          final history = await AddressStorageService.getAddressHistory();
          if (history.isNotEmpty) {
            // Получаем текущую позицию (быстрая попытка, без сложной многоступенчатой логики)
            Position? pos;
            try {
              pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low, timeLimit: const Duration(seconds: 5));
            } catch (e) {
              print('⚠️ Не удалось получить текущую позицию для выбора ближайшего адреса из истории: $e');
            }

            if (pos != null) {
              double bestDistance = double.infinity;
              Map<String, dynamic>? bestEntry;
              for (final entry in history) {
                final point = entry['point'];
                if (point == null) continue;
                final lat = (point['lat'] as num?)?.toDouble();
                final lon = (point['lon'] as num?)?.toDouble();
                if (lat == null || lon == null) continue;
                final d = locationService.calculateDistance(pos.latitude, pos.longitude, lat, lon);
                if (d < bestDistance) {
                  bestDistance = d;
                  bestEntry = entry;
                }
              }
              if (bestEntry != null) {
                const nearThresholdMeters = 1000.0; // 1 км
                if (bestDistance <= nearThresholdMeters) {
                  // Ближайший адрес достаточно близко — используем автоматически
                  final reconstructed = {
                    'address': bestEntry['name'],
                    'lat': bestEntry['point']['lat'],
                    'lon': bestEntry['point']['lon'],
                    if (bestEntry['apartment'] != null) 'apartment': bestEntry['apartment'],
                    if (bestEntry['entrance'] != null) 'entrance': bestEntry['entrance'],
                    if (bestEntry['floor'] != null) 'floor': bestEntry['floor'],
                    if (bestEntry['comment'] != null) 'comment': bestEntry['comment'],
                    'source': 'history_nearest_auto',
                    'timestamp': DateTime.now().toIso8601String(),
                  };
                  print('📌 Автовыбор адреса из истории: ${reconstructed['address']} (~${(bestDistance / 1000).toStringAsFixed(2)} км)');
                  await AddressStorageService.saveSelectedAddress(reconstructed);
                  if (!mounted) return;
                  setState(() => _selectedAddress = reconstructed);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _autoSelectNearestBusiness();
                  });
                  return; // Завершаем, не показываем модалку
                } else {
                  // Слишком далеко — предлагаем создать новый адрес
                  if (!mounted) return;
                  final distanceKm = (bestDistance / 1000).toStringAsFixed(2);
                  final decision = await showDialog<String>(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Создать новый адрес?'),
                      content: Text(
                        'Ближайший сохранённый адрес находится в ~$distanceKm км от вас. Хотите создать новый ближе или использовать существующий?',
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop('use_old'), child: const Text('Использовать')),
                        TextButton(onPressed: () => Navigator.of(ctx).pop('new'), child: const Text('Создать новый')),
                      ],
                    ),
                  );

                  if (decision == 'use_old') {
                    final reconstructed = {
                      'address': bestEntry['name'],
                      'lat': bestEntry['point']['lat'],
                      'lon': bestEntry['point']['lon'],
                      if (bestEntry['apartment'] != null) 'apartment': bestEntry['apartment'],
                      if (bestEntry['entrance'] != null) 'entrance': bestEntry['entrance'],
                      if (bestEntry['floor'] != null) 'floor': bestEntry['floor'],
                      if (bestEntry['comment'] != null) 'comment': bestEntry['comment'],
                      'source': 'history_far_confirmed',
                      'timestamp': DateTime.now().toIso8601String(),
                    };
                    await AddressStorageService.saveSelectedAddress(reconstructed);
                    if (!mounted) return;
                    setState(() => _selectedAddress = reconstructed);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _autoSelectNearestBusiness();
                    });
                    return;
                  } else if (decision == 'new') {
                    // Показать модалку создания нового адреса
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      if (!mounted) return;
                      await Future.delayed(const Duration(milliseconds: 120));
                      if (mounted) _showAddressSelectionModal();
                    });
                    return; // ждём выбора
                  } else {
                    // Если диалог закрыт системно — просто показываем модалку
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      if (!mounted) return;
                      await Future.delayed(const Duration(milliseconds: 120));
                      if (mounted) _showAddressSelectionModal();
                    });
                    return;
                  }
                }
              }
            }
          }
        } catch (e) {
          print('⚠️ Ошибка при попытке выбрать ближайший адрес из истории: $e');
        }

        // Если история пустая или не удалось определить позицию/найти ближайший — показываем модалку
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) _showAddressSelectionModal();
        });
      }
    }
  }

  /// Пытается автоматически определить текущий адрес пользователя и выбрать ближайший магазин
  Future<void> _attemptAutoDetectAddress() async {
    try {
      await SentryService.addBreadcrumb(
        category: 'address.resolution',
        message: 'Automatic address detection started',
        data: const {'source': 'geolocation_auto'},
      );
      // Проверяем и запрашиваем разрешения
      final locationService = LocationService.instance;
      final permission = await locationService.checkAndRequestPermissions();
      if (!permission.success) {
        print('❌ Автоопределение адреса: нет разрешений (${permission.message})');
        // Фоллбек — показать модальное окно выбора
        _fallbackShowAddressModal();
        return;
      }

      final enabled = await locationService.isLocationServiceEnabled();
      if (!enabled) {
        print('❌ Службы геолокации отключены – показать модалку');
        _fallbackShowAddressModal();
        return;
      }

      // Многоступенчатая стратегия точности (упрощённая относительно модалки)
      Position? position;
      final attempts = [
        {'accuracy': LocationAccuracy.high, 'timeout': const Duration(seconds: 8)},
        {'accuracy': LocationAccuracy.medium, 'timeout': const Duration(seconds: 10)},
        {'accuracy': LocationAccuracy.low, 'timeout': const Duration(seconds: 12)},
      ];
      for (final attempt in attempts) {
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: attempt['accuracy'] as LocationAccuracy,
            timeLimit: attempt['timeout'] as Duration,
          );
          break; // Позиция получена – выходим из цикла
        } catch (e) {
          print('⚠️ Не удалось получить позицию (${attempt['accuracy']}): $e');
        }
      }

      if (position == null) {
        print('❌ Не удалось определить координаты – показываем модалку');
        _fallbackShowAddressModal();
        return;
      }

      print('📍 Координаты auto-detect: ${position.latitude}, ${position.longitude} (accuracy ${position.accuracy})');

      // Обратное геокодирование через API
      final reverse = await ApiService.searchAddresses(lat: position.latitude, lon: position.longitude);

      if (reverse == null || reverse.isEmpty) {
        await SentryService.addBreadcrumb(
          category: 'address.resolution',
          message: 'Automatic address reverse lookup returned no results',
          data: const {'source': 'geolocation_auto'},
          level: SentryLevel.warning,
          type: 'error',
        );
        print('⚠️ API не вернул человекочитаемый адрес, открываем карту для уточнения');
        if (!mounted) return;
        final lat = position.latitude;
        final lon = position.longitude;
        // Переходим сразу на карту с текущими координатами для уточнения и обратного вызова
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MapAddressPage(
              initialLat: lat,
              initialLon: lon,
              onAddressSelected: (data) async {
                _selectedAddress = data;
                _autoSelectNearestBusiness();
              },
            ),
          ),
        );
        await AddressStorageService.markAsLaunched();
        return;
      }

      final base = reverse.first;
      final autoAddress = {
        'address': base['name'] ?? base['description'] ?? 'Определённый адрес',
        'lat': position.latitude,
        'lon': position.longitude,
        'accuracy': position.accuracy,
        'source': 'auto_geolocation',
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Сохраняем адрес
      await AddressStorageService.saveSelectedAddress(autoAddress);
      await AddressStorageService.addToAddressHistory({
        'name': autoAddress['address'],
        'point': {'lat': autoAddress['lat'], 'lon': autoAddress['lon']},
      });
      await AddressStorageService.markAsLaunched();

      await SentryService.addBreadcrumb(
        category: 'address.resolution',
        message: 'Automatic address detection succeeded',
        data: const {'source': 'geolocation_auto', 'result': 'resolved'},
      );

      if (!mounted) return;
      setState(() => _selectedAddress = autoAddress);

      // Если магазины уже есть – сразу выбираем, иначе поставим отложенный хук
      if (widget.businesses.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _autoSelectNearestBusiness();
        });
      } else {
        // Одноразовый ожидатель появления магазинов через микротаймеры
        int attempts = 0;
        Timer.periodic(const Duration(milliseconds: 400), (t) {
          attempts++;
          if (!mounted || attempts > 25) {
            // максимум ~10 секунд ожидания
            t.cancel();
            return;
          }
          if (widget.businesses.isNotEmpty && widget.selectedBusiness == null) {
            t.cancel();
            _autoSelectNearestBusiness();
          }
        });
      }

      // Отобразим ненавязчивый snackbar
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Адрес определён автоматически: ${autoAddress['address']}'), duration: const Duration(seconds: 3)));
      }
    } catch (e) {
      await SentryService.captureBusinessFailure(
        message: 'Automatic address detection failed',
        category: 'address.resolution',
        level: SentryLevel.warning,
        tags: const {'flow': 'address_resolution', 'mode': 'geolocation_auto'},
      );
      print('❌ Ошибка автоопределения адреса: $e');
      _fallbackShowAddressModal();
    }
  }

  void _fallbackShowAddressModal() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) _showAddressSelectionModal();
    });
  }

  Future<void> _showAddressSelectionModal() async {
    print('🔥 _showAddressSelectionModal вызван');
    await SentryService.addBreadcrumb(
      category: 'address.resolution',
      message: 'Main page address selection modal opened',
      data: const {'source': 'main_page_modal'},
    );

    // Проверяем, что контекст доступен и виджет mounted
    if (!mounted) {
      print('❌ Виджет не mounted при показе модального окна');
      return;
    }

    // Ждем несколько кадров, чтобы убедиться что Navigator готов
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) {
      print('❌ Виджет не mounted после ожидания');
      return;
    }

    try {
      print('🎭 Вызываем AddressSelectionModalHelper.show');
      final selectedAddress = await AddressSelectionModalHelper.show(context);

      print('🎯 Результат модального окна: $selectedAddress');

      if (selectedAddress != null && mounted) {
        print('💾 Сохраняем выбранный адрес');
        // Сохраняем в SharedPreferences
        await AddressStorageService.saveSelectedAddress(selectedAddress);
        // Сохраняем в историю с полными данными адреса
        await AddressStorageService.addToAddressHistory({
          'name': selectedAddress['address'],
          'point': {'lat': selectedAddress['lat'], 'lon': selectedAddress['lon']},
          if (selectedAddress['apartment']?.toString().isNotEmpty == true) 'apartment': selectedAddress['apartment'],
          if (selectedAddress['entrance']?.toString().isNotEmpty == true) 'entrance': selectedAddress['entrance'],
          if (selectedAddress['floor']?.toString().isNotEmpty == true) 'floor': selectedAddress['floor'],
          if (selectedAddress['other']?.toString().isNotEmpty == true) 'other': selectedAddress['other'],
          if (selectedAddress['comment']?.toString().isNotEmpty == true) 'comment': selectedAddress['comment'],
        });
        setState(() {
          _selectedAddress = selectedAddress;
        });

        // Отмечаем, что приложение уже запускалось
        await AddressStorageService.markAsLaunched();
        print('✅ Приложение отмечено как запущенное');

        // Уведомляем родительский виджет об изменении адреса
        //widget.onAddressChangeRequested(); // убираем автоматическое открытие выбора магазина

        // Если магазин ещё не выбран – выбираем автоматически, иначе проверяем необходимость предложения смены
        if (widget.selectedBusiness == null) {
          _autoSelectNearestBusiness();
        } else {
          _maybePromptNearestSwitch();
        }

        await SentryService.addBreadcrumb(
          category: 'address.resolution',
          message: 'Main page address selected from modal',
          data: const {'source': 'main_page_modal', 'result': 'selected'},
        );
      } else {
        await SentryService.addBreadcrumb(
          category: 'address.resolution',
          message: 'Main page address modal dismissed',
          data: const {'source': 'main_page_modal', 'result': 'dismissed'},
        );
        print('ℹ️ Адрес не выбран или виджет не mounted');
      }
    } catch (e) {
      print('❌ Ошибка при показе модального окна выбора адреса: $e');
    }
  }

  /// Предлагает переключиться на ближайший магазин, если текущий не ближайший
  Future<void> _maybePromptNearestSwitch() async {
    if (_selectedAddress == null) return;
    if (_selectedAddress!['lat'] == null || _selectedAddress!['lon'] == null) return;
    if (widget.businesses.isEmpty) return;
    if (widget.selectedBusiness == null) return; // тогда пусть авто выбор сделает другая логика

    final lat = (_selectedAddress!['lat'] as num).toDouble();
    final lon = (_selectedAddress!['lon'] as num).toDouble();
    final nearest = _findNearestBusiness(lat, lon);
    if (nearest == null) return;

    // ID текущего и ближайшего магазина
    final currentBusinessId = widget.selectedBusiness!['id'] ?? widget.selectedBusiness!['business_id'] ?? widget.selectedBusiness!['businessId'];
    final nearestBusinessId = nearest['id'] ?? nearest['business_id'] ?? nearest['businessId'];
    if (currentBusinessId == null || nearestBusinessId == null) return;

    // Уже и так ближайший
    if (currentBusinessId == nearestBusinessId) return;

    // Ключ для предотвращения повторных диалогов
    final promptKey = '${lat.toStringAsFixed(5)}_${lon.toStringAsFixed(5)}_${currentBusinessId}_$nearestBusinessId';
    if (_lastPromptKey == promptKey) return; // уже показывали
    _lastPromptKey = promptKey;

    // Расстояния
    final nearestDistanceM = (nearest['distance'] as num?)?.toDouble() ?? _calculateDistanceFromCoords(nearest, lat, lon) ?? 0;
    final currentDistanceM = _calculateDistanceFromCoords(widget.selectedBusiness!, lat, lon) ?? 0;

    final nearestKm = (nearestDistanceM / 1000).toStringAsFixed(2);
    final currentKm = (currentDistanceM / 1000).toStringAsFixed(2);

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final hasCartItems = cartProvider.items.isNotEmpty;

    // Диалог-предложение
    final shouldSwitch = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Ближайший магазин'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Текущий магазин находится на ~$currentKm км от выбранного адреса.'),
              const SizedBox(height: 8),
              Text('Ближайший магазин: ${nearest['name']} (~$nearestKm км).', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Text(hasCartItems ? 'Переключение очистит текущую корзину. Перейти к ближайшему магазину?' : 'Переключить на ближайший магазин?'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Оставить')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Переключить')),
          ],
        );
      },
    );

    if (shouldSwitch == true) {
      if (hasCartItems) {
        cartProvider.clearCart();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Корзина очищена из-за смены магазина'),
              duration: const Duration(seconds: 2),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      }

      widget.onBusinessSelected(nearest);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Вы переключились на ближайший магазин: ${nearest['name']}'), duration: const Duration(seconds: 3)));
      }
    }
  }

  /// Показывает модальное окно с выбором магазина
  void _showBusinessSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        color: Theme.of(context).colorScheme.surfaceDim,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Отмена')),
                  const Text('Выберите магазин', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 80), // Балансировка кнопки
                ],
              ),
            ),
            Expanded(
              child: widget.isLoadingBusinesses
                  ? const Center(child: CircularProgressIndicator())
                  : Builder(
                      builder: (context) {
                        // Создаем список магазинов с расстояниями для сортировки
                        List<Map<String, dynamic>> businessesWithDistance = widget.businesses.map((business) {
                          final distance = _selectedAddress != null && _selectedAddress!['lat'] != null && _selectedAddress!['lon'] != null
                              ? _calculateDistanceFromCoords(business, _selectedAddress!['lat'].toDouble(), _selectedAddress!['lon'].toDouble())
                              : _calculateDistance(business);

                          return {...business, 'calculatedDistance': distance};
                        }).toList();

                        // Сортируем по расстоянию (ближайшие сверху)
                        businessesWithDistance.sort((a, b) {
                          final distanceA = a['calculatedDistance'];
                          final distanceB = b['calculatedDistance'];

                          // Если у одного есть расстояние, а у другого нет
                          if (distanceA == null && distanceB != null) return 1;
                          if (distanceA != null && distanceB == null) return -1;
                          if (distanceA == null && distanceB == null) return 0;

                          // Сравниваем расстояния
                          return distanceA.compareTo(distanceB);
                        });

                        return ListView.builder(
                          itemCount: businessesWithDistance.length,
                          itemBuilder: (context, index) {
                            final business = businessesWithDistance[index];
                            final distance = business['calculatedDistance'];
                            final isSelected = widget.selectedBusiness?['id'] == business['id'];

                            return Container(
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 0.5)),
                              ),
                              child: TextButton(
                                onPressed: () {
                                  _handleBusinessSelection(business);
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    business['name'] ?? 'Без названия',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w600,
                                                      color: isSelected
                                                          ? Theme.of(context).colorScheme.primary
                                                          : Theme.of(context).colorScheme.onSurface,
                                                    ),
                                                  ),
                                                ),
                                                if (distance != null && _selectedAddress != null && _selectedAddress!['lat'] != null)
                                                  Container(
                                                    margin: const EdgeInsets.only(left: 8),
                                                    child: Icon(Icons.near_me, size: 16, color: Theme.of(context).colorScheme.primary),
                                                  ),
                                              ],
                                            ),
                                            if (business['address'] != null)
                                              Text(
                                                business['address'],
                                                style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          if (distance != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '${(distance / 1000).toStringAsFixed(1)} км',
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.primary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          if (isSelected)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceInfo() {
    if (widget.selectedBusiness == null) return const SizedBox.shrink();

    double? distance;
    if (_selectedAddress != null && _selectedAddress!['lat'] != null && _selectedAddress!['lon'] != null) {
      distance = _calculateDistanceFromCoords(widget.selectedBusiness!, _selectedAddress!['lat'].toDouble(), _selectedAddress!['lon'].toDouble());
    } else {
      distance = _calculateDistance(widget.selectedBusiness!);
    }

    if (distance == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.near_me, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            '${(distance / 1000).toStringAsFixed(1)} км',
            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedBusiness = widget.selectedBusiness;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // SliverAppBar(
          //   pinned: true,
          //   backgroundColor: Theme.of(context).colorScheme.surface,
          //   surfaceTintColor: Colors.transparent,
          //   elevation: 0,
          //   shadowColor: Colors.transparent,
          //   forceElevated: false,
          //   toolbarHeight: 56,
          //   titleSpacing: 12,
          //   title: GestureDetector(
          //     onTap: () {
          //       Navigator.of(context).push(
          //         MaterialPageRoute(
          //           builder: (_) => const SearchPage(),
          //         ),
          //       );
          //     },
          //     child: Container(
          //       height: 40,
          //       decoration: BoxDecoration(
          //         color: Theme.of(context).colorScheme.surfaceContainerHighest,
          //         borderRadius: BorderRadius.circular(10),
          //         border: Border.all(
          //           color:
          //               Theme.of(context).colorScheme.outline.withOpacity(0.2),
          //         ),
          //       ),
          //       padding: const EdgeInsets.symmetric(horizontal: 12),
          //       alignment: Alignment.centerLeft,
          //       child: Row(
          //         children: [
          //           Icon(
          //             Icons.search,
          //             size: 20,
          //             color: Theme.of(context).colorScheme.onSurfaceVariant,
          //           ),
          //           const SizedBox(width: 8),
          //           Expanded(
          //             child: Text(
          //               'Поиск товаров',
          //               maxLines: 1,
          //               overflow: TextOverflow.ellipsis,
          //               style: TextStyle(
          //                 color: Theme.of(context).colorScheme.onSurfaceVariant,
          //                 fontSize: 14,
          //               ),
          //             ),
          //           ),
          //         ],
          //       ),
          //     ),
          //   ),
          // ),
          SliverToBoxAdapter(child: widget.selectedBusiness != null ? _buildPromotionsHeroCarousel() : const SizedBox.shrink()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchPage()));
                    },
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Icon(Icons.search, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Поиск товаров',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Адрес и магазин: компактный ряд из двух плиток
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Адрес доставки
                      Expanded(
                        child: GestureDetector(
                          onTap: _showAddressSelectionModal,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              // border: Border.all(
                              //   color: Theme.of(context)
                              //       .colorScheme
                              //       .outline
                              //       .withOpacity(0.2),
                              //   width: 1.0,
                              // ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Доставка по адресу', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.2)),
                                      const SizedBox(height: 2),
                                      Text(
                                        _selectedAddress != null ? _selectedAddress!['address'] : 'Выберите адрес доставки',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.15),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 3,
                                      ),
                                    ],
                                  ),
                                ),
                                // Container(
                                //   padding: const EdgeInsets.all(4),
                                //   decoration: BoxDecoration(
                                //     color: Theme.of(context)
                                //         .colorScheme
                                //         .secondary
                                //         .withOpacity(0.12),
                                //     borderRadius: BorderRadius.circular(8),
                                //   ),
                                //   child: Icon(
                                //     Icons.keyboard_arrow_down,
                                //     size: 18,
                                //   ),
                                // ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Магазин
                      Expanded(
                        child: GestureDetector(
                          onTap: widget.businesses.isNotEmpty && !widget.isLoadingBusinesses ? _showBusinessSelector : null,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              // border: Border.all(
                              //   color: Theme.of(context)
                              //       .colorScheme
                              //       .outline
                              //       .withOpacity(0.2),
                              //   width: 1.0,
                              // ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Container(
                                //   padding: const EdgeInsets.all(8),
                                //   decoration: BoxDecoration(
                                //     color:
                                //         Theme.of(context).colorScheme.surface,
                                //     borderRadius: BorderRadius.circular(10),
                                //   ),
                                //   child: Icon(
                                //     Icons.store,
                                //     color:
                                //         Theme.of(context).colorScheme.secondary,
                                //     size: 18,
                                //   ),
                                // ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (widget.isLoadingBusinesses)
                                        Text(
                                          'Загрузка магазинов...',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.secondary.withOpacity(0.8),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.2,
                                          ),
                                        )
                                      else if (selectedBusiness != null) ...[
                                        Text(
                                          'Магазин',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.secondary.withOpacity(0.8),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                selectedBusiness['name'] ?? 'Магазин',
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  height: 1.15,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            // const SizedBox(width: 8),
                                            _buildDistanceInfo(),
                                          ],
                                        ),
                                        if (selectedBusiness['address'] != null) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            selectedBusiness['address'],
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w500,
                                              height: 1.25,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                          ),
                                        ],
                                      ] else
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Магазин для заказа',
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.secondary.withOpacity(0.8),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Выберите магазин',
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                height: 1.15,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.keyboard_arrow_down, color: Theme.of(context).colorScheme.secondary, size: 18),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Hero карусель акций

                  // Бонусная карта
                  if (_bonusData != null && _bonusData!['success'] == true) ...[const SizedBox(height: 12), _buildBonusCard()],

                  // Категории товаров
                  if (_categories.isNotEmpty || _isLoadingCategories || _categoriesError != null) ...[
                    const SizedBox(height: 12),
                    _buildCategoriesSection(),
                  ],

                  // Активные заказы
                  if (_activeOrders.isNotEmpty || _isLoadingActiveOrders || _activeOrdersError != null) ...[
                    const SizedBox(height: 12),
                    _buildActiveOrdersSection(),
                  ],
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: const SizedBox(height: 500)),
        ],
      ),
    );
  }

  /// Строит секцию с активными заказами
  Widget _buildActiveOrdersSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text("Активные заказы", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoadingActiveOrders)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [CircularProgressIndicator(), SizedBox(width: 12), Text('Загрузка заказов...')],
                  ),
                ),
              )
            else if (_activeOrdersError != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 24),
                      const SizedBox(height: 8),
                      Text(
                        _activeOrdersError!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _loadActiveOrders, child: const Text('Повторить')),
                    ],
                  ),
                ),
              )
            else if (_activeOrders.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 32),
                      const SizedBox(height: 8),
                      Text('У вас нет активных заказов', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
                    ],
                  ),
                ),
              )
            else
              Column(children: [for (int i = 0; i < _activeOrders.length; i++) _buildActiveOrderCard(_activeOrders[i], i)]),
          ],
        ),
      ),
    );
  }

  /// Строит карточку активного заказа
  Widget _buildActiveOrderCard(Map<String, dynamic> order, int index) {
    final business = order['business'] as Map<String, dynamic>?;
    final currentStatus = order['current_status'] as Map<String, dynamic>?;
    final deliveryAddress = order['delivery_address'] as Map<String, dynamic>?;
    final itemsSummary = order['items_summary'] as Map<String, dynamic>?;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => OrderDetailPage(order: order)));
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: EdgeInsets.only(bottom: index < _activeOrders.length - 1 ? 12 : 0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок заказа
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Заказ #${order['order_id']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      if (business != null)
                        Text(
                          business['name'] ?? 'Неизвестный магазин',
                          style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                  if (currentStatus != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _parseColor(currentStatus['status_color']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _parseColor(currentStatus['status_color']), width: 1),
                      ),
                      child: Text(
                        currentStatus['status_description'] ?? 'Неизвестно',
                        style: TextStyle(color: _parseColor(currentStatus['status_color']), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Информация о доставке
              if (deliveryAddress != null) ...[
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        deliveryAddress["address_id"] == 1 ? 'Самовывоз' : (deliveryAddress['address'] ?? 'Адрес не указан'),
                        style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Информация о товарах
              if (itemsSummary != null) ...[
                Row(
                  children: [
                    Icon(Icons.shopping_bag, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      'Товаров: ${itemsSummary['items_count'] ?? 0} (${itemsSummary['total_amount'] ?? 0} шт.)',
                      style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Сумма заказа
              // if (costSummary != null)
              //   Row(
              //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //     children: [
              //       const Text(
              //         'Сумма заказа:',
              //         style: TextStyle(
              //           fontSize: 14,
              //           fontWeight: FontWeight.w500,
              //         ),
              //       ),
              //       Text(
              //         '${costSummary['total_sum']} ₸',
              //         style: TextStyle(
              //           fontSize: 16,
              //           fontWeight: FontWeight.w600,
              //           color: Theme.of(context).colorScheme.primary,
              //         ),
              //       ),
              //     ],
              //   ),

              // Индикатор того, что заказ кликабельный
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Нажмите для подробностей',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios, size: 12, color: Theme.of(context).colorScheme.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Парсит цвет из строки
  Color _parseColor(String? colorString) {
    if (colorString == null || !colorString.startsWith('#')) {
      return Theme.of(context).colorScheme.primary;
    }

    try {
      return Color(int.parse(colorString.substring(1), radix: 16) + 0xFF000000);
    } catch (e) {
      return Theme.of(context).colorScheme.primary;
    }
  }

  /// Строит hero карусель акций
  Widget _buildPromotionsHeroCarousel() {
    final width = MediaQuery.of(context).size.width; // учёт внешних отступов
    return SizedBox(
      height: (width / 3) * 2, // квадрат
      child: _buildPromotionsCarousel(width),
    );
  }

  /// Строит карусель акций
  Widget _buildPromotionsCarousel(double size) {
    if (_isLoadingPromotions) {
      return const Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [CircularProgressIndicator(), SizedBox(width: 12), Text('Загрузка акций...')],
        ),
      );
    }

    if (_promotionsError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 24),
            const SizedBox(height: 8),
            Text('Ошибка загрузки акций', style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14)),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadPromotions, child: const Text('Повторить')),
          ],
        ),
      );
    }

    if (_promotions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_offer_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 32),
            const SizedBox(height: 8),
            Text('В данный момент нет активных акций', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
          ],
        ),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _promoPageController,
          itemCount: _promotions.length,
          onPageChanged: (i) => setState(() => _currentPromoPage = i),
          itemBuilder: (context, index) => _buildPromotionPage(_promotions[index], size),
        ),
        // Индикаторы
        Positioned(
          bottom: 8,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_promotions.length, (i) {
              final active = i == _currentPromoPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 6,
                width: active ? 18 : 6,
                decoration: BoxDecoration(
                  color: active ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  /// Страница промо (квадрат)
  Widget _buildPromotionPage(Promotion promotion, double size) {
    final bizId = widget.selectedBusiness != null
        ? (widget.selectedBusiness!['id'] as int?) ?? (widget.selectedBusiness!['businessId'] as int?)
        : null;
    return GestureDetector(
      onTap: () {
        if (bizId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PromotionItemsPage(promotionId: promotion.marketingPromotionId, promotionName: promotion.name, businessId: bizId),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(0)),
        clipBehavior: Clip.hardEdge,
        // borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 3 / 2,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Фото
              Image.network(
                promotion.cover ?? '',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Theme.of(context).colorScheme.surface,
                  alignment: Alignment.center,
                  child: Icon(Icons.broken_image, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 48),
                ),
              ),
              // Градиент снизу
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.0), Colors.black.withOpacity(0.55)],
                    ),
                  ),
                  child: Text(
                    promotion.name ?? 'Акция без названия',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, height: 1.2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startPromoAutoScroll() {
    _promoAutoScrollTimer?.cancel();
    if (_promotions.length <= 1) return; // не скроллим если одна акция
    _promoAutoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final next = (_currentPromoPage + 1) % _promotions.length;
      _promoPageController.animateToPage(next, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      _currentPromoPage = next;
      if (mounted) setState(() {});
    });
  }

  void _showBarcodeModal(String cardUuid) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: Text('Бонусная карта', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          message: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Text('Номер карты: $cardUuid', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                SizedBox(height: 20),
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(16),
                  child: BarcodeWidget(barcode: Barcode.code128(), data: cardUuid, width: 250, height: 80, drawText: false),
                ),
                SizedBox(height: 10),
                Text(
                  cardUuid,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Закрыть'),
          ),
        );
      },
    );
  }

  /// Построить виджет бонусной карты
  Widget _buildBonusCard() {
    final bonusData = _bonusData!['data'];
    final totalBonuses = bonusData['totalBonuses'] ?? 0;
    final cardUuid = bonusData['bonusCard']?['cardUuid'] ?? '';

    // Получаем последнее значение из истории бонусов
    final bonusHistory = bonusData['bonusHistory'] as List?;
    final latestBonusAmount = bonusHistory != null && bonusHistory.isNotEmpty ? bonusHistory.first['amount'] ?? 0 : 0;

    return GestureDetector(
      onTap: () {
        if (cardUuid.isNotEmpty) {
          _showBarcodeModal(cardUuid);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            // Иконка и название
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.card_giftcard, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
            ),
            const SizedBox(width: 12),

            // Основная информация
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Бонусная карта',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text('Нажмите для показа штрихкода', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
                ],
              ),
            ),

            // Баланс
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$totalBonuses ₸',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (latestBonusAmount > 0)
                  Text(
                    '+$latestBonusAmount ₸',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
              ],
            ),

            // Стрелка
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 16),
          ],
        ),
      ),
    );
  }

  /// Строит секцию с категориями товаров
  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(Icons.category, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              const Text("Категории", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        SizedBox(height: 8),

        // Горизонтальная сетка категорий
        SizedBox(
          height: 160, // Высота для 2 рядов
          child: _buildCategoriesGrid(),
        ),
      ],
    );
  }

  /// Строит горизонтальную сетку категорий
  Widget _buildCategoriesGrid() {
    if (_isLoadingCategories) {
      return const Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [CircularProgressIndicator(), SizedBox(width: 12), Text('Загрузка категорий...')],
        ),
      );
    }

    if (_categoriesError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 24),
            const SizedBox(height: 8),
            Text('Ошибка загрузки категорий', style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14)),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadCategories, child: const Text('Повторить')),
          ],
        ),
      );
    }

    if (_categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 32),
            const SizedBox(height: 8),
            Text('Категории не найдены', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
          ],
        ),
      );
    }

    // Вычисляем ширину элемента
    const itemWidth = 120.0;
    const itemHeight = 120.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        height: itemHeight,
        // width: columnsCount * (itemWidth + 8), // ширина + отступ
        child: GridView.builder(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // 2 ряда
            childAspectRatio: itemWidth / itemHeight,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            return _buildCategoryCard(_categories[index]);
          },
        ),
      ),
    );
  }

  /// Строит карточку категории
  Widget _buildCategoryCard(Map<String, dynamic> category) {
    final categoryName = category['name'] ?? 'Без названия';

    // Определяем иконку и цвет на основе названия категории
    final iconAndColor = _getCategoryIconAndColor(categoryName);

    return InkWell(
      onTap: () {
        // Получаем ID выбранного магазина
        final businessId = widget.selectedBusiness?['id'] ?? widget.selectedBusiness?['business_id'] ?? widget.selectedBusiness?['businessId'];

        if (businessId != null) {
          // Создаем объект Category из данных
          final categoryObj = Category.fromJson(category);

          // Навигация в CategoryPage
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CategoryPage(
                category: categoryObj,
                allCategories: _categories.map((cat) => Category.fromJson(cat)).toList(),
                businessId: businessId,
              ),
            ),
          );
        } else {
          // Показываем сообщение если магазин не выбран
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: const Text('Сначала выберите магазин'), backgroundColor: Theme.of(context).colorScheme.error));
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 120,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Иконка категории
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
              ),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.network(
                  category["img"] ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(iconAndColor['icon'], color: iconAndColor['color'], size: 24);
                  },
                ),
              ),
            ),

            // Название категории
            Text(
              categoryName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),

            // Количество товаров
            // if (itemsCount > 0)
            //   Text(
            //     '$itemsCount',
            //     style: TextStyle(
            //       fontSize: 10,
            //       color: Theme.of(context).colorScheme.onSurfaceVariant,
            //     ),
            //   ),
          ],
        ),
      ),
    );
  }

  /// Возвращает иконку и цвет для категории на основе названия
  Map<String, dynamic> _getCategoryIconAndColor(String categoryName) {
    final lowerName = categoryName.toLowerCase();

    // Алкоголь
    if (lowerName.contains('алкоголь') ||
        lowerName.contains('вино') ||
        lowerName.contains('пиво') ||
        lowerName.contains('водка') ||
        lowerName.contains('виски') ||
        lowerName.contains('коньяк')) {
      return {'icon': Icons.wine_bar, 'color': const Color(0xFFE91E63)};
    }

    // Сигареты
    if (lowerName.contains('сигарет') || lowerName.contains('табак') || lowerName.contains('курение')) {
      return {'icon': Icons.smoking_rooms, 'color': const Color(0xFF9C27B0)};
    }

    // Сладости
    if (lowerName.contains('сладост') ||
        lowerName.contains('конфет') ||
        lowerName.contains('шоколад') ||
        lowerName.contains('торт') ||
        lowerName.contains('печенье')) {
      return {'icon': Icons.cake, 'color': const Color(0xFF795548)};
    }

    // Напитки
    if (lowerName.contains('напитк') ||
        lowerName.contains('сок') ||
        lowerName.contains('вода') ||
        lowerName.contains('газировка') ||
        lowerName.contains('лимонад')) {
      return {'icon': Icons.local_drink, 'color': const Color(0xFF2196F3)};
    }

    // Фрукты и овощи
    if (lowerName.contains('фрукт') || lowerName.contains('овощ') || lowerName.contains('ягод') || lowerName.contains('зелен')) {
      return {'icon': Icons.eco, 'color': const Color(0xFF4CAF50)};
    }

    // Снеки
    if (lowerName.contains('снек') || lowerName.contains('чипс') || lowerName.contains('сухарик') || lowerName.contains('орех')) {
      return {'icon': Icons.lunch_dining, 'color': const Color(0xFFFF9800)};
    }

    // Молочные продукты
    if (lowerName.contains('молочн') ||
        lowerName.contains('молоко') ||
        lowerName.contains('кефир') ||
        lowerName.contains('йогурт') ||
        lowerName.contains('сыр')) {
      return {'icon': Icons.local_cafe, 'color': const Color(0xFF00BCD4)};
    }

    // Мясо и рыба
    if (lowerName.contains('мясо') || lowerName.contains('рыба') || lowerName.contains('колбас') || lowerName.contains('сосиск')) {
      return {'icon': Icons.restaurant, 'color': const Color(0xFFFF5722)};
    }

    // Хлеб и выпечка
    if (lowerName.contains('хлеб') || lowerName.contains('выпечк') || lowerName.contains('булочк') || lowerName.contains('батон')) {
      return {'icon': Icons.bakery_dining, 'color': const Color(0xFF8BC34A)};
    }

    // По умолчанию
    return {'icon': Icons.category, 'color': Theme.of(context).colorScheme.primary};
  }
}
