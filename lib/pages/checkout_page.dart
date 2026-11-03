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
import '../ui/frosted_dock.dart';
import '../ui/product_card.dart';
import '../design/motion.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../features/cart/ui/cart_page.dart' as feature_cart;
import '../features/checkout/checkout_contract.dart';
import '../features/orders/ui/orders_page.dart';
import '../services/onboarding_service.dart';
import '../services/store_city.dart';
import '../ui/app_icon.dart';
import '../ui/app_icon_button.dart';
import '../ui/app_states.dart';
import '../ui/app_top_bar.dart';
import '../ui/surfaces.dart';
import '../ui/text_width_cache.dart';
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

/// Opens the delivery-address picker. [city] is the selected store's city
/// (addresses must be searched, reverse-geocoded and validated there) and
/// [fallbackCenter] the store's coordinates, used when there is no usable
/// initial address.
typedef CheckoutAddressPicker = Future<Map<String, dynamic>?> Function(
  BuildContext context,
  Map<String, dynamic>? address,
  bool detailsFirst, {
  String? city,
  ({double lat, double lon})? fallbackCenter,
});

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
  final CheckoutAddressPicker? addressPicker;
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
  final _comment = TextEditingController();
  final _promo = TextEditingController();
  final _certificate = TextEditingController();
  double _footerHeight = 110;
  bool _deliveryDetailsExpanded = true;
  CartProvider? _cart;
  BusinessProvider? _business;
  Map<String, dynamic>? _address;
  CheckoutQuote? _quote;
  Map<String, dynamic>? _promoData;
  Map<String, dynamic>? _certificateData;
  String _mode = 'DELIVERY';
  String? _storeCity;
  Map<String, dynamic>? _storeCityBusiness;
  int _storeCityRequest = 0;
  Future<void>? _storeCityLoad;
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
  bool get _addressCityMismatch =>
      _delivery && addressMatchesCity(_address, _storeCity) == false;
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
      !_addressCityMismatch &&
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
      _comment,
      _floor,
      _apartment,
      _promo,
      _certificate
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Resolves the selected store's city (the delivery address must be in it).
  Future<void> _refreshStoreCity() {
    if (!mounted) return Future.value();
    final business = _business?.selectedBusiness;
    if (identical(business, _storeCityBusiness)) {
      return _storeCityLoad ?? Future.value();
    }
    _storeCityBusiness = business;
    _storeCity = null;
    return _storeCityLoad = _loadStoreCity(business, ++_storeCityRequest);
  }

  Future<void> _loadStoreCity(
      Map<String, dynamic>? business, int request) async {
    String? city;
    try {
      city = await storeCityName(business)
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
    } catch (_) {
      city = null;
    }
    if (!mounted || request != _storeCityRequest) return;
    final wasBlocked = _addressCityMismatch;
    setState(() => _storeCity = city);
    if (wasBlocked != _addressCityMismatch) _calculateDelivery();
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
            'rows': group.rows.map((item) => item.toJson()).toList(),
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
    if (!identical(_storeCityBusiness, _business?.selectedBusiness)) {
      _refreshStoreCity();
    }
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
      await _refreshStoreCity();
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
    _comment.text = address['comment']?.toString() ?? '';
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
      if (_comment.text.trim().isNotEmpty || _address!.containsKey('comment'))
        'comment': _comment.text.trim(),
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
      final business = _business?.selectedBusiness;
      final city = _storeCity ??
          await storeCityName(business)
              .timeout(const Duration(seconds: 4), onTimeout: () => null);
      if (!mounted) return;
      final center = storeCoordinates(business);
      // An address from another city is never offered as the starting point:
      // the picker opens on the store's city instead.
      final wrongCity = addressMatchesCity(_address, city) == false;
      final current = wrongCity ? null : (_normalizedAddress() ?? _address);
      // Entrance, floor, flat and comment are edited inline on this page, so
      // changing the address goes straight to choosing a new one on the map —
      // never through the separate details page.
      const detailsFirst = false;
      final selected = widget.addressPicker != null
          ? await widget.addressPicker!(context, current, detailsFirst,
              city: city, fallbackCenter: center)
          : await AddressSelectionModalHelper.show(context,
              initialAddress: current,
              openDetailsFirst: detailsFirst,
              collectDetails: false,
              city: city,
              fallbackCenter: center);
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
    if (!_delivery ||
        !_hasItems ||
        address == null ||
        businessId == null ||
        _addressCityMismatch) {
      if (mounted) {
        setState(() {
          _quote = null;
          _quoting = false;
          if (_addressCityMismatch) _quoteError = null;
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
    // The page reads the cart only through revision-tracked views and the business only
    // through the selected store, so those are the only changes that rebuild it.
    context.select<CartProvider, int>((cart) => cart.contentRevision);
    context.select<BusinessProvider, Map<String, dynamic>?>(
      (business) => business.selectedBusiness,
    );
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
                child: FrostedDock(
                  onDockHeightChanged: (height) {
                    if ((height - _footerHeight).abs() > 0.5) {
                      setState(() => _footerHeight = height);
                    }
                  },
                  content: Column(
                    children: [
                      if (MediaQuery.viewInsetsOf(context).bottom == 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _header(),
                        ),
                      Expanded(child: _checkoutContent()),
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
        title: 'Оформление',
        onBack: _back,
        backEnabled: !_busy,
        trailing: AppIconButton(
          key: const ValueKey('checkout-faq'),
          asset: AppIcons.faq,
          tooltip: 'Вопросы об оформлении',
          onTap: _editingLocked ? null : () => _openHelp(FaqSection.delivery),
        ),
      );

  double get _footerReserve => _hasItems
      ? _footerHeight + AppSpacing.xl + MediaQuery.paddingOf(context).bottom
      : 0;

  Widget _checkoutContent() => ListView(
        key: const ValueKey('checkout-scroll'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(16, 16, 16, _footerReserve + 20),
        children: [
          if (MediaQuery.viewInsetsOf(context).bottom > 0) _header(),
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
            _benefits(),
            const SizedBox(height: 24),
            _orderSummary(),
            const SizedBox(height: 24),
            _summary(),
            if (MediaQuery.viewInsetsOf(context).bottom > 0 &&
                _submissionStatus != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _submissionStatus!,
                  key: const ValueKey('checkout-readiness'),
                  style: AppTypography.caption,
                ),
              ),
            if (_submitError != null && !_creationUncertain) ...[
              const SizedBox(height: 16),
              _submissionMessage(),
            ],
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

  Widget _fulfillment() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _modeSwitch(),
          const SizedBox(height: 16),
          _storeCard(),
          if (_delivery) ...[
            const SizedBox(height: 12),
            _addressCard(),
          ],
        ],
      );

  // ---- Fulfilment: mode, store, address ------------------------------------

  bool get _largeText => MediaQuery.textScalerOf(context).scale(14) > 14 * 1.3;

  Widget _modeSwitch() => AppSurface(
        radius: 36,
        padding: const EdgeInsets.all(4),
        child: LayoutBuilder(builder: (context, constraints) {
          final stacked = constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(14) > 14 * 1.2;
          final delivery = _modeSegment(
              'Доставка', 'DELIVERY', Icons.local_shipping_outlined,
              paintFill: stacked);
          final pickup = _modeSegment(
              'Самовывоз', 'PICKUP', Icons.storefront_outlined,
              paintFill: stacked);
          if (stacked) {
            return Column(children: [
              SizedBox(width: constraints.maxWidth, child: delivery),
              const SizedBox(height: 4),
              SizedBox(width: constraints.maxWidth, child: pickup),
            ]);
          }
          final palette = context.palette;
          // Side by side, one accent thumb slides between the two segments.
          return Stack(children: [
            Positioned.fill(
              child: AnimatedAlign(
                alignment: _mode == 'PICKUP'
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                duration: AppMotion.of(context, AppMotion.slide),
                curve: AppMotion.out,
                child: SizedBox(
                  width: (constraints.maxWidth - 4) / 2,
                  height: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.accent,
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                ),
              ),
            ),
            Row(children: [
              Expanded(child: delivery),
              const SizedBox(width: 4),
              Expanded(child: pickup),
            ]),
          ]);
        }),
      );

  /// With [paintFill] the segment draws its own selected fill; otherwise a thumb behind
  /// the segments does.
  Widget _modeSegment(String label, String mode, IconData icon,
      {required bool paintFill}) {
    final palette = context.palette;
    final selected = _mode == mode;
    final foreground = selected ? palette.textOnAccent : palette.textSecondary;
    final shown =
        _editingLocked ? foreground.withValues(alpha: .6) : foreground;
    return Semantics(
      selected: selected,
      child: AnimatedContainer(
        duration: AppMotion.of(context, AppMotion.state),
        curve: AppMotion.out,
        decoration: BoxDecoration(
          color: paintFill && selected ? palette.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(32),
        ),
        child: TextButton(
          key: ValueKey('checkout-mode-${mode.toLowerCase()}'),
          onPressed: _editingLocked ? null : () => _changeMode(mode),
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 48),
            foregroundColor: foreground,
            disabledForegroundColor: foreground.withValues(alpha: .6),
            shape: const StadiumBorder(),
            textStyle: AppTypography.bodyMedium,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          ),
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: shown),
            duration: AppMotion.of(context, AppMotion.state),
            curve: AppMotion.out,
            builder: (context, color, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) => AppSurface(
        radius: AppRadii.xxl,
        clip: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );

  Widget _hairline() =>
      Divider(height: 1, thickness: 1, color: context.palette.divider);

  Widget _glyphTile(Widget glyph) => Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.palette.accentFaint,
          borderRadius: BorderRadius.circular(14),
        ),
        child: glyph,
      );

  Widget _headerLine(String text, {bool strong = false}) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          text,
          style:
              (strong ? AppTypography.bodySmallMedium : AppTypography.bodySmall)
                  .copyWith(
                      color: strong
                          ? context.palette.textPrimary
                          : context.palette.textSecondary),
        ),
      );

  /// Tappable heading of a fulfilment card: glyph, title, supporting lines and
  /// a visual "change" pill (the whole heading is the hit target).
  Widget _cardHeader({
    required Key key,
    required Widget glyph,
    required String title,
    required List<Widget> body,
    required String actionLabel,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    final palette = context.palette;
    final pill = Opacity(
      opacity: onTap == null ? .5 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: palette.background, borderRadius: AppRadii.pillAll),
        child: Text(actionLabel,
            style: AppTypography.labelSemibold
                .copyWith(color: palette.textPrimary)),
      ),
    );
    return Tooltip(
      message: tooltip,
      child: AppSurface(
        key: key,
        onTap: onTap,
        fill: Colors.transparent,
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(builder: (context, constraints) {
          final inline = constraints.maxWidth >= 260 && !_largeText;
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style:
                      AppTypography.title.copyWith(color: palette.textPrimary)),
              ...body,
              if (!inline) ...[
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: pill),
              ],
            ],
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              glyph,
              const SizedBox(width: 12),
              Expanded(child: text),
              if (inline) ...[
                const SizedBox(width: 12),
                pill,
              ],
            ],
          );
        }),
      ),
    );
  }

  Widget _storeCard() {
    final palette = context.palette;
    final resolved = _businessId != null;
    final address = _business?.selectedBusiness?['address']?.toString().trim();
    return _card([
      _cardHeader(
        key: const ValueKey('checkout-store'),
        glyph: _glyphTile(
            AppIcon(AppIcons.shopGlyph, size: 24, color: palette.accent)),
        title: !resolved
            ? 'Выберите магазин'
            : _business?.selectedBusinessName ?? 'Магазин №$_businessId',
        body: [
          _headerLine(!resolved
              ? 'Магазин сохранённой корзины не определён'
              : (address == null || address.isEmpty)
                  ? 'Магазин для заказа'
                  : address),
        ],
        actionLabel: resolved ? 'Изменить' : 'Выбрать',
        tooltip: resolved ? 'Изменить магазин' : 'Выбрать магазин',
        onTap: _editingLocked ? null : _selectStore,
      ),
      if (_switchingStore) const LinearProgressIndicator(),
      if (_cart?.hasUnresolvedBusiness == true)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _statusRow(
            'Магазин старой корзины неизвестен. Товары сохранены: их можно уменьшить или удалить в корзине. Выбор магазина требует отдельного согласия на удаление.',
            tone: _StatusTone.attention,
            action: _statusAction(
                'Открыть корзину', _editingLocked ? null : () => _openCart()),
          ),
        ),
    ]);
  }

  Widget _addressCard() {
    final palette = context.palette;
    final hasAddress = _address != null;
    final city = _storeCity;
    final details = [
      if (_entrance.text.trim().isNotEmpty) 'Подъезд ${_entrance.text.trim()}',
      if (_floor.text.trim().isNotEmpty) 'Этаж ${_floor.text.trim()}',
      if (_apartment.text.trim().isNotEmpty) 'Кв. ${_apartment.text.trim()}',
    ].join(' · ');
    final addressCity = hasAddress && _addressCityMismatch
        ? (ApiService.extractCityName(_address) ?? city)
        : city;
    final statusRows = <Widget>[
      if (_addressCityMismatch)
        _statusRow(
          'Адрес в другом городе — магазин доставляет по г. $city.',
          key: const ValueKey('checkout-address-city-mismatch'),
          tone: _StatusTone.attention,
          icon: Icons.wrong_location_outlined,
          action: _statusAction(
            'Выбрать адрес в г. $city',
            _editingLocked ? null : _pickAddress,
            key: const ValueKey('checkout-address-city-action'),
          ),
        ),
      if (_addressError != null)
        _statusRow(
          _addressError!,
          key: const ValueKey('checkout-address-error'),
          tone: _StatusTone.error,
          action: _statusAction(
            _normalizedAddress() == null
                ? 'Выбрать на карте'
                : 'Повторить сохранение',
            _editingLocked
                ? null
                : (_normalizedAddress() == null ? _pickAddress : _saveAddress),
            key: const ValueKey('checkout-save-address'),
          ),
        ),
      if (hasAddress && _normalizedAddress() == null && _addressError == null)
        _statusRow(
          'У адреса нет точных координат. Выберите его на карте.',
          tone: _StatusTone.attention,
          action: _statusAction(
              'Выбрать адрес', _editingLocked ? null : _pickAddress),
        ),
    ];
    return _card([
      _cardHeader(
        key: const ValueKey('checkout-address'),
        glyph: _glyphTile(
            AppIcon(AppIcons.location, size: 20, color: palette.accent)),
        // Stored labels may carry the «• Под. 2, Эт. 7, Кв. 45» summary; the
        // details have their own fields below, so the heading is the street.
        title: !hasAddress
            ? 'Выберите адрес доставки'
            : (ApiService.extractAddressLabel(_address!) ??
                    ApiService.formatAddressSummary(_address))
                .split(' • ')
                .first,
        body: [
          _headerLine(
            !hasAddress
                ? (city == null
                    ? 'Нужен перед подтверждением заказа'
                    : 'Нужен перед подтверждением заказа. Доставка по г. $city')
                : addressCity == null
                    ? 'Доставка по этому адресу'
                    : 'г. $addressCity',
          ),
        ],
        actionLabel: hasAddress ? 'Изменить' : 'Выбрать',
        tooltip: hasAddress ? 'Изменить адрес' : 'Выбрать адрес',
        onTap: _editingLocked ? null : _pickAddress,
      ),
      if (_pickingAddress) const LinearProgressIndicator(),
      if (statusRows.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, row) in statusRows.indexed) ...[
                if (index > 0) const SizedBox(height: 8),
                row,
              ],
            ],
          ),
        ),
      _hairline(),
      _deliveryDetails(details),
      _hairline(),
      _deliveryCostBlock(),
    ]);
  }

  Widget _deliveryDetails(String details) {
    final palette = context.palette;
    return ExpansionTile(
      key: const ValueKey('checkout-delivery-details'),
      maintainState: true,
      initiallyExpanded: _deliveryDetailsExpanded,
      minTileHeight: 56,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: palette.textSecondary,
      collapsedIconColor: palette.textSecondary,
      title: Text(
        'Детали доставки',
        key: const ValueKey('checkout-delivery-details-toggle'),
        style:
            AppTypography.bodySmallMedium.copyWith(color: palette.textPrimary),
      ),
      subtitle: _deliveryDetailsExpanded
          ? null
          : Text(
              details.isEmpty
                  ? 'Подъезд, этаж, квартира и комментарий · необязательно'
                  : _comment.text.trim().isEmpty
                      ? details
                      : '$details · есть комментарий',
              style:
                  AppTypography.caption.copyWith(color: palette.textSecondary),
            ),
      onExpansionChanged: (expanded) {
        setState(() => _deliveryDetailsExpanded = expanded);
        if (!expanded) FocusManager.instance.primaryFocus?.unfocus();
      },
      children: [
        LayoutBuilder(builder: (context, constraints) {
          final fields = [
            _addressField('Подъезд', _entrance, 'checkout-entrance'),
            _addressField('Этаж', _floor, 'checkout-floor'),
            _addressField('Квартира', _apartment, 'checkout-apartment'),
          ];
          return constraints.maxWidth < 240 || _largeText
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, field) in fields.indexed) ...[
                      if (index > 0) const SizedBox(height: 12),
                      field,
                    ],
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (index, field) in fields.indexed) ...[
                      if (index > 0) const SizedBox(width: 12),
                      Expanded(child: field),
                    ],
                  ],
                );
        }),
        const SizedBox(height: 12),
        _addressField(
          'Комментарий курьеру',
          _comment,
          'checkout-comment',
          hint: 'Например: домофон не работает, позвоните',
          multiline: true,
        ),
      ],
    );
  }

  Widget _deliveryCostBlock() {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.local_shipping_outlined,
                  size: 20, color: palette.accent),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryRow(
                  'Стоимость доставки',
                  _quoting
                      ? 'Рассчитываем…'
                      : _quote == null
                          ? 'Не рассчитана'
                          : _money(_deliveryCost),
                ),
              ),
            ],
          ),
          if (_quoting) ...[
            const SizedBox(height: 8),
            _statusRow('Рассчитываем доставку…', progress: true),
          ],
          if (_quoteError != null) ...[
            const SizedBox(height: 8),
            _statusRow(
              _quoteError!,
              key: const ValueKey('checkout-quote-error'),
              tone: _StatusTone.error,
              action: _statusAction(
                'Рассчитать ещё раз',
                _editingLocked ? null : _calculateDelivery,
                key: const ValueKey('checkout-quote-retry'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusRow(
    String text, {
    Key? key,
    _StatusTone tone = _StatusTone.info,
    IconData? icon,
    Widget? action,
    bool progress = false,
  }) {
    final palette = context.palette;
    final tint = tone == _StatusTone.error ? palette.error : palette.accent;
    final glyph = icon ??
        switch (tone) {
          _StatusTone.info => Icons.info_outline,
          _StatusTone.attention => Icons.error_outline,
          _StatusTone.error => Icons.error_outline,
        };
    return Container(
      key: key,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(tint.withValues(alpha: .12), palette.surface),
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(glyph, size: 20, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text,
                    style: AppTypography.bodySmall
                        .copyWith(color: palette.textPrimary)),
                if (progress) ...[
                  const SizedBox(height: 8),
                  const ClipRRect(
                    borderRadius: AppRadii.pillAll,
                    child: LinearProgressIndicator(minHeight: 4),
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: 8),
                  action,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusAction(String label, VoidCallback? onPressed, {Key? key}) {
    final palette = context.palette;
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        key: key,
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: palette.textPrimary,
          backgroundColor: palette.background,
          disabledForegroundColor: palette.textSecondary,
          shape: const StadiumBorder(),
          textStyle: AppTypography.bodySmallSemibold,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _addressField(
    String label,
    TextEditingController controller,
    String key, {
    String? hint,
    bool multiline = false,
  }) {
    final palette = context.palette;
    final enabled = !_editingLocked && _address != null;
    OutlineInputBorder border(Color color, [double width = 0]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: width == 0
              ? BorderSide.none
              : BorderSide(color: color, width: width),
        );
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(label,
                style: AppTypography.labelMedium
                    .copyWith(color: palette.textSecondary)),
          ),
          TextField(
            key: ValueKey(key),
            controller: controller,
            enabled: enabled,
            keyboardType:
                multiline ? TextInputType.multiline : TextInputType.text,
            minLines: multiline ? 2 : 1,
            maxLines: multiline ? 4 : 1,
            textInputAction: multiline || key == 'checkout-apartment'
                ? TextInputAction.done
                : TextInputAction.next,
            onChanged: (_) => setState(() => _addressError = null),
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            scrollPadding: EdgeInsets.only(bottom: _footerReserve + 24),
            style: AppTypography.bodySmall.copyWith(color: palette.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTypography.bodySmall
                  .copyWith(color: palette.textSecondary),
              filled: true,
              fillColor: enabled
                  ? palette.background
                  : palette.background.withValues(alpha: .5),
              border: border(Colors.transparent),
              enabledBorder: border(Colors.transparent),
              disabledBorder: border(Colors.transparent),
              focusedBorder: border(palette.accent, 1.5),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

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
            ? 'На балансе: ${_money(_bonusBalance!)}'
            : _bonusError != null
                ? 'Баланс бонусов не подтверждён'
                : null;
    return Column(
      key: const ValueKey('checkout-benefits'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSurface(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Списать бонусы',
                      key: const ValueKey('checkout-benefits-toggle'),
                      style: AppTypography.bodyMedium,
                    ),
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
                ],
              ),
              if (balance != null)
                Text(balance,
                    style: AppTypography.bodySmallBold
                        .copyWith(color: palette.gold)),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  if (_bonusBalance != null)
                    Text('Можно списать до ${_money(_maxBonusUsed)}',
                        style: AppTypography.caption
                            .copyWith(color: palette.textSecondary)),
                  TextButton(
                    onPressed: _editingLocked
                        ? null
                        : () => _openHelp(FaqSection.bonuses),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: AppTypography.caption,
                    ),
                    child: const Text('Как работают бонусы'),
                  ),
                ],
              ),
              if (applied ||
                  _validating ||
                  _loggedIn == false ||
                  _promo.text.trim().isNotEmpty ||
                  _certificate.text.trim().isNotEmpty)
                Text(
                  summary,
                  key: applied
                      ? const ValueKey('checkout-benefit-applied')
                      : null,
                  style: AppTypography.caption.copyWith(
                      color: applied ? palette.accent : palette.textSecondary),
                ),
              if (_loadingBonus || _validating) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        _codeField('Промокод', _promo, false),
        const SizedBox(height: 16),
        _codeField('Сертификат', _certificate, true),
        const SizedBox(height: 8),
        Text(
          'Бонусы, промокод и сертификат применяются по отдельности.',
          style: AppTypography.caption.copyWith(color: palette.textSecondary),
        ),
        if (applied)
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
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Убрать льготу'),
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

  Widget _orderSummary() => AppSurface(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ваш заказ', style: AppTypography.titleMedium),
                      Text('${_groups.length} позиций',
                          style: AppTypography.caption
                              .copyWith(color: context.palette.textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('checkout-edit-cart'),
                  tooltip: 'Изменить корзину',
                  onPressed: _editingLocked ? null : () => _openCart(),
                  style: IconButton.styleFrom(
                      minimumSize: const Size.square(44),
                      foregroundColor: context.palette.accent),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final group in _groups) ...[
              _item(group),
              if (group.freeQuantity > 0) _gift(group),
              const Divider(height: 16),
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
              _summaryRow('Фирменный пакет-майка · 1 шт.', _money(_bag!.price))
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
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  child: const Text('Обновить упаковку'),
                ),
              ),
            ],
          ],
        ),
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
    final view = snapshot == null ? null : ProductView.fromItem(snapshot);
    final unit = quantityUnitLabel(snapshot?.unit) ?? '';
    final normalizedUnit = unit.toLowerCase().replaceAll('.', '');
    final perPiece = const ['', 'шт', 'pcs', 'piece'].contains(normalizedUnit);
    final secondary = {
      if (view?.type ?? view?.category case final category?) category,
      if (view?.country case final country?) country,
    }.join(' · ');
    final parameters = group.baseVariants
        .map((variant) => variant['item_name']?.toString() ?? '')
        .where((label) => label.trim().isNotEmpty)
        .join(', ');
    final bottles = group.bottleBreakdownLabel;
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: [name.name, ...name.attributes].join(' · '),
          child: ExcludeSemantics(
            child: Text(name.name,
                style: AppTypography.bodyMedium
                    .copyWith(color: context.palette.textPrimary)),
          ),
        ),
        if (secondary.isNotEmpty)
          Text(secondary,
              style: AppTypography.caption
                  .copyWith(color: context.palette.textSecondary)),
        if (!perPiece && view != null)
          Text(view.unitPriceLabel,
              style: AppTypography.caption
                  .copyWith(color: context.palette.textSecondary)),
        if (group.totalPrice < group.subtotalBeforePromotions - 0.001)
          Text(_money(group.subtotalBeforePromotions),
              style: AppTypography.caption.copyWith(
                  color: context.palette.textSecondary,
                  decoration: TextDecoration.lineThrough)),
        Text(_money(group.totalPrice),
            style:
                AppTypography.bodyBold.copyWith(color: context.palette.accent)),
      ],
    );
    return Padding(
      key: ValueKey('checkout-item-${group.key}'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(builder: (context, constraints) {
        final controlWidth = math.min(
          constraints.maxWidth,
          math.max(
            108.0,
            TextWidthCache.of(
                  formatQuantity(group.totalQuantity, perPiece ? '' : unit),
                  AppTypography.bodyMedium,
                  MediaQuery.textScalerOf(context),
                  Directionality.of(context),
                ) +
                100,
          ),
        );
        final quantity = SizedBox(
          width: controlWidth,
          child: ProductQuantityControl(
            key: ValueKey('checkout-quantity-${group.key}'),
            quantity: group.totalQuantity,
            unit: perPiece ? null : unit,
            onIncrement: _editingLocked || !group.canIncrease
                ? null
                : () => _cart!.incrementDisplayGroup(group),
            onDecrement: _editingLocked
                ? null
                : () => _cart!.decrementDisplayGroup(group),
          ),
        );
        final remove = IconButton(
          key: ValueKey('checkout-remove-${group.key}'),
          tooltip: 'Удалить',
          onPressed:
              _editingLocked ? null : () => _cart!.removeDisplayGroup(group),
          style: IconButton.styleFrom(
            minimumSize: const Size.square(44),
            foregroundColor: context.palette.textSecondary,
          ),
          icon: const Icon(Icons.delete_outline, size: 20),
        );
        final compact = constraints.maxWidth - controlWidth - 106 >= 72 &&
            MediaQuery.textScalerOf(context).scale(14) <= 17;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _itemImage(snapshot?.image ?? group.image),
                const SizedBox(width: 10),
                Expanded(child: identity),
                if (compact) ...[
                  const SizedBox(width: 8),
                  quantity,
                  remove,
                ],
              ],
            ),
            if (!compact)
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [quantity, remove],
              ),
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
          ],
        );
      }),
    );
  }

  Widget _containerCosts(CartDisplayGroup group) {
    final selection = group.selection;
    if (selection == null || !selection.usesPourFlow) {
      return const SizedBox.shrink();
    }
    var containerCost = 0.0;
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
        final count = formatQuantity(row.physicalQuantity / capacity, 'шт.');
        final replaced =
            variant['price_type']?.toString().toUpperCase() == 'REPLACE';
        if (!replaced) containerCost += price * row.physicalQuantity / capacity;
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
        if (containerCost > 0) _summaryRow('Тара', _money(containerCost)),
        if (containerCost > 0)
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
                  cacheWidth:
                      (44 * MediaQuery.devicePixelRatioOf(context)).ceil(),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.redeem_outlined, color: context.palette.accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${formatQuantity(group.freeQuantity, unit)} в подарок · ${_money(0)}',
              style: AppTypography.bodySmallMedium
                  .copyWith(color: context.palette.accent),
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

  /// Why the order cannot be placed yet; null when it can.
  String? get _submissionStatus {
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
    if (_delivery && _addressCityMismatch) {
      return 'Выберите адрес в г. $_storeCity';
    }
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
    return null;
  }

  // The dock supplies the 16px sides and the safe-area inset below.
  Widget _bottomBar() => Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
        child: LayoutBuilder(builder: (context, constraints) {
          final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
          final label = _money(_total);
          final stacked = constraints.maxWidth < 296 ||
              MediaQuery.textScalerOf(context).scale(16) > 20 ||
              TextWidthCache.of(
                    label,
                    AppTypography.headline,
                    MediaQuery.textScalerOf(context),
                    Directionality.of(context),
                  ) >
                  constraints.maxWidth - 176;
          final amount = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _quoteReady && !_loadingBag && _bag != null
                    ? 'Итого'
                    : 'Предварительно',
                style: AppTypography.caption
                    .copyWith(color: context.palette.textPrimary),
              ),
              Text(label,
                  key: const ValueKey('checkout-total'),
                  style: AppTypography.headline
                      .copyWith(color: context.palette.textPrimary)),
            ],
          );
          final action = FilledButton(
            key: const ValueKey('checkout-submit'),
            onPressed: _canSubmit ? _submitOrder : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(164, 49),
              shape: const StadiumBorder(),
              textStyle: AppTypography.bodyMedium,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            child: Text(
              _submitting ? 'Создаём заказ…' : 'Оформить заказ',
              textAlign: TextAlign.center,
            ),
          );
          if (keyboard) return action;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (stacked) ...[
                amount,
                const SizedBox(height: 8),
                action,
              ] else
                Row(
                  children: [
                    Expanded(child: amount),
                    const SizedBox(width: 12),
                    action,
                  ],
                ),
              if (_submissionStatus case final status?) ...[
                const SizedBox(height: 6),
                Text(
                  status,
                  key: const ValueKey('checkout-readiness'),
                  style: AppTypography.caption
                      .copyWith(color: context.palette.textPrimary),
                ),
              ],
            ],
          );
        }),
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
  List<OnboardingCity> _cities = [];
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
        _cities = cities;
        _stores = stores;
        if (stores == null) _error = 'Не удалось загрузить магазины';
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось загрузить магазины');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _city(Map<String, dynamic> store) => storeCityIn(store, _cities);

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

/// Emphasis of an inline status row inside the fulfilment cards.
enum _StatusTone { info, attention, error }
