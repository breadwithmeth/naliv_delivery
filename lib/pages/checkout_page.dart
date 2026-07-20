import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/faq_page.dart';
import 'package:naliv_delivery/pages/payment_method_page.dart';
import 'package:naliv_delivery/services/onboarding_service.dart';
import 'package:naliv_delivery/shared/app_theme.dart';
import 'package:naliv_delivery/utils/address_storage_service.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/utils/app_navigator.dart';
import 'package:naliv_delivery/utils/bonus_rules.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:naliv_delivery/utils/certificate_checkout_math.dart';
import 'package:naliv_delivery/utils/item_name_presentation.dart';
import 'package:naliv_delivery/utils/responsive.dart';
import 'package:naliv_delivery/utils/subtract_promotion_math.dart';
import 'package:provider/provider.dart';
import '../utils/cart_provider.dart';
import '../utils/smart_cart.dart';
import 'package:naliv_delivery/widgets/address_selection_modal_material.dart';
import 'cart_page.dart';

class CheckoutPage extends StatefulWidget {
  static const routeName = '/checkout';
  final String? initialDeliveryType;
  final Map<String, dynamic>? initialAddress;

  const CheckoutPage({
    super.key,
    this.initialDeliveryType,
    this.initialAddress,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  static const List<int> _courierTipPresetAmounts = <int>[100, 200];
  static const Map<int, int> _bagItemIdsByShopId = <int, int>{
    1: 48044,
    2: 50848,
    6: 50837,
    4: 52317,
    7: 29503,
    5: 28399,
    3: 27295,
    8: 43914,
    11: 103935,
    9: 46063,
    10: 51676,
  };
  static const double _checkoutBagPrice = 30.0;

  bool _useBonus = false;
  Map<String, dynamic>? _selectedAddress;
  Map<String, dynamic>? _deliveryData;
  Map<String, dynamic>? _bonusData;
  bool _isCalculatingDelivery = false;
  bool _isSubmitting = false;
  // Тип доставки: DELIVERY, PICKUP, SCHEDULED
  String _deliveryType = 'DELIVERY';
  int _selectedCourierTips = 0;

  bool get _isPromoCodeApplied => _appliedPromoData != null;
  // Время доставки: NOW или конкретное время
  String _deliveryTime = 'NOW';
  DateTime? _selectedDeliveryDateTime;
  final TextEditingController _entranceController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _apartmentController = TextEditingController();
  final TextEditingController _promoCodeController = TextEditingController();
  bool _isValidatingPromo = false;
  Map<String, dynamic>? _appliedPromoData;
  bool _isValidatingCertificate = false;
  Map<String, dynamic>? _appliedCertificateData;

  void _handleBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      // Safeguard: if this is the last route, return to cart instead of a blank screen.
      navigator
          .pushReplacement(MaterialPageRoute(builder: (_) => const CartPage()));
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _floorController.dispose();
    _apartmentController.dispose();
    _promoCodeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final initialDeliveryType =
        widget.initialDeliveryType?.trim().toUpperCase();
    if (initialDeliveryType == 'PICKUP' || initialDeliveryType == 'DELIVERY') {
      _deliveryType = initialDeliveryType!;
    }
    if (widget.initialAddress != null) {
      _selectedAddress = Map<String, dynamic>.from(widget.initialAddress!);
      _syncAddressDetailControllers(_selectedAddress);
    }
    _initAddressSelection();
    _loadUserBonuses();
  }

  Future<void> _initAddressSelection() async {
    if (widget.initialAddress != null) {
      if (_deliveryType == 'DELIVERY' && _selectedAddress != null) {
        await AddressStorageService.saveSelectedAddress(_selectedAddress!);
      }
      await _calculateDelivery();
      return;
    }

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

  Future<void> _showAddressSelectionModal({
    Map<String, dynamic>? initialAddress,
  }) async {
    if (!mounted) return;
    final selected = await AddressSelectionModalHelper.show(
      context,
      initialAddress: initialAddress ?? _addressWithDetails(),
      openDetailsFirst: _selectedAddress != null,
    );
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
    final availableCities =
        (await OnboardingService.fetchAvailableCities(forceRefresh: true))
            .map((city) => city.name)
            .toList();
    final selectedCity = await OnboardingService.getSelectedCity();
    final businesses = await ApiService.getAllBusinesses();

    if (!mounted) return;
    if (businesses == null || businesses.isEmpty) {
      await _showNotice('Магазины не найдены',
          'Не удалось загрузить список магазинов. Попробуйте ещё раз.');
      return;
    }

    final preparedBusinesses =
        List<Map<String, dynamic>>.from(businesses).map((business) {
      return {
        ...business,
        '_cityName': _detectBusinessCity(business, availableCities) ?? '',
      };
    }).toList();

    final businessProvider =
        Provider.of<BusinessProvider>(context, listen: false);
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
      await _showNotice('Нужна авторизация',
          'Пожалуйста, авторизуйтесь, чтобы оформить заказ.');
      return;
    }

    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final businessProvider =
        Provider.of<BusinessProvider>(context, listen: false);
    if (businessProvider.selectedBusiness == null) {
      await _showNotice('Магазин не выбран',
          'Пожалуйста, выберите магазин перед оформлением заказа.');
      setState(() => _isSubmitting = false);
      return;
    }
    if (_selectedAddress == null && _deliveryType == 'DELIVERY') {
      await _showAddressSelectionModal();
      if (_selectedAddress == null) {
        setState(() => _isSubmitting = false);
        return;
      }
    }

    if (_deliveryType == 'DELIVERY' && !_hasCompleteAddressDetails()) {
      await _showAddressSelectionModal(initialAddress: _addressWithDetails());
      if (!_hasCompleteAddressDetails()) {
        setState(() => _isSubmitting = false);
        return;
      }
    }

    final normalizedAddress = _addressWithDetails();
    if (_deliveryType == 'DELIVERY' && normalizedAddress['lat'] == null) {
      setState(() => _isSubmitting = false);
      return;
    }
    final businessId = _asInt(_businessIdOf(businessProvider.selectedBusiness));
    if (businessId == null) {
      await _showNotice('Магазин не выбран',
          'Не удалось определить магазин для оформления заказа.');
      setState(() => _isSubmitting = false);
      return;
    }
    final bagItemId = _bagItemIdForBusinessId(businessId);
    final orderItems = _orderItemsWithBag(cartProvider, bagItemId: bagItemId);
    final certificateAmount = _getCertificateAmount();
    final certificate = _appliedCertificate();
    final isPickup = _deliveryType == 'PICKUP';
    final courierTips = isPickup ? 0 : _getCourierTips();
    if (_deliveryType == 'DELIVERY') {
      await AddressStorageService.saveSelectedAddress(normalizedAddress);
      if (mounted) {
        setState(() {
          _selectedAddress = normalizedAddress;
        });
      }
    }

    final body = <String, dynamic>{
      'business_id': businessId,
      'street': isPickup
          ? ''
          : normalizedAddress['street'] ?? normalizedAddress['address'] ?? '',
      'house': isPickup ? '' : normalizedAddress['house'] ?? '-',
      'lat': isPickup ? 0.0 : normalizedAddress['lat'] ?? 0.0,
      'lon': isPickup ? 0.0 : normalizedAddress['lon'] ?? 0.0,
      'apartment': isPickup ? '' : normalizedAddress['apartment'] ?? '',
      'entrance': isPickup ? '' : normalizedAddress['entrance'] ?? '',
      'floor': isPickup ? '' : normalizedAddress['floor'] ?? '',
      'extra': isPickup ? '' : normalizedAddress['comment'] ?? '',
      'items': orderItems,
      'delivery_type': _deliveryType,
      'delivery_time': _deliveryTime,
      'total_amount': _getTotalWithDelivery(),
      'courier_tips': courierTips,
      'use_bonuses': _useBonus,
      if (_useBonus) 'bonus_amount': _getUsedBonuses(),
      if (_selectedDeliveryDateTime != null)
        'scheduled_time': _selectedDeliveryDateTime!.toIso8601String(),
      'saved_card_id': 1,
      if (_appliedPromoData != null && certificate == null)
        'promo_code': _promoCodeController.text.trim(),
      if (certificate != null && certificateAmount > 0) ...{
        if (_certificateIdOf(certificate) != null)
          'certificate_id': _certificateIdOf(certificate),
        if (_certificateIdOf(certificate) == null &&
            certificate['code'] != null)
          'certificate_code': certificate['code'].toString(),
        'certificate_amount': certificateAmount,
      },
    };
    try {
      final result = await ApiService.createUserOrder(body);
      if (result['success'] == true) {
        cartProvider.clearCart();
      }

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
        final errorMessage = result['error'] is Map
            ? result['error']['message']
            : result['error'];
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
    final businessProvider =
        Provider.of<BusinessProvider>(context, listen: false);
    if (businessProvider.selectedBusiness == null) {
      await _showNotice('Магазин не выбран',
          'Сначала выберите магазин, чтобы рассчитать доставку.');
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
        await _showNotice(
            'Доставка не рассчитана', 'Не удалось рассчитать доставку: $e');
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
            title: const Text('Сейчас',
                style: TextStyle(
                    color: AppColors.text, fontWeight: FontWeight.w700)),
            subtitle: const Text('Доставка в ближайшее время',
                style: TextStyle(color: AppColors.textMute)),
            onTap: () => Navigator.pop(context, 'NOW'),
          ),
          const Divider(color: Color(0x229FB0C8)),
          ListTile(
            leading: const Icon(Icons.calendar_today, color: AppColors.orange),
            title: const Text('Запланировать',
                style: TextStyle(
                    color: AppColors.text, fontWeight: FontWeight.w700)),
            subtitle: const Text('Выберите дату и время',
                style: TextStyle(color: AppColors.textMute)),
            onTap: () async {
              Navigator.pop(context);
              await _showDateTimePicker();
            },
          ),
          if (_deliveryTime != 'NOW' && _selectedDeliveryDateTime != null) ...[
            const Divider(color: Color(0x229FB0C8)),
            ListTile(
              leading: const Icon(Icons.clear, color: AppColors.orange),
              title: const Text('Сбросить',
                  style: TextStyle(
                      color: AppColors.text, fontWeight: FontWeight.w700)),
              subtitle: const Text('Очистить выбранное время',
                  style: TextStyle(color: AppColors.textMute)),
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
      await _showNotice(
          'Некорректное время', 'Нельзя выбрать время в прошлом.');
      return;
    }

    // Проверяем, что время в пределах 24 часов
    if (selectedDateTime.isAfter(now.add(const Duration(hours: 24)))) {
      await _showNotice(
          'Некорректное время', 'Доставка возможна только в течение 24 часов.');
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
    final businessProvider =
        Provider.of<BusinessProvider>(context, listen: false);
    final itemsTotal = cartProvider.getTotalPrice();
    final bagCost = _checkoutBagCost(
        cartProvider.displayGroups, businessProvider.selectedBusiness);
    final hasCertificate = _appliedCertificateData != null;
    final promoDiscount = hasCertificate
        ? 0.0
        : (_appliedPromoData?['promo_discount'] as num?)?.toDouble() ?? 0.0;

    // Bonuses apply only to items (not delivery).
    final bonusApplied =
        _useBonus && _bonusData != null && _bonusData!['success'] == true
            ? _getUsedBonuses()
            : 0.0;
    final certificateApplied = _getCertificateAmount();
    final payableItemsTotal = (itemsTotal +
            bagCost -
            promoDiscount -
            bonusApplied -
            certificateApplied)
        .clamp(0.0, double.infinity)
        .toDouble();

    return payableItemsTotal +
        _getEffectiveDeliveryCost() +
        _getServiceFeeAmount() +
        _getCourierTips();
  }

  double _getEffectiveDeliveryCost() {
    if (_deliveryType != 'DELIVERY') {
      return 0.0;
    }
    final baseDeliveryCost =
        (_deliveryData?['base_delivery_cost'] as num?)?.toDouble();
    final fallbackDeliveryCost =
        (_deliveryData?['delivery_cost'] as num?)?.toDouble() ?? 0.0;
    final promoDeliveryPrice = _appliedCertificateData == null
        ? (_appliedPromoData?['final_delivery_price'] as num?)?.toDouble()
        : null;
    final deliveryCost = promoDeliveryPrice != null
        ? promoDeliveryPrice - _getServiceFeeAmount()
        : baseDeliveryCost ?? fallbackDeliveryCost;
    return deliveryCost
        .clamp(0.0, double.infinity)
        .toDouble();
  }

  double _getServiceFeeAmount() {
    if (_deliveryType != 'DELIVERY') {
      return 0.0;
    }
    final serviceFee =
        (_deliveryData?['service_fee_amount'] as num?)?.toDouble();
    if (serviceFee != null) {
      return serviceFee.clamp(0.0, double.infinity).toDouble();
    }

    final totalDelivery =
        (_deliveryData?['delivery_cost'] as num?)?.toDouble() ?? 0.0;
    final baseDelivery =
        (_deliveryData?['base_delivery_cost'] as num?)?.toDouble();
    if (baseDelivery == null) {
      return 0.0;
    }
    return (totalDelivery - baseDelivery)
        .clamp(0.0, double.infinity)
        .toDouble();
  }

  int _getCourierTips() {
    if (_deliveryType != 'DELIVERY') {
      return 0;
    }
    return _selectedCourierTips.clamp(0, 999999);
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
    final availableBonuses =
        (_bonusData!['data']['totalBonuses'] as num?)?.toDouble() ?? 0.0;

    // Возвращаем меньшее из: доступные бонусы, максимально допустимое использование (30%), или сумма товаров
    return [availableBonuses, maxBonusUsage, itemsTotal]
        .reduce((a, b) => a < b ? a : b);
  }

  double _certificateOrderSubtotal() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final businessProvider =
        Provider.of<BusinessProvider>(context, listen: false);
    return cartProvider.getTotalPrice() +
        _checkoutBagCost(
            cartProvider.displayGroups, businessProvider.selectedBusiness);
  }

  Map<String, dynamic>? _appliedCertificate() {
    if (_appliedCertificateData == null) return null;
    final certificate =
        ApiService.mapFromDynamic(_appliedCertificateData!['certificate']);
    if (certificate.isNotEmpty) return certificate;
    final code = _promoCodeController.text.trim();
    if (code.isNotEmpty) {
      return <String, dynamic>{'code': code};
    }
    return null;
  }

  double _certificateMaxAvailableAmount() {
    if (_appliedCertificateData == null) return 0.0;
    final data = _appliedCertificateData!;
    return _asDouble(
      data['max_available_amount'] ??
          data['certificate_amount'] ??
          data['amount'] ??
          _appliedCertificate()?['balance'],
    );
  }

  double _getCertificateAmount() {
    if (_appliedCertificateData == null) {
      return 0.0;
    }
    return certificateAppliedAmount(
      itemsTotal: _certificateOrderSubtotal(),
      bonusAmount: _getUsedBonuses(),
      maxAvailableAmount: _certificateMaxAvailableAmount(),
    );
  }

  int _getEarnedBonuses() {
    if (_isPromoCodeApplied) {
      return 0;
    }
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    return _calculateEarnedBonuses(cartProvider.displayGroups);
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final displayGroups = cartProvider.displayGroups;
    final businessProvider = Provider.of<BusinessProvider>(context);
    final bool hasCheckoutBag =
        _shouldAddCheckoutBag(displayGroups, businessProvider.selectedBusiness);
    final double bagCost = hasCheckoutBag ? _checkoutBagPrice : 0.0;
    final int checkoutItemCount =
        displayGroups.length + (hasCheckoutBag ? 1 : 0);
    final deliveryCost = _getEffectiveDeliveryCost();
    final serviceFeeAmount = _getServiceFeeAmount();
    final itemsTotal = cartProvider.getTotalPrice();
    final hasCertificate = _appliedCertificateData != null;
    final promoDiscount = hasCertificate
        ? 0.0
        : (_appliedPromoData?['promo_discount'] as num?)?.toDouble() ?? 0.0;
    final courierTips = _getCourierTips();
    final totalWithDelivery = _getTotalWithDelivery();
    final earnedBonuses = _getEarnedBonuses();
    final bool canUseBonus =
        _bonusData != null && _bonusData!['success'] == true;
    final double bonusUsed = _useBonus ? _getUsedBonuses() : 0.0;
    final double certificateUsed = _getCertificateAmount();

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
          title: Text('Оформление',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.sp)),
        ),
        bottomNavigationBar: _bottomCheckoutBar(total: totalWithDelivery),
        body: Stack(
          children: [
            const AppBackground(),
            GestureDetector(
              onTap: _dismissKeyboard,
              behavior: HitTestBehavior.translucent,
              child: SafeArea(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(16.s, 4.s, 16.s, 100.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _deliveryTabs(),
                      SizedBox(height: 14.s),
                      _tapRow(
                        icon: Icons.store,
                        title:
                            businessProvider.selectedBusinessName ?? 'Магазин',
                        value: businessProvider.selectedBusiness?['address'],
                        onTap: _showBusinessSelectionSheet,
                      ),
                      if (_deliveryType == 'DELIVERY') ...[
                        _tapRow(
                          icon: Icons.location_on_outlined,
                          title: _selectedAddress == null
                              ? 'Адрес доставки'
                              : _addressText(),
                          value: _addressDetailsText(),
                          onTap: () => _showAddressSelectionModal(),
                        ),
                        _tapRow(
                          icon: Icons.local_shipping_outlined,
                          title: 'Стоимость доставки',
                          value: _isCalculatingDelivery
                              ? 'считаем…'
                              : (deliveryCost > 0 ? _money(deliveryCost) : '—'),
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
                      _benefitSection(canUseBonus: canUseBonus),
                      _thinDivider(),
                      _sectionTitle('Ваш заказ · $checkoutItemCount поз.'),
                      SizedBox(height: 8.s),
                      for (int i = 0; i < displayGroups.length; i++) ...[
                        if (i > 0)
                          Divider(
                              color: Colors.white.withValues(alpha: 0.05),
                              height: 16.s),
                        _itemTile(displayGroups[i]),
                      ],
                      if (hasCheckoutBag) ...[
                        if (displayGroups.isNotEmpty)
                          Divider(
                              color: Colors.white.withValues(alpha: 0.05),
                              height: 16.s),
                        _bagTile(),
                      ],
                      _thinDivider(),
                      _summaryRow('Товары', _money(itemsTotal)),
                      SizedBox(height: 6.s),
                      if (bagCost > 0) ...[
                        _summaryRow('Пакет', _money(bagCost),
                            valueColor: AppColors.orange),
                        SizedBox(height: 6.s),
                      ],
                      if (_deliveryType == 'DELIVERY') ...[
                        _summaryRow(
                            'Доставка',
                            deliveryCost > 0
                                ? _money(deliveryCost)
                                : '—'),
                        SizedBox(height: 6.s),
                        if (serviceFeeAmount > 0) ...[
                          _summaryRow(
                              'Сервисный сбор',
                              _money(serviceFeeAmount),
                              valueColor: AppColors.orange),
                          SizedBox(height: 6.s),
                        ],
                        _courierTipsSelector(),
                        if (courierTips > 0) ...[
                          SizedBox(height: 6.s),
                          _summaryRow(
                              'Чаевые курьеру',
                              _money(courierTips.toDouble()),
                              valueColor: AppColors.orange),
                        ],
                        SizedBox(height: 6.s),
                      ],
                      if (promoDiscount > 0) ...[
                        _summaryRow('Промокод', '-${_money(promoDiscount)}',
                            valueColor: Colors.greenAccent),
                        SizedBox(height: 6.s),
                      ],
                      if (bonusUsed > 0) ...[
                        _summaryRow('Списание бонусов', '-${_money(bonusUsed)}',
                            valueColor: Colors.greenAccent),
                        SizedBox(height: 6.s),
                      ],
                      if (certificateUsed > 0) ...[
                        _summaryRow('Сертификат', '-${_money(certificateUsed)}',
                            valueColor: Colors.greenAccent),
                        SizedBox(height: 6.s),
                      ],
                      if (earnedBonuses > 0) ...[
                        _summaryRow('Бонусы за заказ', '+$earnedBonuses ₸',
                            valueColor: Colors.greenAccent),
                        SizedBox(height: 6.s),
                      ],
                      Divider(
                          color: Colors.white.withValues(alpha: 0.08),
                          height: 20.s),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Итого',
                              style: TextStyle(
                                  color: AppColors.text,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w800)),
                          Text(_money(totalWithDelivery),
                              style: TextStyle(
                                  color: AppColors.orange,
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ],
                  ),
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
      decoration: AppDecorations.card(
          radius: 22, color: AppColors.cardDark.withValues(alpha: 0.9)),
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
      child: Text(text,
          style: TextStyle(
              color: AppColors.textMute,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4)),
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
                  Text(title,
                      style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.sp)),
                  if (value != null)
                    Text(value,
                        style: TextStyle(
                            color: AppColors.textMute, fontSize: 12.sp),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, color: AppColors.textMute, size: 18.s),
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
              _selectedCourierTips = 0;
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

  static String _fmtQty(double qty) {
    return (qty - qty.roundToDouble()).abs() < 0.001
        ? qty.toStringAsFixed(0)
        : qty.toStringAsFixed(2);
  }

  static String _displayQty(CartDisplayGroup item) {
    return subtractPromotionBundleLabel(
      item.totalQuantity,
      item.promotions,
      formatQuantity: _fmtQty,
    );
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
                  style: const TextStyle(
                      color: AppColors.textMute,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              Text(itemTitle.name,
                  style: const TextStyle(
                      color: AppColors.text, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('x${_displayQty(item)}',
                      style: const TextStyle(
                          color: AppColors.textMute, fontSize: 12)),
                  if (bottleBreakdown != null) ...[
                    SizedBox(width: 6.s),
                    Expanded(
                      child: Text(
                        bottleBreakdown,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.textMute,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600),
                      ),
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
            Text(_money(item.totalPrice),
                style: const TextStyle(
                    color: AppColors.orange, fontWeight: FontWeight.w900)),
          ],
        ),
      ],
    );
  }

  int? _bagItemIdForBusiness(Map<String, dynamic>? business) {
    final businessId = _asInt(_businessIdOf(business));
    if (businessId == null) {
      return null;
    }
    return _bagItemIdForBusinessId(businessId);
  }

  int? _bagItemIdForBusinessId(int businessId) {
    return _bagItemIdsByShopId[businessId];
  }

  bool _shouldAddCheckoutBag(
      Iterable<CartDisplayGroup> items, Map<String, dynamic>? business) {
    final bagItemId = _bagItemIdForBusiness(business);
    return items.isNotEmpty &&
        bagItemId != null &&
        !_hasExplicitBag(items, bagItemId);
  }

  double _checkoutBagCost(
      Iterable<CartDisplayGroup> items, Map<String, dynamic>? business) {
    return _shouldAddCheckoutBag(items, business) ? _checkoutBagPrice : 0.0;
  }

  List<Map<String, dynamic>> _orderItemsWithBag(CartProvider cartProvider,
      {required int? bagItemId}) {
    final items = cartProvider.items
        .map((item) => item.toJsonForOrder())
        .toList(growable: true);
    if (bagItemId == null) {
      return items;
    }

    final hasBag = items.any((item) => _asInt(item['item_id']) == bagItemId);
    if (!hasBag) {
      items.add({
        'item_id': bagItemId,
        'amount': 1,
        'options': const <Map<String, dynamic>>[],
      });
    }
    return items;
  }

  bool _hasExplicitBag(Iterable<CartDisplayGroup> items, int bagItemId) {
    return items.any((item) {
      if (item.itemId == bagItemId) {
        return true;
      }
      final snapshot = item.itemSnapshot;
      final name = snapshot?.name ?? item.name;
      final normalized = name.toLowerCase().replaceAll('ё', 'е');
      return normalized.contains('пакет') || normalized.contains('bag');
    });
  }

  Widget _bagTile() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42.s,
          height: 42.s,
          decoration: BoxDecoration(
            color: AppColors.cardDark.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14.s),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.shopping_bag_outlined,
              color: AppColors.orange, size: 18.s),
        ),
        SizedBox(width: 12.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Пакет',
                  style: TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.sp)),
              SizedBox(height: 6.s),
              Text('x1',
                  style: TextStyle(
                      color: AppColors.textMute,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        SizedBox(width: 12.s),
        Text(
          _money(_checkoutBagPrice),
          style: TextStyle(
              color: AppColors.orange,
              fontSize: 14.sp,
              fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value,
      {Color valueColor = AppColors.text}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(color: AppColors.textMute, fontSize: 12.sp)),
        Text(value,
            style: TextStyle(
                color: valueColor,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _courierTipsSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Чаевые курьеру',
            style: TextStyle(color: AppColors.textMute, fontSize: 12.sp)),
        SizedBox(height: 8.s),
        Row(
          children: [
            for (int i = 0; i < _courierTipPresetAmounts.length; i++) ...[
              if (i > 0) SizedBox(width: 8.s),
              Expanded(
                child: _courierTipButton(
                  label: _money(_courierTipPresetAmounts[i].toDouble()),
                  amount: _courierTipPresetAmounts[i],
                ),
              ),
            ],
            SizedBox(width: 8.s),
            Expanded(
              child: _courierTipButton(
                label: _selectedCourierTips > 0 &&
                        !_courierTipPresetAmounts
                            .contains(_selectedCourierTips)
                    ? _money(_selectedCourierTips.toDouble())
                    : 'Другая',
                amount: null,
                onTap: _showCustomCourierTipDialog,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _courierTipButton({
    required String label,
    required int? amount,
    VoidCallback? onTap,
  }) {
    final selected = amount != null
        ? _selectedCourierTips == amount
        : _selectedCourierTips > 0 &&
            !_courierTipPresetAmounts.contains(_selectedCourierTips);
    final foreground = selected ? Colors.black : AppColors.text;

    return GestureDetector(
      onTap: onTap ??
          () {
            if (amount == null) return;
            setState(() {
              _selectedCourierTips = selected ? 0 : amount;
            });
          },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(vertical: 10.s, horizontal: 8.s),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.orange
              : AppColors.cardDark.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14.s),
          border: Border.all(
            color: selected
                ? AppColors.orange
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: foreground,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Future<void> _showCustomCourierTipDialog() async {
    final controller = TextEditingController(
      text: _selectedCourierTips > 0 &&
              !_courierTipPresetAmounts.contains(_selectedCourierTips)
          ? _selectedCourierTips.toString()
          : '',
    );

    final result = await AppDialogs.show<int>(
      context,
      title: 'Чаевые курьеру',
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: AppColors.text),
        decoration: InputDecoration(
          hintText: 'Введите сумму',
          hintStyle: TextStyle(
              color: AppColors.textMute.withValues(alpha: 0.55)),
          suffixText: '₸',
          suffixStyle: const TextStyle(color: AppColors.textMute),
          filled: true,
          fillColor: AppColors.cardDark,
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(0),
          style: TextButton.styleFrom(foregroundColor: AppColors.textMute),
          child: const Text('Убрать'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.textMute),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () {
            final amount = _asInt(controller.text.trim()) ?? 0;
            Navigator.of(context, rootNavigator: true).pop(amount);
          },
          style: TextButton.styleFrom(foregroundColor: AppColors.orange),
          child: const Text('Готово'),
        ),
      ],
    );
    controller.dispose();
    if (!mounted || result == null) return;
    setState(() {
      _selectedCourierTips = result.clamp(0, 999999);
    });
  }

  Widget _bottomCheckoutBar({required double total}) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.s, 10.s, 16.s, 10.s),
      decoration: BoxDecoration(
        color: AppColors.bgDeep,
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Text(_money(total),
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w900)),
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
            gradient: const LinearGradient(
                colors: [Color(0xFF8B1F1E), AppColors.red]),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 16.s),
              SizedBox(width: 9.s),
              Text(label,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  String _addressText() {
    return ApiService.formatAddressSummary(_selectedAddress,
        emptyText: 'Выберите адрес');
  }

  String _addressDetailsText() {
    if (_selectedAddress == null) {
      return 'Выбрать';
    }

    final parts = <String>[];
    final entrance = _entranceController.text.trim();
    final floor = _floorController.text.trim();
    final apartment = _apartmentController.text.trim();

    if (entrance.isNotEmpty) parts.add('под. $entrance');
    if (floor.isNotEmpty) parts.add('эт. $floor');
    if (apartment.isNotEmpty) parts.add('кв. $apartment');

    return parts.isEmpty ? 'Уточнить детали' : parts.join(' · ');
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

  bool _hasCompleteAddressDetails() {
    return _entranceController.text.trim().isNotEmpty &&
        _floorController.text.trim().isNotEmpty &&
        _apartmentController.text.trim().isNotEmpty;
  }

  Future<void> _showNotice(String title, String message) {
    return AppDialogs.showMessage(
      context,
      title: title,
      message: message,
    );
  }

  dynamic _businessIdOf(Map<String, dynamic>? business) {
    return business?['id'] ??
        business?['business_id'] ??
        business?['businessId'];
  }

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(
          value?.toString().replaceAll(' ', '').replaceAll(',', '.') ?? '',
        ) ??
        0.0;
  }

  int? _certificateIdOf(Map<String, dynamic> certificate) {
    return _asInt(certificate['certificate_id'] ?? certificate['id']);
  }

  String? _detectBusinessCity(
      Map<String, dynamic> business, List<String> availableCities) {
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
    return value
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[^a-zа-я0-9]+'), ' ')
        .trim();
  }

  void _toggleBonuses(bool value) {
    setState(() {
      _useBonus = value;
      if (value) {
        _appliedPromoData = null;
        _appliedCertificateData = null;
        _promoCodeController.clear();
      }
    });
  }

  Widget _benefitSection({required bool canUseBonus}) {
    final isChecking = _isValidatingPromo || _isValidatingCertificate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle('Бонусы и промокод')),
            _faqInfoButton(),
          ],
        ),
        SizedBox(height: 8.s),
        _bonusToggleTile(canUseBonus: canUseBonus),
        SizedBox(height: 12.s),
        TextField(
          enabled: !_useBonus,
          controller: _promoCodeController,
          textInputAction: TextInputAction.done,
          onSubmitted:
              _useBonus ? null : (_) => _validateAndApplyBenefitCode(),
          onTapOutside: (_) => _dismissKeyboard(),
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) {
            if (_appliedPromoData != null || _appliedCertificateData != null) {
              setState(() {
                _appliedPromoData = null;
                _appliedCertificateData = null;
              });
            }
          },
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w700,
            fontSize: 13.sp,
          ),
          decoration: InputDecoration(
            hintText: 'Промокод или сертификат',
            hintStyle: TextStyle(color: AppColors.textMute, fontSize: 12.sp),
            isDense: true,
            filled: true,
            fillColor: AppColors.card,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 14.s, vertical: 13.s),
            suffixIcon: _useBonus
                ? Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.textMute,
                    size: 18.s,
                  )
                : isChecking
                    ? Padding(
                        padding: EdgeInsets.all(12.s),
                        child: SizedBox.square(
                          dimension: 18.s,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.orange,
                          ),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Применить',
                        onPressed: _validateAndApplyBenefitCode,
                        icon: Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.orange,
                          size: 20.s,
                        ),
                      ),
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
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _appliedBenefitBanner(),
        ),
      ],
    );
  }

  Widget _bonusToggleTile({required bool canUseBonus}) {
    final bonusBalance = _asDouble(_bonusData?['data']?['totalBonuses']);
    return Row(
      children: [
        Icon(Icons.stars_rounded, color: AppColors.orange, size: 19.s),
        SizedBox(width: 10.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Списать бонусы',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                canUseBonus ? 'Доступно ${_money(bonusBalance)}' : 'Загрузка…',
                style: TextStyle(color: AppColors.textMute, fontSize: 12.sp),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: _useBonus,
          activeTrackColor: AppColors.orange,
          activeThumbColor: Colors.black,
          onChanged: canUseBonus ? _toggleBonuses : null,
        ),
      ],
    );
  }

  Widget _faqInfoButton() {
    return IconButton(
      tooltip: 'Как работают скидки',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: 32.s, height: 32.s),
      onPressed: () => openFaqPage(
        context,
        initialSection: FaqSection.bonuses,
      ),
      icon: Icon(
        Icons.info_outline_rounded,
        color: AppColors.textMute,
        size: 18.s,
      ),
    );
  }

  Widget _appliedBenefitBanner() {
    final hasPromo = _appliedPromoData != null;
    final hasCertificate = _appliedCertificateData != null;
    if (!hasPromo && !hasCertificate) {
      return const SizedBox.shrink(key: ValueKey('benefit-status-empty'));
    }

    final appliedCertificate = _appliedCertificate();
    final appliedCode = (hasPromo
            ? (_appliedPromoData?['promo_code'] ?? _promoCodeController.text)
            : appliedCertificate?['code'] ?? _promoCodeController.text)
        .toString()
        .trim();
    final promoDiscount =
        (_appliedPromoData?['promo_discount'] as num?)?.toDouble() ?? 0.0;
    final certificateAmount = _getCertificateAmount();
    final amount = hasPromo ? promoDiscount : certificateAmount;
    final label = hasPromo ? 'Промокод' : 'Сертификат';

    return Padding(
      key: ValueKey('benefit-status-$label'),
      padding: EdgeInsets.only(top: 8.s),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded,
              color: AppColors.orange, size: 16.s),
          SizedBox(width: 8.s),
          Expanded(
            child: Text(
              amount > 0
                  ? '$label: $appliedCode  ·  −${_money(amount)}'
                  : '$label: $appliedCode',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Убрать код',
            onPressed: _clearBenefitCode,
            icon: Icon(Icons.close_rounded,
                color: AppColors.textMute, size: 18.s),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  void _clearBenefitCode() {
    setState(() {
      _appliedPromoData = null;
      _appliedCertificateData = null;
      _promoCodeController.clear();
    });
  }

  Future<bool> _validateAndApplyBenefitCode() async {
    if (_useBonus) return false;

    final code = _promoCodeController.text.trim();
    if (code.isEmpty) {
      await _showNotice('Промокод', 'Введите код.');
      return false;
    }

    _dismissKeyboard();

    final promoApplied = await _validateAndApplyPromoCode(
      codeOverride: code,
      silentOnFailure: true,
    );
    if (promoApplied) return true;

    final certificateApplied = await _validateAndApplyCertificate(
      codeOverride: code,
      silentOnFailure: true,
      ignoreBonusSelection: true,
    );
    if (certificateApplied) return true;

    if (!mounted) return false;
    await _showNotice('Код не применён', 'Проверьте код и условия.');
    return false;
  }

  Future<bool> _validateAndApplyCertificate({
    Map<String, dynamic>? certificate,
    String? codeOverride,
    bool silentOnFailure = false,
    bool ignoreBonusSelection = false,
  }) async {
    final code = certificate?['code']?.toString().trim() ??
        codeOverride?.trim() ??
        _promoCodeController.text.trim();
    final certificateId =
        certificate == null ? null : _certificateIdOf(certificate);
    if (certificateId == null && code.isEmpty) {
      if (!silentOnFailure) {
        await _showNotice('Сертификат', 'Введите код сертификата.');
      }
      return false;
    }

    final eligibleSubtotal = certificateEligibleAfterBonuses(
      itemsTotal: _certificateOrderSubtotal(),
      bonusAmount: ignoreBonusSelection ? 0.0 : _getUsedBonuses(),
    );
    if (eligibleSubtotal <= 0) {
      if (!silentOnFailure) {
        await _showNotice(
          'Сертификат',
          'Товарная часть заказа уже покрыта бонусами.',
        );
      }
      return false;
    }

    setState(() => _isValidatingCertificate = true);
    try {
      final result = await ApiService.validateCertificate(
        certificateId: certificateId,
        code: certificateId == null ? code : null,
        orderSubtotal: eligibleSubtotal,
      );
      if (!mounted) return false;

      if (result['success'] == true) {
        final data =
            result['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
        if (data['can_use'] == false) {
          setState(() => _appliedCertificateData = null);
          if (!silentOnFailure) {
            await _showNotice(
              'Сертификат не применён',
              'Этот сертификат нельзя использовать для текущего заказа.',
            );
          }
          return false;
        }
        final validatedCertificate =
            ApiService.mapFromDynamic(data['certificate']);
        setState(() {
          _appliedCertificateData = data;
          _useBonus = false;
          _appliedPromoData = null;
          if (validatedCertificate['code'] != null) {
            _promoCodeController.text = validatedCertificate['code'].toString();
          }
        });
        return true;
      } else {
        setState(() => _appliedCertificateData = null);
        final error = result['error'];
        final message =
            error is Map ? error['message']?.toString() : error?.toString();
        if (!silentOnFailure) {
          await _showNotice(
            'Сертификат не применён',
            message?.isNotEmpty == true
                ? message!
                : 'Проверьте код и баланс сертификата.',
          );
        }
        return false;
      }
    } finally {
      if (mounted) {
        setState(() => _isValidatingCertificate = false);
      }
    }
  }

  Future<bool> _validateAndApplyPromoCode({
    String? codeOverride,
    bool silentOnFailure = false,
  }) async {
    final code = codeOverride?.trim() ?? _promoCodeController.text.trim();
    if (code.isEmpty) {
      if (!silentOnFailure) {
        await _showNotice('Промокод', 'Введите промокод.');
      }
      return false;
    }

    final businessProvider =
        Provider.of<BusinessProvider>(context, listen: false);
    final businessId = _asInt(_businessIdOf(businessProvider.selectedBusiness));
    if (businessId == null) {
      if (!silentOnFailure) {
        await _showNotice('Магазин не выбран', 'Сначала выберите магазин.');
      }
      return false;
    }

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final bagItemId = _bagItemIdForBusinessId(businessId);
    final orderItems = _orderItemsWithBag(cartProvider, bagItemId: bagItemId);
    final itemsForPromo = orderItems
        .map((item) => <String, dynamic>{
              'item_id': _asInt(item['item_id']) ?? 0,
              'amount': item['amount'] is num
                  ? item['amount']
                  : num.tryParse(item['amount']?.toString() ?? '0') ?? 0,
            })
        .where((item) => item['item_id'] != 0 && (item['amount'] as num) > 0)
        .toList(growable: false);

    final deliveryCost =
        (_deliveryData?['delivery_cost'] as num?)?.toDouble() ?? 0.0;
    final subtotal = cartProvider.getTotalPrice() +
        _checkoutBagCost(
            cartProvider.displayGroups, businessProvider.selectedBusiness);

    setState(() => _isValidatingPromo = true);
    try {
      final result = await ApiService.validatePromoCode({
        'promo_code': code,
        'business_id': businessId,
        'order_subtotal': subtotal,
        'delivery_price': _deliveryType == 'DELIVERY' ? deliveryCost : 0,
        'items': itemsForPromo,
      });
      if (!mounted) return false;
      if (result['success'] == true) {
        final data =
            result['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
        setState(() {
          _appliedPromoData = data;
          _useBonus = false;
          _appliedCertificateData = null;
          _promoCodeController.text = code;
        });
        return true;
      } else {
        setState(() => _appliedPromoData = null);
        final error = result['error'];
        final message =
            error is Map ? error['message']?.toString() : error?.toString();
        if (!silentOnFailure) {
          await _showNotice(
              'Промокод не применён',
              message?.isNotEmpty == true
                  ? message!
                  : 'Проверьте условия промокода.');
        }
        return false;
      }
    } finally {
      if (mounted) {
        setState(() => _isValidatingPromo = false);
      }
    }
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

    final parts = trimmed
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
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
      items.add(_CheckoutSheetItem.header(
          entry.key, entry.value.length, entry.key == widget.selectedCity));
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
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(14.s, 0, 14.s, 12.s),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Смена магазина очистит корзину и вернёт вас к каталогу.',
                  style: TextStyle(
                      color: AppColors.textMute.withValues(alpha: 0.6),
                      fontSize: 12.sp),
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
                          Icon(Icons.store_mall_directory,
                              color: AppColors.textMute, size: 32),
                          SizedBox(height: 10),
                          Text('в данный момент доставка не возможна',
                              style: TextStyle(
                                  color: AppColors.text, fontSize: 15)),
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
                          return _cityHeader(item.cityName!, item.shopCount!,
                              item.isCurrentCity!);
                        }
                        return Padding(
                          padding: EdgeInsets.only(bottom: 7.s),
                          child: _shopCard(listContext, item.business!,
                              item.isSelectedShop!),
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
            color: isCurrent
                ? AppColors.orange
                : AppColors.textMute.withValues(alpha: 0.5),
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
              color: isCurrent
                  ? AppColors.orange.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(9.s),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: isCurrent
                    ? AppColors.orange
                    : AppColors.textMute.withValues(alpha: 0.5),
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (isCurrent) ...[
            const Spacer(),
            Text(
              'текущий город',
              style: TextStyle(
                  color: AppColors.orange.withValues(alpha: 0.5),
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _shopCard(
      BuildContext context, Map<String, dynamic> shop, bool isSelected) {
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
          color: isSelected
              ? AppColors.orange.withValues(alpha: 0.10)
              : AppColors.cardDark,
          borderRadius: BorderRadius.circular(12.s),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.storefront_rounded,
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
                      style: TextStyle(
                          color: AppColors.textMute.withValues(alpha: 0.85),
                          fontSize: 12.sp,
                          height: 1.2),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Padding(
                padding: EdgeInsets.only(left: 7.s),
                child: Icon(Icons.check_rounded,
                    color: AppColors.orange, size: 18.s),
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
    return _CheckoutSheetItem._(
        isHeader: true,
        cityName: city,
        shopCount: count,
        isCurrentCity: isCurrent);
  }

  factory _CheckoutSheetItem.shop(
      Map<String, dynamic> business, bool isSelected) {
    return _CheckoutSheetItem._(
        isHeader: false, business: business, isSelectedShop: isSelected);
  }
}
