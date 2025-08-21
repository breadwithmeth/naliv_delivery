import 'package:flutter/material.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:provider/provider.dart';
import '../utils/cart_provider.dart';
import 'package:naliv_delivery/utils/address_storage_service.dart';
import 'package:naliv_delivery/widgets/address_selection_modal_material.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/pages/payment_method_page.dart';

class CheckoutPage extends StatefulWidget {
  static const routeName = '/checkout';
  const CheckoutPage({Key? key}) : super(key: key);

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  bool _useBonus = false;
  Map<String, dynamic>? _selectedAddress;
  List<Map<String, dynamic>>? _userCards;
  Map<String, dynamic>? _selectedCard;
  Map<String, dynamic>? _deliveryData;
  Map<String, dynamic>? _bonusData;
  // Тип доставки: DELIVERY, PICKUP, SCHEDULED
  String _deliveryType = 'DELIVERY';
  // Время доставки: NOW или конкретное время
  String _deliveryTime = 'NOW';
  DateTime? _selectedDeliveryDateTime;
  bool _isCreatingOrder = false;

  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _bonusesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initAddressSelection();
    _loadUserCards();
    _loadUserBonuses();
  }

  Future<void> _initAddressSelection() async {
    final address = await AddressStorageService.getSelectedAddress();
    if (mounted && address != null) {
      setState(() {
        _selectedAddress = address;
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) _showAddressSelectionModal();
        }
      });
    }
    _calculateDelivery();
  }

  Future<void> _loadUserCards() async {
    if (await ApiService.isUserLoggedIn()) {
      final cards = await ApiService.getUserCards();
      if (mounted) {
        setState(() {
          _userCards = cards;
        });
      }
    }
  }

  Future<void> _loadUserBonuses() async {
    if (await ApiService.isUserLoggedIn()) {
      final bonuses = await ApiService.getUserBonuses();
      if (mounted) {
        setState(() {
          _bonusData = bonuses;
        });
      }
    }
  }

  Future<void> _showAddressSelectionModal() async {
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 300));
    final selected = await AddressSelectionModalHelper.show(context);
    if (mounted && selected != null) {
      setState(() {
        _selectedAddress = selected;
        _deliveryData = null;
      });
      await AddressStorageService.markAsLaunched();
      // Рассчитываем доставку по новому адресу
      _calculateDelivery();
    }
  }

  Future<void> _submitOrder() async {
    // Проверяем авторизацию
    final loggedIn = await ApiService.isUserLoggedIn();
    if (!loggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, авторизуйтесь')),
      );
      return;
    }

    // TODO: Собрать тело заказа из выбранного адреса и корзины
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final businessProvider =
        Provider.of<BusinessProvider>(context, listen: false);
    if (businessProvider.selectedBusiness == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите магазин')),
      );
      return;
    }
    final body = <String, dynamic>{
      'business_id': businessProvider.selectedBusiness!['id'],
      'street':
          _selectedAddress?['street'] ?? _selectedAddress?['address'] ?? '',
      'house': _selectedAddress?['house'] ?? '-',
      'lat': _selectedAddress?['lat'] ?? 0.0,
      'lon': _selectedAddress?['lon'] ?? 0.0,
      'items': cartProvider.items.map((item) => item.toJsonForOrder()).toList(),
      'delivery_type': _deliveryType,
      'delivery_time': _deliveryTime,
      'total_amount': _getTotalWithDelivery(),
      'use_bonuses': _useBonus,
      if (_useBonus) 'bonus_amount': _getUsedBonuses(),
      if (_selectedDeliveryDateTime != null)
        'scheduled_time': _selectedDeliveryDateTime!.toIso8601String(),
      'saved_card_id': 1,
    };
    print('Заказ: $body');
    final result = await ApiService.createUserOrder(body);

    setState(() {
      _isCreatingOrder = false;
    });

    if (result['success'] == true) {
      final orderData = result['data'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Заказ создан: ID ${orderData['order_id']}')),
      );
      // Переход на страницу выбора способа оплаты
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentMethodPage(orderData: orderData),
        ),
      );
    } else {
      final errorMessage =
          result['error'] is Map ? result['error']['message'] : result['error'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка создания заказа: $errorMessage')),
      );
    }
  }

  /// Рассчитать стоимость доставки по адресу
  Future<void> _calculateDelivery() async {
    print(_selectedAddress);
    if (_selectedAddress == null) return;
    print("адрес выбран");
    final businessProvider =
        Provider.of<BusinessProvider>(context, listen: false);
    if (businessProvider.selectedBusiness == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите магазин')),
      );
      return;
    }
    // Предполагаем, что в _selectedAddress есть ключ 'address_id'
    final businessId = businessProvider.selectedBusiness!['id'];
    final data = await ApiService.calculateDeliveryByAddress(
      businessId: businessId,
      lat: _selectedAddress!['lat'],
      lon: _selectedAddress!['lon'],
    );
    print("Доставка рассчитана: $data");

    if (mounted) {
      setState(() {
        _deliveryData = data;
      });
    }
  }

  /// Показать диалог выбора времени доставки
  Future<void> _showDeliveryTimeSelection() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выберите время доставки'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Сейчас'),
              subtitle: const Text('Доставка в ближайшее время'),
              onTap: () => Navigator.pop(context, 'NOW'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Запланировать'),
              subtitle: const Text('Выберите дату и время'),
              onTap: () async {
                Navigator.pop(context);
                await _showDateTimePicker();
              },
            ),
            if (_deliveryTime != 'NOW' &&
                _selectedDeliveryDateTime != null) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.clear),
                title: const Text('Сбросить'),
                subtitle: const Text('Очистить выбранное время'),
                onTap: () => Navigator.pop(context, 'RESET'),
              ),
            ],
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        if (result == 'NOW') {
          _deliveryTime = 'NOW';
          _selectedDeliveryDateTime = null;
        } else if (result == 'RESET') {
          _deliveryTime = 'NOW';
          _selectedDeliveryDateTime = null;
        }
      });
    }
  }

  /// Показать выбор даты и времени
  Future<void> _showDateTimePicker() async {
    final now = DateTime.now();
    final maxDate = now.add(const Duration(days: 1));

    // Выбор даты
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: maxDate,
      helpText: 'Выберите дату доставки',
      cancelText: 'Отмена',
      confirmText: 'Далее',
      locale: const Locale('ru', 'RU'),
    );

    if (selectedDate == null || !mounted) return;

    // Выбор времени
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
      helpText: 'Выберите время доставки',
      cancelText: 'Отмена',
      confirmText: 'Готово',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: true,
          ),
          child: child!,
        );
      },
    );

    if (selectedTime == null || !mounted) return;

    final selectedDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    // Проверяем, что выбранное время не в прошлом
    if (selectedDateTime.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нельзя выбрать время в прошлом'),
        ),
      );
      return;
    }

    // Проверяем, что время в пределах 24 часов
    if (selectedDateTime.isAfter(now.add(const Duration(hours: 24)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Доставка возможна только в течение 24 часов'),
        ),
      );
      return;
    }

    setState(() {
      _deliveryTime = 'SCHEDULED';
      _selectedDeliveryDateTime = selectedDateTime;
    });
  }

  String _getDeliveryTimeText() {
    if (_deliveryTime == 'NOW') {
      return 'Сейчас';
    } else if (_selectedDeliveryDateTime != null) {
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));

      String dateText;
      if (_selectedDeliveryDateTime!.day == today.day &&
          _selectedDeliveryDateTime!.month == today.month) {
        dateText = 'Сегодня';
      } else if (_selectedDeliveryDateTime!.day == tomorrow.day &&
          _selectedDeliveryDateTime!.month == tomorrow.month) {
        dateText = 'Завтра';
      } else {
        dateText =
            '${_selectedDeliveryDateTime!.day}.${_selectedDeliveryDateTime!.month.toString().padLeft(2, '0')}';
      }

      final timeText =
          '${_selectedDeliveryDateTime!.hour.toString().padLeft(2, '0')}:${_selectedDeliveryDateTime!.minute.toString().padLeft(2, '0')}';
      return '$dateText в $timeText';
    }
    return 'Выберите время';
  }

  /// Получить итоговую сумму с учетом доставки
  double _getTotalWithDelivery() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final cartTotal = cartProvider.getTotalPrice();

    double total = cartTotal;

    // Добавляем стоимость доставки
    if (_deliveryType == 'DELIVERY' && _deliveryData != null) {
      final deliveryCost =
          (_deliveryData!['delivery_cost'] as num?)?.toDouble() ?? 0.0;
      total += deliveryCost;
    }

    // Вычитаем бонусы если они используются
    if (_useBonus && _bonusData != null && _bonusData!['success'] == true) {
      final availableBonuses =
          (_bonusData!['data']['totalBonuses'] as num?)?.toDouble() ?? 0.0;
      final bonusToUse = availableBonuses > total ? total : availableBonuses;
      total -= _getUsedBonuses();
    }

    return total;
  }

  /// Получить сумму использованных бонусов
  double _getUsedBonuses() {
    if (!_useBonus || _bonusData == null || _bonusData!['success'] != true) {
      return 0.0;
    }

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final cartTotal = cartProvider.getTotalPrice();

    double total = cartTotal;
    if (_deliveryType == 'DELIVERY' && _deliveryData != null) {
      final deliveryCost =
          (_deliveryData!['delivery_cost'] as num?)?.toDouble() ?? 0.0;
      total += deliveryCost;
    }

    // Максимум 25% от суммы заказа можно оплатить бонусами
    final maxBonusUsage = total * 0.25;
    final availableBonuses =
        (_bonusData!['data']['totalBonuses'] as num?)?.toDouble() ?? 0.0;

    // Возвращаем меньшее из: доступные бонусы, максимально допустимое использование (25%), или полная сумма
    return [availableBonuses, maxBonusUsage, total]
        .reduce((a, b) => a < b ? a : b);
  }

  /// Построить подзаголовок с информацией о бонусах
  Widget _buildBonusSubtitle() {
    if (_bonusData == null || _bonusData!['success'] != true) {
      return const Text('Загрузка...');
    }

    final bonusData = _bonusData!['data'];
    final totalBonuses = bonusData['totalBonuses'] ?? 0;

    // Получаем последнее значение из истории бонусов
    final bonusHistory = bonusData['bonusHistory'] as List?;
    final latestBonusAmount = bonusHistory != null && bonusHistory.isNotEmpty
        ? bonusHistory.first['amount'] ?? 0
        : 0;
    final latestBonusDate = bonusHistory != null && bonusHistory.isNotEmpty
        ? bonusHistory.first['timestamp'] ?? ''
        : '';

    // Рассчитываем максимальную сумму для использования бонусов (25% от заказа)
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final cartTotal = cartProvider.getTotalPrice();
    double orderTotal = cartTotal;
    if (_deliveryType == 'DELIVERY' && _deliveryData != null) {
      final deliveryCost =
          (_deliveryData!['delivery_cost'] as num?)?.toDouble() ?? 0.0;
      orderTotal += deliveryCost;
    }
    final maxBonusUsage = orderTotal * 0.25;
    final availableToUse =
        totalBonuses > maxBonusUsage ? maxBonusUsage : totalBonuses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Доступно: $totalBonuses бонусов'),
        if (orderTotal > 0)
          Text(
            'Можно использовать: ${availableToUse.toStringAsFixed(0)} ₸ ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        if (latestBonusAmount > 0)
          Text(
            'Последнее: +$latestBonusAmount ₸ ${_formatBonusDate(latestBonusDate)}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
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
        return '(сегодня)';
      } else if (difference.inDays == 1) {
        return '(вчера)';
      } else if (difference.inDays < 7) {
        return '(${difference.inDays} дн. назад)';
      } else {
        return '(${date.day}.${date.month.toString().padLeft(2, '0')})';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final businessProvider = Provider.of<BusinessProvider>(context);
    final total = cartProvider.getTotalPrice();
    return Scaffold(
      appBar: AppBar(title: const Text('Оформление заказа')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Отображение выбранного магазина
            if (businessProvider.selectedBusiness != null)
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.store,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(businessProvider.selectedBusinessName ??
                      'Неизвестный магазин'),
                  subtitle: Text(
                      businessProvider.selectedBusiness!["address"] ??
                          'Неизвестный магазин'),
                  // trailing: const Icon(Icons.keyboard_arrow_right),
                  // onTap: () {
                  //   // Возвращаемся на главную страницу для смены магазина
                  //   Navigator.of(context).pop();
                  // },
                ),
              ),
            if (businessProvider.selectedBusiness != null)
              const SizedBox(height: 16),

            Row(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: ToggleButtons(
                      renderBorder: true,
                      isSelected: [
                        _deliveryType == 'DELIVERY',
                        _deliveryType == 'PICKUP',
                      ],
                      onPressed: (index) {
                        const options = ['DELIVERY', 'PICKUP'];
                        setState(() {
                          _deliveryType = options[index];
                        });
                      },
                      borderRadius: BorderRadius.circular(800),
                      selectedBorderColor:
                          Theme.of(context).colorScheme.secondary,
                      borderColor: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5),
                      selectedColor: Theme.of(context).colorScheme.onPrimary,
                      fillColor: Theme.of(context).colorScheme.secondary,
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Доставка',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Самовывоз',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: const Text('Адрес доставки'),
                subtitle:
                    Text(_selectedAddress?['address'] ?? 'Адрес не выбран'),
                trailing: const Icon(Icons.keyboard_arrow_right),
                onTap: _showAddressSelectionModal,
              ),
            ),
            const SizedBox(height: 16),

            const SizedBox(height: 24),
            // Показать информацию о доставке, если рассчитана
            _deliveryType == 'DELIVERY' && _deliveryData != null
                ? Card(
                    child: ListTile(
                      title: const Text('Стоимость доставки'),
                      subtitle: Text(
                        '${_deliveryData!['delivery_cost']} ₸',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),

            // Выбор времени доставки
            if (_deliveryType == 'DELIVERY')
              Card(
                child: ListTile(
                  title: const Text('Время доставки'),
                  subtitle: Text(_getDeliveryTimeText()),
                  trailing: const Icon(Icons.keyboard_arrow_right),
                  onTap: _showDeliveryTimeSelection,
                ),
              ),
            // Выбор типа доставки

            // Горизонтальная прокрутка для кнопок доставки

            const SizedBox(height: 16),
            // if (_userCards != null)
            //   Card(
            //     child: ListTile(
            //       title: const Text('Способ оплаты'),
            //       subtitle: Text(_selectedCard != null
            //           ? _selectedCard!['mask']
            //           : 'Выберите карту'),
            //       onTap: () async {
            //         if (_userCards == null || _userCards!.isEmpty) return;
            //         final choice = await showDialog<Map<String, dynamic>>(
            //           context: context,
            //           builder: (_) => SimpleDialog(
            //             title: const Text('Выберите карту'),
            //             children: _userCards!
            //                 .map((card) => SimpleDialogOption(
            //                       onPressed: () => Navigator.pop(context, card),
            //                       child: Text(card['mask']),
            //                     ))
            //                 .toList(),
            //           ),
            //         );
            //         if (choice != null) {
            //           setState(() {
            //             _selectedCard = choice;
            //           });
            //         }
            //       },
            //     ),
            //   ),
            const Text(
              'Товары в корзине',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...cartProvider.items.map((item) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(item.name),
                  subtitle: Text(
                      'x${item.stepQuantity == 1.0 ? item.quantity.toStringAsFixed(0) : item.quantity.toStringAsFixed(2)}'),
                  trailing: Text('${item.totalPrice.toStringAsFixed(0)} ₸'),
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Row(
                children: [
                  const Text('Использовать бонусы'),
                  if (_bonusData != null && _bonusData!['success'] == true) ...[
                    const SizedBox(width: 8),
                    // Container(
                    //   padding: const EdgeInsets.symmetric(
                    //       horizontal: 8, vertical: 2),
                    //   decoration: BoxDecoration(
                    //     color: Theme.of(context)
                    //         .colorScheme
                    //         .primary
                    //         .withOpacity(0.1),
                    //     borderRadius: BorderRadius.circular(12),
                    //     border: Border.all(
                    //       color: Theme.of(context)
                    //           .colorScheme
                    //           .primary
                    //           .withOpacity(0.3),
                    //     ),
                    //   ),
                    //   child: Text(
                    //     '${_bonusData!['data']['totalBonuses']} ₸',
                    //     style: TextStyle(
                    //       fontSize: 12,
                    //       fontWeight: FontWeight.w600,
                    //       color: Theme.of(context).colorScheme.primary,
                    //     ),
                    //   ),
                    // ),
                  ],
                ],
              ),
              subtitle: _bonusData != null && _bonusData!['success'] == true
                  ? _buildBonusSubtitle()
                  : const Text('Загрузка...'),
              value: _useBonus,
              onChanged: _bonusData != null && _bonusData!['success'] == true
                  ? (value) {
                      setState(() {
                        _useBonus = value;
                      });
                    }
                  : null,
            ),
            const SizedBox(height: 16),
            // Показать итоговую сумму с разбивкой
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Товары:'),
                        Text('${total.toStringAsFixed(0)} ₸'),
                      ],
                    ),
                    if (_deliveryType == 'DELIVERY' &&
                        _deliveryData != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Доставка:'),
                          Text('${_deliveryData!['delivery_cost']} ₸'),
                        ],
                      ),
                    ],
                    if (_useBonus && _getUsedBonuses() > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Бонусы:',
                            style: TextStyle(color: Colors.green),
                          ),
                          Text(
                            '-${_getUsedBonuses().toStringAsFixed(0)} ₸',
                            style: const TextStyle(color: Colors.green),
                          ),
                        ],
                      ),
                    ],
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Итого:',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_getTotalWithDelivery().toStringAsFixed(0)} ₸',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _submitOrder,
              child: const Text('Подтвердить заказ'),
            ),
          ], // end children
        ), // end Column
      ), // end SingleChildScrollView
    ); // end Scaffold
  }
}
