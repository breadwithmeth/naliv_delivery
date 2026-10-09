import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:naliv_delivery/features/cart/ui/cart_page.dart';
import 'package:naliv_delivery/features/bonuses/ui/bonus_history_page.dart';
import 'package:naliv_delivery/features/bonuses/ui/bonus_how_it_works_page.dart';
import 'package:naliv_delivery/features/catalog/ui/supercategory_page.dart';
import 'package:naliv_delivery/core/destinations.dart';
import 'package:naliv_delivery/features/search/ui/search_page.dart';
import 'package:naliv_delivery/features/home/home_data_source.dart';
import 'package:naliv_delivery/features/favorites/ui/favorites_page.dart';
import 'package:naliv_delivery/features/home/home_screen.dart';
import 'package:naliv_delivery/features/orders/ui/orders_page.dart';
import 'package:naliv_delivery/features/profile/ui/profile_page.dart';
import 'package:naliv_delivery/features/home/home_view_data.dart';
import 'package:naliv_delivery/features/profile/profile_account.dart';
import 'package:naliv_delivery/features/certificates/ui/certificates_page.dart';
import 'package:naliv_delivery/pages/checkout_page.dart';
import 'package:naliv_delivery/features/faq/ui/faq_page.dart';
import 'package:naliv_delivery/pages/help_chat_page.dart';
import 'package:naliv_delivery/pages/order_detail_page.dart';
import 'package:naliv_delivery/pages/notification_settings_page.dart';
import 'package:naliv_delivery/pages/profile_addresses_page.dart';
import 'package:naliv_delivery/pages/profile_cards_page.dart';
import 'package:naliv_delivery/pages/profile_setup_page.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/pages/login_page.dart';
import 'package:naliv_delivery/pages/promotion_items_page.dart';
import 'package:naliv_delivery/features/home/ui/home_store_sheet.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/services/auth_service.dart';
import 'package:naliv_delivery/services/notification_service.dart';
import 'package:naliv_delivery/widgets/app_loading_screen.dart';

class AuthenticationWrapper extends StatefulWidget {
  final AppDestination? initialDestination;

  const AuthenticationWrapper({super.key, this.initialDestination});

  @override
  State<AuthenticationWrapper> createState() => _AuthenticationWrapperState();
}

