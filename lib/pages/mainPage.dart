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
import '../shared/product_card.dart';
import '../model/item.dart' as ItemModel;
import 'promotion_items_page.dart';
import 'order_detail_page.dart';

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
  // Индексы раскрытых акций
  final Set<int> _expandedPromo = {};

  // Состояние для бонусов
  Map<String, dynamic>? _bonusData;

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
      } else {
        // Очищаем акции если магазин не выбран
        setState(() {
          _promotions = [];
          _isLoadingPromotions = false;
          _promotionsError = null;
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
            expandedHeight: 120,
            // backgroundColor: Theme.of(context).colorScheme.surface,
            actions: [
              // IconButton(
              //   icon: Icon(
              //     Icons.edit_location,
              //     color: Theme.of(context).colorScheme.onSurface,
              //   ),
              //   onPressed: _showAddressSelectionModal,
              // ),
            ],
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                var top = constraints.biggest.height;
                bool isCollapsed =
                    top <= kToolbarHeight + MediaQuery.of(context).padding.top;
                return FlexibleSpaceBar(
                  // Иконка в заголовке при свёрнутом AppBar
                  title: isCollapsed ? const Icon(Icons.location_on) : null,
                  background: Container(
                    decoration: BoxDecoration(
                        // gradient: LinearGradient(
                        //   colors: [
                        //     Theme.of(context)
                        //         .colorScheme
                        //         .primary
                        //         .withOpacity(0.2),
                        //     Colors.transparent,
                        //   ],
                        //   begin: Alignment.topCenter,
                        //   end: Alignment.bottomCenter,
                        // ),
                        ),
                    child: Align(
                        alignment: Alignment.bottomLeft,
                        child: GestureDetector(
                          onTap: _showAddressSelectionModal,
                          child: Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceVariant
                                .withOpacity(0.9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedAddress != null
                                          ? '${_selectedAddress!['address']}${(_selectedAddress!['apartment'] ?? '').isNotEmpty ? ', кв. ${_selectedAddress!['апартамент']}' : ''}${(_selectedAddress!['entrance'] ?? '').isNotEmpty ? ', пд. ${_selectedAddress!['entrance']}' : ''}'
                                          : 'Ваш адрес',
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )),
                  ),
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Секция выбранного магазина
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Выбранный магазин",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (widget.isLoadingBusinesses)
                            const Row(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(width: 8),
                                Text('Загрузка магазинов...'),
                              ],
                            )
                          else if (selectedBusiness != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        selectedBusiness['name'] ??
                                            'Без названия',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    _buildDistanceInfo(),
                                  ],
                                ),
                                if (selectedBusiness['address'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      selectedBusiness['address'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          else
                            Text(
                              'Магазин не выбран',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    foregroundColor:
                                        Theme.of(context).colorScheme.onPrimary,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: widget.businesses.isNotEmpty &&
                                          !widget.isLoadingBusinesses
                                      ? _showBusinessSelector
                                      : null,
                                  icon: const Icon(Icons.store, size: 18),
                                  label: const Text('Выбрать магазин'),
                                ),
                              ),
                              if (selectedBusiness != null) ...[
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHigh,
                                    foregroundColor:
                                        Theme.of(context).colorScheme.onSurface,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline
                                            .withOpacity(0.3),
                                      ),
                                    ),
                                  ),
                                  onPressed: _showBusinessSelector,
                                  child: const Icon(Icons.swap_horiz, size: 18),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Бонусная карта
                  if (_bonusData != null && _bonusData!['success'] == true) ...[
                    const SizedBox(height: 16),
                    _buildBonusCard(),
                  ],

                  // Активные заказы
                  if (_activeOrders.isNotEmpty ||
                      _isLoadingActiveOrders ||
                      _activeOrdersError != null) ...[
                    const SizedBox(height: 16),
                    _buildActiveOrdersSection(),
                  ],

                  // Секция акций
                  if (widget.selectedBusiness != null) ...[
                    const SizedBox(height: 16),
                    _buildPromotionsSection(),
                  ],
                ],
              ),
            ),
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
    final costSummary = order['cost_summary'] as Map<String, dynamic>?;

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
                        deliveryAddress['address'] ?? 'Адрес не указан',
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
              if (costSummary != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Сумма заказа:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${costSummary['total_sum']} ₸',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),

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

  /// Строит секцию с акциями
  Widget _buildPromotionsSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_offer,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  "Акции и предложения",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoadingPromotions)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 12),
                      Text('Загрузка акций...'),
                    ],
                  ),
                ),
              )
            else if (_promotionsError != null)
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
                        _promotionsError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loadPromotions,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_promotions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
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
                ),
              )
            else
              Column(
                children: [
                  // Показываем до 3 акций
                  for (int i = 0; i < _promotions.length && i < 3; i++)
                    _buildPromotionCard(_promotions[i], i),

                  if (_promotions.length > 3) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          // TODO: Открыть страницу всех акций
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Переход к странице всех акций'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: Text('Смотреть все (${_promotions.length})'),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Строит карточку акции
  Widget _buildPromotionCard(Promotion promotion, int index) {
    return InkWell(
      onTap: () {
        // Определяем ID магазина для передачи в страницу товаров акции
        final int? bizId = widget.selectedBusiness != null
            ? (widget.selectedBusiness!['id'] as int?) ??
                (widget.selectedBusiness!['businessId'] as int?)
            : null;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PromotionItemsPage(
            promotionId: promotion.marketingPromotionId,
            promotionName: promotion.name,
            businessId: bizId!,
          ),
        ));
      },
      child: Container(
        margin: EdgeInsets.only(bottom: index < 2 ? 12 : 0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Иконка или изображение акции
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.local_offer,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Информация об акции
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Название акции
                        Text(
                          promotion.name ?? 'Акция без названия',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),

                        // Количество товаров в акции
                        Text(
                          'Товаров в акции: ${promotion.itemsCount}',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Срок действия
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 12,
                              color: promotion.daysLeft <= 3
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              promotion.daysLeft == 0
                                  ? 'Последний день!'
                                  : promotion.daysLeft == 1
                                      ? 'Остался 1 день'
                                      : 'Осталось ${promotion.daysLeft} дней',
                              style: TextStyle(
                                fontSize: 12,
                                color: promotion.daysLeft <= 3
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                fontWeight: promotion.daysLeft <= 3
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Детали акции (если есть)
              if (promotion.details.isNotEmpty) ...[
                // Container(
                //   padding: const EdgeInsets.all(8),
                //   decoration: BoxDecoration(
                //     color: Theme.of(context)
                //         .colorScheme
                //         .primaryContainer
                //         .withValues(alpha: 0.3),
                //     borderRadius: BorderRadius.circular(6),
                //   ),
                //   child: Column(
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [
                //       for (int i = 0; i < promotion.details.length && i < 2; i++)
                //         Padding(
                //           padding: EdgeInsets.only(bottom: i < 1 ? 4 : 0),
                //           child: _buildPromotionDetail(promotion.details[i]),
                //         ),
                //       if (promotion.details.length > 2)
                //         Text(
                //           '... и еще ${promotion.details.length - 2}',
                //           style: TextStyle(
                //             fontSize: 11,
                //             color: Theme.of(context).colorScheme.onSurfaceVariant,
                //             fontStyle: FontStyle.italic,
                //           ),
                //         ),
                //     ],
                //   ),
                // ),
                // Товары в акции
                // Товары в акции: показываем 2 или все в Wrap
                Builder(
                  builder: (context) {
                    final details = promotion.details;
                    final isExpanded = _expandedPromo.contains(index);
                    final visibleCount = isExpanded
                        ? details.length
                        : (details.length < 2 ? details.length : 2);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(visibleCount, (i) {
                            final detail = details[i];
                            if (detail.item != null) {
                              return SizedBox(
                                width: 150,
                                height: 250,
                                child: ProductCard(
                                  item: ItemModel.Item.fromJson(
                                      detail.item!.toJson()),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          }),
                        ),
                        if (details.length > 2)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  if (isExpanded)
                                    _expandedPromo.remove(index);
                                  else
                                    _expandedPromo.add(index);
                                });
                              },
                              child:
                                  Text(isExpanded ? 'Скрыть' : 'Показать все'),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

// ignore: unused_element
  Widget _buildPromotionDetail(PromotionDetail detail) {
    String detailText = '';
    IconData detailIcon = Icons.local_offer;

    switch (detail.type) {
      case 'DISCOUNT':
        if (detail.discount != null) {
          detailText =
              'Скидка ${detail.discount!.toStringAsFixed(0)}% на ${detail.name}';
          detailIcon = Icons.percent;
        }
        break;
      case 'SUBTRACT':
        if (detail.baseAmount != null && detail.addAmount != null) {
          detailText =
              '${detail.baseAmount} + ${detail.addAmount} = ${detail.baseAmount! + detail.addAmount!} ${detail.name}';
          detailIcon = Icons.add;
        }
        break;
      default:
        detailText = detail.name;
    }

    return Row(
      children: [
        Icon(
          detailIcon,
          size: 12,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            detailText,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Форматировать дату бонуса
  String _formatBonusDate(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Сегодня';
      } else if (difference.inDays == 1) {
        return 'Вчера';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} дн. назад';
      } else {
        return '${date.day}.${date.month.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '';
    }
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
    final latestBonusDate = bonusHistory != null && bonusHistory.isNotEmpty
        ? bonusHistory.first['timestamp'] ?? ''
        : '';

    return GestureDetector(
      onTap: () {
        if (cardUuid.isNotEmpty) {
          _showBarcodeModal(cardUuid);
        }
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Бонусная карта',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    Icons.card_giftcard,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Общий баланс',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimary
                                .withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '$totalBonuses ₸',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (latestBonusAmount > 0) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Последнее начисление',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimary
                                .withOpacity(0.8),
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          '+$latestBonusAmount ₸',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (latestBonusDate.isNotEmpty)
                          Text(
                            _formatBonusDate(latestBonusDate),
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimary
                                  .withOpacity(0.7),
                              fontSize: 9,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Номер карты',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        Icon(
                          Icons.qr_code,
                          size: 16,
                          color: Colors.grey[500],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cardUuid,
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Нажмите для показа штрихкода',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
