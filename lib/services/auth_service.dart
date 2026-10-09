import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/services/chat_api_service.dart';
import 'package:naliv_delivery/services/notification_service.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _tokenExpiryKey = 'token_expiry';
  static final ValueNotifier<int> sessionRevision = ValueNotifier(0);
  static String? _currentIdentity;
  static bool _endingSession = false;
  static int _identityVersion = 0;

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
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // ApiService's token persistence also calls this hook. Private state is hidden
  // synchronously, before any delayed read or send can complete for an old user.
  static Future<void> notifySessionChanged() async {
    _identityVersion++;
    _currentIdentity = null;
    ChatApiService.suspendAllSessions();
    sessionRevision.value++;
  }

  static Future<void> bindAuthenticatedIdentity(String? externalId) async {
    final normalized = externalId?.trim();
    final identity = normalized == null || normalized.isEmpty ? null : normalized;
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
    if (_endingSession || version != _identityVersion ||
        token != await ApiService.getAuthToken()) {
      return _currentIdentity;
    }
    await bindAuthenticatedIdentity(identity);
    return identity;
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(_tokenKey);
    DateTime? expiry;
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = jsonDecode(
            utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
        final exp = payload is Map ? payload['exp'] : null;
        if (exp is num) {
          expiry = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
        }
      }
    } catch (e) {
      debugPrint('Error parsing token: $e');
    }
    await prefs.setString(_tokenKey, token);
    if (expiry == null) {
      await prefs.remove(_tokenExpiryKey);
    } else {
      await prefs.setString(_tokenExpiryKey, expiry.toIso8601String());
    }
    if (previous != token) await notifySessionChanged();
  }

  static Future<void> clearToken() async {
    _endingSession = true;
    _identityVersion++;
    _currentIdentity = null;
    final cleared = ChatApiService.clearPrivateSessions();
    sessionRevision.value++;
    try {
      await cleared;
      try {
        await NotificationService.instance.logoutUser();
      } catch (error) {
        // Push deregistration must not prevent a local session from ending.
        debugPrint('Could not unregister push subscription: $error');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_tokenExpiryKey);
    } finally {
      _endingSession = false;
      sessionRevision.value++;
    }
  }
}