class _AuthenticationWrapperState extends State<AuthenticationWrapper>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  Map<String, dynamic>? _userInfo;
  bool _businessLoaded = false;
  bool _requiresProfileSetup = false;
  bool _initialDestinationQueued = false;
  Future<void>? _checkingAuth;
  int _homeRequest = 0;
  bool _selectingStore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthService.sessionRevision.addListener(_sessionChanged);
    _checkAuth();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AuthService.sessionRevision.removeListener(_sessionChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshOnReturn();
  }

  void _sessionChanged() {
    if (!mounted) return;
    _homeRequest++;
    setState(() {
      _userInfo = null;
      _isAuthenticated = false;
      _requiresProfileSetup = false;
      _homeData = null;
    });
    _refreshOnReturn();
  }

  Future<void> _refreshOnReturn() async {
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    await _checkAuth();
  }

  /// Bound on the session check. Without it a stalled `/auth/full-info` — a dead dev server, a
  /// captive network — keeps [_isLoading] true and the app never leaves its loader.
  static const Duration _authCheckTimeout = Duration(seconds: 10);

  Future<void> _checkAuth() =>
      _checkingAuth ??= _readAuth().whenComplete(() => _checkingAuth = null);

  Future<void> _readAuth() async {
    Map<String, dynamic>? userInfo;
    try {
      userInfo = await ApiService.getFullInfo().timeout(_authCheckTimeout);
    } on TimeoutException {
      debugPrint('Auth check timed out; continuing as a guest');
    } catch (e) {
      debugPrint('Error checking authentication: $e');
    }

    if (!mounted) return;

    // An unavailable account read is not proof of an invalid token.
    if (userInfo != null) {
      await AuthService.refreshIdentity(verifiedInfo: userInfo);
    } else if (await ApiService.getAuthToken() == null) {
      AuthService.bindAuthenticatedIdentity(null);
    }
    if (!mounted) return;
    setState(() {
      _userInfo = userInfo;
      _isAuthenticated = userInfo != null;
      _requiresProfileSetup = ProfileSetupPage.isRequiredFor(userInfo);
      _isLoading = false;
    });

    // The home screen is public — the design ships a signed-out variant of it — so it is loaded
    // whether or not there is a session. Loading it only for signed-in users left everyone else
    // staring at the loader, because [build] shows [AppLoadingScreen] while [_homeData] is null.
    if (mounted) await _loadHome();
    if (mounted && _homeData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          NotificationService.instance.resumePendingNavigation(
              openDestination: _navigate);
        }
      });
    }
  }

  Future<void> _handleProfileSetupCompleted(
      Map<String, dynamic>? refreshedUserInfo) async {
    final userInfo = refreshedUserInfo ?? await ApiService.getFullInfo();
    if (userInfo != null) {
      await AuthService.refreshIdentity(verifiedInfo: userInfo);
    }
    if (!mounted) return;
    setState(() {
      _userInfo = userInfo;
      _isAuthenticated = userInfo != null;
      _requiresProfileSetup = ProfileSetupPage.isRequiredFor(userInfo);
    });
    await _loadHome();
  }

  Map<String, dynamic>? _userMap(Map<String, dynamic>? userInfo) {
    final user = userInfo?['user'];
    if (user is Map<String, dynamic>) {
      return user;
    }
    if (user is Map) {
      return user.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppLoadingScreen();
    }

    if (_isAuthenticated && _requiresProfileSetup) {
      final user = _userMap(_userInfo);
      return ProfileSetupPage(
        initialUser: user ?? <String, dynamic>{},
        onCompleted: _handleProfileSetupCompleted,
      );
    }

    final homeData = _homeData;
    if (homeData == null) {
      return _homeError == null
          ? const AppLoadingScreen()
          : AppLoadFailed(message: _homeError!, onRetry: _loadHome);
    }
    if (!_initialDestinationQueued && widget.initialDestination != null) {
      _initialDestinationQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _navigate(widget.initialDestination!);
      });
    }

    return HomeScreen(
      data: homeData,
      onCart: () => _openCart(),
      onSearch: _openSearch,
      onCallCenter: _callSupport,
      onStore: _selectStore,
      onPromo: _openPromotion,
      onActiveOrder: (order) => _push(OrderDetailPage(order: order.source)),
      onBonusHistory: () => _navigate(AppDestination.bonuses),
      onSignIn: _signIn,
      onNavigate: _navigate,
      onCategory: _openSupercategory,
    );
  }

  // Public home data and full-screen destinations share the frozen API.

  HomeViewData? _homeData;
  String? _homeError;

  /// Bound on the home fetch. It fans out to several endpoints at once, so without this a single
  /// stalled request left the app on its loader indefinitely — reported as "endless loading".
  static const Duration _homeLoadTimeout = Duration(seconds: 20);

  Future<void> _loadHome() async {
    if (!mounted) return;
    final request = ++_homeRequest;
    setState(() => _homeError = null);
    try {
      final selected = context.read<BusinessProvider>();
      final cart = context.read<CartProvider>();
      await cart.ensureLoaded();
      if (!_businessLoaded) {
        await selected.loadSavedBusiness();
        _businessLoaded = true;
      }
      final cartStore = cart.hasActiveItems ? cart.businessId : null;
      final data = await HomeDataSource(
        businessId: cartStore ??
            (cart.hasUnresolvedBusiness ? null : selected.selectedBusinessId),
        allowDefaultBusiness: !cart.hasUnresolvedBusiness,
        onBusinessSelected: (business) async {
          if (!mounted || request != _homeRequest) return false;
          final id = BusinessProvider.idOf(business);
          if (id == null ||
              (cart.hasActiveItems && cart.businessId != id)) {
            return false;
          }
          final previous = selected.selectedBusiness;
          if (!await selected.setSelectedBusiness(business)) return false;
          if (!await cart.bindBusiness(id)) {
            await selected.setSelectedBusiness(previous);
            return false;
          }
          return true;
        },
      ).load().timeout(_homeLoadTimeout);
      if (!mounted || request != _homeRequest) return;
      setState(() => _homeData = data);
    } catch (e) {
      debugPrint('HomeDataSource failed: $e');
      if (!mounted || request != _homeRequest) return;
      setState(() => _homeError = 'Не удалось загрузить главную страницу');
    }
  }

  Future<void> _signIn({AppDestination? destination}) async {
    final authenticated = await _pushForResult<bool>(const LoginPage(
      startWithPhoneForm: true,
      completionMode: LoginCompletionMode.returnAuthenticated,
    ));
    if (!mounted || authenticated != true) return;
    await _checkAuth();
    if (mounted && destination != null) await _navigate(destination);
  }

  Future<T?> _pushForResult<T>(Widget page) =>
      Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

  Future<void> _callSupport() => _navigate(AppDestination.support);

  Future<void> _selectStore() async {
    final data = _homeData;
    if (_selectingStore) return;
    if (data == null || data.stores.isEmpty) return;
    final palette = Theme.of(context).colorScheme;
    final store = await showModalBottomSheet<HomeStore>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => HomeStoreSheet(
        stores: data.stores,
        selectedId: data.storeId,
      ),
    );
    if (!mounted || store == null) return;
    final cart = context.read<CartProvider>();
    final selected = context.read<BusinessProvider>();
    final currentId = cart.hasActiveItems ? cart.businessId : data.storeId;
    if (store.id == currentId) return;
    if (cart.hasActiveItems) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Сменить магазин?'),
          content: const Text(
            'Товары относятся к исходному магазину: переносить их без пересчёта нельзя. Удалить текущую корзину и выбрать другой магазин?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              key: const ValueKey('confirm-store-change'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Удалить корзину и сменить'),
            ),
          ],
        ),
      );
      if (!mounted || discard != true) return;
    }
    _selectingStore = true;
    final previous = selected.selectedBusiness;
    final saved = await selected.setSelectedBusiness({
      'id': store.id,
      'name': store.name,
      'address': store.address,
      if (store.city != null) '_cityName': store.city,
    });
    final cartSaved = saved &&
        (cart.hasActiveItems
            ? await cart.discardForBusiness(store.id)
            : await cart.bindBusiness(store.id));
    if (saved && !cartSaved) await selected.setSelectedBusiness(previous);
    _selectingStore = false;
    if (!cartSaved) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Не удалось сохранить магазин. Корзина не изменена.')),
        );
      }
      return;
    }
    if (mounted) {
      setState(() => _homeData = null);
      await _loadHome();
    }
  }

  void _openPromotion(HomeBanner banner) {
    final promotionId = banner.promotionId;
    final storeId = _homeData?.storeId;
    if (promotionId == null || storeId == null) return;
    _push(PromotionItemsPage(
      promotionId: promotionId,
      promotionName: banner.title,
      businessId: storeId,
      onCart: _openCart,
    ));
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => page),
    );
    if (mounted) await _refreshOnReturn();
  }

  Future<void> _navigate(AppDestination destination) async {
    if (!_isAuthenticated &&
        (destination == AppDestination.favorites ||
            destination == AppDestination.orders ||
            destination == AppDestination.bonuses ||
            destination == AppDestination.cards ||
            destination == AppDestination.addresses ||
            destination == AppDestination.certificates)) {
      await _signIn(destination: destination);
      return;
    }
    final storeId = _homeData?.storeId ?? 0;
    switch (destination) {
      case AppDestination.home:
        break; // already on the root screen
      case AppDestination.favorites:
        await _push(FavoritesPage(
          businessId: storeId,
          onCart: () => _openCart(),
        ));
      case AppDestination.notifications:
        await _push(const NotificationSettingsPage());
      case AppDestination.profile:
        await _push(ProfilePage(
          loadAccount: _loadProfileAccount,
          onSignIn: _signIn,
          onNavigate: _navigate,
          onLogout: _logout,
        ));
      case AppDestination.orders:
        await _push(OrdersPage(
          businessId: _homeData?.storeId,
          onCart: _openCart,
        ));
      case AppDestination.bonuses:
        await _push(BonusHistoryPage(
          onHowItWorks: _openHowBonusesWork,
          onCart: _openCart,
        ));
      case AppDestination.certificates:
        await _push(CertificatesPage(
          onCart: _openCart,
        ));
      case AppDestination.addresses:
        await _push(const ProfileAddressesPage());
      case AppDestination.cards:
        await _push(const ProfileCardsPage());
      case AppDestination.faq:
        await _push(const FaqPage());
      case AppDestination.support:
        await _push(const HelpChatPage(entryPoint: 'profile'));
    }
  }

  Future<ProfileAccount?> _loadProfileAccount() async {
    if (!_isAuthenticated) return null;
    final info = await ApiService.getFullInfo().timeout(_authCheckTimeout);
    if (info == null) throw StateError('Could not load account');
    final account = ProfileAccount.fromJson(info);
    if (mounted) setState(() => _userInfo = info);
    return account;
  }

  /// Opens the store-scoped cart and its active checkout route.
  void _openCart() {
    _push(CartPage(
      businessId: _homeData?.storeId,
      address: _homeData?.storeAddress,
      onCheckout: () => _push(const CheckoutPage()),
      onCatalog: () => Navigator.of(context).maybePop(),
    ));
  }

  /// The redesigned search screen, scoped to the store the home screen is showing.
  void _openSearch() {
    if (_homeData?.storeId == null) {
      _selectStore();
      return;
    }
    _push(SearchPage(
      businessId: _homeData?.storeId,
      onCart: () => _openCart(),
    ));
  }

  /// Home tiles and the promo card open the supercategory screen.
  void _openSupercategory(HomeCategory category) {
    final storeId = _homeData?.storeId;
    if (storeId == null) {
      _selectStore();
      return;
    }
    _push(SupercategoryPage(
      supercategoryId: category.id,
      businessId: storeId,
      title: category.title,
      onSearch: _openSearch,
      onCart: () => _openCart(),
    ));
  }

  Future<void> _openHowBonusesWork() =>
      _push(BonusHowItWorksPage(onOpenFaq: () => _push(const FaqPage())));

  Future<void> _logout() async {
    try {
      await AuthService.clearToken();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось выйти из аккаунта')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _isAuthenticated = false;
      _userInfo = null;
      _homeData = null;
    });
    await _loadHome();
  }
}

/// Minimal failure state for the home screen. Not a designed screen: the design defines
/// "could not load" only for FAQ, so this stays deliberately plain until that is specified.
class AppLoadFailed extends StatelessWidget {
  const AppLoadFailed({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Повторить')),
            ],
          ),
        ),
      ),
    );
  }
}
