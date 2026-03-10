import 'package:shared_preferences/shared_preferences.dart';

/// Сервис для управления пользовательскими согласиями
class AgreementService {
  static const String _offerAcceptedKey = 'offer_accepted';
  static const String _privacyAcceptedKey = 'privacy_accepted';
  static const String _termsAcceptedKey = 'terms_accepted';

  /// Проверить, принята ли оферта
  static Future<bool> isOfferAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_offerAcceptedKey) ?? false;
  }

  /// Отметить оферту как принятую
  static Future<void> acceptOffer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_offerAcceptedKey, true);
  }

  /// Проверить, принята ли политика конфиденциальности
  static Future<bool> isPrivacyAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_privacyAcceptedKey) ?? false;
  }

  /// Отметить политику конфиденциальности как принятую
  static Future<void> acceptPrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privacyAcceptedKey, true);
  }

  /// Проверить, приняты ли условия использования
  static Future<bool> isTermsAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_termsAcceptedKey) ?? false;
  }

  /// Отметить условия использования как принятые
  static Future<void> acceptTerms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_termsAcceptedKey, true);
  }

  /// Проверить, приняты ли все необходимые соглашения
  static Future<bool> areAllAgreementsAccepted() async {
    final offerAccepted = await isOfferAccepted();
    // Можно добавить другие соглашения при необходимости
    // final privacyAccepted = await isPrivacyAccepted();
    // final termsAccepted = await isTermsAccepted();

    return offerAccepted;
  }

  /// Сбросить все согласия (для отладки)
  static Future<void> resetAllAgreements() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_offerAcceptedKey);
    await prefs.remove(_privacyAcceptedKey);
    await prefs.remove(_termsAcceptedKey);
  }

  /// Принять все соглашения разом
  static Future<void> acceptAllAgreements() async {
    await acceptOffer();
    await acceptPrivacy();
    await acceptTerms();
  }
}
