import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/destinations.dart';
import '../../utils/cart_provider.dart';
import '../../ui/app_cart_button.dart';
import '../../ui/product_card.dart';
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
    return HomePage(
      data: data,
      cartDock: Selector<CartProvider, (int, double?)>(
        selector: (_, cart) => (
          cart.displayItemCount,
          cart.displayItemCount == 0 ? null : cart.getTotalPrice(),
        ),
        builder: (_, summary, __) => AppCartButton(
          itemCount: summary.$1,
          total: summary.$2,
          onTap: onCart,
        ),
      ),
      onCart: onCart,
      onSearch: onSearch,
      onCallCenter: onCallCenter,
      onLiked: () => onNavigate?.call(AppDestination.favorites),
      onNotifications: () => onNavigate?.call(AppDestination.notifications),
      onProfile:
          onNavigate == null ? null : () => onNavigate!(AppDestination.profile),
      onStore: onStore,
      onPromo: onPromo,
      onActiveOrder: onActiveOrder,
      onCategory: onCategory,
      onBonusHistory: onBonusHistory,
      onSignIn: onSignIn,
      productBuilder: (_, product) => Selector<CartProvider, double>(
        selector: (_, cart) =>
            cart.getCatalogQuantityForKey(product.catalogKey),
        builder: (context, quantity, _) => ProductCard.fromView(
          product,
          key: ValueKey('home-product-${product.itemId}'),
          quantity: quantity,
          onTap: () => openProduct(
            context,
            product,
            businessId: data.storeId,
            onCart: onCart,
          ),
          onIncrement: () =>
              context.read<CartProvider>().incrementCatalogItem(product.source),
          onDecrement: () =>
              context.read<CartProvider>().decrementCatalogItem(product.source),
        ),
      ),
    );
  }
}
