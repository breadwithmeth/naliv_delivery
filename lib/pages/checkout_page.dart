import 'package:flutter/material.dart';
import 'package:gradusy24/pages/bonus_info_page.dart';
import 'package:gradusy24/pages/payment_method_page.dart';
import 'package:gradusy24/services/onboarding_service.dart';
import 'package:gradusy24/shared/app_theme.dart';
import 'package:gradusy24/utils/address_storage_service.dart';
import 'package:gradusy24/utils/api.dart';
import 'package:gradusy24/utils/app_navigator.dart';
import 'package:gradusy24/utils/bonus_rules.dart';
import 'package:gradusy24/utils/business_provider.dart';
import 'package:gradusy24/utils/item_name_presentation.dart';
import 'package:gradusy24/utils/responsive.dart';
import 'package:provider/provider.dart';
import '../utils/cart_provider.dart';
import '../utils/smart_cart.dart';
import 'package:gradusy24/widgets/address_selection_modal_material.dart';
import 'cart_page.dart';

class CheckoutPage extends StatefulWidget {
  static const routeName = '/checkout';
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  bool _useBonus = false;
  Map<String, dynamic>? _selectedAddress;
  Map<String, dynamic>? _deliveryData;
  Map<String, dynamic>? _bonusData;
  bool _isCalculatingDelivery = false;
  bool _isSubmitting = false;
  // Тип доставки: DELIVERY, PICKUP, SCHEDULED
  String _deliveryType = 'DELIVERY';
  // Время доставки: NOW или конкретное время
  String _deliveryTime = 'NOW';
  DateTime? _selectedDeliveryDateTime;
  final TextEditingController _entranceController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _apartmentController = TextEditingController();

  int get _itemCount => Provider.of<CartProvider>(context, listen: false).displayItemCount;

