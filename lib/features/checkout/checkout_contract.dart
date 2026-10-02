import '../../utils/api.dart';

class CheckoutQuote {
  const CheckoutQuote._({
    required this.deliveryPrice,
    required this.baseDeliveryCost,
    required this.serviceFee,
  });

  final double deliveryPrice;
  final double baseDeliveryCost;
  final double serviceFee;

  static CheckoutQuote? fromResponse(Map<String, dynamic>? data) {
    if (data == null) return null;
    final total = checkoutAmount(data['delivery_cost']);
    if (total == null) return null;
    final base = data['base_delivery_cost'] != null
        ? checkoutAmount(data['base_delivery_cost'])
        : total;
    final fee = data['service_fee_amount'] != null
        ? checkoutAmount(data['service_fee_amount'])
        : base == null
            ? null
            : (total - base).clamp(0.0, double.infinity).toDouble();
    if (base == null || fee == null) return null;
    return CheckoutQuote._(
      deliveryPrice: total,
      baseDeliveryCost: base,
      serviceFee: fee,
    );
  }
}

double? checkoutAmount(dynamic value) {
  final amount = value is num ? value.toDouble() : double.tryParse('$value');
  return amount != null && amount.isFinite && amount >= 0 ? amount : null;
}

Map<String, dynamic>? checkoutCreatedOrder(Map<String, dynamic> response) {
  if (response['success'] != true) return null;
  final order = ApiService.mapFromDynamic(response['data']);
  final id = order['order_id'] ?? order['order_uuid'] ?? order['id'];
  if (id is! String && id is! num) return null;
  if (id is num && (!id.isFinite || id <= 0)) return null;
  final text = id.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return null;
  final numericId = double.tryParse(text);
  if (numericId != null && (!numericId.isFinite || numericId <= 0)) return null;
  return order;
}
