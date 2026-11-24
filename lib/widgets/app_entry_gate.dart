import 'package:flutter/material.dart';
import 'package:naliv_delivery/features/onboarding/ui/intro_slides_page.dart';
import 'package:naliv_delivery/pages/onboarding_page.dart';
import 'package:naliv_delivery/services/onboarding_service.dart';
import 'package:naliv_delivery/features/onboarding/legal_acceptance.dart';
import 'package:naliv_delivery/features/onboarding/ui/legal_acceptance_page.dart';
import 'package:naliv_delivery/widgets/app_loading_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppEntryGate extends StatefulWidget {
  const AppEntryGate({required this.onAdmitted, super.key});

  final VoidCallback onAdmitted;

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
  Map<String, int> _accepted = {};
  String? _error;
  bool _admissionQueued = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final state = await OnboardingService.getState();
      final prefs = await SharedPreferences.getInstance();
      final accepted = await LegalAcceptance.read();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isCompleted = state.isCompleted;
        _introSeen = prefs.getBool(_introSeenKey) ?? state.isCompleted;
        _selectedCity = state.selectedCity;
        _accepted = accepted;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Не удалось прочитать состояние входа. Повторите попытку.';
        });
      }
    }
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

    if (_error != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                TextButton(
                  onPressed: _loadState,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (!_introSeen) {
      return IntroSlidesPage(onContinue: _completeIntro);
    }

    if (!LegalAcceptance.isCurrent(_accepted)) {
      return LegalAcceptancePage(
        accepted: _accepted,
        onAccepted: () =>
            setState(() => _accepted = Map.of(LegalAcceptance.current)),
      );
    }

    if (_isCompleted) {
      if (!_admissionQueued) {
        _admissionQueued = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onAdmitted();
        });
      }
      return const AppLoadingScreen();
    }

    return OnboardingPage(
      initialCity: _selectedCity,
      onCompleted: _handleOnboardingCompleted,
    );
  }
}
