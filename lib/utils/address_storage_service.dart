import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddressBookSnapshot {
  const AddressBookSnapshot({
    required this.localAddresses,
    required this.hiddenIds,
    required this.selectedAddress,
  });

  final List<Map<String, dynamic>> localAddresses;
  final Set<String> hiddenIds;
  final Map<String, dynamic>? selectedAddress;
}

class AddressStorageService {
  static const String _selectedAddressKey = 'selected_address';
  static const String _addressHistoryKey = 'address_history';
  static const String _isFirstLaunchKey = 'is_first_launch';
  static const String _lastReaddressPromptKey = 'last_readdress_prompt';
  static const String _localKey = 'profile_local_addresses';
  static const String _hiddenKey = 'profile_hidden_addresses';
  static Future<void>? _pendingWrite;
  static final _selectedAddressController =
      StreamController<Map<String, dynamic>?>.broadcast();

  static Stream<Map<String, dynamic>?> get selectedAddressStream =>
      _selectedAddressController.stream;

  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isFirstLaunchKey) ?? true;
  }

  static Future<void> markAsLaunched() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(_isFirstLaunchKey, false)) {
      throw StateError('Не удалось сохранить состояние запуска');
    }
  }

  static Future<bool> hasSelectedAddress() async =>
      await getSelectedAddress() != null;

  static Future<Map<String, dynamic>?> getSelectedAddress() async {
    final pending = _pendingWrite;
    if (pending != null) await pending;
    final prefs = await SharedPreferences.getInstance();
    return _decodeSelected(prefs);
  }

  static Map<String, dynamic>? _decodeSelected(SharedPreferences prefs) {
    final raw = prefs.getString(_selectedAddressKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final value = jsonDecode(raw);
      return value is Map ? Map<String, dynamic>.from(value) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<AddressBookSnapshot> getBookSnapshot() async {
    final pending = _pendingWrite;
    if (pending != null) await pending;
    final prefs = await SharedPreferences.getInstance();
    return _book(prefs);
  }

  static AddressBookSnapshot _book(SharedPreferences prefs) =>
      AddressBookSnapshot(
        localAddresses: _decodeList(prefs.getStringList(_localKey) ?? []),
        hiddenIds: (prefs.getStringList(_hiddenKey) ?? []).toSet(),
        selectedAddress: _decodeSelected(prefs),
      );

  static List<Map<String, dynamic>> _decodeList(List<String> values) =>
      values.map((raw) {
        final value = jsonDecode(raw);
        if (value is! Map) {
          throw const FormatException('Некорректный сохранённый адрес');
        }
        return Map<String, dynamic>.from(value);
      }).toList();

  static String identity(Map<String, dynamic> address) {
    final id = address['id'] ?? address['address_id'] ?? address['uuid'];
    if (id != null && id.toString().isNotEmpty) return id.toString();
    final label = address['address'] ?? address['name'];
    if (label != null && label.toString().isNotEmpty) return label.toString();
    final point = coordinates(address);
    return '${point?.$1}_${point?.$2}_${address['street']}_${address['house']}';
  }

  static (double, double)? coordinates(Map<String, dynamic> address) {
    final point = address['point'];
    final geometry = address['geometry'];
    final values = geometry is Map ? geometry['coordinates'] : null;
    final lat = _number(address['lat'] ??
        (point is Map ? point['lat'] : null) ??
        (values is List && values.length >= 2 ? values[1] : null));
    final lon = _number(address['lon'] ??
        (point is Map ? point['lon'] : null) ??
        (values is List && values.length >= 2 ? values[0] : null));
    if (lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180) {
      return null;
    }
    return (lat, lon);
  }

  static double? _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value');

  static bool sameAddress(
      Map<String, dynamic>? first, Map<String, dynamic>? second) {
    if (first == null || second == null) return false;
    final firstId = first['id'] ?? first['address_id'] ?? first['uuid'];
    final secondId = second['id'] ?? second['address_id'] ?? second['uuid'];
    if (firstId != null && secondId != null) {
      return firstId.toString() == secondId.toString();
    }
    final a = coordinates(first);
    final b = coordinates(second);
    if (a == null || b == null || a != b) return false;
    return (first['address'] ?? first['name']) ==
            (second['address'] ?? second['name']) &&
        '${first['apartment'] ?? ''}' == '${second['apartment'] ?? ''}';
  }

  static Map<String, dynamic>? deliveryAddress(Map<String, dynamic> address) {
    final point = coordinates(address);
    final label = (address['address'] ?? address['name'])?.toString().trim();
    if (point == null || label == null || label.isEmpty) return null;
    return {
      ...address,
      'address': label,
      'lat': point.$1,
      'lon': point.$2,
      'point': {'lat': point.$1, 'lon': point.$2},
    };
  }

  static Future<bool> saveSelectedAddress(Map<String, dynamic> address) =>
      _serialize(() async {
        final prefs = await SharedPreferences.getInstance();
        final success = await _commit(prefs, {
          _selectedAddressKey: jsonEncode(address),
        });
        if (success) _selectedAddressController.add(Map.of(address));
        return success;
      });

  static Future<bool> selectBookAddress(Map<String, dynamic> address) =>
      _serialize(() async {
        final selected = deliveryAddress(address);
        if (selected == null) return false;
        final prefs = await SharedPreferences.getInstance();
        final book = _book(prefs);
        if (book.hiddenIds.contains(identity(address))) return false;
        final history = _historyWith(prefs, selected);
        final success = await _commit(prefs, {
          _selectedAddressKey: jsonEncode(selected),
          _addressHistoryKey: history.map(jsonEncode).toList(),
        });
        if (success) _selectedAddressController.add(selected);
        return success;
      });

  static Future<bool> saveBookAddress(Map<String, dynamic> address,
          {Map<String, dynamic>? replacing}) =>
      _serialize(() async {
        final normalized = deliveryAddress(address);
        if (normalized == null) return false;
        final prefs = await SharedPreferences.getInstance();
        final book = _book(prefs);
        final local = List<Map<String, dynamic>>.of(book.localAddresses);
        final hidden = Set<String>.of(book.hiddenIds);
        final priorLocal = replacing == null
            ? -1
            : local.indexWhere((item) => identity(item) == identity(replacing));
        final saved = <String, dynamic>{
          ...normalized,
          'id': priorLocal >= 0
              ? identity(local[priorLocal])
              : 'device_${DateTime.now().microsecondsSinceEpoch}',
          'device_local': true,
          'source': 'profile_local',
          if (replacing != null && priorLocal < 0)
            'edited_from': identity(replacing),
        };
        if (priorLocal >= 0) {
          local[priorLocal] = saved;
        } else {
          local.insert(0, saved);
          if (replacing != null) hidden.add(identity(replacing));
        }
        final changes = <String, Object?>{
          _localKey: local.map(jsonEncode).toList(),
          _hiddenKey: hidden.toList(),
        };
        final updateSelected = sameAddress(book.selectedAddress, replacing);
        if (updateSelected) {
          changes[_selectedAddressKey] = jsonEncode(saved);
          changes[_addressHistoryKey] =
              _historyWith(prefs, saved, removing: replacing)
                  .map(jsonEncode)
                  .toList();
        }
        final success = await _commit(prefs, changes);
        if (success && updateSelected) _selectedAddressController.add(saved);
        return success;
      });

  static Future<bool> removeBookAddress(Map<String, dynamic> address) =>
      _serialize(() async {
        final prefs = await SharedPreferences.getInstance();
        final book = _book(prefs);
        final id = identity(address);
        final local =
            book.localAddresses.where((item) => identity(item) != id).toList();
        final isLocal = local.length != book.localAddresses.length;
        final hidden = Set<String>.of(book.hiddenIds);
        if (!isLocal) hidden.add(id);
        final clearSelected = sameAddress(book.selectedAddress, address);
        final history =
            _decodeList(prefs.getStringList(_addressHistoryKey) ?? [])
                .where((item) => !sameAddress(item, address))
                .toList();
        final success = await _commit(prefs, {
          _localKey: local.map(jsonEncode).toList(),
          _hiddenKey: hidden.toList(),
          _addressHistoryKey: history.map(jsonEncode).toList(),
          if (clearSelected) _selectedAddressKey: null,
        });
        if (success && clearSelected) _selectedAddressController.add(null);
        return success;
      });

  static Future<bool> removeSelectedAddress() => _serialize(() async {
        final prefs = await SharedPreferences.getInstance();
        final success = await _commit(prefs, {_selectedAddressKey: null});
        if (success) _selectedAddressController.add(null);
        return success;
      });

  static Future<List<Map<String, dynamic>>> getAddressHistory() async {
    final pending = _pendingWrite;
    if (pending != null) await pending;
    final prefs = await SharedPreferences.getInstance();
    try {
      return _decodeList(prefs.getStringList(_addressHistoryKey) ?? []);
    } catch (error) {
      debugPrint('Не удалось прочитать историю адресов: $error');
      return [];
    }
  }

  static List<Map<String, dynamic>> _historyWith(
      SharedPreferences prefs, Map<String, dynamic> address,
      {Map<String, dynamic>? removing}) {
    final history = _decodeList(prefs.getStringList(_addressHistoryKey) ?? []);
    history.removeWhere(
        (item) => sameAddress(item, address) || sameAddress(item, removing));
    history.insert(0, {
      ...address,
      'name': address['address'] ?? address['name'],
    });
    return history.take(10).toList();
  }

  static Future<bool> addToAddressHistory(Map<String, dynamic> address) =>
      _serialize(() async {
        final prefs = await SharedPreferences.getInstance();
        return _commit(prefs, {
          _addressHistoryKey:
              _historyWith(prefs, address).map(jsonEncode).toList(),
        });
      });

  static Future<bool> clearAddressHistory() => _serialize(() async {
        final prefs = await SharedPreferences.getInstance();
        return _commit(prefs, {_addressHistoryKey: null});
      });

  static Future<void> clearAllAddressData() async {
    final success = await _serialize(() async {
      final prefs = await SharedPreferences.getInstance();
      final saved = await _commit(prefs, {
        _selectedAddressKey: null,
        _addressHistoryKey: null,
      });
      if (saved) _selectedAddressController.add(null);
      return saved;
    });
    if (!success) throw StateError('Не удалось очистить адреса');
  }

  static Future<bool> _serialize(Future<bool> Function() operation) async {
    final previous = _pendingWrite;
    final completion = Completer<void>();
    _pendingWrite = completion.future;
    try {
      if (previous != null) await previous;
      return await operation();
    } catch (error) {
      debugPrint('Не удалось сохранить адреса: $error');
      return false;
    } finally {
      // Release only the idle tail, before callers can enqueue another write.
      // Keeping a completed future would retain its scheduling zone.
      if (identical(_pendingWrite, completion.future)) _pendingWrite = null;
      completion.complete();
    }
  }

  // SharedPreferences has no multi-key transaction. Stage every value, restore
  // the prior snapshot on failure, and only notify consumers after all writes succeed.
  static Future<bool> _commit(
      SharedPreferences prefs, Map<String, Object?> changes) async {
    final before = <String, Object?>{
      for (final key in changes.keys) key: prefs.get(key),
    };
    try {
      for (final entry in changes.entries) {
        if (!await _writeValue(prefs, entry.key, entry.value)) {
          throw StateError('Запись настроек отклонена');
        }
      }
      return true;
    } catch (error) {
      for (final entry in before.entries.toList().reversed) {
        try {
          if (!await _writeValue(prefs, entry.key, entry.value)) {
            debugPrint('Не удалось восстановить ${entry.key}');
          }
        } catch (rollbackError) {
          debugPrint('Не удалось восстановить ${entry.key}: $rollbackError');
        }
      }
      try {
        await prefs.reload();
      } catch (reloadError) {
        debugPrint('Не удалось перечитать сохранённые адреса: $reloadError');
      }
      debugPrint('Не удалось сохранить адреса: $error');
      return false;
    }
  }

  static Future<bool> _writeValue(
      SharedPreferences prefs, String key, Object? value) {
    if (value == null) {
      return prefs.containsKey(key) ? prefs.remove(key) : Future.value(true);
    }
    if (value is String) return prefs.setString(key, value);
    if (value is List<String>) return prefs.setStringList(key, value);
    throw ArgumentError.value(value, key);
  }

  static Future<void> setLastReaddressPromptKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_lastReaddressPromptKey, key)) {
      throw StateError('Не удалось сохранить состояние подсказки');
    }
  }

  static Future<String?> getLastReaddressPromptKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastReaddressPromptKey);
  }
}
