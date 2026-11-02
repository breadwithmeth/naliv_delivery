import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/services/chat_api_service.dart';
import 'package:naliv_delivery/services/notification_service.dart';

@immutable
class AuthSession {
  const AuthSession._(this.token, this.revision);

  final String token;
  final int revision;
  bool get isCurrent =>
      revision == AuthService.credentialRevision &&
      !AuthService.isEndingSession;
}

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _tokenExpiryKey = 'token_expiry';
  static final ValueNotifier<int> sessionRevision = ValueNotifier(0);
  static String? _currentIdentity;
  static bool _endingSession = false;
  static int _identityVersion = 0;
  static int _credentialRevision = 0;
  static Future<void>? _clearing;
  static Future<void>? _credentialWrites;
  static bool _credentialPublicationPending = false;
  static String? _locallyRevokedToken;
  static bool _credentialStorageUnverified = false;

  static Future<void> _serializeCredentialWrite(
      Future<void> Function() action) {
    final previous = _credentialWrites;
    final operation = previous == null
        ? Future<void>.sync(action)
        : previous.then((_) => action());
    late final Future<void> tail;
    void release() {
      if (identical(_credentialWrites, tail)) _credentialWrites = null;
    }

    tail = operation.then<void>((_) => release(),
        onError: (Object _, StackTrace __) => release());
    _credentialWrites = tail;
    return operation;
  }

  static int get credentialRevision => _credentialRevision;

  static Future<AuthSession?> captureSession() async {
    if (_endingSession ||
        _credentialPublicationPending ||
        _credentialStorageUnverified) {
      return null;
    }
    final revision = _credentialRevision;
    final token = await ApiService.getAuthToken();
    if (_endingSession ||
        _credentialPublicationPending ||
        _credentialStorageUnverified ||
        revision != _credentialRevision ||
        token == null ||
        token.isEmpty ||
        token == _locallyRevokedToken) {
      return null;
    }
    return AuthSession._(token, revision);
  }

  static String? get currentIdentity => _currentIdentity;
  static bool get isEndingSession => _endingSession;

  static Future<bool> isTokenExpired() async {
    try {
      return await ApiService.getFullInfo() == null;
    } catch (e) {
      debugPrint('Error checking token validity: $e');
      return true;
    }
  }

  static Future<String?> getToken() async {
    if (_endingSession ||
        _credentialPublicationPending ||
        _credentialStorageUnverified) {
      return null;
    }
    final revision = _credentialRevision;
    final prefs = await SharedPreferences.getInstance();
    if (_endingSession ||
        _credentialPublicationPending ||
        _credentialStorageUnverified ||
        revision != _credentialRevision) {
      return null;
    }
    final token = prefs.getString(_tokenKey);
    return token == _locallyRevokedToken ? null : token;
  }

  // ApiService's token persistence also calls this hook. Private state is hidden
  // synchronously, before any delayed read or send can complete for an old user.
  static Future<void> notifySessionChanged() async {
    _credentialRevision++;
    _identityVersion++;
    _currentIdentity = null;
    ChatApiService.suspendAllSessions();
    sessionRevision.value++;
  }

  static Future<void> bindAuthenticatedIdentity(String? externalId) async {
    final normalized = externalId?.trim();
    final identity =
        normalized == null || normalized.isEmpty ? null : normalized;
    if (_endingSession && identity != null) return;
    if (_currentIdentity == identity) return;
    final version = ++_identityVersion;
    _currentIdentity = identity;
    Future<void>? retained;
    if (identity == null) {
      // Expired authentication hides live history immediately. The labelled
      // capability is usable again only after the same identity is verified;
      // explicit logout below destroys it, and another account discards it.
      ChatApiService.suspendAllSessions();
    } else {
      retained = ChatApiService.retainSessionsForIdentity(
        identity,
        isCurrent: () => version == _identityVersion,
      );
    }
    sessionRevision.value++;
    if (retained != null) await retained;
  }

  static Future<String?> refreshIdentity({
    Map<String, dynamic>? verifiedInfo,
  }) async {
    if (_endingSession) return null;
    final version = _identityVersion;
    final token = await ApiService.getAuthToken();
    final identity = token == null
        ? null
        : await ApiService.getCurrentUserExternalId(verifiedInfo: verifiedInfo);
    if (_endingSession ||
        version != _identityVersion ||
        token != await ApiService.getAuthToken()) {
      return _currentIdentity;
    }
    await bindAuthenticatedIdentity(identity);
    return identity;
  }

  static Future<void> saveToken(String token) {
    final revision = _credentialRevision;
    return _serializeCredentialWrite(() => _saveToken(token, revision));
  }

  static Future<void> _saveToken(String token, int revision) async {
    if (_endingSession || revision != _credentialRevision) {
      throw StateError('Authentication changed before credentials were saved');
    }
    final prefs = await SharedPreferences.getInstance();
    if (_endingSession || revision != _credentialRevision) {
      throw StateError('Authentication changed before credentials were saved');
    }
    DateTime? expiry;
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = jsonDecode(
            utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
        final exp = payload is Map ? payload['exp'] : null;
        if (exp is num) {
          expiry = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000,
              isUtc: true);
        }
      }
    } catch (error) {
      debugPrint('Error parsing token: $error');
    }
    // The preferences cache is optimistic. Nothing may use its new token until
    // both durable writes acknowledge this publication.
    _credentialPublicationPending = true;
    var publication = _credentialRevision;
    try {
      final tokenWrite =
          Future<bool>.sync(() => prefs.setString(_tokenKey, token));
      final expiryWrite = Future<bool>.sync(() => expiry == null
          ? prefs.containsKey(_tokenExpiryKey)
              ? prefs.remove(_tokenExpiryKey)
              : true
          : prefs.setString(_tokenExpiryKey, expiry.toIso8601String()));
      unawaited(notifySessionChanged());
      publication = _credentialRevision;
      List<bool>? saved;
      try {
        saved = await Future.wait([tokenWrite, expiryWrite]);
      } catch (error) {
        debugPrint('Authentication storage failure: $error');
      }
      if (_endingSession || publication != _credentialRevision) {
        throw StateError('Authentication changed while credentials were saved');
      }
      if (saved == null || saved.any((value) => !value)) {
        final removed = await _removeStoredCredentials(prefs);
        throw StateError(removed
            ? 'Could not save authentication credentials'
            : 'Could not save or remove local authentication credentials');
      }
      _locallyRevokedToken = null;
      _credentialStorageUnverified = false;
    } finally {
      _credentialPublicationPending = false;
      if (!_endingSession && publication == _credentialRevision) {
        // Credential readiness is a new publication, not an identity binding.
        // Consumers that rejected the pending token can now capture it safely.
        await notifySessionChanged();
      }
    }
  }

  static Future<void> clearToken() {
    final pending = _clearing;
    if (pending != null) return pending;
    _endingSession = true;
    _credentialRevision++;
    _identityVersion++;
    _currentIdentity = null;
    ChatApiService.suspendAllSessions();
    sessionRevision.value++;
    final operation = _serializeCredentialWrite(_clearLocalCredentials);
    _clearing = operation;
    return operation;
  }

  static Future<bool> _removeStoredCredentials(SharedPreferences prefs) async {
    final oldToken = prefs.getString(_tokenKey);
    _locallyRevokedToken = oldToken;
    final hadToken = prefs.containsKey(_tokenKey);
    final hadExpiry = prefs.containsKey(_tokenExpiryKey);
    List<bool>? removed;
    try {
      removed = await Future.wait([
        prefs.remove(_tokenKey),
        prefs.remove(_tokenExpiryKey),
      ]);
    } catch (error) {
      debugPrint('Authentication removal failure: $error');
    }
    try {
      await prefs.reload();
      final retained = prefs.getString(_tokenKey);
      _locallyRevokedToken = retained ?? oldToken;
      _credentialStorageUnverified = false;
      return removed != null &&
          (!hadToken || removed[0]) &&
          (!hadExpiry || removed[1]) &&
          !prefs.containsKey(_tokenKey) &&
          !prefs.containsKey(_tokenExpiryKey);
    } catch (error) {
      _credentialStorageUnverified = true;
      debugPrint('Could not verify local credential removal: $error');
      return false;
    }
  }

  static Future<void> _clearLocalCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final oldToken = prefs.getString(_tokenKey);
      // Queue captured-account cleanup, but never wait for optional transport.
      unawaited(NotificationService.instance
          .logoutUser(authToken: oldToken)
          .catchError((Object error) {
        debugPrint('Could not unregister push subscription: $error');
      }));
      // Reloading the credentials replaces the entire preferences cache. Finish
      // that verification before removing chat state, or a parallel reload can
      // resurrect the capability in memory after its durable removal.
      final credentialsRemoved = await _removeStoredCredentials(prefs);
      await ChatApiService.clearPrivateSessions();
      if (!credentialsRemoved) {
        throw StateError('Could not remove local authentication credentials');
      }
    } finally {
      _endingSession = false;
      _clearing = null;
      sessionRevision.value++;
    }
  }
}
