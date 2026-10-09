import 'dart:async';
import 'dart:math';


import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:naliv_delivery/utils/app_navigator.dart';
import 'package:naliv_delivery/utils/api.dart';
import '../core/destinations.dart';
import '../pages/help_chat_page.dart';
import '../pages/login_page.dart';
import 'auth_service.dart';
import 'chat_api_service.dart';
import 'onesignal_web_bridge_stub.dart'
    if (dart.library.js_interop) 'onesignal_web_bridge_web.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;
  NotificationService._internal()
      : _navigatorKey = AppNavigator.key,
        _resolveIdentity = AuthService.refreshIdentity,
        _chatServiceFactory = ChatApiService.new,
        _authenticate = null;

  @visibleForTesting
  NotificationService.forTesting({
    required GlobalKey<NavigatorState> navigatorKey,
    required Future<String?> Function() resolveIdentity,
    required ChatApiService Function() chatServiceFactory,
    Future<bool> Function(NavigatorState)? authenticate,
  })  : _navigatorKey = navigatorKey,
        _resolveIdentity = resolveIdentity,
        _chatServiceFactory = chatServiceFactory,
        _authenticate = authenticate;

  final GlobalKey<NavigatorState> _navigatorKey;
  final Future<String?> Function() _resolveIdentity;
  final ChatApiService Function() _chatServiceFactory;
  final Future<bool> Function(NavigatorState)? _authenticate;
  final _supportUpdates =
      StreamController<SupportNotificationTarget>.broadcast();
  final _supportPages = <bool Function(String, String)>[];
  final _handledSupportClicks = <String>{};
  SupportNotificationTarget? _pendingSupport;
  AppDestination? _pendingDestination;
  Future<void> Function(AppDestination)? _openDestination;
  bool _navigationReady = false;
  bool _handlingClick = false;

  Stream<SupportNotificationTarget> get supportUpdates => _supportUpdates.stream;

  VoidCallback registerSupportPage(
      bool Function(String identity, String sessionId) isVisible) {
    _supportPages.add(isVisible);
    return () => _supportPages.remove(isVisible);
  }

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
        await OneSignalWebBridge.setNotificationHandler((data, clicked) {
          unawaited(handleNotificationData(data, clicked: clicked));
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
      if (!await OneSignalWebBridge.addTag(_topicTag(topic), 'true')) {
        throw StateError('Could not subscribe to notification topic');
      }
      return;
    }

    if (!_isMobilePushSupported) return;
    await OneSignal.User.addTagWithKey(_topicTag(topic), 'true');
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await initialize();

    if (_isWeb) {
      if (!await OneSignalWebBridge.removeTag(_topicTag(topic))) {
        throw StateError('Could not unsubscribe from notification topic');
      }
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
    _pendingSupport = null;
    _pendingDestination = null;
    _handledSupportClicks.clear();
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
      unawaited(handleNotificationData(
        event.notification.additionalData ?? <String, dynamic>{},
      ));
    });
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      unawaited(handleNotificationData(
        event.notification.additionalData ?? <String, dynamic>{},
        clicked: false,
      ));
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

  // Only route metadata is used. Message contents and credentials always come
  // from the history API using an already-owned support session.
  Future<void> handleNotificationData(
    Map<String, dynamic> data, {
    bool clicked = true,
  }) async {
    final target = SupportNotificationTarget.tryParse(data);
    if (target != null) {
      if (!clicked) {
        final identity = await _resolveIdentity();
        if (identity != null &&
            target.acceptsIdentity(identity) &&
            await ChatApiService.ownsSession(target.sessionId, identity)) {
          _supportUpdates.add(target);
        }
        return;
      }
      _pendingSupport = target;
      if (_navigationReady) await resumePendingNavigation();
      return;
    }
    if (!clicked) return;
    final type = data['type'];
    if ((type == 'order_status_change' || type == 'delivery_update') &&
        SupportNotificationTarget.identifier(data['order_id']) != null) {
      _pendingDestination = AppDestination.orders;
      if (_navigationReady) await resumePendingNavigation();
    }
    // Unknown payloads must not remove a checkout route or reset a cart.
  }

  Future<void> resumePendingNavigation({
    Future<void> Function(AppDestination)? openDestination,
  }) async {
    if (openDestination != null) _openDestination = openDestination;
    _navigationReady = true;
    final navigator = _navigatorKey.currentState;
    if (_handlingClick || navigator == null || !navigator.mounted) return;
    final target = _pendingSupport;
    if (target == null) {
      final destination = _pendingDestination;
      final open = _openDestination;
      if (destination != null && open != null) {
        _pendingDestination = null;
        await open(destination);
      }
      return;
    }
    _pendingSupport = null;
    _handlingClick = true;
    try {
      var identity = await _resolveIdentity();
      if (identity == null) {
        final authenticated = _authenticate == null
            ? await navigator.push<bool>(MaterialPageRoute(
                builder: (_) => const LoginPage(
                  startWithPhoneForm: true,
                  completionMode: LoginCompletionMode.returnAuthenticated,
                ),
              ))
            : await _authenticate!(navigator);
        if (authenticated != true || !navigator.mounted) return;
        identity = await _resolveIdentity();
      }
      if (identity == null || !navigator.mounted) return;
      final revision = AuthService.sessionRevision.value;
      if (!target.acceptsIdentity(identity) ||
          !await ChatApiService.ownsSession(target.sessionId, identity)) {
        final context = _navigatorKey.currentContext;
        if (context != null && context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
            content: Text('Это обращение недоступно в текущем аккаунте.'),
          ));
        }
        return;
      }
      if (revision != AuthService.sessionRevision.value) return;
      final clickKey = '$identity:${target.sessionId}:${target.messageId}';
      if (!_handledSupportClicks.add(clickKey)) return;
      _supportUpdates.add(target);
      if (_supportPages.any((page) => page(identity!, target.sessionId))) return;
      unawaited(navigator.push<void>(MaterialPageRoute(
        settings: RouteSettings(name: '/support/${target.sessionId}'),
        builder: (_) => HelpChatPage(
          entryPoint: 'notification',
          sessionId: target.sessionId,
          messageId: target.messageId,
          chatService: _chatServiceFactory(),
          notificationService: this,
          resolveIdentity: _resolveIdentity,
        ),
      )));
    } finally {
      _handlingClick = false;
      if (_pendingSupport != null) unawaited(resumePendingNavigation());
    }
  }

  Future<String?> _resolveExternalId() async {
    return AuthService.refreshIdentity();
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

  Future<PushPermissionState> getPermissionState() async {
    await initialize();
    return PushPermissionState(
      supported: _isMobilePushSupported || (_isWeb && _webPushSupported),
      permissionGranted: await _permissionGranted(),
      optedIn: await _optedIn(),
    );
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

class PushPermissionState {
  const PushPermissionState({
    required this.supported,
    required this.permissionGranted,
    required this.optedIn,
  });

  final bool supported;
  final bool permissionGranted;
  final bool optedIn;
}

// These are client-side route fields, not proof of a deployed support publisher.
// The provider must send the same session/message IDs as the widget history API;
// no session token is accepted from a notification.
class SupportNotificationTarget {
  const SupportNotificationTarget({
    required this.sessionId,
    required this.messageId,
    this.externalId,
  });

  final String sessionId;
  final int messageId;
  final String? externalId;

  static String? identifier(Object? value) {
    if (value is! String && value is! int) return null;
    final id = value.toString().trim();
    return id.isEmpty || id == 'null' ? null : id;
  }

  static SupportNotificationTarget? tryParse(Map<String, dynamic> data) {
    if (data['type'] != 'support_message' && data['type'] != 'chat_message') {
      return null;
    }
    if (data.keys.any((key) => key.toLowerCase().contains('token'))) return null;
    final session = identifier(data['session_id'] ?? data['sessionId']);
    final rawMessage = identifier(data['message_id'] ?? data['messageId']);
    final message = rawMessage == null ? null : int.tryParse(rawMessage);
    if (session == null || message == null || message <= 0) return null;
    return SupportNotificationTarget(
      sessionId: session,
      messageId: message,
      externalId: identifier(data['external_id'] ?? data['externalId']),
    );
  }

  bool acceptsIdentity(String identity) =>
      externalId == null || externalId == identity;
}
