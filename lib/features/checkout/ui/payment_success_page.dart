import 'package:flutter/material.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/design/typography.dart';
import 'package:naliv_delivery/features/orders/ui/orders_page.dart';
import 'package:naliv_delivery/ui/surfaces.dart';

class PaymentSuccessPage extends StatefulWidget {
  const PaymentSuccessPage(
      {super.key, required this.orderId, this.businessId, this.onOrders});

  final String orderId;
  final int? businessId;
  final Future<void> Function()? onOrders;

  @override
  State<PaymentSuccessPage> createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage> {
  bool _opening = false;

  Future<void> _orders() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      if (widget.onOrders != null) {
        await widget.onOrders!();
      } else if (mounted) {
        await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
          builder: (_) => OrdersPage(businessId: widget.businessId),
        ));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(children: [
          Expanded(
              child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minHeight: constraints.maxHeight),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 128, 16, 32),
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: palette.accent),
                                      child: Icon(Icons.check_rounded,
                                          color: palette.textOnAccent,
                                          size: 56)),
                                  const SizedBox(height: 28),
                                  Text('Оплата прошла успешно!',
                                      textAlign: TextAlign.center,
                                      style: AppTypography.displayBold),
                                  const SizedBox(height: 24),
                                  AppSurface(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(children: [
                                        Text('Заказ #${widget.orderId}',
                                            textAlign: TextAlign.center,
                                            style: AppTypography.title),
                                        const SizedBox(height: 8),
                                        Text(
                                            'Статус заказа доступен в разделе «Мои заказы».',
                                            textAlign: TextAlign.center,
                                            style: AppTypography.body.copyWith(
                                                color: palette.textSecondary)),
                                      ])),
                                ]),
                          ))))),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('payment-success-orders'),
                    onPressed: _opening ? null : _orders,
                    child: Text(_opening ? 'Открываем заказы…' : 'Мои заказы'),
                  ))),
        ]),
      ))),
    );
  }
}
