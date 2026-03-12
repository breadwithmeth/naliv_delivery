import 'package:shared_preferences/shared_preferences.dart';

class OnboardingState {
  const OnboardingState({
    required this.isCompleted,
    required this.selectedCity,
    required this.locationPromptSeen,
    required this.notificationPromptSeen,
  });

  final bool isCompleted;
  final String? selectedCity;
  final bool locationPromptSeen;
  final bool notificationPromptSeen;
}

class OnboardingService {
  static const String _completedKey = 'onboarding_completed';
  static const String _selectedCityKey = 'onboarding_selected_city';
  static const String _locationPromptSeenKey = 'onboarding_location_prompt_seen';
  static const String _notificationPromptSeenKey = 'onboarding_notification_prompt_seen';

  static Future<OnboardingState> getState() async {
    final prefs = await SharedPreferences.getInstance();
    return OnboardingState(
      isCompleted: prefs.getBool(_completedKey) ?? false,
      selectedCity: prefs.getString(_selectedCityKey),
      locationPromptSeen: prefs.getBool(_locationPromptSeenKey) ?? false,
      notificationPromptSeen: prefs.getBool(_notificationPromptSeenKey) ?? false,
    );
  }

  static Future<void> setSelectedCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedCityKey, city);
  }

  static Future<void> markLocationPromptSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_locationPromptSeenKey, true);
  }

  static Future<void> markNotificationPromptSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationPromptSeenKey, true);
  }

  static Future<void> complete({required String city}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedCityKey, city);
    await prefs.setBool(_completedKey, true);
  }
}
