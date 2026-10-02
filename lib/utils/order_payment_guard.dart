import 'package:shared_preferences/shared_preferences.dart';

enum OrderPaymentOutcome { completed, refused, pending, unknown }

enum OrderPaymentState { ready, unconfirmed, completed, storageUnavailable }

const _completedStatuses = {
  'completed',
  'paid',
  'processed',
  'success',
  'succeeded',
};
const _refusedStatuses = {
  'failed',
  'rejected',
  'canceled',
  'cancelled',
  'expired',
  'error',
  'declined',
};
const _pendingStatuses = {
  'pending',
  'processing',
  'in_progress',
  'in_process',
  'in_processing',
};

String _status(dynamic value) =>
    value?.toString().trim().toLowerCase().replaceAll('-', '_') ?? '';

OrderPaymentOutcome orderPaymentOutcome(Map<String, dynamic> data) {
  final paymentStatus = _status(data['payment_status']);
  final kaspiStatus = _status(data['kaspi_status']);
  if (_completedStatuses.contains(paymentStatus) ||
      _completedStatuses.contains(kaspiStatus)) {
    return OrderPaymentOutcome.completed;
  }
  final currentStatus = data['current_status'];
  final status = data['status'];
  final statusCode = currentStatus is Map
      ? currentStatus['status']?.toString()
      : status is Map
          ? status['status']?.toString()
          : null;
  if (_pendingStatuses.contains(paymentStatus) ||
      _pendingStatuses.contains(kaspiStatus) ||
      statusCode == '61') {
    return OrderPaymentOutcome.pending;
  }
  if (_refusedStatuses.contains(paymentStatus) ||
      _refusedStatuses.contains(kaspiStatus)) {
    return OrderPaymentOutcome.refused;
  }
  return OrderPaymentOutcome.unknown;
}

OrderPaymentOutcome orderPaymentResultOutcome(Map<String, dynamic> result) {
  if (result['requestSent'] == false) return OrderPaymentOutcome.unknown;
  final data = result['data'];
  final outcome = orderPaymentOutcome(data is Map<String, dynamic>
      ? data
      : data is Map
          ? data.cast<String, dynamic>()
          : const {});
  if (outcome == OrderPaymentOutcome.completed) {
    return result['success'] == true ? outcome : OrderPaymentOutcome.unknown;
  }
  if (outcome == OrderPaymentOutcome.pending) return outcome;
  final statusCode = result['statusCode'];
  final uncertain = result['outcomeUnknown'] == true ||
      (statusCode is int && (statusCode >= 500 || statusCode == 408));
  if (!uncertain &&
      (outcome == OrderPaymentOutcome.refused || result['success'] == false)) {
    return OrderPaymentOutcome.refused;
  }
  return OrderPaymentOutcome.unknown;
}

String? paymentOrderId(Map<String, dynamic> order) {
  final value = order['order_id'] ?? order['order_uuid'] ?? order['id'];
  final id = value?.toString().trim();
  return id == null || id.isEmpty || id.toLowerCase() == 'null' ? null : id;
}

class OrderPaymentGuard {
  static const localStateKey = '_local_payment_state';
  static const _preferencePrefix = 'order_payment_guard.';
  // Reservations contain no shared Futures: each caller keeps its own zone.
  static final _busy = <String>{};
  // Keep a confirmed result terminal if its completion write fails. Any existing
  // durable reservation also protects the next application session.
  static final _unpersistedCompletions = <String>{};
  static final _attemptRevisions = <String, int>{};
  static int _revision = 0;

  static String preferenceKey(String orderId) =>
      '$_preferencePrefix${Uri.encodeComponent(orderId.trim())}';

  static int beginOrderRead() => _revision;

  static Future<OrderPaymentState> _readStored(String orderId) async {
    if (_unpersistedCompletions.contains(orderId.trim())) {
      return OrderPaymentState.completed;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final value = prefs.get(preferenceKey(orderId));
      if (value == null) return OrderPaymentState.ready;
      if (value == 'completed') return OrderPaymentState.completed;
      // Unknown stored values cannot make an unresolved order payable.
      return OrderPaymentState.unconfirmed;
    } catch (_) {
      return OrderPaymentState.storageUnavailable;
    }
  }

  static Future<OrderPaymentState> read(String orderId) async {
    final state = await _readStored(orderId);
    return _busy.contains(orderId.trim()) && state == OrderPaymentState.ready
        ? OrderPaymentState.unconfirmed
        : state;
  }

  static Future<bool> _store(String orderId, String? value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = preferenceKey(orderId);
      final saved = value == null
          ? await prefs.remove(key)
          : await prefs.setString(key, value);
      if (!saved) {
        await prefs.reload();
        return false;
      }
      await prefs.reload();
      return prefs.get(key) == value;
    } catch (_) {
      return false;
    }
  }

  // A ready result owns the reservation until release(), including settlement.
  static Future<OrderPaymentState> reserve(String orderId) async {
    orderId = orderId.trim();
    if (!_busy.add(orderId)) return OrderPaymentState.unconfirmed;
    var reserved = false;
    try {
      final state = await _readStored(orderId);
      if (state != OrderPaymentState.ready) return state;
      _attemptRevisions[orderId] = ++_revision;
      if (!await _store(orderId, 'unconfirmed')) {
        return OrderPaymentState.storageUnavailable;
      }
      reserved = true;
      return OrderPaymentState.ready;
    } finally {
      if (!reserved) _busy.remove(orderId);
    }
  }

  static void release(String orderId) => _busy.remove(orderId.trim());

  static Future<OrderPaymentState> settle(
      String orderId, OrderPaymentOutcome outcome) async {
    if (outcome == OrderPaymentOutcome.completed) {
      _unpersistedCompletions.add(orderId.trim());
      if (await _store(orderId, 'completed')) {
        _unpersistedCompletions.remove(orderId.trim());
      }
      return OrderPaymentState.completed;
    }
    if (outcome == OrderPaymentOutcome.refused) {
      return await _store(orderId, null)
          ? OrderPaymentState.ready
          : OrderPaymentState.unconfirmed;
    }
    return OrderPaymentState.unconfirmed;
  }

  static Future<void> reconcileOrder(
    Map<String, dynamic> order, {
    required int readRevision,
    String? orderId,
  }) async {
    final id = paymentOrderId(order) ?? orderId;
    if (id == null) return;
    final outcome = orderPaymentOutcome(order);
    var state = await read(id);
    final stale = (_attemptRevisions[id] ?? 0) > readRevision;
    if (!stale && _busy.add(id)) {
      try {
        // Re-read inside the reservation before changing a persisted decision.
        state = await _readStored(id);
        if (state != OrderPaymentState.completed ||
            (outcome == OrderPaymentOutcome.completed &&
                _unpersistedCompletions.contains(id))) {
          if (outcome == OrderPaymentOutcome.completed) {
            state = await settle(id, outcome);
          } else if (outcome == OrderPaymentOutcome.refused &&
              state == OrderPaymentState.unconfirmed) {
            state = await settle(id, outcome);
          } else if (outcome == OrderPaymentOutcome.pending &&
              state != OrderPaymentState.unconfirmed) {
            state = await _store(id, 'unconfirmed')
                ? OrderPaymentState.unconfirmed
                : OrderPaymentState.storageUnavailable;
          }
        }
      } finally {
        _busy.remove(id);
      }
    }
    order[localStateKey] = state.name;
  }
}
