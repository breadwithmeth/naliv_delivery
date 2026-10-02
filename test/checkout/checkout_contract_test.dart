import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/features/checkout/checkout_contract.dart';

void main() {
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
