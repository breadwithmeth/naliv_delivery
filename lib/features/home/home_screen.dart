import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/destinations.dart';
import '../../core/theme_controller.dart';
import '../../ui/app_icon.dart';
import '../../ui/app_sidebar.dart';
import '../../utils/cart_provider.dart';
import 'home_view_data.dart';
import 'ui/home_page.dart';

/// Hosts the redesigned home screen: live cart state in, navigation intent out.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.data,
    this.onNavigate,
    this.onCart,
    this.onSearch,
    this.onCallCenter,
    this.onStore,
    this.onCategory,
    this.onBonusHistory,
    this.onSignIn,
    this.onLogout,
    this.userName,
    this.userSubtitle,
    this.onThemeModeChanged,
    super.key,
  });

  final HomeViewData data;
  final ValueChanged<AppDestination>? onNavigate;
  final VoidCallback? onCart;
  final VoidCallback? onSearch;
  final VoidCallback? onCallCenter;
  final VoidCallback? onStore;
  final ValueChanged<HomeCategory>? onCategory;
  final VoidCallback? onBonusHistory;
  final VoidCallback? onSignIn;
  final VoidCallback? onLogout;

  /// Identity shown in the sidebar. The store's name is **not** the user's: `/auth/full-info`
  /// returns the person's name, and carries no phone, so the subtitle stays empty unless given.
  final String? userName;
  final String? userSubtitle;

  /// Sidebar theme switch; the app owns persistence through [ThemeController].
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        // The two numbers the design puts in the cart button (`Поиск - Удачный поиск`):
        // the badge counts distinct cart rows, the pill shows the payable total.
        final count = cart.displayItemCount;
        final total = count == 0 ? null : cart.getTotalPrice().round();
        return HomePage(
          data: data,
          cartItemCount: count,
          cartTotal: total,
          onCart: onCart,
          onSearch: onSearch,
          onCallCenter: onCallCenter,
          onFavorites: () => onNavigate?.call(AppDestination.favorites),
          onLiked: () => onNavigate?.call(AppDestination.favorites),
          onNotifications: () => onNavigate?.call(AppDestination.notifications),
          onStore: onStore,
          onCategory: onCategory,
          onBonusHistory: onBonusHistory,
          onSignIn: onSignIn,
          sidebar: AppSidebar(
            userName: data.signedIn ? (userName ?? 'Гость') : null,
            userSubtitle:
                data.signedIn ? userSubtitle : 'Войдите, чтобы копить бонусы',
            themeMode: context.watch<ThemeController>().mode,
            onThemeModeChanged: onThemeModeChanged,
            items: [
              for (final entry in const [
                (AppIcons.shop, 'Главная', AppDestination.home),
                (AppIcons.heart, 'Избранное', AppDestination.favorites),
                (AppIcons.bell, 'Уведомления', AppDestination.notifications),
                (AppIcons.user, 'Профиль', AppDestination.profile),
                (AppIcons.orders, 'История заказов', AppDestination.orders),
                (AppIcons.bonusStar, 'Бонусы', AppDestination.bonuses),
                (
                  AppIcons.certificates,
                  'Сертификаты',
                  AppDestination.certificates
                ),
                (AppIcons.addresses, 'Адреса', AppDestination.addresses),
                (AppIcons.cards, 'Карты', AppDestination.cards),
                (AppIcons.faq, 'FAQ', AppDestination.faq),
                (AppIcons.support, 'Поддержка', AppDestination.support),
              ])
                AppSidebarItem(
                  icon: entry.$1,
                  label: entry.$2,
                  badgeCount: entry.$3 == AppDestination.notifications
                      ? data.notificationCount
                      : 0,
                  onTap: () {
                    Navigator.of(context).maybePop();
                    onNavigate?.call(entry.$3);
                  },
                ),
            ],
            onLogout: onLogout,
          ),
        );
      },
    );
  }
}
