import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/payment_method_page.dart';
import 'package:naliv_delivery/shared/app_theme.dart';
import 'package:naliv_delivery/utils/address_storage_service.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:naliv_delivery/utils/responsive.dart';
import 'package:provider/provider.dart';
import '../utils/cart_provider.dart';
import 'package:naliv_delivery/widgets/address_selection_modal_material.dart';
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

  Future<bool> _handleBack() async {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      // Safeguard: if this is the last route, return to cart instead of a blank screen.
      navigator.pushReplacement(MaterialPageRoute(builder: (_) => const CartPage()));
    }
    return false;
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
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) _showAddressSelectionModal();
        }
      });
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

  Future<void> _submitOrder() async {
    // Проверяем авторизацию
    final loggedIn = await ApiService.isUserLoggedIn();
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
    final deliveryCost = (_deliveryData?['delivery_cost'] as num?)?.toDouble() ?? 0.0;
    final itemsTotal = cartProvider.getTotalPrice();
    final totalWithDelivery = _getTotalWithDelivery();

    return WillPopScope(
      onWillPop: _handleBack,
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
          title: const Text('Оформление заказа', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: Stack(
          children: [
            const AppBackground(),
            SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(14.s, 0, 14.s, 24.s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 10.s),
                    _deliveryTabs(),
                    SizedBox(height: 10.s),
                    _infoCard(
                      icon: Icons.store,
                      title: businessProvider.selectedBusinessName ?? 'Магазин не выбран',
                      subtitle: businessProvider.selectedBusiness != null
                          ? businessProvider.selectedBusiness!['address'] ?? ''
                          : 'Выберите магазин на предыдущем экране',
                      onTap: () => Navigator.pop(context),
                    ),
                    if (_deliveryType == 'DELIVERY') ...[
                      SizedBox(height: 9.s),
                      _infoCard(
                        icon: Icons.location_on_outlined,
                        title: 'Адрес доставки',
                        subtitle: _addressText(),
                        trailing: const Icon(Icons.chevron_right, color: AppColors.textMute),
                        onTap: _showAddressSelectionModal,
                      ),
                      SizedBox(height: 9.s),
                      _addressDetailsCard(),
                      SizedBox(height: 9.s),
                      _infoCard(
                        icon: Icons.local_shipping_outlined,
                        title: 'Стоимость доставки',
                        subtitle: _isCalculatingDelivery ? 'Рассчитываем…' : (deliveryCost > 0 ? _money(deliveryCost) : '—'),
                        onTap: _calculateDelivery,
                      ),
                      SizedBox(height: 9.s),
                      _infoCard(
                        icon: Icons.access_time,
                        title: 'Время доставки',
                        subtitle: _getDeliveryTimeText(),
                        trailing: const Icon(Icons.chevron_right, color: AppColors.textMute),
                        onTap: _showDeliveryTimeSelection,
                      ),
                    ],
                    SizedBox(height: 12.s),
                    _sectionHeader('Товары в корзине'),
                    SizedBox(height: 9.s),
                    ...cartProvider.items.map((item) => _itemTile(item)).toList(),
                    SizedBox(height: 12.s),
                    _bonusCard(),
                    SizedBox(height: 12.s),
                    _totalCard(itemsTotal: itemsTotal, deliveryCost: _deliveryType == 'DELIVERY' ? deliveryCost : 0, total: totalWithDelivery),
                    SizedBox(height: 18.s),
                    _primaryButton(
                      label: _isSubmitting ? 'Отправка…' : 'Подтвердить заказ',
                      onTap: _isSubmitting ? null : _submitOrder,
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

  Widget _infoCard({required IconData icon, required String title, String? subtitle, Widget? trailing, VoidCallback? onTap}) {
    return Container(
      padding: EdgeInsets.all(12.s),
      decoration: AppDecorations.card(radius: 16, color: AppColors.cardDark.withValues(alpha: 0.95)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(9.s),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12.s),
            ),
            child: Icon(icon, color: AppColors.orange, size: 18.s),
          ),
          SizedBox(width: 10.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 14.sp)),
                if (subtitle != null) ...[
                  SizedBox(height: 3.s),
                  Text(subtitle, style: TextStyle(color: AppColors.textMute, fontSize: 12.sp)),
                ],
              ],
            ),
          ),
          if (trailing != null)
            InkWell(onTap: onTap, child: trailing)
          else if (onTap != null)
            IconButton(
              icon: const Icon(Icons.chevron_right, color: AppColors.textMute),
              onPressed: onTap,
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(5.s),
          decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.2), shape: BoxShape.circle),
          child: Icon(Icons.shopping_bag, color: AppColors.orange, size: 14.s),
        ),
        SizedBox(width: 7.s),
        Text(text, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 15.sp)),
      ],
    );
  }

  static double _freeAmount(item) {
    for (final promo in item.promotions) {
      final type = (promo['type'] as String?) ?? (promo['discount_type'] as String?);
      if (type == 'SUBTRACT') {
        final base = ((promo['baseAmount'] as num?) ?? (promo['base_amount'] as num?) ?? 0).toInt();
        final add = ((promo['addAmount'] as num?) ?? (promo['add_amount'] as num?) ?? 0).toInt();
        final groupSize = base + add;
        if (groupSize > 0 && base > 0 && item.quantity >= groupSize) {
          final count = item.quantity ~/ groupSize;
          return (count * add).toDouble();
        }
      }
    }
    return 0;
  }

  static String _fmtQty(double qty) {
    return (qty - qty.roundToDouble()).abs() < 0.001 ? qty.toStringAsFixed(0) : qty.toStringAsFixed(2);
  }

  Widget _itemTile(item) {
    final double freeQty = _freeAmount(item);
    final bool hasFree = freeQty > 0;
    final double rawTotal = item.price * item.quantity;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 5.s),
      padding: EdgeInsets.all(12.s),
      decoration: AppDecorations.card(radius: 14, color: AppColors.cardDark.withValues(alpha: 0.9)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('x${_fmtQty(item.quantity)}', style: const TextStyle(color: AppColors.textMute, fontSize: 12)),
                    if (hasFree) ...[
                      SizedBox(width: 6.s),
                      Text(
                        '(${_fmtQty(freeQty)} бесплатно)',
                        style: TextStyle(color: AppColors.orange, fontSize: 11.sp, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (hasFree)
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _bonusCard() {
    final bool canUseBonus = _bonusData != null && _bonusData!['success'] == true;
    final subtitle = canUseBonus ? _buildBonusSubtitle() : const Text('Загрузка...', style: TextStyle(color: AppColors.textMute));
    return Container(
      padding: EdgeInsets.all(12.s),
      decoration: AppDecorations.card(radius: 16, color: AppColors.cardDark.withValues(alpha: 0.95)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Использовать бонусы', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
                SizedBox(height: 5.s),
                subtitle,
              ],
            ),
          ),
          Switch(
            value: _useBonus,
            activeColor: Colors.black,
            activeTrackColor: AppColors.orange,
            inactiveThumbColor: AppColors.text,
            inactiveTrackColor: AppColors.blue,
            onChanged: canUseBonus
                ? (value) {
                    setState(() {
                      _useBonus = value;
                    });
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _totalCard({required double itemsTotal, required double deliveryCost, required double total}) {
    final bonusUsed = _useBonus ? _getUsedBonuses() : 0.0;
    return Container(
      padding: EdgeInsets.all(14.s),
      decoration: AppDecorations.card(radius: 18, color: AppColors.cardDark.withValues(alpha: 0.96)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: AppColors.orange, size: 20.s),
              SizedBox(width: 7.s),
              Text('Итоги', style: TextStyle(color: AppColors.text, fontSize: 15.sp, fontWeight: FontWeight.w800)),
            ],
          ),
          SizedBox(height: 10.s),
          _summaryRow('Товары', _money(itemsTotal)),
          if (_deliveryType == 'DELIVERY') ...[
            SizedBox(height: 7.s),
            _summaryRow('Доставка', deliveryCost > 0 ? _money(deliveryCost) : '—'),
          ],
          if (bonusUsed > 0) ...[
            SizedBox(height: 7.s),
            _summaryRow('Бонусы', '-${_money(bonusUsed)}', valueColor: Colors.greenAccent),
          ],
          Divider(color: const Color(0x229FB0C8), height: 16.s),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Итого', style: TextStyle(color: AppColors.text, fontSize: 16.sp, fontWeight: FontWeight.w800)),
              Text(_money(total), style: TextStyle(color: AppColors.orange, fontSize: 18.sp, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
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

    _showNotice('Незаполненный адрес', 'Укажите ${missing.join(', ')} для адреса доставки.');
    return false;
  }

  Future<void> _showNotice(String title, String message) {
    return AppDialogs.showMessage(
      context,
      title: title,
      message: message,
    );
  }

  Widget _addressDetailsCard() {
    return Container(
      padding: EdgeInsets.all(12.s),
      decoration: AppDecorations.card(radius: 16, color: AppColors.cardDark.withValues(alpha: 0.95)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.apartment_rounded, color: AppColors.orange),
              SizedBox(width: 8),
              Text('Детали адреса', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Подъезд, этаж и квартира обязательны для оформления доставки.',
            style: TextStyle(color: AppColors.textMute, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _detailField(controller: _entranceController, label: 'Подъезд')),
              const SizedBox(width: 8),
              Expanded(child: _detailField(controller: _floorController, label: 'Этаж')),
              const SizedBox(width: 8),
              Expanded(child: _detailField(controller: _apartmentController, label: 'Квартира')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailField({required TextEditingController controller, required String label}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMute, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: 'Обязательно',
            hintStyle: const TextStyle(color: AppColors.textMute, fontSize: 12),
            isDense: true,
            filled: true,
            fillColor: AppColors.card,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: AppColors.orange),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBonusSubtitle() {
    if (_bonusData == null || _bonusData!['success'] != true) {
      return const Text('Загрузка...', style: TextStyle(color: AppColors.textMute));
    }

    final bonusData = _bonusData!['data'];
    final totalBonuses = bonusData['totalBonuses'] ?? 0;
    final bonusHistory = bonusData['bonusHistory'] as List?;
    final latestBonusAmount = bonusHistory != null && bonusHistory.isNotEmpty ? bonusHistory.first['amount'] ?? 0 : 0;
    final latestBonusDate = bonusHistory != null && bonusHistory.isNotEmpty ? bonusHistory.first['timestamp'] ?? '' : '';

    // Рассчитываем максимальную сумму для использования бонусов (30% от суммы товаров, без доставки)
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final itemsTotal = cartProvider.getTotalPrice();
    final maxBonusUsage = itemsTotal * 0.30;
    final availableToUse = totalBonuses > maxBonusUsage ? maxBonusUsage : totalBonuses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Доступно: $totalBonuses ₸', style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w800)),
        Text(
          'Можно списать до ${availableToUse.toStringAsFixed(0)} ₸ (30% от товаров, доставка не списывается).',
          style: const TextStyle(color: AppColors.textMute, fontSize: 12, height: 1.35, fontWeight: FontWeight.w600),
        ),
        if (latestBonusAmount != 0)
          Padding(
            padding: EdgeInsets.only(top: 4.s),
            child: Text(
              'Последнее изменение: ${latestBonusAmount > 0 ? '+' : ''}$latestBonusAmount ₸ ${_formatBonusDate(latestBonusDate)}',
              style: const TextStyle(color: AppColors.textMute, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  static String _money(double value) => '${value.toStringAsFixed(0)} ₸';
}
