import 'package:flutter/material.dart';
import 'package:naliv_delivery/widgets/authentication_wrapper.dart';
import '../core/destinations.dart';

class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static NavigatorState? get _nav => key.currentState;

  static VoidCallback? _cartOpener;

  /// The live home screen's way to open its store-scoped cart; null while
  /// there is no home screen.
  static void registerCartOpener(VoidCallback? opener) => _cartOpener = opener;
  static void unregisterCartOpener(VoidCallback opener) {
    if (identical(_cartOpener, opener)) _cartOpener = null;
  }

  static Future<void> goToHome({AppDestination? destination}) async {
    await _nav?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => AuthenticationWrapper(initialDestination: destination),
      ),
      (route) => false,
    );
  }

  /// Back to home with the cart on top, so back from the cart goes home. The
  /// live home screen does both through its own navigator.
  static Future<void> openCart() async {
    final opener = _cartOpener;
    if (opener != null) {
      opener();
      return;
    }
    await goToHome(destination: AppDestination.cart);
  }
}
