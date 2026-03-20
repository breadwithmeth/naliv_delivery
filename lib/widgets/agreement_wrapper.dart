import 'package:flutter/material.dart';
import '../services/agreement_service.dart';
import '../pages/mandatory_offer_page.dart';
import '../utils/responsive.dart';
import 'authentication_wrapper.dart';

/// Виджет-обертка для проверки принятия пользовательских соглашений
class AgreementWrapper extends StatefulWidget {
  const AgreementWrapper({super.key});

  @override
  State<AgreementWrapper> createState() => _AgreementWrapperState();
}

class _AgreementWrapperState extends State<AgreementWrapper> {
  bool _isLoading = true;
  bool _agreementsAccepted = false;

  @override
  void initState() {
    super.initState();
    _checkAgreements();
  }

  Future<void> _checkAgreements() async {
    try {
      final accepted = await AgreementService.areAllAgreementsAccepted();

      setState(() {
        _agreementsAccepted = accepted;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Ошибка при проверке согласий: $e');
      setState(() {
        _agreementsAccepted = false;
        _isLoading = false;
      });
    }
  }

  void _onAgreementAccepted() {
    setState(() {
      _agreementsAccepted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/naliv_logo_loading.png',
                width: 108.s,
                height: 108.s,
              ),
              SizedBox(height: 22.s),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(height: 14.s),
              Text(
                'Загружаем приложение...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15.sp,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_agreementsAccepted) {
      return MandatoryOfferPage(
        onAccepted: _onAgreementAccepted,
      );
    }

    return const AuthenticationWrapper();
  }
}
