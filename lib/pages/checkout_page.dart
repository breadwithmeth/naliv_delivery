import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/theme.dart';
import '../design/typography.dart';
import '../features/cart/ui/cart_page.dart' as feature_cart;
import '../features/checkout/checkout_contract.dart';
import '../features/orders/ui/orders_page.dart';
import '../services/onboarding_service.dart';
import '../ui/app_states.dart';
import '../ui/app_top_bar.dart';
import '../ui/surfaces.dart';
import '../utils/address_storage_service.dart';
import '../utils/api.dart';
import '../utils/app_navigator.dart';
import '../utils/bonus_rules.dart';
import '../utils/business_provider.dart';
import '../utils/cart_provider.dart';
import '../utils/certificate_checkout_math.dart';
import '../utils/item_name_presentation.dart';
import '../utils/smart_cart.dart';
import '../utils/subtract_promotion_math.dart';
import '../widgets/address_selection_modal_material.dart';
import '../features/faq/models/faq.dart';
import '../features/faq/faq_navigation.dart';
import 'login_page.dart';
import 'payment_method_page.dart';

class CheckoutPage extends StatefulWidget {
  static const routeName = '/checkout';

  const CheckoutPage({
    super.key,
    this.initialDeliveryType,
    this.initialAddress,
    this.addressPicker,
    this.openCardForm,
    this.onPaymentCompleted,
    this.onCatalog,
  });

