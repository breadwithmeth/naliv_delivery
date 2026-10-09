import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/features/checkout/checkout_contract.dart';
import 'package:naliv_delivery/utils/order_ui_helpers.dart';

void main() {
  group('server total reconciliation', () {
    test('a divergent server total is explained to the customer', () {
      final notice = checkoutAmountNotice(
        clientAmount: 105360,
        serverAmount: 105390,
      );
      expect(notice, contains('105390 ₸'));
      expect(notice, contains('105360 ₸'));
      expect(
        checkoutAmountNotice(clientAmount: 26340, serverAmount: 26370),
        isNotNull,
      );
    });

    test('matching or missing totals stay silent', () {
      expect(checkoutAmountNotice(clientAmount: 26340, serverAmount: 26340),
          isNull);
      expect(checkoutAmountNotice(clientAmount: 26340, serverAmount: 26341),
          isNull);
      expect(checkoutAmountNotice(clientAmount: 26340, serverAmount: 26339),
          isNull);
      expect(checkoutAmountNotice(clientAmount: 26340, serverAmount: null),
          isNull);
      expect(checkoutAmountNotice(clientAmount: null, serverAmount: 26340),
          isNull);
      expect(
          checkoutAmountNotice(
              clientAmount: 26340, serverAmount: double.infinity),
          isNull);
    });

    test('the echoed request total is not mistaken for a server recomputation',
        () {
      // A server that echoes `total_amount` while charging its own summary must still be compared
      // against the summary, not against the figure the client sent.
      final order = {
        'total_amount': 26340,
        'cost_summary': {'items_total': 26340, 'total_sum': 26370},
      };
      expect(resolveServerChargedAmount(order), 26370);
      expect(
          checkoutAmountNotice(
            clientAmount: 26340,
            serverAmount: resolveServerChargedAmount(order),
          ),
          isNotNull);
      // An acknowledgment that only echoes the request total stays silent.
      expect(resolveServerChargedAmount({'total_amount': 26340}), 26340);
      expect(
          checkoutAmountNotice(
            clientAmount: 26340,
            serverAmount: resolveServerChargedAmount({'total_amount': 26340}),
          ),
          isNull);
    });

    test('the created order exposes the amount the server will charge', () {
      expect(
          resolveOrderTotalAmount({
            'order_id': 99123,
            'total_amount': 26370,
            'cost_summary': {'items_total': 26340, 'total_sum': 26370},
          }),
          26370);
      expect(
          resolveOrderTotalAmount({
            'cost_summary': {'total_sum': 26370}
          }),
          26370);
      // No total in the acknowledgment means nothing to compare, not a mismatch.
      expect(resolveOrderTotalAmount({'order_id': 99123}), isNull);
    });
  });

  test('only an explicit finite delivery price can authorize a delivery quote',
      () {
    for (final response in <Map<String, dynamic>?>[
      null,
      {},
      {'service_fee_amount': 100},
      {'delivery_cost': null},
      {'delivery_cost': -1},
      {'delivery_cost': double.nan},
      {'delivery_cost': double.infinity},
      {'delivery_cost': 800, 'base_delivery_cost': -100},
      {'delivery_cost': 800, 'service_fee_amount': 'unknown'},
    ]) {
      expect(CheckoutQuote.fromResponse(response), isNull);
    }
    final free = CheckoutQuote.fromResponse({'delivery_cost': 0});
    expect(free!.baseDeliveryCost, 0);
    expect(free.serviceFee, 0);
    final quoted = CheckoutQuote.fromResponse(
        {'delivery_cost': 800, 'base_delivery_cost': 700});
    expect(quoted!.baseDeliveryCost, 700);
    expect(quoted.serviceFee, 100);
  });

  test(
      'order acknowledgment requires a usable server identity before cart destruction',
      () {
    for (final response in <Map<String, dynamic>>[
      {
        'success': false,
        'data': {'order_id': 'server-order'}
      },
      {'success': true},
      {'success': true, 'data': []},
      {
        'success': true,
        'data': {'total_amount': 1000}
      },
      {
        'success': true,
        'data': {'order_id': ''}
      },
      {
        'success': true,
        'data': {'order_id': 'null'}
      },
      {
        'success': true,
        'data': {'order_id': false}
      },
      {
        'success': true,
        'data': {'order_id': 0}
      },
      {
        'success': true,
        'data': {'order_id': '0'}
      },
    ]) {
      expect(checkoutCreatedOrder(response), isNull);
    }
    final accepted = checkoutCreatedOrder({
      'success': true,
      'data': {'order_uuid': 'real-server-uuid', 'total_amount': 1830}
    });
    expect(accepted!['order_uuid'], 'real-server-uuid');
    expect(accepted['total_amount'], 1830);
  });
}
