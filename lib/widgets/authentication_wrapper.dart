import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:naliv_delivery/features/cart/ui/cart_page.dart';
import 'package:naliv_delivery/features/bonuses/ui/bonus_history_page.dart';
import 'package:naliv_delivery/features/bonuses/ui/bonus_how_it_works_page.dart';
import 'package:naliv_delivery/features/catalog/ui/supercategory_page.dart';
import 'package:naliv_delivery/core/destinations.dart';
import 'package:naliv_delivery/core/theme_controller.dart';
import 'package:naliv_delivery/features/search/ui/search_page.dart';
import 'package:naliv_delivery/features/home/home_data_source.dart';
import 'package:naliv_delivery/features/favorites/ui/favorites_page.dart';
import 'package:naliv_delivery/features/home/home_screen.dart';
import 'package:naliv_delivery/features/orders/ui/orders_page.dart';
import 'package:naliv_delivery/features/profile/ui/profile_page.dart';
import 'package:naliv_delivery/features/home/home_view_data.dart';
import 'package:naliv_delivery/features/certificates/ui/certificates_page.dart';
import 'package:naliv_delivery/features/certificates/ui/certificates_placeholder_page.dart';
import 'package:naliv_delivery/pages/certificates_page.dart' as legacy;
import 'package:naliv_delivery/pages/checkout_page.dart';
import 'package:naliv_delivery/features/faq/ui/faq_page.dart';
import 'package:naliv_delivery/pages/help_chat_page.dart';
import 'package:naliv_delivery/pages/notification_settings_page.dart';
import 'package:naliv_delivery/pages/profile_addresses_page.dart';
import 'package:naliv_delivery/pages/profile_cards_page.dart';
import 'package:naliv_delivery/pages/profile_setup_page.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/services/auth_service.dart';
import 'package:naliv_delivery/widgets/app_loading_screen.dart';

class AuthenticationWrapper extends StatefulWidget {
  final int? initialTabIndex;
  final bool openCheckoutOnStart;

  const AuthenticationWrapper(
      {super.key, this.initialTabIndex, this.openCheckoutOnStart = false});

  @override
  State<AuthenticationWrapper> createState() => _AuthenticationWrapperState();
}

class _AuthenticationWrapperState extends State<AuthenticationWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  Map<String, dynamic>? _userInfo;
  bool _requiresProfileSetup = false;

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

    // Если токен невалидный (userInfo == null), почистим локально сохранённый токен
    if (userInfo == null) {
      await AuthService.clearToken();
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

    return HomeScreen(
      data: homeData,
      onCart: () => _openCart(),
      onSearch: _openSearch,
      onNavigate: _navigate,
      onCategory: _openSupercategory,
      onLogout: _logout,
      onThemeModeChanged: (mode) =>
          context.read<ThemeController>().setMode(mode),
      userName: _userMap(_userInfo)?['name']?.toString(),
    );
  }

  // ── Redesigned home wiring ──────────────────────────────────────────────────────────────
  //
  // The home screen is loaded from the same frozen API the old main page used. Destinations
  // that have not been rebuilt yet still open their existing screens; the sidebar is the
  // bridge, not a permanent arrangement.

  HomeViewData? _homeData;
  String? _homeError;

  /// Bound on the home fetch. It fans out to several endpoints at once, so without this a single
  /// stalled request left the app on its loader indefinitely — reported as "endless loading".
  static const Duration _homeLoadTimeout = Duration(seconds: 20);

  Future<void> _loadHome() async {
    setState(() => _homeError = null);
    try {
      final data =
          await const HomeDataSource().load().timeout(_homeLoadTimeout);
      if (!mounted) return;
      setState(() => _homeData = data);
    } catch (e) {
      debugPrint('HomeDataSource failed: $e');
      if (!mounted) return;
      setState(() => _homeError = 'Не удалось загрузить главную страницу');
    }
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _navigate(AppDestination destination) {
    final storeId = _homeData?.storeId ?? 0;
    switch (destination) {
      case AppDestination.home:
        break; // already on the root screen
      case AppDestination.favorites:
        _push(FavoritesPage(
          businessId: storeId,
          onCart: () => _openCart(),
        ));
      case AppDestination.notifications:
        _push(const NotificationSettingsPage());
      case AppDestination.profile:
        _push(ProfilePage(
          addressSummary: _addressSummary(_userInfo),
          cardsSummary: _cardsSummary(_userInfo),
          onNavigate: _navigate,
          onLogout: _logout,
        ));
      case AppDestination.orders:
        _push(OrdersPage(
          businessId: _homeData?.storeId,
          onCart: _openCart,
        ));
      case AppDestination.bonuses:
        _push(BonusHistoryPage(
          onHowItWorks: _openHowBonusesWork,
          onCart: _openCart,
        ));
      case AppDestination.certificates:
        // Placeholder by request; the real screen stays reachable so activation and purchase
        // are not lost while this area is parked.
        _push(CertificatesPlaceholderPage(
          onOpenDetails: () => _push(CertificatesPage(
            onBuy: () => _push(const legacy.CertificatesPage()),
            onCart: _openCart,
          )),
        ));
      case AppDestination.addresses:
        _push(const ProfileAddressesPage());
      case AppDestination.cards:
        _push(const ProfileCardsPage());
      case AppDestination.faq:
        _push(const FaqPage());
      case AppDestination.support:
        _push(const HelpChatPage(entryPoint: 'profile'));
    }
  }

  /// Row subtitles on the profile screen, worded exactly as the app words them today.
  String _addressSummary(Map<String, dynamic>? info) {
    final list =
        (info?['addresses'] as List?)?.whereType<Map>().toList() ?? const [];
    if (list.isEmpty) return 'Нет сохранённых адресов';
    return '${list.length} адрес(ов) · ${list.first['address'] ?? ''}';
  }

  String _cardsSummary(Map<String, dynamic>? info) {
    final list =
        (info?['cards'] as List?)?.whereType<Map>().toList() ?? const [];
    if (list.isEmpty) return 'Добавленных карт нет';
    return '${list.length} карт(ы) · ${list.first['mask'] ?? '••••'}';
  }

  /// The redesigned cart, scoped to the store the home screen is showing. Checkout is still the
  /// legacy screen: the design's delivery/payment frames come next.
  void _openCart() {
    _push(CartPage(
      businessId: _homeData?.storeId,
      address: _homeData?.storeAddress,
      onCheckout: () => _push(CheckoutPage()),
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
    await AuthService.clearToken();
    if (!mounted) return;
    setState(() {
      _isAuthenticated = false;
      _userInfo = null;
      _homeData = null;
    });
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
