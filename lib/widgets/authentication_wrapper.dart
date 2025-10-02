import 'package:flutter/material.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/pages/bottomMenu.dart';
import 'package:naliv_delivery/services/auth_service.dart';

class AuthenticationWrapper extends StatefulWidget {
  final int? initialTabIndex;

  const AuthenticationWrapper({super.key, this.initialTabIndex});

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
      print('Error checking authentication: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Всегда показываем bottomMenu, но передаем статус авторизации
    return BottomMenu(
      isAuthenticated: _isAuthenticated,
      userInfo: _userInfo,
      initialTabIndex: widget.initialTabIndex,
    );
  }
}
