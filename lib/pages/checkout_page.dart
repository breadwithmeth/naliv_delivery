import 'package:flutter/material.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../utils/cart_provider.dart';
import 'package:naliv_delivery/utils/address_storage_service.dart';
import 'package:naliv_delivery/widgets/address_selection_modal_material.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/pages/payment_method_page.dart';
import 'package:naliv_delivery/services/sentry_service.dart';

class CheckoutPage extends StatefulWidget {
  static const routeName = '/checkout';
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  static const double _bonusUsageRate = 0.30;

  bool _useBonus = false;
  Map<String, dynamic>? _selectedAddress;
  Map<String, dynamic>? _deliveryData;
  Map<String, dynamic>? _bonusData;
  // Тип доставки: DELIVERY, PICKUP, SCHEDULED
  String _deliveryType = 'DELIVERY';
  // Время доставки: NOW или конкретное время
  String _deliveryTime = 'NOW';
  DateTime? _selectedDeliveryDateTime;

  @override
  void initState() {
    super.initState();
    _initAddressSelection();
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
    await SentryService.addBreadcrumb(category: 'checkout.address', message: 'Checkout address modal opened', data: const {'source': 'modal'});
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    final selected = await AddressSelectionModalHelper.show(context);
    if (mounted && selected != null) {
      setState(() {
        _selectedAddress = selected;
        _deliveryData = null;
      });
      // Сохраняем выбранный адрес со всеми деталями
      await AddressStorageService.saveSelectedAddress(selected);
      await AddressStorageService.markAsLaunched();
      // Рассчитываем доставку по новому адресу
      _calculateDelivery();
      await SentryService.addBreadcrumb(
        category: 'checkout.address',
        message: 'Checkout address selected',
        data: const {'source': 'modal', 'selection_result': 'selected'},
      );
    } else {
      await SentryService.addBreadcrumb(
        category: 'checkout.address',
        message: 'Checkout address modal dismissed',
        data: const {'source': 'modal', 'selection_result': 'dismissed'},
      );
    }
  }

  Future<void> _submitOrder() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final appliedBonusAmount = _getUsedBonuses();

    // Проверяем авторизацию
    final loggedIn = await ApiService.isUserLoggedIn();
    if (!mounted) return;
    if (!loggedIn) {
      messenger.showSnackBar(const SnackBar(content: Text('Пожалуйста, авторизуйтесь')));
      return;
    }

    // TODO: Собрать тело заказа из выбранного адреса и корзины
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
    if (businessProvider.selectedBusiness == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Пожалуйста, выберите магазин')));
      return;
    }
    final body = <String, dynamic>{
      'business_id': businessProvider.selectedBusiness!['id'],
      'street': _selectedAddress?['street'] ?? _selectedAddress?['address'] ?? '',
      'house': _selectedAddress?['house'] ?? '-',
      'lat': _selectedAddress?['lat'] ?? 0.0,
      'lon': _selectedAddress?['lon'] ?? 0.0,
      'apartment': _selectedAddress?['apartment'] ?? '',
      'entrance': _selectedAddress?['entrance'] ?? '',
      'floor': _selectedAddress?['floor'] ?? '',
      'extra': _selectedAddress?['comment'] ?? '',
      'items': cartProvider.items.map((item) => item.toJsonForOrder()).toList(),
      'delivery_type': _deliveryType,
      'delivery_time': _deliveryTime,
      'total_amount': _getTotalWithDelivery(),
      'use_bonuses': _useBonus,
      if (_useBonus) 'bonus_amount': appliedBonusAmount,
      if (_selectedDeliveryDateTime != null) 'scheduled_time': _selectedDeliveryDateTime!.toIso8601String(),
      'saved_card_id': 1,
    };
    await SentryService.addBreadcrumb(
      category: 'checkout',
      message: 'Checkout order submission started',
      data: {
        'items_count': cartProvider.items.length,
        'delivery_type': _deliveryType,
        'delivery_time': _deliveryTime,
        'use_bonuses': _useBonus,
        'bonus_amount': appliedBonusAmount,
        'has_scheduled_time': _selectedDeliveryDateTime != null,
      },
    );
    debugPrint('Заказ: $body');
    final result = await ApiService.createUserOrder(body);
    if (!mounted) return;

