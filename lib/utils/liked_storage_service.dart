import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';

class LikedStorageService {
  static final Map<String, Future<void>> _writes = {};

  // Legacy business-only keys have no verifiable account owner. Leave them
  // untouched, but never use them to color a different account's heart.
  static String _key(String identity, int businessId) =>
      'liked_items_v2_${Uri.encodeComponent(identity)}_$businessId';

  static Set<int> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return {
          for (final value in decoded)
            if (int.tryParse('$value') case final int id when id > 0) id,
        };
      }
    } catch (_) {}
    return {};
  }

  static Future<Set<int>> getLikedIds({required int businessId}) async {
    final identity = AuthService.currentIdentity;
    final revision = AuthService.credentialRevision;
    if (identity == null || AuthService.isEndingSession) return {};
    final session = await AuthService.captureSession();
    if (session == null) return {};
    final prefs = await SharedPreferences.getInstance();
    if (revision != AuthService.credentialRevision ||
        identity != AuthService.currentIdentity ||
        AuthService.isEndingSession) {
      return {};
    }
    return _decode(prefs.getString(_key(identity, businessId)));
  }

  static Future<void> setLiked({
    required int businessId,
    required int itemId,
    required bool liked,
  }) {
    final identity = AuthService.currentIdentity;
    final revision = AuthService.credentialRevision;
    if (identity == null || AuthService.isEndingSession) {
      return Future.error(StateError('Не подтверждён владелец избранного'));
    }
    final key = _key(identity, businessId);
    final operation = (_writes[key] ?? Future<void>.value()).then((_) async {
      final session = await AuthService.captureSession();
      if (session == null ||
          revision != AuthService.credentialRevision ||
          identity != AuthService.currentIdentity ||
          AuthService.isEndingSession) {
        throw StateError('Аккаунт избранного изменился');
      }
      final prefs = await SharedPreferences.getInstance();
      if (revision != AuthService.credentialRevision ||
          identity != AuthService.currentIdentity ||
          AuthService.isEndingSession) {
        throw StateError('Аккаунт избранного изменился');
      }
      final ids = _decode(prefs.getString(key));
      if (liked) {
        ids.add(itemId);
      } else {
        ids.remove(itemId);
      }
      try {
        if (!await prefs.setString(key, jsonEncode(ids.toList()))) {
          throw StateError('Не удалось сохранить избранное на устройстве');
        }
      } catch (_) {
        // SharedPreferences updates its cache before awaiting platform storage.
        // Reload the durable value before the next queued read-modify-write.
        await prefs.reload();
        rethrow;
      }
    });
    final settled =
        operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _writes[key] = settled;
    return operation.whenComplete(() {
      if (identical(_writes[key], settled)) _writes.remove(key);
    });
  }

  static Future<bool> isLiked({
    required int businessId,
    required int itemId,
  }) async =>
      (await getLikedIds(businessId: businessId)).contains(itemId);
}