  void _handleBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      // Safeguard: if this is the last route, return to cart instead of a blank screen.
      navigator.pushReplacement(MaterialPageRoute(builder: (_) => const CartPage()));
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _floorController.dispose();
    _apartmentController.dispose();
    super.dispose();
  }

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
      _syncAddressDetailControllers(address);
    }
    await _calculateDelivery();
  }

  Future<void> _loadUserBonuses() async {
    if (await ApiService.isUserLoggedIn()) {
      final bonuses = await ApiService.getUserBonuses();
      debugPrint('Loaded bonuses: $bonuses');
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
    if (!mounted) return;
    final selected = await AddressSelectionModalHelper.show(context);
    if (mounted && selected != null) {
      setState(() {
        _selectedAddress = selected;
        _deliveryData = null;
      });
      _syncAddressDetailControllers(selected);
      // Сохраняем выбранный адрес со всеми деталями
      await AddressStorageService.saveSelectedAddress(selected);
      await AddressStorageService.markAsLaunched();
      // Рассчитываем доставку по новому адресу
      await _calculateDelivery();
    }
  }

  Future<void> _showBusinessSelectionSheet() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final availableCities = (await OnboardingService.fetchAvailableCities(forceRefresh: true)).map((city) => city.name).toList();
    final selectedCity = await OnboardingService.getSelectedCity();
    final businesses = await ApiService.getAllBusinesses();

    if (!mounted) return;
    if (businesses == null || businesses.isEmpty) {
      await _showNotice('Магазины не найдены', 'Не удалось загрузить список магазинов. Попробуйте ещё раз.');
      return;
    }

    final preparedBusinesses = List<Map<String, dynamic>>.from(businesses).map((business) {
      return {
        ...business,
        '_cityName': _detectBusinessCity(business, availableCities) ?? '',
      };
    }).toList();

    final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
    final selectedBusiness = businessProvider.selectedBusiness;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      builder: (sheetContext) {
        return _CheckoutShopCitySheet(
          allBusinesses: preparedBusinesses,
          availableCities: availableCities,
          selectedCity: selectedCity,
          selectedBusiness: selectedBusiness,
        );
      },
    );

    if (!mounted || result == null) return;

    final currentBusinessId = _businessIdOf(selectedBusiness);
    final nextBusinessId = _businessIdOf(result);
    if (currentBusinessId != null && currentBusinessId == nextBusinessId) {
      return;
    }

    final shouldSwitch = await AppDialogs.show<bool>(
      context,
      title: 'Сменить магазин?',
      content: const Text(
        'Смена магазина очистит текущую корзину и вернёт вас к выбору товаров.',
        style: TextStyle(color: AppColors.textMute),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: AppColors.textMute),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.orange),
          child: const Text('Сменить'),
        ),
      ],
    );

    if (shouldSwitch != true || !mounted) return;

    final nextCity = result['_cityName']?.toString();
    if (nextCity != null && nextCity.isNotEmpty && nextCity != selectedCity) {
      await OnboardingService.setSelectedCity(nextCity);
      await AddressStorageService.removeSelectedAddress();
    }

    cartProvider.clearCart();
    await businessProvider.setSelectedBusiness(result);
    if (!mounted) return;
    await AppNavigator.goToHomeTab(0);
  }

  Future<void> _submitOrder() async {
    // Проверяем авторизацию
    final loggedIn = await ApiService.isUserLoggedIn();
    if (!mounted) return;
    if (!loggedIn) {
      await _showNotice('Нужна авторизация', 'Пожалуйста, авторизуйтесь, чтобы оформить заказ.');
      return;
    }

    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
    if (businessProvider.selectedBusiness == null) {
      await _showNotice('Магазин не выбран', 'Пожалуйста, выберите магазин перед оформлением заказа.');
      setState(() => _isSubmitting = false);
      return;
    }
    if (_selectedAddress == null && _deliveryType == 'DELIVERY') {
      await _showNotice('Адрес не выбран', 'Пожалуйста, выберите адрес доставки.');
      setState(() => _isSubmitting = false);
      return;
    }

    if (_deliveryType == 'DELIVERY' && !_validateAddressDetails()) {
      setState(() => _isSubmitting = false);
      return;
    }

    final normalizedAddress = _addressWithDetails();
    if (_deliveryType == 'DELIVERY') {
      await AddressStorageService.saveSelectedAddress(normalizedAddress);
      if (mounted) {
        setState(() {
          _selectedAddress = normalizedAddress;
        });
      }
    }

    final body = <String, dynamic>{
      'business_id': businessProvider.selectedBusiness!['id'],
      'street': normalizedAddress['street'] ?? normalizedAddress['address'] ?? '',
      'house': normalizedAddress['house'] ?? '-',
      'lat': normalizedAddress['lat'] ?? 0.0,
      'lon': normalizedAddress['lon'] ?? 0.0,
      'apartment': normalizedAddress['apartment'] ?? '',
      'entrance': normalizedAddress['entrance'] ?? '',
      'floor': normalizedAddress['floor'] ?? '',
      'extra': normalizedAddress['comment'] ?? '',
      'items': cartProvider.items.map((item) => item.toJsonForOrder()).toList(),
      'delivery_type': _deliveryType,
      'delivery_time': _deliveryTime,
      'total_amount': _getTotalWithDelivery(),
      'use_bonuses': _useBonus,
      if (_useBonus) 'bonus_amount': _getUsedBonuses(),
      if (_selectedDeliveryDateTime != null) 'scheduled_time': _selectedDeliveryDateTime!.toIso8601String(),
      'saved_card_id': 1,
    };
    try {
      final result = await ApiService.createUserOrder(body);
      if (!mounted) return;

      if (result['success'] == true) {
        final orderData = result['data'];
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentMethodPage(
              orderData: orderData,
              displayAmount: _getTotalWithDelivery(),
            ),
          ),
        );
      } else {
        final errorMessage = result['error'] is Map ? result['error']['message'] : result['error'];
        await _showNotice('Ошибка создания заказа', '$errorMessage');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Рассчитать стоимость доставки по адресу
  Future<void> _calculateDelivery() async {
    if (_selectedAddress == null || _deliveryType != 'DELIVERY') return;
    if (_isCalculatingDelivery) return;
    setState(() => _isCalculatingDelivery = true);
    final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
    if (businessProvider.selectedBusiness == null) {
      await _showNotice('Магазин не выбран', 'Сначала выберите магазин, чтобы рассчитать доставку.');
      setState(() => _isCalculatingDelivery = false);
      return;
    }
    // Предполагаем, что в _selectedAddress есть ключ 'address_id'
    final businessId = businessProvider.selectedBusiness!['id'];
    try {
      final data = await ApiService.calculateDeliveryByAddress(
        businessId: businessId,
        lat: _selectedAddress!['lat'],
        lon: _selectedAddress!['lon'],
      );

      if (mounted) {
        setState(() {
          _deliveryData = data;
        });
      }
    } catch (e) {
      if (mounted) {
        await _showNotice('Доставка не рассчитана', 'Не удалось рассчитать доставку: $e');
      }
    } finally {
      if (mounted) setState(() => _isCalculatingDelivery = false);
    }
  }

  /// Показать диалог выбора времени доставки
  Future<void> _showDeliveryTimeSelection() async {
    final result = await AppDialogs.show<String>(
      context,
      title: 'Выберите время доставки',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.schedule, color: AppColors.orange),
            title: const Text('Сейчас', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
            subtitle: const Text('Доставка в ближайшее время', style: TextStyle(color: AppColors.textMute)),
            onTap: () => Navigator.pop(context, 'NOW'),
          ),
          const Divider(color: Color(0x229FB0C8)),
          ListTile(
            leading: const Icon(Icons.calendar_today, color: AppColors.orange),
            title: const Text('Запланировать', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
            subtitle: const Text('Выберите дату и время', style: TextStyle(color: AppColors.textMute)),
            onTap: () async {
              Navigator.pop(context);
              await _showDateTimePicker();
            },
          ),
          if (_deliveryTime != 'NOW' && _selectedDeliveryDateTime != null) ...[
            const Divider(color: Color(0x229FB0C8)),
            ListTile(
              leading: const Icon(Icons.clear, color: AppColors.orange),
              title: const Text('Сбросить', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
              subtitle: const Text('Очистить выбранное время', style: TextStyle(color: AppColors.textMute)),
              onTap: () => Navigator.pop(context, 'RESET'),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: AppColors.textMute),
          child: const Text('Отмена'),
        ),
      ],
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
      await _showNotice('Некорректное время', 'Нельзя выбрать время в прошлом.');
      return;
    }

    // Проверяем, что время в пределах 24 часов
    if (selectedDateTime.isAfter(now.add(const Duration(hours: 24)))) {
      await _showNotice('Некорректное время', 'Доставка возможна только в течение 24 часов.');
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

  /// Получить итоговую сумму с учетом доставки
  double _getTotalWithDelivery() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final itemsTotal = cartProvider.getTotalPrice();
    final deliveryCost = (_deliveryType == 'DELIVERY' && _deliveryData != null) ? (_deliveryData!['delivery_cost'] as num?)?.toDouble() ?? 0.0 : 0.0;

    // Bonuses apply only to items (not delivery).
    final bonusApplied = _useBonus && _bonusData != null && _bonusData!['success'] == true ? _getUsedBonuses() : 0.0;

    return (itemsTotal - bonusApplied).clamp(0, double.infinity) + deliveryCost;
  }

  /// Получить сумму использованных бонусов
  double _getUsedBonuses() {
    if (!_useBonus || _bonusData == null || _bonusData!['success'] != true) {
      return 0.0;
    }

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final itemsTotal = cartProvider.getTotalPrice();

    // Максимум 30% от суммы товаров можно оплатить бонусами, доставка не покрывается бонусами.
    final maxBonusUsage = itemsTotal * 0.30;
    final availableBonuses = (_bonusData!['data']['totalBonuses'] as num?)?.toDouble() ?? 0.0;

    // Возвращаем меньшее из: доступные бонусы, максимально допустимое использование (30%), или сумма товаров
    return [availableBonuses, maxBonusUsage, itemsTotal].reduce((a, b) => a < b ? a : b);
  }

  int _getEarnedBonuses() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    return _calculateEarnedBonuses(cartProvider.displayGroups);
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final displayGroups = cartProvider.displayGroups;
    final businessProvider = Provider.of<BusinessProvider>(context);
    final deliveryCost = (_deliveryData?['delivery_cost'] as num?)?.toDouble() ?? 0.0;
    final itemsTotal = cartProvider.getTotalPrice();
    final totalWithDelivery = _getTotalWithDelivery();
    final earnedBonuses = _getEarnedBonuses();
    final bool canUseBonus = _bonusData != null && _bonusData!['success'] == true;
    final double bonusUsed = _useBonus ? _getUsedBonuses() : 0.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          foregroundColor: AppColors.text,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: _handleBack,
          ),
          title: Text('Оформление', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.sp)),
        ),
        bottomNavigationBar: _bottomCheckoutBar(total: totalWithDelivery),
        body: Stack(
          children: [
            const AppBackground(),
            SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16.s, 4.s, 16.s, 100.s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _deliveryTabs(),
                    SizedBox(height: 14.s),
                    _tapRow(
                      icon: Icons.store,
                      title: businessProvider.selectedBusinessName ?? 'Магазин',
                      value: businessProvider.selectedBusiness?['address'],
                      onTap: _showBusinessSelectionSheet,
                    ),
                    if (_deliveryType == 'DELIVERY') ...[
                      _tapRow(
                        icon: Icons.location_on_outlined,
                        title: _addressText(),
                        value: _selectedAddress == null
                            ? 'Можно выбрать позже, но перед подтверждением заказа адрес обязателен'
                            : 'Нажмите, чтобы уточнить или изменить адрес',
                        onTap: _showAddressSelectionModal,
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: 4.s),
                        child: Row(
                          children: [
                            Expanded(child: _compactField(_entranceController, 'Подъезд')),
                            SizedBox(width: 8.s),
                            Expanded(child: _compactField(_floorController, 'Этаж')),
                            SizedBox(width: 8.s),
                            Expanded(child: _compactField(_apartmentController, 'Квартира')),
                          ],
                        ),
                      ),
                      _tapRow(
                        icon: Icons.local_shipping_outlined,
                        title: 'Стоимость доставки',
                        value: _isCalculatingDelivery ? 'считаем…' : (deliveryCost > 0 ? _money(deliveryCost) : '—'),
                        onTap: _calculateDelivery,
                      ),
                    ],
                    _tapRow(
                      icon: Icons.access_time,
                      title: 'Когда доставить',
                      value: _getDeliveryTimeText(),
                      onTap: _showDeliveryTimeSelection,
                    ),
                    _thinDivider(),
                    Row(
                      children: [
                        Icon(Icons.stars_rounded, color: AppColors.orange, size: 18.s),
                        SizedBox(width: 10.s),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Списать бонусы', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
                              if (canUseBonus)
                                _buildBonusSubtitle()
                              else
                                const Text('Проверяем баланс…', style: TextStyle(color: AppColors.textMute, fontSize: 12)),
                            ],
                          ),
                        ),
                        Switch(
                          value: _useBonus,
                          activeThumbColor: Colors.black,
                          activeTrackColor: AppColors.orange,
                          inactiveThumbColor: AppColors.text,
                          inactiveTrackColor: AppColors.blue,
                          onChanged: canUseBonus ? (v) => setState(() => _useBonus = v) : null,
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BonusInfoPage())),
                      child: Padding(
                        padding: EdgeInsets.only(left: 28.s, top: 2.s),
                        child: Text('Как работают бонусы →', style: TextStyle(color: AppColors.orange, fontSize: 12.sp, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    _thinDivider(),
                    _sectionTitle('Ваш заказ · $_itemCount поз.'),
                    SizedBox(height: 8.s),
                    for (int i = 0; i < displayGroups.length; i++) ...[
                      if (i > 0) Divider(color: Colors.white.withValues(alpha: 0.05), height: 16.s),
                      _itemTile(displayGroups[i]),
                    ],
                    _thinDivider(),
                    _summaryRow('Товары', _money(itemsTotal)),
                    SizedBox(height: 6.s),
                    if (_deliveryType == 'DELIVERY') ...[
                      _summaryRow('Доставка', deliveryCost > 0 ? _money(deliveryCost) : '—'),
                      SizedBox(height: 6.s),
                    ],
                    if (bonusUsed > 0) ...[
                      _summaryRow('Списание бонусов', '-${_money(bonusUsed)}', valueColor: Colors.greenAccent),
                      SizedBox(height: 6.s),
                    ],
                    if (earnedBonuses > 0) ...[
                      _summaryRow('Бонусы за заказ', '+$earnedBonuses ₸', valueColor: Colors.greenAccent),
                      SizedBox(height: 6.s),
                    ],
                    Divider(color: Colors.white.withValues(alpha: 0.08), height: 20.s),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Итого', style: TextStyle(color: AppColors.text, fontSize: 16.sp, fontWeight: FontWeight.w800)),
                        Text(_money(totalWithDelivery), style: TextStyle(color: AppColors.orange, fontSize: 18.sp, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deliveryTabs() {
    return Container(
      padding: EdgeInsets.all(4.s),
      decoration: AppDecorations.card(radius: 22, color: AppColors.cardDark.withValues(alpha: 0.9)),
      child: Row(
        children: [
          _deliveryTab('Доставка', 'DELIVERY'),
          _deliveryTab('Самовывоз', 'PICKUP'),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: EdgeInsets.only(top: 2.s),
      child: Text(text, style: TextStyle(color: AppColors.textMute, fontSize: 12.sp, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
    );
  }

  Widget _thinDivider() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14.s),
      child: Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
    );
  }

  Widget _tapRow({
    required IconData icon,
    required String title,
    String? value,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10.s),
        child: Row(
          children: [
            Icon(icon, color: AppColors.orange, size: 18.s),
            SizedBox(width: 10.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 14.sp)),
                  if (value != null)
                    Text(value, style: TextStyle(color: AppColors.textMute, fontSize: 12.sp), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (onTap != null) Icon(Icons.chevron_right, color: AppColors.textMute, size: 18.s),
          ],
        ),
      ),
    );
  }

  Widget _deliveryTab(String label, String value) {
    final bool active = _deliveryType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_deliveryType == value) return;
          setState(() {
            _deliveryType = value;
            if (value == 'PICKUP') {
              _deliveryData = null;
            } else {
              _calculateDelivery();
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 10.s),
          decoration: BoxDecoration(
            color: active ? AppColors.orange : Colors.transparent,
            borderRadius: BorderRadius.circular(18.s),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.black : AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  static double _freeAmount(CartDisplayGroup item) {
    if (item.freeQuantity > 0) {
      return item.freeQuantity;
    }
    for (final promo in item.promotions) {
      final type = (promo['type'] as String?) ?? (promo['discount_type'] as String?);
      if (type == 'SUBTRACT') {
        final base = ((promo['baseAmount'] as num?) ?? (promo['base_amount'] as num?) ?? 0).toInt();
        final add = ((promo['addAmount'] as num?) ?? (promo['add_amount'] as num?) ?? 0).toInt();
        final groupSize = base + add;
        if (groupSize > 0 && base > 0 && item.totalQuantity >= groupSize) {
          final count = item.totalQuantity ~/ groupSize;
          return (count * add).toDouble();
        }
      }
    }
    return 0;
  }

  static String _fmtQty(double qty) {
    return (qty - qty.roundToDouble()).abs() < 0.001 ? qty.toStringAsFixed(0) : qty.toStringAsFixed(2);
  }

  Widget _itemTile(CartDisplayGroup item) {
    final snapshot = item.itemSnapshot;
    final itemTitle = snapshot != null
        ? presentItemName(
            rawName: snapshot.name,
            categoryName: snapshot.category?.name,
          )
        : presentItemName(
            rawName: item.name,
            storedType: item.itemType,
            storedPackagingType: item.packagingType,
          );
    final double freeQty = _freeAmount(item);
    final bool hasFree = freeQty > 0;
    final double rawTotal = item.subtotalBeforePromotions;
    final bool hasSavings = item.totalPrice < rawTotal - 0.001;
    final bottleBreakdown = item.bottleBreakdownLabel;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (itemTitle.attributes.isNotEmpty)
                Text(
                  itemTitle.attributes.join(' • '),
                  style: const TextStyle(color: AppColors.textMute, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              Text(itemTitle.name, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('x${_fmtQty(item.totalQuantity)}', style: const TextStyle(color: AppColors.textMute, fontSize: 12)),
                  if (bottleBreakdown != null) ...[
                    SizedBox(width: 6.s),
                    Expanded(
                      child: Text(
                        bottleBreakdown,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textMute, fontSize: 11.sp, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  if (hasFree) ...[
                    SizedBox(width: 6.s),
                    Text(
                      '+ ${_fmtQty(freeQty)} в подарок',
                      style: TextStyle(color: AppColors.orange, fontSize: 11.sp, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        SizedBox(width: 12.s),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (hasSavings)
              Text(
                _money(rawTotal),
                style: TextStyle(
                  color: AppColors.textMute.withValues(alpha: 0.5),
                  fontSize: 11.sp,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: AppColors.textMute.withValues(alpha: 0.5),
                ),
              ),
            Text(_money(item.totalPrice), style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w900)),
            if (hasFree)
              Text(
                '+ ${_fmtQty(freeQty)} в подарок',
                style: TextStyle(color: AppColors.orange, fontSize: 11.sp, fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {Color valueColor = AppColors.text}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textMute, fontSize: 12.sp)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 13.sp, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _bottomCheckoutBar({required double total}) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.s, 10.s, 16.s, 10.s),
      decoration: BoxDecoration(
        color: AppColors.bgDeep,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Text(_money(total), style: TextStyle(color: AppColors.text, fontSize: 20.sp, fontWeight: FontWeight.w900)),
            SizedBox(width: 14.s),
            Expanded(
              child: _primaryButton(
                label: _isSubmitting ? 'Отправка…' : 'Подтвердить',
                onTap: _isSubmitting ? null : _submitOrder,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton({required String label, required VoidCallback? onTap}) {
    final bool disabled = onTap == null;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.7 : 1,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 14.s),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23.s),
            gradient: const LinearGradient(colors: [Color(0xFF8B1F1E), AppColors.red]),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 10)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 16.s),
              SizedBox(width: 9.s),
              Text(label, style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  String _addressText() {
    return ApiService.formatAddressSummary(_selectedAddress, emptyText: 'Выберите адрес');
  }

  void _syncAddressDetailControllers(Map<String, dynamic>? address) {
    _entranceController.text = address?['entrance']?.toString() ?? '';
    _floorController.text = address?['floor']?.toString() ?? '';
    _apartmentController.text = address?['apartment']?.toString() ?? '';
  }

  Map<String, dynamic> _addressWithDetails() {
    return {
      ...?_selectedAddress,
      'entrance': _entranceController.text.trim(),
      'floor': _floorController.text.trim(),
      'apartment': _apartmentController.text.trim(),
    };
  }

  bool _validateAddressDetails() {
    final missing = <String>[];
    if (_entranceController.text.trim().isEmpty) missing.add('подъезд');
    if (_floorController.text.trim().isEmpty) missing.add('этаж');
    if (_apartmentController.text.trim().isEmpty) missing.add('квартиру');

    if (missing.isEmpty) return true;

    _showNotice('Незаполненный адрес', 'Добавьте ${missing.join(', ')} перед подтверждением заказа.');
    return false;
  }

  Future<void> _showNotice(String title, String message) {
    return AppDialogs.showMessage(
      context,
      title: title,
      message: message,
    );
  }

  dynamic _businessIdOf(Map<String, dynamic>? business) {
    return business?['id'] ?? business?['business_id'] ?? business?['businessId'];
  }

  String? _detectBusinessCity(Map<String, dynamic> business, List<String> availableCities) {
    final rawSources = [
      business['city'],
      business['city_name'],
      business['cityName'],
      business['city_title'],
      business['cityTitle'],
      business['address'],
      business['description'],
    ];

    for (final source in rawSources) {
      if (source == null) continue;
      final text = source.toString();
      for (final city in availableCities) {
        if (_textMatchesCity(text, city)) {
          return city;
        }
      }
    }

    return null;
  }

  bool _textMatchesCity(String text, String city) {
    final normalizedText = _normalizeText(text);
    final normalizedCity = _normalizeText(city);
    return normalizedCity.isNotEmpty && normalizedText.contains(normalizedCity);
  }

  String _normalizeText(String value) {
    return value.toLowerCase().replaceAll('ё', 'е').replaceAll(RegExp(r'[^a-zа-я0-9]+'), ' ').trim();
  }

  Widget _compactField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 13.sp),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textMute, fontSize: 12.sp),
        isDense: true,
        filled: true,
        fillColor: AppColors.card,
        contentPadding: EdgeInsets.symmetric(horizontal: 10.s, vertical: 10.s),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.orange, width: 1),
        ),
      ),
    );
  }

  Widget _buildBonusSubtitle() {
    if (_bonusData == null || _bonusData!['success'] != true) {
      return const Text('Загрузка...', style: TextStyle(color: AppColors.textMute));
    }

    final bonusData = _bonusData!['data'];
    final totalBonuses = bonusData['totalBonuses'] ?? 0;

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final itemsTotal = cartProvider.getTotalPrice();
    final maxBonusUsage = itemsTotal * 0.30;
    final availableToUse = totalBonuses > maxBonusUsage ? maxBonusUsage : totalBonuses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('На балансе: $totalBonuses ₸', style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w800)),
        Text(
          'Можно списать до ${availableToUse.toStringAsFixed(0)} ₸',
          style: const TextStyle(color: AppColors.textMute, fontSize: 12, height: 1.35, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  static String _money(double value) => '${value.toStringAsFixed(0)} ₸';

  int _calculateEarnedBonuses(Iterable<CartDisplayGroup> items) {
    final eligibleSubtotal = items.fold<double>(0, (sum, item) {
      final snapshot = item.itemSnapshot;
      final excluded = BonusRules.isBonusExcludedText(
        name: snapshot?.name ?? item.name,
        description: snapshot?.description,
        categoryName: snapshot?.category?.name,
        code: snapshot?.code,
      );
      if (excluded) {
        return sum;
      }
      return sum + item.totalPrice;
    });
    return BonusRules.calculateEarnedBonuses(eligibleSubtotal);
  }
}

class _CheckoutShopCitySheet extends StatefulWidget {
  final List<Map<String, dynamic>> allBusinesses;
  final List<String> availableCities;
  final String? selectedCity;
  final Map<String, dynamic>? selectedBusiness;

  const _CheckoutShopCitySheet({
    required this.allBusinesses,
    required this.availableCities,
    required this.selectedCity,
    required this.selectedBusiness,
  });

  @override
  State<_CheckoutShopCitySheet> createState() => _CheckoutShopCitySheetState();
}

class _CheckoutShopCitySheetState extends State<_CheckoutShopCitySheet> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _selectedShopKey = GlobalKey();

  String _compactShopAddress(String rawAddress, String? cityName) {
    final trimmed = rawAddress.trim();
    if (trimmed.isEmpty || cityName == null || cityName.trim().isEmpty) {
      return trimmed;
    }

    final parts = trimmed.split(',').map((part) => part.trim()).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return trimmed;

    final lastPart = parts.last.toLowerCase();
    final normalizedCity = cityName.trim().toLowerCase();
    if (lastPart == normalizedCity) {
      parts.removeLast();
    }

    return parts.join(', ');
  }

  Map<String, List<Map<String, dynamic>>> _groupedByCity() {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final city in widget.availableCities) {
      groups[city] = [];
    }
    groups['Другое'] = [];

    for (final business in widget.allBusinesses) {
      final city = business['_cityName']?.toString() ?? '';
      if (city.isNotEmpty && groups.containsKey(city)) {
        groups[city]!.add(business);
      } else if (city.isNotEmpty) {
        groups.putIfAbsent(city, () => []);
        groups[city]!.add(business);
      } else {
        groups['Другое']!.add(business);
      }
    }

    groups.removeWhere((_, shops) => shops.isEmpty);
    return groups;
  }

  bool _isSelected(Map<String, dynamic> shop) {
    if (widget.selectedBusiness == null) return false;
    return widget.selectedBusiness!['id'] == shop['id'];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedContext = _selectedShopKey.currentContext;
      if (selectedContext != null) {
        Scrollable.ensureVisible(
          selectedContext,
          alignment: 0.35,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.8;
    final grouped = _groupedByCity();
    final items = <_CheckoutSheetItem>[];

    for (final entry in grouped.entries) {
      items.add(_CheckoutSheetItem.header(entry.key, entry.value.length, entry.key == widget.selectedCity));
      for (final shop in entry.value) {
        items.add(_CheckoutSheetItem.shop(shop, _isSelected(shop)));
      }
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 32.s,
                height: 4.s,
                margin: EdgeInsets.only(top: 10.s, bottom: 12.s),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2.s),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(14.s, 0, 14.s, 2.s),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Выберите магазин',
                  style: TextStyle(color: AppColors.text, fontSize: 18.sp, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(14.s, 0, 14.s, 12.s),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Смена магазина очистит корзину и вернёт вас к каталогу.',
                  style: TextStyle(color: AppColors.textMute.withValues(alpha: 0.6), fontSize: 12.sp),
                ),
              ),
            ),
            Flexible(
              child: widget.allBusinesses.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.store_mall_directory, color: AppColors.textMute, size: 32),
                          SizedBox(height: 10),
                          Text('Магазины не найдены', style: TextStyle(color: AppColors.text, fontSize: 15)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      itemCount: items.length,
                      itemBuilder: (listContext, index) {
                        final item = items[index];
                        if (item.isHeader) {
                          return _cityHeader(item.cityName!, item.shopCount!, item.isCurrentCity!);
                        }
                        return Padding(
                          padding: EdgeInsets.only(bottom: 7.s),
                          child: _shopCard(listContext, item.business!, item.isSelectedShop!),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cityHeader(String city, int count, bool isCurrent) {
    return Padding(
      padding: EdgeInsets.only(top: 7.s, bottom: 9.s),
      child: Row(
        children: [
          Icon(
            isCurrent ? Icons.my_location_rounded : Icons.location_city_rounded,
            size: 14.s,
            color: isCurrent ? AppColors.orange : AppColors.textMute.withValues(alpha: 0.5),
          ),
          SizedBox(width: 7.s),
          Text(
            city,
            style: TextStyle(
              color: isCurrent ? AppColors.orange : AppColors.text,
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(width: 7.s),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 7.s, vertical: 2.s),
            decoration: BoxDecoration(
              color: isCurrent ? AppColors.orange.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(9.s),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: isCurrent ? AppColors.orange : AppColors.textMute.withValues(alpha: 0.5),
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (isCurrent) ...[
            const Spacer(),
            Text(
              'текущий город',
              style: TextStyle(color: AppColors.orange.withValues(alpha: 0.5), fontSize: 10.sp, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _shopCard(BuildContext context, Map<String, dynamic> shop, bool isSelected) {
    final name = (shop['name'] ?? shop['title'] ?? 'Магазин').toString();
    final city = shop['_cityName']?.toString();
    final rawAddress = (shop['address'] ?? shop['subtitle'] ?? '').toString();
    final addr = _compactShopAddress(rawAddress, city);
    final primaryLabel = addr.isNotEmpty ? '$name, $addr' : name;

    return GestureDetector(
      onTap: () => Navigator.pop(context, shop),
      child: Container(
        key: isSelected ? _selectedShopKey : null,
        padding: EdgeInsets.all(12.s),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.orange.withValues(alpha: 0.10) : AppColors.cardDark,
          borderRadius: BorderRadius.circular(12.s),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.storefront_rounded,
              color: AppColors.orange,
              size: 22.s,
            ),
            SizedBox(width: 10.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    primaryLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? AppColors.orange : AppColors.text,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  if (city != null && city.isNotEmpty) ...[
                    SizedBox(height: 3.s),
                    Text(
                      city,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textMute.withValues(alpha: 0.85), fontSize: 12.sp, height: 1.2),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Padding(
                padding: EdgeInsets.only(left: 7.s),
                child: Icon(Icons.check_rounded, color: AppColors.orange, size: 18.s),
              ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutSheetItem {
  final bool isHeader;
  final String? cityName;
  final int? shopCount;
  final bool? isCurrentCity;
  final Map<String, dynamic>? business;
  final bool? isSelectedShop;

  _CheckoutSheetItem._({
    required this.isHeader,
    this.cityName,
    this.shopCount,
    this.isCurrentCity,
    this.business,
    this.isSelectedShop,
  });

  factory _CheckoutSheetItem.header(String city, int count, bool isCurrent) {
    return _CheckoutSheetItem._(isHeader: true, cityName: city, shopCount: count, isCurrentCity: isCurrent);
  }

  factory _CheckoutSheetItem.shop(Map<String, dynamic> business, bool isSelected) {
    return _CheckoutSheetItem._(isHeader: false, business: business, isSelectedShop: isSelected);
  }
}
