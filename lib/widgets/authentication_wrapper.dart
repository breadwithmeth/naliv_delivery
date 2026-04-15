import 'package:flutter/material.dart';
import 'package:gradusy24/utils/api.dart';
import 'package:gradusy24/pages/bottomMenu.dart';
import 'package:gradusy24/services/auth_service.dart';
import 'package:gradusy24/widgets/app_loading_screen.dart';

class AuthenticationWrapper extends StatefulWidget {
  final int? initialTabIndex;
  final bool openCheckoutOnStart;

  const AuthenticationWrapper({super.key, this.initialTabIndex, this.openCheckoutOnStart = false});

  @override
  State<AuthenticationWrapper> createState() => _AuthenticationWrapperState();
}

class _AuthenticationWrapperState extends State<AuthenticationWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  Map<String, dynamic>? _userInfo;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      final userInfo = await ApiService.getFullInfo();

      if (mounted) {
        setState(() {
          _userInfo = userInfo;
          _isAuthenticated = userInfo != null;
          _isLoading = false;
        });
      }

      // Если токен невалидный (userInfo == null), почистим локально сохранённый токен
      if (userInfo == null) {
        await AuthService.clearToken();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
        });
      }
      debugPrint('Error checking authentication: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppLoadingScreen();
    }

    // Всегда показываем bottomMenu, но передаем статус авторизации
    return BottomMenu(
      isAuthenticated: _isAuthenticated,
      userInfo: _userInfo,
      initialTabIndex: widget.initialTabIndex,
      openCheckoutOnStart: widget.openCheckoutOnStart,
    );
  }
}
