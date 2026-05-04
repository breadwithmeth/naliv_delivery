import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/onboarding_page.dart';
import 'package:naliv_delivery/services/onboarding_service.dart';
import 'package:naliv_delivery/widgets/authentication_wrapper.dart';
import 'package:naliv_delivery/widgets/app_loading_screen.dart';

class AppEntryGate extends StatefulWidget {
  const AppEntryGate({super.key});

  @override
  State<AppEntryGate> createState() => _AppEntryGateState();
}

class _AppEntryGateState extends State<AppEntryGate> {
  bool _isLoading = true;
  bool _isCompleted = false;
  String? _selectedCity;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final state = await OnboardingService.getState();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isCompleted = state.isCompleted;
      _selectedCity = state.selectedCity;
    });
  }

  void _handleOnboardingCompleted() {
    if (!mounted) return;
    setState(() {
      _isCompleted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppLoadingScreen();
    }

    if (_isCompleted) {
      return const AuthenticationWrapper();
    }

    return OnboardingPage(
      initialCity: _selectedCity,
      onCompleted: _handleOnboardingCompleted,
    );
  }
}
