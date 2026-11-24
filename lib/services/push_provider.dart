import 'package:flutter/foundation.dart';

@immutable
class PushSubscriptionSnapshot {
  const PushSubscriptionSnapshot({
    this.subscriptionId,
    this.pushToken,
    this.oneSignalId,
    this.permissionGranted = false,
    this.optedIn = false,
  });

  final String? subscriptionId;
  final String? pushToken;
  final String? oneSignalId;
  final bool permissionGranted;
  final bool optedIn;
}

/// A provider notification's display envelope and transient routing data.
@immutable
class PushNotificationEvent {
  const PushNotificationEvent({
    required this.id,
    required this.title,
    required this.body,
    required this.clicked,
    this.data = const {},
  });

  final String? id;
  final String? title;
  final String? body;
  final bool clicked;
  final Map<String, dynamic> data;
}

abstract interface class PushProvider {
  bool get supported;
  String get deviceType;
  bool get isWeb;
  PushSubscriptionSnapshot get current;
  Future<void> initialize({
    required VoidCallback onChange,
    required void Function(PushNotificationEvent) onNotification,
  });
  Future<PushSubscriptionSnapshot> readSubscription();
  Future<String?> readExternalId();
  Future<void> login(String externalId);
  Future<void> logout();
  Future<bool> requestPermission();
  Future<void> addTag(String key, String value);
  Future<void> removeTag(String key);
  Future<void> clearNotifications();
  void dispose();
}

// Fixture composition deliberately uses no SDK, platform channel or web bridge.
class InMemoryPushProvider implements PushProvider {
  InMemoryPushProvider({this.supported = true, this.deviceType = 'fixture'});

  @override
  final bool supported;
  @override
  final String deviceType;
  @override
  bool get isWeb => false;
  @override
  PushSubscriptionSnapshot current = const PushSubscriptionSnapshot();
  String? externalId;
  final tags = <String, String>{};

  @override
  Future<void> initialize({
    required VoidCallback onChange,
    required void Function(PushNotificationEvent) onNotification,
  }) async {}
  @override
  Future<PushSubscriptionSnapshot> readSubscription() async => current;
  @override
  Future<String?> readExternalId() async => externalId;
  @override
  Future<void> login(String externalId) async => this.externalId = externalId;
  @override
  Future<void> logout() async => externalId = null;
  @override
  Future<bool> requestPermission() async {
    current = PushSubscriptionSnapshot(
      permissionGranted: supported,
      optedIn: supported,
    );
    return supported;
  }

  @override
  Future<void> addTag(String key, String value) async => tags[key] = value;
  @override
  Future<void> removeTag(String key) async => tags.remove(key);
  @override
  Future<void> clearNotifications() async {}
  @override
  void dispose() {}
}
