import 'package:flutter/material.dart';
import 'package:naliv_delivery/design/motion.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/design/tokens.dart';
import 'package:naliv_delivery/design/typography.dart';
import 'package:naliv_delivery/pages/order_detail_page.dart';
import 'package:naliv_delivery/ui/frosted_dock.dart';
import 'package:naliv_delivery/ui/kaspi_payment.dart';
import 'package:naliv_delivery/ui/motion_widgets.dart';
import 'package:naliv_delivery/ui/surfaces.dart';

class PaymentSuccessPage extends StatefulWidget {
  const PaymentSuccessPage(
      {super.key,
      required this.orderId,
      this.businessId,
      this.onOrders,
      this.kaspi = false,
      this.amount});

  final String orderId;
  final int? businessId;
  final Future<void> Function()? onOrders;

  /// A payment made with Kaspi.kz: the page follows Kaspi's recommended «Оплата
  /// принята» state, with the paid [amount] when the server reported it.
  final bool kaspi;
  final String? amount;

  @override
  State<PaymentSuccessPage> createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage> {
  bool _opening = false;
  double _dockHeight = 0;

  /// The paid order, with Home beneath it: back from the order goes home, and
  /// the checkout and cart that led here never come back.
  Future<void> _orders() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      if (widget.onOrders != null) {
        await widget.onOrders!();
      } else if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => OrderDetailPage(order: {
              'order_id': widget.orderId,
              if (widget.businessId != null) 'business_id': widget.businessId,
            }),
          ),
          (route) => route.isFirst,
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _home() => Navigator.of(context).popUntil((route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _home();
      },
      child: Scaffold(
        backgroundColor: palette.background,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: FrostedDock(
              onDockHeightChanged: (height) {
                if ((height - _dockHeight).abs() > 0.5) {
                  setState(() => _dockHeight = height);
                }
              },
              content: SafeArea(
                bottom: false,
                child: CustomScrollView(
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.xxxl,
                          AppSpacing.huge,
                          AppSpacing.xxxl,
                          // Clears the bar by its measured height.
                          _dockHeight +
                              MediaQuery.paddingOf(context).bottom +
                              AppSpacing.huge,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AppearIn(
                              scale: .7,
                              duration: AppMotion.pop,
                              child: widget.kaspi
                                  ? const KaspiResultMark(accepted: true)
                                  : Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: palette.accent,
                                      ),
                                      child: Icon(Icons.check_rounded,
                                          color: palette.textOnAccent,
                                          size: 56),
                                    ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                                widget.kaspi
                                    ? 'Оплата принята'
                                    : 'Оплата прошла успешно!',
                                textAlign: TextAlign.center,
                                style: AppTypography.displayBold),
                            if (widget.kaspi && widget.amount != null) ...[
                              const SizedBox(height: AppSpacing.xl),
                              Text(widget.amount!,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.displayBold),
                            ],
                            const SizedBox(height: AppSpacing.huge),
                            AppSurface(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.xxxl),
                              child: Column(
                                children: [
                                  Text('Заказ #${widget.orderId}',
                                      textAlign: TextAlign.center,
                                      style: AppTypography.title),
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    'Следите за статусом в заказе.',
                                    textAlign: TextAlign.center,
                                    style: AppTypography.body
                                        .copyWith(color: palette.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              dock: Padding(
                // The dock supplies the 16 px sides and the safe-area inset below.
                padding: const EdgeInsets.fromLTRB(
                    0, AppSpacing.xxxl, 0, AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      key: const ValueKey('payment-success-orders'),
                      onPressed: _opening ? null : _orders,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                          _opening ? 'Открываем заказ…' : 'Отслеживать заказ'),
                    ),
                    TextButton(
                      key: const ValueKey('payment-success-home'),
                      onPressed: _opening ? null : _home,
                      style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(44)),
                      child: const Text('На главную'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
