import 'package:flutter/material.dart';
import 'package:naliv_delivery/features/onboarding/ui/intro_slides_page.dart';
import 'package:naliv_delivery/pages/onboarding_page.dart';
import 'package:naliv_delivery/services/onboarding_service.dart';
import 'package:naliv_delivery/widgets/authentication_wrapper.dart';
import 'package:naliv_delivery/widgets/app_loading_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppEntryGate extends StatefulWidget {
  const AppEntryGate({super.key});

  @override
  State<AppEntryGate> createState() => _AppEntryGateState();
}

class _AppEntryGateState extends State<AppEntryGate> {
  /// The introduction slides are shown once, before the city/permissions onboarding, and are
  /// independent of it — so they get their own key rather than changing [OnboardingService].
  static const String _introSeenKey = 'intro_slides_seen';

  bool _isLoading = true;
  bool _isCompleted = false;
  bool _introSeen = true;
  String? _selectedCity;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final state = await OnboardingService.getState();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isCompleted = state.isCompleted;
      _introSeen = prefs.getBool(_introSeenKey) ?? false;
      _selectedCity = state.selectedCity;
    });
  }

  Future<void> _completeIntro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_introSeenKey, true);
    if (!mounted) return;
    setState(() => _introSeen = true);
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

    if (!_introSeen) {
      return IntroSlidesPage(onContinue: _completeIntro);
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
