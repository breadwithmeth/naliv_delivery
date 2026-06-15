import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:naliv_delivery/utils/app_navigator.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'onesignal_web_bridge_stub.dart'
    if (dart.library.js_interop) 'onesignal_web_bridge_web.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;
  NotificationService._internal();

  static const String _oneSignalAndroidAppId =
      '3da3fda3-1598-4617-970f-62621f3263ee';
  static const String _oneSignalIOSAppId =
      'f9a3bf44-4a96-4859-99a9-37aa2b579577';
  static const String _deviceIdKey = 'onesignal_device_id';

  bool _isInitialized = false;
  bool _webPushSupported = false;
  String? _webSubscriptionId;
  String? _webPushToken;
  String? _webOneSignalId;
  String? _mobileOneSignalId;
  OnPushSubscriptionChangeObserver? _pushSubscriptionObserver;
  OnNotificationPermissionChangeObserver? _permissionObserver;
  OnUserChangeObserver? _userObserver;

  bool get _isWeb => kIsWeb;
  bool get _isAndroid =>
      !_isWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _isIOS => !_isWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get _isMobilePushSupported => _isAndroid || _isIOS;
  String get _mobileOneSignalAppId =>
      _isIOS ? _oneSignalIOSAppId : _oneSignalAndroidAppId;

  bool get isWebVapidKeyConfigured => _isWeb;

  String? get oneSignalId => _isWeb
      ? _webSubscriptionId
      : _isMobilePushSupported
          ? OneSignal.User.pushSubscription.id
          : null;

  String? get pushToken => _isWeb
      ? _webPushToken
      : _isMobilePushSupported
          ? OneSignal.User.pushSubscription.token
          : null;

  String? get subscriptionId => oneSignalId;

  Future<void> initialize() async {
    if (_isInitialized) return;

    if (_isWeb) {
      try {
        _webPushSupported = await OneSignalWebBridge.initialize();
        await OneSignalWebBridge.setChangeHandler(() {
          unawaited(syncSubscriptionWithBackend());
        });
        await _refreshWebSubscription();
        debugPrint(
          'OneSignal web initialized: supported=$_webPushSupported, subscription=$subscriptionId',
        );
      } catch (e) {
        debugPrint('OneSignal web initialization error: $e');
      }

      _isInitialized = true;
      unawaited(syncSubscriptionWithBackend(ensureInitialized: false));
      return;
    }

    if (!_isMobilePushSupported) {
      debugPrint('OneSignal mobile push is not supported on this platform');
      _isInitialized = true;
      return;
    }

    try {
      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      }

      await OneSignal.initialize(_mobileOneSignalAppId);
      await OneSignal.User.setLanguage('ru');
      _setupEventHandlers();

      _isInitialized = true;
      debugPrint('OneSignal initialized: appId=$_mobileOneSignalAppId');
      unawaited(syncSubscriptionWithBackend(ensureInitialized: false));
    } catch (e) {
      debugPrint('OneSignal initialization error: $e');
    }
  }

  Future<bool> enablePushNotifications() async {
    if (_isWeb) {
      await initialize();

      try {
        final granted = await OneSignalWebBridge.requestPermission();
        _webPushSupported = granted || _webPushSupported;
        await _refreshWebSubscription();
        unawaited(syncSubscriptionWithBackend());
        debugPrint(
          'OneSignal web permission: $granted, subscription: $subscriptionId',
        );
        return granted;
      } catch (e) {
        debugPrint('OneSignal web permission request error: $e');
        return false;
      }
    }

    if (!_isMobilePushSupported) {
      debugPrint('OneSignal mobile push is not supported on this platform');
      return false;
    }

    await initialize();

    try {
      final granted = await OneSignal.Notifications.requestPermission(false);
      if (granted) {
        await OneSignal.User.pushSubscription.optIn();
      }
      unawaited(syncSubscriptionWithBackend());
      debugPrint(
        'OneSignal permission: $granted, subscription: $subscriptionId',
      );
      return granted;
    } catch (e) {
      debugPrint('OneSignal permission request error: $e');
      return false;
    }
  }

  Future<bool> syncTokenWithServerIfNeeded() async {
    if (!_isWeb && !_isMobilePushSupported) {
      debugPrint('OneSignal push is not supported on this platform');
      return false;
    }

    await initialize();

    final externalId = await _resolveExternalId();
    if (externalId == null || externalId.isEmpty) {
      debugPrint('OneSignal external id skipped: user is not authenticated');
      return false;
    }

    try {
      if (_isWeb) {
        final synced = await OneSignalWebBridge.login(externalId);
        await _refreshWebSubscription();
        final backendSynced = await syncSubscriptionWithBackend(
          externalIdOverride: externalId,
        );
        debugPrint(
          'OneSignal web external id ${synced ? 'set' : 'skipped'}: $externalId',
        );
        return synced && backendSynced;
      }

      await OneSignal.login(externalId);
      final backendSynced = await syncSubscriptionWithBackend(
        externalIdOverride: externalId,
      );
      debugPrint('OneSignal external id set: $externalId');
      return backendSynced;
    } catch (e) {
      debugPrint('OneSignal external id error: $e');
      return false;
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    await initialize();

    if (_isWeb) {
      await OneSignalWebBridge.addTag(_topicTag(topic), 'true');
      return;
    }

    if (!_isMobilePushSupported) return;
    await OneSignal.User.addTagWithKey(_topicTag(topic), 'true');
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await initialize();

    if (_isWeb) {
      await OneSignalWebBridge.removeTag(_topicTag(topic));
      return;
    }

    if (!_isMobilePushSupported) return;
    await OneSignal.User.removeTag(_topicTag(topic));
  }

  Future<void> clearAllNotifications() async {
    if (!_isMobilePushSupported) return;
    await initialize();
    await OneSignal.Notifications.clearAll();
  }

  Future<int> getBadgeCount() async {
    return 0;
  }

  Future<void> setBadgeCount(int count) async {
    await initialize();

    if (_isWeb) {
      await OneSignalWebBridge.addTag('badge_count', count.toString());
      return;
    }

    if (!_isMobilePushSupported) return;
    await OneSignal.User.addTagWithKey('badge_count', count.toString());
  }

  Future<void> logoutUser() async {
    await initialize();

    if (_isWeb) {
      await _refreshWebSubscription();
    }
    final currentSubscriptionId = subscriptionId;
    if (currentSubscriptionId != null && currentSubscriptionId.isNotEmpty) {
      await ApiService.deleteOneSignalSubscription(currentSubscriptionId);
    }

    if (_isWeb) {
      await OneSignalWebBridge.logout();
      _webSubscriptionId = null;
      _webPushToken = null;
      _webOneSignalId = null;
      return;
    }

    if (!_isMobilePushSupported) return;
    await OneSignal.logout();
    _mobileOneSignalId = null;
  }

  Future<String?> getCurrentSubscriptionId() async {
    await initialize();
    if (_isWeb) {
      await _refreshWebSubscription();
    }
    return subscriptionId;
  }

  void _setupEventHandlers() {
    OneSignal.Notifications.addClickListener((event) {
      _handleNotificationData(
        event.notification.additionalData ?? <String, dynamic>{},
      );
    });

    _pushSubscriptionObserver ??= (_) {
      unawaited(syncSubscriptionWithBackend());
    };
    OneSignal.User.pushSubscription.addObserver(_pushSubscriptionObserver!);

    _permissionObserver ??= (_) {
      unawaited(syncSubscriptionWithBackend());
    };
    OneSignal.Notifications.addPermissionObserver(_permissionObserver!);

    _userObserver ??= (state) {
      _mobileOneSignalId = state.current.onesignalId;
      unawaited(syncSubscriptionWithBackend());
    };
    OneSignal.User.addObserver(_userObserver!);
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    final orderId = data['order_id']?.toString();
    final businessId = data['business_id']?.toString();

    debugPrint(
      'OneSignal notification: type=$type, order=$orderId, business=$businessId',
    );

    switch (type) {
      case 'order_status_change':
        _navigateToOrder(orderId);
        break;
      case 'promotion':
        _navigateToPromotions(businessId);
        break;
      case 'delivery_update':
        _navigateToDeliveryTracking(orderId);
        break;
      default:
        _navigateToHome();
        break;
    }
  }

  void _navigateToOrder(String? orderId) {
    if (orderId != null && orderId.isNotEmpty) {
      AppNavigator.goToHomeTab(4);
    }
  }

  void _navigateToPromotions(String? businessId) {
    if (businessId != null && businessId.isNotEmpty) {
      AppNavigator.goToHomeTab(0);
    }
  }

  void _navigateToDeliveryTracking(String? orderId) {
    if (orderId != null && orderId.isNotEmpty) {
      AppNavigator.goToHomeTab(4);
    }
  }

  void _navigateToHome() {
    AppNavigator.goToHomeTab(0);
  }

  Future<String?> _resolveExternalId() async {
    return ApiService.getCurrentUserExternalId();
  }

  Future<void> _refreshWebSubscription() async {
    if (!_isWeb) return;
    _webSubscriptionId = await OneSignalWebBridge.getSubscriptionId();
    _webPushToken = await OneSignalWebBridge.getPushToken();
    _webOneSignalId = await OneSignalWebBridge.getOneSignalId();
  }

  Future<bool> syncSubscriptionWithBackend({
    String? externalIdOverride,
    bool ensureInitialized = true,
  }) async {
    if (!_isWeb && !_isMobilePushSupported) {
      return false;
    }

    if (ensureInitialized) {
      await initialize();
    }

    if (_isWeb) {
      await _refreshWebSubscription();
    }

    final currentSubscriptionId = subscriptionId;
    if (currentSubscriptionId == null || currentSubscriptionId.isEmpty) {
      debugPrint('OneSignal backend sync skipped: subscription id is empty');
      return false;
    }

    final externalId = externalIdOverride ?? await _resolveExternalId();
    final payload = <String, dynamic>{
      'subscriptionId': currentSubscriptionId,
      'onesignalId': _isWeb ? _webOneSignalId : _mobileOneSignalId,
      'externalId': externalId,
      'deviceId': await _getStableDeviceId(),
      'deviceType': _deviceType,
      'permissionGranted': await _permissionGranted(),
      'optedIn': await _optedIn(),
    };

    final synced = await ApiService.upsertOneSignalSubscription(payload);
    debugPrint(
      'OneSignal backend sync ${synced ? 'completed' : 'failed'}: subscription=$currentSubscriptionId',
    );
    return synced;
  }

  Future<String> _getStableDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final generated = _generateUuidV4();
    await prefs.setString(_deviceIdKey, generated);
    return generated;
  }

  String _generateUuidV4() {
    final random = _secureRandom();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return '${value.substring(0, 8)}-'
        '${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-'
        '${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }

  Random _secureRandom() {
    try {
      return Random.secure();
    } catch (_) {
      return Random();
    }
  }

  String get _deviceType {
    if (_isWeb) return 'web';
    if (_isIOS) return 'ios';
    if (_isAndroid) return 'android';
    return defaultTargetPlatform.name;
  }

  Future<bool> _permissionGranted() async {
    if (_isWeb) {
      return OneSignalWebBridge.getPermissionGranted();
    }
    if (_isMobilePushSupported) {
      return OneSignal.Notifications.permission;
    }
    return false;
  }

  Future<bool> _optedIn() async {
    if (_isWeb) {
      return OneSignalWebBridge.getOptedIn();
    }
    if (_isMobilePushSupported) {
      return OneSignal.User.pushSubscription.optedIn ?? false;
    }
    return false;
  }

  String _topicTag(String topic) => 'notification_$topic';
}
