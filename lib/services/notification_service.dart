import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:naliv_delivery/utils/app_navigator.dart';
import 'package:naliv_delivery/utils/api.dart';
import '../core/destinations.dart';
import '../features/notifications/notification_history.dart';
import '../pages/help_chat_page.dart';
import '../pages/login_page.dart';
import 'auth_service.dart';
import 'chat_api_service.dart';
import 'onesignal_push_provider.dart';
import 'push_provider.dart';

class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService();

  // Root composition can replace the provider without changing auth consumers.
  static VoidCallback installProvider(PushProvider provider) {
    final previous = _instance;
    final installed = NotificationService(provider: provider);
    _instance = installed;
    return () {
      if (identical(_instance, installed)) _instance = previous;
      installed.dispose();
    };
  }

  NotificationService({
    PushProvider? provider,
    GlobalKey<NavigatorState>? navigatorKey,
    Future<String?> Function()? resolveIdentity,
    ChatApiService Function()? chatServiceFactory,
    Future<bool> Function(NavigatorState)? authenticate,
  })  : _provider = provider ?? OneSignalPushProvider(),
        _navigatorKey = navigatorKey ?? AppNavigator.key,
        _resolveIdentity = resolveIdentity ?? AuthService.refreshIdentity,
        _chatServiceFactory = chatServiceFactory ?? ChatApiService.new,
        _authenticate = authenticate;

  final PushProvider _provider;
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

  Stream<SupportNotificationTarget> get supportUpdates =>
      _supportUpdates.stream;

  VoidCallback registerSupportPage(
      bool Function(String identity, String sessionId) isVisible) {
    _supportPages.add(isVisible);
    return () => _supportPages.remove(isVisible);
  }

  static const String _deviceIdKey = 'onesignal_device_id';
  static const _pushOwnerKey = 'notification_history_provider_owner_v1';
  static const _mixedPushOwners = ':mixed';
  static const _noPushOwner = ':anonymous';
  static const _recipientKeys = [
    'external_id',
    'externalId',
    'recipient_user_id',
    'recipientUserId',
  ];
  final _pendingHistory = <String, (String, HistoryNotification)>{};
  bool _isInitialized = false;
  bool _disposed = false;
  bool _observingSession = false;
  Future<void>? _initialization;
  Future<void>? _effects;
  Future<bool>? _pendingSync;
  int _pendingSyncRevision = -1;
  int _observedRevision = -1;
  AuthSession? _providerSession;
  bool _providerIdentityKnown = false;
  String? _providerBoundIdentity;
  String? _implicitHistoryOwner;

  bool get isWebVapidKeyConfigured => _provider.isWeb;
  String? get oneSignalId => _provider.current.subscriptionId;
  String? get pushToken => _provider.current.pushToken;
  String? get subscriptionId => oneSignalId;

  Future<void> initialize() => _ensureInitialized();

  Future<void> _ensureInitialized({bool synchronize = true}) {
    if (_disposed) return Future.error(StateError('Push service is disposed'));
    if (_isInitialized) return Future.value();
    final pending = _initialization;
    if (pending != null) return pending;
    if (!_observingSession) {
      _observedRevision = AuthService.credentialRevision;
      AuthService.sessionRevision.addListener(_onSessionChanged);
      _observingSession = true;
    }
    late final Future<void> operation;
    operation = Future<void>.sync(() => _initialize(synchronize: synchronize))
        .whenComplete(() {
      if (identical(_initialization, operation)) _initialization = null;
    });
    _initialization = operation;
    return operation;
  }

  Future<void> _initialize({required bool synchronize}) async {
    await _provider.initialize(
      onChange: () {
        if (!_disposed) unawaited(syncSubscriptionWithBackend());
      },
      onNotification: (event) {
        if (_disposed) return;
        unawaited(_captureHistory(event).catchError(_reportHistoryFailure));
        unawaited(handleNotificationData(event.data, clicked: event.clicked));
      },
    );
    if (_disposed) return;
    _isInitialized = true;
    if (synchronize) {
      scheduleMicrotask(() {
        if (!_disposed) unawaited(syncSubscriptionWithBackend());
      });
    }
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    Future<T> run() async {
      if (_disposed) throw StateError('Push service is disposed');
      return operation();
    }

    final previous = _effects;
    final result =
        previous == null ? Future<T>.sync(run) : previous.then((_) => run());
    late final Future<void> tail;
    void release() {
      if (identical(_effects, tail)) _effects = null;
    }

    tail = result.then<void>((_) => release(),
        onError: (Object _, StackTrace __) => release());
    _effects = tail;
    return result;
  }

  void _onSessionChanged() {
    final revision = AuthService.credentialRevision;
    if (_disposed) return;
    if (revision == _observedRevision) {
      final identity = AuthService.verifiedIdentity;
      if (identity != null && _pendingHistory.isNotEmpty) {
        for (final (recipient, notification) in _pendingHistory.values) {
          if (recipient == identity) {
            unawaited(_appendHistory(identity, notification));
          }
        }
        _pendingHistory.clear();
      }
      return;
    }
    _pendingHistory.clear();
    _implicitHistoryOwner = null;
    _observedRevision = revision;
    if (!AuthService.isEndingSession) {
      final previous = _providerSession;
      if (previous != null) {
        unawaited(_queueCleanup(previous.token));
      }
      unawaited(syncTokenWithServerIfNeeded());
    }
  }

  Future<void> _captureHistory(PushNotificationEvent event) async {
    final id = event.id?.trim();
    final title = event.title ?? '';
    final body = event.body ?? '';
    if (id == null || id.isEmpty || id.length > 128 ||
        (title.trim().isEmpty && body.trim().isEmpty) ||
        AuthService.isEndingSession) {
      return;
    }
    String? recipient;
    for (final key in _recipientKeys) {
      if (!event.data.containsKey(key)) continue;
      final value = SupportNotificationTarget.identifier(event.data[key]);
      if (value == null || (recipient != null && recipient != value)) return;
      recipient = value;
    }
    final revision = AuthService.credentialRevision;
    bool current() => !_disposed && !AuthService.isEndingSession &&
        AuthService.credentialRevision == revision;
    final notification = HistoryNotification(
      id: id,
      title: title,
      body: body,
      receivedAt: DateTime.now().toUtc(),
    );
    if (recipient != null) {
      var identity = AuthService.verifiedIdentity;
      if (identity == null && event.clicked) {
        // A click from a cold start may wait for the existing credentials to be
        // verified. Never carry its display text through login or replacement.
        final session = await AuthService.captureSession();
        if (!current() || session == null || !session.isCurrent) return;
        identity = AuthService.verifiedIdentity;
        if (identity == null) {
          if (!_pendingHistory.containsKey(id)) {
            if (_pendingHistory.length >= 16) {
              _pendingHistory.remove(_pendingHistory.keys.first);
            }
            _pendingHistory[id] = (recipient, notification);
          }
          return;
        }
      }
      if (identity == recipient) await _appendHistory(recipient, notification);
      return;
    }
    // A delayed click has no trustworthy recipient without an explicit ID.
    // Only a live delivery on a continuously single-owner push association can
    // use provider state to fill in a missing recipient.
    final identity = AuthService.verifiedIdentity;
    if (event.clicked || identity == null ||
        _implicitHistoryOwner != identity || _providerSession?.revision != revision) {
      return;
    }
    final identityRevision = AuthService.sessionRevision.value;
    final externalId = await _provider.readExternalId();
    if (!current() || externalId != identity) return;
    final prefs = await SharedPreferences.getInstance();
    await AuthService.reloadLocalPreferences(prefs);
    if (!current() || _implicitHistoryOwner != identity ||
        identityRevision != AuthService.sessionRevision.value ||
        AuthService.verifiedIdentity != identity ||
        prefs.get(_pushOwnerKey) != Uri.encodeComponent(identity)) {
      return;
    }
    await _appendHistory(identity, notification);
  }

  Future<void> _appendHistory(String identity, HistoryNotification entry) async {
    try {
      await NotificationHistory.instance.append(identity, entry);
    } catch (error) {
      _reportHistoryFailure(error);
    }
  }

  static void _reportHistoryFailure(Object _) {
    debugPrint('Local notification history capture unavailable');
  }

  Future<bool> _trackPushOwner(String? identity) async {
    try {
      final existingProviderOwner = await _provider.readExternalId();
      final prefs = await SharedPreferences.getInstance();
      await AuthService.reloadLocalPreferences(prefs);
      final previous = prefs.get(_pushOwnerKey);
      final owner = identity == null ? null : Uri.encodeComponent(identity);
      final sdkOwner = existingProviderOwner == null
          ? null
          : Uri.encodeComponent(existingProviderOwner);
      // A legacy registration has no local account lineage. In particular,
      // its previously targeted messages may arrive after a new provider login.
      final known = switch (previous) {
        null => prefs.containsKey(_deviceIdKey) ? _mixedPushOwners : _noPushOwner,
        String stored => stored,
        _ => _mixedPushOwners,
      };
      final first = known == _noPushOwner ? sdkOwner ?? owner : known;
      final next = (sdkOwner != null && sdkOwner != first) ||
              (owner != null && owner != first)
          ? _mixedPushOwners
          : first ?? _noPushOwner;
      if (previous != next && !await prefs.setString(_pushOwnerKey, next)) {
        return false;
      }
      return owner != null && owner == next;
    } catch (error) {
      _reportHistoryFailure(error);
      return false;
    }
  }

  Future<bool> enablePushNotifications() async {
    try {
      await initialize();
      final granted = await _serialize(_provider.requestPermission);
      unawaited(syncSubscriptionWithBackend());
      if (granted) unawaited(applyTopicPreferences());
      return granted;
    } catch (error) {
      debugPrint('Push permission unavailable: $error');
      return false;
    }
  }

  /// What the customer can be notified about.
  static const topics = ['orders', 'promotions', 'delivery'];

  static String topicPreferenceKey(String topic) => 'notification_topic_$topic';

  /// Like every app, every topic is on until the customer turns it off.
  static bool topicEnabled(SharedPreferences preferences, String topic) =>
      preferences.getBool(topicPreferenceKey(topic)) ?? true;

  /// Tags the device with the topics the customer has on (all, by default).
  /// Safe to repeat; failures leave the tags for the next attempt.
  Future<void> applyTopicPreferences() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      for (final topic in topics) {
        if (topicEnabled(preferences, topic)) {
          await subscribeToTopic(topic);
        } else {
          await unsubscribeFromTopic(topic);
        }
      }
    } catch (error) {
      debugPrint('Push topics unavailable: $error');
    }
  }

  Future<bool> syncTokenWithServerIfNeeded() => _requestSync().then((synced) {
        // A device that already allowed push gets the default topics too.
        if (synced) unawaited(applyTopicPreferences());
        return synced;
      });

  Future<bool> _requestSync() {
    if (_disposed || !_provider.supported || AuthService.isEndingSession) {
      return Future.value(false);
    }
    final revision = AuthService.credentialRevision;
    if (_pendingSync != null && _pendingSyncRevision == revision) {
      return _pendingSync!;
    }
    var captureFailed = false;
    final captured = AuthService.captureSession().catchError((Object error) {
      captureFailed = true;
      debugPrint('Push credential capture unavailable: $error');
      return null;
    });
    _pendingSyncRevision = revision;
    final operation = _serialize(() async {
      try {
        final session = await captured;
        bool current() =>
            !_disposed &&
            !captureFailed &&
            !AuthService.isEndingSession &&
            AuthService.credentialRevision == revision &&
            (session == null || session.isCurrent);
        if (!current()) return false;
        await _ensureInitialized(synchronize: false);
        if (!current()) return false;
        final identity =
            session == null ? null : await AuthService.refreshIdentity();
        if (!current()) return false;
        if (session != null && identity == null) return false;
        if (session == null &&
            (!_providerIdentityKnown || _providerSession != null)) {
          await _trackPushOwner(null);
          if (!current()) return false;
          await _provider.logout();
          _providerSession = null;
          _providerBoundIdentity = null;
          _implicitHistoryOwner = null;
          _providerIdentityKnown = true;
          if (!current()) return false;
        }
        if (session != null &&
            (!_providerIdentityKnown ||
                _providerSession?.revision != session.revision ||
                _providerSession?.token != session.token ||
                _providerBoundIdentity != identity)) {
          _providerIdentityKnown = false;
          _providerSession = session;
          _implicitHistoryOwner = null;
          final owner = identity!;
          final exclusive = await _trackPushOwner(owner);
          if (!current() || AuthService.currentIdentity != owner) return false;
          await _provider.login(owner);
          _providerIdentityKnown = true;
          _providerBoundIdentity = identity;
          if (!current() || AuthService.currentIdentity != identity) {
            await _provider.logout();
            _providerSession = null;
            _providerBoundIdentity = null;
            _providerIdentityKnown = true;
            return false;
          }
          _implicitHistoryOwner = exclusive ? identity : null;
        }
        final snapshot = await _provider.readSubscription();
        if (!current()) return false;
        final id = snapshot.subscriptionId;
        if (id == null || id.isEmpty) return false;
        final deviceId = await _getStableDeviceId();
        if (!current()) return false;
        final result = await ApiService.upsertOneSignalSubscription({
          'subscriptionId': id,
          'onesignalId': snapshot.oneSignalId,
          'externalId': identity,
          'deviceId': deviceId,
          'deviceType': _provider.deviceType,
          'permissionGranted': snapshot.permissionGranted,
          'optedIn': snapshot.optedIn,
        }, authToken: session?.token);
        return current() && result;
      } catch (error) {
        debugPrint('Push synchronization unavailable: $error');
        return false;
      }
    }).catchError((Object error) {
      debugPrint('Push synchronization unavailable: $error');
      return false;
    });
    _pendingSync = operation;
    unawaited(operation.then<void>((_) {
      if (identical(_pendingSync, operation)) _pendingSync = null;
    }, onError: (Object _, StackTrace __) {
      if (identical(_pendingSync, operation)) _pendingSync = null;
    }));
    return operation;
  }

  Future<void> subscribeToTopic(String topic) async {
    await initialize();
    await _serialize(() => _provider.addTag(_topicTag(topic), 'true'));
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await initialize();
    await _serialize(() => _provider.removeTag(_topicTag(topic)));
  }

  Future<void> clearAllNotifications() async {
    await initialize();
    await _serialize(_provider.clearNotifications);
  }

  Future<int> getBadgeCount() async => 0;

  Future<void> setBadgeCount(int count) async {
    await initialize();
    await _serialize(() => _provider.addTag('badge_count', count.toString()));
  }

  Future<void> logoutUser({required String? authToken}) {
    _pendingSupport = null;
    _pendingDestination = null;
    _pendingHistory.clear();
    _implicitHistoryOwner = null;
    _handledSupportClicks.clear();
    return _queueCleanup(authToken);
  }

  Future<void> _queueCleanup(String? authToken) => _serialize(() async {
        try {
          await _ensureInitialized(synchronize: false);
          final snapshot = await _provider.readSubscription();
          final id = snapshot.subscriptionId;
          if (authToken != null && id != null && id.isNotEmpty) {
            await ApiService.deleteOneSignalSubscription(id,
                authToken: authToken);
          }
          await _provider.logout();
          _providerSession = null;
          _providerBoundIdentity = null;
          _implicitHistoryOwner = null;
          _providerIdentityKnown = true;
        } catch (error) {
          debugPrint('Push cleanup unavailable: $error');
        }
      }).catchError((Object error) {
        debugPrint('Push cleanup unavailable: $error');
      });

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_observingSession) {
      AuthService.sessionRevision.removeListener(_onSessionChanged);
    }
    _provider.dispose();
    _supportPages.clear();
    _pendingSupport = null;
    _pendingDestination = null;
    _pendingHistory.clear();
    unawaited(_supportUpdates.close());
  }

  // Only route metadata is used. Message contents and credentials always come
  // from the history API using an already-owned support session.
  Future<void> handleNotificationData(
    Map<String, dynamic> data, {
    bool clicked = true,
  }) async {
    if (_disposed) return;
    final target = SupportNotificationTarget.tryParse(data);
    if (target != null) {
      if (!clicked) {
        final revision = AuthService.credentialRevision;
        final identity = await _resolveIdentity();
        if (identity != null &&
            target.acceptsIdentity(identity) &&
            await ChatApiService.ownsSession(target.sessionId, identity) &&
            !_disposed &&
            revision == AuthService.credentialRevision) {
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
    if (_disposed) return;
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
            : await _authenticate(navigator);
        if (_disposed || authenticated != true || !navigator.mounted) return;
        identity = await _resolveIdentity();
      }
      if (_disposed || identity == null || !navigator.mounted) return;
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
      if (_disposed || revision != AuthService.sessionRevision.value) return;
      final clickKey = '$identity:${target.sessionId}:${target.messageId}';
      if (!_handledSupportClicks.add(clickKey)) return;
      _supportUpdates.add(target);
      if (_supportPages.any((page) => page(identity!, target.sessionId))) {
        return;
      }
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

  Future<bool> syncSubscriptionWithBackend() => _requestSync();

  Future<String> _getStableDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final generated = _generateUuidV4();
    if (!await prefs.setString(_deviceIdKey, generated)) {
      throw StateError('Could not save push device identifier');
    }
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

  Future<PushPermissionState> getPermissionState() async {
    await initialize();
    final snapshot = await _provider.readSubscription();
    return PushPermissionState(
      supported: _provider.supported,
      permissionGranted: snapshot.permissionGranted,
      optedIn: snapshot.optedIn,
    );
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
    if (data.keys.any((key) => key.toLowerCase().contains('token'))) {
      return null;
    }
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
