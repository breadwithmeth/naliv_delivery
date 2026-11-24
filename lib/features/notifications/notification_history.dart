import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_service.dart';

/// Display text captured from one local push delivery or click.
@immutable
class HistoryNotification {
  const HistoryNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
  });

  /// The stable notification ID provided by the push SDK.
  final String id;
  final String title;
  final String body;

  /// The local observation time, not a server send timestamp.
  final DateTime receivedAt;
}

/// A bounded inbox on this installation, readable only by its verified owner.
///
/// Does not sync with the server or contain routing data or credentials.
class NotificationHistory extends ChangeNotifier {
  NotificationHistory._();

  static final instance = NotificationHistory._();
  static const _maxEntries = 100;
  static const _maxEvictedIds = 256;
  Future<void>? _operations;

  /// Reads the current owner's entries, newest first.
  ///
  /// Returns no entries if [identity] is not or stops being the verified owner.
  /// Storage and malformed-data errors for the current owner are propagated.
  Future<List<HistoryNotification>> read(String identity) {
    final revision = AuthService.sessionRevision.value;
    if (!_isCurrent(identity, revision)) return Future.value(const []);
    return _serialize(() async {
      if (!_isCurrent(identity, revision)) return const [];
      try {
        final prefs = await SharedPreferences.getInstance();
        await AuthService.reloadLocalPreferences(prefs);
        if (!_isCurrent(identity, revision)) return const [];
        return _decode(prefs.get(_key(identity))).entries;
      } catch (_) {
        if (!_isCurrent(identity, revision)) return const [];
        rethrow;
      }
    });
  }

  /// Adds [entry] for the current verified [identity] and notifies listeners.
  ///
  /// Returns false for an invalid row, a previously seen provider ID in the
  /// bounded history, an entry older than retention, or a superseded session.
  /// A duplicate does not overwrite the original text or observation time.
  /// Storage errors are propagated.
  Future<bool> append(String identity, HistoryNotification entry) {
    final revision = AuthService.sessionRevision.value;
    if (!_isCurrent(identity, revision)) return Future.value(false);
    final id = entry.id.trim();
    final title = _boundedText(entry.title, 256);
    final body = _boundedText(entry.body, 2048);
    if (!_validId(id) || (title.isEmpty && body.isEmpty)) {
      return Future.value(false);
    }
    return _serialize(() async {
      if (!_isCurrent(identity, revision)) return false;
      final prefs = await SharedPreferences.getInstance();
      await AuthService.reloadLocalPreferences(prefs);
      if (!_isCurrent(identity, revision)) return false;
      final key = _key(identity);
      final raw = prefs.get(key);
      final snapshot = _decode(raw);
      final entries = snapshot.entries;
      final evicted = snapshot.evicted;
      if (entries.any((row) => row.id == id) || evicted.contains(id)) {
        return false;
      }
      final time = entry.receivedAt.toUtc();
      final index = entries.indexWhere((row) => !row.receivedAt.isAfter(time));
      entries.insert(
        index < 0 ? entries.length : index,
        HistoryNotification(id: id, title: title, body: body, receivedAt: time),
      );
      String? evictedId;
      if (entries.length > _maxEntries) {
        evictedId = entries.removeLast().id;
        evicted.add(evictedId);
        if (evicted.length > _maxEvictedIds) evicted.removeAt(0);
      }
      final encoded = jsonEncode({
        'entries': [
          for (final row in entries)
            {
              'id': row.id,
              'title': row.title,
              'body': row.body,
              'receivedAt': row.receivedAt.millisecondsSinceEpoch,
            },
        ],
        'evicted': evicted,
      });
      if (!await prefs.setString(key, encoded)) {
        throw StateError('Could not persist local notification history');
      }
      if (!_isCurrent(identity, revision)) {
        // The backend may acknowledge an optimistic write after auth changed.
        // Undo it without replacing a newer value written by another context.
        await AuthService.reloadLocalPreferences(prefs);
        if (prefs.get(key) == encoded) {
          final restored = raw == null
              ? await prefs.remove(key)
              : await prefs.setString(key, raw as String);
          if (!restored) throw StateError('Could not revoke stale history write');
        }
        return false;
      }
      if (evictedId == id) return false;
      notifyListeners();
      return true;
    });
  }

  /// Drops the outgoing account's display history during explicit logout.
  Future<void> forgetOnLogout(String identity) {
    if (!AuthService.isEndingSession) return Future.value();
    return _serialize(() async {
      final prefs = await SharedPreferences.getInstance();
      await AuthService.reloadLocalPreferences(prefs);
      final key = _key(identity);
      if (prefs.containsKey(key) && !await prefs.remove(key)) {
        throw StateError('Could not remove local notification history');
      }
    });
  }

  static bool _isCurrent(String identity, int revision) =>
      !AuthService.isEndingSession &&
      AuthService.verifiedIdentity == identity &&
      AuthService.sessionRevision.value == revision;

  static String _key(String identity) =>
      'notification_history_v1.${base64Url.encode(utf8.encode(identity))}';

  static bool _validId(String id) => id.isNotEmpty && id.length <= 128;

  static String _boundedText(String input, int limit) {
    final text = input.trim();
    if (text.length <= limit) return text;
    final last = text.codeUnitAt(limit - 1);
    return text.substring(0, last >= 0xD800 && last <= 0xDBFF ? limit - 1 : limit);
  }

  static ({List<HistoryNotification> entries, List<String> evicted}) _decode(
    Object? raw,
  ) {
    if (raw == null) return (entries: [], evicted: []);
    const invalid = FormatException('Invalid local notification history');
    if (raw is! String) throw invalid;
    // Do not include the rejected source in the exception reported by callers.
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw invalid;
    }
    if (decoded case {'entries': final List<Object?> stored,
        'evicted': final List<Object?> ids}) {
      if (stored.length > _maxEntries || ids.length > _maxEvictedIds) {
        throw invalid;
      }
      final seen = <String>{};
      final entries = <HistoryNotification>[];
      int? previous;
      for (final row in stored) {
        if (row case {'id': final String id, 'title': final String title,
            'body': final String body, 'receivedAt': final int milliseconds}
            when _validId(id) && title.length <= 256 && body.length <= 2048 &&
                (title.isNotEmpty || body.isNotEmpty) &&
                milliseconds.abs() <= 8640000000000000 &&
                (previous == null || previous >= milliseconds) && seen.add(id)) {
          entries.add(HistoryNotification(
            id: id,
            title: title,
            body: body,
            receivedAt: DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true),
          ));
          previous = milliseconds;
        } else {
          throw invalid;
        }
      }
      final evicted = <String>[];
      for (final id in ids) {
        if (id is! String || !_validId(id) || !seen.add(id)) throw invalid;
        evicted.add(id);
      }
      return (entries: entries, evicted: evicted);
    }
    throw invalid;
  }

  Future<T> _serialize<T>(Future<T> Function() work) {
    final previous = _operations;
    final result = previous == null ? Future<T>.sync(work) : previous.then((_) => work());
    late final Future<void> tail;
    void release() {
      if (identical(_operations, tail)) _operations = null;
    }
    tail = result.then<void>((_) => release(), onError: (Object _, StackTrace __) => release());
    _operations = tail;
    return result;
  }
}
