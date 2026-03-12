import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/payment_method_page.dart';
import 'package:naliv_delivery/shared/app_theme.dart';
import 'package:naliv_delivery/utils/address_storage_service.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:provider/provider.dart';
import '../utils/cart_provider.dart';
import 'package:naliv_delivery/widgets/address_selection_modal_material.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, авторизуйтесь')),
      );
      return;
    }

    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
    if (businessProvider.selectedBusiness == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите магазин')),
      );
      setState(() => _isSubmitting = false);
      return;
    }
    if (_selectedAddress == null && _deliveryType == 'DELIVERY') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите адрес доставки')),
      );
      setState(() => _isSubmitting = false);
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
      if (_useBonus) 'bonus_amount': _getUsedBonuses(),
      if (_selectedDeliveryDateTime != null) 'scheduled_time': _selectedDeliveryDateTime!.toIso8601String(),
      'saved_card_id': 1,
    };
    try {
      final result = await ApiService.createUserOrder(body);
      if (!mounted) return;

      if (result['success'] == true) {
        final orderData = result['data'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Заказ создан: ID ${orderData['order_id']}')),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentMethodPage(orderData: orderData),
          ),
        );
      } else {
        final errorMessage = result['error'] is Map ? result['error']['message'] : result['error'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка создания заказа: $errorMessage')),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите магазин')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось рассчитать доставку: $e')),
        );
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
    final cartTotal = cartProvider.getTotalPrice();

    double total = cartTotal;

    // Добавляем стоимость доставки
    if (_deliveryType == 'DELIVERY' && _deliveryData != null) {
      final deliveryCost = (_deliveryData!['delivery_cost'] as num?)?.toDouble() ?? 0.0;
      total += deliveryCost;
    }

    // Вычитаем бонусы если они используются
    if (_useBonus && _bonusData != null && _bonusData!['success'] == true) {
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
      final deliveryCost = (_deliveryData!['delivery_cost'] as num?)?.toDouble() ?? 0.0;
      total += deliveryCost;
    }

    // Максимум 25% от суммы заказа можно оплатить бонусами
    final maxBonusUsage = total * 0.25;
    final availableBonuses = (_bonusData!['data']['totalBonuses'] as num?)?.toDouble() ?? 0.0;

    // Возвращаем меньшее из: доступные бонусы, максимально допустимое использование (25%), или полная сумма
    return [availableBonuses, maxBonusUsage, total].reduce((a, b) => a < b ? a : b);
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

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.text,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('Оформление заказа', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  _deliveryTabs(),
                  const SizedBox(height: 12),
                  _infoCard(
                    icon: Icons.store,
                    title: businessProvider.selectedBusinessName ?? 'Магазин не выбран',
                    subtitle: businessProvider.selectedBusiness != null
                        ? businessProvider.selectedBusiness!['address'] ?? ''
                        : 'Выберите магазин на предыдущем экране',
                    onTap: () => Navigator.pop(context),
                  ),
                  if (_deliveryType == 'DELIVERY') ...[
                    const SizedBox(height: 10),
                    _infoCard(
                      icon: Icons.location_on_outlined,
                      title: 'Адрес доставки',
                      subtitle: _addressText(),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.textMute),
                      onTap: _showAddressSelectionModal,
                    ),
                    const SizedBox(height: 10),
                    _infoCard(
                      icon: Icons.local_shipping_outlined,
                      title: 'Стоимость доставки',
                      subtitle: _isCalculatingDelivery ? 'Рассчитываем…' : (deliveryCost > 0 ? _money(deliveryCost) : '—'),
                      onTap: _calculateDelivery,
                    ),
                    const SizedBox(height: 10),
                    _infoCard(
                      icon: Icons.access_time,
                      title: 'Время доставки',
                      subtitle: _getDeliveryTimeText(),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.textMute),
                      onTap: _showDeliveryTimeSelection,
                    ),
                  ],
                  const SizedBox(height: 14),
                  _sectionHeader('Товары в корзине'),
                  const SizedBox(height: 10),
                  ...cartProvider.items.map((item) => _itemTile(item)).toList(),
                  const SizedBox(height: 14),
                  _bonusCard(),
                  const SizedBox(height: 14),
                  _totalCard(itemsTotal: itemsTotal, deliveryCost: _deliveryType == 'DELIVERY' ? deliveryCost : 0, total: totalWithDelivery),
                  const SizedBox(height: 20),
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
    );
  }

  Widget _deliveryTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cardDark.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.orange : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
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
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(radius: 18, color: AppColors.cardDark.withValues(alpha: 0.95)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.orange, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: AppColors.textMute, fontSize: 13)),
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
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.2), shape: BoxShape.circle),
          child: const Icon(Icons.shopping_bag, color: AppColors.orange, size: 16),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 16)),
      ],
    );
  }

  Widget _itemTile(item) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(radius: 16, color: AppColors.cardDark.withValues(alpha: 0.9)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('x${item.stepQuantity == 1.0 ? item.quantity.toStringAsFixed(0) : item.quantity.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppColors.textMute, fontSize: 12)),
              ],
            ),
          ),
          Text(_money(item.totalPrice), style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _bonusCard() {
    final bool canUseBonus = _bonusData != null && _bonusData!['success'] == true;
    final subtitle = canUseBonus ? _buildBonusSubtitle() : const Text('Загрузка...', style: TextStyle(color: AppColors.textMute));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(radius: 18, color: AppColors.cardDark.withValues(alpha: 0.95)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Использовать бонусы', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
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
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(radius: 20, color: AppColors.cardDark.withValues(alpha: 0.96)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.receipt_long, color: AppColors.orange),
              SizedBox(width: 8),
              Text('Итоги', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          _summaryRow('Товары', _money(itemsTotal)),
          if (_deliveryType == 'DELIVERY') ...[
            const SizedBox(height: 8),
            _summaryRow('Доставка', deliveryCost > 0 ? _money(deliveryCost) : '—'),
          ],
          if (bonusUsed > 0) ...[
            const SizedBox(height: 8),
            _summaryRow('Бонусы', '-${_money(bonusUsed)}', valueColor: Colors.greenAccent),
          ],
          const Divider(color: Color(0x229FB0C8), height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Итого', style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800)),
              Text(_money(total), style: const TextStyle(color: AppColors.orange, fontSize: 20, fontWeight: FontWeight.w900)),
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
        Text(label, style: const TextStyle(color: AppColors.textMute, fontSize: 13)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.w700)),
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
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(colors: [Color(0xFF8B1F1E), AppColors.red]),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 10)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  String _addressText() {
    if (_selectedAddress == null) return 'Выберите адрес';
    final parts = <String>[_selectedAddress!['address'] ?? _selectedAddress!['street'] ?? 'Адрес не указан'];
    final detail = <String>[];
    if (_selectedAddress!['entrance']?.toString().isNotEmpty == true) detail.add('Под. ${_selectedAddress!['entrance']}');
    if (_selectedAddress!['floor']?.toString().isNotEmpty == true) detail.add('Эт. ${_selectedAddress!['floor']}');
    if (_selectedAddress!['apartment']?.toString().isNotEmpty == true) detail.add('Кв. ${_selectedAddress!['apartment']}');
    if (detail.isNotEmpty) parts.add(detail.join(', '));
    return parts.join(' • ');
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

    // Рассчитываем максимальную сумму для использования бонусов (25% от заказа)
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final cartTotal = cartProvider.getTotalPrice();
    double orderTotal = cartTotal;
    if (_deliveryType == 'DELIVERY' && _deliveryData != null) {
      final deliveryCost = (_deliveryData!['delivery_cost'] as num?)?.toDouble() ?? 0.0;
      orderTotal += deliveryCost;
    }
    final maxBonusUsage = orderTotal * 0.25;
    final availableToUse = totalBonuses > maxBonusUsage ? maxBonusUsage : totalBonuses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Доступно: $totalBonuses бонусов', style: const TextStyle(color: AppColors.text, fontSize: 13)),
        if (orderTotal > 0)
          Text(
            'Можно использовать: ${availableToUse.toStringAsFixed(0)} ₸ ',
            style: const TextStyle(color: AppColors.textMute, fontSize: 12),
          ),
        if (latestBonusAmount > 0)
          Text(
            'Последнее: +$latestBonusAmount ₸ ${_formatBonusDate(latestBonusDate)}',
            style: const TextStyle(color: AppColors.textMute, fontSize: 11),
          ),
      ],
    );
  }

  static String _money(double value) => '${value.toStringAsFixed(0)} ₸';
}
