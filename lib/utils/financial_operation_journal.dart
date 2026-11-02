import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum FinancialOperationKind { orderCreation, certificatePurchase }

enum FinancialOperationOutcome { accepted, refused, unknown }

FinancialOperationOutcome financialOperationOutcome(Map<String, dynamic> result,
    {required bool accepted}) {
  final status = result['statusCode'];
  if (result['outcomeUnknown'] == true ||
      (status is int && (status == 408 || status >= 500))) {
    return FinancialOperationOutcome.unknown;
  }
  if (accepted && result['success'] == true) {
    return FinancialOperationOutcome.accepted;
  }
  if (result['requestSent'] == false || result['success'] == false) {
    return FinancialOperationOutcome.refused;
  }
  return FinancialOperationOutcome.unknown;
}

class FinancialOperationIntent {
  FinancialOperationIntent({
    required this.request,
    this.identity,
    this.result,
    this.completed = false,
  });

  final Map<String, dynamic> request;
  final String? identity;
  final Map<String, dynamic>? result;
  final bool completed;

  Map<String, dynamic> toJson() => {
        'version': 1,
        'state': completed ? 'completed' : 'unresolved',
        'request': request,
        if (identity != null) 'identity': identity,
        if (result != null) 'result': result,
      };

  static FinancialOperationIntent parse(Object raw) {
    if (raw is! String) throw const FormatException('Invalid journal value');
    final value = jsonDecode(raw);
    if (value is! Map ||
        value['version'] != 1 ||
        !const {'unresolved', 'completed'}.contains(value['state']) ||
        value['request'] is! Map ||
        (value['identity'] != null &&
            (value['identity'] is! String ||
                (value['identity'] as String).trim().isEmpty)) ||
        (value['result'] != null && value['result'] is! Map)) {
      throw const FormatException('Invalid financial journal');
    }
    return FinancialOperationIntent(
      request: Map<String, dynamic>.from(value['request'] as Map),
      identity: value['identity'] as String?,
      result: value['result'] == null
          ? null
          : Map<String, dynamic>.from(value['result'] as Map),
      completed: value['state'] == 'completed',
    );
  }
}

class FinancialOperationRead {
  const FinancialOperationRead({this.intent, this.storageUnavailable = false});
  final FinancialOperationIntent? intent;
  final bool storageUnavailable;
  bool get ready => intent == null && !storageUnavailable;
}

/// An account-owned write-ahead intent. Absence of a server reply never releases it.
class FinancialOperationJournal {
  FinancialOperationJournal(this.account, this.kind);

  FinancialOperationIntent? _reservedIntent;
  final String account;
  final FinancialOperationKind kind;
  static final _busy = <String>{};
  // Preserve returned identities in this process even when their update is refused.
  // The previously persisted unresolved intent still blocks a restarted process.
  static final _retained = <String, FinancialOperationIntent>{};

  String get preferenceKey =>
      'financial_operation.${Uri.encodeComponent(account)}.${kind.name}';

  Future<FinancialOperationRead> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.get(preferenceKey);
      final retained = _retained[preferenceKey];
      if (raw == null) {
        if (retained != null) return FinancialOperationRead(intent: retained);
        return const FinancialOperationRead();
      }
      final stored = FinancialOperationIntent.parse(raw);
      return FinancialOperationRead(intent: retained ?? stored);
    } catch (_) {
      return FinancialOperationRead(
          intent: _retained[preferenceKey], storageUnavailable: true);
    }
  }

  Future<bool> _store(FinancialOperationIntent? intent) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = intent == null ? null : jsonEncode(intent.toJson());
      final saved = value == null
          ? await prefs.remove(preferenceKey)
          : await prefs.setString(preferenceKey, value);
      await prefs.reload();
      return saved && prefs.get(preferenceKey) == value;
    } catch (_) {
      return false;
    }
  }

  /// Returns true only to the caller holding a verified durable reservation.
  Future<bool> reserve(Map<String, dynamic> request) async {
    if (account.trim().isEmpty || !_busy.add(preferenceKey)) return false;
    var reserved = false;
    try {
      if (!(await read()).ready) return false;
      final intent = FinancialOperationIntent(
          request: Map<String, dynamic>.from(
              jsonDecode(jsonEncode(request)) as Map));
      reserved = await _store(intent);
      if (reserved) _reservedIntent = intent;
      return reserved;
    } finally {
      if (!reserved) _busy.remove(preferenceKey);
    }
  }

  Future<bool> settle({
    required FinancialOperationOutcome outcome,
    String? identity,
    Map<String, dynamic>? result,
    bool completed = false,
  }) async {
    final current = await read();
    final prior = current.intent ?? _reservedIntent;
    if (prior == null) return false;
    if (prior.completed) return !current.storageUnavailable;
    if (prior.identity != null &&
        identity != null &&
        prior.identity != identity) {
      return false;
    }
    if (outcome == FinancialOperationOutcome.refused) {
      if (current.storageUnavailable) return false;
      if (!await _store(null)) return false;
      _retained.remove(preferenceKey);
      _reservedIntent = null;
      return true;
    }
    final updated = FinancialOperationIntent(
      request: prior.request,
      identity: identity ?? prior.identity,
      result: result ?? prior.result,
      completed: completed || prior.completed,
    );
    _retained[preferenceKey] = updated;
    if (current.storageUnavailable) return false;
    final saved = await _store(updated);
    if (saved) _retained.remove(preferenceKey);
    return saved;
  }

  /// Only a completed operation or a definitely unsent reservation may be cleared.
  Future<bool> acknowledge({bool requestNotSent = false}) async {
    final current = await read();
    if (current.storageUnavailable ||
        (!requestNotSent && current.intent?.completed != true)) {
      return false;
    }
    if (!await _store(null)) return false;
    _retained.remove(preferenceKey);
    _reservedIntent = null;
    return true;
  }

  void release() {
    _busy.remove(preferenceKey);
    _reservedIntent = null;
  }
}