  final String? initialDeliveryType;
  final Map<String, dynamic>? initialAddress;
  final Future<Map<String, dynamic>?> Function(
      BuildContext, Map<String, dynamic>?, bool)? addressPicker;
  final Future<bool> Function(Uri)? openCardForm;
  final Future<void> Function(String orderId)? onPaymentCompleted;
  final VoidCallback? onCatalog;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  static const _bagIds = <int, int>{
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
  static const _bagPrice = 30.0;

  final _entrance = TextEditingController();
  final _floor = TextEditingController();
  final _apartment = TextEditingController();
  final _promo = TextEditingController();
  final _certificate = TextEditingController();
  CartProvider? _cart;
  BusinessProvider? _business;
  Map<String, dynamic>? _address;
  CheckoutQuote? _quote;
  Map<String, dynamic>? _promoData;
  Map<String, dynamic>? _certificateData;
  String _mode = 'DELIVERY';
  String _cartSnapshot = '';
  int? _storeSnapshot;
  int _revision = 0;
  int _quoteRequest = 0;
  int _benefitRequest = 0;
  bool _initializing = true;
  bool? _loggedIn;
  bool _loadingBonus = false;
  double? _bonusBalance;
  String? _bonusError;
  bool _useBonus = false;
  bool _quoting = false;
  bool _validating = false;
  bool _submitting = false;
  bool _pickingAddress = false;
  bool _switchingStore = false;
  bool _creationUncertain = false;
  bool _created = false;
  String? _quoteError;
  String? _addressError;
  String? _benefitError;
  String? _submitError;

  bool get _delivery => _mode == 'DELIVERY';
  int? get _businessId => _id(_business?.selectedBusiness);
  List<CartDisplayGroup> get _groups => _cart!.activeDisplayGroups;
  bool get _hasItems => _cart?.hasActiveItems == true;
  bool get _busy =>
      _initializing || _submitting || _switchingStore || _pickingAddress;
  bool get _quoteReady => !_delivery || (!_quoting && _quote != null);
  bool get _canSubmit =>
      _loggedIn == true &&
      _hasItems &&
      _businessId != null &&
      _quoteReady &&
      !_initializing &&
      !_busy &&
      !_validating &&
      !_creationUncertain &&
      !_created &&
      (!_delivery || _normalizedAddress() != null);

  @override
  void initState() {
    super.initState();
    if (widget.initialDeliveryType?.trim().toUpperCase() == 'PICKUP') {
      _mode = 'PICKUP';
    }
    if (widget.initialAddress != null) _setAddress(widget.initialAddress!);
    _promo.addListener(_codeChanged);
    _certificate.addListener(_codeChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cart = context.read<CartProvider>();
    final business = context.read<BusinessProvider>();
    if (identical(cart, _cart) && identical(business, _business)) return;
    _cart?.removeListener(_dependenciesChanged);
    _business?.removeListener(_dependenciesChanged);
    _cart = cart;
    _business = business;
    _cartSnapshot = _snapshotCart();
    _storeSnapshot = _businessId;
    cart.addListener(_dependenciesChanged);
    business.addListener(_dependenciesChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initialize();
    });
  }

  @override
  void dispose() {
    _cart?.removeListener(_dependenciesChanged);
    _business?.removeListener(_dependenciesChanged);
    for (final controller in [
      _entrance,
      _floor,
      _apartment,
      _promo,
      _certificate
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _snapshotCart() => jsonEncode({
        'items': _cart!.toJsonForOrder(),
        'total': _cart!.getTotalPrice(),
      });

  void _dependenciesChanged() {
    if (!mounted || _created || _switchingStore) return;
    final nextCart = _snapshotCart();
    final nextStore = _businessId;
    if (nextCart == _cartSnapshot && nextStore == _storeSnapshot) return;
    _cartSnapshot = nextCart;
    _storeSnapshot = nextStore;
    setState(_invalidate);
    _calculateDelivery();
  }

  void _invalidate() {
    _revision++;
    _quoteRequest++;
    _benefitRequest++;
    _quote = null;
    _quoting = false;
    _quoteError = null;
    _promoData = null;
    _certificateData = null;
    _validating = false;
    _benefitError = null;
    _useBonus = false;
    _submitError = null;
  }

  Future<void> _initialize() async {
    try {
      if (widget.initialAddress == null) {
        final saved = await AddressStorageService.getSelectedAddress();
        if (!mounted) return;
        if (saved != null) _setAddress(saved);
      }
    } catch (_) {
      if (mounted) {
        _addressError =
            'Не удалось прочитать сохранённый адрес. Выберите адрес заново.';
      }
    }
    try {
      final loggedIn = await ApiService.isUserLoggedIn();
      if (!mounted) return;
      setState(() {
        _loggedIn = loggedIn;
        _initializing = false;
      });
      _calculateDelivery();
      if (loggedIn) _loadBonuses();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loggedIn = false;
        _initializing = false;
        _submitError = 'Не удалось проверить авторизацию. Войдите в аккаунт.';
      });
    }
  }

  Future<void> _loadBonuses() async {
    if (_loadingBonus) return;
    setState(() {
      _loadingBonus = true;
      _bonusError = null;
    });
    try {
      final result = await ApiService.getUserBonuses();
      if (!mounted) return;
      final data = ApiService.mapFromDynamic(result?['data']);
      final balance = checkoutAmount(data['totalBonuses']);
      setState(() {
        _bonusBalance = result?['success'] == true ? balance : null;
        if (_bonusBalance == null) _bonusError = 'Не удалось загрузить бонусы';
      });
    } catch (_) {
      if (mounted) setState(() => _bonusError = 'Не удалось загрузить бонусы');
    } finally {
      if (mounted) setState(() => _loadingBonus = false);
    }
  }

  void _setAddress(Map<String, dynamic> address) {
    _address = Map<String, dynamic>.from(address);
    _entrance.text = address['entrance']?.toString() ?? '';
    _floor.text = address['floor']?.toString() ?? '';
    _apartment.text = address['apartment']?.toString() ?? '';
  }

  Map<String, dynamic>? _normalizedAddress() {
    if (_address == null) return null;
    final value = <String, dynamic>{
      ..._address!,
      'address': ApiService.formatAddressSummary(_address, emptyText: ''),
      'entrance': _entrance.text.trim(),
      'floor': _floor.text.trim(),
      'apartment': _apartment.text.trim(),
    };
    return AddressStorageService.deliveryAddress(value);
  }

  Future<void> _pickAddress() async {
    if (_busy) return;
    setState(() {
      _pickingAddress = true;
      _addressError = null;
    });
    try {
      final current = _normalizedAddress() ?? _address;
      final selected = widget.addressPicker != null
          ? await widget.addressPicker!(context, current, _address != null)
          : await AddressSelectionModalHelper.show(context,
              initialAddress: current, openDetailsFirst: _address != null);
      if (!mounted || selected == null) return;
      setState(() {
        _setAddress(selected);
        _invalidate();
      });
      final normalized = _normalizedAddress();
      if (normalized == null) {
        setState(() => _addressError =
            'Для адреса нужны точные координаты и название. Выберите его на карте.');
        return;
      }
      if (!await AddressStorageService.saveSelectedAddress(normalized)) {
        if (mounted) {
          setState(() => _addressError =
              'Адрес не сохранён на устройстве. Повторите сохранение.');
        }
      }
      if (mounted) _calculateDelivery();
    } catch (_) {
      if (mounted) {
        setState(() => _addressError =
            'Не удалось выбрать или сохранить адрес. Попробуйте ещё раз.');
      }
    } finally {
      if (mounted) setState(() => _pickingAddress = false);
    }
  }

  Future<void> _saveAddress() async {
    final normalized = _normalizedAddress();
    if (normalized == null || _busy) return;
    try {
      final saved = await AddressStorageService.saveSelectedAddress(normalized);
      if (!mounted) return;
      setState(() => _addressError = saved
          ? null
          : 'Адрес не сохранён на устройстве. Повторите сохранение.');
    } catch (_) {
      if (mounted) {
        setState(() => _addressError =
            'Адрес не сохранён на устройстве. Повторите сохранение.');
      }
    }
  }

  Future<void> _calculateDelivery() async {
    final request = ++_quoteRequest;
    final revision = _revision;
    final address = _normalizedAddress();
    final businessId = _businessId;
    if (!_delivery || !_hasItems || address == null || businessId == null) {
      if (mounted) {
        setState(() {
          _quote = null;
          _quoting = false;
        });
      }
      return;
    }
    setState(() {
      _quote = null;
      _quoting = true;
      _quoteError = null;
      _benefitRequest++;
      _promoData = null;
      _certificateData = null;
      _validating = false;
    });
    CheckoutQuote? quote;
    try {
      quote = CheckoutQuote.fromResponse(
          await ApiService.calculateDeliveryByAddress(
        businessId: businessId,
        lat: address['lat'] as double,
        lon: address['lon'] as double,
      ));
    } catch (_) {
      quote = null;
    }
    if (!mounted ||
        request != _quoteRequest ||
        revision != _revision ||
        !_delivery) {
      return;
    }
    setState(() {
      _quoting = false;
      _quote = quote;
      _quoteError = quote == null
          ? 'Не удалось рассчитать доставку. Без расчёта заказ не отправится.'
          : null;
    });
  }

  void _changeMode(String mode) {
    if (_busy || _mode == mode) return;
    setState(() {
      _mode = mode;
      _invalidate();
    });
    _calculateDelivery();
  }

  void _codeChanged() {
    if (!mounted) return;
    setState(() {
      _benefitRequest++;
      _validating = false;
      _promoData = null;
      _certificateData = null;
      _benefitError = null;
    });
  }

  void _toggleBonuses(bool value) {
    if (_busy) return;
    setState(() {
      _benefitRequest++;
      _validating = false;
      _useBonus = value;
      if (value) {
        _promoData = null;
        _certificateData = null;
      }
      _benefitError = null;
    });
  }

  Future<void> _validateCode({required bool certificate}) async {
    if (_validating || _busy || _useBonus) return;
    final code = (certificate ? _certificate : _promo).text.trim();
    if (code.isEmpty) {
      setState(() => _benefitError = 'Введите код');
      return;
    }
    if (_loggedIn != true) {
      setState(() => _benefitError = 'Войдите в аккаунт, чтобы применить код');
      return;
    }
    if (!_quoteReady || !_hasItems || _businessId == null) {
      setState(() => _benefitError =
          'Выберите магазин и адрес, дождитесь расчёта доставки');
      return;
    }
    final revision = _revision;
    final request = ++_benefitRequest;
    final controller = certificate ? _certificate : _promo;
    setState(() {
      _validating = true;
      _benefitError = null;
    });
    try {
      final result = certificate
          ? await ApiService.validateCertificate(
              code: code, orderSubtotal: _itemsSubtotal)
          : await ApiService.validatePromoCode({
              'promo_code': code,
              'business_id': _businessId,
              'order_subtotal': _itemsSubtotal,
              'delivery_price': _delivery ? _quote!.deliveryPrice : 0,
              'items': _orderItems()
                  .map((item) => {
                        'item_id': item['item_id'],
                        'amount': item['amount'],
                      })
                  .toList(),
            });
      if (!mounted ||
          revision != _revision ||
          request != _benefitRequest ||
          controller.text.trim() != code ||
          _useBonus) {
        return;
      }
      final data = ApiService.mapFromDynamic(result['data']);
      var accepted = result['success'] == true && data.isNotEmpty;
      if (certificate) {
        final actualCertificate =
            ApiService.mapFromDynamic(data['certificate']);
        final available = _certificateAvailable(data);
        accepted = accepted &&
            data['can_use'] != false &&
            available != null &&
            available > 0;
        if (accepted && actualCertificate.isEmpty) {
          data['certificate'] = {'code': code};
        }
      } else {
        accepted = accepted &&
            (checkoutAmount(data['promo_discount']) != null ||
                checkoutAmount(data['final_delivery_price']) != null);
        if (data.containsKey('promo_discount') &&
            checkoutAmount(data['promo_discount']) == null) {
          accepted = false;
        }
        if (data.containsKey('final_delivery_price') &&
            checkoutAmount(data['final_delivery_price']) == null) {
          accepted = false;
        }
      }
      setState(() {
        if (accepted) {
          _promoData = certificate ? null : {...data, 'promo_code': code};
          _certificateData = certificate ? data : null;
          _useBonus = false;
        } else {
          _benefitError = _errorMessage(
              result['error'], 'Код не применён. Проверьте код и условия.');
        }
      });
    } catch (_) {
      if (mounted && revision == _revision && request == _benefitRequest) {
        setState(() =>
            _benefitError = 'Не удалось проверить код. Попробуйте ещё раз.');
      }
    } finally {
      if (mounted && request == _benefitRequest) {
        setState(() => _validating = false);
      }
    }
  }

  Future<void> _selectStore() async {
    if (_busy) return;
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CheckoutStoreSheet(selectedId: _businessId),
    );
    if (!mounted || selected == null || _id(selected) == _businessId) return;
    final confirmed = !_hasItems ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Сменить магазин?'),
                content: const Text(
                    'Смена магазина очистит корзину и вернёт вас к выбору товаров.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Отмена')),
                  FilledButton(
                      key: const ValueKey('checkout-confirm-store'),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Сменить')),
                ],
              ),
            ) ==
            true;
    if (!mounted || !confirmed) return;
    setState(() => _switchingStore = true);
    final previous = _business!.selectedBusiness;
    String? previousCity;
    Map<String, dynamic>? previousAddress;
    var storeChanged = false;
    var cityChanged = false;
    try {
      previousCity = await OnboardingService.getSelectedCity();
      previousAddress = await AddressStorageService.getSelectedAddress();
      final city = selected.remove('_checkoutCity')?.toString();
      if (!await _business!.setSelectedBusiness(selected)) {
        throw StateError('Магазин не сохранён');
      }
      storeChanged = true;
      if (city != null && city.isNotEmpty && city != previousCity) {
        cityChanged = true;
        await OnboardingService.setSelectedCity(city);
        if (!await AddressStorageService.removeSelectedAddress()) {
          throw StateError('Не удалось сбросить адрес предыдущего города');
        }
      }
      if (!mounted) return;
      _cart!.clearCart();
      _goCatalog();
    } catch (_) {
      var restored = true;
      if (storeChanged) {
        restored = await _business!.setSelectedBusiness(previous);
      }
      if (cityChanged) {
        try {
          if (previousCity != null) {
            await OnboardingService.setSelectedCity(previousCity);
          } else {
            final prefs = await SharedPreferences.getInstance();
            if (!await prefs.remove('onboarding_selected_city')) {
              restored = false;
            }
          }
          if (previousAddress != null &&
              !await AddressStorageService.saveSelectedAddress(
                  previousAddress)) {
            restored = false;
          }
        } catch (_) {
          restored = false;
        }
      }
      if (mounted) {
        setState(() => _submitError = restored
            ? 'Магазин не изменён: не удалось сохранить выбор. Корзина сохранена.'
            : 'Не удалось сохранить выбор и восстановить настройки. Корзина сохранена; выберите магазин заново.');
      }
    } finally {
      if (mounted) {
        final persistenceError = _submitError;
        setState(() => _switchingStore = false);
        _dependenciesChanged();
        if (persistenceError != null) {
          setState(() => _submitError = persistenceError);
        }
      }
    }
  }

  Future<void> _submitOrder() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    final revision = _revision;
    var mutationStarted = false;
    try {
      if (!await ApiService.isUserLoggedIn()) {
        if (mounted) {
          setState(() {
            _loggedIn = false;
            _submitError = 'Войдите в аккаунт, чтобы оформить заказ';
          });
        }
        return;
      }
      if (!mounted || revision != _revision || !_hasItems || !_quoteReady) {
        return;
      }
      final address = _normalizedAddress();
      if (_delivery && address == null) {
        setState(() => _addressError = 'Выберите адрес с точными координатами');
        return;
      }
      if (_delivery &&
          !await AddressStorageService.saveSelectedAddress(address!)) {
        if (mounted) {
          setState(() => _addressError =
              'Адрес не сохранён на устройстве. Повторите сохранение перед заказом.');
        }
        return;
      }
      if (!mounted || revision != _revision || !_hasItems || !_quoteReady) {
        return;
      }
      final amount = _total;
      final certificate =
          ApiService.mapFromDynamic(_certificateData?['certificate']);
      final certificateId =
          _integer(certificate['certificate_id'] ?? certificate['id']);
      final body = <String, dynamic>{
        'business_id': _businessId,
        'street': _delivery ? address!['street'] ?? address['address'] : '',
        'house': _delivery ? address!['house'] ?? '-' : '',
        'lat': _delivery ? address!['lat'] : 0.0,
        'lon': _delivery ? address!['lon'] : 0.0,
        'apartment': _delivery ? address!['apartment'] : '',
        'entrance': _delivery ? address!['entrance'] : '',
        'floor': _delivery ? address!['floor'] : '',
        'extra': _delivery ? address!['comment'] ?? '' : '',
        'items': _orderItems(),
        'delivery_type': _mode,
        'delivery_time': 'NOW',
        'total_amount': amount,
        'courier_tips': 0,
        'use_bonuses': _useBonus,
        if (_useBonus) 'bonus_amount': _bonusUsed,
        if (_promoData != null) 'promo_code': _promoData!['promo_code'],
        if (_certificateData != null && _certificateUsed > 0) ...{
          if (certificateId != null) 'certificate_id': certificateId,
          if (certificateId == null)
            'certificate_code': certificate['code'] ?? _certificate.text.trim(),
          'certificate_amount': _certificateUsed,
        },
      };
      mutationStarted = true;
      final result = await ApiService.createUserOrder(body);
      final order = checkoutCreatedOrder(result);
      if (order != null) {
        _created = true;
        _cart!.clearCart();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
          builder: (_) => PaymentMethodPage(
            orderData: order,
            displayAmount: amount,
            openCardForm: widget.openCardForm,
            onPaymentCompleted: widget.onPaymentCompleted,
          ),
        ));
      } else if (mounted) {
        setState(() {
          _creationUncertain =
              result['success'] == true || result['statusCode'] == null;
          _submitError = _creationUncertain
              ? 'Статус создания заказа неизвестен. Проверьте «Мои заказы» перед новым оформлением. Корзина сохранена.'
              : _errorMessage(
                  result['error'], 'Заказ не создан. Корзина сохранена.');
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _creationUncertain = mutationStarted;
          _submitError = mutationStarted
              ? 'Статус создания заказа неизвестен. Проверьте «Мои заказы» перед новым оформлением.'
              : 'Не удалось подготовить заказ. Корзина и введённые данные сохранены.';
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool get _addBag {
    final bagId = _bagIds[_businessId];
    if (bagId == null || !_hasItems) return false;
    return !_groups.any((item) {
      if (item.itemId == bagId) return true;
      final name = (item.itemSnapshot?.name ?? item.name)
          .toLowerCase()
          .replaceAll('ё', 'е');
      return name.contains('пакет') || name.contains('bag');
    });
  }

  List<Map<String, dynamic>> _orderItems() {
    final items = _cart!.toJsonForOrder();
    if (_addBag) {
      items.add({
        'item_id': _bagIds[_businessId],
        'amount': 1,
        'options': <Map<String, dynamic>>[]
      });
    }
    return items;
  }

  double get _bagCost => _addBag ? _bagPrice : 0;
  double get _itemsSubtotal => _cart!.getTotalPrice() + _bagCost;
  double get _bonusUsed => _useBonus && _bonusBalance != null
      ? math.min(_bonusBalance!, _cart!.getTotalPrice() * 0.3)
      : 0;
  double? _certificateAvailable(Map<String, dynamic> data) {
    final certificate = ApiService.mapFromDynamic(data['certificate']);
    return checkoutAmount(data['max_available_amount'] ??
        data['certificate_amount'] ??
        data['amount'] ??
        certificate['balance']);
  }

  double get _certificateUsed => _certificateData == null
      ? 0
      : certificateAppliedAmount(
          itemsTotal: _itemsSubtotal,
          bonusAmount: _bonusUsed,
          maxAvailableAmount: _certificateAvailable(_certificateData!) ?? 0,
        );
  double get _promoDiscount => _certificateData == null
      ? checkoutAmount(_promoData?['promo_discount']) ?? 0
      : 0;
  double get _serviceFee => _delivery ? _quote?.serviceFee ?? 0 : 0;
  double get _deliveryCost {
    if (!_delivery || _quote == null) return 0;
    final promoPrice = _certificateData == null
        ? checkoutAmount(_promoData?['final_delivery_price'])
        : null;
    return promoPrice != null
        ? math.max(0, promoPrice - _serviceFee)
        : _quote!.baseDeliveryCost;
  }

  double get _total =>
      math.max(
          0, _itemsSubtotal - _promoDiscount - _bonusUsed - _certificateUsed) +
      _deliveryCost +
      _serviceFee;

  int get _earnedBonuses {
    if (_promoData != null) return 0;
    final eligible = _groups.fold<double>(0, (sum, group) {
      final item = group.itemSnapshot;
      return BonusRules.isBonusExcludedText(
              name: item?.name ?? group.name,
              description: item?.description,
              categoryName: item?.category?.name,
              code: item?.code)
          ? sum
          : sum + group.totalPrice;
    });
    return BonusRules.calculateEarnedBonuses(eligible);
  }

  void _goCatalog() {
    if (widget.onCatalog != null) {
      widget.onCatalog!();
    } else {
      AppNavigator.goToHome();
    }
  }

  void _back() {
    if (_busy) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    _openCart(replace: true);
  }

  void _openCart({bool replace = false}) {
    final navigator = Navigator.of(context);
    final route = MaterialPageRoute<void>(
      builder: (cartContext) => feature_cart.CartPage(
        businessId: _businessId,
        address:
            _address == null ? null : ApiService.formatAddressSummary(_address),
        onCatalog: _goCatalog,
        onCheckout: () =>
            Navigator.of(cartContext).push(MaterialPageRoute<void>(
          builder: (_) => CheckoutPage(
            addressPicker: widget.addressPicker,
            openCardForm: widget.openCardForm,
            onPaymentCompleted: widget.onPaymentCompleted,
            onCatalog: widget.onCatalog,
          ),
        )),
      ),
    );
    if (replace) {
      navigator.pushReplacement(route);
    } else {
      navigator.push(route);
    }
  }

  Future<void> _signIn() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const LoginPage(startWithPhoneForm: true)));
    if (!mounted) return;
    final loggedIn = await ApiService.isUserLoggedIn();
    if (!mounted) return;
    setState(() => _loggedIn = loggedIn);
    if (loggedIn) _loadBonuses();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<CartProvider>();
    context.watch<BusinessProvider>();
    return PopScope(
      canPop: !_busy && Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_busy) _back();
      },
      child: Scaffold(
        key: const ValueKey('checkout-page'),
        resizeToAvoidBottomInset: false,
        bottomNavigationBar: !_hasItems ? null : _bottomBar(),
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: MediaQuery.viewInsetsOf(context).bottom > 0
                  ? _checkoutContent(includeHeader: true)
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _header(),
                        ),
                        const SizedBox(height: 14),
                        Expanded(child: _checkoutContent()),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => AppTopBar(
        title: 'Оформление',
        onBack: _back,
        backEnabled: !_busy,
        trailing: IconButton(
          key: const ValueKey('checkout-faq'),
          tooltip: 'Помощь с оформлением',
          onPressed: () =>
              openFaqPage(context, initialSection: FaqSection.delivery),
          icon: const Icon(Icons.help_outline),
        ),
      );

  Widget _checkoutContent({bool includeHeader = false}) => ListView(
        key: const ValueKey('checkout-scroll'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          if (includeHeader) ...[_header(), const SizedBox(height: 14)],
          if (!_hasItems)
            AppEmptyState(
              key: const ValueKey('checkout-empty'),
              title: 'Корзина пуста',
              subtitle: 'Добавьте товары, чтобы оформить заказ',
              topOffset: 80,
              action: FilledButton(
                  onPressed: _goCatalog, child: const Text('В каталог')),
            )
          else ...[
            if (_initializing) const LinearProgressIndicator(),
            if (_loggedIn == false) ...[
              _message(
                'Войдите в аккаунт, чтобы оформить заказ',
                action: TextButton(
                  key: const ValueKey('checkout-sign-in'),
                  onPressed: _signIn,
                  child: const Text('Войти'),
                ),
              ),
              const SizedBox(height: 16),
            ],
            _fulfillment(),
            const SizedBox(height: 24),
            _benefits(),
            const SizedBox(height: 24),
            Text('Ваш заказ',
                style: AppTypography.title
                    .copyWith(color: context.palette.textPrimary)),
            const SizedBox(height: 12),
            for (final group in _groups) ...[
              _item(group),
              const SizedBox(height: 6),
            ],
            if (_addBag) _summaryRow('Пакет · 1 шт.', _money(_bagPrice)),
            const SizedBox(height: 24),
            _summary(),
            if (_submitError != null) ...[
              const SizedBox(height: 16),
              _message(
                _submitError!,
                key: const ValueKey('checkout-submit-error'),
                action: _creationUncertain
                    ? TextButton(
                        key: const ValueKey('checkout-check-orders'),
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => OrdersPage(
                                    businessId: _businessId,
                                    onCart: _openCart))),
                        child: const Text('Мои заказы'),
                      )
                    : null,
              ),
            ],
          ],
        ],
      );

  Widget _fulfillment() {
    final palette = context.palette;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AppSurface(
          radius: 100,
          padding: const EdgeInsets.all(2),
          child: Row(children: [
            for (final entry in [
              ('Доставка', 'DELIVERY'),
              ('Самовывоз', 'PICKUP')
            ])
              Expanded(
                  child: Semantics(
                      selected: _mode == entry.$2,
                      child: TextButton(
                        key:
                            ValueKey('checkout-mode-${entry.$2.toLowerCase()}'),
                        onPressed: _busy ? null : () => _changeMode(entry.$2),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          foregroundColor: _mode == entry.$2
                              ? palette.textOnAccent
                              : palette.textSecondary,
                          backgroundColor: _mode == entry.$2
                              ? palette.accent
                              : Colors.transparent,
                          shape: const StadiumBorder(),
                          textStyle: AppTypography.titleRegular,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 10),
                        ),
                        child: Text(entry.$1, textAlign: TextAlign.center),
                      ))),
          ])),
      const SizedBox(height: 16),
      _selectionTile(
          key: const ValueKey('checkout-store'),
          icon: Icons.storefront_outlined,
          title: _business?.selectedBusinessName ?? 'Выберите магазин',
          subtitle: _business?.selectedBusiness?['address']?.toString() ??
              'Магазин для заказа',
          onTap: _busy ? null : _selectStore),
      if (_switchingStore) const LinearProgressIndicator(),
      if (_delivery) ...[
        const SizedBox(height: 8),
        _selectionTile(
            key: const ValueKey('checkout-address'),
            icon: Icons.location_on_outlined,
            title: ApiService.formatAddressSummary(_address,
                emptyText: 'Выберите адрес'),
            subtitle: _address == null
                ? 'Нужен перед подтверждением заказа'
                : 'Изменить адрес или детали',
            onTap: _busy ? null : _pickAddress),
        if (_pickingAddress) const LinearProgressIndicator(),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
          final fields = [
            _addressField('Подъезд', _entrance, 'checkout-entrance'),
            _addressField('Этаж', _floor, 'checkout-floor'),
            _addressField('Квартира', _apartment, 'checkout-apartment'),
          ];
          return largeText
              ? Column(children: [
                  for (final field in fields)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 8), child: field)
                ])
              : Row(children: [
                  for (var i = 0; i < fields.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: fields[i]),
                  ]
                ]);
        }),
        if (_addressError != null) ...[
          const SizedBox(height: 8),
          _message(_addressError!,
              key: const ValueKey('checkout-address-error'),
              action: TextButton(
                  key: const ValueKey('checkout-save-address'),
                  onPressed: _busy
                      ? null
                      : (_normalizedAddress() == null
                          ? _pickAddress
                          : _saveAddress),
                  child: Text(_normalizedAddress() == null
                      ? 'Выбрать на карте'
                      : 'Повторить сохранение'))),
        ],
        const SizedBox(height: 16),
        _summaryRow(
            'Стоимость доставки',
            _quoting
                ? 'Рассчитываем…'
                : _quote == null
                    ? 'Не рассчитана'
                    : _money(_deliveryCost + _serviceFee)),
        if (_quoting)
          const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator()),
        if (_quoteError != null)
          _message(_quoteError!,
              key: const ValueKey('checkout-quote-error'),
              action: TextButton(
                  key: const ValueKey('checkout-quote-retry'),
                  onPressed: _busy ? null : _calculateDelivery,
                  child: const Text('Рассчитать ещё раз'))),
        if (_address != null &&
            _normalizedAddress() == null &&
            _addressError == null)
          _message('У адреса нет точных координат. Выберите его на карте.',
              action: TextButton(
                  onPressed: _busy ? null : _pickAddress,
                  child: const Text('Выбрать адрес'))),
      ],
      const SizedBox(height: 12),
      _summaryRow(_delivery ? 'Когда доставить' : 'Когда забрать',
          _delivery ? 'Сейчас' : 'Как можно скорее'),
    ]);
  }

  Widget _addressField(
          String label, TextEditingController controller, String key) =>
      TextField(
        key: ValueKey(key),
        controller: controller,
        enabled: !_busy && _address != null,
        keyboardType: TextInputType.text,
        textInputAction: key == 'checkout-apartment'
            ? TextInputAction.done
            : TextInputAction.next,
        onChanged: (_) => setState(() => _addressError = null),
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        style: AppTypography.body,
        decoration: InputDecoration(
            labelText: label,
            helperText: 'Необязательно',
            helperStyle: AppTypography.label
                .copyWith(color: context.palette.textSecondary),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 14)),
      );

  Widget _benefits() {
    final palette = context.palette;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text('Списать бонусы',
                style: AppTypography.titleMedium
                    .copyWith(color: palette.textPrimary))),
        Switch.adaptive(
            key: const ValueKey('checkout-bonus-toggle'),
            value: _useBonus,
            onChanged:
                !_busy && (_bonusBalance ?? 0) > 0 ? _toggleBonuses : null),
      ]),
      if (_loadingBonus)
        const LinearProgressIndicator()
      else if (_bonusBalance != null)
        Text(
            'На балансе: ${_money(_bonusBalance!)}\nМожно списать до ${_money(math.min(_bonusBalance!, _cart!.getTotalPrice() * 0.3))}',
            style:
                AppTypography.bodySmall.copyWith(color: palette.textSecondary)),
      if (_bonusError != null)
        _message(_bonusError!,
            action: TextButton(
                key: const ValueKey('checkout-bonus-retry'),
                onPressed: _loadBonuses,
                child: const Text('Обновить бонусы'))),
      TextButton(
          onPressed: () =>
              openFaqPage(context, initialSection: FaqSection.bonuses),
          child: const Text('Как работают бонусы')),
      const SizedBox(height: 8),
      _codeField('Промокод', _promo, false),
      const SizedBox(height: 16),
      _codeField('Сертификат', _certificate, true),
      if (_validating)
        const Padding(
            padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
      if (_useBonus)
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
                'Бонусы, промокод и сертификат применяются по отдельности.',
                style: AppTypography.bodySmall
                    .copyWith(color: palette.textSecondary))),
      if (_promoData != null || _certificateData != null)
        Padding(
            key: const ValueKey('checkout-benefit-applied'),
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Expanded(
                  child: Text(
                      _promoData != null
                          ? 'Промокод применён'
                          : 'Сертификат применён',
                      style: AppTypography.bodyMedium
                          .copyWith(color: palette.accent))),
              IconButton(
                  key: const ValueKey('checkout-clear-benefit'),
                  tooltip: 'Убрать скидку',
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _promoData = null;
                            _certificateData = null;
                            _benefitRequest++;
                          }),
                  icon: const Icon(Icons.close)),
            ])),
      if (_benefitError != null)
        _message(_benefitError!, key: const ValueKey('checkout-benefit-error')),
    ]);
  }

  Widget _codeField(
      String label, TextEditingController controller, bool certificate) {
    final name = certificate ? 'certificate' : 'promo';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style:
              AppTypography.title.copyWith(color: context.palette.textPrimary)),
      const SizedBox(height: 8),
      TextField(
        key: ValueKey('checkout-$name-code'),
        controller: controller,
        enabled: !_busy && !_useBonus,
        textCapitalization: TextCapitalization.characters,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _validateCode(certificate: certificate),
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        style: AppTypography.body,
        decoration: InputDecoration(
            hintText: 'Введите ${certificate ? 'код сертификата' : 'промокод'}',
            suffixIcon: IconButton(
                key: ValueKey('checkout-apply-$name'),
                tooltip: 'Применить $label',
                onPressed: !_busy && !_validating && !_useBonus
                    ? () => _validateCode(certificate: certificate)
                    : null,
                icon: const Icon(Icons.arrow_forward))),
      ),
    ]);
  }

  Widget _item(CartDisplayGroup group) {
    final snapshot = group.itemSnapshot;
    final name = snapshot != null
        ? presentItemName(
            rawName: snapshot.name, categoryName: snapshot.category?.name)
        : presentItemName(
            rawName: group.name,
            storedType: group.itemType,
            storedPackagingType: group.packagingType);
    final quantity = subtractPromotionBundleLabel(
        group.totalQuantity, group.promotions,
        formatQuantity: (value) => value == value.roundToDouble()
            ? value.toStringAsFixed(0)
            : value.toStringAsFixed(2));
    return AppSurface(
        key: ValueKey('checkout-item-${group.key}'),
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name.name,
              style: AppTypography.bodyBold
                  .copyWith(color: context.palette.textPrimary)),
          if (name.attributes.isNotEmpty)
            Text(name.attributes.join(' · '),
                style: AppTypography.bodySmall
                    .copyWith(color: context.palette.textSecondary)),
          if (group.bottleBreakdownLabel != null)
            Text(group.bottleBreakdownLabel!,
                style: AppTypography.bodySmall
                    .copyWith(color: context.palette.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
              spacing: 12,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text('× $quantity', style: AppTypography.bodySmall),
                if (group.totalPrice < group.subtotalBeforePromotions - 0.001)
                  Text(_money(group.subtotalBeforePromotions),
                      style: AppTypography.bodySmall.copyWith(
                          color: context.palette.textSecondary,
                          decoration: TextDecoration.lineThrough)),
                Text(_money(group.totalPrice),
                    style: AppTypography.bodyBold
                        .copyWith(color: context.palette.accent)),
              ]),
        ]));
  }

  Widget _summary() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Расчёт',
            style: AppTypography.title
                .copyWith(color: context.palette.textPrimary)),
        const SizedBox(height: 12),
        _summaryRow('Товары', _money(_cart!.getTotalPrice())),
        if (_bagCost > 0) _summaryRow('Пакет', _money(_bagCost)),
        if (_delivery)
          _summaryRow('Доставка',
              _quote == null ? 'Не рассчитана' : _money(_deliveryCost)),
        if (_serviceFee > 0) _summaryRow('Сервисный сбор', _money(_serviceFee)),
        if (_promoDiscount > 0)
          _summaryRow('Промокод', '−${_money(_promoDiscount)}'),
        if (_bonusUsed > 0) _summaryRow('Бонусы', '−${_money(_bonusUsed)}'),
        if (_certificateUsed > 0)
          _summaryRow('Сертификат', '−${_money(_certificateUsed)}'),
        if (_earnedBonuses > 0)
          _summaryRow(
              'Начислится бонусов', '+${_money(_earnedBonuses.toDouble())}'),
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
        _summaryRow(
            _quoteReady ? 'К оплате' : 'Товары без доставки', _money(_total),
            emphasized: true),
      ]);

  Widget _summaryRow(String label, String value, {bool emphasized = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: LayoutBuilder(builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final style = emphasized ? AppTypography.title : AppTypography.body;
          final labelWidget = Text(label,
              style: style.copyWith(color: context.palette.textSecondary));
          final valueWidget = Text(value,
              style: style.copyWith(
                  color: emphasized
                      ? context.palette.accent
                      : context.palette.textPrimary));
          return scale > 1.5 && constraints.maxWidth < 420
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [labelWidget, valueWidget])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: labelWidget),
                  const SizedBox(width: 12),
                  Flexible(child: valueWidget)
                ]);
        }),
      );

  Widget _selectionTile(
          {required Key key,
          required IconData icon,
          required String title,
          required String subtitle,
          required VoidCallback? onTap}) =>
      AppSurface(
        key: key,
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: context.palette.accent),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: AppTypography.titleMedium
                        .copyWith(color: context.palette.textPrimary)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: AppTypography.bodySmall
                        .copyWith(color: context.palette.textSecondary)),
              ])),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right),
        ]),
      );

  Widget _message(String text, {Widget? action, Key? key}) => AppSurface(
        key: key,
        fill: context.palette.accentFaint,
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text,
              style: AppTypography.bodySmall
                  .copyWith(color: context.palette.textPrimary)),
          if (action != null) action,
        ]),
      );

  Widget _bottomBar() => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: AppGlassPanel(
                  radius: 20,
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(builder: (context, constraints) {
                    final amount = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_quoteReady ? 'К оплате' : 'Без доставки',
                              style: AppTypography.bodySmall.copyWith(
                                  color: context.palette.textSecondary)),
                          Text(_money(_total),
                              key: const ValueKey('checkout-total'),
                              style: AppTypography.displayBold.copyWith(
                                  color: context.palette.textPrimary)),
                        ]);
                    final button = FilledButton(
                        key: const ValueKey('checkout-submit'),
                        onPressed: _canSubmit ? _submitOrder : null,
                        style: FilledButton.styleFrom(
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14)),
                        child: Text(_submitting ? 'Отправляем…' : 'Подтвердить',
                            textAlign: TextAlign.center));
                    final stacked = constraints.maxWidth < 290 ||
                        MediaQuery.textScalerOf(context).scale(14) > 20;
                    return stacked
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                                amount,
                                const SizedBox(height: 8),
                                button
                              ])
                        : Row(children: [
                            Expanded(child: amount),
                            const SizedBox(width: 12),
                            Flexible(child: button)
                          ]);
                  }),
                ),
              ),
            ),
          )));

  static int? _integer(dynamic value) {
    final parsed = value is int ? value : int.tryParse('$value');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  static int? _id(Map<String, dynamic>? business) => _integer(
      business?['id'] ?? business?['business_id'] ?? business?['businessId']);
  static String _money(double value) => '${value.toStringAsFixed(0)} ₸';
  static String _errorMessage(dynamic error, String fallback) {
    final text = (error is Map ? error['message'] : error)?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }
}

