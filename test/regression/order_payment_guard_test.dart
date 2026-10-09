import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/utils/order_payment_guard.dart';
import 'package:naliv_delivery/utils/order_ui_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class PaymentPreferences extends InMemorySharedPreferencesStore {
  PaymentPreferences(Map<String, Object> values)
      : super.withData({
          for (final entry in values.entries)
            'flutter.${entry.key}': entry.value,
        });

  bool rejectWrites = false;
  bool throwWrites = false;
  bool rejectRemoval = false;

  void install() {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = this;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.startsWith('flutter.order_payment_guard.')) {
      if (throwWrites) throw StateError('Fixture storage unavailable');
      if (rejectWrites) return false;
    }
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    if (rejectRemoval && key.startsWith('flutter.order_payment_guard.')) {
      return false;
    }
    return super.remove(key);
  }
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

Map<String, dynamic> _order(String id, {String? paymentStatus}) => {
      'order_id': id,
      'payable_amount': 1200,
      'current_status': {'status': '60'},
      if (paymentStatus != null) 'payment_status': paymentStatus,
    };

http.Client _client(Future<http.Response> Function(http.Request) reply) =>
    MockClient((request) {
      expect(request.url.host, 'njt25.naliv.kz');
      expect(request.headers['Authorization'], 'Bearer fixture-only');
      return reply(request);
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'auth_token': 'fixture-only'});
  });

  for (final acknowledgment in ['pending', 'unreadable']) {
    test('$acknowledgment survives history, detail and preferences reload',
        () async {
      var posts = 0;
      const id = '1001';
      final client = _client((request) async {
        if (request.method == 'POST' &&
            request.url.path == '/api/orders/$id/pay') {
          posts++;
          // The durable reservation must precede the actual request.
          final stored = await SharedPreferencesStorePlatform.instance.getAll();
          expect(stored['flutter.${OrderPaymentGuard.preferenceKey(id)}'],
              'unconfirmed');
          return acknowledgment == 'pending'
              ? _json({
                  'success': true,
                  'data': {'payment_status': 'pending'}
                })
              : http.Response('{unreadable', 200);
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/orders/my-orders') {
          return _json({
            'success': true,
            'data': {
              'orders': [_order(id)]
            }
          });
        }
        if (request.method == 'GET' && request.url.path == '/api/orders/$id') {
          return _json({
            'success': true,
            'data': {'order': _order(id)}
          });
        }
        throw StateError('Unexpected fixture request: $request');
      });
      await http.runWithClient(() async {
        final first = await ApiService.payOrder(id, 'saved-card');
        expect(first['paymentGuardState'], 'unconfirmed');
        final history = await ApiService.getMyOrdersHistoryList();
        expect(canPayOrder(history.single), isFalse);
        final detail = await ApiService.getOrderDetails(int.parse(id));
        expect(canPayOrder(detail!), isFalse);
        expect((await ApiService.payOrder(id, 'saved-card'))['requestSent'],
            isFalse);
        SharedPreferences.resetStatic();
        expect(await OrderPaymentGuard.read(id), OrderPaymentState.unconfirmed);
        expect((await ApiService.payOrder(id, 'saved-card'))['requestSent'],
            isFalse);
        expect(posts, 1);
      }, () => client);
    });
  }

  test('same-order calls in different zones reserve only one POST', () async {
    final entered = Completer<void>();
    final response = Completer<http.Response>();
    var posts = 0;
    final client = _client((request) async {
      if (request.method != 'POST' ||
          request.url.path != '/api/orders/1002/pay') {
        throw StateError('Unexpected fixture request: $request');
      }
      posts++;
      entered.complete();
      return response.future;
    });
    final first = http.runWithClient(
        () => ApiService.payOrder('1002', 'saved-card'), () => client);
    await entered.future;
    final blockedClient = _client((request) async {
      throw StateError('Concurrent caller must not reach HTTP: $request');
    });
    final second = await http.runWithClient(
        () => ApiService.payOrder('1002', 'saved-card'), () => blockedClient);
    expect(second['requestSent'], isFalse);
    expect(second['paymentGuardState'], 'unconfirmed');
    response.complete(_json({
      'success': true,
      'data': {'payment_status': 'pending'}
    }));
    await first;
    expect(posts, 1);
  });

  test('different order IDs progress while another payment is in flight',
      () async {
    final entered = Completer<void>();
    final held = Completer<http.Response>();
    final posts = <String>[];
    final client = _client((request) async {
      if (request.method != 'POST' ||
          !['/api/orders/1003/pay', '/api/orders/1004/pay']
              .contains(request.url.path)) {
        throw StateError('Unexpected fixture request: $request');
      }
      posts.add(request.url.path);
      if (request.url.path == '/api/orders/1003/pay') {
        entered.complete();
        return held.future;
      }
      return _json({
        'success': true,
        'data': {'payment_status': 'completed'}
      });
    });
    await http.runWithClient(() async {
      final first = ApiService.payOrder('1003', 'saved-card');
      await entered.future;
      final second = await ApiService.payOrder('1004', 'saved-card');
      expect(second['paymentGuardState'], 'completed');
      expect(
          await OrderPaymentGuard.read('1003'), OrderPaymentState.unconfirmed);
      held.complete(_json({
        'success': true,
        'data': {'payment_status': 'pending'}
      }));
      await first;
      expect(posts, ['/api/orders/1003/pay', '/api/orders/1004/pay']);
    }, () => client);
  });

  test('definitive refusal permits an explicit retry, completion never does',
      () async {
    var posts = 0;
    final client = _client((request) async {
      if (request.method == 'POST' &&
          request.url.path == '/api/orders/1005/pay') {
        posts++;
        return posts == 1
            ? _json({
                'success': false,
                'error': 'declined',
                'data': {'payment_status': 'failed'}
              })
            : _json({
                'success': true,
                'data': {'payment_status': 'completed'}
              });
      }
      if (request.method == 'GET' && request.url.path == '/api/orders/1005') {
        // A contradictory later refusal cannot undo known completion.
        return _json(
            {'success': true, 'data': _order('1005', paymentStatus: 'failed')});
      }
      throw StateError('Unexpected fixture request: $request');
    });
    await http.runWithClient(() async {
      expect(
          (await ApiService.payOrder(
              '1005', 'saved-card'))['paymentGuardState'],
          'ready');
      expect(posts, 1);
      expect(
          (await ApiService.payOrder(
              '1005', 'saved-card'))['paymentGuardState'],
          'completed');
      final detail = await ApiService.getOrderDetails(1005);
      expect(canPayOrder(detail!), isFalse);
      SharedPreferences.resetStatic();
      final blocked = await ApiService.payOrder('1005', 'saved-card');
      expect(blocked['requestSent'], isFalse);
      expect(blocked['success'], isFalse);
      expect(blocked['paymentGuardState'], 'completed');
      expect(posts, 2);
    }, () => client);
  });

  test(
      'server completed/pending fields override status 60 and block direct pay',
      () async {
    var posts = 0;
    final client = _client((request) async {
      if (request.method == 'GET' &&
          ['/api/orders/1006', '/api/orders/1007'].contains(request.url.path)) {
        final id = request.url.path.split('/').last;
        return _json({
          'success': true,
          'data':
              _order(id, paymentStatus: id == '1006' ? 'completed' : 'pending')
        });
      }
      posts++;
      throw StateError(
          'Known pending/completed payment must not POST: $request');
    });
    await http.runWithClient(() async {
      for (final id in ['1006', '1007']) {
        expect(
            canPayOrder(_order(id,
                paymentStatus: id == '1006' ? 'completed' : 'pending')),
            isFalse);
        final order = await ApiService.getOrderDetails(int.parse(id));
        expect(canPayOrder(order!), isFalse);
        expect((await ApiService.payOrder(id, 'saved-card'))['requestSent'],
            isFalse);
      }
      expect(posts, 0);
    }, () => client);
  });

  test('only a fresh definitive refusal read unlocks an unknown attempt',
      () async {
    final readStarted = Completer<void>();
    final oldRead = Completer<http.Response>();
    var holdRead = true;
    var posts = 0;
    final client = _client((request) async {
      if (request.method == 'GET' && request.url.path == '/api/orders/1008') {
        if (holdRead) {
          readStarted.complete();
          return oldRead.future;
        }
        return _json(
            {'success': true, 'data': _order('1008', paymentStatus: 'failed')});
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/orders/1008/pay') {
        posts++;
        return posts == 1
            ? http.Response('{unreadable', 200)
            : _json({
                'success': true,
                'data': {'payment_status': 'completed'}
              });
      }
      throw StateError('Unexpected fixture request: $request');
    });
    await http.runWithClient(() async {
      final stale = ApiService.getOrderDetails(1008);
      await readStarted.future;
      await ApiService.payOrder('1008', 'saved-card');
      oldRead.complete(_json(
          {'success': true, 'data': _order('1008', paymentStatus: 'failed')}));
      expect(canPayOrder((await stale)!), isFalse);
      expect((await ApiService.payOrder('1008', 'saved-card'))['requestSent'],
          isFalse);
      holdRead = false;
      expect(canPayOrder((await ApiService.getOrderDetails(1008))!), isTrue);
      expect(posts, 1);
      await ApiService.payOrder('1008', 'saved-card');
      expect(posts, 2);
    }, () => client);
  });

  test('failed refusal persistence keeps the reservation until a safe read',
      () async {
    final store = PaymentPreferences({'auth_token': 'fixture-only'})
      ..rejectRemoval = true;
    store.install();
    var posts = 0;
    final client = _client((request) async {
      if (request.method == 'POST' &&
          request.url.path == '/api/orders/1009/pay') {
        posts++;
        return _json({
          'success': false,
          'data': {'payment_status': 'failed'}
        });
      }
      if (request.method == 'GET' && request.url.path == '/api/orders/1009') {
        return _json(
            {'success': true, 'data': _order('1009', paymentStatus: 'failed')});
      }
      throw StateError('Unexpected fixture request: $request');
    });
    await http.runWithClient(() async {
      final refused = await ApiService.payOrder('1009', 'saved-card');
      expect(refused['guardPersistenceFailed'], isTrue);
      expect((await ApiService.payOrder('1009', 'saved-card'))['requestSent'],
          isFalse);
      store.rejectRemoval = false;
      expect(canPayOrder((await ApiService.getOrderDetails(1009))!), isTrue);
      expect(posts, 1);
    }, () => client);
  });

  test('failed completion write retains the durable lock and terminal result',
      () async {
    final store = PaymentPreferences({'auth_token': 'fixture-only'});
    store.install();
    var posts = 0;
    final client = _client((request) async {
      if (request.method == 'POST' &&
          request.url.path == '/api/orders/1013/pay') {
        posts++;
        store.rejectWrites = true;
        return _json({
          'success': true,
          'data': {'payment_status': 'completed'}
        });
      }
      if (request.method == 'GET' && request.url.path == '/api/orders/1013') {
        return _json(
            {'success': true, 'data': _order('1013', paymentStatus: 'failed')});
      }
      throw StateError('Unexpected fixture request: $request');
    });
    await http.runWithClient(() async {
      expect(
          (await ApiService.payOrder(
              '1013', 'saved-card'))['paymentGuardState'],
          'completed');
      final persisted = await store.getAll();
      expect(persisted['flutter.${OrderPaymentGuard.preferenceKey('1013')}'],
          'unconfirmed');
      expect(canPayOrder((await ApiService.getOrderDetails(1013))!), isFalse);
      SharedPreferences.resetStatic();
      expect((await ApiService.payOrder('1013', 'saved-card'))['requestSent'],
          isFalse);
      expect(posts, 1);
    }, () => client);
  });

  for (final statusCode in [408, 503]) {
    test('HTTP $statusCode is not a definitive refusal or completion',
        () async {
      var posts = 0;
      final id = 'http-$statusCode';
      final client = _client((request) async {
        if (request.method != 'POST' ||
            request.url.path != '/api/orders/$id/pay') {
          throw StateError('Unexpected fixture request: $request');
        }
        posts++;
        return _json({
          'success': false,
          'error': 'unavailable',
          'data': {'payment_status': 'failed'},
        }, statusCode);
      });
      await http.runWithClient(() async {
        final result = await ApiService.payOrder(id, 'saved-card');
        expect(result['paymentGuardState'], 'unconfirmed');
        expect(result['outcomeUnknown'], isTrue);
        expect((await ApiService.payOrder(id, 'saved-card'))['requestSent'],
            isFalse);
        expect(posts, 1);
      }, () => client);
    });
  }

  for (final throws in [false, true]) {
    test(
        'reservation storage ${throws ? 'exception' : 'refusal'} sends no payment',
        () async {
      final store = PaymentPreferences({
        'auth_token': 'fixture-only',
        'cart_items': '[{"itemId":83,"quantity":2}]',
        OrderPaymentGuard.preferenceKey('unrelated'): 'unconfirmed',
      })
        ..rejectWrites = !throws
        ..throwWrites = throws;
      store.install();
      final before = await store.getAll();
      var posts = 0;
      final client = _client((request) async {
        posts++;
        throw StateError('Storage failure must not POST: $request');
      });
      final result = await http.runWithClient(
          () => ApiService.payOrder('1010', 'saved-card'), () => client);
      expect(result['success'], isFalse);
      expect(result['requestSent'], isFalse);
      expect(result['localFailure'], isTrue);
      expect(result['outcomeUnknown'], isNot(true));
      expect(result['paymentGuardState'], 'storageUnavailable');
      expect(posts, 0);
      expect(await store.getAll(), before);
    });
  }
  test('accepted Kaspi link survives reload and terminal completion discards it',
      () async {
    const id = 'kaspi-link-reload';
    const link = 'https://fixture-bank.example/pay/kept-attempt';
    expect(await OrderPaymentGuard.reserve(id), OrderPaymentState.ready);
    try {
      expect(await OrderPaymentGuard.retainKaspiLink(id, link), isTrue);
      expect(await OrderPaymentGuard.settle(id, OrderPaymentOutcome.pending),
          OrderPaymentState.unconfirmed);
    } finally {
      OrderPaymentGuard.release(id);
    }
    SharedPreferences.resetStatic();
    expect(await OrderPaymentGuard.read(id), OrderPaymentState.unconfirmed);
    expect(await OrderPaymentGuard.readKaspiLink(id), link);
    expect(await OrderPaymentGuard.reserve(id), OrderPaymentState.unconfirmed);
    final client = _client((request) async {
      throw StateError('Retained attempt must not charge again: $request');
    });
    await http.runWithClient(() async {
      expect((await ApiService.payOrder(id, 'bank-card'))['requestSent'], isFalse);
    }, () => client);
    await OrderPaymentGuard.reconcileOrder({
      'order_id': id,
      'payment_status': 'completed',
    }, readRevision: OrderPaymentGuard.beginOrderRead());
    SharedPreferences.resetStatic();
    expect(await OrderPaymentGuard.read(id), OrderPaymentState.completed);
    expect(await OrderPaymentGuard.readKaspiLink(id), isNull);
    expect(await OrderPaymentGuard.settle(id, OrderPaymentOutcome.refused),
        OrderPaymentState.completed);
    expect(await OrderPaymentGuard.reserve(id), OrderPaymentState.completed);
  });

}
