import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

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

  bool _isInitialized = false;
  bool _webPushSupported = false;
  String? _webSubscriptionId;
  String? _webPushToken;

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
        await _refreshWebSubscription();
        debugPrint(
          'OneSignal web initialized: supported=$_webPushSupported, subscription=$subscriptionId',
        );
      } catch (e) {
        debugPrint('OneSignal web initialization error: $e');
      }

      _isInitialized = true;
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
        debugPrint(
          'OneSignal web external id ${synced ? 'set' : 'skipped'}: $externalId',
        );
        return synced;
      }

      await OneSignal.login(externalId);
      debugPrint('OneSignal external id set: $externalId');
      return true;
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
      await OneSignalWebBridge.logout();
      _webSubscriptionId = null;
      _webPushToken = null;
      return;
    }

    if (!_isMobilePushSupported) return;
    await OneSignal.logout();
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
  }

  String _topicTag(String topic) => 'notification_$topic';
}
