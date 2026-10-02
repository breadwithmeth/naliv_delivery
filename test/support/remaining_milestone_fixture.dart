import 'dart:convert';
import 'package:http/http.dart' as http;

enum PaymentFixtureScenario { completed, pending, unreadable, refused }

class RemainingMilestoneFixture {
  static int quoteFailures = 0;
  static int createRefusals = 0;
  static PaymentFixtureScenario paymentScenario =
      PaymentFixtureScenario.completed;
  static int _purchaseNumber = 0;
  static int _orderNumber = 900;
  static final _purchases = <String, Map<String, dynamic>>{};
  static final certificates = <Map<String, dynamic>>[];
  static final orders = <Map<String, dynamic>>[];

  static void reset() {
    quoteFailures = 0;
    createRefusals = 0;
    paymentScenario = PaymentFixtureScenario.completed;
    _purchaseNumber = 0;
    _orderNumber = 900;
    _purchases.clear();
    certificates.clear();
    orders.clear();
  }

  static http.Response _json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status,
          headers: {'content-type': 'application/json; charset=utf-8'});

  static bool _number(Object? value) => value is num && value.isFinite;
  static Map<String, dynamic>? _body(http.Request request) {
    try {
      final value = jsonDecode(request.body);
      return value is Map<String, dynamic> ? value : null;
    } catch (_) {
      return null;
    }
  }

  static Future<http.Response?> respond(
    http.Request request, {
    required bool authorized,
    required List<Map<String, dynamic>> cards,
    required Future<http.Response> Function() reject,
    required List<Map<String, dynamic>> Function(List<Map<String, dynamic>>)
        orderItems,
  }) async {
    final uri = request.url;
    if (uri.pathSegments.length == 3 && uri.pathSegments[1] == 'orders') {
      final id = int.tryParse(uri.pathSegments[2]);
      final order =
          orders.where((order) => order['order_id'] == id).firstOrNull;
      if (order != null) {
        if (!authorized ||
            request.method != 'GET' ||
            uri.queryParameters.isNotEmpty) {
          return reject();
        }
        return _json({
          'success': true,
          'data': {'order': order}
        });
      }
    }
    if (uri.path == '/api/delivery/calculate-by-address') {
      if (request.method != 'GET' ||
          !const {'1', '2'}.contains(uri.queryParameters['business_id']) ||
          uri.queryParameters.length != 3 ||
          double.tryParse(uri.queryParameters['lat'] ?? '')?.isFinite != true ||
          double.tryParse(uri.queryParameters['lon'] ?? '')?.isFinite != true) {
        return reject();
      }
      if (quoteFailures > 0) {
        quoteFailures--;
        return _json(
            {'success': false, 'error': 'Фикстура: расчёт доставки недоступен'},
            503);
      }
      return _json({
        'success': true,
        'data': {
          'delivery_cost': 800,
          'base_delivery_cost': 700,
          'service_fee_amount': 100,
        }
      });
    }
    if (uri.path == '/api/orders/validate-promo-code') {
      final body = _body(request);
      if (!authorized ||
          request.method != 'POST' ||
          uri.queryParameters.isNotEmpty ||
          body == null ||
          body.length != 5 ||
          body['promo_code'] is! String ||
          !_number(body['order_subtotal']) ||
          !_number(body['delivery_price']) ||
          !const [1, 2].contains(body['business_id']) ||
          body['items'] is! List) {
        return reject();
      }
      if (body['promo_code'] != 'SALE') {
        return _json(
            {'success': false, 'error': 'Фикстура: промокод не найден'});
      }
      return _json({
        'success': true,
        'data': {
          'promo_discount': 100,
          'final_delivery_price': body['delivery_price'],
        }
      });
    }
    if (uri.path == '/api/certificates/validate') {
      final body = _body(request);
      if (!authorized ||
          request.method != 'POST' ||
          uri.queryParameters.isNotEmpty ||
          body == null ||
          body.length != 2 ||
          body['code'] is! String ||
          !_number(body['order_subtotal'])) {
        return reject();
      }
      if (body['code'] != 'GIFT') {
        return _json(
            {'success': false, 'error': 'Фикстура: сертификат не найден'});
      }
      return _json({
        'success': true,
        'data': {
          'can_use': true,
          'max_available_amount': 500,
          'certificate': {'id': 81, 'code': 'GIFT', 'balance': 500}
        }
      });
    }
    if (uri.path == '/api/orders/create-order-no-payment') {
      final body = _body(request);
      const required = {
        'business_id',
        'street',
        'house',
        'lat',
        'lon',
        'apartment',
        'entrance',
        'floor',
        'extra',
        'items',
        'delivery_type',
        'delivery_time',
        'total_amount',
        'courier_tips',
        'use_bonuses'
      };
      const allowed = {
        ...required,
        'bonus_amount',
        'promo_code',
        'certificate_id',
        'certificate_code',
        'certificate_amount'
      };
      if (!authorized ||
          request.method != 'POST' ||
          uri.queryParameters.isNotEmpty ||
          body == null ||
          !body.keys.toSet().containsAll(required) ||
          !body.keys.every(allowed.contains) ||
          !const [1, 2].contains(body['business_id']) ||
          !const ['DELIVERY', 'PICKUP'].contains(body['delivery_type']) ||
          body['delivery_time'] != 'NOW' ||
          body['courier_tips'] != 0 ||
          body['use_bonuses'] is! bool ||
          !_number(body['total_amount']) ||
          body['items'] is! List ||
          (body['items'] as List).isEmpty) {
        return reject();
      }
      if (createRefusals > 0) {
        createRefusals--;
        return _json({
          'success': false,
          'error': {'message': 'Фикстура: заказ отклонён'}
        }, 409);
      }
      final order = <String, dynamic>{
        'order_id': ++_orderNumber,
        'business_id': body['business_id'],
        'business': {
          'id': body['business_id'],
          'name': 'Тестовый магазин',
          'address': 'Тестовый адрес, 16'
        },
        'total_amount': body['total_amount'],
        'items': orderItems([
          for (final item in body['items'] as List)
            Map<String, dynamic>.from(item as Map),
        ]),
        'delivery_type': body['delivery_type'],
        'street': body['street'],
        'house': body['house'],
        'log_timestamp': '2026-10-02T10:00:00Z',
        'current_status': {'status': '0'},
      };
      orders.insert(0, order);
      return _json({'success': true, 'data': order}, 201);
    }
    if (uri.pathSegments.length == 5 &&
        uri.pathSegments[1] == 'orders' &&
        uri.pathSegments[3] == 'kaspi-qr') {
      final id = uri.pathSegments[2];
      final order = orders
          .where((order) => order['order_id'].toString() == id)
          .firstOrNull;
      final action = uri.pathSegments.last;
      if (!authorized ||
          uri.queryParameters.isNotEmpty ||
          (id != 'fixture-order' && order == null)) {
        return reject();
      }
      if (action == 'pay') {
        final body = _body(request);
        if (request.method != 'POST' ||
            body == null ||
            body.length != 1 ||
            body['method'] != 'link') {
          return reject();
        }
        if (paymentScenario == PaymentFixtureScenario.unreadable) {
          return http.Response('{"success":', 200,
              headers: {'content-type': 'application/json'});
        }
        return _json({
          'success': true,
          'data': {
            'paymentLink': 'http://127.0.0.1:8775/fixture_bank.html?order=$id',
            'behaviorOptions': {
              'StatusPollingInterval': 2,
              'PaymentConfirmationTimeout': 2,
            },
          },
        });
      }
      if (action == 'status' && request.method == 'GET') {
        final status = switch (paymentScenario) {
          PaymentFixtureScenario.completed => 'completed',
          PaymentFixtureScenario.pending => 'pending',
          PaymentFixtureScenario.refused => 'failed',
          PaymentFixtureScenario.unreadable => null,
        };
        if (status == null) {
          return http.Response('{"success":', 200,
              headers: {'content-type': 'application/json'});
        }
        if (order != null) order['payment_status'] = status;
        return _json({
          'success': true,
          'data': {'payment_status': status},
          if (status == 'failed') 'message': 'Фикстура: банк отклонил оплату',
        });
      }
      return reject();
    }
    if (uri.pathSegments.length == 4 &&
        uri.pathSegments[1] == 'orders' &&
        uri.pathSegments.last == 'pay') {
      final body = _body(request);
      final id = int.tryParse(uri.pathSegments[2]);
      final order = orders.where((o) => o['order_id'] == id).firstOrNull;
      if (!authorized ||
          request.method != 'POST' ||
          uri.queryParameters.isNotEmpty ||
          body == null ||
          body.length != 2 ||
          body['payment_type'] != 'card' ||
          !cards.any((c) => c['card_id'] == body['card_id']) ||
          order == null) {
        return reject();
      }
      if (paymentScenario == PaymentFixtureScenario.refused) {
        order['payment_status'] = 'failed';
        return _json(
            {'success': false, 'message': 'Синтетический отказ банка'}, 409);
      }
      if (paymentScenario == PaymentFixtureScenario.pending ||
          paymentScenario == PaymentFixtureScenario.unreadable) {
        order['payment_status'] = 'pending';
        if (paymentScenario == PaymentFixtureScenario.unreadable) {
          return http.Response('{unreadable', 200);
        }
        return _json({
          'success': true,
          'data': {'payment_status': 'pending'}
        });
      }
      order['payment_status'] = 'completed';
      return _json({
        'success': true,
        'data': {'payment_status': 'completed'}
      });
    }
    if (uri.path == '/api/certificates/purchase') {
      final body = _body(request);
      const allowed = {
        'amount',
        'payment_type',
        'halyk_card_id',
        'recipient_login',
        'message'
      };
      if (!authorized ||
          request.method != 'POST' ||
          uri.queryParameters.isNotEmpty ||
          body == null ||
          !body.keys.every(allowed.contains) ||
          !_number(body['amount']) ||
          (body['amount'] as num) <= 0 ||
          body['payment_type'] != 'card' ||
          !cards.any((c) => c['card_id'] == body['halyk_card_id']) ||
          (body.containsKey('recipient_login') &&
              body['recipient_login'] is! String) ||
          (body.containsKey('message') && body['message'] is! String)) {
        return reject();
      }
      if (body['message'] == 'refuse') {
        return _json({
          'success': false,
          'error': {'message': 'Фикстура: покупка отклонена'}
        });
      }
      final id = 'fixture-purchase-${++_purchaseNumber}';
      final record = <String, dynamic>{
        'purchase_id': id,
        'amount': body['amount'],
        'payment_status':
            body['message'] == 'pending' ? 'pending' : 'completed',
        'certificate': {
          'certificate_id': 900 + _purchaseNumber,
          'code':
              'FIXT-2026-GIFT-${_purchaseNumber.toString().padLeft(4, '0')}',
          'amount': body['amount'],
          'balance': body['amount'],
          'status': 'active'
        },
      };
      _purchases[id] = record;
      if (record['payment_status'] == 'completed') {
        certificates
            .add(Map<String, dynamic>.from(record['certificate'] as Map));
      }
      return _json({'success': true, 'data': record});
    }
    if (uri.pathSegments.length == 5 &&
        uri.pathSegments[1] == 'certificates' &&
        uri.pathSegments[2] == 'purchases' &&
        uri.pathSegments[4] == 'status') {
      final record = _purchases[uri.pathSegments[3]];
      if (!authorized ||
          request.method != 'GET' ||
          uri.queryParameters.isNotEmpty ||
          record == null) {
        return reject();
      }
      if (record['payment_status'] != 'completed') {
        record['payment_status'] = 'completed';
        certificates
            .add(Map<String, dynamic>.from(record['certificate'] as Map));
      }
      return _json({'success': true, 'data': record});
    }
    final id = int.tryParse(uri.pathSegments.last);
    final order = orders.where((o) => o['order_id'] == id).firstOrNull;
    if (uri.pathSegments.length == 3 &&
        uri.pathSegments[1] == 'orders' &&
        order != null) {
      if (!authorized ||
          request.method != 'GET' ||
          uri.queryParameters.isNotEmpty) {
        return reject();
      }
      return _json({'success': true, 'data': order});
    }
    return null;
  }
}
