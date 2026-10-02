import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/destinations.dart';
import '../../utils/cart_provider.dart';
import '../product/product_navigation.dart';
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
    this.onPromo,
    this.onActiveOrder,
    this.onCategory,
    this.onBonusHistory,
    this.onSignIn,
    super.key,
  });

  final HomeViewData data;
  final ValueChanged<AppDestination>? onNavigate;
  final VoidCallback? onCart;
  final VoidCallback? onSearch;
  final VoidCallback? onCallCenter;
  final VoidCallback? onStore;
  final ValueChanged<HomeBanner>? onPromo;
  final ValueChanged<HomeActiveOrder>? onActiveOrder;
  final ValueChanged<HomeCategory>? onCategory;
  final VoidCallback? onBonusHistory;
  final VoidCallback? onSignIn;

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
          onLiked: () => onNavigate?.call(AppDestination.favorites),
          onNotifications: () => onNavigate?.call(AppDestination.notifications),
          onProfile: onNavigate == null
              ? null
              : () => onNavigate!(AppDestination.profile),
          onStore: onStore,
          onPromo: onPromo,
          onActiveOrder: onActiveOrder,
          onCategory: onCategory,
          onBonusHistory: onBonusHistory,
          onSignIn: onSignIn,
          productQuantity: (product) => cart.getCatalogQuantity(product.source),
          onProductTap: (product) => openProduct(
            context,
            product,
            businessId: data.storeId,
            onCart: onCart,
          ),
          onProductIncrement: (product) =>
              context.read<CartProvider>().incrementCatalogItem(product.source),
          onProductDecrement: (product) =>
              context.read<CartProvider>().decrementCatalogItem(product.source),
        );
      },
    );
  }
}
