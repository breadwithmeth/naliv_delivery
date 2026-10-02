import 'package:flutter/material.dart';
import 'package:naliv_delivery/widgets/authentication_wrapper.dart';
import '../core/destinations.dart';

class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static NavigatorState? get _nav => key.currentState;

  static Future<void> goToHome({AppDestination? destination}) async {
    await _nav?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => AuthenticationWrapper(initialDestination: destination),
      ),
      (route) => false,
    );
  }
}