    if (result['success'] == true) {
      final orderData = result['data'];
      await SentryService.addBreadcrumb(
        category: 'checkout',
        message: 'Checkout order created successfully',
        data: const {'next_step': 'payment_method'},
      );
      messenger.showSnackBar(SnackBar(content: Text('Заказ создан: ID ${orderData['order_id']}')));
      // Переход на страницу выбора способа оплаты
      navigator.push(MaterialPageRoute(builder: (context) => PaymentMethodPage(orderData: orderData)));
    } else {
      await SentryService.addBreadcrumb(
        category: 'checkout',
        message: 'Checkout order creation returned failure',
        data: {'has_error': true, 'status_code': result['statusCode']},
        level: SentryLevel.warning,
        type: 'error',
      );
      final errorMessage = result['error'] is Map ? result['error']['message'] : result['error'];
      messenger.showSnackBar(SnackBar(content: Text('Ошибка создания заказа: $errorMessage')));
    }
  }

  /// Рассчитать стоимость доставки по адресу
  Future<void> _calculateDelivery() async {
    final messenger = ScaffoldMessenger.of(context);
    debugPrint('Selected address: $_selectedAddress');
    if (_selectedAddress == null) return;
    debugPrint('адрес выбран');
    final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
    if (businessProvider.selectedBusiness == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Пожалуйста, выберите магазин')));
      return;
    }
    // Предполагаем, что в _selectedAddress есть ключ 'address_id'
    final businessId = businessProvider.selectedBusiness!['id'];
    final data = await ApiService.calculateDeliveryByAddress(businessId: businessId, lat: _selectedAddress!['lat'], lon: _selectedAddress!['lon']);
    debugPrint('Доставка рассчитана: $data');

    if (!mounted) return;
    setState(() {
      _deliveryData = data;
    });
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
            if (_deliveryTime != 'NOW' && _selectedDeliveryDateTime != null) ...[
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
        return MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!);
      },
    );

    if (selectedTime == null || !mounted) return;

    final selectedDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);

    // Проверяем, что выбранное время не в прошлом
    if (selectedDateTime.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нельзя выбрать время в прошлом')));
      return;
    }

    // Проверяем, что время в пределах 24 часов
    if (selectedDateTime.isAfter(now.add(const Duration(hours: 24)))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Доставка возможна только в течение 24 часов')));
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
      if (_selectedDeliveryDateTime!.day == today.day && _selectedDeliveryDateTime!.month == today.month) {
        dateText = 'Сегодня';
      } else if (_selectedDeliveryDateTime!.day == tomorrow.day && _selectedDeliveryDateTime!.month == tomorrow.month) {
        dateText = 'Завтра';
      } else {
        dateText = '${_selectedDeliveryDateTime!.day}.${_selectedDeliveryDateTime!.month.toString().padLeft(2, '0')}';
      }

      final timeText =
          '${_selectedDeliveryDateTime!.hour.toString().padLeft(2, '0')}:${_selectedDeliveryDateTime!.minute.toString().padLeft(2, '0')}';
      return '$dateText в $timeText';
    }
    return 'Выберите время';
  }

  double _getCartItemsTotal() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    return cartProvider.getTotalPrice();
  }

  double _getDeliveryCost() {
    if (_deliveryType != 'DELIVERY' || _deliveryData == null) {
      return 0.0;
    }

    return (_deliveryData!['delivery_cost'] as num?)?.toDouble() ?? 0.0;
  }

  double _getAvailableBonuses() {
    if (_bonusData == null || _bonusData!['success'] != true) {
      return 0.0;
    }

    return (_bonusData!['data']['totalBonuses'] as num?)?.toDouble() ?? 0.0;
  }

  double _getMaxBonusUsageFromCart() {
    final cartItemsTotal = _getCartItemsTotal();
    if (cartItemsTotal <= 0) {
      return 0.0;
    }

    return cartItemsTotal * _bonusUsageRate;
  }

  /// Получить итоговую сумму с учетом доставки
  double _getTotalWithDelivery() {
    double total = _getCartItemsTotal();

    // Добавляем стоимость доставки
    total += _getDeliveryCost();

    // Вычитаем бонусы если они используются
    if (_useBonus && _bonusData != null && _bonusData!['success'] == true) {
      total -= _getUsedBonuses();
    }

    return total;
  }

  /// Получить сумму использованных бонусов
  double _getUsedBonuses() {
    if (!_useBonus) {
      return 0.0;
    }

    final cartItemsTotal = _getCartItemsTotal();
    final availableBonuses = _getAvailableBonuses();
    final maxBonusUsage = _getMaxBonusUsageFromCart();

    if (cartItemsTotal <= 0 || availableBonuses <= 0 || maxBonusUsage <= 0) {
      return 0.0;
    }

    // Бонусы можно списать только с товаров: не более 30% стоимости корзины, без доставки.
    final appliedBonuses = [availableBonuses, maxBonusUsage, cartItemsTotal].reduce((a, b) => a < b ? a : b);

    return appliedBonuses.floorToDouble();
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
    final latestBonusAmount = bonusHistory != null && bonusHistory.isNotEmpty ? bonusHistory.first['amount'] ?? 0 : 0;
    final latestBonusDate = bonusHistory != null && bonusHistory.isNotEmpty ? bonusHistory.first['timestamp'] ?? '' : '';

    final cartItemsTotal = _getCartItemsTotal();
    final maxBonusUsage = _getMaxBonusUsageFromCart();
    final availableToUse = _getUsedBonuses();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Доступно: $totalBonuses бонусов'),
        if (cartItemsTotal > 0)
          Text(
            'Можно использовать: ${availableToUse.toStringAsFixed(0)} ₸ (30% от товаров, доставка не учитывается)',
            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
        if (maxBonusUsage > 0)
          Text(
            'Лимит списания с корзины: ${maxBonusUsage.floorToDouble().toStringAsFixed(0)} ₸',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        if (latestBonusAmount > 0)
          Text('Последнее: +$latestBonusAmount ₸ ${_formatBonusDate(latestBonusDate)}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
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
                  leading: Icon(Icons.store, color: Theme.of(context).colorScheme.primary),
                  title: Text(businessProvider.selectedBusinessName ?? 'Неизвестный магазин'),
                  subtitle: Text(businessProvider.selectedBusiness!["address"] ?? 'Неизвестный магазин'),
                  // trailing: const Icon(Icons.keyboard_arrow_right),
                  // onTap: () {
                  //   // Возвращаемся на главную страницу для смены магазина
                  //   Navigator.of(context).pop();
                  // },
                ),
              ),
            if (businessProvider.selectedBusiness != null) const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: ToggleButtons(
                    renderBorder: true,
                    isSelected: [_deliveryType == 'DELIVERY', _deliveryType == 'PICKUP'],
                    onPressed: (index) {
                      const options = ['DELIVERY', 'PICKUP'];
                      setState(() {
                        _deliveryType = options[index];
                      });
                    },
                    borderRadius: BorderRadius.circular(800),
                    selectedBorderColor: Theme.of(context).colorScheme.secondary,
                    borderColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    selectedColor: Theme.of(context).colorScheme.onPrimary,
                    fillColor: Theme.of(context).colorScheme.secondary,
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Доставка', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Самовывоз', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: const Text('Адрес доставки'),
                subtitle: _selectedAddress != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedAddress!['address'] ?? 'Адрес не указан'),
                          if (_selectedAddress!['apartment']?.toString().isNotEmpty == true ||
                              _selectedAddress!['entrance']?.toString().isNotEmpty == true ||
                              _selectedAddress!['floor']?.toString().isNotEmpty == true) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (_selectedAddress!['entrance']?.toString().isNotEmpty == true) ...[
                                  Text(
                                    'Под. ${_selectedAddress!['entrance']}',
                                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                                  if (_selectedAddress!['apartment']?.toString().isNotEmpty == true ||
                                      _selectedAddress!['floor']?.toString().isNotEmpty == true)
                                    Text(', ', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                ],
                                if (_selectedAddress!['floor']?.toString().isNotEmpty == true) ...[
                                  Text(
                                    'Эт. ${_selectedAddress!['floor']}',
                                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                                  if (_selectedAddress!['apartment']?.toString().isNotEmpty == true)
                                    Text(', ', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                ],
                                if (_selectedAddress!['apartment']?.toString().isNotEmpty == true)
                                  Text(
                                    'Кв. ${_selectedAddress!['apartment']}',
                                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                              ],
                            ),
                          ],
                          if (_selectedAddress!['other']?.toString().isNotEmpty == true) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Комментарий: ${_selectedAddress!['other']}',
                              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      )
                    : const Text('Адрес не выбран'),
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
                      subtitle: Text('${_deliveryData!['delivery_cost']} ₸', style: const TextStyle(fontSize: 18)),
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
            const Text('Товары в корзине', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...cartProvider.items.map((item) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(item.name),
                  subtitle: Text('x${item.stepQuantity == 1.0 ? item.quantity.toStringAsFixed(0) : item.quantity.toStringAsFixed(2)}'),
                  trailing: Text('${item.totalPrice.toStringAsFixed(0)} ₸'),
                ),
              );
            }),
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
              subtitle: _bonusData != null && _bonusData!['success'] == true ? _buildBonusSubtitle() : const Text('Загрузка...'),
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
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Товары:'), Text('${total.toStringAsFixed(0)} ₸')]),
                    if (_deliveryType == 'DELIVERY' && _deliveryData != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [const Text('Доставка:'), Text('${_deliveryData!['delivery_cost']} ₸')],
                      ),
                    ],
                    if (_useBonus && _getUsedBonuses() > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Бонусы:', style: TextStyle(color: Colors.green)),
                          Text('-${_getUsedBonuses().toStringAsFixed(0)} ₸', style: const TextStyle(color: Colors.green)),
                        ],
                      ),
                    ],
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Итого:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('${_getTotalWithDelivery().toStringAsFixed(0)} ₸', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _submitOrder,
              child: const Text('Подтвердить заказ'),
            ),
          ], // end children
        ), // end Column
      ), // end SingleChildScrollView
    ); // end Scaffold
  }
}