class _CheckoutStoreSheet extends StatefulWidget {
  const _CheckoutStoreSheet({required this.selectedId});
  final int? selectedId;
  @override
  State<_CheckoutStoreSheet> createState() => _CheckoutStoreSheetState();
}

class _CheckoutStoreSheetState extends State<_CheckoutStoreSheet> {
  List<Map<String, dynamic>>? _stores;
  List<String> _cities = [];
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cities =
          await OnboardingService.fetchAvailableCities(forceRefresh: true);
      final response = await ApiService.getBusinesses(page: 1, limit: 1000);
      final rawStores = response?['businesses'];
      final stores = rawStores is List &&
              rawStores.every((store) =>
                  store is Map &&
                  _CheckoutPageState._id(Map<String, dynamic>.from(store)) !=
                      null)
          ? ApiService.mapListFromDynamic(rawStores)
          : null;
      if (!mounted) return;
      setState(() {
        _cities = cities.map((city) => city.name).toList();
        _stores = stores;
        if (stores == null) _error = 'Не удалось загрузить магазины';
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось загрузить магазины');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _city(Map<String, dynamic> store) {
    final sources = [
      store['city'],
      store['city_name'],
      store['cityName'],
      store['city_title'],
      store['cityTitle'],
      store['address'],
      store['description']
    ];
    for (final source in sources) {
      final text = '$source'.toLowerCase().replaceAll('ё', 'е');
      for (final city in _cities) {
        if (text.contains(city.toLowerCase().replaceAll('ё', 'е'))) return city;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final store in _stores ?? <Map<String, dynamic>>[]) {
      groups.putIfAbsent(_city(store) ?? 'Магазины', () => []).add(store);
    }
    return SafeArea(
        child: SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Выберите магазин',
                style: AppTypography.headline
                    .copyWith(color: context.palette.textPrimary))),
        Expanded(
            child: _loading
                ? const AppLoading()
                : _error != null
                    ? AppErrorState(message: _error!, onRetry: _load)
                    : groups.isEmpty
                        ? const AppEmptyState(
                            title: 'Магазинов нет',
                            subtitle: 'Список доступных магазинов пуст')
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            children: [
                                for (final entry in groups.entries) ...[
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: Text(entry.key,
                                          style: AppTypography.title.copyWith(
                                              color: context
                                                  .palette.textPrimary))),
                                  for (final store in entry.value)
                                    Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
                                        child: AppSurface(
                                            onTap: () => Navigator.pop(
                                                    context, {
                                                  ...store,
                                                  '_checkoutCity': _city(store)
                                                }),
                                            key: ValueKey(
                                                'checkout-store-option-${_CheckoutPageState._id(store)}'),
                                            padding: const EdgeInsets.all(14),
                                            child: Row(children: [
                                              Icon(
                                                  _CheckoutPageState._id(
                                                              store) ==
                                                          widget.selectedId
                                                      ? Icons.check_circle
                                                      : Icons
                                                          .storefront_outlined,
                                                  color:
                                                      context.palette.accent),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                  child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                    Text(
                                                        '${store['name'] ?? store['title'] ?? 'Магазин'}',
                                                        style: AppTypography
                                                            .titleMedium
                                                            .copyWith(
                                                                color: context
                                                                    .palette
                                                                    .textPrimary)),
                                                    if (store['address'] !=
                                                        null)
                                                      Text(
                                                          '${store['address']}',
                                                          style: AppTypography
                                                              .body
                                                              .copyWith(
                                                                  color: context
                                                                      .palette
                                                                      .textSecondary)),
                                                  ])),
                                            ]))),
                                ],
                              ])),
      ]),
    ));
  }
}
