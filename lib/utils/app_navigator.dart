import 'package:flutter/material.dart';
import 'package:gradusy24/widgets/authentication_wrapper.dart';

class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static NavigatorState? get _nav => key.currentState;

  static Future<void> goToHomeTab(int tabIndex) async {
    await _nav?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => AuthenticationWrapper(initialTabIndex: tabIndex),
      ),
      (route) => false,
    );
  }
}
