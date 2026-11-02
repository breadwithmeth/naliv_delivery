import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'onesignal_web_bridge_stub.dart'
    if (dart.library.js_interop) 'onesignal_web_bridge_web.dart';
import 'push_provider.dart';

class OneSignalPushProvider implements PushProvider {
  static const _androidAppId = '3da3fda3-1598-4617-970f-62621f3263ee';
  static const _iosAppId = 'f9a3bf44-4a96-4859-99a9-37aa2b579577';
  bool _disposed = false;
  bool _listening = false;
  String? _oneSignalId;
  VoidCallback? _onChange;
  void Function(Map<String, dynamic>, bool)? _onNotification;
  OnPushSubscriptionChangeObserver? _subscriptionObserver;
  OnNotificationPermissionChangeObserver? _permissionObserver;
  OnUserChangeObserver? _userObserver;
  OnNotificationClickListener? _clickListener;
  OnNotificationWillDisplayListener? _foregroundListener;
  PushSubscriptionSnapshot _webSnapshot = const PushSubscriptionSnapshot();

  @override
  bool get isWeb => kIsWeb;
  bool get _mobile =>
      !isWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  @override
  bool get supported => isWeb || _mobile;
  @override
  String get deviceType => isWeb ? 'web' : defaultTargetPlatform.name;
  @override
  PushSubscriptionSnapshot get current => isWeb
      ? _webSnapshot
      : !_mobile
          ? const PushSubscriptionSnapshot()
          : PushSubscriptionSnapshot(
              subscriptionId: OneSignal.User.pushSubscription.id,
              pushToken: OneSignal.User.pushSubscription.token,
              oneSignalId: _oneSignalId,
              permissionGranted: OneSignal.Notifications.permission,
              optedIn: OneSignal.User.pushSubscription.optedIn ?? false,
            );

  @override
  Future<void> initialize({
    required VoidCallback onChange,
    required void Function(Map<String, dynamic>, bool) onNotification,
  }) async {
    if (_disposed) throw StateError('Push provider is disposed');
    _onChange = onChange;
    _onNotification = onNotification;
    if (!supported) return;
    if (isWeb) {
      if (!await OneSignalWebBridge.initialize()) {
        throw StateError('Web push initialization unavailable');
      }
      if (_disposed) return;
      final changed = await OneSignalWebBridge.setChangeHandler(() {
        if (!_disposed) _onChange?.call();
      });
      final notifications = await OneSignalWebBridge.setNotificationHandler(
        (data, clicked) {
          if (!_disposed) _onNotification?.call(data, clicked);
        },
      );
      if (!changed || !notifications) {
        throw StateError('Web push listeners unavailable');
      }
      return;
    }
    if (kDebugMode) await OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    await OneSignal.initialize(defaultTargetPlatform == TargetPlatform.iOS
        ? _iosAppId
        : _androidAppId);
    await OneSignal.User.setLanguage('ru');
    if (_disposed || _listening) return;
    _clickListener = (event) {
      _onNotification?.call(
          event.notification.additionalData ?? <String, dynamic>{}, true);
    };
    _foregroundListener = (event) {
      _onNotification?.call(
          event.notification.additionalData ?? <String, dynamic>{}, false);
    };
    _subscriptionObserver = (_) => _onChange?.call();
    _permissionObserver = (_) => _onChange?.call();
    _userObserver = (state) {
      _oneSignalId = state.current.onesignalId;
      _onChange?.call();
    };
    OneSignal.Notifications.addClickListener(_clickListener!);
    OneSignal.Notifications.addForegroundWillDisplayListener(
        _foregroundListener!);
    OneSignal.User.pushSubscription.addObserver(_subscriptionObserver!);
    OneSignal.Notifications.addPermissionObserver(_permissionObserver!);
    OneSignal.User.addObserver(_userObserver!);
    _listening = true;
  }

  @override
  Future<PushSubscriptionSnapshot> readSubscription() async {
    if (isWeb) {
      final values = await Future.wait<Object?>([
        OneSignalWebBridge.getSubscriptionId(),
        OneSignalWebBridge.getPushToken(),
        OneSignalWebBridge.getOneSignalId(),
        OneSignalWebBridge.getPermissionGranted(),
        OneSignalWebBridge.getOptedIn(),
      ]);
      _webSnapshot = PushSubscriptionSnapshot(
        subscriptionId: values[0] as String?,
        pushToken: values[1] as String?,
        oneSignalId: values[2] as String?,
        permissionGranted: values[3] == true,
        optedIn: values[4] == true,
      );
    }
    return current;
  }

  @override
  Future<void> login(String externalId) async {
    if (isWeb) {
      if (!await OneSignalWebBridge.login(externalId)) {
        throw StateError('Web push login unavailable');
      }
    } else if (_mobile) {
      await OneSignal.login(externalId);
    }
  }

  @override
  Future<void> logout() async {
    if (isWeb) {
      if (!await OneSignalWebBridge.logout()) {
        throw StateError('Web push logout unavailable');
      }
    } else if (_mobile) {
      await OneSignal.logout();
    }
    _oneSignalId = null;
  }

  @override
  Future<bool> requestPermission() async {
    if (isWeb) return OneSignalWebBridge.requestPermission();
    if (!_mobile) return false;
    final granted = await OneSignal.Notifications.requestPermission(false);
    if (granted) await OneSignal.User.pushSubscription.optIn();
    return granted;
  }

  @override
  Future<void> addTag(String key, String value) async {
    if (isWeb) {
      if (!await OneSignalWebBridge.addTag(key, value)) {
        throw StateError('Web push tag unavailable');
      }
    } else if (_mobile) {
      await OneSignal.User.addTagWithKey(key, value);
    }
  }

  @override
  Future<void> removeTag(String key) async {
    if (isWeb) {
      if (!await OneSignalWebBridge.removeTag(key)) {
        throw StateError('Web push tag unavailable');
      }
    } else if (_mobile) {
      await OneSignal.User.removeTag(key);
    }
  }

  @override
  Future<void> clearNotifications() async {
    if (_mobile) await OneSignal.Notifications.clearAll();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _onChange = null;
    _onNotification = null;
    if (!_listening) return;
    OneSignal.Notifications.removeClickListener(_clickListener!);
    OneSignal.Notifications.removeForegroundWillDisplayListener(
        _foregroundListener!);
    OneSignal.User.pushSubscription.removeObserver(_subscriptionObserver!);
    OneSignal.Notifications.removePermissionObserver(_permissionObserver!);
    OneSignal.User.removeObserver(_userObserver!);
    _listening = false;
  }
}
