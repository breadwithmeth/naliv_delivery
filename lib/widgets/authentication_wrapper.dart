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
import 'package:naliv_delivery/widgets/app_loading_screen.dart';

class AuthenticationWrapper extends StatefulWidget {
  final AppDestination? initialDestination;

  const AuthenticationWrapper({super.key, this.initialDestination});

  @override
  State<AuthenticationWrapper> createState() => _AuthenticationWrapperState();
}

class _AuthenticationWrapperState extends State<AuthenticationWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  Map<String, dynamic>? _userInfo;
  bool _businessLoaded = false;
  bool _requiresProfileSetup = false;
  bool _initialDestinationQueued = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  /// Bound on the session check. Without it a stalled `/auth/full-info` — a dead dev server, a
  /// captive network — keeps [_isLoading] true and the app never leaves its loader.
  static const Duration _authCheckTimeout = Duration(seconds: 10);

  Future<void> _checkAuth() async {
    Map<String, dynamic>? userInfo;
    try {
      userInfo = await ApiService.getFullInfo().timeout(_authCheckTimeout);
    } on TimeoutException {
      debugPrint('Auth check timed out; continuing as a guest');
    } catch (e) {
      debugPrint('Error checking authentication: $e');
    }

    if (!mounted) return;
    setState(() {
      _userInfo = userInfo;
      _isAuthenticated = userInfo != null;
      _requiresProfileSetup = ProfileSetupPage.isRequiredFor(userInfo);
      _isLoading = false;
    });

    // A guest has nothing to log out of. In particular, do not initialize the
    // push SDK on every anonymous launch before loading the public home page.
    if (userInfo == null && await ApiService.getAuthToken() != null) {
      try {
        await AuthService.clearToken();
      } catch (error) {
        debugPrint('Could not clear invalid session: $error');
      }
    }

    // The home screen is public — the design ships a signed-out variant of it — so it is loaded
    // whether or not there is a session. Loading it only for signed-in users left everyone else
    // staring at the loader, because [build] shows [AppLoadingScreen] while [_homeData] is null.
    if (mounted) await _loadHome();
  }

  Future<void> _handleProfileSetupCompleted(
      Map<String, dynamic>? refreshedUserInfo) async {
    final userInfo = refreshedUserInfo ?? await ApiService.getFullInfo();
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
    setState(() => _homeError = null);
    try {
      final selected = context.read<BusinessProvider>();
      if (!_businessLoaded) {
        await selected.loadSavedBusiness();
        _businessLoaded = true;
      }
      final data = await HomeDataSource(businessId: selected.selectedBusinessId)
          .load()
          .timeout(_homeLoadTimeout);
      if (!mounted) return;
      setState(() => _homeData = data);
    } catch (e) {
      debugPrint('HomeDataSource failed: $e');
      if (!mounted) return;
      setState(() => _homeError = 'Не удалось загрузить главную страницу');
    }
  }

  Future<void> _signIn({AppDestination? destination}) async {
    await _pushForResult(LoginPage(
      startWithPhoneForm: true,
      destinationAfterSignIn: destination,
    ));
    if (mounted) await _checkAuth();
  }

  Future<T?> _pushForResult<T>(Widget page) =>
      Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

  Future<void> _callSupport() => _navigate(AppDestination.support);

  Future<void> _selectStore() async {
    final data = _homeData;
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
    if (!mounted || store == null || store.id == data.storeId) return;
    final cart = context.read<CartProvider>();
    if (cart.hasActiveItems) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Сменить магазин?'),
          content: const Text(
            'Цены и ассортимент отличаются. Товары текущего магазина будут удалены из корзины.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Сменить магазин'),
            ),
          ],
        ),
      );
      if (!mounted || discard != true) return;
    }
    final saved = await context.read<BusinessProvider>().setSelectedBusiness({
      'id': store.id,
      'name': store.name,
      'address': store.address,
      if (store.city != null) '_cityName': store.city,
    });
    if (!saved) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Не удалось сохранить магазин. Корзина не изменена.')),
        );
      }
      return;
    }
    cart.clearCart();
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
    _push(SearchPage(
      businessId: _homeData?.storeId,
      onCart: () => _openCart(),
    ));
  }

  /// Home tiles and the promo card open the supercategory screen.
  void _openSupercategory(HomeCategory category) {
    _push(SupercategoryPage(
      supercategoryId: category.id,
      businessId: _homeData?.storeId ?? 0,
      title: category.title,
      onSearch: _openSearch,
      onCart: () => _openCart(),
    ));
  }

  void _openHowBonusesWork() {
    _push(BonusHowItWorksPage(onOpenFaq: () => _push(const FaqPage())));
  }

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
