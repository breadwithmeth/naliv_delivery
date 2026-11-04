import 'package:flutter/material.dart';

import '../pages/order_detail_page.dart';

/// Where a customer stands once an order exists: on that order, with the app's
/// first screen (Home) right beneath it. Back from the order goes home; the
/// cleared cart and the finished checkout never come back.
///
/// [payment], when given, is opened on top of the order, so leaving payment
/// without paying shows the unpaid order and its «Оплатить», not an empty cart.
Future<void> showOrderFromRoot(
  NavigatorState navigator, {
  required Map<String, dynamic> order,
  Widget? payment,
}) {
  final orderRoute = MaterialPageRoute<void>(
    builder: (_) => OrderDetailPage(order: order),
  );
  final settled =
      navigator.pushAndRemoveUntil(orderRoute, (route) => route.isFirst);
  if (payment != null) {
    navigator.push(MaterialPageRoute<void>(builder: (_) => payment));
  }
  return settled;
}

/// The created order as its page first shows it: the server's answer, plus the
/// delivery type and address this checkout sent wherever the answer leaves
/// them out (an unpaid order's response may carry no address at all).
Map<String, dynamic> withSubmittedAddress(
  Map<String, dynamic> order,
  Map<String, dynamic> request,
) {
  String? text(Object? value) {
    final result = value?.toString().trim();
    return result == null || result.isEmpty || result == 'null' ? null : result;
  }

  final result = <String, dynamic>{...order};
  final type = text(request['delivery_type']);
  if (text(result['delivery_type']) == null && type != null) {
    result['delivery_type'] = type;
  }
  if (type != 'DELIVERY') return result;
  final street = text(request['street']);
  final house = text(request['house']);
  final submitted = <String, dynamic>{
    if (street != null)
      'address': house == null || house == '-' ? street : '$street, $house',
    if (street != null) 'street': street,
    if (house != null && house != '-') 'house': house,
    if (request['lat'] != null) 'lat': request['lat'],
    if (request['lon'] != null) 'lon': request['lon'],
    if (text(request['entrance']) case final value?) 'entrance': value,
    if (text(request['floor']) case final value?) 'floor': value,
    if (text(request['apartment']) case final value?) 'apartment': value,
    if (text(request['extra']) case final value?) 'comment': value,
  };
  final known = result['delivery_address'];
  result['delivery_address'] = {
    ...submitted,
    if (known is Map)
      for (final entry in known.entries)
        if (text(entry.value) != null) entry.key.toString(): entry.value,
  };
  return result;
}
