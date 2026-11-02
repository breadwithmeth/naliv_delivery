import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/money.dart';
import '../core/json_payload.dart';
import '../core/product_view.dart';
import '../model/category_items.dart';
import '../core/quantity.dart';
import '../services/auth_service.dart';
import '../ui/liquid_glass_dock.dart';
import '../ui/product_card.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
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
import '../utils/financial_operation_journal.dart';
import '../utils/item_name_presentation.dart';
import '../utils/order_payment_guard.dart';
import '../utils/smart_cart.dart';
import '../utils/order_ui_helpers.dart';
import '../widgets/address_selection_modal_material.dart';
import '../features/faq/models/faq.dart';
import '../features/faq/faq_navigation.dart';
import 'login_page.dart';
import 'help_chat_page.dart';
import 'payment_method_page.dart';
import 'profile_setup_page.dart';

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

class _CheckoutPageState extends State<CheckoutPage>
    with WidgetsBindingObserver {
  // Verified public catalogue master code; store-local IDs/prices are read live.
  static const _brandedBagCode = 'KR-00002264';

  final _entrance = TextEditingController();
  final _floor = TextEditingController();
  final _apartment = TextEditingController();
  final _promo = TextEditingController();
  final _certificate = TextEditingController();
  double _footerHeight = 180;
  bool _deliveryDetailsExpanded = false;
  bool _benefitsExpanded = false;
  CartProvider? _cart;
  BusinessProvider? _business;
  Map<String, dynamic>? _address;
  CheckoutQuote? _quote;
  Map<String, dynamic>? _promoData;
  Map<String, dynamic>? _certificateData;
  String _mode = 'DELIVERY';
  int _cartSnapshot = -1;
  int? _storeSnapshot;
  int _revision = 0;
  int _quoteRequest = 0;
  int _benefitRequest = 0;
  int _bonusRequest = 0;
  int _bagRequest = 0;
  CategoryItem? _bag;
  CategoryItem? _bagCatalogue;
  int? _bagStore;
  String? _benefitSnapshot;
  FinancialOperationJournal? _creationJournal;
  int _credentialRevision = AuthService.credentialRevision;
  bool _creationStorageUnavailable = false;
  Map<String, dynamic>? _recoveredOrder;
  String? _creationIdentity;
  double? _creationAmount;
  int? _bagLoadingStore;
  CartEvaluation? _operationEvaluation;
  bool _cartRestoreFailed = false;

  T _withPricing<T>(T Function() compute) {
    final previous = _operationEvaluation;
    _operationEvaluation = _cart!.evaluate();
    try {
      return compute();
    } finally {
      _operationEvaluation = previous;
    }
  }

  bool _loadingBag = false;
  String? _bagError;
  Future<void>? _refreshingSession;
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
  int? get _businessId =>
      _hasItems ? _cart?.businessId : _business?.selectedBusinessId;
  List<CartDisplayGroup> get _groups => _cart!.activeDisplayGroups;
  bool get _hasItems => _cart?.hasActiveItems == true;
  bool get _busy =>
      _initializing || _submitting || _switchingStore || _pickingAddress;
  bool get _editingLocked =>
      _busy || _creationUncertain || _created || _cartRestoreFailed;
  bool get _quoteReady => !_delivery || (!_quoting && _quote != null);
  bool get _canSubmit =>
      _loggedIn == true &&
      _hasItems &&
      !_cartRestoreFailed &&
      _businessId != null &&
      _quoteReady &&
      !_loadingBag &&
      _bag != null &&
      (!_useBonus ||
          (!_loadingBonus && _bonusBalance != null && _maxBonusUsed > 0)) &&
      !_initializing &&
      !_busy &&
      !_validating &&
      !_creationUncertain &&
      !_creationStorageUnavailable &&
      !_created &&
      (!_delivery || _normalizedAddress() != null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthService.sessionRevision.addListener(_sessionChanged);
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
    _cart?.saveStatus.removeListener(_cartSaveChanged);
    _business?.removeListener(_dependenciesChanged);
    _cart = cart;
    _business = business;
    _cartRestoreFailed = cart.saveStatus.value == CartSaveStatus.restoreFailed;
    _cartSnapshot = _snapshotCart();
    _storeSnapshot = _businessId;
    cart.addListener(_dependenciesChanged);
    cart.saveStatus.addListener(_cartSaveChanged);
    business.addListener(_dependenciesChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AuthService.sessionRevision.removeListener(_sessionChanged);
    _cart?.removeListener(_dependenciesChanged);
    _cart?.saveStatus.removeListener(_cartSaveChanged);
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

  void _cartSaveChanged() {
    final failed = _cart?.saveStatus.value == CartSaveStatus.restoreFailed;
    if (!mounted || failed == _cartRestoreFailed) return;
    setState(() => _cartRestoreFailed = failed);
  }

  Future<void> _retryCartRestore() async {
    if (_initializing) return;
    setState(() => _initializing = true);
    if (await _cart!.retryLoad()) {
      if (!mounted) return;
      await _initialize();
    } else if (mounted) {
      setState(() => _initializing = false);
    }
  }

  int _snapshotCart() => _cart!.contentRevision;

  String _pricedSnapshot() {
    final evaluation = _operationEvaluation ?? _cart!.evaluate();
    return jsonEncode({
      'store': _businessId,
      'mode': _mode,
      'lines': [
        for (final group in evaluation.activeGroups)
          {
            'rows': group.paidItems.map((item) => item.toJson()).toList(),
            'physical': group.toJsonForOrder(),
            'price': group.price.totalPrice,
            'discount': group.price.discount,
            'options': group.price.optionsTotal,
          },
      ],
      'bag': _bag == null ? null : {'id': _bag!.itemId, 'price': _bag!.price},
      'delivery': _delivery ? _quote?.deliveryPrice : 0,
    });
  }

  void _dependenciesChanged() {
    if (!mounted || _created || _switchingStore) return;
    final nextCart = _snapshotCart();
    final nextStore = _businessId;
    if (nextCart == _cartSnapshot && nextStore == _storeSnapshot) return;
    final storeChanged = nextStore != _storeSnapshot;
    _cartSnapshot = nextCart;
    _storeSnapshot = nextStore;
    setState(_invalidate);
    _calculateDelivery();
    if (storeChanged) {
      _bagCatalogue = null;
      _bagStore = null;
    }
    _loadBag();
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
    _benefitSnapshot = null;
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
      await _cart!.ensureLoaded();
      final storeId = _businessId;
      if (storeId != null && storeId != _business!.selectedBusinessId) {
        final response = await ApiService.getBusinesses(page: 1, limit: 1000);
        final stores = payloadMaps(response?['businesses']);
        final matches = stores.where((store) => _id(store) == storeId);
        if (matches.length != 1 ||
            !await _business!.setSelectedBusiness(matches.single)) {
          throw StateError('Не удалось восстановить магазин корзины');
        }
      }
      if (!mounted) return;
      await _refreshSession(invalidate: false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitError =
          'Не удалось прочитать сохранённую корзину и магазин. Товары не изменены.');
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        ModalRoute.of(context)?.isCurrent == true &&
        !_busy &&
        !_created) {
      _refreshSession();
    }
  }

  void _sessionChanged() {
    final credentialRevision = AuthService.credentialRevision;
    if (!mounted || _created || credentialRevision == _credentialRevision) {
      return;
    }
    _credentialRevision = credentialRevision;
    _bonusRequest++;
    setState(() {
      _loggedIn = false;
      _bonusBalance = null;
      _loadingBonus = false;
      _creationJournal = null;
      _creationIdentity = null;
      _creationAmount = null;
      _recoveredOrder = null;
      _creationUncertain = false;
      _creationStorageUnavailable = false;
      _invalidate();
    });
    _refreshingSession = null;
    _refreshSession();
  }

  Future<void> _refreshSession({bool invalidate = true}) =>
      _refreshingSession ??= _readSession(invalidate: invalidate)
          .whenComplete(() => _refreshingSession = null);

  Future<void> _readSession({required bool invalidate}) async {
    if (!mounted || _created) return;
    if (invalidate) setState(_invalidate);
    final credentialRevision = AuthService.credentialRevision;
    try {
      final session = await AuthService.captureSession();
      final token = session?.token;
      final info = token == null
          ? null
          : await ApiService.getFullInfo(credentialToken: session?.token)
              .timeout(const Duration(seconds: 10));
      if (credentialRevision != AuthService.credentialRevision ||
          (session != null && !session.isCurrent)) {
        return;
      }
      final loggedIn =
          info?['user'] is Map && !ProfileSetupPage.isRequiredFor(info);
      if (info != null) {
        await AuthService.refreshIdentity(verifiedInfo: info);
      } else if (token == null) {
        AuthService.bindAuthenticatedIdentity(null);
      }
      if (session != null && !session.isCurrent) return;
      if (!mounted || (session != null && !session.isCurrent)) return;
      if (loggedIn && session != null) await _restoreCreation(session);
      if (!mounted || (session != null && !session.isCurrent)) return;
      setState(() {
        _loggedIn = loggedIn;
        if (!loggedIn) {
          _bonusRequest++;
          _bonusBalance = null;
          _loadingBonus = false;
          _useBonus = false;
          if (token != null) {
            _submitError =
                'Не удалось подтвердить аккаунт и заполненный профиль. Повторите вход.';
          }
        }
      });
      unawaited(_calculateDelivery());
      unawaited(_loadBag(force: invalidate));
      if (loggedIn) unawaited(_loadBonuses());
    } catch (_) {
      if (mounted && credentialRevision == AuthService.credentialRevision) {
        setState(() {
          _loggedIn = false;
          _bonusBalance = null;
          _useBonus = false;
          _submitError =
              'Не удалось обновить аккаунт. Введённые данные сохранены.';
        });
      }
    }
  }

  Future<bool> _loadBonuses() async {
    final request = ++_bonusRequest;
    setState(() {
      _loadingBonus = true;
      _bonusBalance = null;
      _bonusError = null;
    });
    try {
      final session = await AuthService.captureSession();
      if (session == null) return false;
      final result =
          await ApiService.getUserBonuses(credentialToken: session.token);
      if (!mounted || !session.isCurrent || request != _bonusRequest) {
        return false;
      }
      final data = payloadMap(result?['data']);
      final balance = checkoutAmount(data['totalBonuses']);
      final accepted = result?['success'] == true && balance != null;
      setState(() {
        _bonusBalance = accepted ? balance : null;
        if (!accepted) {
          _bonusError = 'Не удалось загрузить бонусы';
          _useBonus = false;
        }
      });
      return accepted;
    } catch (_) {
      if (mounted && request == _bonusRequest) {
        setState(() {
          _bonusBalance = null;
          _useBonus = false;
          _bonusError = 'Не удалось загрузить бонусы';
        });
      }
      return false;
    } finally {
      if (mounted && request == _bonusRequest) {
        setState(() => _loadingBonus = false);
      }
    }
  }

  Future<void> _loadBag({bool force = false}) async {
    final store = _businessId;
    if (_loadingBag && _bagLoadingStore == store && !force) return;
    final request = ++_bagRequest;
    if (!force &&
        store != null &&
        _bagStore == store &&
        _bagCatalogue != null) {
      _applyBag(_bagCatalogue!);
      return;
    }
    final previous = _bag;
    _bagLoadingStore = store;
    if (!mounted) return;
    setState(() {
      _bag = null;
      _loadingBag = store != null && _hasItems;
      _bagError = null;
    });
    if (store == null || !_hasItems) return;
    try {
      final matches = <CategoryItem>[];
      var page = 1;
      while (true) {
        final response = await ApiService.searchItemsTyped(
          'майка',
          businessId: store,
          page: page,
          limit: 100,
        );
        if (!mounted || request != _bagRequest || store != _businessId) return;
        if (response == null || !response.success) {
          throw StateError('Не удалось прочитать каталог упаковки');
        }
        matches.addAll(response.data.items
            .where((item) => item.code?.trim() == _brandedBagCode));
        if (!response.data.pagination.hasNextPage) break;
        page++;
      }
      if (matches.length != 1) {
        throw StateError(
            'В магазине не определён единственный фирменный пакет');
      }
      final bag = matches.single;
      _bagCatalogue = bag;
      _bagStore = store;
      if (!_bagEligible(bag)) {
        throw StateError('Фирменный пакет недоступен в выбранном магазине');
      }
      if (!mounted || request != _bagRequest) return;
      setState(() {
        _bag = bag;
        if (previous != null &&
            (previous.itemId != bag.itemId || previous.price != bag.price)) {
          _revision++;
          _benefitRequest++;
          _promoData = null;
          _certificateData = null;
          _benefitSnapshot = null;
          _useBonus = false;
          _benefitError =
              'Упаковка или цена изменились. Проверьте сумму и примените льготу заново.';
        }
      });
    } catch (_) {
      if (mounted && request == _bagRequest) {
        setState(() => _bagError =
            'Не удалось подтвердить фирменный пакет-майку в этом магазине. Обновите каталог упаковки.');
      }
    } finally {
      if (mounted && request == _bagRequest) {
        setState(() => _loadingBag = false);
      }
    }
  }

  bool _bagEligible(CategoryItem bag) {
    final alreadySelected = _groups
        .where((group) => group.itemId == bag.itemId)
        .fold<double>(0, (sum, group) => sum + group.totalOrderQuantity);
    return bag.itemId > 0 &&
        bag.price.isFinite &&
        bag.price >= 0 &&
        bag.visible == 1 &&
        bag.amount != null &&
        bag.amount! >= math.max(1, alreadySelected) &&
        !(bag.options ?? const <CategoryItemOption>[])
            .any((option) => option.required);
  }

  void _applyBag(CategoryItem bag) {
    if (!mounted) return;
    final eligible = _bagEligible(bag);
    setState(() {
      _bag = eligible ? bag : null;
      _loadingBag = false;
      _bagError =
          eligible ? null : 'Фирменный пакет недоступен в выбранном магазине';
    });
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
      'address': (_address!['address'] ?? _address!['name'])
                  ?.toString()
                  .trim()
                  .isNotEmpty ==
              true
          ? (_address!['address'] ?? _address!['name']).toString().trim()
          : '${_address!['street'] ?? ''} ${_address!['house'] ?? ''}'.trim(),
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
    if (!_quoteReady ||
        !_hasItems ||
        _businessId == null ||
        _loadingBag ||
        _bag == null) {
      setState(() => _benefitError =
          'Выберите магазин и адрес, дождитесь расчёта доставки');
      return;
    }
    final revision = _revision;
    final input = _withPricing(() => (
          snapshot: _pricedSnapshot(),
          subtotal: _itemsSubtotal,
          items: _orderItems(),
        ));
    final pricedSnapshot = input.snapshot;
    final request = ++_benefitRequest;
    final controller = certificate ? _certificate : _promo;
    setState(() {
      _validating = true;
      _benefitError = null;
    });
    try {
      final result = certificate
          ? await ApiService.validateCertificate(
              code: code, orderSubtotal: input.subtotal)
          : await ApiService.validatePromoCode({
              'promo_code': code,
              'business_id': _businessId,
              'order_subtotal': input.subtotal,
              'delivery_price': _delivery ? _quote!.deliveryPrice : 0,
              'items': input.items
                  .map((item) => {
                        'item_id': item['item_id'],
                        'amount': item['amount'],
                      })
                  .toList(),
            });
      if (!mounted ||
          revision != _revision ||
          request != _benefitRequest ||
          pricedSnapshot != _pricedSnapshot() ||
          controller.text.trim() != code ||
          _useBonus) {
        return;
      }
      final data = payloadMap(result['data']);
      var accepted = result['success'] == true && data.isNotEmpty;
      if (certificate) {
        final actualCertificate = payloadMap(data['certificate']);
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
          _benefitSnapshot = pricedSnapshot;
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
                    'Товары относятся к исходному магазину и не переносятся без пересчёта. Удалить корзину и выбрать другой магазин?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Отмена')),
                  FilledButton(
                      key: const ValueKey('checkout-confirm-store'),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Удалить корзину и сменить')),
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
      final nextId = _id(selected)!;
      final committed = _hasItems
          ? await _cart!.discardForBusiness(nextId)
          : await _cart!.bindBusiness(nextId);
      if (!committed) throw StateError('Корзина не сохранена');
      if (mounted) _goCatalog();
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

  Future<void> _restoreCreation(AuthSession session) async {
    final account = AuthService.currentIdentity;
    if (account == null || !session.isCurrent) return;
    final journal = FinancialOperationJournal(
        account, FinancialOperationKind.orderCreation);
    final stored = await journal.read();
    if (!mounted || !session.isCurrent) return;
    _creationJournal = journal;
    _creationStorageUnavailable = stored.storageUnavailable;
    final intent = stored.intent;
    _creationUncertain = intent != null;
    _creationIdentity = intent?.identity;
    _creationAmount = checkoutAmount(intent?.request['total_amount']);
    _recoveredOrder = intent?.completed != true || intent?.result == null
        ? null
        : checkoutCreatedOrder({'success': true, 'data': intent!.result});
    if (stored.storageUnavailable) {
      _submitError =
          'Не удалось прочитать состояние предыдущего заказа. Новое оформление заблокировано.';
    } else if (intent != null) {
      _submitError =
          'Предыдущее оформление не завершено на устройстве. Проверьте заказ; повторный запрос не будет отправлен.';
    }
  }

  Future<void> _resumeCreation() async {
    final journal = _creationJournal;
    final identity = _creationIdentity;
    if (_busy || identity == null || journal == null) return;
    setState(() => _submitting = true);
    try {
      final session = await AuthService.captureSession();
      if (session == null ||
          !mounted ||
          journal.account != AuthService.currentIdentity) {
        return;
      }
      var order = _recoveredOrder;
      final numericId = int.tryParse(identity);
      if (numericId != null) {
        order = await ApiService.getOrderDetails(numericId,
            credentialToken: session.token);
      }
      if (!mounted || !session.isCurrent) return;
      if (order == null || paymentOrderId(order) != identity) {
        setState(() => _submitError =
            'Сервер пока не подтвердил заказ. Проверьте «Мои заказы» или обратитесь в поддержку. Новый запрос не отправлен.');
        return;
      }
      final stored = await journal.read();
      if (!session.isCurrent ||
          stored.storageUnavailable ||
          stored.intent == null) {
        return;
      }
      if (!await journal.settle(
          outcome: FinancialOperationOutcome.accepted,
          identity: identity,
          result: order,
          completed: true)) {
        return;
      }
      if (!session.isCurrent || !mounted) return;
      final original = stored.intent!.request;
      final unchanged = original['business_id'] == _businessId &&
          jsonEncode(original['items']) == jsonEncode(_orderItems()) &&
          checkoutAmount(original['total_amount']) == _total;
      if (unchanged) {
        _created = true;
        _cart!.clearCart();
        if (!await _cart!.ensureSaved()) return;
      }
      if (!session.isCurrent || !mounted) return;
      await journal.acknowledge();
      if (!session.isCurrent || !mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => PaymentMethodPage(
            orderData: order!, displayAmount: _creationAmount),
      ));
    } finally {
      if (mounted) setState(() => _submitting = false);
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
    FinancialOperationJournal? journal;
    var reserved = false;
    AuthSession? session;
    try {
      session = await AuthService.captureSession();
      if (session == null || AuthService.currentIdentity == null) {
        if (mounted) setState(() => _loggedIn = false);
        return;
      }
      await _restoreCreation(session);
      if (_creationUncertain || _creationStorageUnavailable) return;
      if (!await _cart!.ensureSaved()) {
        if (mounted) {
          setState(() => _submitError =
              'Корзина не сохранена на устройстве. Повторите её сохранение перед оформлением.');
        }
        return;
      }
      await _loadBag(force: true);
      if (_bag == null || _loadingBag || !session.isCurrent) return;
      if ((_promoData != null || _certificateData != null) &&
          _benefitSnapshot != _pricedSnapshot()) {
        if (mounted) {
          setState(() {
            _promoData = null;
            _certificateData = null;
            _benefitSnapshot = null;
            _benefitError =
                'Состав или цены изменились. Примените льготу заново.';
          });
        }
        return;
      }
      if (!mounted ||
          !session.isCurrent ||
          revision != _revision ||
          !_hasItems ||
          !_quoteReady) {
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
      if (!mounted ||
          !session.isCurrent ||
          revision != _revision ||
          !_hasItems ||
          !_quoteReady) {
        return;
      }
      if (_useBonus) {
        final expectedBonus = _bonusUsed;
        final fresh = await _loadBonuses();
        if (!mounted || !session.isCurrent || revision != _revision) return;
        if (!fresh || expectedBonus != _bonusUsed) {
          setState(() {
            _useBonus = false;
            _benefitError = fresh
                ? 'Баланс бонусов изменился. Проверьте сумму и включите списание заново.'
                : 'Списание не подтверждено: обновите баланс бонусов.';
          });
          return;
        }
      }
      final input = _withPricing(() => (
            amount: _total,
            items: _orderItems(),
            bonus: _bonusUsed,
            certificate: _certificateUsed,
          ));
      final amount = input.amount;
      final certificate = payloadMap(_certificateData?['certificate']);
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
        'items': input.items,
        'delivery_type': _mode,
        'delivery_time': 'NOW',
        'total_amount': amount,
        'courier_tips': 0,
        'use_bonuses': _useBonus,
        if (_useBonus) 'bonus_amount': input.bonus,
        if (_promoData != null) 'promo_code': _promoData!['promo_code'],
        if (_certificateData != null && input.certificate > 0) ...{
          if (certificateId != null) 'certificate_id': certificateId,
          if (certificateId == null)
            'certificate_code': certificate['code'] ?? _certificate.text.trim(),
          'certificate_amount': input.certificate,
        },
      };
      journal = _creationJournal!;
      reserved = await journal.reserve(body);
      if (!reserved) {
        await _restoreCreation(session);
        if (mounted && session.isCurrent) {
          setState(() {
            _creationStorageUnavailable = true;
            _submitError =
                'Не удалось сохранить намерение оформить заказ. Новый запрос не отправлен.';
          });
        }
        return;
      }
      if (!session.isCurrent || !mounted || revision != _revision) {
        await journal.acknowledge(requestNotSent: true);
        return;
      }
      mutationStarted = true;
      final result = await ApiService.createUserOrder(body,
          credentialToken: session.token);
      final order = checkoutCreatedOrder(result);
      final rawData = payloadMap(result['data']);
      final identity = paymentOrderId(order ?? rawData);
      var outcome = financialOperationOutcome(result, accepted: order != null);
      if (identity != null && outcome == FinancialOperationOutcome.refused) {
        outcome = FinancialOperationOutcome.unknown;
      }
      final saved = await journal.settle(
        outcome: outcome,
        identity: identity,
        result: order ?? rawData,
        completed: outcome == FinancialOperationOutcome.accepted,
      );
      if (!mounted || !session.isCurrent) return;
      if (order != null &&
          outcome == FinancialOperationOutcome.accepted &&
          saved) {
        _created = true;
        _cart!.clearCart();
        if (await _cart!.ensureSaved()) await journal.acknowledge();
        if (!mounted || !session.isCurrent) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
          builder: (_) => PaymentMethodPage(
            orderData: order,
            displayAmount: amount,
            amountNotice: checkoutAmountNotice(
              clientAmount: amount,
              serverAmount: resolveServerChargedAmount(order),
            ),
            openCardForm: widget.openCardForm,
            onPaymentCompleted: widget.onPaymentCompleted,
          ),
        ));
      } else {
        await _restoreCreation(session);
        if (!mounted || !session.isCurrent) return;
        setState(() {
          _creationUncertain =
              outcome != FinancialOperationOutcome.refused || !saved;
          _submitError = _creationUncertain
              ? 'Статус создания заказа неизвестен. Проверьте «Мои заказы» перед новым оформлением. Корзина сохранена.'
              : _errorMessage(
                  result['error'], 'Заказ не создан. Корзина сохранена.');
        });
      }
    } catch (_) {
      if (mutationStarted) {
        await journal?.settle(outcome: FinancialOperationOutcome.unknown);
      }
      if (mounted && (session == null || session.isCurrent)) {
        setState(() {
          _creationUncertain = mutationStarted;
          _submitError = mutationStarted
              ? 'Статус создания заказа неизвестен. Проверьте «Мои заказы» перед новым оформлением.'
              : 'Не удалось подготовить заказ. Корзина и введённые данные сохранены.';
        });
      }
    } finally {
      if (reserved) journal?.release();
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool get _addBag =>
      _bag != null &&
      _hasItems &&
      !_groups.any((group) => group.itemId == _bag!.itemId);

  List<Map<String, dynamic>> _orderItems() {
    final items = (_operationEvaluation ?? _cart!.evaluate()).toJsonForOrder();
    if (_addBag) {
      items.add({
        'item_id': _bag!.itemId,
        'amount': 1,
        'options': <Map<String, dynamic>>[]
      });
    }
    return items;
  }

  double get _bagCost => _addBag ? _bag!.price : 0;
  double get _cartPrice =>
      (_operationEvaluation ?? _cart!.evaluate()).totalPrice;
  double get _itemsSubtotal => _cartPrice + _bagCost;
  double get _bonusEligibleSubtotal =>
      BonusRules.calculateEligibleSubtotalForEvaluations(
          (_operationEvaluation ?? _cart!.evaluate()).activeGroups);
  int get _maxBonusUsed => BonusRules.calculateRedeemableBonuses(
      balance: _bonusBalance ?? 0, eligibleSubtotal: _bonusEligibleSubtotal);
  double get _bonusUsed => _useBonus ? _maxBonusUsed.toDouble() : 0;
  double? _certificateAvailable(Map<String, dynamic> data) {
    final certificate = payloadMap(data['certificate']);
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

  int get _earnedBonuses => _promoData != null
      ? 0
      : BonusRules.calculateEarnedBonuses(_bonusEligibleSubtotal);

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
        onCheckout: () {
          if (!replace) {
            Navigator.of(cartContext).pop();
            return;
          }
          Navigator.of(cartContext).push(MaterialPageRoute<void>(
            builder: (_) => CheckoutPage(
              addressPicker: widget.addressPicker,
              openCardForm: widget.openCardForm,
              onPaymentCompleted: widget.onPaymentCompleted,
              onCatalog: widget.onCatalog,
            ),
          ));
        },
      ),
    );
    if (replace) {
      navigator.pushReplacement(route);
    } else {
      navigator.push(route).then((_) {
        if (mounted) _refreshSession();
      });
    }
  }

  Future<void> _signIn() async {
    final authenticated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const LoginPage(
          startWithPhoneForm: true,
          completionMode: LoginCompletionMode.returnAuthenticated,
        ),
      ),
    );
    if (!mounted || authenticated != true) return;
    await _refreshSession();
  }

  @override
  Widget build(BuildContext context) =>
      _withPricing(() => _buildCheckout(context));

  Widget _buildCheckout(BuildContext context) {
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
        body: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: LiquidGlassDock(
                  onDockHeightChanged: (height) {
                    if ((height - _footerHeight).abs() > 0.5) {
                      setState(() => _footerHeight = height);
                    }
                  },
                  content: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _header(),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: _footerReserve),
                          child: _checkoutContent(),
                        ),
                      ),
                    ],
                  ),
                  dock: _hasItems && !_cartRestoreFailed ? _bottomBar() : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => AppTopBar(
        title: 'Заказ',
        onBack: _back,
        backEnabled: !_busy,
      );

  double get _footerReserve => _hasItems
      ? _footerHeight + AppSpacing.xl + MediaQuery.paddingOf(context).bottom
      : 0;

  Widget _checkoutContent() => ListView(
        key: const ValueKey('checkout-scroll'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        children: [
          if (!_hasItems && (_creationUncertain || _creationStorageUnavailable))
            _submissionMessage(),
          if (_cartRestoreFailed)
            AppErrorState(
              key: const ValueKey('checkout-cart-restore-error'),
              message: 'Сохранённую корзину не удалось прочитать. '
                  'Она не заменена пустой корзиной; оформление заблокировано.',
              onRetry: _initializing ? null : _retryCartRestore,
            )
          else if (!_hasItems)
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
                'Войдите в аккаунт, чтобы оформить заказ. Введённые данные сохранятся.',
                action: TextButton(
                  key: const ValueKey('checkout-sign-in'),
                  onPressed: _editingLocked ? null : _signIn,
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  child: const Text('Войти'),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (_creationUncertain) ...[
              _submissionMessage(),
              const SizedBox(height: 20),
            ],
            _fulfillment(),
            const SizedBox(height: 24),
            _orderSummary(),
            const SizedBox(height: 24),
            _benefits(),
            const SizedBox(height: 24),
            _summary(),
            if (MediaQuery.viewInsetsOf(context).bottom > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _submissionStatus,
                  key: const ValueKey('checkout-readiness'),
                  style: AppTypography.caption,
                ),
              ),
            if (_submitError != null && !_creationUncertain) ...[
              const SizedBox(height: 16),
              _submissionMessage(),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('checkout-faq'),
                onPressed: _editingLocked
                    ? null
                    : () => _openHelp(FaqSection.delivery),
                style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: context.palette.textSecondary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 12)),
                icon: const Icon(Icons.help_outline, size: 20),
                label: const Text('Помощь с оформлением'),
              ),
            ),
          ],
        ],
      );

  Widget _submissionMessage() => _message(
        _submitError ??
            'Статус создания заказа неизвестен. Проверьте «Мои заказы» перед новым оформлением. Корзина сохранена.',
        key: const ValueKey('checkout-submit-error'),
        action: _creationUncertain
            ? Wrap(children: [
                TextButton(
                  key: const ValueKey('checkout-check-orders'),
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => OrdersPage(
                              businessId: _businessId, onCart: _openCart))),
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  child: const Text('Мои заказы'),
                ),
                if (_creationIdentity != null)
                  TextButton(
                    key: const ValueKey('checkout-resume-order'),
                    onPressed: _busy ? null : _resumeCreation,
                    child: const Text('Проверить созданный заказ'),
                  ),
                TextButton(
                  key: const ValueKey('checkout-creation-support'),
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const HelpChatPage(
                              entryPoint: 'order_creation_unknown'))),
                  child: const Text('Поддержка'),
                ),
              ])
            : null,
      );

  Widget _fulfillment() {
    final palette = context.palette;
    final details = [
      if (_entrance.text.trim().isNotEmpty) 'Подъезд ${_entrance.text.trim()}',
      if (_floor.text.trim().isNotEmpty) 'Этаж ${_floor.text.trim()}',
      if (_apartment.text.trim().isNotEmpty)
        'Квартира ${_apartment.text.trim()}',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Получение заказа', style: AppTypography.titleMedium),
        const SizedBox(height: 12),
        AppSurface(
          radius: 18,
          padding: const EdgeInsets.all(4),
          child: LayoutBuilder(builder: (context, constraints) {
            final stacked = constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(14) > 14 * 1.2;
            return Wrap(runSpacing: 4, children: [
              for (final entry in [
                ('Доставка', 'DELIVERY'),
                ('Самовывоз', 'PICKUP')
              ])
                SizedBox(
                  width:
                      stacked ? constraints.maxWidth : constraints.maxWidth / 2,
                  child: Semantics(
                    selected: _mode == entry.$2,
                    child: TextButton(
                      key: ValueKey('checkout-mode-${entry.$2.toLowerCase()}'),
                      onPressed:
                          _editingLocked ? null : () => _changeMode(entry.$2),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        foregroundColor: _mode == entry.$2
                            ? palette.textOnAccent
                            : palette.textSecondary,
                        backgroundColor: _mode == entry.$2
                            ? palette.accent
                            : Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        textStyle: AppTypography.bodyMedium,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 12),
                      ),
                      child: Text(entry.$1, textAlign: TextAlign.center),
                    ),
                  ),
                ),
            ]);
          }),
        ),
        const SizedBox(height: 12),
        AppSurface(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _selectionTile(
                key: const ValueKey('checkout-store'),
                icon: Icons.storefront_outlined,
                title: _businessId == null
                    ? 'Выберите магазин'
                    : _business?.selectedBusinessName ??
                        'Магазин №$_businessId',
                subtitle: _businessId == null
                    ? 'Магазин сохранённой корзины не определён'
                    : _business?.selectedBusiness?['address']?.toString() ??
                        'Магазин для заказа',
                actionLabel: _businessId == null
                    ? 'Выбрать магазин'
                    : 'Изменить магазин',
                onTap: _editingLocked ? null : _selectStore,
              ),
              if (_switchingStore) const LinearProgressIndicator(),
              if (_cart?.hasUnresolvedBusiness == true)
                _message(
                  'Магазин старой корзины неизвестен. Товары сохранены: их можно уменьшить или удалить в корзине. Выбор магазина требует отдельного согласия на удаление.',
                  action: TextButton(
                    onPressed: _editingLocked ? null : () => _openCart(),
                    style:
                        TextButton.styleFrom(minimumSize: const Size(44, 44)),
                    child: const Text('Открыть корзину'),
                  ),
                ),
              if (_delivery) ...[
                const Divider(height: 16, indent: 14, endIndent: 14),
                _selectionTile(
                  key: const ValueKey('checkout-address'),
                  icon: Icons.location_on_outlined,
                  title: ApiService.formatAddressSummary(_address,
                      emptyText: 'Выберите адрес'),
                  subtitle: _address == null
                      ? 'Нужен перед подтверждением заказа'
                      : 'Доставка сейчас',
                  actionLabel:
                      _address == null ? 'Выбрать адрес' : 'Изменить адрес',
                  onTap: _editingLocked ? null : _pickAddress,
                ),
                if (_pickingAddress) const LinearProgressIndicator(),
                ExpansionTile(
                  key: const ValueKey('checkout-delivery-details'),
                  maintainState: true,
                  initiallyExpanded: _deliveryDetailsExpanded,
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  iconColor: palette.textSecondary,
                  collapsedIconColor: palette.textSecondary,
                  title: Text(
                    'Детали доставки',
                    key: const ValueKey('checkout-delivery-details-toggle'),
                    style: AppTypography.bodyMedium,
                  ),
                  subtitle: Text(
                    details.isEmpty
                        ? 'Подъезд, этаж и квартира · необязательно'
                        : details,
                    style: AppTypography.caption
                        .copyWith(color: palette.textSecondary),
                  ),
                  onExpansionChanged: (expanded) {
                    setState(() => _deliveryDetailsExpanded = expanded);
                    if (!expanded) {
                      FocusManager.instance.primaryFocus?.unfocus();
                    }
                  },
                  children: [
                    _addressField('Подъезд', _entrance, 'checkout-entrance'),
                    const SizedBox(height: 12),
                    _addressField('Этаж', _floor, 'checkout-floor'),
                    const SizedBox(height: 12),
                    _addressField('Квартира', _apartment, 'checkout-apartment'),
                    if (_address?['comment']?.toString().trim().isNotEmpty ==
                        true) ...[
                      const SizedBox(height: 12),
                      Text('Комментарий: ${_address!['comment']}',
                          style: AppTypography.bodySmall),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
        if (_delivery) ...[
          if (_addressError != null) ...[
            const SizedBox(height: 8),
            _message(
              _addressError!,
              key: const ValueKey('checkout-address-error'),
              action: TextButton(
                key: const ValueKey('checkout-save-address'),
                onPressed: _editingLocked
                    ? null
                    : (_normalizedAddress() == null
                        ? _pickAddress
                        : _saveAddress),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                child: Text(_normalizedAddress() == null
                    ? 'Выбрать на карте'
                    : 'Повторить сохранение'),
              ),
            ),
          ],
          if (_quoting)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Рассчитываем доставку…',
                      style: AppTypography.bodySmall
                          .copyWith(color: palette.textSecondary)),
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
              ),
            ),
          if (_quoteError != null) ...[
            const SizedBox(height: 8),
            _message(
              _quoteError!,
              key: const ValueKey('checkout-quote-error'),
              action: TextButton(
                key: const ValueKey('checkout-quote-retry'),
                onPressed: _editingLocked ? null : _calculateDelivery,
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                child: const Text('Рассчитать ещё раз'),
              ),
            ),
          ],
          if (_address != null &&
              _normalizedAddress() == null &&
              _addressError == null)
            _message(
              'У адреса нет точных координат. Выберите его на карте.',
              action: TextButton(
                onPressed: _editingLocked ? null : _pickAddress,
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                child: const Text('Выбрать адрес'),
              ),
            ),
        ],
      ],
    );
  }

  Widget _addressField(
          String label, TextEditingController controller, String key) =>
      TextField(
        key: ValueKey(key),
        controller: controller,
        enabled: !_editingLocked && _address != null,
        keyboardType: TextInputType.text,
        textInputAction: key == 'checkout-apartment'
            ? TextInputAction.done
            : TextInputAction.next,
        onChanged: (_) => setState(() => _addressError = null),
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        scrollPadding: EdgeInsets.only(bottom: _footerReserve + 24),
        style: AppTypography.bodySmall,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: context.palette.surfaceMuted,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
      );

  Widget _benefits() {
    final palette = context.palette;
    final applied = _useBonus || _promoData != null || _certificateData != null;
    final summary = _useBonus
        ? 'Бонусами: −${_money(_bonusUsed)}'
        : _promoData != null
            ? 'Промокод ${_promoData!['promo_code']} применён'
            : _certificateData != null
                ? 'Сертификат применён: −${_money(_certificateUsed)}'
                : _validating
                    ? 'Проверяем код…'
                    : _promo.text.trim().isNotEmpty ||
                            _certificate.text.trim().isNotEmpty
                        ? 'Код сохранён. Примените его для текущего заказа.'
                        : _loggedIn == false
                            ? 'Доступны после входа в аккаунт'
                            : 'Выберите одну льготу для заказа';
    final balance = _loadingBonus
        ? 'Баланс бонусов обновляется…'
        : _bonusBalance != null
            ? 'Баланс подтверждён: ${_money(_bonusBalance!)}'
            : _bonusError != null
                ? 'Баланс бонусов не подтверждён'
                : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSurface(
          child: ExpansionTile(
            key: const ValueKey('checkout-benefits'),
            maintainState: true,
            initiallyExpanded: _benefitsExpanded,
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            shape: const Border(),
            collapsedShape: const Border(),
            iconColor: palette.accent,
            collapsedIconColor: palette.textSecondary,
            title: Text(
              'Бонусы и скидки',
              key: const ValueKey('checkout-benefits-toggle'),
              style: AppTypography.titleMedium,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  summary,
                  key: applied
                      ? const ValueKey('checkout-benefit-applied')
                      : null,
                  style: AppTypography.bodySmall.copyWith(
                      color: applied ? palette.accent : palette.textSecondary),
                ),
                if (balance != null) ...[
                  const SizedBox(height: 4),
                  Text(balance,
                      style: AppTypography.caption
                          .copyWith(color: palette.textSecondary)),
                ],
                if (_loadingBonus || _validating) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
            onExpansionChanged: (expanded) {
              setState(() => _benefitsExpanded = expanded);
              if (!expanded) {
                FocusManager.instance.primaryFocus?.unfocus();
              }
            },
            children: [
              const Divider(height: 20),
              Text(
                'Бонусы, промокод и сертификат применяются по отдельности.',
                style: AppTypography.bodySmall
                    .copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child:
                      Text('Списать бонусы', style: AppTypography.bodyMedium),
                ),
                Switch.adaptive(
                  key: const ValueKey('checkout-bonus-toggle'),
                  value: _useBonus,
                  onChanged: !_editingLocked &&
                          !_loadingBonus &&
                          _loggedIn == true &&
                          _maxBonusUsed > 0
                      ? _toggleBonuses
                      : null,
                ),
              ]),
              if (_bonusBalance != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Можно списать до ${_money(_maxBonusUsed)}',
                      style: AppTypography.caption
                          .copyWith(color: palette.textSecondary)),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _editingLocked
                      ? null
                      : () => _openHelp(FaqSection.bonuses),
                  style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 12)),
                  child: const Text('Как работают бонусы'),
                ),
              ),
              const SizedBox(height: 12),
              _codeField('Промокод', _promo, false),
              const SizedBox(height: 20),
              _codeField('Сертификат', _certificate, true),
              if (applied) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('checkout-clear-benefit'),
                    onPressed: _editingLocked
                        ? null
                        : () => setState(() {
                              _useBonus = false;
                              _promoData = null;
                              _certificateData = null;
                              _benefitRequest++;
                            }),
                    style:
                        TextButton.styleFrom(minimumSize: const Size(44, 44)),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Убрать льготу'),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_bonusError != null) ...[
          const SizedBox(height: 8),
          _message(
            _bonusError!,
            action: TextButton(
              key: const ValueKey('checkout-bonus-retry'),
              onPressed: _editingLocked ? null : _loadBonuses,
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              child: const Text('Обновить бонусы'),
            ),
          ),
        ],
        if (_benefitError != null) ...[
          const SizedBox(height: 8),
          _message(_benefitError!,
              key: const ValueKey('checkout-benefit-error')),
        ],
      ],
    );
  }

  Widget _codeField(
      String label, TextEditingController controller, bool certificate) {
    final name = certificate ? 'certificate' : 'promo';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: AppTypography.bodyMedium
              .copyWith(color: context.palette.textPrimary)),
      const SizedBox(height: 8),
      LayoutBuilder(builder: (context, constraints) {
        final input = TextField(
          key: ValueKey('checkout-$name-code'),
          controller: controller,
          enabled: !_editingLocked && !_useBonus,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          scrollPadding: EdgeInsets.only(bottom: _footerReserve + 24),
          onSubmitted: (_) => _validateCode(certificate: certificate),
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: AppTypography.bodySmall,
          decoration: InputDecoration(
              hintText: certificate ? 'Код сертификата' : 'Введите промокод',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
        );
        final apply = FilledButton(
          key: ValueKey('checkout-apply-$name'),
          onPressed: !_editingLocked && !_validating && !_useBonus
              ? () => _validateCode(certificate: certificate)
              : null,
          style: FilledButton.styleFrom(
              minimumSize: const Size(44, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle: AppTypography.bodySmallMedium),
          child: const Text('Применить'),
        );
        return constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(14) > 20
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                input,
                const SizedBox(height: 8),
                apply,
              ])
            : Row(children: [
                Expanded(child: input),
                const SizedBox(width: 8),
                apply,
              ]);
      }),
    ]);
  }

  Widget _orderSummary() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Состав заказа', style: AppTypography.titleMedium),
          const SizedBox(height: 4),
          Text('${_groups.length} позиций',
              style: AppTypography.caption
                  .copyWith(color: context.palette.textSecondary)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('checkout-edit-cart'),
              onPressed: _editingLocked ? null : () => _openCart(),
              style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 12)),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Изменить корзину'),
            ),
          ),
          const SizedBox(height: 8),
          AppSurface(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final group in _groups) ...[
                  _item(group),
                  if (group.freeQuantity > 0) _gift(group),
                  const Divider(height: 24),
                ],
                Text('Обязательная упаковка', style: AppTypography.bodyMedium),
                const SizedBox(height: 4),
                if (_loadingBag) ...[
                  Text('Проверяем наличие и цену пакета…',
                      style: AppTypography.bodySmall
                          .copyWith(color: context.palette.textSecondary)),
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
                if (_addBag)
                  _summaryRow(
                      'Фирменный пакет-майка · 1 шт.', _money(_bag!.price))
                else if (_bag != null)
                  Text('Фирменный пакет-майка уже в составе корзины.',
                      style: AppTypography.bodySmall
                          .copyWith(color: context.palette.textSecondary)),
                if (_bagError != null) ...[
                  const SizedBox(height: 8),
                  _message(
                    _bagError!,
                    key: const ValueKey('checkout-bag-error'),
                    action: TextButton(
                      key: const ValueKey('checkout-bag-retry'),
                      onPressed:
                          _editingLocked ? null : () => _loadBag(force: true),
                      style:
                          TextButton.styleFrom(minimumSize: const Size(44, 44)),
                      child: const Text('Обновить упаковку'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );

  Widget _item(CartDisplayGroup group) {
    final snapshot = group.itemSnapshot;
    final name = snapshot != null
        ? presentItem(snapshot,
            storedType: group.itemType,
            storedPackagingType: group.packagingType)
        : presentItemName(
            rawName: group.name,
            storedType: group.itemType,
            storedPackagingType: group.packagingType);
    final unit = quantityUnitLabel(snapshot?.unit) ?? '';
    final parameters = group.baseVariants
        .map((variant) => variant['item_name']?.toString() ?? '')
        .where((label) => label.trim().isNotEmpty)
        .join(', ');
    final bottles = group.bottleBreakdownLabel;
    return Padding(
      key: ValueKey('checkout-item-${group.key}'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _itemImage(snapshot?.image ?? group.image),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.name,
                      style: AppTypography.bodyMedium
                          .copyWith(color: context.palette.textPrimary)),
                  if (name.attributes.isNotEmpty)
                    Text(name.attributes.join(' · '),
                        style: AppTypography.caption
                            .copyWith(color: context.palette.textSecondary)),
                  if (snapshot != null)
                    Text(ProductView.fromItem(snapshot).unitPriceLabel,
                        style: AppTypography.caption
                            .copyWith(color: context.palette.textSecondary)),
                ],
              ),
            ),
          ]),
          if (parameters.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(parameters,
                style: AppTypography.bodySmall
                    .copyWith(color: context.palette.textSecondary)),
          ],
          if (bottles != null) ...[
            const SizedBox(height: 8),
            Text('Физическая тара: $bottles',
                style: AppTypography.bodySmall
                    .copyWith(color: context.palette.textSecondary)),
            _containerCosts(group),
          ],
          const SizedBox(height: 10),
          if (group.totalPrice < group.subtotalBeforePromotions - 0.001)
            Text(_money(group.subtotalBeforePromotions),
                style: AppTypography.caption.copyWith(
                    color: context.palette.textSecondary,
                    decoration: TextDecoration.lineThrough)),
          Text(_money(group.totalPrice),
              style: AppTypography.bodyBold
                  .copyWith(color: context.palette.accent)),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, constraints) {
            final quantity = SizedBox(
              width: math.min(constraints.maxWidth, 184),
              child: ProductQuantityControl(
                key: ValueKey('checkout-quantity-${group.key}'),
                quantity: group.totalQuantity,
                unit: unit,
                onIncrement: _editingLocked || !group.canIncrease
                    ? null
                    : () => _cart!.incrementDisplayGroup(group),
                onDecrement: _editingLocked
                    ? null
                    : () => _cart!.decrementDisplayGroup(group),
              ),
            );
            final remove = TextButton.icon(
              key: ValueKey('checkout-remove-${group.key}'),
              onPressed: _editingLocked
                  ? null
                  : () => _cart!.removeDisplayGroup(group),
              style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  foregroundColor: context.palette.textSecondary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 12)),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Удалить'),
            );
            return constraints.maxWidth < 310 ||
                    MediaQuery.textScalerOf(context).scale(14) > 20
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [quantity, const SizedBox(height: 4), remove])
                : Row(children: [
                    Expanded(child: quantity),
                    const SizedBox(width: 12),
                    remove,
                  ]);
          }),
        ],
      ),
    );
  }

  Widget _containerCosts(CartDisplayGroup group) {
    final selection = group.selection;
    if (selection == null || !selection.usesPourFlow) {
      return const SizedBox.shrink();
    }
    var paidCost = 0.0;
    var giftCost = 0.0;
    final tariffs = <Widget>[];
    for (final row in group.physicalItems) {
      for (final selected in row.selectedVariants) {
        if (!selection.isBottleVariant(selected)) continue;
        final variant =
            selected['variant'] is Map ? selected['variant'] as Map : selected;
        final capacity = SmartCartSelection.variantParentItemAmount(selected);
        final price = checkoutAmount(variant['price']);
        if (capacity == null || capacity <= 0 || price == null) continue;
        final label = variant['item_name']?.toString() ?? '';
        final paid = row.quantity / capacity;
        final gift = row.bottledGiftQuantity / capacity;
        final count = formatQuantity(paid + gift, 'шт.');
        final replaced =
            variant['price_type']?.toString().toUpperCase() == 'REPLACE';
        if (!replaced) {
          paidCost += price * paid;
          giftCost += price * gift;
        }
        tariffs.add(Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${label.isEmpty ? selection.volumeLabel(capacity) : label} · $count · '
            '${_money(price)} / шт.'
            '${replaced ? ' (цена с напитком, вместо базовой)' : ''}',
            style: AppTypography.caption
                .copyWith(color: context.palette.textSecondary),
          ),
        ));
      }
    }
    return Column(
      key: ValueKey('checkout-containers-${group.key}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...tariffs,
        if (paidCost > 0)
          _summaryRow('Тара для выбранного объёма', _money(paidCost)),
        if (giftCost > 0)
          _summaryRow('Тара для подарочного объёма', _money(giftCost)),
        if (paidCost > 0 || giftCost > 0)
          Text('Стоимость тары включена в сумму позиции ниже.',
              style: AppTypography.caption
                  .copyWith(color: context.palette.textSecondary)),
      ],
    );
  }

  Widget _itemImage(String? image) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 44,
          height: 50,
          child: image?.isNotEmpty == true
              ? Image.network(image!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(Icons.image_outlined,
                      color: context.palette.textSecondary))
              : Icon(Icons.image_outlined,
                  color: context.palette.textSecondary),
        ),
      );

  Widget _gift(CartDisplayGroup group) {
    final unit = quantityUnitLabel(group.itemSnapshot?.unit) ?? '';
    return Padding(
      key: ValueKey('checkout-gift-${group.key}'),
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.redeem_outlined, color: context.palette.accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatQuantity(group.freeQuantity, unit)} в подарок · ${_money(0)}',
                  style: AppTypography.bodySmallMedium
                      .copyWith(color: context.palette.accent),
                ),
                const SizedBox(height: 4),
                Text(
                  group.selection?.usesPourFlow == true
                      ? 'Напиток — бесплатно. Тара для подарка оплачивается по обычному тарифу и уже включена в сумму позиции.'
                      : 'Подарок по действующей акции товара',
                  style: AppTypography.caption
                      .copyWith(color: context.palette.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary() {
    final bagInCart = _bag == null
        ? 0.0
        : _groups
            .where((group) => group.itemId == _bag!.itemId)
            .fold<double>(0, (sum, group) => sum + group.totalPrice);
    final priceReady = _quoteReady && !_loadingBag && _bag != null;
    final hasContainers =
        _groups.any((group) => group.selection?.usesPourFlow == true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Стоимость заказа', style: AppTypography.titleMedium),
        const SizedBox(height: 12),
        AppSurface(
          key: const ValueKey('checkout-price-breakdown'),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _summaryRow(
                hasContainers ? 'Товары, включая тару' : 'Товары',
                _money(_cartPrice - bagInCart),
              ),
              _summaryRow(
                'Обязательный пакет',
                _bag == null
                    ? (_loadingBag ? 'Уточняем цену…' : 'Цена не подтверждена')
                    : _money(_bagCost + bagInCart),
              ),
              _summaryRow(
                'Доставка',
                !_delivery
                    ? _money(0)
                    : _quote == null
                        ? (_quoting ? 'Рассчитываем…' : 'Не рассчитана')
                        : _money(_deliveryCost),
              ),
              if (_serviceFee > 0)
                _summaryRow('Сервисный сбор', _money(_serviceFee)),
              if (_promoData != null)
                _summaryRow(
                    'Промокод',
                    _promoDiscount > 0
                        ? '−${_money(_promoDiscount)}'
                        : 'Применён')
              else if (_bonusUsed > 0)
                _summaryRow('Бонусы', '−${_money(_bonusUsed)}')
              else if (_certificateData != null)
                _summaryRow('Сертификат', '−${_money(_certificateUsed)}')
              else
                _summaryRow('Бонусы и скидки', 'Не применены'),
              const Divider(height: 24),
              _summaryRow(
                  priceReady ? 'Итого к оплате' : 'Предварительная сумма',
                  _money(_total),
                  emphasized: true),
              if (!priceReady)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Итог уточняется после подтверждения упаковки и доставки.',
                    style: AppTypography.caption
                        .copyWith(color: context.palette.textSecondary),
                  ),
                ),
              const SizedBox(height: 8),
              _summaryRow(
                  'Оценка бонусов за заказ', '+${_money(_earnedBonuses)}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {bool emphasized = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: LayoutBuilder(builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final style =
              emphasized ? AppTypography.title : AppTypography.bodySmall;
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
          required String actionLabel,
          required VoidCallback? onTap}) =>
      AppSurface(
        key: key,
        onTap: onTap,
        fill: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: context.palette.accent),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: AppTypography.bodySmallMedium
                        .copyWith(color: context.palette.textPrimary)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: AppTypography.caption
                        .copyWith(color: context.palette.textSecondary)),
                const SizedBox(height: 8),
                Text(actionLabel,
                    style: AppTypography.bodySmallMedium.copyWith(
                        color: onTap == null
                            ? context.palette.textSecondary
                            : context.palette.accent)),
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

  Future<void> _openHelp(FaqSection section) async {
    await openFaqPage(context, initialSection: section);
    if (mounted) await _refreshSession();
  }

  String get _submissionStatus {
    if (_creationUncertain) return 'Проверьте статус в «Моих заказах»';
    if (_submitting) return 'Не закрывайте экран до ответа магазина';
    if (_initializing) return 'Проверяем данные заказа…';
    if (_loggedIn == null) {
      return _submitError != null
          ? 'Не удалось загрузить данные заказа'
          : 'Проверяем аккаунт…';
    }
    if (_loggedIn != true) return 'Войдите для подтверждения';
    if (_businessId == null) return 'Выберите магазин';
    if (_delivery && _normalizedAddress() == null) {
      return 'Выберите адрес доставки';
    }
    if (_loadingBag) return 'Проверяем обязательную упаковку…';
    if (_bag == null) return 'Обновите упаковку в составе заказа';
    if (_quoting) return 'Рассчитываем доставку…';
    if (!_quoteReady) return 'Повторите расчёт доставки';
    if (_validating) return 'Проверяем код…';
    if (_useBonus && (_loadingBonus || _bonusBalance == null)) {
      return 'Подтверждаем баланс бонусов…';
    }
    if (_pickingAddress || _switchingStore) return 'Сохраняем выбор…';
    if (_submitError != null) return 'Проверьте сообщение об ошибке';
    return 'Далее — выбор оплаты';
  }

  Widget _bottomBar() => Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (MediaQuery.viewInsetsOf(context).bottom == 0) ...[
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                      _quoteReady && !_loadingBag && _bag != null
                          ? 'Итого'
                          : 'Предварительно',
                      style: AppTypography.bodySmall
                          .copyWith(color: context.palette.textPrimary)),
                  Text(_money(_total),
                      key: const ValueKey('checkout-total'),
                      style: AppTypography.headline
                          .copyWith(color: context.palette.textPrimary)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _submissionStatus,
                key: const ValueKey('checkout-readiness'),
                style: AppTypography.caption
                    .copyWith(color: context.palette.textPrimary),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              key: const ValueKey('checkout-submit'),
              onPressed: _canSubmit ? _submitOrder : null,
              style: FilledButton.styleFrom(
                  minimumSize: const Size(44, 48),
                  shape: const StadiumBorder(),
                  textStyle: AppTypography.bodyMedium,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
              child: Text(
                _submitting ? 'Создаём заказ…' : 'Оформить заказ',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );

  static int? _integer(dynamic value) {
    final parsed = value is int ? value : int.tryParse('$value');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  static int? _id(Map<String, dynamic>? business) =>
      BusinessProvider.idOf(business);
  static String _money(num value) => formatTenge(value);
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
          ? payloadMaps(rawStores)
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
