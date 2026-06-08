class OneSignalWebBridge {
  static Future<bool> initialize() async => false;

  static Future<bool> requestPermission() async => false;

  static Future<String?> getSubscriptionId() async => null;

  static Future<String?> getPushToken() async => null;

  static Future<bool> login(String externalId) async => false;

  static Future<bool> logout() async => false;

  static Future<bool> addTag(String key, String value) async => false;

  static Future<bool> removeTag(String key) async => false;
}
