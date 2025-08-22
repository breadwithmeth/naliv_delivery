import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:naliv_delivery/utils/address_storage_service.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/widgets/address_selection_modal_material.dart';
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
  final LocationService locationService = LocationService.instance;
  StreamSubscription<Map<String, dynamic>?>? _addressSubscription;

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
    if (widget.userPosition != null &&
        business['lat'] != null &&
        business['lon'] != null) {
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
  double? _calculateDistanceFromCoords(
      Map<String, dynamic> business, double lat, double lon) {
    if (business['lat'] != null && business['lon'] != null) {
      try {
        final businessLat = business['lat'].toDouble();
        final businessLon = business['lon'].toDouble();

        print('🧮 Расчет расстояния:');
        print('   От: $lat, $lon');
        print('   До: ${business['name']} ($businessLat, $businessLon)');

        final distance = locationService.calculateDistance(
          lat,
          lon,
          businessLat,
          businessLon,
        );

        print('   Результат: ${(distance / 1000).toStringAsFixed(2)} км');
        return distance;
      } catch (e) {
        print('❌ Ошибка при расчете расстояния до ${business['name']}: $e');
        return null;
      }
    } else {
      print(
          '❌ У магазина ${business['name']} отсутствуют координаты: lat=${business['lat']}, lon=${business['lon']}');
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
        print(
            '🏪 ${business['name']}: ${(distance / 1000).toStringAsFixed(2)} км');
        if (distance < minDistance) {
          minDistance = distance;
          nearestBusiness = {
            ...business,
            'distance': distance,
          };
        }
      } else {
        print('❌ Не удалось рассчитать расстояние до ${business['name']}');
      }
    }

    if (nearestBusiness != null) {
      print(
          '🎯 Ближайший магазин: ${nearestBusiness['name']} (${(minDistance / 1000).toStringAsFixed(2)} км)');
    } else {
      print('❌ Ближайший магазин не найден');
    }

    return nearestBusiness;
  }

  /// Автоматически выбирает ближайший магазин при смене адреса
  void _autoSelectNearestBusiness() {
    // Если уже есть выбранный магазин, не меняем его автоматически
    if (widget.selectedBusiness != null) {
      print(
          '✅ Магазин уже выбран: ${widget.selectedBusiness!['name']}, автоматический выбор пропущен');
      return;
    }

    if (_selectedAddress != null &&
        _selectedAddress!['lat'] != null &&
        _selectedAddress!['lon'] != null) {
      final currentLat = _selectedAddress!['lat'].toDouble();
      final currentLon = _selectedAddress!['lon'].toDouble();

      print('🎯 Автоматический выбор ближайшего магазина для адреса:');
      print('   ${_selectedAddress!['address']}');
      print('   Координаты: $currentLat, $currentLon');

      final nearestBusiness = _findNearestBusiness(currentLat, currentLon);

      if (nearestBusiness != null) {
        print(
            '🏪 Автоматически выбран ближайший магазин: ${nearestBusiness['name']}');
        print(
            '   Расстояние: ${(nearestBusiness['distance'] / 1000).toStringAsFixed(2)} км');

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
    final distanceText =
        distance != null ? ' (${(distance / 1000).toStringAsFixed(1)} км)' : '';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.store,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Выбран ближайший магазин: ${business['name']}$distanceText',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        action: SnackBarAction(
          label: 'Изменить',
          textColor: Colors.white,
          onPressed: _showBusinessSelector,
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Обрабатывает выбор магазина с проверкой корзины
  Future<void> _handleBusinessSelection(Map<String, dynamic> business) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    // Проверяем, есть ли товары в корзине
    if (cartProvider.items.isNotEmpty) {
      // Проверяем, отличается ли выбранный магазин от текущего
      final currentBusinessId = widget.selectedBusiness?['id'] ??
          widget.selectedBusiness?['business_id'] ??
          widget.selectedBusiness?['businessId'];
      final newBusinessId =
          business['id'] ?? business['business_id'] ?? business['businessId'];

      if (currentBusinessId != newBusinessId) {
        // Показываем предупреждение
        final bool? shouldClear = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Смена магазина'),
              content: const Text(
                  'При смене магазина все товары из корзины будут удалены. Продолжить?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
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
        businessId = widget.selectedBusiness!['id'] ??
            widget.selectedBusiness!['business_id'] ??
            widget.selectedBusiness!['businessId'];

        print('🔄 Загружаем акции для магазина ID: $businessId');
        print('📊 Данные магазина: ${widget.selectedBusiness}');
      }

      // Загружаем акции
      final promotions = await ApiService.getActivePromotionsTyped(
        businessId: businessId,
        limit: 10,
      );

      if (mounted) {
        setState(() {
          _promotions = promotions ?? [];
          _isLoadingPromotions = false;
        });

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

        setState(() {
          _activeOrders = activeOrdersList.cast<Map<String, dynamic>>();
          _isLoadingActiveOrders = false;
        });

        print('✅ Загружено активных заказов: ${_activeOrders.length}');
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
        businessId = widget.selectedBusiness!['id'] ??
            widget.selectedBusiness!['business_id'] ??
            widget.selectedBusiness!['businessId'];

        print('🔄 Загружаем категории для магазина ID: $businessId');
      }

      // Загружаем категории из API
      final categoriesData = await ApiService.getCategories(
        businessId: businessId,
      );

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
    _addressSubscription =
        AddressStorageService.selectedAddressStream.listen((address) {
      if (mounted) {
        setState(() {
          _selectedAddress = address;
        });
        if (address != null) _autoSelectNearestBusiness();
      }
    });

    print('🚀 MainPage initState:');
    print('   Количество магазинов: ${widget.businesses.length}');
    print('   Выбранный магазин: ${widget.selectedBusiness?['name']}');
    print('   Выбранный адрес: ${widget.selectedAddress?['address']}');

    // Инициализируем адрес из widget или загружаем из хранилища
    _selectedAddress = widget.selectedAddress;
    if (_selectedAddress == null) {
      _initAddressSelection();
    } else {
      // Если адрес уже есть, автоматически выбираем ближайший магазин
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoSelectNearestBusiness();
      });
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

  @override
  void dispose() {
    _addressSubscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(MainPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    print('🔄 MainPage didUpdateWidget:');
    print(
        '   Магазины изменились: ${widget.businesses.length} vs ${oldWidget.businesses.length}');
    print(
        '   Адрес изменился: ${widget.selectedAddress != oldWidget.selectedAddress}');
    print(
        '   Магазин изменился: ${widget.selectedBusiness != oldWidget.selectedBusiness}');

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
    if (oldWidget.businesses.isEmpty &&
        widget.businesses.isNotEmpty &&
        _selectedAddress != null &&
        widget.selectedBusiness == null) {
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
      // Если адрес не найден, показываем модальное окно
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        print('⏰ PostFrameCallback выполняется');

        // Дополнительная проверка что виджет еще mounted
        if (mounted) {
          print('✅ Виджет mounted, ждем 100ms');
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) {
            print('🎯 Показываем модальное окно');
            _showAddressSelectionModal();
          } else {
            print('❌ Виджет больше не mounted после задержки');
          }
        } else {
          print('❌ Виджет не mounted в PostFrameCallback');
        }
      });
    }
  }

  Future<void> _showAddressSelectionModal() async {
    print('🔥 _showAddressSelectionModal вызван');

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
        // Сохраняем в историю
        await AddressStorageService.addToAddressHistory({
          'name': selectedAddress['address'],
          'point': {
            'lat': selectedAddress['lat'],
            'lon': selectedAddress['lon']
          }
        });
        setState(() {
          _selectedAddress = selectedAddress;
        });

        // Отмечаем, что приложение уже запускалось
        await AddressStorageService.markAsLaunched();
        print('✅ Приложение отмечено как запущенное');

        // Уведомляем родительский виджет об изменении адреса
        //widget.onAddressChangeRequested(); // убираем автоматическое открытие выбора магазина

        // Автоматически выбираем ближайший магазин
        _autoSelectNearestBusiness();
      } else {
        print('ℹ️ Адрес не выбран или виджет не mounted');
      }
    } catch (e) {
      print('❌ Ошибка при показе модального окна выбора адреса: $e');
    }
  }

  /// Показывает модальное окно с выбором магазина
  void _showBusinessSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        color: Theme.of(context).colorScheme.surfaceDim,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade300,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Отмена'),
                  ),
                  const Text(
                    'Выберите магазин',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 80), // Балансировка кнопки
                ],
              ),
            ),
            Expanded(
              child: widget.isLoadingBusinesses
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : Builder(
                      builder: (context) {
                        // Создаем список магазинов с расстояниями для сортировки
                        List<Map<String, dynamic>> businessesWithDistance =
                            widget.businesses.map((business) {
                          final distance = _selectedAddress != null &&
                                  _selectedAddress!['lat'] != null &&
                                  _selectedAddress!['lon'] != null
                              ? _calculateDistanceFromCoords(
                                  business,
                                  _selectedAddress!['lat'].toDouble(),
                                  _selectedAddress!['lon'].toDouble(),
                                )
                              : _calculateDistance(business);

                          return {
                            ...business,
                            'calculatedDistance': distance,
                          };
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
                            final isSelected = widget.selectedBusiness?['id'] ==
                                business['id'];

                            return Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade300,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: TextButton(
                                onPressed: () {
                                  _handleBusinessSelection(business);
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    business['name'] ??
                                                        'Без названия',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: isSelected
                                                          ? Theme.of(context)
                                                              .colorScheme
                                                              .primary
                                                          : Theme.of(context)
                                                              .colorScheme
                                                              .onSurface,
                                                    ),
                                                  ),
                                                ),
                                                if (distance != null &&
                                                    _selectedAddress != null &&
                                                    _selectedAddress!['lat'] !=
                                                        null)
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            left: 8),
                                                    child: Icon(
                                                      Icons.near_me,
                                                      size: 16,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .primary,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            if (business['address'] != null)
                                              Text(
                                                business['address'],
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          if (distance != null)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '${(distance / 1000).toStringAsFixed(1)} км',
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          if (isSelected)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 4),
                                              child: Icon(
                                                Icons.check_circle,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
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
    if (_selectedAddress != null &&
        _selectedAddress!['lat'] != null &&
        _selectedAddress!['lon'] != null) {
      distance = _calculateDistanceFromCoords(
        widget.selectedBusiness!,
        _selectedAddress!['lat'].toDouble(),
        _selectedAddress!['lon'].toDouble(),
      );
    } else {
      distance = _calculateDistance(widget.selectedBusiness!);
    }

    if (distance == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.near_me,
            size: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            '${(distance / 1000).toStringAsFixed(1)} км',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
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
          SliverAppBar(
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            forceElevated: false,
            toolbarHeight: 56,
            titleSpacing: 12,
            title: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SearchPage(),
                  ),
                );
              },
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Поиск товаров',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (widget.selectedBusiness != null) ...[
                    _buildPromotionsHeroCarousel(),
                  ],
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Доставка по адресу',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _selectedAddress != null
                                            ? _selectedAddress!['address']
                                            : 'Выберите адрес доставки',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          height: 1.15,
                                        ),
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
                          onTap: widget.businesses.isNotEmpty &&
                                  !widget.isLoadingBusinesses
                              ? _showBusinessSelector
                              : null,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (widget.isLoadingBusinesses)
                                        Text(
                                          'Загрузка магазинов...',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondary
                                                .withOpacity(0.8),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.2,
                                          ),
                                        )
                                      else if (selectedBusiness != null) ...[
                                        Text(
                                          'Магазин',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondary
                                                .withOpacity(0.8),
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
                                                selectedBusiness['name'] ??
                                                    'Магазин',
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface,
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
                                        if (selectedBusiness['address'] !=
                                            null) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            selectedBusiness['address'],
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Магазин для заказа',
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .secondary
                                                    .withOpacity(0.8),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Выберите магазин',
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
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
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondary
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.keyboard_arrow_down,
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                    size: 18,
                                  ),
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
                  if (_bonusData != null && _bonusData!['success'] == true) ...[
                    const SizedBox(height: 12),
                    _buildBonusCard(),
                  ],

                  // Категории товаров
                  if (_categories.isNotEmpty ||
                      _isLoadingCategories ||
                      _categoriesError != null) ...[
                    const SizedBox(height: 12),
                    _buildCategoriesSection(),
                  ],

                  // Активные заказы
                  if (_activeOrders.isNotEmpty ||
                      _isLoadingActiveOrders ||
                      _activeOrdersError != null) ...[
                    const SizedBox(height: 12),
                    _buildActiveOrdersSection(),
                  ],
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: const SizedBox(height: 500),
          ),
        ],
      ),
    );
  }

  /// Строит секцию с активными заказами
  Widget _buildActiveOrdersSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  "Активные заказы",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoadingActiveOrders)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 12),
                      Text('Загрузка заказов...'),
                    ],
                  ),
                ),
              )
            else if (_activeOrdersError != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _activeOrdersError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loadActiveOrders,
                        child: const Text('Повторить'),
                      ),
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
                      Icon(
                        Icons.receipt_long_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'У вас нет активных заказов',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (int i = 0; i < _activeOrders.length; i++)
                    _buildActiveOrderCard(_activeOrders[i], i),
                ],
              ),
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
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => OrderDetailPage(
              order: order,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin:
            EdgeInsets.only(bottom: index < _activeOrders.length - 1 ? 12 : 0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
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
                      Text(
                        'Заказ #${order['order_id']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (business != null)
                        Text(
                          business['name'] ?? 'Неизвестный магазин',
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  if (currentStatus != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _parseColor(currentStatus['status_color'])
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _parseColor(currentStatus['status_color']),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        currentStatus['status_description'] ?? 'Неизвестно',
                        style: TextStyle(
                          color: _parseColor(currentStatus['status_color']),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Информация о доставке
              if (deliveryAddress != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        deliveryAddress["address_id"] == 1
                            ? 'Самовывоз'
                            : (deliveryAddress['address'] ?? 'Адрес не указан'),
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
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
                    Icon(
                      Icons.shopping_bag,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Товаров: ${itemsSummary['items_count'] ?? 0} (${itemsSummary['total_amount'] ?? 0} шт.)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок секции

        // Hero карусель
        SizedBox(
          height: 150, // Высота hero баннеров
          child: _buildPromotionsCarousel(),
        ),
      ],
    );
  }

  /// Строит карусель акций
  Widget _buildPromotionsCarousel() {
    if (_isLoadingPromotions) {
      return const Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 12),
            Text('Загрузка акций...'),
          ],
        ),
      );
    }

    if (_promotionsError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              'Ошибка загрузки акций',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadPromotions,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_promotions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_offer_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'В данный момент нет активных акций',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Горизонтальная карусель акций
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 0),
      itemCount: _promotions.length,
      itemBuilder: (context, index) {
        return Container(
          // width: MediaQuery.of(context).size.width *
          //     0.6, // Ширина каждого hero баннера
          // margin:
          //     EdgeInsets.only(right: index < _promotions.length - 1 ? 16 : 0),
          child: _buildPromotionHeroBanner(_promotions[index], index),
        );
      },
    );
  }

  /// Строит hero баннер акции
  Widget _buildPromotionHeroBanner(Promotion promotion, int index) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: InkWell(
          onTap: () {
            // Определяем ID магазина для передачи в страницу товаров акции
            final int? bizId = widget.selectedBusiness != null
                ? (widget.selectedBusiness!['id'] as int?) ??
                    (widget.selectedBusiness!['businessId'] as int?)
                : null;

            if (bizId != null) {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PromotionItemsPage(
                  promotionId: promotion.marketingPromotionId,
                  promotionName: promotion.name,
                  businessId: bizId,
                ),
              ));
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  // BoxShadow(
                  //   color: Theme.of(context).colorScheme.primary.withAlpha(30),
                  //   blurRadius: 2,
                  //   offset: const Offset(0, 2),
                  // ),
                ],
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AspectRatio(
                      aspectRatio: 2 / 1,
                      child: Image.network(
                        promotion.cover ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Theme.of(context).colorScheme.surface,
                          child: Icon(
                            Icons.broken_image,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    promotion.name ?? 'Акция без названия',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ))),
    );
  }

  void _showBarcodeModal(String cardUuid) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: Text(
            'Бонусная карта',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          message: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'Номер карты: $cardUuid',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 20),
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(16),
                  child: BarcodeWidget(
                    barcode: Barcode.code128(),
                    data: cardUuid,
                    width: 250,
                    height: 80,
                    drawText: false,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  cardUuid,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
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
    final latestBonusAmount = bonusHistory != null && bonusHistory.isNotEmpty
        ? bonusHistory.first['amount'] ?? 0
        : 0;

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
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            // Иконка и название
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.card_giftcard,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Основная информация
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Бонусная карта',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Нажмите для показа штрихкода',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Баланс
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$totalBonuses ₸',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (latestBonusAmount > 0)
                  Text(
                    '+$latestBonusAmount ₸',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),

            // Стрелка
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 16,
            ),
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
              Icon(
                Icons.category,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                "Категории",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 8,
        ),

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
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 12),
            Text('Загрузка категорий...'),
          ],
        ),
      );
    }

    if (_categoriesError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              'Ошибка загрузки категорий',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadCategories,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Категории не найдены',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
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
        final businessId = widget.selectedBusiness?['id'] ??
            widget.selectedBusiness?['business_id'] ??
            widget.selectedBusiness?['businessId'];

        if (businessId != null) {
          // Создаем объект Category из данных
          final categoryObj = Category.fromJson(category);

          // Навигация в CategoryPage
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CategoryPage(
              category: categoryObj,
              allCategories:
                  _categories.map((cat) => Category.fromJson(cat)).toList(),
              businessId: businessId,
            ),
          ));
        } else {
          // Показываем сообщение если магазин не выбран
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Сначала выберите магазин'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
                  border: Border.all(
                    color:
                        Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.network(
                    category["img"] ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        iconAndColor['icon'],
                        color: iconAndColor['color'],
                        size: 24,
                      );
                    },
                  ),
                )),

            // Название категории
            Text(
              categoryName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
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
      return {
        'icon': Icons.wine_bar,
        'color': const Color(0xFFE91E63),
      };
    }

    // Сигареты
    if (lowerName.contains('сигарет') ||
        lowerName.contains('табак') ||
        lowerName.contains('курение')) {
      return {
        'icon': Icons.smoking_rooms,
        'color': const Color(0xFF9C27B0),
      };
    }

    // Сладости
    if (lowerName.contains('сладост') ||
        lowerName.contains('конфет') ||
        lowerName.contains('шоколад') ||
        lowerName.contains('торт') ||
        lowerName.contains('печенье')) {
      return {
        'icon': Icons.cake,
        'color': const Color(0xFF795548),
      };
    }

    // Напитки
    if (lowerName.contains('напитк') ||
        lowerName.contains('сок') ||
        lowerName.contains('вода') ||
        lowerName.contains('газировка') ||
        lowerName.contains('лимонад')) {
      return {
        'icon': Icons.local_drink,
        'color': const Color(0xFF2196F3),
      };
    }

    // Фрукты и овощи
    if (lowerName.contains('фрукт') ||
        lowerName.contains('овощ') ||
        lowerName.contains('ягод') ||
        lowerName.contains('зелен')) {
      return {
        'icon': Icons.eco,
        'color': const Color(0xFF4CAF50),
      };
    }

    // Снеки
    if (lowerName.contains('снек') ||
        lowerName.contains('чипс') ||
        lowerName.contains('сухарик') ||
        lowerName.contains('орех')) {
      return {
        'icon': Icons.lunch_dining,
        'color': const Color(0xFFFF9800),
      };
    }

    // Молочные продукты
    if (lowerName.contains('молочн') ||
        lowerName.contains('молоко') ||
        lowerName.contains('кефир') ||
        lowerName.contains('йогурт') ||
        lowerName.contains('сыр')) {
      return {
        'icon': Icons.local_cafe,
        'color': const Color(0xFF00BCD4),
      };
    }

    // Мясо и рыба
    if (lowerName.contains('мясо') ||
        lowerName.contains('рыба') ||
        lowerName.contains('колбас') ||
        lowerName.contains('сосиск')) {
      return {
        'icon': Icons.restaurant,
        'color': const Color(0xFFFF5722),
      };
    }

    // Хлеб и выпечка
    if (lowerName.contains('хлеб') ||
        lowerName.contains('выпечк') ||
        lowerName.contains('булочк') ||
        lowerName.contains('батон')) {
      return {
        'icon': Icons.bakery_dining,
        'color': const Color(0xFF8BC34A),
      };
    }

    // По умолчанию
    return {
      'icon': Icons.category,
      'color': Theme.of(context).colorScheme.primary,
    };
  }
}
